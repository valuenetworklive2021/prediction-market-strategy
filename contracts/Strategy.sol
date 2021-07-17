pragma solidity 0.8.0;

import "./interfaces/IPredictionMarket.sol";
import "./Checkpoint.sol";

contract Strategy is Checkpoint {
    IPredictionMarket public predictionMarket;
    address public trader;
    uint256 public traderFund;
    string public strategyName;

    enum StrategyStatus {
        ACTIVE,
        INACTIVE
    }

    struct User {
        uint256 amount;
        uint256 entryCheckpointId;
        uint256 exitCheckpointId;
    }

    mapping(address => User) public userInfo;

    uint256 latestCheckpointId;

    StrategyStatus public status;

    //to get list of users
    address[] public users;
    uint256[] public userAmounts;

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
        uint256[] memory markets;
        uint256 checkpoint = addCheckpoint(latestCheckpointId, userAmounts, users, 0,0,0,0, markets);

        user.amount = msg.value;
        user.entryCheckpointId = checkpoint;

        users.push(msg.sender);

        //event
    }

    //unfollow is subjected to fund availability
    function unfollow(uint256 _amount) public {
        User storage user = userInfo[msg.sender];

        require(
            _amount > 0 && _amount <= user.amount,
            "Strategy::removeUserFund:INVALID AMOUNT."
        );

        //check if can claim
        //update checkpoint
        uint256 checkpoint;
        user.amount -= _amount;
        user.exitCheckpointId = checkpoint;

        //apply checks
        (msg.sender).transfer(_amount);

        //event
    }

    

    function addTraderFund() public payable onlyTrader {
        require(msg.value > 0, "Strategy::addTraderFund: ZERO_FUNDS");
        traderFund += msg.value;
    }

    function removeTraderFund(uint256 _amount) public onlyTrader {
        require(
            _amount > 0 && _amount <= traderFund,
            "Strategy::removeUserFund:INVALID AMOUNT."
        );

        if (_amount == traderFund) {
            status = StrategyStatus.INACTIVE;
        }

        traderFund -= _amount;
        (msg.sender).transfer(_amount);
    }

    //only if a user or checkpoint exists
    function placeBet(
        uint256 _conditionIndex,
        uint8 _side,
        uint256 _amount
    ) public isStrategyActive onlyTrader {}

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
