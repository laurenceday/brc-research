// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { AggregatorV3Interface } from "./AggregatorV3Interface.sol";

interface IChainlinkAggregatorProxy is AggregatorV3Interface {
  function phaseAggregators(uint16 phaseId) external view returns (address);
}
