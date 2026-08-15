// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Vendored from smartcontractkit/chainlink-brownie-contracts at
// f82d1ac09fc5d3190600d308be99a4a509854686:
// contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol
interface AggregatorV3Interface {
  function decimals() external view returns (uint8);

  function description() external view returns (string memory);

  function version() external view returns (uint256);

  function getRoundData(uint80 roundId)
    external
    view
    returns (uint80, int256, uint256, uint256, uint80);

  function latestRoundData() external view returns (uint80, int256, uint256, uint256, uint80);
}
