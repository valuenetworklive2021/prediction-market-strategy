//SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.0;

import "./interfaces/IPredictionMarket.sol";
import "./interfaces/IStrategyFactory.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract StrategyStorage {
    //strategy details
    StrategyStatus public status;
    IStrategyFactory public strategyFactory;

    uint256 internal constant PERCENTAGE_MULTIPLIER = 10000;
    uint256 internal constant MAX_BET_PERCENTAGE = 50000;

    string public strategyName;
    address payable public trader;
    address payable public operator;
    uint256 public initialTraderFunds;
    uint256 public traderClaimedAmount;

    uint256 public userPortfolio;
    uint256 public traderPortfolio;

    uint256 public depositPeriod;
    uint256 public tradingPeriod;

    //Fees Percentage
    //PERCENTAGE_MULTIPLIER decimals
    uint256 public constant FEE_PERCENTAGE = 2000; // 20%
    uint256 public traderFees;
    bool isFeeClaimed;

    enum StrategyStatus {
        ACTIVE,
        INACTIVE
    }

    uint256 public totalUserActiveMarkets;
    uint256 public totalTraderActiveMarkets;
    uint256 public totalUserFunds;
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

    //user details]
    uint256 public totalUsers;
    mapping(address => User) public userInfo;
    mapping(uint256 => Market) public markets;
    //conditionIndex -> 1 -> users
    //conditionIndex -> 0 -> trader
    mapping(uint256 => mapping(uint8 => bool)) public isBetPlaced;

    event StrategyFollowed(address follower, uint256 amount);
    event StrategyUnfollowed(
        address follower,
        uint256 amountClaimed,
        string unfollowType
    );
    event BetPlaced(uint256 conditionIndex, uint8 side, uint256 totalAmount);
    event BetClaimed(
        uint256 conditionIndex,
        uint8 winningSide,
        uint256 amountReceived
    );
    event StrategyInactive();
    event TraderClaimed(uint256 amountClaimed);
    event TraderFeeClaimed(uint256 traderFees);
    event AddedTraderFunds(address trader, uint256 amount);
}
