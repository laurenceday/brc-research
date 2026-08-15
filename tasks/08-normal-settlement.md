# Task 08: implement normal maturity settlement

## Aim

Turn a fully paid Wildcat claim and the fixed BTC maturity observation into two pots: the borrower's rebate and the assets backing note redemption.

## Settlement sequence

After maturity, anybody may move the series along:

1. Prove and store `ST` through the task 5 adapter.
2. Queue the vault's complete live Wildcat balance while Wildcat can still represent the batch expiry. If the sanctions path already queued it, supply and adopt that authenticated expiry.
3. Record every batch needed to reconstruct the scaled position minted at activation.
4. After expiry, execute the complete available withdrawal.
5. Require the market to be closed and the vault's contractual claim to have been collected in full.
6. Calculate the principal slash and borrower rebate through `BRCMath`.
7. Reserve accrued interest and unslashed principal for noteholders.
8. Make the borrower rebate claimable, then open note redemption.

These can be separate transactions. Calls are permissionless, progress only moves forwards and changing the order must not change either side's total payout.

## Full-performance test

Use Wildcat's own accounting to prove full performance; a token balance on its own is not enough. Keep these four things separate:

- principal deposited;
- interest and other amounts owed to the vault;
- amounts already withdrawn; and
- unrelated assets sent to the vault.

The borrower rebate becomes available only when the market is closed and the complete vault claim has been collected. A merely funded withdrawal batch is not enough.

## Redemption

- Burn notes and pay the holder's pro-rata share of the reserved noteholder pool.
- Use cumulative accounting so redemption order cannot create or destroy claims.
- Give the final note burn any division dust left in the reserve.
- Let a holder send their own redemption to another recipient. Any future delegated burn needs an allowance or signed authorisation.

## Tests to add

- No breach, exact barrier and deep breach.
- Interest accrued before and after the borrower repays principal.
- Queueing before maturity and executing before batch expiry.
- A funded but not closed market.
- Multiple withdrawal batches and prior partial withdrawals.
- A sanctions withdrawal queued and executed before the vault starts settlement.
- Construction and runtime calls at the last safe 32-bit settlement timestamp.
- Redemptions in every order, including transfers between settlement and redemption.
- Repeated fixing, queue, execution, finalisation, rebate and redemption calls.
- Direct settlement-asset transfers to the vault before finalisation.

## Accounting properties

- The borrower never receives accrued interest.
- `borrowerRebate + noteholderReserve` equals the assets attributed to this settlement.
- Total note redemptions never exceed the reserve.
- A complete note burn makes `noteholderReserve - redeemedAssets` zero.

## Not in this task

If the market cannot meet the full-performance test, or the safe queue window has passed, enter no borrower rebate path. Partial recovery, stale oracle resolution and write-off belong in task 9.
