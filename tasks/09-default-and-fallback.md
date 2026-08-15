# Task 09: add default recovery and oracle fallback

## Aim

Define the two exceptional paths without weakening the ordinary one: partial Wildcat recovery belongs entirely to noteholders, while an unavailable maturity observation requires delayed, contestable evidence rather than an administrator price.

## Market recovery

Enter `Recovery` when the normal full-performance condition cannot be met after the contractual grace period or when Wildcat accounting records a terminal shortfall.

- Reserve every recovered settlement-asset unit for noteholders.
- Keep accepting and accounting for later Wildcat recoveries.
- Never calculate or pay a borrower rebate from a partial recovery.
- Permit pro-rata interim redemptions only if cumulative accounting gives existing and later claimants the same economic treatment.
- Add a terminal recovery or write-off transition with an objective delay and authority stated in the series terms.
- Emit cumulative debt, withdrawal, recovery, redemption and write-off figures at every transition.

Default and oracle failure are independent. A valid `ST` does not entitle the borrower to a rebate when the market has underperformed, and borrower default must not select a convenient BTC price.

## Oracle fallback trigger

The fallback path opens only when:

- maturity and `maxObservationDelay` have passed;
- no primary Chainlink round can satisfy the task 5 rule; and
- the additional fallback waiting period has elapsed.

An oracle shutdown, proxy migration or inaccessible historical round may satisfy the first two conditions. A temporarily inconvenient price may not.

## Proposal and challenge

- Any account may propose an answer, observation time, source identifier and evidence hash after the trigger.
- Start a challenge period on proposal; do not write `ST` yet.
- A proposal needs the immutable ratifier threshold from the series terms after the challenge period.
- Ratifiers sign the complete series identifier, proposed value, observation time, evidence hash, source and chain ID.
- A competing proposal, successful challenge or recovered primary Chainlink proof cancels the pending proposal under stated priority rules.
- Once accepted, store the fallback record once and expose every signature and evidence reference needed for review.

The legal terms should name the authoritative off-chain source and correction convention. Code should enforce time, quorum and replay rules; it cannot decide whether a news page is financially authoritative.

## Tests to add

- Partial recovery before and after a valid maturity fixing.
- Several late recoveries with redemptions between them.
- Borrower attempt to claim a rebate during recovery.
- Fallback proposal before each waiting period expires.
- Duplicate, expired, wrong-chain and wrong-series signatures.
- Threshold changes attempted after deployment.
- Competing proposals and a primary proof arriving during challenge.
- Cancellation, replacement and repeated finalisation.
- Terminal write-off followed by an unexpected token transfer.

## Acceptance

- No default path transfers value to the borrower.
- No single account can set `ST` immediately.
- Primary Chainlink evidence wins whenever the contractual primary rule remains provable.
- Recovery and fallback records are reproducible from emitted data and referenced evidence.

## Review requirement

Treat this branch as a separate security and legal review item. Ratifier composition, evidence custody, challenge standing, market-default timing and write-off authority all need explicit decisions before deployment.
