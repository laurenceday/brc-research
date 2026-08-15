# Task 05: add deterministic maturity fixing

## Aim

Select `ST` as the first valid Chainlink BTC/USD observation published at or after the contractual maturity. The caller may supply evidence; the caller may not choose among valid prices.

## Selection rule

A candidate round is acceptable only when:

- it passes the answer and timestamp checks from task 4;
- `updatedAt >= maturity`;
- `updatedAt <= maturity + maxObservationDelay`; and
- the supplied predecessor evidence proves that no earlier published round in the proxy history also satisfies `updatedAt >= maturity`.

The adapter must store the answer, proxy round identifier, aggregator address, aggregator round identifier and update time. `ST` may be written once.

## Proxy phases

Treat a proxy round identifier as a phase and aggregator-round pair. Do not subtract one from the composite identifier and assume the result exists.

- Within a phase, verify the predecessor against that phase's aggregator.
- At the first round of a phase, inspect the final answered round of the previous phase.
- Reject evidence if the proxy's recorded aggregator for either phase does not match the submitted round data.
- Deal explicitly with skipped or reverting aggregator-round identifiers. A bounded evidence walk may cross gaps, but it must finish at an answered predecessor or fail.

## Permissionless submission

Any account may submit a candidate and its proof. The transaction outcome must depend only on the immutable series terms and verifiable Chainlink history. Paying more gas or waiting for a later favourable round must not change the accepted fixing.

## Tests to add

- Maturity between two ordinary rounds.
- A round updated exactly at maturity.
- Candidate before maturity and candidate after the observation deadline.
- A later round offered when an earlier eligible round exists.
- Maturity on both sides of a proxy phase transition.
- Missing aggregator round identifiers within a phase.
- Reverting round lookups and inconsistent aggregator evidence.
- Repeated submission after `ST` has been stored.

## Acceptance

- A fixture with fixed Chainlink history admits exactly one maturity answer.
- Phase transitions cannot change that answer.
- Invalid or insufficient evidence fails without changing state.
- The stored record is enough for an off-chain verifier to repeat every lookup.

## Not in this task

Do not let a committee choose an ordinary maturity observation. Fallback exists only for a primary path that remains unusable after its contractual waiting period, and belongs in task 9.
