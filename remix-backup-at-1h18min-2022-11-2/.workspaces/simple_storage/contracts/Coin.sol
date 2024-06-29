// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

contract CoinFlip {
    address payable public player1;

    bool private player1bit;
    uint256 public betAmount;


    constructor(bool choice) payable {
        player1 = payable(msg.sender);
        player1bit = choice;
        betAmount = msg.value;
    }

    function TakeBet(bool choice) public payable {
        require(msg.value == betAmount);

        if (player1bit == choice) {
            payable(msg.sender).transfer(address(this).balance);
        } else {
            player1.transfer(address(this).balance);
        }
    }
}