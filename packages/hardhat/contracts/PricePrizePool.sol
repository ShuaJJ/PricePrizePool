pragma solidity >=0.8.0 <0.9.0;
//SPDX-License-Identifier: MIT

contract PricePrizePool {

  event Deposited(address indexed user, uint256 amount);

  mapping(address => uint) public bets;

  function deposit() external payable {

    require(msg.value >= 10 ** 16, "Minimum deposit is 0.01!");

    bets[msg.sender] = msg.value;

    emit Deposited(msg.sender, msg.value);

  }
}
