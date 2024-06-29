// SPDX-License-Identifier: MIT

pragma solidity >=0.4.22 <0.6.0;

contract SimpleAuction {
    address payable public beneficiary;
    uint public auctionEndTime;

    address public highestBidder;
    uint public highestBid;
    uint public minimumBid;
    uint public minimumIncrement;
    mapping(address => uint) pendingReturns;
    bool ended;
    bool received;

    event HighestBidIncreased(address bidder, uint amount);
    event AuctionEnded(address winner, uint amount);

    constructor(
        uint _biddingTime,
        address payable _beneficiary,
        uint _minimumBid,
        uint _minimumIncrement
    ) public {
        beneficiary = _beneficiary;
        auctionEndTime = now + (_biddingTime * 1 seconds);
        minimumBid = _minimumBid;
        minimumIncrement = _minimumIncrement;
        received = false;
    }

    function bid() public payable {
        require(
            now <= auctionEndTime,
            "Auction already ended."
        );

        require(
            msg.value >= highestBid + minimumIncrement || highestBid < minimumBid, // For the first bid in case minimum increment is larger than minimum bid
            "The bid offered needs to exceed the minimum increment compared to the highest bid"
        );

        require(
            msg.value >= minimumBid,
            "The bid offered needs to exceed the minimum bid"
        );

        if (highestBid != 0) {
            pendingReturns[highestBidder] += highestBid;
        }
        highestBidder = msg.sender;
        highestBid = msg.value;
        emit HighestBidIncreased(msg.sender, msg.value);
    }

    function withdraw() public returns (bool) {
        uint amount = pendingReturns[msg.sender];
        if (amount > 0) {
            pendingReturns[msg.sender] = 0;

            if (!msg.sender.send(amount)) {
                pendingReturns[msg.sender] = amount;
                return false;
            }
        }
        return true;
    }

    function auctionEnd() public {
        require(now >= auctionEndTime, "Auction not yet ended.");
        require(!ended, "auctionEnd has already been called.");

        ended = true;
        emit AuctionEnded(highestBidder, highestBid);

        beneficiary.transfer(highestBid);
    }

    function confirmTransaction() 
        public 
    {
        require(ended, "Auction not yet ended or auctionEnd has not been called.");
        require(msg.sender == highestBidder, "Only the winner can confirm the transaction");
        require(!received, "Transaction already confirmed.");

        if (beneficiary.send(highestBid)) {
            received = true;
        }
    }
}
