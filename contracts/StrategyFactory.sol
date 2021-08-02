//SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.0;

import "./Strategy.sol";

contract StrategyFactory {
    IPredictionMarket public predictionMarket;
    uint256 public strategyID;

    mapping(address => uint256[]) public traderStrategies;
    //strategyID -> strategy
    mapping(uint256 => address) public strategies;

    event StartegyCreated(
        address traderAddress,
        string traderName,
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
    }

    function createStrategy(string memory _name)
        external
        payable
        returns (uint256)
    {
        require(
            msg.value > 0,
            "StrategyFactory::createStrategy: ZERO_DEPOSIT_FUND"
        );

        strategyID = strategyID + 1;
        traderStrategies[msg.sender].push(strategyID);

        Strategy strategy = new Strategy{value: msg.value}(
            address(predictionMarket),
            _name,
            payable(msg.sender)
        );
        strategies[strategyID] = address(strategy);

        emit StartegyCreated(
            msg.sender,
            _name,
            strategyID,
            msg.value,
            address(strategy)
        );
        return strategyID;
    }
}
