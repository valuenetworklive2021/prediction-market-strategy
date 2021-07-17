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

    
    function addCheckpoint(
        uint256 _latestCheckpointId,
        uint256[] memory _userAmounts,
        address[] memory _users,
        uint256 _totalVolume,
        uint256 _totalInvested,
        uint256 _totalProfit,
        uint256 _totalLoss,
        uint256[] memory _markets) 
        internal 
        returns ( uint256 checkpointId) {
        Checkpoint storage newCheckpoint = Checkpoints[_latestCheckpointId++];
        newCheckpoint.users = _users;
        newCheckpoint.totalVolume = _totalVolume;
        newCheckpoint.totalInvested = _totalInvested;
        newCheckpoint.totalProfit = _totalProfit;
        newCheckpoint.totalLoss = _totalLoss;
        newCheckpoint.markets = _markets;
        for (uint256 i= 0; i< _users.length; i++){
            newCheckpoint.userAmounts[_users[i]] = _userAmounts[i];
        }
        return _latestCheckpointId;
    }


}
