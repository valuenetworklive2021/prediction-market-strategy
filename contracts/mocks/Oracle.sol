//SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.0;

import "./AggregatorV3Interface.sol";

contract Oracle is AggregatorV3Interface{
    uint8 public override decimals = 8;
    // function decimals() external view returns (uint8){
    //     return (8);
    // };
    string public override description = "BTC/USD";

    // function description() external view returns (string memory);
    
    uint256 public override version = 3;

    // function version() external view returns (uint256);

    // getRoundData and latestRoundData should both raise "No data present"
    // if they do not have data to report, instead of returning unset values
    // which could be misinterpreted as actual reported values.
    function getRoundData(uint80 _roundId)
        external
        view
        override
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        ){
            roundId = 1;
            answer = 5000000000000;
             startedAt = 16279090;
             updatedAt = 16289090;
            answeredInRound = 10;
        }

    function latestRoundData()
        external
        view
        override
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        ){
            roundId = 1;
            answer = 5000000000000;
             startedAt = 16279090;
             updatedAt = 16289090;
            answeredInRound = 10;
        }
}