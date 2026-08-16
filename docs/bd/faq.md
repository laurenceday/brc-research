# BRC discussion FAQ

This FAQ is for professional discovery calls about the research prototype. It does not answer
whether a person should invest, borrow or receive any tax, accounting or legal treatment.

## Product

### Is this a loan or an option?

Economically, both. The vault lends through Wildcat and the lender sells the borrower a BTC put.
Legally and for accounting or tax, the answer depends on the final entities, documents and
jurisdictions.

### Is this a bond?

The prototype issues ERC-20-like vault notes over one Wildcat lender position. Calling that a bond
does not settle its legal classification.

### Does the lender receive BTC upside?

No. BTC appreciation does not increase the note pool. The linked leg only reduces face principal
after a barrier breach in normal settlement.

### Does a 60% barrier cap loss at 40%?

No. At barrier equality, the example loses 40% of face immediately because loss is measured from
the strike. A lower fixing can slash up to all face principal.

### Is the barrier monitored all term?

No. The implementation observes once at maturity. Continuous, daily and autocall structures need
different code, data and pricing.

### Is there a coupon?

There is no periodic cash coupon in the prototype. The Wildcat lender return accrues in the market
and is collected through settlement or recovery.

### Is 12% the proposed return?

No. It is an example input used in the repository. A real price must separate ordinary credit,
option value, liquidity, operations and costs.

## Borrower outcome

### Can the borrower pay less when BTC falls?

Not into Wildcat. It must pay the complete lender claim. After collection, a breached barrier can
create the contractual rebate from the vault.

### Can the borrower default and still receive the BTC rebate?

No. Recovery marks the borrower rebate as satisfied at zero and reserves collected assets for
notes.

### Can the borrower close or reprice the market early?

The fixed-term hook policy blocks early closure, term reduction, and APR or reserve-ratio changes
before maturity. Early repayment does not end lender accrual or settle the option.

### Does the rebate recipient follow a later borrower-account change?

No. The recipient is fixed at deployment. A later principal succession in the identity registry
does not rewrite it.

## Lender outcome

### Is principal protected?

No. Normal BTC settlement can slash all face, and Wildcat default can also produce a partial or zero
recovery.

### Does Wildcat secure the debt?

No. Wildcat accounts for the unsecured market, access policy, interest, delinquency and
withdrawals. Singleton lender status prevents another direct lender entering; it does not provide
collateral.

### What happens to interest after a BTC breach?

The slash applies to face notional. Collected Wildcat interest remains in the note pool.

### What happens if Wildcat pays only part?

After the recovery delay and write-off conditions, the vault fixes the authenticated assets it has
collected for notes. There is no borrower rebate. Later payments are outside the fixed claims.

### Can holders exit early?

There is no vault redemption before settlement and no promised secondary market. Transfers may
also be restricted by eligibility policy.

## Oracle

### Can we choose any Chainlink feed in the manifest?

No. The code and terms implement one Ethereum Chainlink BTC/USD proxy shape. Another asset needs
source-specific code, tests and review even if it exposes `AggregatorV3`.

### What does “first valid round” mean?

The maturity value is the first valid proxy round at or after maturity within the observation
window. The caller supplies predecessor evidence, and the contract scans intervening round IDs so a
later favourable value cannot be selected.

### What if Chainlink is unavailable?

After the observation window and waiting period, an immutable ratifier can propose evidence from
the precommitted fallback source. A threshold must approve, any ratifier may veto, and a challenge
delay must pass. A valid primary proof cancels a pending fallback.

### Why not use a Safe for fallback?

The current verifier uses ECDSA recovery and rejects addresses with deployed code at construction.
Ratifiers must be rehearsed ECDSA EOAs.

### Can this reference the S&P 500?

Not today. No official S&P 500 source suitable for this product was verified, and S&P DJI treats
structured-product use as licensed. Chainlink's public `SPX/USD` result is SPX6900, not the S&P 500.
The [oracle survey](../research/reference-assets-and-oracles.md) explains the technical and rights
work.

### What about SPY instead?

SPY is an ETF share, not the index. It introduces fees, distributions, exchange sessions and
tracking basis. It can be discussed only as a different economic reference.

### Can we use Pyth, RedStone, Chronicle, API3 or UMA?

They are researched routes, not current adapter options. Pull reports, read permissions, feed IDs,
historical evidence and dispute systems each need a separate design.

## Wildcat and operations

### Must the borrower formally close the Wildcat market?

No. Normal settlement needs the vault's Wildcat lender supply to be zero and the tracked
withdrawals collected. Formal closure is not required.

### Can the vault queue before the BTC fixing arrives?

Yes. Queueing starts at maturity and is independent of the maturity fixing. Normal finalisation
still waits for the fixing.

### Are Wildcat fees fixed?

The vault checks the activation-time fee and recipient, but governance can later change the fee
within the protocol ceiling. In default, protocol fees can reduce lender recovery.

### What can SphereX do?

Wildcat's SphereX engine runs around market calls and can be changed by external administration. A
hostile or broken engine can block queueing or withdrawal. The vault has no local bypass.

### What if the vault address is sanctioned?

Wildcat can quarantine the position or withdrawal. The vault can adopt an authenticated sanctions
batch and continue after assets reach it, but cannot extract assets from escrow itself.

### What if operations miss the final queue horizon?

The onchain path can remain stuck in `Active`; there is no privileged jump to recovery. The launch
plan needs an offchain transaction and legal fallback for that case.

## Status and governance

### Is the code audited?

No external audit has been completed. The repository contains internal review, unit, fuzz and
stateful test results, but those are not a substitute.

### Is there a live series?

No. There is no approved manifest, production deployment, offering, index licence or completed
operational rehearsal.

### Can the vault be upgraded or swept?

No. It has no upgrade, general executor or admin sweep. That limits intervention as well as
administrative power.

### Does the historic Swiss tax treatment apply?

No conclusion follows. The historic treatment separates bond interest and option premium under
specific Swiss rules and product conditions. A live onchain series needs advice for every entity,
holder, cash flow, jurisdiction and date.

### What should happen next after a useful call?

Complete the [discovery guide](discovery-guide.md), price plain credit and the option separately,
score the exact oracle route, assign data-rights and legal owners, then decide whether the proposed
series is close enough to the implementation to justify engineering.
