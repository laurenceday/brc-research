// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

struct BRCFallbackConfig {
  address[] ratifiers;
  uint8 threshold;
  uint32 waitingPeriod;
  uint32 challengePeriod;
  bytes32 sourceId;
}
