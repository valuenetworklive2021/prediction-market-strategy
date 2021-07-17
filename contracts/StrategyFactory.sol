pragma solidity 0.8.0;

import "./Strategy.sol";

contract StrategyFactory {
    IPredictionMarket public predictionMarket;
    uint256 public traderId;

    mapping(address => uint256[]) public traderStrategies;

    //event CreateStrategy (trader, id, amount)

    constructor(address _predictionMarket) {
        //check zero address
        predictionMarket = IPredictionMarket(_predictionMarket);
    }

    function createStrategy(string memory _name)
        external
        payable
        returns (uint256)
    {
        require(
            msg.value > 0,
            "StrategyRegistry::createStrategy: ZERO_DEPOSIT_FUND"
        );

        traderId = traderId + 1;
        traderStrategies[msg.sender].push(traderId);

        Strategy strategy = new Strategy(_predictionMarket, _name, msg.sender);
        strategy.addTraderFund{value: msg.value}();

        //emit event

        return traderId;
    }
}
