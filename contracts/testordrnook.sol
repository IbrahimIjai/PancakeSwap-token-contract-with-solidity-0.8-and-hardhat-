pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

contract MyContract is IERC20 {
    using EnumerableSet for EnumerableSet.Bytes32Set;

    struct OrderDetails {
        uint256 orderId;
        address user;
        uint256 price;
        uint256 quantity;
        bool isBuy;
    }

    mapping(address => EnumerableSet.Bytes32Set) private sellOrders;
    mapping(address => EnumerableSet.Bytes32Set) private buyOrders;
    mapping(bytes32 => OrderDetails) private orderDetails;

    function createOrder(uint256 amount, bool isBuy) public returns (bytes32) {
        bytes32 orderId = generateOrderId();
        OrderDetails memory details = OrderDetails(
            orderId,
            msg.sender,
            0,
            amount,
            isBuy
        );
        orderDetails[orderId] = details;

        if (isBuy) {
            buyOrders[msg.sender].add(orderId);
        } else {
            sellOrders[msg.sender].add(orderId);
        }

        return orderId;
    }

    function __createOrder(uint256 amount, bool isBuy, uint256 price) external {
        // Check if the user has approved the contract to transfer tokens
        uint256 allowance;
        if (isBuy) {
            allowance = IERC20(quote).allowance(msg.sender, address(this));
            require(allowance >= amount, "Insufficient quote token allowance");
            IERC20(quote).transferFrom(msg.sender, address(this), amount);
        } else {
            allowance = IERC20(base).allowance(msg.sender, address(this));
            require(allowance >= amount, "Insufficient base token allowance");
            IERC20(base).transferFrom(msg.sender, address(this), amount);
        }

        // Generate order ID
        bytes32 orderId = keccak256(
            abi.encodePacked(
                msg.sender,
                block.timestamp,
                block.difficulty,
                orderIndex
            )
        );

        // Create new order
        Orderdetails memory order = Orderdetails(
            orderIndex,
            msg.sender,
            price,
            amount,
            isBuy
        );
        Orders[orderId] = order;
        orderIndex++;

        // Add order to appropriate order book
        if (isBuy) {
            buyOrders[msg.sender].add(orderId);
        } else {
            sellOrders[msg.sender].add(orderId);
        }
    }

    function generateOrderId() private view returns (bytes32) {
        return
            keccak256(
                abi.encodePacked(block.timestamp, msg.sender, block.difficulty)
            );
    }

    function cancelOrder(bytes32 orderId) public {
        OrderDetails memory details = orderDetails[orderId];
        require(
            msg.sender == details.user,
            "Only the user who created the order can cancel it"
        );

        if (details.isBuy) {
            buyOrders[msg.sender].remove(orderId);
        } else {
            sellOrders[msg.sender].remove(orderId);
        }

        delete orderDetails[orderId];
    }

    function approveOrder(bytes32 orderId) public {
        OrderDetails storage details = orderDetails[orderId];
        require(
            msg.sender == details.user,
            "Only the user who created the order can approve it"
        );

        // perform approval logic here

        details.price = 100; // example of changing the price after approval
    }
    function matchOrder(bytes32 order1, bytes32 order2) public {
    require(Orders[order1].user == msg.sender || Orders[order2].user == msg.sender, "You are not the owner of either order");
    require(Orders[order1].quantity != 0 && Orders[order2].quantity != 0, "Orders cannot have zero quantity");
    require(Orders[order1].isBuy != Orders[order2].isBuy, "Both orders cannot be of the same type");
    require(Orders[order1].price == Orders[order2].price || (Orders[order2].isBuy && Orders[order2].price < Orders[order1].price) || (!Orders[order2].isBuy && Orders[order2].price > Orders[order1].price), "Orders cannot be matched");

    address seller = Orders[order1].isBuy ? Orders[order2].user : Orders[order1].user;
    address buyer = Orders[order1].isBuy ? Orders[order1].user : Orders[order2].user;
    uint256 quantity = Orders[order1].quantity < Orders[order2].quantity ? Orders[order1].quantity : Orders[order2].quantity;
    uint256 price = Orders[order1].price;

    uint256 amount = quantity * price;

    // Transfer tokens from buyer to seller
    if (Orders[order1].isBuy) {
        IERC20(baseToken).transferFrom(buyer, seller, quantity);
        IERC20(quoteToken).transferFrom(seller, buyer, amount);
    } else {
        IERC20(quoteToken).transferFrom(buyer, seller, amount);
        IERC20(baseToken).transferFrom(seller, buyer, quantity);
    }

    // Update orders
    Orders[order1].quantity -= quantity;
    Orders[order2].quantity -= quantity;

    if (Orders[order1].quantity == 0) {
        if (Orders[order1].isBuy) {
            buyOrders[price].remove(order1);
        } else {
            sellOrders[price].remove(order1);
        }
    }

    if (Orders[order2].quantity == 0) {
        if (Orders[order2].isBuy) {
            buyOrders[price].remove(order2);
        } else {
            sellOrders[price].remove(order2);
        }
    }

    emit OrderMatched(order1, order2, buyer, seller, quantity, price);
}

// Modifier to check if both orders are valid and can be matched
modifier canMatch(bytes32 order1, bytes32 order2) {
    require(Orders[order1].quantity != 0 && Orders[order2].quantity != 0, "Orders cannot have zero quantity");
    require(Orders[order1].isBuy != Orders[order2].isBuy, "Both orders cannot be of the same type");
    require(Orders[order1].price == Orders[order2].price || (Orders[order2].isBuy && Orders[order2].price < Orders[order1].price) || (!Orders[order2].isBuy && Orders[order2].price > Orders[order1].price), "Orders cannot be matched");
    _;
}


    function getOrders(
        address user,
        bool isBuy
    ) public view returns (bytes32[] memory) {
        if (isBuy) {
            // return buyOrders[user]._inner._values;
        } else {
            // return sellOrders[user]._inner._values;
        }
    }
}
