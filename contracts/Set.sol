//SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.0;

contract Set {
    address public controller;
    address[] users;
    mapping(address => uint256) isUser;

    modifier isController() {
        require(msg.sender == controller, "Set: INVALID_SENDER");
        _;
    }

    constructor(address controller_) {
        controller = controller_ == address(0) ? msg.sender : controller_;
    }

    function updateController(address _newController)
        external
        isController
        returns (uint256)
    {
        controller = _newController;
    }

    function size() external view returns (uint256) {
        return users.length;
    }

    function has(address item) external view returns (bool) {
        return isUser[item] > 0;
    }

    function indexOf(address item) external view returns (uint256) {
        return isUser[item] - 1;
    }

    function get(uint256 index) external view returns (address) {
        return users[index];
    }

    function add(address item) external isController {
        if (isUser[item] == 0) {
            users.push(item);
            isUser[item] = users.length; // index plus one
        }
    }

    function remove(address item) external isController {
        if (isUser[item] > 0) {
            uint256 index = isUser[item] - 1;
            isUser[item] = 0;
            isUser[users[users.length - 1]] = index + 1;
            users[index] = users[users.length - 1];
            users.pop();
        }
    }

    function clear() external isController {
        for (uint256 i = 0; i < users.length; i++) {
            isUser[users[i]] = 0;
        }

        delete users;
    }

    function destroy() external isController {
        selfdestruct(payable(msg.sender));
    }
}
