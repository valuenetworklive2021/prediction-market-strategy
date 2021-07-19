//SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.0;

import "./interfaces/IPredictionMarket.sol";

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
    address payable public trader;
    string public strategyName;
    uint256 public traderFund;

    uint256 latestCheckpointId;

    //user details
    mapping(address => User) public userInfo;

    //to get list of users
    address[] public users;
    uint256[] public userAmounts;

    uint256 totalUserFunds;

    //Fees Percentage
    uint256 public traderFees;

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

    mapping(uint256 => Checkpoint) public checkpoints;

    //maps checkpoint -> conditionindex -> market
    mapping(uint256 => mapping(uint256 => Market)) public markets;
    mapping(uint256 => uint256[]) public conditionIndexToCheckpoints;
}
