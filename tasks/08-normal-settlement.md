# Task 08: implement normal maturity settlement

Status: implemented and merged. This step turns complete Wildcat performance and the stored BTC maturity fixing into a borrower rebate and a noteholder reserve.

## What shipped

At or after maturity, anybody may queue the vault's complete Wildcat position. The caller may supply up to eight authenticated pre-existing batch expiries, including a sanctions batch, and the vault queues any remaining live balance. The recorded batches must account for the full scaled position fixed at activation.

Queueing does not wait for `ST`. The maturity proof and the Wildcat withdrawal can progress in either order. Once a batch is withdrawable, anybody may execute it for the vault.

Normal finalisation requires:

- a stored maturity fixing;
- zero remaining Wildcat lender supply;
- every recorded batch to match the vault's account status;
- every batch to be fully burned and withdrawn;
- the sum of recorded scaled amounts to equal the activated position; and
- the vault balance to cover the authenticated batch proceeds above its activation baseline.

Formal closure of the otherwise empty Wildcat market is not required. Complete lender performance is the condition that matters.

The vault calculates the principal slash from `N`, `K`, `B` and `ST`. That amount becomes the borrower rebate. Authenticated Wildcat proceeds above the rebate, including accrued interest, become the noteholder reserve. Loose token donations do not enter either amount.

Noteholders burn their own notes and may choose the asset recipient. Non-final redemptions use `floor(noteholderReserve × noteAmount / N)`. The final holder receives the remaining reserve, including division dust. The borrower rebate is paid once to the borrower principal fixed at deployment.

## Evidence

`test/BRCSettlement.t.sol` covers no breach, exact barrier, deep breach, interest before and after principal repayment, queueing before `ST`, incomplete performance, the 32-bit expiry boundary, multiple and pre-existing batches, sanctions withdrawals, redemption order, note transfers, donations and repeated calls.

`BRCSystemInvariantTest` checks that aggregate claims do not change with ownership, call ordering or redemption order.

## Boundary of this step

Task 08 opens the borrower rebate only after complete performance. It does not let a partly paid market use the normal waterfall. Partial recovery and oracle fallback arrived in task 09. Missing the last safe 32-bit queue time remains a terminal operational failure with no alternate onchain exit.
