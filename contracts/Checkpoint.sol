pragma solidity 0.8.0;

contract Checkpoint {
    struct Checkpoint {
        mapping(address => uint256) userAmounts;
        address[] users;
        uint256 totalVolume;
        uint256 totalInvested;
        uint256 totalProfit;
        uint256 totalLoss;
        uint256[] markets;
    }

    mapping(uint256 => Checkpoint) public Checkpoints;

    function addCheckpoint() internal returns (uint256) {}

    function updateCheckpoint() internal returns (uint256) {}
}
