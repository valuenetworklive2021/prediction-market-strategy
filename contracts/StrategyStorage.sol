//SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.0;

import "./interfaces/IPredictionMarket.sol";

contract StrategyStorage {
    //strategy details
    StrategyStatus public status;
    IPredictionMarket public predictionMarket;
    address payable public trader;
    string public strategyName;
    uint256 public traderFund;
    uint256 public totalUserFunds;
    uint256 public latestCheckpointId;
    //Fees Percentage
    uint256 public traderFees;

    enum StrategyStatus {
        ACTIVE,
        INACTIVE
    }

    struct Checkpoint {
        address[] users;
        uint256 totalVolume;
        uint256 totalInvested;
        uint256 totalProfit;
        uint256 totalLoss;
    }

    struct Market {
        uint256 lowBets;
        uint256 highBets;
    }

    struct User {
        uint256 depositAmount;
        uint256 entryCheckpointId;
        uint256 exitCheckpointId;
        uint256 totalProfit;
        uint256 totalLoss;
        bool exited;
        uint256 remainingClaim;
    }

    //user details
    mapping(address => User) public userInfo;
    mapping(uint256 => Checkpoint) public checkpoints;

    //to get list of users
    address[] public users;
    uint256[] public userAmounts;

    
    //maps checkpoint -> conditionindex -> market
    mapping(uint256 => mapping(uint256 => Market)) public markets;
    mapping(uint256 => uint256[]) public conditionIndexToCheckpoints;
}
