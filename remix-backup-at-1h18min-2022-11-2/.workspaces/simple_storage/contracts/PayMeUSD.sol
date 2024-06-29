// SPDX-License-Identifier: MIT

// Smart contract that lets anyone deposit ETH into the contract
// Only the owner of the contract can withdraw the ETH
pragma solidity ^0.8.0;

// Get the latest ETH/USD price from chainlink price feed

// IMPORTANT: This contract has been updated to use the Goerli testnet
// Please see: https://docs.chain.link/docs/get-the-latest-price/
// For more information

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "hardhat/console.sol";

contract PayMe {
    address GOERLI_TESTNET_ETH_USD = 0xD4a33860578De61DBAbDc8BFdb98FD742fA7028e;

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
        require(ethToUSD(msg.value) >= 5 * 10**18, 
            "Minimum value to top up is 5 USD");

        emit toppedUp(msg.sender, msg.value);
        
        addrToBalance[msg.sender] += msg.value;
    }

    // returns balance in cents
    function checkBalance()
        public
        view
        returns(uint) 
    {
        return ethToUSD(addrToBalance[msg.sender]) / 10**16;
    }

    // withdraws the value in the input argument (USD) from balance
    function withdrawFromBalance(uint valueUSD) 
        public 
    {
        uint valueUSD18d = valueUSD * 10**18;
        uint valueReq = usdToEth(valueUSD18d);
        require(addrToBalance[msg.sender] >= valueReq, 
            "Not enough balance to withdraw");

        emit withdrawn(msg.sender, valueReq);

        payable(msg.sender).transfer(valueReq);
        addrToBalance[msg.sender] -= valueReq;
    }

    // withdraws all value from balance
    function withdrawAllFromBalance() 
        public 
    {
        emit withdrawn(msg.sender, addrToBalance[msg.sender]);

        payable(msg.sender).transfer(addrToBalance[msg.sender]);
        addrToBalance[msg.sender] = 0;

    }

    // tansfers the value in the first input argument (USD) from balance 
    // to the address in the second input argument
    function transfer(uint valueUSD, address recipient) 
        public 
    {
        uint valueUSD18d = valueUSD * 10**18;
        uint valueReq = usdToEth(valueUSD18d);
        require(addrToBalance[msg.sender] >= valueReq, 
            "Not enough balance to transfer");

        emit transferred(msg.sender, recipient, valueReq);

        addrToBalance[recipient] += valueReq;
        addrToBalance[msg.sender] -= valueReq;
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

    // pays the value in the input argument (USD) 
    // and stores any excessive value in balance
    function payDirect(uint valueUSD) 
        public 
        payable 
    {
        uint valueUSD18d = valueUSD * 10**18;
        uint valueReq = usdToEth(valueUSD18d);
        require(msg.value >= valueReq, 
            "Not enough money paid");
        // extra money paid will go into balance

        uint excessPaid = msg.value - valueReq;

        if (excessPaid > 0) {
            emit toppedUp(msg.sender, excessPaid);
            addrToBalance[msg.sender] += excessPaid;
        }

        if (valueReq > 0) {
            emit paid(msg.sender, orderID, valueReq - valueReq/2);
            allOrders.push(
                Order(
                    orderID, 
                    msg.sender, 
                    valueReq/2, 
                    valueReq - valueReq/2, 
                    State.Paid
                )
            );
            orderID++;
        }
    }

    // pays the value in the input argument (USD) with balance
    function payWithBalance(uint valueUSD) 
        public
    {
        uint valueUSD18d = valueUSD * 10**18;
        uint valueReq = usdToEth(valueUSD18d);
        require(addrToBalance[msg.sender] >= valueReq, 
            "Not enough balance");
        
        emit paid(msg.sender, orderID, valueReq - valueReq/2);
        
        addrToBalance[msg.sender] -= valueReq;
        
        allOrders.push(
            Order(
                orderID, 
                msg.sender, 
                valueReq/2, 
                valueReq - valueReq/2, 
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
    
    // ************************************************************** //
    // ****************** MONEY CONVERTION RELATED ****************** //
    // ************************************************************** //


    function getRate() 
        internal 
        view 
        returns(uint) 
    {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(GOERLI_TESTNET_ETH_USD);
        (,int256 answer,,,) = priceFeed.latestRoundData();
        return uint(answer);
    }

    // Input ETH, Output US$
    function ethToUSD(uint ethAmount) 
        public 
        view 
        returns(uint) 
    {
        uint ethPrice = getRate();
        uint ethAmountInUsd = (ethPrice * ethAmount) / 10**8;
        return ethAmountInUsd;
    }

    // Input US$, Output ETH
    function usdToEth(uint usdAmount) 
        public 
        view 
        returns(uint) 
    {
        uint ethPrice = getRate();
        uint usdAmountInEth = usdAmount * 10**8 / ethPrice;
        return usdAmountInEth;
    }

}