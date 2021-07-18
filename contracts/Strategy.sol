//SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.0;

import "./interfaces/IBetToken.sol";
import "./Checkpoint.sol";

contract Strategy is Checkpoint {
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
    ) {
        require(
            _trader != address(0),
            "Strategy::constructor:INVALID TRADER ADDRESS."
        );
        require(
            _predictionMarket != address(0),
            "Strategy::constructor:INVALID PREDICTION MARKET ADDRESS."
        );
        predictionMarket = IPredictionMarket(_predictionMarket);
        strategyName = _name;
        trader = _trader;

        status = StrategyStatus.ACTIVE;
    }

    function follow() public payable isStrategyActive {
        User storage user = userInfo[msg.sender];

        require(msg.value > 0, "Strategy::addUserFund: ZERO_FUNDS");
        require(
            user.depositAmount == 0,
            "Strategy::addUserFund: ALREADY_FOLLOWING"
        );

        totalUserFunds += msg.value;

        user.depositAmount = msg.value;
        users.push(msg.sender);

        //get total volume (trader + all users)
        addCheckpoint(users, (totalUserFunds + traderFund));
        user.entryCheckpointId = latestCheckpointId;

        //event
    }

    //unfollow is subjected to fund availability
    function unfollow() public onlyUser {
        User storage user = userInfo[msg.sender];

        //update checkpoint
        uint256 checkpoint;
        // user.amount -= _amount;
        // user.exitCheckpointId = checkpoint;

        //apply checks
        // (msg.sender).transfer(_amount);

        //event
    }

    //to be shifted to constructor and removed
    function addTraderFund() public payable onlyTrader isStrategyActive {
        require(msg.value > 0, "Strategy::addTraderFund: ZERO_FUNDS");
        traderFund += msg.value;
    }

    function removeTraderFund() public onlyTrader {
        if (status == StrategyStatus.ACTIVE) status = StrategyStatus.INACTIVE;
        uint256 amount; // = getClaimAmount();
        traderFund -= amount;
        trader.transfer(amount);
    }

    //only if a user or checkpoint exists
    function bet(
        uint256 _conditionIndex,
        uint8 _side,
        uint256 _amount
    ) public isStrategyActive onlyTrader {
        //require _amount <= 5% of total trader fund
        //calculate fund

        Checkpoint memory checkpoint = checkpoints[latestCheckpointId];
        checkpoint.totalInvested += _amount;
        conditionIndexToCheckpoints[_conditionIndex].push(latestCheckpointId);

        Market memory market;
        if (_side == 0) {
            market.lowBets = _amount;
        } else {
            market.highBets = _amount;
        }
        markets[latestCheckpointId][_conditionIndex] = market;
    }

    function claim(uint256 _conditionIndex) public isStrategyActive onlyTrader {
        //todo: return following in prediction market
        //todo: adjust perBetPrice for decimals
        (bool winner, uint256 perBetPrice) = predictionMarket.claim(
            _conditionIndex
        );

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

            if (winner && market.highBets > 0) {
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
}
