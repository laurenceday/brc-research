# Task 08: implement normal maturity settlement

## Aim

Turn complete Wildcat performance and the fixed BTC maturity observation into a borrower rebate and a redeemable noteholder pool.

## Settlement sequence

After maturity, any account may advance these calls:

1. Prove and store `ST` through the task 5 adapter.
2. Queue the vault's complete Wildcat market balance for withdrawal.
3. Record the withdrawal batch and its expiry.
4. After expiry, execute the complete available withdrawal.
5. Require the market to be closed and the vault's contractual claim to have been collected in full.
6. Calculate the principal slash and borrower rebate through `BRCMath`.
7. Reserve accrued interest and unslashed principal for noteholders.
8. Make the borrower rebate claimable, then open note redemption.

Steps may be separate transactions, but each transition is one-shot and permissionless. Reordering or repeating calls must not improve either party's payout.

## Full-performance test

Define full performance from Wildcat accounting fields, not from an assumed token balance. The implementation must distinguish:

- principal deposited;
- interest and other amounts owed to the vault;
- amounts already withdrawn; and
- unrelated assets sent to the vault.

The borrower rebate becomes available only when the market is closed and the complete vault claim has been collected. A merely funded withdrawal batch is not enough.

## Redemption

- Burn notes and pay the holder's pro-rata share of the reserved noteholder pool.
- Use cumulative accounting so redemption order cannot create or destroy claims.
- Assign final division dust by an explicit rule, preferably to the final note burn.
- Follow checks-effects-interactions and support a recipient distinct from the note owner only under a standard allowance or signed-authorisation path.

## Tests to add

- No breach, exact barrier and deep breach.
- Interest accrued before and after the borrower repays principal.
- Queueing before maturity and executing before batch expiry.
- A funded but not closed market.
- Multiple withdrawal batches and prior partial withdrawals.
- Redemptions in every order, including transfers between settlement and redemption.
- Repeated fixing, queue, execution, finalisation, rebate and redemption calls.
- Direct settlement-asset transfers to the vault before finalisation.

## Accounting properties

- The borrower never receives accrued interest.
- `borrowerRebate + noteholderReserve` equals the assets attributed to this settlement.
- Total note redemptions never exceed the reserve.
- Complete note burning reduces the reserve to zero, subject only to the stated dust rule.

## Not in this task

If the market cannot meet the full-performance test, enter no borrower rebate path. Partial recovery, stale oracle resolution and write-off belong in task 9.
