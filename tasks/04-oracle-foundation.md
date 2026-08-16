# Task 04: add the Chainlink oracle foundation

Status: implemented and merged. This step bound each configured series to one Chainlink BTC/USD proxy and stored its initial fixing.

## What shipped

`BtcUsdFixingOracle` fixes the following values at construction:

- the proxy address;
- expected decimals;
- the hash of `description()`;
- the maximum age of the initial round; and
- the permitted future timestamp skew.

Construction checks the live metadata. There is no administrator price setter or feed-replacement function.

The initial round must have a positive answer, a nonzero round ID and timestamp, `answeredInRound >= roundId`, a timestamp before maturity and an age within the configured limits. A successful call stores the proxy round ID, answer and update time once, then derives strike and barrier from that answer.

Prices remain in the Chainlink feed's raw units. There is no conversion at the payoff edge: `K`, `B` and `ST` all use the same feed precision, so the units cancel in `(K - ST) / K`. Settlement-asset decimals determine the note and settlement-token units, not the BTC price ratio.

The vault creates the oracle and records `S0` in its constructor. If vault deployment reverts, the oracle deployment and fixing revert with it. A later activation failure does not alter the stored fixing.

## Evidence

`test/BtcUsdFixingOracle.t.sol` covers the accepted path, caller restriction, repeated recording, zero and negative answers, stale and future timestamps, incomplete rounds, round zero, direct aggregators without proxy phase history, and decimal or description mismatches. Fuzzing covers the configured age and future-skew boundaries.

## Boundary of this step

Task 04 did not choose `ST` or add fallback governance. Task 05 added deterministic maturity selection, and task 09 added the delayed ratifier route.
