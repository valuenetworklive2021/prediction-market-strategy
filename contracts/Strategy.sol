pragma solidity 0.8.0;

import "./interfaces/IPredictionMarket.sol";
import "./interfaces/IBetToken.sol";
import "./Checkpoint.sol";

contract Strategy is Checkpoint {
    struct User {
        uint256 depositAmount;
        uint256 entryCheckpointId;
        uint256 exitCheckpointId;
        uint256 totalProfit;
        uint256 totalLoss;
        bool exited;
        uint256 remainingClaim;
        //totalClaimed = amount + profit - loss
    }

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
        address _trader
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
        require(user.amount == 0, "Strategy::addUserFund: ALREADY_FOLLOWING");

        totalUserFunds += msg.value;

        user.amount = msg.value;
        users.push(msg.sender);

        //get total volume (trader + all users)
        uint256 checkpoint = addCheckpoint(users, totalVolume);
        user.entryCheckpointId = checkpoint;

        //event
    }

    //unfollow is subjected to fund availability
    function unfollow() public onlyUser {
        User storage user = userInfo[msg.sender];

        //update checkpoint
        uint256 checkpoint;
        user.amount -= _amount;
        user.exitCheckpointId = checkpoint;

        //apply checks
        (msg.sender).transfer(_amount);

        //event
    }

    //to be shifted to constructor and removed
    function addTraderFund() public payable onlyTrader isStrategyActive {
        require(msg.value > 0, "Strategy::addTraderFund: ZERO_FUNDS");
        traderFund += msg.value;
    }

    function removeTraderFund() public onlyTrader {
        if (status == StrategyStatus.ACTIVE) status = StrategyStatus.INACTIVE;
        uint256 amount = getClaimAmount();
        traderFund -= amount;
        (msg.sender).transfer(amount);
    }

    //only if a user or checkpoint exists
    function bet(
        uint256 _conditionIndex,
        uint8 _side,
        uint256 _amount
    ) public isStrategyActive onlyTrader {
        //require _amount <= 5% of total trader fund
        //calculate fund
    }

    function claim(uint256 _conditionIndex) public isStrategyActive onlyTrader {
        address lowBetToken;
        address highBetToken;
        (, , , , , , lowBetToken, highBetToken, , ) = predictionMarket
        .conditions(_conditionIndex);

        IBetToken highBet = IBetToken(highBetToken);
        IBetToken lowBet = IBetToken(lowBetToken);
        predictionMarket.claim(_conditionIndex);

        uint256[] _checkpoints = marketToCheckpoint[_conditionIndex];
        for (uint256 index = 0; index < _checkpoints.length; index++) {
            //update total profit and loss according to the invested amount
            //increase total vol in latest checkpoint accordingly
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
