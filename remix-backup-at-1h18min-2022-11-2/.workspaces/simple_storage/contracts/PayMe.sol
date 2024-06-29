// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract PayMe {
    address public owner;

    uint public orderID;
    uint public orderIDWaiting;
    Order[] private allOrders;

    mapping(address => uint) public addrToBalance;

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
        orderID = 1;
        orderIDWaiting = 1;
    }

    event toppedUp(address addr, uint value);
    event withdrawn(address addr, uint value);
    event transferred(address addrOut, address addrIn, uint value);

    event paid(address addr, uint id, uint deposit);
    event cancelled(address addr, uint id, uint deposit);
    event accepted(address addr, uint id, uint deposit);
    event received(address addr, uint id, uint deposit);

    event noOrderAvailable();

    // ************************************************************** //
    // ******************** BALANCE RELATED ************************* //
    // ************************************************************** //

    // top up balance
    function topUp()
        public 
        payable 
    {
        require(msg.value >= 5 * 10**15, 
            "Minimum value to top up is 0.005 ETH");

        emit toppedUp(msg.sender, msg.value);
        
        addrToBalance[msg.sender] += msg.value;
    }

    // returns balance in Gwei
    function checkBalance()
        public
        view
        returns(uint) 
    {
        return addrToBalance[msg.sender] / 10**9;
    }

    // withdraws the value in the input argument in Gwei
    function withdrawFromBalance(uint value) 
        public 
    {
        value *= 10**9;
        require(addrToBalance[msg.sender] >= value, 
            "Not enough balance to withdraw");

        emit withdrawn(msg.sender, value);

        payable(msg.sender).transfer(value);
        addrToBalance[msg.sender] -= value;
    }

    // withdraws all value from balance
    function withdrawAllFromBalance() 
        public 
    {
        emit withdrawn(msg.sender, addrToBalance[msg.sender]);

        payable(msg.sender).transfer(addrToBalance[msg.sender]);
        addrToBalance[msg.sender] = 0;

    }

    // tansfers the value in the first input argument (Gwei) from balance 
    // to the address in the second input argument
    function transfer(uint value, address recipient) 
        public 
    {
        value *= 10**9;
        require(addrToBalance[msg.sender] >= value, 
            "Not enough balance to transfer");

        emit transferred(msg.sender, recipient, value);

        addrToBalance[recipient] += value;
        addrToBalance[msg.sender] -= value;
    }

    // tansfers all value from balance to the address in the input argument
    function transferAll(address recipient) 
        public 
    {
        emit transferred(msg.sender, recipient, addrToBalance[msg.sender]);

        addrToBalance[recipient] += addrToBalance[msg.sender];
        addrToBalance[msg.sender] = 0;
    }

    // top up balance by owner (no minimum limit)
    function topUpByOwner()
        onlyOwnder
        public 
        payable 
    {
        emit toppedUp(msg.sender, msg.value);
        
        addrToBalance[owner] += msg.value;
    }

    // ************************************************************** //
    // ***************** CREATING PURCHASE - BUYER ****************** //
    // ************************************************************** //

    // pays the value in the input argument (Gwei) 
    // and stores any excessive value in balance
    function payDirect(uint value) 
        public 
        payable 
    {
        value *= 10**9;
        require(msg.value >= value, 
            "Not enough money paid");
        // extra money paid will go into balance

        uint excessPaid = msg.value - value;

        if (excessPaid > 0) {
            emit toppedUp(msg.sender, excessPaid);
            addrToBalance[msg.sender] += excessPaid;
        }

        if (value > 0) {
            emit paid(msg.sender, orderID, value - value/2);
            allOrders.push(
                Order(
                    orderID, 
                    msg.sender, 
                    value/2, 
                    value - value/2, 
                    State.Paid
                )
            );
            orderID++;
        }
    }

    // pays the value in the input argument (Gwei) with balance
    function payWithBalance(uint value) 
        public
    {
        value *= 10**9;
        require(addrToBalance[msg.sender] >= value, 
            "Not enough balance");
        
        emit paid(msg.sender, orderID, value - value/2);
        
        addrToBalance[msg.sender] -= value;
        
        allOrders.push(
            Order(
                orderID, 
                msg.sender, 
                value/2, 
                value - value/2, 
                State.Paid
            )
        );
        
        orderID++;
    }

    // cancel order made by order id and retrieving all money paid as balance
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

        addrToBalance[msg.sender] += 
            order.valuePaid + order.valueDeposited;
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

        require(msg.value >= order.valueDeposited, 
            "Not enough money in balance to be deposited");
        
        emit accepted(order.buyer, order.orderID, order.valueDeposited);

        addrToBalance[owner] += msg.value - order.valueDeposited;

        order.state = State.Accepted;
        orderIDWaiting++;
        nextOrder();
    }

    // accepts next order, deposit paid using owner's balance
    function acceptNextOrder()
        onlyOwnder
        public
    {
        require(orderIDWaiting < orderID, 
            "No orders to accept");
        require(allOrders[orderIDWaiting].state == State.Paid, 
            "Next order is cancelled, call checkNextOrder first");
        
        Order storage order = allOrders[orderIDWaiting];

        require(addrToBalance[owner] >= order.valueDeposited, 
            "Not enough money deposited");
        
        emit accepted(order.buyer, order.orderID, order.valueDeposited);

        addrToBalance[owner] -= order.valueDeposited;

        order.state = State.Accepted;
        orderIDWaiting++;
        nextOrder();
    }

    // cancels next order, all money paid returns back to buyer's balance
    function cancelNextOrder()
        onlyOwnder
        public
    {
        require(orderIDWaiting < orderID, 
            "No orders to cancel");
        require(allOrders[orderIDWaiting].state == State.Paid, 
            "Next order is already cancelled, call checkNextOrder first");
        
        Order storage order = allOrders[orderIDWaiting];

        emit cancelled(order.buyer, order.orderID, order.valueDeposited);

        order.state = State.Cancelled;

        addrToBalance[order.buyer] += 
            order.valuePaid + order.valueDeposited;
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
        
        addrToBalance[owner] += order.valueDeposited + order.valuePaid;
        addrToBalance[msg.sender] += order.valueDeposited;
    }
}