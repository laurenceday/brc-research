# Task 09: add default recovery and oracle fallback

## Aim

Define the two exceptional paths without weakening the ordinary one: partial Wildcat recovery belongs entirely to noteholders, while an unavailable maturity observation requires delayed, contestable evidence rather than an administrator price.

## Market recovery

The vault may queue the complete position from maturity without waiting for the BTC fixing. After the contractual grace period, anybody may move that `Withdrawing` series into `Recovery` only while the queued claim remains partly unpaid. A fully paid claim must use normal settlement, whether or not the borrower has closed the otherwise empty market. The prototype makes these choices explicit:

- Reserve every recovered settlement-asset unit for noteholders.
- Keep accepting and accounting for later Wildcat recoveries.
- Never calculate or pay a borrower rebate from a partial recovery.
- Keep redemptions closed while recoveries are arriving; this avoids giving early and late redeemers different claims.
- Use a write-off eligibility time fixed at deployment. Finalisation is permissionless after that time and snapshots the amounts paid by Wildcat in that transaction.
- Require the complete activated scaled position and an expired batch list before finalisation. Pull every then-withdrawable amount and derive the pool from cumulative Wildcat withdrawal status rather than the vault's loose token balance.
- Treat anything arriving after finalisation as surplus outside the noteholder pool.

Default and oracle failure are independent. A valid `ST` does not entitle the borrower to a rebate when the market has underperformed, and borrower default must not select a convenient BTC price.

## Oracle fallback trigger

The fallback path opens only when:

- maturity and `maxObservationDelay` have passed;
- the additional fallback waiting period has elapsed.

An oracle shutdown, proxy migration or inaccessible historical round may justify using it. A temporarily inconvenient price may not. Solidity cannot prove that a valid Chainlink round does not exist but remains unsubmitted, so the ratifiers carry that evidence obligation.

## Proposal and challenge

- Any immutable ratifier may propose an answer, observation time, the fixed source identifier and an evidence hash after the trigger. This stops an outsider occupying the single pending slot; the ratifier trust model already gives each ratifier a veto.
- Start a challenge period on proposal; do not write `ST` yet.
- A proposal needs the immutable ratifier threshold from the series terms after the challenge period. This prototype accepts ECDSA EOAs only; contract wallets require a later EIP-1271 implementation.
- Ratifiers sign the complete series identifier, proposed value, observation time, evidence hash, source and chain ID.
- Any one ratifier may veto the pending proposal. A replacement gets a new nonce and none of the old approvals.
- A valid primary Chainlink proof cancels a pending proposal. Once the threshold-approved fallback is final, it remains the stored fixing.
- Once accepted, store the fallback record once and expose every signature and evidence reference needed for review.

The legal terms should name the authoritative off-chain source and correction convention. Code should enforce time, quorum and replay rules; it cannot decide whether a news page is financially authoritative.

## Tests to add

- Partial recovery before and after a valid maturity fixing.
- Several late recoveries, with redemption attempts rejected until write-off.
- Borrower attempt to claim a rebate during recovery.
- Fallback proposal before each waiting period expires.
- Duplicate, expired, wrong-chain and wrong-series signatures.
- Invalid, duplicated and contract-wallet ratifier sets at deployment; there is no threshold setter afterwards.
- Competing proposals and a primary proof arriving during challenge.
- Cancellation, replacement and repeated finalisation.
- Permissionless terminal write-off followed by an unexpected token transfer, plus a late recovery queue that cannot finalise before expiry.

## Acceptance

- No default path transfers value to the borrower.
- No single account can set `ST` immediately.
- Primary Chainlink evidence wins while the fallback proposal is pending.
- Recovery and fallback records are reproducible from emitted data and referenced evidence.

## Review requirement

Treat this branch as a separate security and legal review item. Ratifier composition, evidence custody, challenge standing, market-default timing and write-off authority all need explicit decisions before deployment.
