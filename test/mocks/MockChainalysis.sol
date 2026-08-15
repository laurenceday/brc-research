// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

contract MockChainalysis {
  mapping(address => bool) public isSanctioned;

  function setSanctioned(address account, bool sanctioned) external {
    isSanctioned[account] = sanctioned;
  }
}
