# Task 04: add the Chainlink oracle foundation

## Aim

Bind a series to one named Chainlink BTC/USD proxy and store its initial fixing once. Reject feed data that is incomplete, stale or inconsistent with the series manifest.

## Immutable feed identity

The oracle adapter must bind:

- the proxy address;
- the expected feed decimals;
- a hash of the expected `description()` value;
- the maximum age permitted for the activation round; and
- the maximum tolerated future timestamp skew.

Deployment or activation must fail if the live proxy does not match the recorded metadata. The contract must not contain an administrator price setter or an unrestricted feed replacement path.

## Round validation

For each accepted round, require:

- `answer > 0`;
- `updatedAt != 0`;
- `updatedAt <= block.timestamp + permittedSkew`;
- `answeredInRound >= roundId`; and
- the age at the relevant observation point is within the configured limit.

Keep raw feed units in oracle storage. Convert only at the payoff-library edge, with an explicit rounding rule.

## Initial fixing

- Read `latestRoundData()` during activation.
- Require the round to be fresh at the activation transaction timestamp.
- Store `S0`, its proxy round identifier and `updatedAt` together.
- Derive the strike and barrier from stored `S0` and the immutable series terms.
- Make the write one-shot. A failed activation must leave no partial fixing.

## Tests to add

- Correct proxy metadata and a fresh positive answer.
- Zero and negative answers.
- Zero, stale and future timestamps.
- `answeredInRound < roundId`.
- Decimal and description mismatches.
- A second initial-fixing attempt.
- A proxy phase change before activation.

## Acceptance

- Every rejected datum fails with a specific custom error.
- An accepted fixing records enough data to reproduce it from Chainlink history.
- No privileged account can revise `S0`, the strike, the barrier or the bound proxy.
- Fuzz tests cover timestamp limits and feed-decimal conversion.

## Not in this task

Do not choose the post-maturity round or implement a fallback. `latestRoundData()` is suitable for a fresh activation observation; it is not the maturity selection rule.
