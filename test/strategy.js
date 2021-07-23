const { expect } = require("chai");
const { BigNumber } = ethers;
const {abi} = require("../artifacts/contracts/Strategy.sol/Strategy.json");

describe("Strategy", function () {
  let trader1, user1, user2, user3, user4, userInitFunds, traderInitFund, firstBetAmount;
  const DECIMALS = BigNumber.from(10).pow(18);
  const TRIGGER_VALUE = 60000000000;
  const SETTLEMENT_TIME = 60000000000;
  const MARKET = "BTC/USD";
  const STRATEGY_NAME = "S1";

  beforeEach(async () => {
    [trader1, user1, user2, user3, user4] = await ethers.getSigners();
    userInitFunds = [10, 20, 30, 10]
    traderInitFund = 50;
    firstBetAmount = BigNumber.from(traderInitFund).mul(10).div(100);

    signers = await ethers.getSigners();
    //Deploying Contract Oracle
    const Oracle = await ethers.getContractFactory("Oracle");
    oracle = await Oracle.deploy();
    await oracle.deployed();
    console.log("Oracle address: ", oracle.address);
    contractSigner = await oracle.signer;

    //Deploying Contract PM
    const PredictionMarket = await ethers.getContractFactory("PredictionMarket");
    predictionMarket = await PredictionMarket.deploy();
    await predictionMarket.deployed();
    console.log("PM address: ", predictionMarket.address);

    //Deploying Contract StrategyFactory
    const StrategyFactory = await ethers.getContractFactory("StrategyFactory");
    strategyFactory = await StrategyFactory.deploy(predictionMarket.address);
    await strategyFactory.deployed();
    console.log("strategy factory address: ", strategyFactory.address);

    Strategy = await ethers.getContractFactory("Strategy");

  })


  it("Should create new strategy, add users ", async function () {

    const traderFund = BigNumber.from(50).mul(DECIMALS).div(1);
    const createdStrategy = await strategyFactory.createStrategy(STRATEGY_NAME,{ value: traderFund });
    const txReceipt = await createdStrategy.wait();
    expect(await strategyFactory.traderId()).to.equal("1");

    //Getting Strategy Contract deployed
    const strategyAddress = txReceipt.events[0].args.strategyAddress;
    let provider = await ethers.provider;

    const strategy = new ethers.Contract(strategyAddress,abi,provider);
    
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

    let totalUserFund = userInitFunds.reduce((sum,userFund)=>{
      return sum += userFund;
    })

    expect(await strategy.totalUserFunds()).to.equal(BigNumber.from(totalUserFund).mul(DECIMALS).div(1));

    //Create Market using Prediction Market 
    await predictionMarket.prepareCondition(oracle.address,
      SETTLEMENT_TIME,
      TRIGGER_VALUE,
      MARKET);
    expect(await predictionMarket.latestConditionIndex()).to.equal("1");

    // console.log(await predictionMarket.conditions(1), "Condition details");
    await strategy.connect(user4).bet(1, 1, firstBetAmount);

    console.log("BET Verify", await strategy.checkpoints(4));

  });
 
});
