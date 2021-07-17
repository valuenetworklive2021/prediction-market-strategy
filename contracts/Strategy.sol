pragma solidity 0.8.0;

import "./interfaces/IPredictionMarket.sol";

contract Strategy {
    IPredictionMarket public predictionMarket;
    string public traderName;
    address public traderAddress;

    constructor(
        address _predictionMarket,
        string memory _name,
        address _trader
    ) {
        require(_trader != address(0),"Strategy::constructor:INVALID TRADER ADDRESS.");
        require(_predictionMarket != address(0),"Strategy::constructor:INVALID PRDICTION MARKET ADDRESS.");
        predictionMarket = IPredictionMarket(_predictionMarket);
        traderName = _name;
        traderAddress = _trader;
    }

    function addUserFund() public payable {
        require(msg.value > 0, "Strategy::addUserFund:SEND SOME FUNDS.");
        User storage user = userInfo[msg.sender];
        user.userFund += msg.value;
        user.userBalance += msg.value;
        userVolume += msg.value;
        users.push(msg.sender);
    }

    function addTraderFund() public payable {
        require(msg.value > 0, "Strategy::addTraderFund:SEND SOME FUNDS.");
        traderFund += msg.value;
        traderBalance += msg.value;
    }

    function removeUserFund(uint256 _amount) public {
        User storage user = userInfo[msg.sender];

        require(
            amount > 0 && amount <= user.userBalance,
            "Strategy::removeUserFund:INVALID AMOUNT."
        );
        user.userFund -= amount;
        user.userBalance -= amount;
        userVolume -= amount;

        (msg.sender).transfer(amount);
    }

    function removeTraderFund(uint256 _amount) public {
        require(
            amount > 0 && amount <= traderBalance,
            "Strategy::removeUserFund:INVALID AMOUNT."
        );
        traderFund -= amount;
        traderBalance -= amount;

        (msg.sender).transfer(amount);
    }

    function placeBet(
        uint256 _conditionIndex,
        uint8 _side,
        uint256 _amount
    ) public {}

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
