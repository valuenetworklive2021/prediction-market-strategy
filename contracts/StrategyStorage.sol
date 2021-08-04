//SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.0;

import "./interfaces/IPredictionMarket.sol";

contract StrategyStorage {
    //strategy details
    StrategyStatus public status;
    IPredictionMarket public predictionMarket;

    address payable public trader;
    string public strategyName;
    uint256 public traderFunds;

    uint256 public totalBetFunds;
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
        uint256[] initialAmounts;
        uint256[] userAmountAvailable; //used by next checkpoint as initial Amounts
        uint256 totalInvested;
        uint256 totalProfit;
        uint256 totalLoss;
        uint256 totalActiveMarkets;
        bool status; //true - profit, false - loss
        bool isSettled;
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
        uint256[] checkpointsToClaim;
    }

    //user details
    mapping(address => User) public userInfo;
    mapping(uint256 => Checkpoint) public checkpoints;

    //to get list of users
    address[] public users;
    mapping(address => uint256) isUser;
    uint256[] public userAmounts;

    //maps checkpointId -> conditionindex -> market
    mapping(uint256 => mapping(uint256 => Market)) public markets;
    mapping(uint256 => uint256[]) public conditionIndexToCheckpoints;
    //conditionIndex -> isSettled
    mapping(uint256 => bool) isMarketSettled;

    event StrategyFollowed(
        address follower,
        uint256 amount,
        uint256 entryCheckpointId
    );
    event StrategyUnfollowed(
        address follower,
        uint256 amountClaimed,
        //full and partial
        bool claimType,
        uint256 exitCheckpointId
    );
    event BetPlaced(
        uint256 conditionIndex,
        uint8 side,
        uint256 totalAmount,
        uint256 checkpointId
    );
    event BetClaimed(
        uint256 conditionIndex,
        uint8 winningSide,
        uint256 amountReceived
    );
}
