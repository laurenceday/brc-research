# Task 03: implement BRC payoff mathematics

## Aim

Put the series terms and cash-settlement arithmetic in a pure library before state, tokens or oracle calls can obscure it.

## Terms

Add a `BRCSeriesTerms` type containing notional, strike, barrier, maturity and the settlement-asset precision. Reject zero notional, zero strike, a barrier above the strike, and values that cannot be represented safely by later accounting.

For the example series, `K = S0` and `B = 60% × S0`. At maturity:

```text
breached = ST <= B
slash = breached ? floor(N × (K - ST) / K) : 0
borrowerRebate = min(slash, recoveredPrincipal)
noteholderPool = collectedAssets - borrowerRebate
```

If a future series permits `ST > K` while breached under a different observation convention, the implementation must clamp the slash at zero rather than underflow. Use full-precision multiplication and state every rounding direction in the library.

## Work

- Add pure functions for barrier derivation, breach detection, principal slash, borrower rebate, noteholder pool and pro-rata note redemption.
- Separate principal from accrued interest. The BTC put may reduce face value; it may not reduce the contractual coupon or other assets collected above principal.
- Define the settlement states used by later contracts without adding transition code.
- Add custom errors for malformed terms and impossible accounting inputs.
- Document units at every external edge: feed decimals, settlement-asset decimals and note-token decimals.

## Properties to prove

- `slash <= notional` for every accepted input.
- Lower `ST` cannot reduce the slash after the barrier has been breached.
- No breach produces a zero slash.
- Collected interest is never included in the borrower rebate.
- `noteholderPool + borrowerRebate == collectedAssets`.
- Sum of redemptions cannot exceed the reserved noteholder pool, regardless of redemption order.

## Tests to add

- One unit test on each side of the barrier and exactly at the barrier.
- `ST` at zero, at strike and above strike.
- Odd notionals and prices that expose rounding.
- Fuzz tests over all accepted term combinations.
- Differential tests against a simple high-precision reference implementation.

## Not in this task

Do not issue notes, read Chainlink, deposit in Wildcat or transfer a borrower rebate. This branch determines amounts; later branches decide when those amounts may move.
