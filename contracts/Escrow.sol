// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";

contract Escrow is AccessControl {
    constructor() {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    struct Order {
        address buyer;
        address receiver;
        uint256 amount;
        uint256 releaseTime;
        bool release;
        bool completed;
    }

    mapping(bytes32 => Order) public orders;
    mapping(address => bytes32[]) public incompleteOrders;
    mapping(address => bytes32[]) public completeOrders;

    event OrderCreated(bytes32 orderId, address indexed buyer, address indexed receiver, uint256 amount, uint256 releaseTime);
    event OrderCompleted(bytes32 orderId);
    event OrderReleased(bytes32 orderId);
    event OrderRefunded(bytes32 orderId);

    function releaseOrder(bytes32 orderId) external {
        require(orders[orderId].buyer != address(0), "Order ID does not exist");
        Order storage orderInfo = orders[orderId];
        require(hasRole(getRoleAdmin(DEFAULT_ADMIN_ROLE), _msgSender()), "Only admin can release");
        require(!orderInfo.release, "Order already released");

        orderInfo.release = true;
        emit OrderReleased(orderId);
    }

    function refundOrder(bytes32 orderId) external {
        require(orders[orderId].buyer != address(0), "Order ID does not exist");
        Order storage orderInfo = orders[orderId];
        require(hasRole(getRoleAdmin(DEFAULT_ADMIN_ROLE), _msgSender()), "Only admin can refund");
        require(!orderInfo.completed, "Order already completed");

        orderInfo.completed = true;
        emit OrderRefunded(orderId);

        payable(orderInfo.buyer).transfer(orderInfo.amount);
    }

    function createOrder(bytes32 orderId, address _receiver, uint256 _releaseTime) external payable {
        require(_releaseTime > 0, "Release time must be greater than 0");
        require(_receiver != address(0), "Invalid receiver address");
        require(msg.sender != _receiver, "Buyer and receiver cannot be the same");
        require(msg.value > 0, "Amount must be greater than 0");
        require(orders[orderId].buyer == address(0), "Order ID already exists");

        orders[orderId] = Order({
            buyer: msg.sender,
            receiver: _receiver,
            amount: msg.value,
            releaseTime: block.timestamp + _releaseTime,
            release: false,
            completed: false
        });

        incompleteOrders[msg.sender].push(orderId);

        emit OrderCreated(orderId, msg.sender, _receiver, msg.value, block.timestamp + _releaseTime);
    }

    function claimOrder(bytes32 orderId) external {
        require(orders[orderId].buyer != address(0), "Order ID does not exist");
        Order storage orderInfo = orders[orderId];
        require(orderInfo.receiver == msg.sender, "Only receiver can claim");
        if (!orderInfo.release) {
            require(block.timestamp >= orderInfo.releaseTime, "Release time not reached");
        }
        require(!orderInfo.completed, "Order already completed");

        orderInfo.completed = true;
        emit OrderCompleted(orderId);

        payable(msg.sender).transfer(orderInfo.amount);
        // Move the orderId from incompleteOrders to completeOrders
        _moveOrder(orderId, incompleteOrders[msg.sender], completeOrders[msg.sender]);
    }

    function claimOrders(bytes32[] memory orderIds) external {
        uint256 totalAmount = 0;

        for (uint256 i = 0; i < orderIds.length; i++) {
            require(orders[orderIds[i]].buyer != address(0), "Order ID does not exist");
            Order storage orderInfo = orders[orderIds[i]];
            require(orderInfo.receiver == msg.sender, "Only receiver can claim");
            require(block.timestamp >= orderInfo.releaseTime, "Release time not reached");
            require(!orderInfo.completed, "Order already completed");

            totalAmount += orderInfo.amount;
            orderInfo.completed = true;
            emit OrderCompleted(orderIds[i]);

            // Move the orderId from incompleteOrders to completeOrders
            _moveOrder(orderIds[i], incompleteOrders[msg.sender], completeOrders[msg.sender]);
        }

        require(totalAmount > 0, "No orders to claim");

        payable(msg.sender).transfer(totalAmount);
    }

    function getUserIncompleteOrders(address user) external view returns (bytes32[] memory) {
        return incompleteOrders[user];
    }

    function getUserCompleteOrders(address user) external view returns (bytes32[] memory) {
        return completeOrders[user];
    }

    function _moveOrder(bytes32 orderId, bytes32[] storage source, bytes32[] storage destination) internal {
        for (uint256 i = 0; i < source.length; i++) {
            if (source[i] == orderId) {
                source[i] = source[source.length - 1];
                source.pop();
                destination.push(orderId);
                break;
            }
        }
    }
}
