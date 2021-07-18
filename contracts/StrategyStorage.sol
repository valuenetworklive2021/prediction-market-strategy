pragma solidity 0.8.0;

contract StrategyStorage {
    enum StrategyStatus {
        ACTIVE,
        INACTIVE
    }

    struct User {
        uint256 depositAmount;
        uint256 entryCheckpointId;
        uint256 exitCheckpointId;
        uint256 totalProfit;
        uint256 totalLoss;
        bool exited;
        uint256 remainingClaim;
        //totalClaimed = amount + profit - loss
    }

    //strategy details
    StrategyStatus public status;
    IPredictionMarket public predictionMarket;
    address public trader;
    string public strategyName;
    uint256 public traderFund;
    uint256 latestCheckpointId;

    //user details
    mapping(address => User) public userInfo;

    //to get list of users
    address[] public users;
    uint256[] public userAmounts;

    uint256 totalUserFunds;

    struct Checkpoint {
        address[] users;
        uint256 totalVolume;
        uint256 totalInvested;
        uint256 totalProfit;
        uint256 totalLoss;
        uint256[] markets;
    }

    mapping(uint256 => Checkpoint) public checkpoints;

    mapping(uint256 => uint256[]) public marketToCheckpoint;
}
