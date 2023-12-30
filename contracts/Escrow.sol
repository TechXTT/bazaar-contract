// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.0;

contract TimedEscrow {
    struct Order {
        address buyer;
        address receiver;
        uint256 amount;
        uint256 releaseTime;
        bool completed;
    }

    mapping(bytes32 => Order) public orders;
    mapping(address => bytes32[]) public userOrders;

    event OrderCreated(bytes32 orderId, address indexed buyer, address indexed receiver, uint256 amount, uint256 releaseTime);
    event OrderCompleted(bytes32 orderId);

    function createOrder(bytes32 orderId, address _receiver, uint256 _releaseTime) external payable {
        require(_receiver != address(0), "Invalid receiver address");
        require(msg.value > 0, "Amount must be greater than 0");
        require(orders[orderId].buyer == address(0), "Order ID already exists");

        orders[orderId] = Order({
            buyer: msg.sender,
            receiver: _receiver,
            amount: msg.value,
            releaseTime: block.timestamp + _releaseTime,
            completed: false
        });

        userOrders[_receiver].push(orderId);

        emit OrderCreated(orderId, msg.sender, _receiver, msg.value, block.timestamp + _releaseTime);
    }

    function claimOrders(bytes32[] memory orderIds) external {
        uint256 totalAmount = 0;

        for (uint256 i = 0; i < orderIds.length; i++) {
            Order storage orderInfo = orders[orderIds[i]];
            require(orderInfo.receiver == msg.sender, "Only reciever can claim");
            require(block.timestamp >= orderInfo.releaseTime, "Release time not reached");
            require(!orderInfo.completed, "Order already completed");

            totalAmount += orderInfo.amount;
            orderInfo.completed = true;
            emit OrderCompleted(orderIds[i]);
        }

        require(totalAmount > 0, "No orders to claim");

        payable(msg.sender).transfer(totalAmount);
    }

    function getUserOrders(address user) external view returns (bytes32[] memory) {
        return userOrders[user];
    }
}
