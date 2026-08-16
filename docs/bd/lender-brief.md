# Lender brief: what the note pays for

This brief explains the lender side of the research prototype. It is educational material, not an
offer, recommendation, suitability assessment or return forecast.

## Start with the position, not the APR

Buying the note combines two risks:

1. an unsecured fixed-term Wildcat claim on the borrower; and
2. a BTC/USD put sold to that borrower, activated by a European maturity barrier.

The Wildcat APR is compensation specified in the market, not a guaranteed realised yield. Payment
depends on borrower performance, withdrawal and settlement. A higher rate can reflect plain credit
spread, option premium, liquidity and operating risk. This repository does not price those parts.

## The maximum principal outcome

In normal settlement, the BTC-linked slash can reach the full face notional. It cannot take accrued
Wildcat interest under the implemented formula. If BTC/USD is zero at maturity and Wildcat has paid
face plus interest completely, face principal becomes the borrower rebate and the note pool keeps
the collected interest.

The 60% barrier does not mean loss is capped at 40%. If the maturity fixing is one feed unit above
the barrier, there is no slash. At the barrier, the slash is the whole decline from strike to
barrier: 40% of face in the example. Below the barrier, it grows with the decline from strike.

The worked numbers and integer-rounding rules are in the [primer](../primer.md).

## What can improve the lender outcome

- BTC/USD finishes above the barrier, so the BTC-linked rebate is zero.
- The borrower pays the Wildcat claim in full, including the lender return.
- The position queues and withdraws on time without sanctions or SphereX interference.
- The primary fixing is proved promptly, avoiding delayed fallback operations.
- The settlement asset holds its expected value and transfer behaviour.

None of those points is a promise.

## What can damage it

### Borrower credit

The vault is the only direct Wildcat lender, but singleton access does not secure repayment. The
borrower can default. Recovery may return less than face and does not wait forever for future
payments.

### BTC downside and the barrier cliff

The lender sells downside without sharing in BTC appreciation. Barrier equality counts as breach,
and loss then starts at the strike rather than the barrier.

### Correlation

The worst case may combine a BTC crash with stress at a crypto borrower and stress in the
settlement asset or protocol. The recovery rule stops a defaulting borrower receiving the BTC
rebate, but it does not remove correlated credit loss.

### Liquidity and transfer

The prototype supplies no secondary market, early redemption or assured buyer. Transfer eligibility
may restrict who can receive or operate the notes. The borrower cannot shorten the Wildcat term,
but the lender still needs funding it can leave outstanding. The note exposes ordinary transfer
and allowance functions, but has no permit or delegated redemption; custody integrations need to
check the exact interface.

### Oracle and calendar

The primary path is one Chainlink BTC/USD proxy and a first-valid-round rule. A bounded proof can
fail or arrive late. The delayed fallback uses an immutable ECDSA ratifier set, threshold and
single-ratifier veto. Another asset or provider needs a new adapter and evidence rule.

### Protocol and governance

Wildcat governance, protocol fees, SphereX, sanctions handling and borrower identity remain live
external assumptions. A changed fee can rank ahead of unpaid lender recovery. A changed SphereX
engine can block queueing or withdrawal. The vault has no admin bypass.

### Settlement asset

A stablecoin may depeg, freeze transfers, charge fees or change contract behaviour. Exact
balance-delta checks reject some non-standard behaviour, but they do not make the asset risk-free.

### Terminal recovery

Recovery reserves what the vault has authenticated and collected by the fixed snapshot. Payments
and donations arriving later do not enlarge note claims and may remain trapped. Missing the final
safe withdrawal-queue horizon can leave the vault in `Active` with no onchain recovery transition.

## Questions to put to the borrower

- What is the legal borrowing entity and who receives a normal-settlement rebate?
- What assets, cash flows and obligations support the Wildcat claim?
- How does a BTC drawdown affect the borrower's ability to pay before any rebate exists?
- Why does the chosen barrier hedge that risk, and how was the option premium valued?
- What ordinary credit spread would the borrower pay without the BTC feature?
- How will the borrower fund Wildcat interest and any protocol-fee change through maturity?
- Who operates repayment, withdrawal and incident response?
- What reporting will lenders receive before maturity and during delinquency?
- What legal, accounting, tax and regulatory opinions will each side obtain?

## Questions for lender investment review

- Can the mandate hold unsecured credit combined with a written put?
- Is full face loss within the risk limit, including the barrier cliff?
- Can the position remain illiquid through the term and settlement window?
- Are the borrower, settlement asset, Wildcat and oracle exposures acceptable together?
- Which holders and transferees are permitted?
- Is the proposed observation rule objectively verifiable on the chosen calendar?
- Is the fallback authority and challenge process acceptable?
- What independent credit, smart-contract, legal and data-rights diligence is required?

## Evidence to request before funding

1. Final economic terms and payoff vectors, including barrier equality and zero-price cases.
2. Borrower credit materials and the plain-credit comparison.
3. Exact deployment manifest, addresses, code hashes and read-only verifier output.
4. Oracle address, metadata, observation rule, fallback source and ratifier rehearsal.
5. Wildcat hook policy, identity state, fees, SphereX roles and sanctions plan.
6. Transfer, custody, settlement and recovery operating procedures.
7. Legal documents, data and index rights, and jurisdiction-specific advice.
8. External smart-contract review and an independent launch rehearsal.

Those last two items do not exist for the research repository. The [review packet](../review-packet.md)
lists the full release blockers.

## The honest lender sentence

“I am lending to this borrower and selling it BTC downside under a cliff payoff; my return and
principal depend on credit, BTC, the oracle, Wildcat, the settlement asset and operations.”

If that sentence is not acceptable, the discussion should stop before APR.

Continue with the [discovery guide](discovery-guide.md) only after the lender can state the barrier
cliff, full-face principal exposure and borrower-credit risk without prompting.
