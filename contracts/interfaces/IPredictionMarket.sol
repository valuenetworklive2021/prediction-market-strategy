//SPDX-License-Identifier: UNLICENSED
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

    function claim(uint256 _conditionIndex) external returns (uint256, uint8);

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
