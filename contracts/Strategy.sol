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
        string memory _name,
        address payable _trader,
        uint256 _depositPeriod, //time remaining from now
        uint256 _tradingPeriod, //deposit time + trading period
        address payable _operator
    ) payable {
        require(
            _trader != address(0),
            "Strategy::constructor:INVALID TRADER ADDRESS."
        );

        require(msg.value > 0, "Strategy::constructor: ZERO_FUNDS");

        strategyFactory = IStrategyFactory(msg.sender);
        strategyName = _name;
        trader = _trader;
        initialTraderFunds = msg.value;
        traderPortfolio = msg.value;
        operator = _operator;

        depositPeriod = block.timestamp + _depositPeriod;
        tradingPeriod = depositPeriod + _tradingPeriod;
        status = StrategyStatus.ACTIVE;
    }

    function follow() external payable isStrategyActive inDepositPeriod {
        User storage user = userInfo[msg.sender];

        require(msg.value > 0, "Strategy::follow: ZERO_FUNDS");
        require(user.depositAmount == 0, "Strategy::follow: ALREADY_FOLLOWING");

        totalUserFunds += msg.value;
        totalUsers++;
        userPortfolio = totalUserFunds;
        user.depositAmount = msg.value;

        emit StrategyFollowed(msg.sender, msg.value);
    }

    function deposit()
        external
        payable
        isStrategyActive
        inDepositPeriod
        onlyTrader
    {
        require(msg.value > 0, "Strategy::deposit: ZERO_FUNDS");

        initialTraderFunds += msg.value;
        traderPortfolio += msg.value;
        emit AddedTraderFunds(msg.sender, msg.value);
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

        _getPredictionMarket().betOnCondition{value: betAmount}(
            _conditionIndex,
            _side
        );

        emit BetPlaced(_conditionIndex, _side, betAmount);
    }

    //0 - deposit and claiming period
    //1 - trading
    function _updateActiveMarkets(uint256 _conditionIndex, uint8 _scenario)
        internal
    {
        if (_scenario == 1) {
            if (!isBetPlaced[_conditionIndex][1]) {
                isBetPlaced[_conditionIndex][1] = true;
                totalUserActiveMarkets++;
            }
        }
        if (!isBetPlaced[_conditionIndex][0]) {
            isBetPlaced[_conditionIndex][0] = true;
            totalTraderActiveMarkets++;
        }
    }

    function _betInDepositPeriod(
        uint256 _amount,
        uint8 _side,
        uint256 _conditionIndex
    ) internal returns (uint256 betAmount) {
        betAmount = _amount;
        traderPortfolio -= _amount;

        Market storage market = markets[_conditionIndex];
        if (_side == 0) {
            market.traderLowBets += _amount;
        } else {
            market.traderHighBets += _amount;
        }

        _updateActiveMarkets(_conditionIndex, 0);
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

        Market storage market = markets[_conditionIndex];
        if (_side == 0) {
            market.userLowBets += betAmount;
            market.traderLowBets += _amount;
        } else {
            market.userHighBets += betAmount;
            market.traderHighBets += _amount;
        }

        _updateActiveMarkets(_conditionIndex, 1);
        betAmount += _amount;
    }

    function _getBetAmount(uint256 _amount)
        internal
        view
        returns (uint256 betAmount)
    {
        uint256 percentage = _getPercentage(_amount);
        require(
            percentage < strategyFactory.maxBetPercentage(),
            "Strategy::placeBet:: AMOUNT_EXCEEDS_MAX_BET_PERCENTAGE"
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
        percentage = (_amount * 100 * PERCENTAGE_MULTIPLIER) / traderPortfolio;
    }

    /**--------------------------BET CLAIM RELATED FUNCTIONS-------------------------- */
    function claimBet(uint256 _conditionIndex) external {
        Market storage market = markets[_conditionIndex];
        require(
            isBetPlaced[_conditionIndex][0] || isBetPlaced[_conditionIndex][1],
            "Strategy:claimBet:: NO_BETS"
        );
        require(
            _isMarketSettled(_conditionIndex),
            "Strategy:claimBet:: MARKET_ACTIVE"
        );
        require(!market.isClaimed, "Strategy:claimBet:: ALREADY_CLAIMED");

        uint256 totalLowBets = market.userLowBets + market.traderLowBets;
        uint256 totalHighBets = market.userHighBets + market.traderHighBets;
        if (totalLowBets == 0 && totalHighBets == 0) return;

        if (isBetPlaced[_conditionIndex][1]) totalUserActiveMarkets--;
        totalTraderActiveMarkets--;
        market.isClaimed = true;

        uint256 initialAmount = address(this).balance;
        _getPredictionMarket().claim(_conditionIndex);
        market.amountClaimed = address(this).balance - initialAmount;

        uint8 winningSide = _getWinningSide(_conditionIndex);

        uint256 userClaim;
        if (winningSide == 1) {
            userClaim = _updatePortfolio(
                market.amountClaimed,
                totalHighBets,
                market.userHighBets
            );
        } else {
            userClaim = _updatePortfolio(
                market.amountClaimed,
                totalLowBets,
                market.userLowBets
            );
        }

        emit BetClaimed(_conditionIndex, winningSide, userClaim);
    }

    function _updatePortfolio(
        uint256 _amountClaimed,
        uint256 _totalBets,
        uint256 _userBets
    ) internal returns (uint256 userClaim) {
        if (_totalBets == 0) return 0;
        userClaim = (_amountClaimed * _userBets) / _totalBets;
        userPortfolio += userClaim;
        traderPortfolio += (_amountClaimed - userClaim);
    }

    function _getPredictionMarket()
        internal
        view
        returns (IPredictionMarket predictionMarket)
    {
        predictionMarket = IPredictionMarket(
            strategyFactory.predictionMarket()
        );
    }

    /**--------------------------MARKET RELATED VIEW FUNCTIONS-------------------------- */
    function _isMarketSettled(uint256 _conditionIndex)
        internal
        view
        returns (bool)
    {
        (, , , uint256 settlementTime, , , , , , ) = _getPredictionMarket()
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

        ) = _getPredictionMarket().conditions(_conditionIndex);
        if (triggerPrice >= settledPrice) return 0;
        return 1;
    }

    /**--------------------------UNFOLLOW AND CLAIMS-------------------------- */
    function unfollow() external onlyUser {
        require(
            depositPeriod >= block.timestamp || tradingPeriod < block.timestamp,
            "Strategy:unfollow:: CANNOT_CLAIM_IN_TRADING_PERIOD"
        );

        if (depositPeriod >= block.timestamp) {
            _returnUserFunds();
        } else {
            _unfollow();
        }
    }

    function _returnUserFunds() internal {
        User storage user = userInfo[msg.sender];
        require(user.depositAmount != 0, "Strategy:unfollow:: ALREADY_CLAIMED");

        uint256 toClaim = getUserClaimAmount(msg.sender);
        totalUserFunds -= user.depositAmount;
        userPortfolio = totalUserFunds;
        user.depositAmount = 0;

        payable(msg.sender).transfer(toClaim);
        emit StrategyUnfollowed(msg.sender, toClaim, "BEFORE_TRADE");
    }

    function _unfollow() internal {
        require(
            totalUserActiveMarkets == 0,
            "Strategy:unfollow:: MARKET_ACTIVE"
        );
        User storage user = userInfo[msg.sender];
        require(!user.exited, "Strategy:unfollow:: ALREADY_CLAIMED");

        uint256 toClaim = getUserClaimAmount(msg.sender);
        user.exited = true;
        user.claimedAmount = toClaim;
        payable(msg.sender).transfer(toClaim);

        emit StrategyUnfollowed(msg.sender, toClaim, "AFTER_TRADE");
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
            fees = (userPortfolio * FEE_PERCENTAGE) / PERCENTAGE_MULTIPLIER;
        }
    }

    function removeTraderFund() external tradingPeriodEnded onlyTrader {
        require(
            totalTraderActiveMarkets == 0,
            "Strategy:removeTraderFund:: MARKET_ACTIVE"
        );
        require(
            traderClaimedAmount == 0,
            "Strategy:removeTraderFund:: ALREADY_CLAIMED"
        );
        traderClaimedAmount = traderPortfolio;
        traderPortfolio = 0;
        initialTraderFunds = 0;

        status = StrategyStatus.INACTIVE;

        _claimFee();
        _transferETH(trader, traderFees + traderClaimedAmount);

        emit StrategyInactive();
        emit TraderFeeClaimed(traderFees);
        emit TraderClaimed(traderClaimedAmount);
    }

    // function claimFees() public onlyTrader {
    //     require(
    //         totalUserActiveMarkets == 0,
    //         "Strategy:removeTraderFund:: MARKET_ACTIVE"
    //     );
    //     _claimFee();
    // }

    function _claimFee() internal {
        require(!isFeeClaimed, "Strategy:claimFees:: ALREADY_CLAIMED");
        isFeeClaimed = true;
        traderFees = getTraderFees();
    }

    function _transferETH(address payable _to, uint256 _amount) internal {
        require(
            address(this).balance >= _amount,
            "Strategy:_transferETH:: AMOUNT_EXCEED_STRATEGY_BALANCE"
        );
        _to.transfer(_amount);
    }

    function inCaseTokensGetStuck(address _token) external {
        require(
            operator == msg.sender,
            "Strategy:inCaseTokensGetStuck:: INVALID_OPERATOR"
        );
        if (_token != address(0)) {
            IERC20 token = IERC20(_token);
            token.transfer(operator, token.balanceOf(address(this)));
        } else {
            operator.transfer(address(this).balance);
            status = StrategyStatus.INACTIVE;
            emit StrategyInactive();
        }
    }

    receive() external payable {
        require(
            address(_getPredictionMarket()) == msg.sender,
            "Strategy:receive:: INVALID_ETH_SOURCE"
        );
    }
}
