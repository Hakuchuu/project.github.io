// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

contract CoinFlip {
    address payable public player1;
    address payable public player2;

    bytes32 public player1Commitment;
    bytes32 public player2Commitment;

    uint256 public betAmount;
    uint256 public earnestAmount;

    bool public player2Choice;

    constructor(bytes32 commitment) payable {
        player1 = payable(msg.sender);
        player1Commitment = commitment;
        betAmount = msg.value / 2;
        earnestAmount = msg.value - betAmount;
    }

    function TakeBet(bool choice) public payable {
        require(player2 == address(0));
        require(msg.value == betAmount);

        player2 = payable(msg.sender);
        player2Choice = choice;
    }

    function Reveal(uint256 nonce) public {
        require(player2 != address(0));
        require(
            keccak256(abi.encodePacked(player2Choice, nonce)) == player1Commitment || 
            keccak256(abi.encodePacked(!player2Choice, nonce)) == player1Commitment
            );

        if (keccak256(abi.encodePacked(player2Choice, nonce)) == player1Commitment) {
            player1.call{value: earnestAmount}("");
            player2.call{value: address(this).balance}("");
            // player2.transfer(earnestAmount);
            // player2.transfer(address(this).balance);
        } else {
            player1.transfer(address(this).balance);
        }
    }
} 