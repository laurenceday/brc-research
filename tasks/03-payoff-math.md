# Task 03: implement BRC payoff mathematics

Status: implemented and merged. This step added the series types and pure arithmetic used to describe the cash-settled payoff.

## What shipped

`BRCSeriesTerms` stores notional, strike, barrier, maturity and settlement-asset decimals. `BRCMath` rejects zero notional, zero strike, zero maturity, a barrier above strike and settlement assets with more than 18 decimals.

For the example series:

```text
breached = ST <= B
slash = breached && ST < K ? floor(N × (K - ST) / K) : 0
noteholderPool = collectedAssets - borrowerRebate
```

The multiplication is safe in `uint256` because both factors are at most `uint128`. Division rounds down. A price at or above strike produces no slash even if another observation convention could otherwise describe it as breached.

The library contains helpers for barrier derivation, breach detection, principal slash, a capped borrower rebate, noteholder-pool accounting and pro-rata redemption. The live vault does not call the capped `borrowerRebate` helper. In normal settlement it calculates the full `principalSlash` and requires authenticated Wildcat proceeds to cover it; in recovery it sets the rebate to zero. The helper remains a tested arithmetic primitive rather than the live settlement route.

`BRCState` also established the lifecycle labels later used by the vault.

## Evidence

`test/BRCMath.t.sol` covers both sides of the barrier, equality, zero price, strike and higher prices, odd-value rounding and malformed terms. Its fuzz tests compare the slash with an independent reference calculation, check monotonicity below the barrier and prove that redemptions cannot exceed the pool.

`BRCSystemPayoffDifferentialTest` later checks the same payoff against exact rational quotient bounds over fuzzed full-width inputs.

## Boundary of this step

Task 03 added no state transitions, note token, Chainlink read, Wildcat deposit or asset transfer. Later tasks decide when the arithmetic can be used and which party receives each amount.

Next implementation record: [Task 04, oracle foundation](04-oracle-foundation.md).
