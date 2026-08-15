// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

contract MockERC20 {
  string public name;
  string public symbol;
  uint8 public immutable decimals;
  uint256 public totalSupply;
  bool public failTransfers;

  mapping(address => uint256) public balanceOf;
  mapping(address => mapping(address => uint256)) public allowance;

  constructor(string memory name_, string memory symbol_, uint8 decimals_) {
    name = name_;
    symbol = symbol_;
    decimals = decimals_;
  }

  function setFailTransfers(bool value) external {
    failTransfers = value;
  }

  function mint(address recipient, uint256 amount) external {
    totalSupply += amount;
    balanceOf[recipient] += amount;
  }

  function approve(address spender, uint256 amount) external returns (bool) {
    allowance[msg.sender][spender] = amount;
    return true;
  }

  function transfer(address recipient, uint256 amount) external returns (bool) {
    if (failTransfers) return false;
    _transfer(msg.sender, recipient, amount);
    return true;
  }

  function transferFrom(address sender, address recipient, uint256 amount) external returns (bool) {
    if (failTransfers) return false;
    uint256 allowed = allowance[sender][msg.sender];
    if (allowed != type(uint256).max) allowance[sender][msg.sender] = allowed - amount;
    _transfer(sender, recipient, amount);
    return true;
  }

  function _transfer(address sender, address recipient, uint256 amount) internal {
    balanceOf[sender] -= amount;
    balanceOf[recipient] += amount;
  }
}
