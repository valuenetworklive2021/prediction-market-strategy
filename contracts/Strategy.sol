//SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.0;

import "./StrategyStorage.sol";

contract Strategy is StrategyStorage {
    modifier isStrategyActive() {
        require(
            status == StrategyStatus.ACTIVE,
            "Strategy::isStrategyActive: STRATEGY_INACTIVE"
        );
        _;
    }

    modifier onlyTrader() {
        require(msg.sender == trader, "Strategy::onlyTrader: INVALID_TRADER");
        _;
    }

    modifier onlyUser() {
        require(
            userInfo[msg.sender].depositAmount > 0,
            "Strategy::onlyTrader: INVALID_USER"
        );
        _;
    }

    modifier inDepositPeriod() {
        require(
            depositPeriod >= block.timestamp,
            "Strategy: DEPOSIT_PERIOD_ENDED"
        );
        _;
    }

    modifier inTradingPeriod() {
        require(
            tradingPeriod >= block.timestamp && depositPeriod < block.timestamp,
            "Strategy: TRADING_PERIOD_NOT_STARTED"
        );
        _;
    }

    modifier tradingPeriodEnded() {
        require(
            tradingPeriod < block.timestamp,
            "Strategy: TRADING_PERIOD_ACTIVE"
        );
        _;
    }

    constructor(
        address _predictionMarket,
        string memory _name,
        address payable _trader,
        uint256 _depositPeriod, //time remaining from now
        uint256 _tradingPeriod //deposit time + trading period
    ) payable {
        require(
            _trader != address(0),
            "Strategy::constructor:INVALID TRADER ADDRESS."
        );
        require(
            _predictionMarket != address(0),
            "Strategy::constructor:INVALID PREDICTION MARKET ADDRESS."
        );
        require(msg.value > 0, "Strategy::constructor: ZERO_FUNDS");

        predictionMarket = IPredictionMarket(_predictionMarket);
        strategyName = _name;
        trader = _trader;
        initialTraderFunds = msg.value;
        traderPortfolio = msg.value;

        depositPeriod = block.timestamp + _depositPeriod;
        tradingPeriod = depositPeriod + _tradingPeriod;
        status = StrategyStatus.ACTIVE;
    }

    function follow() external payable isStrategyActive inDepositPeriod {
        User storage user = userInfo[msg.sender];

        require(msg.value > 0, "Strategy::follow: ZERO_FUNDS");
        require(user.depositAmount == 0, "Strategy::follow: ALREADY_FOLLOWING");

        totalUserFunds += msg.value;
        userPortfolio = totalUserFunds;
        user.depositAmount = msg.value;

        emit StrategyFollowed(msg.sender, msg.value);
    }

    /**--------------------------BET PLACE RELATED FUNCTIONS-------------------------- */
    function placeBet(
        uint256 _conditionIndex,
        uint8 _side,
        uint256 _amount
    ) external isStrategyActive onlyTrader {
        require(
            !_isMarketSettled(_conditionIndex),
            "Strategy:placeBet:: MARKET_SETTLED"
        );
        require(
            traderPortfolio >= _amount && _amount > 0,
            "Strategy:placeBet:: INVALID_BET_AMOUNT"
        );

        uint256 betAmount;
        if (
            tradingPeriod >= block.timestamp && depositPeriod < block.timestamp
        ) {
            betAmount = _betInTradingPeriod(_amount, _side, _conditionIndex);
        } else {
            betAmount = _betInDepositPeriod(_amount, _side, _conditionIndex);
        }

        if (!isBetPlaced[_conditionIndex]) {
            isBetPlaced[_conditionIndex] = true;
            totalActiveMarkets++;
        }

        predictionMarket.betOnCondition{value: betAmount}(
            _conditionIndex,
            _side
        );

        emit BetPlaced(_conditionIndex, _side, betAmount);
    }

    function _betInDepositPeriod(
        uint256 _amount,
        uint8 _side,
        uint256 _conditionIndex
    ) internal returns (uint256 betAmount) {
        betAmount = _amount;
        traderPortfolio -= _amount;

        Market memory market;
        if (_side == 0) {
            market.traderLowBets += _amount;
        } else {
            market.traderHighBets += _amount;
        }

        markets[_conditionIndex] = market;
    }

    function _betInTradingPeriod(
        uint256 _amount,
        uint8 _side,
        uint256 _conditionIndex
    ) internal inTradingPeriod returns (uint256 betAmount) {
        betAmount = _getBetAmount(_amount);
        require(betAmount <= userPortfolio, "Strategy:placeBet OUT_OF_FUNDS");

        userPortfolio -= betAmount;
        traderPortfolio -= _amount;

        Market memory market;
        if (_side == 0) {
            market.userLowBets += betAmount;
            market.traderLowBets += _amount;
        } else {
            market.userHighBets += betAmount;
            market.traderHighBets += _amount;
        }

        markets[_conditionIndex] = market;
        betAmount += _amount;
    }

    function _getBetAmount(uint256 _amount)
        internal
        view
        returns (uint256 betAmount)
    {
        uint256 percentage = _getPercentage(_amount);
        require(
            percentage < MAX_BET_PERCENTAGE,
            "Strategy::placeBet:: AMOUNT_EXCEEDS_5_PERCENTAGE"
        );
        betAmount =
            (totalUserFunds * percentage) /
            (PERCENTAGE_MULTIPLIER * 100);

        //safety check
        require(betAmount < totalUserFunds);
    }

    function _getPercentage(uint256 _amount)
        internal
        view
        returns (uint256 percentage)
    {
        percentage =
            (_amount * 100 * PERCENTAGE_MULTIPLIER) /
            initialTraderFunds;
    }

    /**--------------------------BET CLAIM RELATED FUNCTIONS-------------------------- */
    function claimBet(uint256 _conditionIndex) external {
        Market storage market = markets[_conditionIndex];

        require(
            _isMarketSettled(_conditionIndex),
            "Strategy:claimBet:: MARKET_ACTIVE"
        );
        require(!market.isClaimed, "Strategy:claimBet:: ALREADY_CLAIMED");

        uint256 totalLowBets = market.userLowBets + market.traderLowBets;
        uint256 totalHighBets = market.userHighBets + market.traderHighBets;
        if (totalLowBets == 0 && totalHighBets == 0) return;

        totalActiveMarkets--;

        uint256 initialAmount = address(this).balance;
        predictionMarket.claim(_conditionIndex);
        uint256 finalAmount = address(this).balance;
        uint256 amountClaimed = 0;
        if (finalAmount != initialAmount)
            amountClaimed = finalAmount - initialAmount;

        market.isClaimed = true;
        market.amountClaimed = amountClaimed;
        uint8 winningSide = _getWinningSide(_conditionIndex);

        uint256 totalBets = winningSide == 1 ? totalHighBets : totalLowBets;
        _updatePortfolio(market, amountClaimed, winningSide, totalBets);

        emit BetClaimed(_conditionIndex, winningSide, market.amountClaimed);
    }

    function _updatePortfolio(
        Market memory _market,
        uint256 _amountClaimed,
        uint8 _winningSide,
        uint256 _totalBets
    ) internal {
        if (_winningSide == 1) {
            userPortfolio +=
                (_amountClaimed * _market.userHighBets) /
                _totalBets;
            traderPortfolio += (_amountClaimed - _market.traderHighBets);
        } else {
            userPortfolio +=
                (_amountClaimed * _market.userLowBets) /
                _totalBets;
            traderPortfolio += (_amountClaimed - _market.traderLowBets);
        }
    }

    /**--------------------------MARKET RELATED VIEW FUNCTIONS-------------------------- */
    function _isMarketSettled(uint256 _conditionIndex)
        internal
        view
        returns (bool)
    {
        (, , , uint256 settlementTime, , , , , , ) = predictionMarket
            .conditions(_conditionIndex);
        if (settlementTime > block.timestamp) return false;
        return true;
    }

    function _getWinningSide(uint256 _conditionIndex)
        internal
        view
        returns (uint8)
    {
        (
            ,
            ,
            int256 triggerPrice,
            ,
            ,
            int256 settledPrice,
            ,
            ,
            ,

        ) = predictionMarket.conditions(_conditionIndex);
        if (triggerPrice >= settledPrice) return 0;
        return 1;
    }

    /**--------------------------UNFOLLOW AND CLAIMS-------------------------- */
    function unfollow() external onlyUser {
        User storage user = userInfo[msg.sender];
        require(totalActiveMarkets == 0, "Strategy:unfollow:: MARKET_ACTIVE");
        require(!user.exited, "Strategy:unfollow:: ALREADY_CLAIMED");

        require(
            depositPeriod >= block.timestamp || tradingPeriod < block.timestamp,
            "Strategy:unfollow:: CANNOT_CLAIM_IN_TRADING_PERIOD"
        );

        uint256 toClaim = getUserClaimAmount(msg.sender);
        user.exited = true;
        user.claimedAmount = toClaim;
        payable(msg.sender).transfer(toClaim);

        emit StrategyUnfollowed(msg.sender, toClaim);
    }

    function getUserClaimAmount(address _user)
        public
        view
        returns (uint256 amount)
    {
        User memory userDetails = userInfo[_user];
        if (userPortfolio > totalUserFunds) {
            uint256 profit = ((userPortfolio - getTraderFees()) *
                userDetails.depositAmount) / totalUserFunds;

            amount = userDetails.depositAmount + profit;
        } else if (userPortfolio == totalUserFunds) {
            amount = userDetails.depositAmount;
        } else {
            uint256 loss = (userPortfolio * userDetails.depositAmount) /
                totalUserFunds;

            amount = userDetails.depositAmount - loss;
        }
    }

    function getTraderFees() public view returns (uint256 fees) {
        fees = 0;
        if (userPortfolio > totalUserFunds) {
            fees = (userPortfolio * feePercentage) / PERCENTAGE_MULTIPLIER;
        }
    }

    function removeTraderFund() external tradingPeriodEnded onlyTrader {
        require(
            totalActiveMarkets == 0,
            "Strategy:removeTraderFund:: MARKET_ACTIVE"
        );
        require(
            amountClaimed == 0,
            "Strategy:removeTraderFund:: ALREADY_CLAIMED"
        );
        amountClaimed = traderPortfolio;
        traderPortfolio = 0;
        initialTraderFunds = 0;

        status = StrategyStatus.INACTIVE;

        trader.transfer(amountClaimed);

        emit StrategyInactive();
        emit TraderClaimed(amountClaimed);
    }

    function claimFees() external onlyTrader {
        require(!isFeeClaimed, "Strategy:claimFees:: ALREADY_CLAIMED");
        isFeeClaimed = true;
        traderFees = getTraderFees();

        trader.transfer(traderFees);
        emit TraderFeeClaimed(traderFees);
    }

    function inCaseTokensGetStuck(address _token) external onlyOperator {
        if (token != address(0)) {
            IERC20(token).transfer(operator);
        } else {
            operator.transfer(address(this).balance);
            status = StrategyStatus.INACTIVE;
            emit StrategyInactive();
        }
    }
}
