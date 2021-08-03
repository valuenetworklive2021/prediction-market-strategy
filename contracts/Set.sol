//SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.0;

contract Set {
    address immutable controller;
    address[] items;
    mapping(address => uint256) presence;

    constructor(address controller_) {
        controller = controller_ == address(0) ? msg.sender : controller_;
    }

    function size() public view returns (uint256) {
        return items.length;
    }

    function has(address item) public view returns (bool) {
        return presence[item] > 0;
    }

    function indexOf(address item) public view returns (uint256) {
        return presence[item] - 1;
    }

    function get(uint256 index) public view returns (address) {
        return items[index];
    }

    function add(address item) public {
        require(msg.sender == controller, "Sender does not own this set.");

        if (presence[item] == 0) {
            items.push(item);
            presence[item] = items.length; // index plus one
        }
    }

    function remove(address item) public {
        require(msg.sender == controller, "Sender does not own this set.");

        if (presence[item] > 0) {
            uint256 index = presence[item] - 1;
            presence[item] = 0;
            presence[items[items.length - 1]] = index + 1;
            items[index] = items[items.length - 1];
            items.pop();
        }
    }

    function clear() public {
        require(msg.sender == controller, "Sender does not own this set.");

        for (uint256 i = 0; i < items.length; i++) {
            presence[items[i]] = 0;
        }

        delete items;
    }

    function destroy() public {
        require(msg.sender == controller, "Sender does not own this set.");
        selfdestruct(payable(msg.sender));
    }
}
