//SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.0;

import "./interfaces/IBetToken.sol";
import "./interfaces/IPredictionMarket.sol";
import "./Checkpoint.sol";

contract Strategy is Checkpoint {
    event StrategyFollowed(
        address userFollowed,
        uint256 userAmount,
        address traderAddress,
        address strategyAddress,
        uint256 checkpointId
    );
    event StrategyUnfollowed(
        address userUnFollowed,
        uint256 userAmountClaimed,
        address strategyAddress,
        bool isFullClaim,
        uint256 checkpointId
    );
    event BetPlaced(
        uint256 conditionIndex,
        uint8 side,
        uint256 totalAmount,
        uint256 checkpointId
    );
    event BetClaimed(
        uint256 conditionIndex,
        uint8 winningSide,
        bool isWon,
        uint256 totalAmount
    );
    
    modifier isStrategyActive() {
        require(
            status == StrategyStatus.ACTIVE,
            "Strategy::isStrategyActive: STRATEGY_INACTIVE"
        );
        _;
    }

    modifier onlyTrader() {
        require(msg.sender == trader, "Strategy::onlyTrader: INVALID_SENDER");
        _;
    }

    modifier onlyUser() {
        require(
            userInfo[msg.sender].depositAmount > 0,
            "Strategy::onlyTrader: INVALID_USER"
        );
        _;
    }

    constructor(
        address _predictionMarket,
        string memory _name,
        address payable _trader
    ) payable {
        require(
            _trader != address(0),
            "Strategy::constructor:INVALID TRADER ADDRESS."
        );
        require(
            _predictionMarket != address(0),
            "Strategy::constructor:INVALID PREDICTION MARKET ADDRESS."
        );
        require(msg.value > 0, "Strategy::constructor: ZERO_FUNDS");

        predictionMarket = IPredictionMarket(_predictionMarket);
        strategyName = _name;
        trader = _trader;
        traderFund += msg.value;

        status = StrategyStatus.ACTIVE;
    }

    function follow() public payable isStrategyActive {
        User storage user = userInfo[msg.sender];

        require(msg.value > 0, "Strategy::follow: ZERO_FUNDS");
        require(user.depositAmount == 0, "Strategy::follow: ALREADY_FOLLOWING");

        totalUserFunds += msg.value;

        user.depositAmount = msg.value;
        users.push(msg.sender);

        //get total volume (trader + all users)
        addCheckpoint(users, (totalUserFunds + traderFund));
        user.entryCheckpointId = latestCheckpointId;
        emit StrategyFollowed(
            msg.sender,
            msg.value,
            trader,
            address(this),
            latestCheckpointId
        );
    }

    //unfollow is subjected to fund availability
    function unfollow() public onlyUser {
        User storage user = userInfo[msg.sender];
        user.exitCheckpointId = latestCheckpointId;
        (
            uint256 userClaimAmount,
            uint256 userTotalProfit,
            uint256 userTotalLoss
        ) = getUserClaimAmount(user);
        require(
            userClaimAmount > 0,
            "Strategy::unfollow: ZERO_CLAIMABLE_AMOUNT"
        );

        (payable(msg.sender)).transfer(userClaimAmount);
        user.totalProfit = userTotalProfit;
        user.totalLoss = userTotalLoss;

        totalUserFunds -= userClaimAmount;
        for (uint256 userIndex = 0; userIndex < users.length; userIndex++) {
            if (users[userIndex] == msg.sender) {
                delete users[userIndex];
                break;
            }
        }
        addCheckpoint(users, (totalUserFunds + traderFund));

        emit StrategyUnfollowed(
            msg.sender,
            userClaimAmount,
            address(this),
            isFullClaim,
            latestCheckpointId - 1
        );
    }

    //get user claim amount. deduct fees from profit
    // update exitpoint
    // transfer amt
    // add new checkpoint, pop the user from array, update userfund
    // update user(if any)

    // for getting USer claim amount
    function getUserClaimAmount(User memory userDetails)
        internal
        view
        returns (
            uint256 userClaimAmount,
            uint256 userTotalProfit,
            uint256 userTotalLoss
        )
    {
        for (
            uint256 cpIndex = userDetails.entryCheckpointId;
            cpIndex < userDetails.exitCheckpointId;
            cpIndex++
        ) {
            Checkpoint memory cp = checkpoints[cpIndex];

            uint256 userProfit = (cp.totalProfit * userDetails.depositAmount) /
                cp.totalVolume;
            userTotalLoss +=
                (cp.totalLoss * userDetails.depositAmount) /
                cp.totalVolume;

            userTotalProfit += userProfit - calculateFees(userProfit);
        }
        userClaimAmount =
            userDetails.depositAmount +
            userTotalProfit -
            userTotalLoss;
        return (userClaimAmount, userTotalProfit, userTotalLoss);
    }

    function removeTraderFund() public onlyTrader {
        if (status == StrategyStatus.ACTIVE) status = StrategyStatus.INACTIVE;
        uint256 amount = getClaimAmount();
        traderFund -= amount;
        trader.transfer(amount);
    }

    // for getting Trader claim amount
    function getClaimAmount()
        internal
        view
        returns (uint256 traderClaimAmount)
    {
        uint256 traderTotalProfit;
        uint256 traderTotalLoss;
        for (uint256 cpIndex = 0; cpIndex < latestCheckpointId; cpIndex++) {
            Checkpoint memory cp = checkpoints[cpIndex];
            uint256 traderProfit = (cp.totalProfit * traderFund) /
                cp.totalVolume;
            traderTotalLoss += (cp.totalLoss * traderFund) / cp.totalVolume;

            uint256 userProfit = cp.totalProfit - traderProfit;
            traderTotalProfit += traderProfit + calculateFees(userProfit);
        }
        traderClaimAmount = traderFund + traderTotalProfit - traderTotalLoss;
    }

    //fuction to calculate fees
    function calculateFees(uint256 amount)
        internal
        view
        returns (uint256 feeAmount)
    {
        feeAmount = (amount * traderFees) / 10000;
    }

    function bet(
        uint256 _conditionIndex,
        uint8 _side,
        uint256 _amount
    ) public isStrategyActive onlyTrader {
        require(
            latestCheckpointId > 0,
            "Strategy::bet: NO CHECKPOINT CREATED YET"
        );

        require(users.length > 0, "Strategy::bet: NO USERS EXIST");

        uint256 percentage = (_amount * 100) / traderFund;
        require(
            percentage < 5,
            "Strategy::placeBet:INVALID AMOUNT. Percentage > 5"
        );

        uint256 betAmount = ((percentage * totalUserFunds) / 100) + _amount;
        Checkpoint storage checkpoint = checkpoints[latestCheckpointId - 1];
        checkpoint.totalInvested += betAmount;
        conditionIndexToCheckpoints[_conditionIndex].push(latestCheckpointId);
        Market memory market;
        if (_side == 0) {
            market.lowBets = betAmount;
        } else {
            market.highBets = betAmount;
        }
        markets[latestCheckpointId][_conditionIndex] = market;

        predictionMarket.betOnCondition{value: betAmount}(
            _conditionIndex,
            _side,
            betAmount,
            latestCheckpointId - 1
        );
    }

    function claim(uint256 _conditionIndex) public isStrategyActive onlyTrader {
        (uint8 winningSide, uint256 perBetPrice) = predictionMarket
            .getPerUserClaimAmount(_conditionIndex);
        predictionMarket.claim(_conditionIndex);

        (
            ,
            ,
            ,
            ,
            ,
            ,
            address lowBetToken,
            address highBetToken,
            ,

        ) = predictionMarket.conditions(_conditionIndex);

        IBetToken highBet = IBetToken(highBetToken);
        IBetToken lowBet = IBetToken(lowBetToken);

        uint256 totalInvested;
        uint256[] memory checkpointList = conditionIndexToCheckpoints[
            _conditionIndex
        ];
        for (uint256 index = 0; index < checkpointList.length; index++) {
            Market memory market = markets[checkpointList[index]][
                _conditionIndex
            ];
            Checkpoint memory cp = checkpoints[checkpointList[index]];

            uint256 profit;
            uint256 loss;

            if (winningSide == 1 && market.highBets > 0) {
                profit = market.highBets * perBetPrice;
                loss = market.lowBets;
            } else {
                profit = market.lowBets * perBetPrice;
                loss = market.highBets;
            }

            cp.totalProfit += profit;
            cp.totalLoss += loss;

            totalUserFunds = totalUserFunds + profit - loss;
        }
        //add event
    }

    function getConditionDetails(uint256 _conditionIndex)
        public
        view
        returns (
            string memory market,
            uint256 settlementTime,
            bool isSettled
        )
    {
        (market, , , settlementTime, isSettled, , , , , ) = (
            predictionMarket.conditions(_conditionIndex)
        );
    }

    function getActiveConditions(uint256 _checkpoint)
        public
        view
        returns (uint256[] memory conditionStatus)
    {
        uint256[] memory condition = conditionIndexToCheckpoints[_checkpoint];
        for (uint256 index = 0; index < condition.length; index++) {
            (
                string memory market,
                ,
                ,
                uint256 settlementTime,
                bool isSettled,
                ,
                ,
                ,
                ,

            ) = (predictionMarket.conditions(condition[index]));
            if (!isSettled) {
                conditionStatus.push(condition[index]);
            }
            //compare settlement time, push id in an array and return
        }
    }
}
