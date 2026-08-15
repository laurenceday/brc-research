# Example BTC BRC terms

These are the terms for the research series. They are not a priced offer, and they do not settle the note's legal or tax treatment.

## Instrument

The note is a 90-day, USDC-denominated barrier reverse convertible linked to BTC/USD. Investors fund a vault, which becomes the sole lender in a fixed-term Wildcat market. The vault issues one note unit for each smallest unit of USDC subscribed.

The Wildcat position accrues the lender return. The note pays at maturity instead of sending out a running cash coupon.

## Example parameters

| Term | Value |
| --- | --- |
| Network | Ethereum mainnet |
| Settlement asset | USDC |
| Face notional, `N` | 1,000,000 USDC |
| Term | 90 days |
| Wildcat APR | 12%, encoded as 1,200 bips |
| Reserve ratio | 10%, encoded as 1,000 bips |
| Reference | Standard Chainlink BTC/USD proxy |
| Strike, `K` | Initial fixing `S0` |
| Barrier, `B` | 60% of `S0` |
| Observation | European, once at maturity |
| Breach | `ST <= B` |
| Settlement | Cash in USDC |

A final deployment may use different commercial parameters. Whatever they are, the manifest must record them without changing the formulae below.

## Price observations

`S0` is a fresh Chainlink BTC/USD answer, recorded when the vault activates and deposits the funded notional into Wildcat.

`ST` is the first valid Chainlink BTC/USD proxy round with an `updatedAt` at or after maturity, but no later than `maturity + maxOracleDelay`. A settlement caller cannot pick a later round just because its answer looks nicer.

The feed address, decimals and description hash are fixed in the series terms and checked onchain. A missing or invalid answer pauses settlement; it never means the barrier was missed.

## Payoff

For a fully performed Wildcat market:

```text
if ST > B:
    slash = 0
else:
    slash = floor(N * (K - ST) / K)

borrowerRebate = slash
noteholderPool = actualWildcatProceeds - slash
```

The slash cannot exceed `N`. It applies to face principal, not accrued Wildcat interest.

Say `K` is 100,000, `B` is 60,000 and `ST` is 55,000. The slash is 45% of face principal, so noteholders keep 55% of principal plus the Wildcat interest actually collected. If `ST` is 65,000, the European barrier was not breached and noteholders keep full principal plus collected interest.

## Default

Normal BRC settlement needs the market to close and the vault to collect its complete Wildcat claim. Until that happens, the series stays in recovery. Partial recoveries belong to noteholders and the borrower gets no barrier rebate.

Any later write-off, negotiated recovery or fallback price process has to follow rules fixed before subscriptions open.
