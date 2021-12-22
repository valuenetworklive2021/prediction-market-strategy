//SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.0;

import "./Strategy.sol";

contract StrategyFactory {
    address public predictionMarket;
    address payable public operator;
    uint256 public strategyID;
    uint256 public maxBetPercentage = 200000;
    uint256 public constant PERCENTAGE_MULTIPLIER = 10000;

    //strategyID -> strategy
    mapping(uint256 => address) public strategies;
    mapping(address => uint256[]) public traderStrategies;
    mapping(address => bool) public isStrategy;

    event StartegyCreated(
        address traderAddress,
        string strategyName,
        uint256 id,
        uint256 amount,
        address strategyAddress
    );
    event UpdatedMaxBetPercentage(uint256 _maxBetPercentage);

    constructor(address _predictionMarket) {
        require(
            _predictionMarket != address(0),
            "StrategyFactory::constructor: INVALID_PREDICTION_MARKET_ADDRESS."
        );
        predictionMarket = _predictionMarket;
        operator = payable(msg.sender);
    }

    function updateMaxBetPercentage(uint256 _maxBetPercentage) external {
        require(
            msg.sender == operator,
            "StrategyFactory:updatePredictionMarket:: INVALID_SENDER"
        );
        require(
            _maxBetPercentage > 0 && _maxBetPercentage < 1000000,
            "Strategy::deposit: ZERO_FUNDS"
        );

        maxBetPercentage = _maxBetPercentage;
        emit UpdatedMaxBetPercentage(_maxBetPercentage);
    }

    function updatePredictionMarket(address _predictionMarket) external {
        require(
            msg.sender == operator,
            "StrategyFactory:updatePredictionMarket:: INVALID_SENDER"
        );
        require(
            _predictionMarket != address(0) ||
                _predictionMarket != predictionMarket,
            "StrategyFactory:updatePredictionMarket:: INVALID_ADDRESS"
        );
        predictionMarket = _predictionMarket;
    }

    function createStrategy(
        string memory _name,
        uint256 _depositPeriod,
        uint256 _tradingPeriod
    ) external payable {
        require(
            msg.value > 0,
            "StrategyFactory::createStrategy: ZERO_DEPOSIT_FUND"
        );

        strategyID = strategyID + 1;
        traderStrategies[msg.sender].push(strategyID);

        Strategy strategy = new Strategy{value: msg.value}(
            _name,
            payable(msg.sender),
            _depositPeriod,
            _tradingPeriod,
            operator
        );
        strategies[strategyID] = address(strategy);
        isStrategy[address(strategy)] = true;

        emit StartegyCreated(
            msg.sender,
            _name,
            strategyID,
            msg.value,
            address(strategy)
        );
    }
}
