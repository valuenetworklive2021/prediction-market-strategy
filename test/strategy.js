const { expect } = require("chai");
const { ethers } = require("hardhat");

const { BigNumber, utils } = ethers;

const StrategyABI =
  require("../artifacts/contracts/Strategy.sol/Strategy.json").abi;
const BetTokenABI =
  require("../artifacts/contracts/mocks/PredictionMarket.sol/BetToken.json").abi;

describe("Strategy", function () {
  let trader;
  let user1;
  let user2;
  let user3;
  const userInitFunds = [10, 20, 30, 10];
  const traderInitFund = 50; //utils.parseEther("50");
  const DECIMALS = BigNumber.from(10).pow(18);
  const TRIGGER_VALUE = 60000000000;
  const SETTLEMENT_TIME = 300;
  const MARKET = "BTC/USD";
  const STRATEGY_NAME = "S1";

  const firstBetAmount = BigNumber.from(traderInitFund)
    .mul(1)
    .mul(DECIMALS)
    .div(100);
  let totalUserFund = 0;

  const secondBetAmount = BigNumber.from(traderInitFund)
    .mul(2)
    .mul(DECIMALS)
    .div(100);

  let totalFirstBetAmount = BigNumber.from(totalUserFund + traderInitFund)
    .mul(1)
    .mul(DECIMALS)
    .div(100);
  const totalSecondBetAmount = BigNumber.from(totalUserFund + traderInitFund)
    .mul(2)
    .mul(DECIMALS)
    .div(100);

  beforeEach(async () => {
    [trader, user1, user2, user3, user4] = await ethers.getSigners();
    totalUserFund = userInitFunds.reduce((sum, userFund) => {
      return (sum += userFund);
    });

    // totalUserFund = utils.parseEther(totalUserFund);

    signers = await ethers.getSigners();

    const Oracle = await ethers.getContractFactory("Oracle");
    const PredictionMarket = await ethers.getContractFactory(
      "PredictionMarket"
    );
    const StrategyFactory = await ethers.getContractFactory("StrategyFactory");
    Strategy = await ethers.getContractFactory("Strategy");

    //Deploying Contract Oracle
    oracle = await Oracle.deploy();
    await oracle.deployed();

    //Deploying Contract PM
    predictionMarket = await PredictionMarket.deploy();
    await predictionMarket.deployed();

    //Deploying Contract StrategyFactory
    strategyFactory = await StrategyFactory.deploy(predictionMarket.address);
    await strategyFactory.deployed();
  });

  it("Should create new strategy, add users, place 2 bets for 2 different conditions ", async function () {
    const traderFund = BigNumber.from(50).mul(DECIMALS).div(1);

    const createdStrategy = await strategyFactory.createStrategy(
      STRATEGY_NAME,
      200,
      600,
      { value: traderFund }
    );

    const txReceipt = await createdStrategy.wait();
    expect(await strategyFactory.strategyID()).to.equal("1");

    //Getting Strategy Contract deployed
    const strategyAddress = txReceipt.events[0].args.strategyAddress;
    const provider = await ethers.provider;

    //Creating Instance of strategy contract
    const strategy = new ethers.Contract(
      strategyAddress,
      StrategyABI,
      provider
    );

    //User1 follows
    const user1Fund = BigNumber.from(userInitFunds[0]).mul(DECIMALS).div(1);
    await strategy.connect(user1).follow({ value: user1Fund });

    //User2 Follows
    const user2Fund = BigNumber.from(userInitFunds[1]).mul(DECIMALS).div(1);
    await strategy.connect(user2).follow({ value: user2Fund });

    //User3 Follows
    const user3Fund = BigNumber.from(userInitFunds[2]).mul(DECIMALS).div(1);
    await strategy.connect(user3).follow({ value: user3Fund });

    //User4 Follows
    const user4Fund = BigNumber.from(userInitFunds[3]).mul(DECIMALS).div(1);
    await strategy.connect(user4).follow({ value: user4Fund });

    expect(await strategy.totalUserFunds()).to.equal(
      BigNumber.from(totalUserFund).mul(DECIMALS).div(1)
    );

    //BET1
    //Create Market using Prediction Market
    await predictionMarket.prepareCondition(
      oracle.address,
      SETTLEMENT_TIME,
      TRIGGER_VALUE,
      MARKET
    );
    expect(await predictionMarket.latestConditionIndex()).to.equal("1");

    await strategy.connect(trader).placeBet(1, 1, firstBetAmount);
    let conditionInfoAfterBet = await predictionMarket.conditions(1);

    let highBetToken = new ethers.Contract(
      conditionInfoAfterBet.highBetToken,
      BetTokenABI,
      provider
    );

    expect(await highBetToken.totalSupply()).to.equal(
      await highBetToken.balanceOf(strategy.address)
    );
    expect(await strategy.trader()).to.equal(trader.address);

    //BET2
    //Create Market using Prediction Market
    await predictionMarket.prepareCondition(
      oracle.address,
      SETTLEMENT_TIME + 5000,
      TRIGGER_VALUE + 5000,
      MARKET
    );
    expect(await predictionMarket.latestConditionIndex()).to.equal("2");

    await strategy.connect(trader).placeBet(2, 0, secondBetAmount);
    conditionInfoAfterBet = await predictionMarket.conditions(2);

    lowBetToken = new ethers.Contract(
      conditionInfoAfterBet.lowBetToken,
      BetTokenABI,
      provider
    );

    expect(await lowBetToken.totalSupply()).to.equal(
      await lowBetToken.balanceOf(strategy.address)
    );
  });

  it("Should create new strategy, follow-bet-follow-bet scenario", async function () {
    const traderFund = BigNumber.from(50).mul(DECIMALS).div(1);
    const createdStrategy = await strategyFactory.createStrategy(
      STRATEGY_NAME,
      200,
      400,
      { value: traderFund }
    );
    const txReceipt = await createdStrategy.wait();
    expect(await strategyFactory.strategyID()).to.equal("1");

    //Getting Strategy Contract deployed
    const strategyAddress = txReceipt.events[0].args.strategyAddress;
    let provider = await ethers.provider;

    //Creating Instance of strategy contract
    const strategy = new ethers.Contract(
      strategyAddress,
      StrategyABI,
      provider
    );

    //User1 follows
    const user1Fund = BigNumber.from(userInitFunds[0]).mul(DECIMALS).div(1);
    await strategy.connect(user1).follow({ value: user1Fund });

    //User2 Follows
    const user2Fund = BigNumber.from(userInitFunds[1]).mul(DECIMALS).div(1);
    await strategy.connect(user2).follow({ value: user2Fund });

    //BET1
    //Create Market using Prediction Market
    await predictionMarket.prepareCondition(
      oracle.address,
      SETTLEMENT_TIME,
      TRIGGER_VALUE,
      MARKET
    );
    expect(await predictionMarket.latestConditionIndex()).to.equal("1");

    await strategy.connect(trader).placeBet(1, 1, firstBetAmount);
    let conditionInfoAfterBet = await predictionMarket.conditions(1);

    let highBetToken = new ethers.Contract(
      conditionInfoAfterBet.highBetToken,
      BetTokenABI,
      provider
    );
    totalUserFund = userInitFunds[0] + userInitFunds[1];
    totalFirstBetAmount = BigNumber.from(totalUserFund + traderInitFund)
      .mul(1)
      .mul(DECIMALS)
      .div(100);

    expect(await highBetToken.totalSupply()).to.equal(
      await highBetToken.balanceOf(strategy.address)
    );
    expect(await strategy.trader()).to.equal(trader.address);

    // User3 Follows
    const user3Fund = BigNumber.from(userInitFunds[2]).mul(DECIMALS).div(1);
    await strategy.connect(user3).follow({ value: user3Fund });

    //User4 Follows
    const user4Fund = BigNumber.from(userInitFunds[3]).mul(DECIMALS).div(1);
    await strategy.connect(user4).follow({ value: user4Fund });

    totalUserFund += userInitFunds[2] + userInitFunds[3];
    expect(await strategy.totalUserFunds()).to.equal(
      BigNumber.from(totalUserFund).mul(DECIMALS).div(1)
    );

    //BET2
    //Create Market using Prediction Market
    await predictionMarket.prepareCondition(
      oracle.address,
      SETTLEMENT_TIME + 5000,
      TRIGGER_VALUE + 5000,
      MARKET
    );
    expect(await predictionMarket.latestConditionIndex()).to.equal("2");

    await strategy.connect(trader).placeBet(2, 0, secondBetAmount);
    conditionInfoAfterBet = await predictionMarket.conditions(2);

    lowBetToken = new ethers.Contract(
      conditionInfoAfterBet.lowBetToken,
      BetTokenABI,
      provider
    );
    expect(await lowBetToken.totalSupply()).to.equal(
      await lowBetToken.balanceOf(strategy.address)
    );
  });

  describe("Claim bets", async () => {
    let strategy;
    before(async () => {
      const traderFund = BigNumber.from(50).mul(DECIMALS).div(1);

      const createdStrategy = await strategyFactory.createStrategy(
        STRATEGY_NAME,
        200,
        600,
        { value: traderFund }
      );

      const txReceipt = await createdStrategy.wait();

      //Getting Strategy Contract deployed
      const strategyAddress = txReceipt.events[0].args.strategyAddress;
      const provider = await ethers.provider;

      //Creating Instance of strategy contract
      strategy = new ethers.Contract(strategyAddress, StrategyABI, provider);

      //User1 follows
      const user1Fund = BigNumber.from(userInitFunds[0]).mul(DECIMALS).div(1);
      await strategy.connect(user1).follow({ value: user1Fund });

      //User2 Follows
      const user2Fund = BigNumber.from(userInitFunds[1]).mul(DECIMALS).div(1);
      await strategy.connect(user2).follow({ value: user2Fund });

      await predictionMarket.prepareCondition(
        oracle.address,
        SETTLEMENT_TIME,
        TRIGGER_VALUE,
        MARKET
      );

      await strategy.connect(trader).placeBet(1, 0, secondBetAmount);
    });

    it("should claim bets", async () => {
      await network.provider.send("evm_increaseTime", [86400]);
      await strategy.connect(trader).claimBet(1);
    });
  });
});
