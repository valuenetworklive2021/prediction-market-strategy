const { expect } = require("chai");
const { BigNumber } = ethers;
const { abi } = require("../artifacts/contracts/Strategy.sol/Strategy.json");
const betTokenABI = require("../artifacts/contracts/mocks/BetToken.sol/BetToken.json");

describe("Strategy", function () {
  let trader1;
  let  user1;
  let  user2;
  let  user3;
  let  user4;
  let  userInitFunds;
  let  traderInitFund;
  let  firstBetAmount;
  let  totalFirstBetAmount;
  let  totalUserFund;
  let  secondBetAmount;
  let  totalSecondBetAmount;
  
  const DECIMALS = BigNumber.from(10).pow(18);
  const TRIGGER_VALUE = 60000000000;
  const SETTLEMENT_TIME = 60000000000;
  const MARKET = "BTC/USD";
  const STRATEGY_NAME = "S1";

  beforeEach(async () => {
    [trader1, user1, user2, user3, user4] = await ethers.getSigners();
    userInitFunds = [10, 20, 30, 10];
    traderInitFund = 50;
    totalUserFund = userInitFunds.reduce((sum, userFund) => {
      return (sum += userFund);
    });
    firstBetAmount = BigNumber.from(traderInitFund)
      .mul(1)
      .mul(DECIMALS)
      .div(100);
    secondBetAmount = BigNumber.from(traderInitFund)
      .mul(2)
      .mul(DECIMALS)
      .div(100);
    totalFirstBetAmount = BigNumber.from(totalUserFund + traderInitFund)
      .mul(1)
      .mul(DECIMALS)
      .div(100);
    totalSecondBetAmount = BigNumber.from(totalUserFund + traderInitFund)
      .mul(2)
      .mul(DECIMALS)
      .div(100);
    signers = await ethers.getSigners();
    //Deploying Contract Oracle
    const Oracle = await ethers.getContractFactory("Oracle");
    oracle = await Oracle.deploy();
    await oracle.deployed();
    console.log("Oracle address: ", oracle.address);
    contractSigner = await oracle.signer;

    //Deploying Contract PM
    const PredictionMarket = await ethers.getContractFactory(
      "PredictionMarket"
    );
    predictionMarket = await PredictionMarket.deploy();
    await predictionMarket.deployed();
    console.log("PM address: ", predictionMarket.address);

    //Deploying Contract StrategyFactory
    const StrategyFactory = await ethers.getContractFactory("StrategyFactory");
    strategyFactory = await StrategyFactory.deploy(predictionMarket.address);
    await strategyFactory.deployed();
    console.log("strategy factory address: ", strategyFactory.address);

    Strategy = await ethers.getContractFactory("Strategy");
  });

  it("Should create new strategy, add users, place 2 bets for 2 different conditions ", async function () {
    const traderFund = BigNumber.from(50).mul(DECIMALS).div(1);
    const createdStrategy = await strategyFactory.createStrategy(
      STRATEGY_NAME,
      { value: traderFund }
    );
    const txReceipt = await createdStrategy.wait();
    expect(await strategyFactory.traderId()).to.equal("1");

    //Getting Strategy Contract deployed
    const strategyAddress = txReceipt.events[0].args.strategyAddress;
    let provider = await ethers.provider;

    //Creating Instance of strategy contract
    const strategy = new ethers.Contract(strategyAddress, abi, provider);

    //User1 follows
    const user1Fund = BigNumber.from(userInitFunds[0]).mul(DECIMALS).div(1);
    await strategy.connect(user1).follow({ value: user1Fund });

    expect(await strategy.users(0)).to.equal(user1.address);

    //User2 Follows
    const user2Fund = BigNumber.from(userInitFunds[1]).mul(DECIMALS).div(1);
    await strategy.connect(user2).follow({ value: user2Fund });

    expect(await strategy.users(1)).to.equal(user2.address);

    //User3 Follows
    const user3Fund = BigNumber.from(userInitFunds[2]).mul(DECIMALS).div(1);
    await strategy.connect(user3).follow({ value: user3Fund });

    expect(await strategy.users(2)).to.equal(user3.address);

    //User4 Follows
    const user4Fund = BigNumber.from(userInitFunds[3]).mul(DECIMALS).div(1);
    await strategy.connect(user4).follow({ value: user4Fund });

    expect(await strategy.users(3)).to.equal(user4.address);

    expect(await strategy.totalUserFunds()).to.equal(
      BigNumber.from(totalUserFund).mul(DECIMALS).div(1)
    );
    expect(await strategy.latestCheckpointId()).to.equal(4);

    //BET1
    //Create Market using Prediction Market
    await predictionMarket.prepareCondition(
      oracle.address,
      SETTLEMENT_TIME,
      TRIGGER_VALUE,
      MARKET
    );
    expect(await predictionMarket.latestConditionIndex()).to.equal("1");

    await strategy.connect(trader1).bet(1, 1, firstBetAmount);
    let conditionInfoAfterBet = await predictionMarket.conditions(1);

    let highBetToken = new ethers.Contract(
      conditionInfoAfterBet.highBetToken,
      betTokenABI.abi,
      provider
    );

    expect(await highBetToken.totalSupply()).to.equal(totalFirstBetAmount);
    expect((await strategy.checkpoints(3)).totalInvested).to.equal(
      totalFirstBetAmount
    );
    expect(await strategy.trader()).to.equal(trader1.address);

    //BET2
    //Create Market using Prediction Market
    await predictionMarket.prepareCondition(
      oracle.address,
      SETTLEMENT_TIME + 5000,
      TRIGGER_VALUE + 5000,
      MARKET
    );
    expect(await predictionMarket.latestConditionIndex()).to.equal("2");

    await strategy.connect(trader1).bet(2, 0, secondBetAmount);
    conditionInfoAfterBet = await predictionMarket.conditions(2);

    lowBetToken = new ethers.Contract(
      conditionInfoAfterBet.lowBetToken,
      betTokenABI.abi,
      provider
    );
    expect(await lowBetToken.totalSupply()).to.equal(totalSecondBetAmount);
    expect((await strategy.checkpoints(3)).totalInvested).to.equal(
      totalSecondBetAmount.add(totalFirstBetAmount)
    );
  });

  it("Should create new strategy, follow-bet-folfow-bet scenario", async function () {
    const traderFund = BigNumber.from(50).mul(DECIMALS).div(1);
    const createdStrategy = await strategyFactory.createStrategy(
      STRATEGY_NAME,
      { value: traderFund }
    );
    const txReceipt = await createdStrategy.wait();
    expect(await strategyFactory.traderId()).to.equal("1");

    //Getting Strategy Contract deployed
    const strategyAddress = txReceipt.events[0].args.strategyAddress;
    let provider = await ethers.provider;

    //Creating Instance of strategy contract
    const strategy = new ethers.Contract(strategyAddress, abi, provider);

    //User1 follows
    const user1Fund = BigNumber.from(userInitFunds[0]).mul(DECIMALS).div(1);
    await strategy.connect(user1).follow({ value: user1Fund });

    expect(await strategy.users(0)).to.equal(user1.address);

    //User2 Follows
    const user2Fund = BigNumber.from(userInitFunds[1]).mul(DECIMALS).div(1);
    await strategy.connect(user2).follow({ value: user2Fund });

    expect(await strategy.users(1)).to.equal(user2.address);

    //BET1
    //Create Market using Prediction Market
    await predictionMarket.prepareCondition(
      oracle.address,
      SETTLEMENT_TIME,
      TRIGGER_VALUE,
      MARKET
    );
    expect(await predictionMarket.latestConditionIndex()).to.equal("1");

    await strategy.connect(trader1).bet(1, 1, firstBetAmount);
    let conditionInfoAfterBet = await predictionMarket.conditions(1);

    let highBetToken = new ethers.Contract(
      conditionInfoAfterBet.highBetToken,
      betTokenABI.abi,
      provider
    );
    totalUserFund = userInitFunds[0] + userInitFunds[1];
    totalFirstBetAmount = BigNumber.from(totalUserFund + traderInitFund)
      .mul(1)
      .mul(DECIMALS)
      .div(100);

    expect(await highBetToken.totalSupply()).to.equal(totalFirstBetAmount);
    expect((await strategy.checkpoints(1)).totalInvested).to.equal(
      totalFirstBetAmount
    );
    expect(await strategy.trader()).to.equal(trader1.address);

    // User3 Follows
    const user3Fund = BigNumber.from(userInitFunds[2]).mul(DECIMALS).div(1);
    await strategy.connect(user3).follow({ value: user3Fund });

    expect(await strategy.users(2)).to.equal(user3.address);

    //User4 Follows
    const user4Fund = BigNumber.from(userInitFunds[3]).mul(DECIMALS).div(1);
    await strategy.connect(user4).follow({ value: user4Fund });

    expect(await strategy.users(3)).to.equal(user4.address);
    totalUserFund += userInitFunds[2] + userInitFunds[3];
    expect(await strategy.totalUserFunds()).to.equal(
      BigNumber.from(totalUserFund).mul(DECIMALS).div(1)
    );
    expect(await strategy.latestCheckpointId()).to.equal(4);

    //BET2
    //Create Market using Prediction Market
    await predictionMarket.prepareCondition(
      oracle.address,
      SETTLEMENT_TIME + 5000,
      TRIGGER_VALUE + 5000,
      MARKET
    );
    expect(await predictionMarket.latestConditionIndex()).to.equal("2");

    await strategy.connect(trader1).bet(2, 0, secondBetAmount);
    conditionInfoAfterBet = await predictionMarket.conditions(2);

    lowBetToken = new ethers.Contract(
      conditionInfoAfterBet.lowBetToken,
      betTokenABI.abi,
      provider
    );
    expect(await lowBetToken.totalSupply()).to.equal(totalSecondBetAmount);
    expect((await strategy.checkpoints(3)).totalInvested).to.equal(
      totalSecondBetAmount
    );
  });
});
