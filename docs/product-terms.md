# Example BTC BRC terms

These are the terms for the research series. They are not a priced offer, and they do not settle the note's legal or tax treatment.

The deployable manifest path requires `minimumRaise == notional`. The underlying vault contract also
has an unconfigured test mode that can represent a partial minimum; that mode is not a supported BRC
series configuration.

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

`S0` is a fresh Chainlink BTC/USD proxy answer recorded when the vault is deployed. Investors can inspect the stored round, strike and barrier before subscribing. Activation reads that fixed value; it does not choose another observation.

`ST` is the first valid Chainlink BTC/USD proxy round with an `updatedAt` at or after maturity, but no later than `maturity + maxOracleDelay`. A settlement caller cannot pick a later round just because its answer looks nicer.

The market's withdrawal-batch duration is fixed in the series manifest and checked before activation. It controls the ordinary delay between queuing the vault's claim at maturity and being able to execute it if the borrower has not already closed the market.

The manifest also fixes the Wildcat delinquency fee and grace period: when extra delinquency compensation starts, and how quickly it accrues if the market cannot meet withdrawal demand.

The vault also checks the activation-time protocol fee and fee recipient before depositing. Wildcat governance can later move the fee, up to 1,000 bips. If the borrower pays in full, that adds to its debt without cutting the stated lender APR. In default, accrued protocol fees sit ahead of an unpaid lender withdrawal and can eat into noteholder recovery.

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

Normal BRC settlement needs the vault's complete Wildcat claim to be paid and collected. The
otherwise empty market need not be formally closed. The vault can queue its claim from maturity
while the BTC fixing is still pending. After the separate contractual `recoveryDelay`, recovery can
open only while that queued claim remains partly unpaid. This delay is distinct from Wildcat's
`delinquencyGracePeriod`, which controls delinquency accounting. Partial recoveries stay locked until
at least the fixed write-off time, then belong entirely to noteholders; the borrower gets no barrier
rebate. Finalisation first collects every amount then withdrawable from the recorded batches and
snapshots the pool. Payments arriving later are outside noteholder claims.

The write-off time, oracle fallback source, delays, ratifier set, signature threshold and single-ratifier veto all have to be fixed before subscriptions open. Ratifiers in this prototype must be ECDSA EOAs, not Safe or other contract wallets. The contract does not establish that a valid Chainlink round is absent; that remains part of the ratifiers' evidence check.

The Wildcat ArchController can replace the market's SphereX engine. A replacement can block withdrawal queueing or execution, and the BRC vault has no second route out after activation. The ArchController owner can change and push the protocol fee too. The manifest records the owner, SphereX roles, engine, fee recipient and fee seen before funding; the bits Wildcat can change remain live governance assumptions for the whole term.
