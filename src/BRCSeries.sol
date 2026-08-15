// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

struct BRCSeriesTerms {
  uint128 notional;
  uint128 strike;
  uint128 barrier;
  uint40 maturity;
  uint8 settlementAssetDecimals;
}

enum BRCState {
  Funding,
  Funded,
  Active,
  Withdrawing,
  Settled,
  Recovery,
  Redeemable,
  Cancelled
}
