# Example BTC BRC terms

These terms describe the research series. They are not a priced offer and do not settle the legal or tax treatment of the note.

## Instrument

The note is a 90-day, USDC-denominated barrier reverse convertible linked to BTC/USD. Investors fund a vault. The vault is the sole lender in a fixed-term Wildcat market and issues one note unit for each smallest unit of subscribed USDC.

The Wildcat position accrues the lender return. The note pays at maturity rather than distributing a running cash coupon.

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

The final deployment may use different commercial parameters. The manifest must record them without changing the formulae below.

## Price observations

`S0` is a fresh Chainlink BTC/USD answer recorded when the vault activates and deposits the funded notional into Wildcat.

`ST` is the first valid Chainlink BTC/USD proxy round whose `updatedAt` is at or after maturity and no later than `maturity + maxOracleDelay`. A settlement caller must not be able to choose a later round because its answer is more favourable.

The feed address, decimals and description hash are fixed in the series terms and checked onchain. A missing or invalid answer pauses settlement. It never implies that the barrier was missed.

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

The slash is capped at `N`. It applies to face principal, not accrued Wildcat interest.

If `K` is 100,000, `B` is 60,000 and `ST` is 55,000, the slash is 45% of face principal. Noteholders keep 55% of principal plus the Wildcat interest actually collected. If `ST` is 65,000, the European barrier was not breached and noteholders keep full principal plus collected interest.

## Default

Normal BRC settlement requires the market to close and the vault to collect its complete Wildcat claim. Until then, the series remains in recovery. Partial recoveries belong to noteholders and the borrower receives no barrier rebate.

Any later write-off, negotiated recovery or fallback price process must follow rules fixed before subscriptions open.

