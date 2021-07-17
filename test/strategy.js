const { expect } = require("chai");
const { BigNumber } = ethers;

describe("Strategy", function () {
  let trader1, user1, user2, user3;
  const DECIMALS = BigNumber.from(10).pow(18);
  const TRIGGER_VALUE = 60000000000;

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

    //Deploying Contract Strategy
    const Strategy = await ethers.getContractFactory("Strategy");
    strategy = await Strategy.deploy(predictionMarket.address);
    await strategy.deployed();
    console.log("strategy address: ", strategy.address);

  })

  it("Should create market ", async function () {

    await predictionMarket.prepareCondition(oracle.address,
      Math.floor(Date.now() / 1000) + 1000,
      TRIGGER_VALUE,
      "BTC/USD");
    // console.log(await predictionMarket.conditions(1));
    expect(await predictionMarket.latestConditionIndex()).to.equal("1");

  });

  it("Should create market bet, claim ", async function () {
    //Checking the transfer function
    await predictionMarket.prepareCondition(oracle.address,
      Math.floor(Date.now() / 1000) + 1000,
      TRIGGER_VALUE,
      "BTC/USD");

    //create strategy
    await strategy.createStrategy("Nupura", 1);
    console.log("Trader Info1", await strategy.name());

    //addTraderFund
    const traderValue = BigNumber.from(50).mul(DECIMALS);
    await strategy.addTraderFund({ value: traderValue });
    console.log("Trader Info2", await strategy.traderFund());

    //addUSerFund
    const userValue = BigNumber.from(20).mul(DECIMALS);
    await strategy.connect(user1).addUserFund({ value: userValue });
    console.log("User Info", await strategy.connect(user1).userInfo(user1.address));

    //bet
    await strategy.placeBet(1, 1, BigNumber.from(10).mul(DECIMALS));
    // console.log("User Info", await strategy.connect(user1).userInfo(user1.address));
    // console.log("bet Info", await strategy.connect(user1).bets(user1.address,0));

    //get Condition
    // console.log("Condition Info", await strategy.getConditionDetails("1"));

    //claim
    await strategy.claim(user1.address, 1);
    console.log("User Info", await strategy.connect(user1).userInfo(user1.address));

  });
});
