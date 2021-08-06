//SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.0;

import "./interfaces/IPredictionMarket.sol";

contract StrategyStorage {
    //strategy details
    StrategyStatus public status;
    IPredictionMarket public predictionMarket;

    uint256 internal constant PERCENTAGE_MULTIPLIER = 10000;
    uint256 internal constant MAX_BET_PERCENTAGE = 50000;

    string public strategyName;
    address payable public trader;
    uint256 public initialTraderFunds;
    uint256 public amountClaimed;

    uint256 public userPortfolio;
    uint256 public traderPortfolio;

    uint256 public depositPeriod;
    uint256 public tradingPeriod;

    //Fees Percentage
    //PERCENTAGE_MULTIPLIER decimals
    uint256 public feePercentage;
    uint256 public traderFees;
    bool isFeeClaimed;

    enum StrategyStatus {
        ACTIVE,
        INACTIVE
    }

    uint256 totalActiveMarkets;
    uint256 public totalUserFunds;
    uint256 public availableUserFunds;
    uint256 public availableTraderFunds;

    struct User {
        uint256 depositAmount;
        uint256 claimedAmount;
        bool exited;
    }

    struct Market {
        uint256 userLowBets;
        uint256 userHighBets;
        uint256 traderLowBets;
        uint256 traderHighBets;
        bool isClaimed;
        uint256 amountClaimed;
    }

    //user details
    address[] public users;
    mapping(address => User) public userInfo;
    mapping(uint256 => Market) public markets;
    mapping(uint256 => bool) public isBetPlaced;

    event StrategyFollowed(address follower, uint256 amount);
    event StrategyUnfollowed(address follower, uint256 amountClaimed);
    event BetPlaced(uint256 conditionIndex, uint8 side, uint256 totalAmount);
    event BetClaimed(
        uint256 conditionIndex,
        uint8 winningSide,
        uint256 amountReceived
    );
}
