//SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.0;

import "./Strategy.sol";

contract StrategyFactory {
    IPredictionMarket public predictionMarket;
    address payable public operator;
    uint256 public strategyID;

    //strategyID -> strategy
    mapping(uint256 => address) public strategies;
    mapping(address => uint256[]) public traderStrategies;

    event StartegyCreated(
        address traderAddress,
        string strategyName,
        uint256 id,
        uint256 amount,
        address strategyAddress
    );

    constructor(address _predictionMarket) {
        require(
            _predictionMarket != address(0),
            "StrategyFactory::constructor: INVALID_PREDICTION_MARKET_ADDRESS."
        );
        predictionMarket = IPredictionMarket(_predictionMarket);
        operator = payable(msg.sender);
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

        emit StartegyCreated(
            msg.sender,
            _name,
            strategyID,
            msg.value,
            address(strategy)
        );
    }
}
