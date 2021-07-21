const { expect } = require("chai");
const { BigNumber } = ethers;
const strategyABI = require("../artifacts/contracts/Strategy.sol/Strategy.json").abi;

describe("Strategy", function () {
  let trader1, user1, user2, user3;
  const DECIMALS = BigNumber.from(10).pow(18);
  const TRIGGER_VALUE = 60000000000;
  const SETTLEMENT_TIME = 60000000000;
  const MARKET = "BTC/USD";
  const STRATEGY_NAME = "S1";

  beforeEach(async () => {
    [trader1, user1, user2, user3] = await ethers.getSigners();

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

  })

  it("Should create market ", async function () {

    await predictionMarket.prepareCondition(oracle.address,
      SETTLEMENT_TIME,
      TRIGGER_VALUE,
      MARKET);
    expect(await predictionMarket.latestConditionIndex()).to.equal("1");

  });

  it("Should create new strategy ", async function () {

    const traderFund = BigNumber.from(50).mul(DECIMALS);
    const createdStrategy = await strategyFactory.createStrategy(STRATEGY_NAME,{ value: traderFund });
    const txReceipt = await createdStrategy.wait();
    expect(await strategyFactory.traderId()).to.equal("1");

    // getting Strategy Contract deployed
    const strategyAddressDeployed = txReceipt.events[0].args.strategyAddress;
    const strategy = new ethers.Contract(strategyAddressDeployed,strategyABI)     

  });

  it("Should create new strategy, add users ", async function () {

    const traderFund = BigNumber.from(50).mul(DECIMALS);
    const createdStrategy = await strategyFactory.createStrategy(STRATEGY_NAME,{ value: traderFund });
    const txReceipt = await createdStrategy.wait();
    expect(await strategyFactory.traderId()).to.equal("1");

    // getting Strategy Contract deployed
    const strategyAddressDeployed = txReceipt.events[0].args.strategyAddress;
    const strategy = new ethers.Contract(strategyAddressDeployed,strategyABI) 
    
    //User1 follows
    console.log(strategy);
    const user1Fund = BigNumber.from(10).mul(DECIMALS);
    await strategy.connect(user1).follow({ value: user1Fund });  

    expect(await strategy.users(0)).to.equal(user1.address);

  });

 
});
