// ParentContract.sol
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Orderbook {
    using EnumerableSet for EnumerableSet.Bytes32Set;

    address public base;
    address public quote;
    string public pairSymbol;
    uint256 public orderIndex;
    bool approved;
    struct Orderdetails {
        bytes32 orderId;
        address user;
        uint256 price;
        uint256 quantity;
        bool isBuy;
    }

    //mappings

    mapping(address => EnumerableSet.Bytes32Set) private sellOrders;
    mapping(address => EnumerableSet.Bytes32Set) private buyOrders;
    mapping(bytes32 => Orderdetails) private Orders;

    constructor(address _base, address _quote, string memory _pairSymbol) {
        base = _base;
        quote = _quote;
        pairSymbol = _pairSymbol;
    }

    function CreateOrder(
        uint amount,
        bool isBuy,
        uint256 price
    ) public pure canCreate(isBuy, amount) {
        bytes32 orderId = keccak256(
            abi.encodePacked(
                msg.sender,
                block.timestamp,
                block.difficulty,
                orderIndex
            )
        );
        Orderdetails memory details = Orderdetails(
            orderId,
            msg.sender,
            0,
            amount,
            isBuy
        );

        Orders[orderId] = details;

        if (isBuy) {
            //userwants to buy
            IERC20(quote).transferFrom(msg.sender, address(this), amount);
            buyOrders[msg.sender].add(orderId);
        } else {
            //user wants to sell
            IERC20(base).transferFrom(msg.sender, address(this), amount);
            sellOrders[msg.sender].add(orderId);
        }

        emit OrderCreated(orderId, msg.sender, isBuy, price, amount);
    }

    function CancelOrder(bytes32 orderId, uint amount) public pure {
        Orderdetails memory details = Orders[orderId];
        uint256 amount = details.quantity;
        if (details.isBuy) {
            buyOrders[msg.sender].remove(orderId);
            IERC20(base).transferFrom(address(this), msg.sender, amount);
        } else {
            sellOrders[msg.sender].remove(orderId);
            IERC20(quote).transferFrom(address(this), msg.sender, amount);
        }
        delete Orders[orderId];
        OrderCancelled(orderId, msg.sender);
    }

    function UpdateOrder(bytes32 orderId, uint256 newPrice) public pure {
        //you can't change the initial amount
        Orderdetails memory details = Orders[orderId];
        uint256 amount = details.quantity;
        require(details.quantity > 0, "Order does not exist");
        require(
            details.user == msg.sender,
            "Only order owner can update the order"
        );
        require(newPrice > 0, "New price must be greater than 0");
        details.price = newPrice;
        emit OrderUpdated(
            orderId,
            details.user,
            details.price,
            details.quantity
        );
    }

    function ExecuteTrade(
        bytes32 order1,
        bytes32 order2
    ) public pure canBeMatched(order1, order2) {
        require(
            Orders[order1].user == msg.sender ||
                Orders[order2].user == msg.sender,
            "You are not the owner of either order"
        );
        require(
            Orders[order1].quantity != 0 && Orders[order2].quantity != 0,
            "Orders cannot have zero quantity"
        );
        require(
            Orders[order1].isBuy != Orders[order2].isBuy,
            "Both orders cannot be of the same type"
        );
        require(
            Orders[order1].price == Orders[order2].price ||
                (Orders[order2].isBuy &&
                    Orders[order2].price < Orders[order1].price) ||
                (!Orders[order2].isBuy &&
                    Orders[order2].price > Orders[order1].price),
            "Orders cannot be matched"
        );

        address seller = Orders[order1].isBuy
            ? Orders[order2].user
            : Orders[order1].user;
        address buyer = Orders[order1].isBuy
            ? Orders[order1].user
            : Orders[order2].user;
        uint256 quantity = Orders[order1].quantity < Orders[order2].quantity
            ? Orders[order1].quantity
            : Orders[order2].quantity;
        uint256 price = Orders[order1].price;
        uint256 amount = quantity * price;

        // Transfer tokens from buyer to seller
        if (Orders[order1].isBuy) {
            IERC20(base).transferFrom(buyer, seller, quantity);
            IERC20(quote).transferFrom(seller, buyer, amount);
        } else {
            IERC20(quote).transferFrom(buyer, seller, amount);
            IERC20(base).transferFrom(seller, buyer, quantity);
        }

        // Update orders
        Orders[order1].quantity -= quantity;
        Orders[order2].quantity -= quantity;

        if (Orders[order1].quantity == 0) {
            if (Orders[order1].isBuy) {
                buyOrders[Orders[order1].user].remove(order1);
            } else {
                sellOrders[Orders[order1].user].remove(order1);
            }
        }

        if (Orders[order2].quantity == 0) {
            if (Orders[order2].isBuy) {
                buyOrders[Orders[order2].user].remove(order2);
            } else {
                sellOrders[Orders[order2].user].remove(order2);
            }
        }

        emit OrderMatched(order1, order2, buyer, seller, quantity, price);
    }

    //utils

    //modifiers

    modifier canCreate(bool isBuy, uint256 quantity) {
        require(approved == true, "Pairs is not approved for trading");
        if (isBuy) {
            require(
                IERC20(quote).balanceOf(msg.sender) > quantity,
                "Not enough balance"
            );
        } else {
            require(
                IERC20(base).balanceOf(msg.sender) > quantity,
                "Not enough balance"
            );
        }
        _;
    }

    modifier canBeMatched(bytes32 order1, bytes32 order2) {
        require(approved == true, "Pairs is not approved for trading");
        require(
            Orders[order1].quantity != 0 && Orders[order2].quantity != 0,
            "Orders cannot have zero quantity"
        );
        require(
            Orders[order1].isBuy != Orders[order2].isBuy,
            "Both orders cannot be of the same type"
        );
        require(
            Orders[order1].price == Orders[order2].price ||
                (Orders[order2].isBuy &&
                    Orders[order2].price < Orders[order1].price) ||
                (!Orders[order2].isBuy &&
                    Orders[order2].price > Orders[order1].price),
            "Orders cannot be matched"
        );
        _;
    }

    //events
    event OrderUpdated(
        bytes32 orderId,
        address User,
        uint256 price,
        uint256 quantity
    );

    event OrderCreated(
        bytes32 orderId,
        address creator,
        bool isBuy,
        uint256 price,
        uint256 quantity
    );
    event OrderCancelled(bytes32 orderId, address user);
    event OrderMatched(
        bytes32 indexed buyOrderId,
        bytes32 indexed sellOrderId,
        address indexed buyer,
        address seller,
        uint256 price,
        uint256 quantity
    );
}

contract ParentContract {
    struct OrderbookInfo {
        address childAddress;
        uint value;
        bool isApproved;
    }

    OrderbookInfo[] public Orderbooks;

    function createOrderbook(uint _value) public returns (address) {
        Orderbook Orderbook = new Orderbook(_value);
        OrderbookInfo memory OrderbookInfo = OrderbookInfo(
            Orderbook,
            _value,
            false
        );
        Orderbooks.push(OrderbookInfo);
        return address(Orderbook);
    }

    function approveOrderbook(uint index) public {
        Orderbooks[index].isApproved = true;
    }

    function disapproveOrderbook(uint index) public {
        Orderbooks[index].isApproved = false;
    }

    function callOrderbookFunction(
        uint index
    ) public view returns (string memory) {
        require(Orderbooks[index].isApproved, "Child contract is not approved");
        Orderbook Orderbook = Orderbook(Orderbooks[index].childAddress);
        return Orderbook.someFunction();
    }
}
