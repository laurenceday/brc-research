# Task 05: pick the maturity price without picking the price

## What we're after

`ST` is the first valid Chainlink BTC/USD observation published at or after maturity. Anyone can bring the evidence on-chain, but nobody gets to shop around for a nicer round.

## The rule

A candidate only counts when:

- it passes task 4's answer and timestamp checks;
- `updatedAt >= maturity`;
- `updatedAt <= maturity + maxObservationDelay`; and
- its predecessor and the intervening history show there was no earlier valid post-maturity round.

We store the answer, proxy round ID, aggregator address, local aggregator round ID and update time. `ST` gets written once.

The initial fixing has to exist before this can happen. Both its transaction and its feed timestamp must be before maturity. That keeps `S0` and `ST` in the right order even when the configured feed-clock skew straddles the boundary.

## Chainlink phases are the annoying bit

A proxy round ID is a phase plus a local aggregator round ID. Subtracting one from the combined number and hoping for the best does not work.

- In one phase, start from an answered pre-maturity predecessor and inspect the IDs before the candidate.
- Across a phase change, check that the predecessor is the old aggregator's tail, then inspect the new phase from its first local ID.
- Resolve aggregator addresses from the proxy rather than accepting them from the caller.
- Check the candidate aggregator's decimals and description. A phase change must not silently turn an 8-decimal BTC price into an 18-decimal number, or swap in a different asset with the same decimals.
- Cap the walk at 32 IDs and fail closed if any of them cannot be read. A revert cannot prove an ID was merely skipped rather than a published round becoming unavailable.

There are two known ways the primary route can fail closed: a retired aggregator can carry on publishing after the proxy has moved on, and a sparse or unreadable stretch can interrupt the bounded walk. Neither case gives anyone a price-selection right. Task 9 adds the delayed fallback for a genuinely stuck primary route.

## Who submits it?

Anyone. The caller pays the gas and supplies the two endpoint IDs; immutable terms and Chainlink history decide whether the proof works. Waiting for a later favourable print just gets you an `EarlierEligibleRound` revert.

## Cases we need covered

- Maturity between two ordinary rounds and exactly on a round.
- Candidates before maturity, after the observation deadline and too far in the future.
- A later candidate when an earlier valid round exists.
- A phase change, including a false predecessor and changed decimals or description.
- An unreadable local ID and a walk over the 32-ID limit.
- A second submission after `ST` is stored.
- An initial fixing attempted at or after maturity.
- An initial round timestamped at maturity even though its transaction lands just beforehand.

## Done means

- One fixed history gives one answer.
- Changing phase cannot change the units or identity of that answer.
- Bad evidence reverts without leaving half a fixing behind.
- The stored record identifies the proxy round and the underlying aggregator round well enough to replay the lookup off-chain.

## Not in this PR

No committee gets to choose an ordinary maturity observation. The delayed fallback for an unusable primary path stays in task 9.
