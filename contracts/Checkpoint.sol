//SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.0;

import "./StrategyStorage.sol";

contract Checkpoint is StrategyStorage {
    function addCheckpoint(address[] memory _users, uint256 _totalVolume)
        internal
    {
        Checkpoint storage newCheckpoint = checkpoints[latestCheckpointId++];
        newCheckpoint.users = _users;
        newCheckpoint.totalVolume = _totalVolume;
        //get amount from userInfo struct through user address
    }

    function updateCheckpoint(
        uint256 _checkpointId,
        uint256 _totalInvestedChange,
        uint256 _totalProfitChange,
        uint256 _totalLossChange,
        uint256 marketToAdd
    ) internal returns (uint256) {
        Checkpoint storage existingCheckpoint = checkpoints[_checkpointId];
        existingCheckpoint.totalInvested += _totalInvestedChange;
        existingCheckpoint.totalProfit += _totalProfitChange;
        existingCheckpoint.totalLoss += _totalLossChange;
    }
}
