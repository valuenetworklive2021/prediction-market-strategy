// File: contracts/interfaces/IBetToken.sol

//SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.0;

interface IBetToken {
  /**
   * Functions for public variables
   */
  function totalHolders() external returns (uint256);

  function predictionMarket() external returns (address);

  /**
   * Functions overridden in BetToken
   */
  function mint(address _to, uint256 _value) external;

  function burn(address _from, uint256 _value) external;

  function burnAll(address _from) external;

  function transfer(address recipient, uint256 amount) external returns (bool);

  function transferFrom(
    address sender,
    address recipient,
    uint256 amount
  ) external returns (bool);

  /**
   * Functions of Pausable
   */
  function paused() external view returns (bool);

  /**
   * Functions of ERC20
   */
  function name() external view returns (string memory);

  function symbol() external view returns (string memory);

  function decimals() external view returns (uint8);

  /**
   * Functions of IERC20
   */
  function totalSupply() external view returns (uint256);

  function balanceOf(address account) external view returns (uint256);

  function allowance(address owner, address spender)
    external
    view
    returns (uint256);

  function approve(address spender, uint256 amount) external returns (bool);
}

// File: contracts/interfaces/IPredictionMarket.sol

pragma solidity 0.8.0;

interface IPredictionMarket {
  event ConditionPrepared(
    uint256 indexed conditionIndex,
    address indexed oracle,
    uint256 indexed settlementTime,
    int256 triggerPrice,
    address lowBetTokenAddress,
    address highBetTokenAddress
  );

  event UserPrediction(
    uint256 indexed conditionIndex,
    address indexed userAddress,
    uint256 indexed ETHStaked,
    uint8 prediction,
    uint256 timestamp
  );

  event UserClaimed(
    uint256 indexed conditionIndex,
    address indexed userAddress,
    uint256 indexed winningAmount
  );

  event ConditionSettled(
    uint256 indexed conditionIndex,
    int256 indexed settledPrice,
    uint256 timestamp
  );

  function conditions(uint256 _index)
    external
    view
    returns (
      string memory market,
      address oracle,
      int256 triggerPrice,
      uint256 settlementTime,
      bool isSettled,
      int256 settledPrice,
      address lowBetToken,
      address highBetToken,
      uint256 totalStakedAbove,
      uint256 totalStakedBelow
    );

  function prepareCondition(
    address _oracle,
    uint256 _settlementTime,
    int256 _triggerPrice,
    string memory _market
  ) external;

  function probabilityRatio(uint256 _conditionIndex)
    external
    view
    returns (uint256 aboveProbabilityRatio, uint256 belowProbabilityRatio);

  function userTotalETHStaked(uint256 _conditionIndex, address userAddress)
    external
    view
    returns (uint256 totalEthStaked);

  function betOnCondition(uint256 _conditionIndex, uint8 _prediction)
    external
    payable;

  function settleCondition(uint256 _conditionIndex) external;

  function claim(uint256 _conditionIndex) external;

  function calculateClaimAmount(uint256 _conditionIndex)
    external
    returns (
      uint8 winningSide,
      uint256 userstake,
      uint256 totalWinnerRedeemable,
      uint256 platformFees
    );

  function getPerUserClaimAmount(uint256 _conditionIndex)
    external
    returns (uint8, uint256);

  function getBalance(uint256 _conditionIndex, address _user)
    external
    view
    returns (uint256 LBTBalance, uint256 HBTBalance);
}

// File: contracts/StrategyStorage.sol

pragma solidity 0.8.0;

contract StrategyStorage {
  enum StrategyStatus {
    ACTIVE,
    INACTIVE
  }

  struct User {
    uint256 depositAmount;
    uint256 entryCheckpointId;
    uint256 exitCheckpointId;
    uint256 totalProfit;
    uint256 totalLoss;
    bool exited;
    uint256 remainingClaim;
    //totalClaimed = amount + profit - loss
  }

  //strategy details
  StrategyStatus public status;
  IPredictionMarket public predictionMarket;
  address payable public trader;
  string public strategyName;
  uint256 public traderFund;

  uint256 latestCheckpointId;

  //user details
  mapping(address => User) public userInfo;

  //to get list of users
  address[] public users;
  uint256[] public userAmounts;

  uint256 totalUserFunds;

  //Fees Percentage
  uint256 public traderFees;

  struct Checkpoint {
    address[] users;
    uint256 totalVolume;
    uint256 totalInvested;
    uint256 totalProfit;
    uint256 totalLoss;
  }

  struct Market {
    uint256 lowBets;
    uint256 highBets;
  }

  mapping(uint256 => Checkpoint) public checkpoints;

  //maps checkpoint -> conditionindex -> market
  mapping(uint256 => mapping(uint256 => Market)) public markets;
  mapping(uint256 => uint256[]) public conditionIndexToCheckpoints;
}

// File: contracts/Checkpoint.sol

pragma solidity 0.8.0;

contract Checkpoint is StrategyStorage {
  function addCheckpoint(address[] memory _users, uint256 _totalVolume)
    internal
  {
    Checkpoint storage newCheckpoint = checkpoints[latestCheckpointId++];
    newCheckpoint.users = _users;
    newCheckpoint.totalVolume = _totalVolume;
  }

  function updateCheckpoint(
    uint256 _checkpointId,
    uint256 _totalInvestedChange,
    uint256 _totalProfitChange,
    uint256 _totalLossChange
  ) internal {
    Checkpoint storage existingCheckpoint = checkpoints[_checkpointId];
    existingCheckpoint.totalInvested += _totalInvestedChange;
    existingCheckpoint.totalProfit += _totalProfitChange;
    existingCheckpoint.totalLoss += _totalLossChange;
  }
}

// File: hardhat/console.sol

// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

library console {
  address constant CONSOLE_ADDRESS =
    address(0x000000000000000000636F6e736F6c652e6c6f67);

  function _sendLogPayload(bytes memory payload) private view {
    uint256 payloadLength = payload.length;
    address consoleAddress = CONSOLE_ADDRESS;
    assembly {
      let payloadStart := add(payload, 32)
      let r := staticcall(
        gas(),
        consoleAddress,
        payloadStart,
        payloadLength,
        0,
        0
      )
    }
  }

  function log() internal view {
    _sendLogPayload(abi.encodeWithSignature("log()"));
  }

  function logInt(int256 p0) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(int)", p0));
  }

  function logUint(uint256 p0) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(uint)", p0));
  }

  function logString(string memory p0) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(string)", p0));
  }

  function logBool(bool p0) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(bool)", p0));
  }

  function logAddress(address p0) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(address)", p0));
  }

  function logBytes(bytes memory p0) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(bytes)", p0));
  }

  function logBytes1(bytes1 p0) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(bytes1)", p0));
  }

  function logBytes2(bytes2 p0) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(bytes2)", p0));
  }

  function logBytes3(bytes3 p0) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(bytes3)", p0));
  }

  function logBytes4(bytes4 p0) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(bytes4)", p0));
  }

  function logBytes5(bytes5 p0) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(bytes5)", p0));
  }

  function logBytes6(bytes6 p0) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(bytes6)", p0));
  }

  function logBytes7(bytes7 p0) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(bytes7)", p0));
  }

  function logBytes8(bytes8 p0) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(bytes8)", p0));
  }

  function logBytes9(bytes9 p0) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(bytes9)", p0));
  }

  function logBytes10(bytes10 p0) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(bytes10)", p0));
  }

  function logBytes11(bytes11 p0) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(bytes11)", p0));
  }

  function logBytes12(bytes12 p0) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(bytes12)", p0));
  }

  function logBytes13(bytes13 p0) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(bytes13)", p0));
  }

  function logBytes14(bytes14 p0) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(bytes14)", p0));
  }

  function logBytes15(bytes15 p0) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(bytes15)", p0));
  }

  function logBytes16(bytes16 p0) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(bytes16)", p0));
  }

  function logBytes17(bytes17 p0) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(bytes17)", p0));
  }

  function logBytes18(bytes18 p0) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(bytes18)", p0));
  }

  function logBytes19(bytes19 p0) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(bytes19)", p0));
  }

  function logBytes20(bytes20 p0) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(bytes20)", p0));
  }

  function logBytes21(bytes21 p0) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(bytes21)", p0));
  }

  function logBytes22(bytes22 p0) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(bytes22)", p0));
  }

  function logBytes23(bytes23 p0) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(bytes23)", p0));
  }

  function logBytes24(bytes24 p0) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(bytes24)", p0));
  }

  function logBytes25(bytes25 p0) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(bytes25)", p0));
  }

  function logBytes26(bytes26 p0) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(bytes26)", p0));
  }

  function logBytes27(bytes27 p0) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(bytes27)", p0));
  }

  function logBytes28(bytes28 p0) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(bytes28)", p0));
  }

  function logBytes29(bytes29 p0) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(bytes29)", p0));
  }

  function logBytes30(bytes30 p0) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(bytes30)", p0));
  }

  function logBytes31(bytes31 p0) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(bytes31)", p0));
  }

  function logBytes32(bytes32 p0) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(bytes32)", p0));
  }

  function log(uint256 p0) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(uint)", p0));
  }

  function log(string memory p0) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(string)", p0));
  }

  function log(bool p0) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(bool)", p0));
  }

  function log(address p0) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(address)", p0));
  }

  function log(uint256 p0, uint256 p1) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(uint,uint)", p0, p1));
  }

  function log(uint256 p0, string memory p1) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(uint,string)", p0, p1));
  }

  function log(uint256 p0, bool p1) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(uint,bool)", p0, p1));
  }

  function log(uint256 p0, address p1) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(uint,address)", p0, p1));
  }

  function log(string memory p0, uint256 p1) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(string,uint)", p0, p1));
  }

  function log(string memory p0, string memory p1) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(string,string)", p0, p1));
  }

  function log(string memory p0, bool p1) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(string,bool)", p0, p1));
  }

  function log(string memory p0, address p1) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(string,address)", p0, p1));
  }

  function log(bool p0, uint256 p1) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(bool,uint)", p0, p1));
  }

  function log(bool p0, string memory p1) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(bool,string)", p0, p1));
  }

  function log(bool p0, bool p1) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(bool,bool)", p0, p1));
  }

  function log(bool p0, address p1) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(bool,address)", p0, p1));
  }

  function log(address p0, uint256 p1) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(address,uint)", p0, p1));
  }

  function log(address p0, string memory p1) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(address,string)", p0, p1));
  }

  function log(address p0, bool p1) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(address,bool)", p0, p1));
  }

  function log(address p0, address p1) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(address,address)", p0, p1));
  }

  function log(
    uint256 p0,
    uint256 p1,
    uint256 p2
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(uint,uint,uint)", p0, p1, p2));
  }

  function log(
    uint256 p0,
    uint256 p1,
    string memory p2
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(uint,uint,string)", p0, p1, p2)
    );
  }

  function log(
    uint256 p0,
    uint256 p1,
    bool p2
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(uint,uint,bool)", p0, p1, p2));
  }

  function log(
    uint256 p0,
    uint256 p1,
    address p2
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(uint,uint,address)", p0, p1, p2)
    );
  }

  function log(
    uint256 p0,
    string memory p1,
    uint256 p2
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(uint,string,uint)", p0, p1, p2)
    );
  }

  function log(
    uint256 p0,
    string memory p1,
    string memory p2
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(uint,string,string)", p0, p1, p2)
    );
  }

  function log(
    uint256 p0,
    string memory p1,
    bool p2
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(uint,string,bool)", p0, p1, p2)
    );
  }

  function log(
    uint256 p0,
    string memory p1,
    address p2
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(uint,string,address)", p0, p1, p2)
    );
  }

  function log(
    uint256 p0,
    bool p1,
    uint256 p2
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(uint,bool,uint)", p0, p1, p2));
  }

  function log(
    uint256 p0,
    bool p1,
    string memory p2
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(uint,bool,string)", p0, p1, p2)
    );
  }

  function log(
    uint256 p0,
    bool p1,
    bool p2
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(uint,bool,bool)", p0, p1, p2));
  }

  function log(
    uint256 p0,
    bool p1,
    address p2
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(uint,bool,address)", p0, p1, p2)
    );
  }

  function log(
    uint256 p0,
    address p1,
    uint256 p2
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(uint,address,uint)", p0, p1, p2)
    );
  }

  function log(
    uint256 p0,
    address p1,
    string memory p2
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(uint,address,string)", p0, p1, p2)
    );
  }

  function log(
    uint256 p0,
    address p1,
    bool p2
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(uint,address,bool)", p0, p1, p2)
    );
  }

  function log(
    uint256 p0,
    address p1,
    address p2
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(uint,address,address)", p0, p1, p2)
    );
  }

  function log(
    string memory p0,
    uint256 p1,
    uint256 p2
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(string,uint,uint)", p0, p1, p2)
    );
  }

  function log(
    string memory p0,
    uint256 p1,
    string memory p2
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(string,uint,string)", p0, p1, p2)
    );
  }

  function log(
    string memory p0,
    uint256 p1,
    bool p2
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(string,uint,bool)", p0, p1, p2)
    );
  }

  function log(
    string memory p0,
    uint256 p1,
    address p2
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(string,uint,address)", p0, p1, p2)
    );
  }

  function log(
    string memory p0,
    string memory p1,
    uint256 p2
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(string,string,uint)", p0, p1, p2)
    );
  }

  function log(
    string memory p0,
    string memory p1,
    string memory p2
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(string,string,string)", p0, p1, p2)
    );
  }

  function log(
    string memory p0,
    string memory p1,
    bool p2
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(string,string,bool)", p0, p1, p2)
    );
  }

  function log(
    string memory p0,
    string memory p1,
    address p2
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(string,string,address)", p0, p1, p2)
    );
  }

  function log(
    string memory p0,
    bool p1,
    uint256 p2
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(string,bool,uint)", p0, p1, p2)
    );
  }

  function log(
    string memory p0,
    bool p1,
    string memory p2
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(string,bool,string)", p0, p1, p2)
    );
  }

  function log(
    string memory p0,
    bool p1,
    bool p2
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(string,bool,bool)", p0, p1, p2)
    );
  }

  function log(
    string memory p0,
    bool p1,
    address p2
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(string,bool,address)", p0, p1, p2)
    );
  }

  function log(
    string memory p0,
    address p1,
    uint256 p2
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(string,address,uint)", p0, p1, p2)
    );
  }

  function log(
    string memory p0,
    address p1,
    string memory p2
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(string,address,string)", p0, p1, p2)
    );
  }

  function log(
    string memory p0,
    address p1,
    bool p2
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(string,address,bool)", p0, p1, p2)
    );
  }

  function log(
    string memory p0,
    address p1,
    address p2
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(string,address,address)", p0, p1, p2)
    );
  }

  function log(
    bool p0,
    uint256 p1,
    uint256 p2
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(bool,uint,uint)", p0, p1, p2));
  }

  function log(
    bool p0,
    uint256 p1,
    string memory p2
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(bool,uint,string)", p0, p1, p2)
    );
  }

  function log(
    bool p0,
    uint256 p1,
    bool p2
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(bool,uint,bool)", p0, p1, p2));
  }

  function log(
    bool p0,
    uint256 p1,
    address p2
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(bool,uint,address)", p0, p1, p2)
    );
  }

  function log(
    bool p0,
    string memory p1,
    uint256 p2
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(bool,string,uint)", p0, p1, p2)
    );
  }

  function log(
    bool p0,
    string memory p1,
    string memory p2
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(bool,string,string)", p0, p1, p2)
    );
  }

  function log(
    bool p0,
    string memory p1,
    bool p2
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(bool,string,bool)", p0, p1, p2)
    );
  }

  function log(
    bool p0,
    string memory p1,
    address p2
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(bool,string,address)", p0, p1, p2)
    );
  }

  function log(
    bool p0,
    bool p1,
    uint256 p2
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(bool,bool,uint)", p0, p1, p2));
  }

  function log(
    bool p0,
    bool p1,
    string memory p2
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(bool,bool,string)", p0, p1, p2)
    );
  }

  function log(
    bool p0,
    bool p1,
    bool p2
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(bool,bool,bool)", p0, p1, p2));
  }

  function log(
    bool p0,
    bool p1,
    address p2
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(bool,bool,address)", p0, p1, p2)
    );
  }

  function log(
    bool p0,
    address p1,
    uint256 p2
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(bool,address,uint)", p0, p1, p2)
    );
  }

  function log(
    bool p0,
    address p1,
    string memory p2
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(bool,address,string)", p0, p1, p2)
    );
  }

  function log(
    bool p0,
    address p1,
    bool p2
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(bool,address,bool)", p0, p1, p2)
    );
  }

  function log(
    bool p0,
    address p1,
    address p2
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(bool,address,address)", p0, p1, p2)
    );
  }

  function log(
    address p0,
    uint256 p1,
    uint256 p2
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(address,uint,uint)", p0, p1, p2)
    );
  }

  function log(
    address p0,
    uint256 p1,
    string memory p2
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(address,uint,string)", p0, p1, p2)
    );
  }

  function log(
    address p0,
    uint256 p1,
    bool p2
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(address,uint,bool)", p0, p1, p2)
    );
  }

  function log(
    address p0,
    uint256 p1,
    address p2
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(address,uint,address)", p0, p1, p2)
    );
  }

  function log(
    address p0,
    string memory p1,
    uint256 p2
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(address,string,uint)", p0, p1, p2)
    );
  }

  function log(
    address p0,
    string memory p1,
    string memory p2
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(address,string,string)", p0, p1, p2)
    );
  }

  function log(
    address p0,
    string memory p1,
    bool p2
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(address,string,bool)", p0, p1, p2)
    );
  }

  function log(
    address p0,
    string memory p1,
    address p2
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(address,string,address)", p0, p1, p2)
    );
  }

  function log(
    address p0,
    bool p1,
    uint256 p2
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(address,bool,uint)", p0, p1, p2)
    );
  }

  function log(
    address p0,
    bool p1,
    string memory p2
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(address,bool,string)", p0, p1, p2)
    );
  }

  function log(
    address p0,
    bool p1,
    bool p2
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(address,bool,bool)", p0, p1, p2)
    );
  }

  function log(
    address p0,
    bool p1,
    address p2
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(address,bool,address)", p0, p1, p2)
    );
  }

  function log(
    address p0,
    address p1,
    uint256 p2
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(address,address,uint)", p0, p1, p2)
    );
  }

  function log(
    address p0,
    address p1,
    string memory p2
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(address,address,string)", p0, p1, p2)
    );
  }

  function log(
    address p0,
    address p1,
    bool p2
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(address,address,bool)", p0, p1, p2)
    );
  }

  function log(
    address p0,
    address p1,
    address p2
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(address,address,address)", p0, p1, p2)
    );
  }

  function log(
    uint256 p0,
    uint256 p1,
    uint256 p2,
    uint256 p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(uint,uint,uint,uint)", p0, p1, p2, p3)
    );
  }

  function log(
    uint256 p0,
    uint256 p1,
    uint256 p2,
    string memory p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(uint,uint,uint,string)", p0, p1, p2, p3)
    );
  }

  function log(
    uint256 p0,
    uint256 p1,
    uint256 p2,
    bool p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(uint,uint,uint,bool)", p0, p1, p2, p3)
    );
  }

  function log(
    uint256 p0,
    uint256 p1,
    uint256 p2,
    address p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(uint,uint,uint,address)", p0, p1, p2, p3)
    );
  }

  function log(
    uint256 p0,
    uint256 p1,
    string memory p2,
    uint256 p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(uint,uint,string,uint)", p0, p1, p2, p3)
    );
  }

  function log(
    uint256 p0,
    uint256 p1,
    string memory p2,
    string memory p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(uint,uint,string,string)", p0, p1, p2, p3)
    );
  }

  function log(
    uint256 p0,
    uint256 p1,
    string memory p2,
    bool p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(uint,uint,string,bool)", p0, p1, p2, p3)
    );
  }

  function log(
    uint256 p0,
    uint256 p1,
    string memory p2,
    address p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(uint,uint,string,address)", p0, p1, p2, p3)
    );
  }

  function log(
    uint256 p0,
    uint256 p1,
    bool p2,
    uint256 p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(uint,uint,bool,uint)", p0, p1, p2, p3)
    );
  }

  function log(
    uint256 p0,
    uint256 p1,
    bool p2,
    string memory p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(uint,uint,bool,string)", p0, p1, p2, p3)
    );
  }

  function log(
    uint256 p0,
    uint256 p1,
    bool p2,
    bool p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(uint,uint,bool,bool)", p0, p1, p2, p3)
    );
  }

  function log(
    uint256 p0,
    uint256 p1,
    bool p2,
    address p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(uint,uint,bool,address)", p0, p1, p2, p3)
    );
  }

  function log(
    uint256 p0,
    uint256 p1,
    address p2,
    uint256 p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(uint,uint,address,uint)", p0, p1, p2, p3)
    );
  }

  function log(
    uint256 p0,
    uint256 p1,
    address p2,
    string memory p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(uint,uint,address,string)", p0, p1, p2, p3)
    );
  }

  function log(
    uint256 p0,
    uint256 p1,
    address p2,
    bool p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(uint,uint,address,bool)", p0, p1, p2, p3)
    );
  }

  function log(
    uint256 p0,
    uint256 p1,
    address p2,
    address p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(uint,uint,address,address)", p0, p1, p2, p3)
    );
  }

  function log(
    uint256 p0,
    string memory p1,
    uint256 p2,
    uint256 p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(uint,string,uint,uint)", p0, p1, p2, p3)
    );
  }

  function log(
    uint256 p0,
    string memory p1,
    uint256 p2,
    string memory p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(uint,string,uint,string)", p0, p1, p2, p3)
    );
  }

  function log(
    uint256 p0,
    string memory p1,
    uint256 p2,
    bool p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(uint,string,uint,bool)", p0, p1, p2, p3)
    );
  }

  function log(
    uint256 p0,
    string memory p1,
    uint256 p2,
    address p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(uint,string,uint,address)", p0, p1, p2, p3)
    );
  }

  function log(
    uint256 p0,
    string memory p1,
    string memory p2,
    uint256 p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(uint,string,string,uint)", p0, p1, p2, p3)
    );
  }

  function log(
    uint256 p0,
    string memory p1,
    string memory p2,
    string memory p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(uint,string,string,string)", p0, p1, p2, p3)
    );
  }

  function log(
    uint256 p0,
    string memory p1,
    string memory p2,
    bool p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(uint,string,string,bool)", p0, p1, p2, p3)
    );
  }

  function log(
    uint256 p0,
    string memory p1,
    string memory p2,
    address p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(uint,string,string,address)", p0, p1, p2, p3)
    );
  }

  function log(
    uint256 p0,
    string memory p1,
    bool p2,
    uint256 p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(uint,string,bool,uint)", p0, p1, p2, p3)
    );
  }

  function log(
    uint256 p0,
    string memory p1,
    bool p2,
    string memory p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(uint,string,bool,string)", p0, p1, p2, p3)
    );
  }

  function log(
    uint256 p0,
    string memory p1,
    bool p2,
    bool p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(uint,string,bool,bool)", p0, p1, p2, p3)
    );
  }

  function log(
    uint256 p0,
    string memory p1,
    bool p2,
    address p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(uint,string,bool,address)", p0, p1, p2, p3)
    );
  }

  function log(
    uint256 p0,
    string memory p1,
    address p2,
    uint256 p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(uint,string,address,uint)", p0, p1, p2, p3)
    );
  }

  function log(
    uint256 p0,
    string memory p1,
    address p2,
    string memory p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(uint,string,address,string)", p0, p1, p2, p3)
    );
  }

  function log(
    uint256 p0,
    string memory p1,
    address p2,
    bool p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(uint,string,address,bool)", p0, p1, p2, p3)
    );
  }

  function log(
    uint256 p0,
    string memory p1,
    address p2,
    address p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature(
        "log(uint,string,address,address)",
        p0,
        p1,
        p2,
        p3
      )
    );
  }

  function log(
    uint256 p0,
    bool p1,
    uint256 p2,
    uint256 p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(uint,bool,uint,uint)", p0, p1, p2, p3)
    );
  }

  function log(
    uint256 p0,
    bool p1,
    uint256 p2,
    string memory p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(uint,bool,uint,string)", p0, p1, p2, p3)
    );
  }

  function log(
    uint256 p0,
    bool p1,
    uint256 p2,
    bool p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(uint,bool,uint,bool)", p0, p1, p2, p3)
    );
  }

  function log(
    uint256 p0,
    bool p1,
    uint256 p2,
    address p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(uint,bool,uint,address)", p0, p1, p2, p3)
    );
  }

  function log(
    uint256 p0,
    bool p1,
    string memory p2,
    uint256 p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(uint,bool,string,uint)", p0, p1, p2, p3)
    );
  }

  function log(
    uint256 p0,
    bool p1,
    string memory p2,
    string memory p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(uint,bool,string,string)", p0, p1, p2, p3)
    );
  }

  function log(
    uint256 p0,
    bool p1,
    string memory p2,
    bool p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(uint,bool,string,bool)", p0, p1, p2, p3)
    );
  }

  function log(
    uint256 p0,
    bool p1,
    string memory p2,
    address p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(uint,bool,string,address)", p0, p1, p2, p3)
    );
  }

  function log(
    uint256 p0,
    bool p1,
    bool p2,
    uint256 p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(uint,bool,bool,uint)", p0, p1, p2, p3)
    );
  }

  function log(
    uint256 p0,
    bool p1,
    bool p2,
    string memory p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(uint,bool,bool,string)", p0, p1, p2, p3)
    );
  }

  function log(
    uint256 p0,
    bool p1,
    bool p2,
    bool p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(uint,bool,bool,bool)", p0, p1, p2, p3)
    );
  }

  function log(
    uint256 p0,
    bool p1,
    bool p2,
    address p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(uint,bool,bool,address)", p0, p1, p2, p3)
    );
  }

  function log(
    uint256 p0,
    bool p1,
    address p2,
    uint256 p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(uint,bool,address,uint)", p0, p1, p2, p3)
    );
  }

  function log(
    uint256 p0,
    bool p1,
    address p2,
    string memory p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(uint,bool,address,string)", p0, p1, p2, p3)
    );
  }

  function log(
    uint256 p0,
    bool p1,
    address p2,
    bool p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(uint,bool,address,bool)", p0, p1, p2, p3)
    );
  }

  function log(
    uint256 p0,
    bool p1,
    address p2,
    address p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(uint,bool,address,address)", p0, p1, p2, p3)
    );
  }

  function log(
    uint256 p0,
    address p1,
    uint256 p2,
    uint256 p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(uint,address,uint,uint)", p0, p1, p2, p3)
    );
  }

  function log(
    uint256 p0,
    address p1,
    uint256 p2,
    string memory p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(uint,address,uint,string)", p0, p1, p2, p3)
    );
  }

  function log(
    uint256 p0,
    address p1,
    uint256 p2,
    bool p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(uint,address,uint,bool)", p0, p1, p2, p3)
    );
  }

  function log(
    uint256 p0,
    address p1,
    uint256 p2,
    address p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(uint,address,uint,address)", p0, p1, p2, p3)
    );
  }

  function log(
    uint256 p0,
    address p1,
    string memory p2,
    uint256 p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(uint,address,string,uint)", p0, p1, p2, p3)
    );
  }

  function log(
    uint256 p0,
    address p1,
    string memory p2,
    string memory p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(uint,address,string,string)", p0, p1, p2, p3)
    );
  }

  function log(
    uint256 p0,
    address p1,
    string memory p2,
    bool p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(uint,address,string,bool)", p0, p1, p2, p3)
    );
  }

  function log(
    uint256 p0,
    address p1,
    string memory p2,
    address p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature(
        "log(uint,address,string,address)",
        p0,
        p1,
        p2,
        p3
      )
    );
  }

  function log(
    uint256 p0,
    address p1,
    bool p2,
    uint256 p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(uint,address,bool,uint)", p0, p1, p2, p3)
    );
  }

  function log(
    uint256 p0,
    address p1,
    bool p2,
    string memory p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(uint,address,bool,string)", p0, p1, p2, p3)
    );
  }

  function log(
    uint256 p0,
    address p1,
    bool p2,
    bool p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(uint,address,bool,bool)", p0, p1, p2, p3)
    );
  }

  function log(
    uint256 p0,
    address p1,
    bool p2,
    address p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(uint,address,bool,address)", p0, p1, p2, p3)
    );
  }

  function log(
    uint256 p0,
    address p1,
    address p2,
    uint256 p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(uint,address,address,uint)", p0, p1, p2, p3)
    );
  }

  function log(
    uint256 p0,
    address p1,
    address p2,
    string memory p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature(
        "log(uint,address,address,string)",
        p0,
        p1,
        p2,
        p3
      )
    );
  }

  function log(
    uint256 p0,
    address p1,
    address p2,
    bool p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(uint,address,address,bool)", p0, p1, p2, p3)
    );
  }

  function log(
    uint256 p0,
    address p1,
    address p2,
    address p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature(
        "log(uint,address,address,address)",
        p0,
        p1,
        p2,
        p3
      )
    );
  }

  function log(
    string memory p0,
    uint256 p1,
    uint256 p2,
    uint256 p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(string,uint,uint,uint)", p0, p1, p2, p3)
    );
  }

  function log(
    string memory p0,
    uint256 p1,
    uint256 p2,
    string memory p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(string,uint,uint,string)", p0, p1, p2, p3)
    );
  }

  function log(
    string memory p0,
    uint256 p1,
    uint256 p2,
    bool p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(string,uint,uint,bool)", p0, p1, p2, p3)
    );
  }

  function log(
    string memory p0,
    uint256 p1,
    uint256 p2,
    address p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(string,uint,uint,address)", p0, p1, p2, p3)
    );
  }

  function log(
    string memory p0,
    uint256 p1,
    string memory p2,
    uint256 p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(string,uint,string,uint)", p0, p1, p2, p3)
    );
  }

  function log(
    string memory p0,
    uint256 p1,
    string memory p2,
    string memory p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(string,uint,string,string)", p0, p1, p2, p3)
    );
  }

  function log(
    string memory p0,
    uint256 p1,
    string memory p2,
    bool p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(string,uint,string,bool)", p0, p1, p2, p3)
    );
  }

  function log(
    string memory p0,
    uint256 p1,
    string memory p2,
    address p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(string,uint,string,address)", p0, p1, p2, p3)
    );
  }

  function log(
    string memory p0,
    uint256 p1,
    bool p2,
    uint256 p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(string,uint,bool,uint)", p0, p1, p2, p3)
    );
  }

  function log(
    string memory p0,
    uint256 p1,
    bool p2,
    string memory p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(string,uint,bool,string)", p0, p1, p2, p3)
    );
  }

  function log(
    string memory p0,
    uint256 p1,
    bool p2,
    bool p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(string,uint,bool,bool)", p0, p1, p2, p3)
    );
  }

  function log(
    string memory p0,
    uint256 p1,
    bool p2,
    address p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(string,uint,bool,address)", p0, p1, p2, p3)
    );
  }

  function log(
    string memory p0,
    uint256 p1,
    address p2,
    uint256 p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(string,uint,address,uint)", p0, p1, p2, p3)
    );
  }

  function log(
    string memory p0,
    uint256 p1,
    address p2,
    string memory p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(string,uint,address,string)", p0, p1, p2, p3)
    );
  }

  function log(
    string memory p0,
    uint256 p1,
    address p2,
    bool p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(string,uint,address,bool)", p0, p1, p2, p3)
    );
  }

  function log(
    string memory p0,
    uint256 p1,
    address p2,
    address p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature(
        "log(string,uint,address,address)",
        p0,
        p1,
        p2,
        p3
      )
    );
  }

  function log(
    string memory p0,
    string memory p1,
    uint256 p2,
    uint256 p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(string,string,uint,uint)", p0, p1, p2, p3)
    );
  }

  function log(
    string memory p0,
    string memory p1,
    uint256 p2,
    string memory p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(string,string,uint,string)", p0, p1, p2, p3)
    );
  }

  function log(
    string memory p0,
    string memory p1,
    uint256 p2,
    bool p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(string,string,uint,bool)", p0, p1, p2, p3)
    );
  }

  function log(
    string memory p0,
    string memory p1,
    uint256 p2,
    address p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(string,string,uint,address)", p0, p1, p2, p3)
    );
  }

  function log(
    string memory p0,
    string memory p1,
    string memory p2,
    uint256 p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(string,string,string,uint)", p0, p1, p2, p3)
    );
  }

  function log(
    string memory p0,
    string memory p1,
    string memory p2,
    string memory p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature(
        "log(string,string,string,string)",
        p0,
        p1,
        p2,
        p3
      )
    );
  }

  function log(
    string memory p0,
    string memory p1,
    string memory p2,
    bool p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(string,string,string,bool)", p0, p1, p2, p3)
    );
  }

  function log(
    string memory p0,
    string memory p1,
    string memory p2,
    address p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature(
        "log(string,string,string,address)",
        p0,
        p1,
        p2,
        p3
      )
    );
  }

  function log(
    string memory p0,
    string memory p1,
    bool p2,
    uint256 p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(string,string,bool,uint)", p0, p1, p2, p3)
    );
  }

  function log(
    string memory p0,
    string memory p1,
    bool p2,
    string memory p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(string,string,bool,string)", p0, p1, p2, p3)
    );
  }

  function log(
    string memory p0,
    string memory p1,
    bool p2,
    bool p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(string,string,bool,bool)", p0, p1, p2, p3)
    );
  }

  function log(
    string memory p0,
    string memory p1,
    bool p2,
    address p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(string,string,bool,address)", p0, p1, p2, p3)
    );
  }

  function log(
    string memory p0,
    string memory p1,
    address p2,
    uint256 p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(string,string,address,uint)", p0, p1, p2, p3)
    );
  }

  function log(
    string memory p0,
    string memory p1,
    address p2,
    string memory p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature(
        "log(string,string,address,string)",
        p0,
        p1,
        p2,
        p3
      )
    );
  }

  function log(
    string memory p0,
    string memory p1,
    address p2,
    bool p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(string,string,address,bool)", p0, p1, p2, p3)
    );
  }

  function log(
    string memory p0,
    string memory p1,
    address p2,
    address p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature(
        "log(string,string,address,address)",
        p0,
        p1,
        p2,
        p3
      )
    );
  }

  function log(
    string memory p0,
    bool p1,
    uint256 p2,
    uint256 p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(string,bool,uint,uint)", p0, p1, p2, p3)
    );
  }

  function log(
    string memory p0,
    bool p1,
    uint256 p2,
    string memory p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(string,bool,uint,string)", p0, p1, p2, p3)
    );
  }

  function log(
    string memory p0,
    bool p1,
    uint256 p2,
    bool p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(string,bool,uint,bool)", p0, p1, p2, p3)
    );
  }

  function log(
    string memory p0,
    bool p1,
    uint256 p2,
    address p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(string,bool,uint,address)", p0, p1, p2, p3)
    );
  }

  function log(
    string memory p0,
    bool p1,
    string memory p2,
    uint256 p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(string,bool,string,uint)", p0, p1, p2, p3)
    );
  }

  function log(
    string memory p0,
    bool p1,
    string memory p2,
    string memory p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(string,bool,string,string)", p0, p1, p2, p3)
    );
  }

  function log(
    string memory p0,
    bool p1,
    string memory p2,
    bool p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(string,bool,string,bool)", p0, p1, p2, p3)
    );
  }

  function log(
    string memory p0,
    bool p1,
    string memory p2,
    address p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(string,bool,string,address)", p0, p1, p2, p3)
    );
  }

  function log(
    string memory p0,
    bool p1,
    bool p2,
    uint256 p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(string,bool,bool,uint)", p0, p1, p2, p3)
    );
  }

  function log(
    string memory p0,
    bool p1,
    bool p2,
    string memory p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(string,bool,bool,string)", p0, p1, p2, p3)
    );
  }

  function log(
    string memory p0,
    bool p1,
    bool p2,
    bool p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(string,bool,bool,bool)", p0, p1, p2, p3)
    );
  }

  function log(
    string memory p0,
    bool p1,
    bool p2,
    address p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(string,bool,bool,address)", p0, p1, p2, p3)
    );
  }

  function log(
    string memory p0,
    bool p1,
    address p2,
    uint256 p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(string,bool,address,uint)", p0, p1, p2, p3)
    );
  }

  function log(
    string memory p0,
    bool p1,
    address p2,
    string memory p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(string,bool,address,string)", p0, p1, p2, p3)
    );
  }

  function log(
    string memory p0,
    bool p1,
    address p2,
    bool p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(string,bool,address,bool)", p0, p1, p2, p3)
    );
  }

  function log(
    string memory p0,
    bool p1,
    address p2,
    address p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature(
        "log(string,bool,address,address)",
        p0,
        p1,
        p2,
        p3
      )
    );
  }

  function log(
    string memory p0,
    address p1,
    uint256 p2,
    uint256 p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(string,address,uint,uint)", p0, p1, p2, p3)
    );
  }

  function log(
    string memory p0,
    address p1,
    uint256 p2,
    string memory p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(string,address,uint,string)", p0, p1, p2, p3)
    );
  }

  function log(
    string memory p0,
    address p1,
    uint256 p2,
    bool p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(string,address,uint,bool)", p0, p1, p2, p3)
    );
  }

  function log(
    string memory p0,
    address p1,
    uint256 p2,
    address p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature(
        "log(string,address,uint,address)",
        p0,
        p1,
        p2,
        p3
      )
    );
  }

  function log(
    string memory p0,
    address p1,
    string memory p2,
    uint256 p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(string,address,string,uint)", p0, p1, p2, p3)
    );
  }

  function log(
    string memory p0,
    address p1,
    string memory p2,
    string memory p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature(
        "log(string,address,string,string)",
        p0,
        p1,
        p2,
        p3
      )
    );
  }

  function log(
    string memory p0,
    address p1,
    string memory p2,
    bool p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(string,address,string,bool)", p0, p1, p2, p3)
    );
  }

  function log(
    string memory p0,
    address p1,
    string memory p2,
    address p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature(
        "log(string,address,string,address)",
        p0,
        p1,
        p2,
        p3
      )
    );
  }

  function log(
    string memory p0,
    address p1,
    bool p2,
    uint256 p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(string,address,bool,uint)", p0, p1, p2, p3)
    );
  }

  function log(
    string memory p0,
    address p1,
    bool p2,
    string memory p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(string,address,bool,string)", p0, p1, p2, p3)
    );
  }

  function log(
    string memory p0,
    address p1,
    bool p2,
    bool p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(string,address,bool,bool)", p0, p1, p2, p3)
    );
  }

  function log(
    string memory p0,
    address p1,
    bool p2,
    address p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature(
        "log(string,address,bool,address)",
        p0,
        p1,
        p2,
        p3
      )
    );
  }

  function log(
    string memory p0,
    address p1,
    address p2,
    uint256 p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature(
        "log(string,address,address,uint)",
        p0,
        p1,
        p2,
        p3
      )
    );
  }

  function log(
    string memory p0,
    address p1,
    address p2,
    string memory p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature(
        "log(string,address,address,string)",
        p0,
        p1,
        p2,
        p3
      )
    );
  }

  function log(
    string memory p0,
    address p1,
    address p2,
    bool p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature(
        "log(string,address,address,bool)",
        p0,
        p1,
        p2,
        p3
      )
    );
  }

  function log(
    string memory p0,
    address p1,
    address p2,
    address p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature(
        "log(string,address,address,address)",
        p0,
        p1,
        p2,
        p3
      )
    );
  }

  function log(
    bool p0,
    uint256 p1,
    uint256 p2,
    uint256 p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(bool,uint,uint,uint)", p0, p1, p2, p3)
    );
  }

  function log(
    bool p0,
    uint256 p1,
    uint256 p2,
    string memory p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(bool,uint,uint,string)", p0, p1, p2, p3)
    );
  }

  function log(
    bool p0,
    uint256 p1,
    uint256 p2,
    bool p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(bool,uint,uint,bool)", p0, p1, p2, p3)
    );
  }

  function log(
    bool p0,
    uint256 p1,
    uint256 p2,
    address p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(bool,uint,uint,address)", p0, p1, p2, p3)
    );
  }

  function log(
    bool p0,
    uint256 p1,
    string memory p2,
    uint256 p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(bool,uint,string,uint)", p0, p1, p2, p3)
    );
  }

  function log(
    bool p0,
    uint256 p1,
    string memory p2,
    string memory p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(bool,uint,string,string)", p0, p1, p2, p3)
    );
  }

  function log(
    bool p0,
    uint256 p1,
    string memory p2,
    bool p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(bool,uint,string,bool)", p0, p1, p2, p3)
    );
  }

  function log(
    bool p0,
    uint256 p1,
    string memory p2,
    address p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(bool,uint,string,address)", p0, p1, p2, p3)
    );
  }

  function log(
    bool p0,
    uint256 p1,
    bool p2,
    uint256 p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(bool,uint,bool,uint)", p0, p1, p2, p3)
    );
  }

  function log(
    bool p0,
    uint256 p1,
    bool p2,
    string memory p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(bool,uint,bool,string)", p0, p1, p2, p3)
    );
  }

  function log(
    bool p0,
    uint256 p1,
    bool p2,
    bool p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(bool,uint,bool,bool)", p0, p1, p2, p3)
    );
  }

  function log(
    bool p0,
    uint256 p1,
    bool p2,
    address p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(bool,uint,bool,address)", p0, p1, p2, p3)
    );
  }

  function log(
    bool p0,
    uint256 p1,
    address p2,
    uint256 p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(bool,uint,address,uint)", p0, p1, p2, p3)
    );
  }

  function log(
    bool p0,
    uint256 p1,
    address p2,
    string memory p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(bool,uint,address,string)", p0, p1, p2, p3)
    );
  }

  function log(
    bool p0,
    uint256 p1,
    address p2,
    bool p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(bool,uint,address,bool)", p0, p1, p2, p3)
    );
  }

  function log(
    bool p0,
    uint256 p1,
    address p2,
    address p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(bool,uint,address,address)", p0, p1, p2, p3)
    );
  }

  function log(
    bool p0,
    string memory p1,
    uint256 p2,
    uint256 p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(bool,string,uint,uint)", p0, p1, p2, p3)
    );
  }

  function log(
    bool p0,
    string memory p1,
    uint256 p2,
    string memory p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(bool,string,uint,string)", p0, p1, p2, p3)
    );
  }

  function log(
    bool p0,
    string memory p1,
    uint256 p2,
    bool p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(bool,string,uint,bool)", p0, p1, p2, p3)
    );
  }

  function log(
    bool p0,
    string memory p1,
    uint256 p2,
    address p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(bool,string,uint,address)", p0, p1, p2, p3)
    );
  }

  function log(
    bool p0,
    string memory p1,
    string memory p2,
    uint256 p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(bool,string,string,uint)", p0, p1, p2, p3)
    );
  }

  function log(
    bool p0,
    string memory p1,
    string memory p2,
    string memory p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(bool,string,string,string)", p0, p1, p2, p3)
    );
  }

  function log(
    bool p0,
    string memory p1,
    string memory p2,
    bool p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(bool,string,string,bool)", p0, p1, p2, p3)
    );
  }

  function log(
    bool p0,
    string memory p1,
    string memory p2,
    address p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(bool,string,string,address)", p0, p1, p2, p3)
    );
  }

  function log(
    bool p0,
    string memory p1,
    bool p2,
    uint256 p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(bool,string,bool,uint)", p0, p1, p2, p3)
    );
  }

  function log(
    bool p0,
    string memory p1,
    bool p2,
    string memory p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(bool,string,bool,string)", p0, p1, p2, p3)
    );
  }

  function log(
    bool p0,
    string memory p1,
    bool p2,
    bool p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(bool,string,bool,bool)", p0, p1, p2, p3)
    );
  }

  function log(
    bool p0,
    string memory p1,
    bool p2,
    address p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(bool,string,bool,address)", p0, p1, p2, p3)
    );
  }

  function log(
    bool p0,
    string memory p1,
    address p2,
    uint256 p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(bool,string,address,uint)", p0, p1, p2, p3)
    );
  }

  function log(
    bool p0,
    string memory p1,
    address p2,
    string memory p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(bool,string,address,string)", p0, p1, p2, p3)
    );
  }

  function log(
    bool p0,
    string memory p1,
    address p2,
    bool p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(bool,string,address,bool)", p0, p1, p2, p3)
    );
  }

  function log(
    bool p0,
    string memory p1,
    address p2,
    address p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature(
        "log(bool,string,address,address)",
        p0,
        p1,
        p2,
        p3
      )
    );
  }

  function log(
    bool p0,
    bool p1,
    uint256 p2,
    uint256 p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(bool,bool,uint,uint)", p0, p1, p2, p3)
    );
  }

  function log(
    bool p0,
    bool p1,
    uint256 p2,
    string memory p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(bool,bool,uint,string)", p0, p1, p2, p3)
    );
  }

  function log(
    bool p0,
    bool p1,
    uint256 p2,
    bool p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(bool,bool,uint,bool)", p0, p1, p2, p3)
    );
  }

  function log(
    bool p0,
    bool p1,
    uint256 p2,
    address p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(bool,bool,uint,address)", p0, p1, p2, p3)
    );
  }

  function log(
    bool p0,
    bool p1,
    string memory p2,
    uint256 p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(bool,bool,string,uint)", p0, p1, p2, p3)
    );
  }

  function log(
    bool p0,
    bool p1,
    string memory p2,
    string memory p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(bool,bool,string,string)", p0, p1, p2, p3)
    );
  }

  function log(
    bool p0,
    bool p1,
    string memory p2,
    bool p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(bool,bool,string,bool)", p0, p1, p2, p3)
    );
  }

  function log(
    bool p0,
    bool p1,
    string memory p2,
    address p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(bool,bool,string,address)", p0, p1, p2, p3)
    );
  }

  function log(
    bool p0,
    bool p1,
    bool p2,
    uint256 p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(bool,bool,bool,uint)", p0, p1, p2, p3)
    );
  }

  function log(
    bool p0,
    bool p1,
    bool p2,
    string memory p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(bool,bool,bool,string)", p0, p1, p2, p3)
    );
  }

  function log(
    bool p0,
    bool p1,
    bool p2,
    bool p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(bool,bool,bool,bool)", p0, p1, p2, p3)
    );
  }

  function log(
    bool p0,
    bool p1,
    bool p2,
    address p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(bool,bool,bool,address)", p0, p1, p2, p3)
    );
  }

  function log(
    bool p0,
    bool p1,
    address p2,
    uint256 p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(bool,bool,address,uint)", p0, p1, p2, p3)
    );
  }

  function log(
    bool p0,
    bool p1,
    address p2,
    string memory p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(bool,bool,address,string)", p0, p1, p2, p3)
    );
  }

  function log(
    bool p0,
    bool p1,
    address p2,
    bool p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(bool,bool,address,bool)", p0, p1, p2, p3)
    );
  }

  function log(
    bool p0,
    bool p1,
    address p2,
    address p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(bool,bool,address,address)", p0, p1, p2, p3)
    );
  }

  function log(
    bool p0,
    address p1,
    uint256 p2,
    uint256 p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(bool,address,uint,uint)", p0, p1, p2, p3)
    );
  }

  function log(
    bool p0,
    address p1,
    uint256 p2,
    string memory p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(bool,address,uint,string)", p0, p1, p2, p3)
    );
  }

  function log(
    bool p0,
    address p1,
    uint256 p2,
    bool p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(bool,address,uint,bool)", p0, p1, p2, p3)
    );
  }

  function log(
    bool p0,
    address p1,
    uint256 p2,
    address p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(bool,address,uint,address)", p0, p1, p2, p3)
    );
  }

  function log(
    bool p0,
    address p1,
    string memory p2,
    uint256 p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(bool,address,string,uint)", p0, p1, p2, p3)
    );
  }

  function log(
    bool p0,
    address p1,
    string memory p2,
    string memory p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(bool,address,string,string)", p0, p1, p2, p3)
    );
  }

  function log(
    bool p0,
    address p1,
    string memory p2,
    bool p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(bool,address,string,bool)", p0, p1, p2, p3)
    );
  }

  function log(
    bool p0,
    address p1,
    string memory p2,
    address p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature(
        "log(bool,address,string,address)",
        p0,
        p1,
        p2,
        p3
      )
    );
  }

  function log(
    bool p0,
    address p1,
    bool p2,
    uint256 p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(bool,address,bool,uint)", p0, p1, p2, p3)
    );
  }

  function log(
    bool p0,
    address p1,
    bool p2,
    string memory p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(bool,address,bool,string)", p0, p1, p2, p3)
    );
  }

  function log(
    bool p0,
    address p1,
    bool p2,
    bool p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(bool,address,bool,bool)", p0, p1, p2, p3)
    );
  }

  function log(
    bool p0,
    address p1,
    bool p2,
    address p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(bool,address,bool,address)", p0, p1, p2, p3)
    );
  }

  function log(
    bool p0,
    address p1,
    address p2,
    uint256 p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(bool,address,address,uint)", p0, p1, p2, p3)
    );
  }

  function log(
    bool p0,
    address p1,
    address p2,
    string memory p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature(
        "log(bool,address,address,string)",
        p0,
        p1,
        p2,
        p3
      )
    );
  }

  function log(
    bool p0,
    address p1,
    address p2,
    bool p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(bool,address,address,bool)", p0, p1, p2, p3)
    );
  }

  function log(
    bool p0,
    address p1,
    address p2,
    address p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature(
        "log(bool,address,address,address)",
        p0,
        p1,
        p2,
        p3
      )
    );
  }

  function log(
    address p0,
    uint256 p1,
    uint256 p2,
    uint256 p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(address,uint,uint,uint)", p0, p1, p2, p3)
    );
  }

  function log(
    address p0,
    uint256 p1,
    uint256 p2,
    string memory p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(address,uint,uint,string)", p0, p1, p2, p3)
    );
  }

  function log(
    address p0,
    uint256 p1,
    uint256 p2,
    bool p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(address,uint,uint,bool)", p0, p1, p2, p3)
    );
  }

  function log(
    address p0,
    uint256 p1,
    uint256 p2,
    address p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(address,uint,uint,address)", p0, p1, p2, p3)
    );
  }

  function log(
    address p0,
    uint256 p1,
    string memory p2,
    uint256 p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(address,uint,string,uint)", p0, p1, p2, p3)
    );
  }

  function log(
    address p0,
    uint256 p1,
    string memory p2,
    string memory p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(address,uint,string,string)", p0, p1, p2, p3)
    );
  }

  function log(
    address p0,
    uint256 p1,
    string memory p2,
    bool p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(address,uint,string,bool)", p0, p1, p2, p3)
    );
  }

  function log(
    address p0,
    uint256 p1,
    string memory p2,
    address p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature(
        "log(address,uint,string,address)",
        p0,
        p1,
        p2,
        p3
      )
    );
  }

  function log(
    address p0,
    uint256 p1,
    bool p2,
    uint256 p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(address,uint,bool,uint)", p0, p1, p2, p3)
    );
  }

  function log(
    address p0,
    uint256 p1,
    bool p2,
    string memory p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(address,uint,bool,string)", p0, p1, p2, p3)
    );
  }

  function log(
    address p0,
    uint256 p1,
    bool p2,
    bool p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(address,uint,bool,bool)", p0, p1, p2, p3)
    );
  }

  function log(
    address p0,
    uint256 p1,
    bool p2,
    address p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(address,uint,bool,address)", p0, p1, p2, p3)
    );
  }

  function log(
    address p0,
    uint256 p1,
    address p2,
    uint256 p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(address,uint,address,uint)", p0, p1, p2, p3)
    );
  }

  function log(
    address p0,
    uint256 p1,
    address p2,
    string memory p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature(
        "log(address,uint,address,string)",
        p0,
        p1,
        p2,
        p3
      )
    );
  }

  function log(
    address p0,
    uint256 p1,
    address p2,
    bool p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(address,uint,address,bool)", p0, p1, p2, p3)
    );
  }

  function log(
    address p0,
    uint256 p1,
    address p2,
    address p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature(
        "log(address,uint,address,address)",
        p0,
        p1,
        p2,
        p3
      )
    );
  }

  function log(
    address p0,
    string memory p1,
    uint256 p2,
    uint256 p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(address,string,uint,uint)", p0, p1, p2, p3)
    );
  }

  function log(
    address p0,
    string memory p1,
    uint256 p2,
    string memory p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(address,string,uint,string)", p0, p1, p2, p3)
    );
  }

  function log(
    address p0,
    string memory p1,
    uint256 p2,
    bool p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(address,string,uint,bool)", p0, p1, p2, p3)
    );
  }

  function log(
    address p0,
    string memory p1,
    uint256 p2,
    address p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature(
        "log(address,string,uint,address)",
        p0,
        p1,
        p2,
        p3
      )
    );
  }

  function log(
    address p0,
    string memory p1,
    string memory p2,
    uint256 p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(address,string,string,uint)", p0, p1, p2, p3)
    );
  }

  function log(
    address p0,
    string memory p1,
    string memory p2,
    string memory p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature(
        "log(address,string,string,string)",
        p0,
        p1,
        p2,
        p3
      )
    );
  }

  function log(
    address p0,
    string memory p1,
    string memory p2,
    bool p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(address,string,string,bool)", p0, p1, p2, p3)
    );
  }

  function log(
    address p0,
    string memory p1,
    string memory p2,
    address p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature(
        "log(address,string,string,address)",
        p0,
        p1,
        p2,
        p3
      )
    );
  }

  function log(
    address p0,
    string memory p1,
    bool p2,
    uint256 p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(address,string,bool,uint)", p0, p1, p2, p3)
    );
  }

  function log(
    address p0,
    string memory p1,
    bool p2,
    string memory p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(address,string,bool,string)", p0, p1, p2, p3)
    );
  }

  function log(
    address p0,
    string memory p1,
    bool p2,
    bool p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(address,string,bool,bool)", p0, p1, p2, p3)
    );
  }

  function log(
    address p0,
    string memory p1,
    bool p2,
    address p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature(
        "log(address,string,bool,address)",
        p0,
        p1,
        p2,
        p3
      )
    );
  }

  function log(
    address p0,
    string memory p1,
    address p2,
    uint256 p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature(
        "log(address,string,address,uint)",
        p0,
        p1,
        p2,
        p3
      )
    );
  }

  function log(
    address p0,
    string memory p1,
    address p2,
    string memory p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature(
        "log(address,string,address,string)",
        p0,
        p1,
        p2,
        p3
      )
    );
  }

  function log(
    address p0,
    string memory p1,
    address p2,
    bool p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature(
        "log(address,string,address,bool)",
        p0,
        p1,
        p2,
        p3
      )
    );
  }

  function log(
    address p0,
    string memory p1,
    address p2,
    address p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature(
        "log(address,string,address,address)",
        p0,
        p1,
        p2,
        p3
      )
    );
  }

  function log(
    address p0,
    bool p1,
    uint256 p2,
    uint256 p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(address,bool,uint,uint)", p0, p1, p2, p3)
    );
  }

  function log(
    address p0,
    bool p1,
    uint256 p2,
    string memory p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(address,bool,uint,string)", p0, p1, p2, p3)
    );
  }

  function log(
    address p0,
    bool p1,
    uint256 p2,
    bool p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(address,bool,uint,bool)", p0, p1, p2, p3)
    );
  }

  function log(
    address p0,
    bool p1,
    uint256 p2,
    address p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(address,bool,uint,address)", p0, p1, p2, p3)
    );
  }

  function log(
    address p0,
    bool p1,
    string memory p2,
    uint256 p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(address,bool,string,uint)", p0, p1, p2, p3)
    );
  }

  function log(
    address p0,
    bool p1,
    string memory p2,
    string memory p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(address,bool,string,string)", p0, p1, p2, p3)
    );
  }

  function log(
    address p0,
    bool p1,
    string memory p2,
    bool p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(address,bool,string,bool)", p0, p1, p2, p3)
    );
  }

  function log(
    address p0,
    bool p1,
    string memory p2,
    address p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature(
        "log(address,bool,string,address)",
        p0,
        p1,
        p2,
        p3
      )
    );
  }

  function log(
    address p0,
    bool p1,
    bool p2,
    uint256 p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(address,bool,bool,uint)", p0, p1, p2, p3)
    );
  }

  function log(
    address p0,
    bool p1,
    bool p2,
    string memory p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(address,bool,bool,string)", p0, p1, p2, p3)
    );
  }

  function log(
    address p0,
    bool p1,
    bool p2,
    bool p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(address,bool,bool,bool)", p0, p1, p2, p3)
    );
  }

  function log(
    address p0,
    bool p1,
    bool p2,
    address p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(address,bool,bool,address)", p0, p1, p2, p3)
    );
  }

  function log(
    address p0,
    bool p1,
    address p2,
    uint256 p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(address,bool,address,uint)", p0, p1, p2, p3)
    );
  }

  function log(
    address p0,
    bool p1,
    address p2,
    string memory p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature(
        "log(address,bool,address,string)",
        p0,
        p1,
        p2,
        p3
      )
    );
  }

  function log(
    address p0,
    bool p1,
    address p2,
    bool p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(address,bool,address,bool)", p0, p1, p2, p3)
    );
  }

  function log(
    address p0,
    bool p1,
    address p2,
    address p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature(
        "log(address,bool,address,address)",
        p0,
        p1,
        p2,
        p3
      )
    );
  }

  function log(
    address p0,
    address p1,
    uint256 p2,
    uint256 p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(address,address,uint,uint)", p0, p1, p2, p3)
    );
  }

  function log(
    address p0,
    address p1,
    uint256 p2,
    string memory p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature(
        "log(address,address,uint,string)",
        p0,
        p1,
        p2,
        p3
      )
    );
  }

  function log(
    address p0,
    address p1,
    uint256 p2,
    bool p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(address,address,uint,bool)", p0, p1, p2, p3)
    );
  }

  function log(
    address p0,
    address p1,
    uint256 p2,
    address p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature(
        "log(address,address,uint,address)",
        p0,
        p1,
        p2,
        p3
      )
    );
  }

  function log(
    address p0,
    address p1,
    string memory p2,
    uint256 p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature(
        "log(address,address,string,uint)",
        p0,
        p1,
        p2,
        p3
      )
    );
  }

  function log(
    address p0,
    address p1,
    string memory p2,
    string memory p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature(
        "log(address,address,string,string)",
        p0,
        p1,
        p2,
        p3
      )
    );
  }

  function log(
    address p0,
    address p1,
    string memory p2,
    bool p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature(
        "log(address,address,string,bool)",
        p0,
        p1,
        p2,
        p3
      )
    );
  }

  function log(
    address p0,
    address p1,
    string memory p2,
    address p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature(
        "log(address,address,string,address)",
        p0,
        p1,
        p2,
        p3
      )
    );
  }

  function log(
    address p0,
    address p1,
    bool p2,
    uint256 p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(address,address,bool,uint)", p0, p1, p2, p3)
    );
  }

  function log(
    address p0,
    address p1,
    bool p2,
    string memory p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature(
        "log(address,address,bool,string)",
        p0,
        p1,
        p2,
        p3
      )
    );
  }

  function log(
    address p0,
    address p1,
    bool p2,
    bool p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(address,address,bool,bool)", p0, p1, p2, p3)
    );
  }

  function log(
    address p0,
    address p1,
    bool p2,
    address p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature(
        "log(address,address,bool,address)",
        p0,
        p1,
        p2,
        p3
      )
    );
  }

  function log(
    address p0,
    address p1,
    address p2,
    uint256 p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature(
        "log(address,address,address,uint)",
        p0,
        p1,
        p2,
        p3
      )
    );
  }

  function log(
    address p0,
    address p1,
    address p2,
    string memory p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature(
        "log(address,address,address,string)",
        p0,
        p1,
        p2,
        p3
      )
    );
  }

  function log(
    address p0,
    address p1,
    address p2,
    bool p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature(
        "log(address,address,address,bool)",
        p0,
        p1,
        p2,
        p3
      )
    );
  }

  function log(
    address p0,
    address p1,
    address p2,
    address p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature(
        "log(address,address,address,address)",
        p0,
        p1,
        p2,
        p3
      )
    );
  }
}

// File: contracts/Strategy.sol

pragma solidity 0.8.0;

contract Strategy is Checkpoint {
  event StrategyFollowed(
    address userFollowed,
    uint256 userAmount,
    address trader,
    uint256 checkpointId
  );
  event StrategyUnfollowed(
    address userunFollowed,
    uint256 userAmountClaimed,
    uint256 checkpointId
  );
  modifier isStrategyActive() {
    require(
      status == StrategyStatus.ACTIVE,
      "Strategy::isStrategyActive: STRATEGY_INACTIVE"
    );
    _;
  }

  modifier onlyTrader() {
    require(msg.sender == trader, "Strategy::onlyTrader: INVALID_SENDER");
    _;
  }

  modifier onlyUser() {
    require(
      userInfo[msg.sender].depositAmount > 0,
      "Strategy::onlyTrader: INVALID_USER"
    );
    _;
  }

  constructor(
    address _predictionMarket,
    string memory _name,
    address payable _trader
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
    traderFund += msg.value;

    status = StrategyStatus.ACTIVE;
  }

  function follow() public payable isStrategyActive {
    User storage user = userInfo[msg.sender];

    require(msg.value > 0, "Strategy::follow: ZERO_FUNDS");
    require(user.depositAmount == 0, "Strategy::follow: ALREADY_FOLLOWING");

    totalUserFunds += msg.value;

    user.depositAmount = msg.value;
    users.push(msg.sender);
    console.log("users: ", users[0]);
    //get total volume (trader + all users)
    addCheckpoint(users, (totalUserFunds + traderFund));
    user.entryCheckpointId = latestCheckpointId;
    emit StrategyFollowed(msg.sender, msg.value, trader, latestCheckpointId);
  }

  //unfollow is subjected to fund availability
  function unfollow() public onlyUser {
    User storage user = userInfo[msg.sender];
    user.exitCheckpointId = latestCheckpointId;
    (
      uint256 userClaimAmount,
      uint256 userTotalProfit,
      uint256 userTotalLoss
    ) = getUserClaimAmount(user);
    (payable(msg.sender)).transfer(userClaimAmount);
    user.totalProfit = userTotalProfit;
    user.totalLoss = userTotalLoss;

    totalUserFunds -= userClaimAmount;
    for (uint256 userIndex = 0; userIndex < users.length; userIndex++) {
      if (users[userIndex] == msg.sender) {
        delete users[userIndex];
        break;
      }
    }
    addCheckpoint(users, (totalUserFunds + traderFund));

    emit StrategyUnfollowed(
      msg.sender,
      userClaimAmount,
      latestCheckpointId - 1
    );
  }

  //get user claim amount. deduct fees from profit
  // update exitpoint
  // transfer amt
  // add new checkpoint, pop the user from array, update userfund
  // update user(if any)

  // for getting USer claim amount
  function getUserClaimAmount(User memory userDetails)
    internal
    view
    returns (
      uint256 userClaimAmount,
      uint256 userTotalProfit,
      uint256 userTotalLoss
    )
  {
    for (
      uint256 cpIndex = userDetails.entryCheckpointId;
      cpIndex < userDetails.exitCheckpointId;
      cpIndex++
    ) {
      Checkpoint memory cp = checkpoints[cpIndex];

      uint256 userProfit = (cp.totalProfit * userDetails.depositAmount) /
        cp.totalVolume;
      userTotalLoss +=
        (cp.totalLoss * userDetails.depositAmount) /
        cp.totalVolume;

      userTotalProfit += userProfit - calculateFees(userProfit);
    }
    userClaimAmount =
      userDetails.depositAmount +
      userTotalProfit -
      userTotalLoss;
    return (userClaimAmount, userTotalProfit, userTotalLoss);
  }

  function removeTraderFund() public onlyTrader {
    if (status == StrategyStatus.ACTIVE) status = StrategyStatus.INACTIVE;
    uint256 amount = getClaimAmount();
    traderFund -= amount;
    trader.transfer(amount);
  }

  // for getting Trader claim amount
  function getClaimAmount() internal view returns (uint256 traderClaimAmount) {
    uint256 traderTotalProfit;
    uint256 traderTotalLoss;
    for (uint256 cpIndex = 0; cpIndex < latestCheckpointId; cpIndex++) {
      Checkpoint memory cp = checkpoints[cpIndex];
      uint256 traderProfit = (cp.totalProfit * traderFund) / cp.totalVolume;
      traderTotalLoss += (cp.totalLoss * traderFund) / cp.totalVolume;

      uint256 userProfit = cp.totalProfit - traderProfit;
      traderTotalProfit += traderProfit + calculateFees(userProfit);
    }
    traderClaimAmount = traderFund + traderTotalProfit - traderTotalLoss;
  }

  //fuction to calculate fees
  function calculateFees(uint256 amount)
    internal
    view
    returns (uint256 feeAmount)
  {
    feeAmount = (amount * traderFees) / 10000;
  }

  function bet(
    uint256 _conditionIndex,
    uint8 _side,
    uint256 _amount
  ) public isStrategyActive onlyTrader {
    require(latestCheckpointId > 0, "Strategy::bet: NO CHECKPOINT CREATED YET");

    require(users.length > 0, "Strategy::bet: NO USERS EXIST");

    uint256 percentage = (_amount * 100) / traderFund;
    require(
      percentage < 5,
      "Strategy::placeBet:INVALID AMOUNT. Percentage > 5"
    );

    uint256 betAmount = (percentage * totalUserFunds) / 100;

    Checkpoint memory checkpoint = checkpoints[latestCheckpointId];
    checkpoint.totalInvested += betAmount;
    conditionIndexToCheckpoints[_conditionIndex].push(latestCheckpointId);

    Market memory market;
    if (_side == 0) {
      market.lowBets = betAmount;
    } else {
      market.highBets = betAmount;
    }
    markets[latestCheckpointId][_conditionIndex] = market;
  }

  function claim(uint256 _conditionIndex) public isStrategyActive onlyTrader {
    (uint8 winningSide, uint256 perBetPrice) = predictionMarket
    .getPerUserClaimAmount(_conditionIndex);
    predictionMarket.claim(_conditionIndex);

    (
      ,
      ,
      ,
      ,
      ,
      ,
      address lowBetToken,
      address highBetToken,
      ,

    ) = predictionMarket.conditions(_conditionIndex);

    IBetToken highBet = IBetToken(highBetToken);
    IBetToken lowBet = IBetToken(lowBetToken);

    uint256 totalInvested;
    uint256[] memory checkpointList = conditionIndexToCheckpoints[
      _conditionIndex
    ];
    for (uint256 index = 0; index < checkpointList.length; index++) {
      Market memory market = markets[checkpointList[index]][_conditionIndex];
      Checkpoint memory cp = checkpoints[checkpointList[index]];

      uint256 profit;
      uint256 loss;

      if (winningSide == 1 && market.highBets > 0) {
        profit = market.highBets * perBetPrice;
        loss = market.lowBets;
      } else {
        profit = market.lowBets * perBetPrice;
        loss = market.highBets;
      }

      cp.totalProfit += profit;
      cp.totalLoss += loss;

      totalUserFunds = totalUserFunds + profit - loss;
    }
  }

  function getConditionDetails(uint256 _conditionIndex)
    public
    view
    returns (
      string memory market,
      uint256 settlementTime,
      bool isSettled
    )
  {
    (market, , , settlementTime, isSettled, , , , , ) = (
      predictionMarket.conditions(_conditionIndex)
    );
  }
}

// File: contracts/StrategyFactory.sol

pragma solidity 0.8.0;

contract StrategyFactory {
  IPredictionMarket public predictionMarket;
  uint256 public traderId;

  mapping(address => uint256[]) public traderStrategies;

  event StrategyCreated(
    string trader,
    uint256 id,
    uint256 amount,
    address strategyAddress
  );

  constructor(address _predictionMarket) {
    require(
      _predictionMarket != address(0),
      "StrategyFactory::constructor:INVALID PRDICTION MARKET ADDRESS."
    );
    predictionMarket = IPredictionMarket(_predictionMarket);
  }

  function createStrategy(string memory _name)
    external
    payable
    returns (uint256)
  {
    require(
      msg.value > 0,
      "StrategyFactory::createStrategy: ZERO_DEPOSIT_FUND"
    );

    traderId = traderId + 1;
    traderStrategies[msg.sender].push(traderId);

    Strategy strategy = new Strategy{value: msg.value}(
      address(predictionMarket),
      _name,
      payable(msg.sender)
    );
    emit StrategyCreated(_name, traderId, msg.value, address(strategy));

    return traderId;
  }
}
