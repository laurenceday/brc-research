# Task 09: add default recovery and oracle fallback

Status: implemented and merged. This step added the partial-recovery route and the delayed fallback for an unusable primary maturity proof.

## Market recovery shipped

The vault may queue its complete position from maturity without waiting for the BTC fixing. After `maturity + recoveryDelay`, anybody may move a `Withdrawing` series into `Recovery` while Wildcat lender supply remains unpaid. A fully paid claim stays on normal settlement even if the borrower did not formally close the empty market.

Recovery keeps note redemption closed while payments can still arrive. At or after the fixed write-off time, finalisation:

- requires every recorded batch to account for the complete activated scaled position;
- requires each expiry to have passed;
- executes every amount then withdrawable;
- derives proceeds from cumulative Wildcat withdrawal status rather than the vault's loose token balance;
- reserves all recovered proceeds for noteholders; and
- marks the borrower rebate as resolved at zero.

Anything paid or donated after that snapshot sits outside noteholder claims. There is no reopen function.

## Oracle fallback shipped

Fallback opens after the primary observation window and an additional waiting period. Only an immutable ratifier may occupy the proposal slot. A proposal fixes the price, observation time, source identifier and evidence hash, then starts a challenge period.

Approval requires signatures from the immutable threshold. Each signature binds the chain ID, oracle address, series ID, proposal nonce, price, observation time, evidence hash and source. Signatures may be relayed by any account. The implementation accepts ECDSA EOAs only; it does not support ERC-1271 contract wallets.

Any ratifier may veto a pending proposal. A replacement receives a new nonce and cannot reuse old approvals. A valid primary Chainlink proof cancels a pending fallback. Once a threshold-approved fallback is final, it remains the stored maturity fixing.

The contract enforces time, quorum, replay and source rules. Ratifiers remain responsible for deciding whether the primary route is genuinely unavailable and whether the cited offchain evidence is correct.

## Evidence

`test/BRCRecovery.t.sol` covers recovery timing, partial payments, valid fixings during default, full-performance exclusion, delayed fixing, paid-but-open markets, write-off timing, expired batches and the maximum adopted-batch gas case.

`test/BtcUsdFallback.t.sol` covers both delays, proposal authority, threshold, challenge, duplicate and wrong-domain signatures, veto and replacement, primary cancellation and invalid ratifier sets.

## Boundary of this step

Task 09 did not decide ratifier membership, legal authority, fallback-source licensing or the commercial write-off policy. Those remain deployment and legal decisions. It also did not add reproducible deployment tooling or the final review package; tasks 10 and 11 did that work.
