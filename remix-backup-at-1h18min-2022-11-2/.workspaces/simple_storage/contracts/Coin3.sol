// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

contract CoinFlip {
    address payable public player1;
    address payable public player2;

    bytes32 public player1Commitment;
    bytes32 public player2Commitment;

    uint256 public betAmount;

    bool public player1Choice;
    bool public revealed;

    constructor(bytes32 commitment) payable {
        player1 = payable(msg.sender);
        player1Commitment = commitment;
        betAmount = msg.value;
        revealed = false;
    }

    function TakeBet(bytes32 commitment) public payable {
        require(player2 == address(0));
        require(msg.value == betAmount);

        player2 = payable(msg.sender);
        player2Commitment = commitment;
    }

    function Reveal1(bool choice, uint256 nonce) public {
        require(player2 != address(0));
        require(!revealed);
        require(keccak256(abi.encodePacked(choice, nonce)) == player1Commitment);

        player1Choice = choice;
        revealed = true;
        player1.transfer(address(this).balance / 4);
    }

    function Reveal2(bool choice, uint256 nonce) public {
        require(player2 != address(0));
        require(revealed);
        require(keccak256(abi.encodePacked(choice, nonce)) == player2Commitment);

        if (player1Choice == choice) {
            player2.transfer(address(this).balance);
        } else {
            player2.transfer(address(this).balance / 3);
            player1.transfer(address(this).balance);
        }
    }
} 