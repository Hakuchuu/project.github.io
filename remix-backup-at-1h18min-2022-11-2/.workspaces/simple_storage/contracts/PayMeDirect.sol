// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract PayMe {
    address public owner;

    uint public orderID;
    uint public orderIDWaiting;
    Order[] public allOrders;

    enum State {
        Paid, 
        Cancelled, 
        Accepted, 
        Received
    }

    struct Order {
        uint orderID;
        address buyer;
        uint valuePaid;
        uint valueDeposited;
        State state;
    }

    modifier onlyOwnder {
        require(msg.sender == owner, "Only the owner can call this function");
        _;
    }

    constructor() {
        owner = msg.sender;
        orderID = 0;
        orderIDWaiting = 0;
    }

    event paid(address addr, uint id, uint deposit);
    event cancelled(address addr, uint id, uint deposit);
    event accepted(address addr, uint id, uint deposit);
    event received(address addr, uint id, uint deposit);

    event noOrderAvailable();

    // ************************************************************** //
    // ***************** CREATING PURCHASE - BUYER ****************** //
    // ************************************************************** //

    // pays the value in the input argument (Gwei) 
    // and stores any excessive value in balance
    function pay() 
        public 
        payable 
        returns(uint)
    {
        emit paid(msg.sender, orderID, msg.value - msg.value/2);
        allOrders.push(
            Order(
                orderID, 
                msg.sender, 
                msg.value/2, // Deposit
                msg.value - msg.value/2, // Paid
                State.Paid
            )
        );
        return orderID++;
    }

    // cancel order made  by order id and retrieving all money paid
    // only works if the order has yet to be accepted by the seller (owner)
    function cancelOrder(uint _orderID) 
        public
    {
        Order storage order = allOrders[_orderID];

        require(order.buyer == msg.sender, 
            "Not your order");
        require(order.state == State.Paid, 
            "Order already accepted or cancelled");

        order.state = State.Cancelled;

        emit cancelled(order.buyer, order.orderID, order.valueDeposited);

        payable(msg.sender).transfer(order.valuePaid + order.valueDeposited);
    }
    
    // ************************************************************** //
    // **************** HANDLING PAID ORDER - OWNER ***************** //
    // ************************************************************** //

    // look for next uncancelled order
    function nextOrder()
        onlyOwnder
        public
    {
        while (orderIDWaiting < orderID) {
            if (allOrders[orderIDWaiting].state == State.Paid)
                return;
            orderIDWaiting++;
        }
        
        emit noOrderAvailable();
    }

    // accepts next order, deposit paid directly
    function acceptNextOrderDirect()
        onlyOwnder
        public
        payable
    {
        require(orderIDWaiting < orderID, 
            "No orders to accept");
        require(allOrders[orderIDWaiting].state == State.Paid, 
            "Next order is cancelled, call nextOrder first");
        
        Order storage order = allOrders[orderIDWaiting];

        require(msg.value == order.valueDeposited, 
            "Value to deposite should be the same as value deposited by buyer");
        
        emit accepted(order.buyer, order.orderID, order.valueDeposited);

        order.state = State.Accepted;
        orderIDWaiting++;
        nextOrder();
    }

    // cancels next order, all money paid returns back to buyer
    function cancelNextOrder()
        onlyOwnder
        public
    {
        require(orderIDWaiting < orderID, 
            "No orders to cancel");
        require(allOrders[orderIDWaiting].state == State.Paid, 
            "Next order is already cancelled, call nextOrder first");
        
        Order storage order = allOrders[orderIDWaiting];

        emit cancelled(order.buyer, order.orderID, order.valueDeposited);

        order.state = State.Cancelled;

        payable(order.buyer).transfer(order.valuePaid + order.valueDeposited);
        orderIDWaiting++;
        nextOrder();
    }
    
    // ************************************************************** //
    // ************** RECEIVING ACCEPTED ORDER - BUYER ************** //
    // ************************************************************** //

    // finish the order after receiving food, and get back the deposit to balance
    function receivedOrder(uint _orderID) 
        public
    {
        Order storage order = allOrders[_orderID];

        require(order.buyer == msg.sender, 
            "Not your order");
        require(order.state == State.Accepted, 
            "Order not yet accepted, has been cancelled or received");

        emit received(msg.sender, order.orderID, order.valueDeposited);

        order.state = State.Received;
        
        payable(owner).transfer(order.valueDeposited + order.valuePaid);
        payable(order.buyer).transfer(order.valueDeposited);
    }
}