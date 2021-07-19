//SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.0;

import "./AggregatorV3Interface.sol";
import "./BetToken.sol";
import "../interfaces/IPredictionMarket.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract PredictionMarket is IPredictionMarket {
    using SafeMath for uint256;

    AggregatorV3Interface internal priceFeed;

    uint256 public latestConditionIndex;
    address payable public owner;

    mapping(uint256 => ConditionInfo) public override conditions;

    struct ConditionInfo {
        string market;
        address oracle;
        int256 triggerPrice;
        uint256 settlementTime;
        bool isSettled;
        int256 settledPrice;
        address lowBetToken;
        address highBetToken;
        uint256 totalStakedAbove;
        uint256 totalStakedBelow;
    }

   
    modifier onlyOwner() {
        require(msg.sender == owner, "Not Owner");
        _;
    }

    constructor() {
        owner = payable(msg.sender);
    }

    function prepareCondition(
        address _oracle,
        uint256 _settlementTime,
        int256 _triggerPrice,
        string memory _market
    ) external override onlyOwner {
        require(_oracle != address(0), "Can't be 0 address");
        require(
            _settlementTime > block.timestamp,
            "Settlement Time should be greater than Trx Confirmed Time"
        );
        latestConditionIndex = latestConditionIndex.add(1);
        ConditionInfo storage conditionInfo = conditions[latestConditionIndex];

        conditionInfo.market = _market;
        conditionInfo.oracle = _oracle;
        conditionInfo.settlementTime = _settlementTime;
        conditionInfo.triggerPrice = _triggerPrice;
        conditionInfo.isSettled = false;

        conditionInfo.lowBetToken = address(
            new BetToken(
                "Low Bet Token",
                string(abi.encodePacked("LBT-", _market))
            )
        );
        conditionInfo.highBetToken = address(
            new BetToken(
                "High Bet Token",
                string(abi.encodePacked("HBT-", _market))
            )
        );

        emit ConditionPrepared(
            latestConditionIndex,
            _oracle,
            _settlementTime,
            _triggerPrice,
            conditionInfo.lowBetToken,
            conditionInfo.highBetToken
        );
    }

    function probabilityRatio(uint256 _conditionIndex)
        external
        override
        view
        returns (uint256 aboveProbabilityRatio, uint256 belowProbabilityRatio)
    {
        ConditionInfo storage conditionInfo = conditions[_conditionIndex];

        if (conditionInfo.isSettled) {
            return (0, 0);
        }

        uint256 ethStakedForAbove =
            BetToken(conditionInfo.highBetToken).totalSupply();

        uint256 ethStakedForBelow =
            BetToken(conditionInfo.lowBetToken).totalSupply();

        uint256 totalETHStaked = ethStakedForAbove.add(ethStakedForBelow);

        aboveProbabilityRatio = totalETHStaked > 0
            ? ethStakedForAbove.mul(1e18).div(totalETHStaked)
            : 0;
        belowProbabilityRatio = totalETHStaked > 0
            ? ethStakedForBelow.mul(1e18).div(totalETHStaked)
            : 0;
    }

    function userTotalETHStaked(uint256 _conditionIndex, address userAddress)
        public
        override
        view
        returns (uint256 totalEthStaked)
    {
        ConditionInfo storage conditionInfo = conditions[_conditionIndex];
        uint256 ethStakedForAbove =
            BetToken(conditionInfo.highBetToken).balanceOf(userAddress);

        uint256 ethStakedForBelow =
            BetToken(conditionInfo.lowBetToken).balanceOf(userAddress);

        totalEthStaked = ethStakedForAbove.add(ethStakedForBelow);
    }

    function betOnCondition(uint256 _conditionIndex, uint8 _prediction)
        public
        override
        payable
    {
        ConditionInfo storage conditionInfo = conditions[_conditionIndex];
        require(conditionInfo.oracle != address(0), "Condition doesn't exists");
        require(
            block.timestamp < conditionInfo.settlementTime,
            "Cannot bet after Settlement Time"
        );
        uint256 userETHStaked = msg.value;
        require(userETHStaked > 0 wei, "Bet cannot be 0");
        require((_prediction == 0) || (_prediction == 1), "Invalid Prediction"); //prediction = 0 (price will be below), if 1 (price will be above)

        address userAddress = msg.sender;

        if (_prediction == 0) {
            BetToken(conditionInfo.lowBetToken).mint(
                userAddress,
                userETHStaked
            );
        } else {
            BetToken(conditionInfo.highBetToken).mint(
                userAddress,
                userETHStaked
            );
        }
        emit UserPrediction(
            _conditionIndex,
            userAddress,
            userETHStaked,
            _prediction,
            block.timestamp
        );
    }

    function settleCondition(uint256 _conditionIndex) public override {
        ConditionInfo storage conditionInfo = conditions[_conditionIndex];
        require(conditionInfo.oracle != address(0), "Condition doesn't exists");
        require(
            block.timestamp >= conditionInfo.settlementTime,
            "Not before Settlement Time"
        );
        require(!conditionInfo.isSettled, "Condition settled already");

        conditionInfo.isSettled = true;
        conditionInfo.totalStakedAbove = BetToken(conditionInfo.highBetToken)
            .totalSupply();
        conditionInfo.totalStakedBelow = BetToken(conditionInfo.lowBetToken)
            .totalSupply();
        priceFeed = AggregatorV3Interface(conditionInfo.oracle);
        (, int256 latestPrice, , , ) = priceFeed.latestRoundData();
        conditionInfo.settledPrice = latestPrice;
        emit ConditionSettled(_conditionIndex, latestPrice, block.timestamp);
    }

    function claim(uint256 _conditionIndex) public override {
        address payable userAddress = payable(msg.sender);
        (uint8 winningSide,
        uint256 userstake, 
        uint256 totalWinnerRedeemable, 
        uint256 platformFees) = calculateClaimAmount(_conditionIndex);
        owner.transfer(platformFees);
        userAddress.transfer(totalWinnerRedeemable);
        
        emit UserClaimed(_conditionIndex, userAddress, totalWinnerRedeemable);
    }



    //get per user claim amount
    function getPerUserClaimAmount(uint256 _conditionIndex) public override  returns(uint8 , uint256 ){
        address payable userAddress = payable(msg.sender);
        (uint8 winningSide,
        uint256 userstake, 
        uint256 totalWinnerRedeemable, 
        uint256 platformFees) = calculateClaimAmount(_conditionIndex);
        uint256 perBetAmount = (totalWinnerRedeemable - userstake)/userstake;
        return(winningSide, perBetAmount);

    }

    function calculateClaimAmount(uint256 _conditionIndex) public override 
    returns (uint8 winningSide, uint256 userStake, uint256 totalWinnerRedeemable, uint256 platformFees) {
        ConditionInfo storage conditionInfo = conditions[_conditionIndex];
        address payable userAddress = payable(msg.sender);
        BetToken lowBetToken = BetToken(conditionInfo.lowBetToken);
        BetToken highBetToken = BetToken(conditionInfo.highBetToken);

        if (!conditionInfo.isSettled) {
            settleCondition(_conditionIndex);
        }

        // platformFees: remaining 10% will be treated as platformFees
        // totalWinnerRedeemable: Amount Redeemable including winnerRedeemable & user initial Stake

        if (conditionInfo.settledPrice >= conditionInfo.triggerPrice) {
            //Users who predicted above price wins
            winningSide = 1;
            userStake = highBetToken.balanceOf(userAddress);

            highBetToken.burnAll(userAddress);
            lowBetToken.burnAll(userAddress);

            if (userStake == 0) {
                return( 0, 0, 0, 0 );
            }

            (totalWinnerRedeemable, platformFees) = getClaimAmount(
                conditionInfo.totalStakedBelow,
                conditionInfo.totalStakedAbove,
                userStake
            );

            owner.transfer(platformFees);
            userAddress.transfer(totalWinnerRedeemable);
        } else if (conditionInfo.settledPrice < conditionInfo.triggerPrice) {
            //Users who predicted below price wins
            winningSide = 1;
            userStake = lowBetToken.balanceOf(userAddress);

            highBetToken.burnAll(userAddress);
            lowBetToken.burnAll(userAddress);

            if (userStake == 0) {
                return( 0, 0, 0, 0 );
            }

            (totalWinnerRedeemable, platformFees) = getClaimAmount(
                conditionInfo.totalStakedAbove,
                conditionInfo.totalStakedBelow,
                userStake
            );
        }
    }

    //totalPayout - Payout to be distributed among winners(total eth staked by loosing side)
    //winnersTotalETHStaked - total eth staked by the winning side
    function getClaimAmount(
        uint256 totalPayout,
        uint256 winnersTotalETHStaked,
        uint256 userStake
    )
        internal
        pure
        returns (uint256 totalWinnerRedeemable, uint256 platformFees)
    {
        uint256 userProportion = userStake.mul(1e18).div(winnersTotalETHStaked);

        uint256 winnerPayout = totalPayout.mul(userProportion).div(1e18);
        uint256 winnerRedeemable = (winnerPayout.div(1000)).mul(900);
        platformFees = (winnerPayout.div(1000)).mul(100);
        totalWinnerRedeemable = winnerRedeemable.add(userStake);
    }

    function getBalance(uint256 _conditionIndex, address _user)
        external
        view
        override
        returns (uint256 LBTBalance, uint256 HBTBalance)
    {
        ConditionInfo storage condition = conditions[_conditionIndex];
        LBTBalance = BetToken(condition.lowBetToken).balanceOf(_user);
        HBTBalance = BetToken(condition.highBetToken).balanceOf(_user);
    }
}