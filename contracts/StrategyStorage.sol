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

    //amount available in strategy which can be invetsed (removes bet applied, profits and losses)
    uint256 public totalBetFunds;

    //Fees Percentage
    uint256 public traderFees;

    enum StrategyStatus {
        ACTIVE,
        INACTIVE
    }

    struct Bet {
        uint256 betAmount;
        uint256 conditionIndex;
        uint8 side;
        uint256[] users;
        uint256[] userAmounts;
        uint256 claimAmount;
    }

    //conditionIndex => betId[]
    mapping(uint256 => uint256[]) public marketToBets;

    //betId => Bet struct
    mapping(uint256 => Bet) public bets;

    struct User {
        uint256 initialdepositAmount;
        uint256 totalProfit;
        uint256 totalLoss;
        bool exited;
        uint256 remainingClaim;
        uint256 firstMarketIndex;
        uint256 exitMarketIndex;
    }

    //user details
    mapping(address => User) public userInfo;

    //to get list of users
    address[] public users;
    // uint256[] public userAmounts;

    //condition indexes
    uint256[] public markets;
}
