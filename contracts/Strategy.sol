//SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.0;

import "./interfaces/IBetToken.sol";
import "./interfaces/IPredictionMarket.sol";

import "./StrategyStorage.sol";

contract Strategy is StrategyStorage {
    event StrategyFollowed(address userFollowed, uint256 userAmount);
    event BetPlaced(uint256 conditionIndex, uint8 side, uint256 totalAmount);
    event BetClaimed(
        uint256 conditionIndex,
        uint8 winningSide,
        uint256 totalAmount
    );
    event StrategyUnfollowed(
        address userUnFollowed,
        uint256 userAmountClaimed,
        address strategyAddress,
        bool isFullClaim,
        uint256 checkpointId
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
            userInfo[msg.sender].initialdepositAmount > 0,
            "Strategy::onlyTrader: INVALID_USER"
        );
        _;
    }

    modifier validBetAmount(uint256 totalAmount, uint256[] memory amounts) {
        uint256 total = 0;
        for (uint8 index = 0; index < amounts.length; index++) {
            total += amounts[index];
        }
        require(
            total == totalAmount,
            "Strategy::validBetAmount: INVALID_BET_AMOUNT"
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

    //view functions
    function isMarketActive(uint256 _conditionIndex)
        public
        view
        returns (bool)
    {
        (, uint256 settlementTime, ) = getConditionDetails(_conditionIndex);
        if (settlementTime > block.timestamp) return true;
        return false;
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

    function follow() public payable isStrategyActive {
        User storage user = userInfo[msg.sender];

        require(msg.value > 0, "Strategy::follow: ZERO_FUNDS");
        require(
            user.initialdepositAmount == 0,
            "Strategy::follow: ALREADY_FOLLOWING"
        );

        totalUserFunds += msg.value;
        totalBetFunds += msg.value;

        user.initialdepositAmount = msg.value;
        user.firstMarketIndex = markets.length;
        users.push(msg.sender);

        emit StrategyFollowed(msg.sender, msg.value);
    }

    function bet(
        uint256 _conditionIndex,
        uint8 _side,
        uint256[] memory _users,
        uint256[] memory _userAmounts
    )
        external
        payable
        isStrategyActive
        onlyTrader
        validBetAmount(msg.value, _userAmounts)
    {
        require(
            isMarketActive(_conditionIndex),
            "Strategy::bet: MARKET_ALREADY_SETTLED"
        );
        require(totalBetFunds > 0, "Strategy::bet: NO_FUND_AVAILABLE");
        require(
            _users.length > 0 && _userAmounts.length > 0,
            "Strategy::bet: NO_USERS_FOUND"
        );
        require(
            _users.length == _userAmounts.length,
            "Strategy::bet: INVALID_ARRAY_LENGTH"
        );

        uint256 betIndex = markets.length;
        markets.push(_conditionIndex);

        Bet memory newBet = bets[betIndex];
        newBet.betAmount = msg.value;
        newBet.conditionIndex = _conditionIndex;
        newBet.side = _side;
        newBet.users = _users;
        newBet.userAmounts = _userAmounts;

        totalBetFunds -= msg.value;
        marketToBets[_conditionIndex].push(betIndex);

        //place bet
        predictionMarket.betOnCondition{value: msg.value}(
            _conditionIndex,
            _side
        );

        emit BetPlaced(_conditionIndex, _side, msg.value);
    }

    function claim(uint256 _conditionIndex) public {
        require(
            !isMarketActive(_conditionIndex),
            "Strategy::claim: MARKET_ACTIVE"
        );
        _claim(_conditionIndex);
    }

    //allows only 5 markets to claim
    function claimAll(uint256[] memory _conditions) public {
        require(
            _conditions.length < 10,
            "Strategy::claimAll: LENGTH_EXCEEDS_MAX_LIMIT"
        );
        for (uint256 index = 0; index < _conditions.length; index++) {
            _claim(_conditions[index]);
        }
    }

    function _claim(uint256 _conditionIndex) internal {
        //get total both token balance
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

        uint256 highBetBalance = IBetToken(highBetToken).balanceOf(
            address(this)
        );
        uint256 lowBetBalance = IBetToken(lowBetToken).balanceOf(address(this));

        (uint256 amountClaimed, uint8 winningSide) = predictionMarket.claim(
            _conditionIndex
        );

        //get all bet Id with this index
        uint256[] memory betIds = marketToBets[_conditionIndex];

        uint256 multiplier = winningSide == 0
            ? (amountClaimed * (1e18)) / lowBetBalance
            : (amountClaimed * (1e18)) / highBetBalance;

        uint256 betFundClaimed;
        for (uint256 index = 0; index < betIds.length; index++) {
            Bet memory oldBet = bets[index];
            if (oldBet.side == winningSide) {
                oldBet.claimAmount = (oldBet.betAmount * multiplier) / 1e18;
                betFundClaimed += oldBet.betAmount;
            }
        }

        totalBetFunds += betFundClaimed;

        //add event
        emit BetClaimed(_conditionIndex, winningSide, amountClaimed);
    }

    //********************************************************************* */
    // //unfollow is subjected to fund availability
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

    // function removeTraderFund() public onlyTrader {
    //     if (status == StrategyStatus.ACTIVE) status = StrategyStatus.INACTIVE;
    //     uint256 amount = getClaimAmount();
    //     traderFund -= amount;
    //     trader.transfer(amount);
    // }

    // // for getting Trader claim amount
    // function getClaimAmount()
    //     internal
    //     view
    //     returns (uint256 traderClaimAmount)
    // {
    //     uint256 traderTotalProfit;
    //     uint256 traderTotalLoss;
    //     for (uint256 cpIndex = 0; cpIndex < latestCheckpointId; cpIndex++) {
    //         Checkpoint memory cp = checkpoints[cpIndex];
    //         uint256 traderProfit = (cp.totalProfit * traderFund) /
    //             cp.totalVolume;
    //         traderTotalLoss += (cp.totalLoss * traderFund) / cp.totalVolume;

    //         uint256 userProfit = cp.totalProfit - traderProfit;
    //         traderTotalProfit += traderProfit + calculateFees(userProfit);
    //     }
    //     traderClaimAmount = traderFund + traderTotalProfit - traderTotalLoss;
    // }

    // //fuction to calculate fees
    // function calculateFees(uint256 amount)
    //     internal
    //     view
    //     returns (uint256 feeAmount)
    // {
    //     feeAmount = (amount * traderFees) / 10000;
    // }
}
