// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { IERC20 } from "../../src/interfaces/IERC20.sol";

contract MockWildcatMarket {
  IERC20 public immutable asset;
  bool public isClosed;

  mapping(address => uint256) public balanceOf;
  mapping(address => uint256) public queued;

  constructor(IERC20 asset_) {
    asset = asset_;
  }

  function deposit(uint256 amount) external {
    require(asset.transferFrom(msg.sender, address(this), amount));
    balanceOf[msg.sender] += amount;
  }

  function queueWithdrawal(uint256 amount) external {
    balanceOf[msg.sender] -= amount;
    queued[msg.sender] += amount;
  }

  function executeWithdrawal() external returns (uint256 amount) {
    amount = queued[msg.sender];
    queued[msg.sender] = 0;
    require(asset.transfer(msg.sender, amount));
  }

  function repay(uint256 amount) external {
    require(asset.transferFrom(msg.sender, address(this), amount));
  }

  function close() external {
    isClosed = true;
  }
}
