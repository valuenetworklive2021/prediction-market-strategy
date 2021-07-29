//SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.0;

import "./Strategy.sol";

contract StrategyFactory {
    IPredictionMarket public predictionMarket;
    uint256 public traderId;

    mapping(address => uint256[]) public traderStrategies;

    event CreateStrategy(
        address traderAddress,
        string traderName,
        uint256 id,
        uint256 amount,
        address strategyAddress
    );

    constructor(address _predictionMarket) {
        require(
            _predictionMarket != address(0),
            "StrategyFactory::constructor:INVALID PRDICTION MARKET ADDRESS."
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

        traderId = traderId + 1;
        traderStrategies[msg.sender].push(traderId);

        Strategy strategy = new Strategy{value: msg.value}(
            address(predictionMarket),
            _name,
            payable(msg.sender)
        );
        emit CreateStrategy(
            msg.sender,
            _name,
            traderId,
            msg.value,
            address(strategy)
        );

        return traderId;
    }
}
