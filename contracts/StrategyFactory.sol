//SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.0;

import "./Strategy.sol";

contract StrategyFactory {
    IPredictionMarket public predictionMarket;
    uint256 public traderId;

    mapping(address => uint256[]) public traderStrategies;

    event CreateStrategy(string trader, uint256 id, uint256 amount);

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

        //todo: merge below 2 steps into one (add funds in constructor) and remove addTraderFund from here and strategy
        Strategy strategy = new Strategy(
            address(predictionMarket),
            _name,
            payable(msg.sender)
        );
        strategy.addTraderFund{value: msg.value}();

        emit CreateStrategy(_name, traderId, msg.value);

        return traderId;
    }
}
