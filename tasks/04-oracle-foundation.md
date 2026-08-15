# Task 04: add the Chainlink oracle foundation

## Aim

Bind a series to one named Chainlink BTC/USD proxy and store its initial fixing once. Anything incomplete, stale or inconsistent with the manifest gets rejected.

## Immutable feed identity

The oracle adapter must bind:

- the proxy address;
- the expected feed decimals;
- a hash of the expected `description()` value;
- the maximum age permitted for the deployment round; and
- the maximum tolerated future timestamp skew.

Deployment has to fail if the live proxy does not match the recorded metadata. There is no admin price setter and no open-ended feed replacement path.

## Round validation

For each accepted round, require:

- `answer > 0`;
- `updatedAt != 0`;
- `updatedAt <= block.timestamp + permittedSkew`;
- `answeredInRound >= roundId`; and
- the age at the relevant observation point is within the configured limit.

Keep raw feed units in oracle storage. Only convert at the payoff-library edge, with the rounding rule written down.

## Initial fixing

- Read `latestRoundData()` while deploying the configured vault.
- Require the round to be fresh at the vault deployment timestamp.
- Store `S0`, its proxy round identifier and `updatedAt` together.
- Derive the strike and barrier from stored `S0` and the immutable series terms.
- Make the write one-shot. A failed vault deployment must leave no half-written fixing behind; a later activation failure must retain the precommitted fixing.

## Tests to add

- Correct proxy metadata and a fresh positive answer.
- Zero and negative answers.
- Zero, stale and future timestamps.
- `answeredInRound < roundId`.
- Decimal and description mismatches.
- A second initial-fixing attempt.
- A proxy phase change before deployment.

## Acceptance

- Every rejected value fails with a specific custom error.
- An accepted fixing records enough detail to reproduce it from Chainlink history.
- No privileged account can revise `S0`, the strike, the barrier or the bound proxy.
- Fuzz tests cover timestamp limits and feed-decimal conversion.

## Not in this task

This branch does not choose the post-maturity round or add a fallback. `latestRoundData()` is fine for a fresh deployment observation; it is not the maturity selection rule.
