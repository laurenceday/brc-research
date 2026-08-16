# Borrower brief: contingent liability relief after full payment

This brief explains the borrower side of the research prototype. It is not a financing proposal,
hedge recommendation, accounting conclusion or statement that a live series is available.

## What the borrower buys

The borrower receives fixed-term funding through a Wildcat market. In return for the lender terms,
it can receive a cash rebate after complete Wildcat performance if BTC/USD finishes at or below
the maturity barrier.

That rebate is crash-contingent liability relief. It is not permission to pay less into Wildcat.
The borrower must fund the complete lender claim first. The vault then applies the BTC payoff to
the collected assets.

If the market remains partly unpaid and the vault enters recovery, the rebate is zero. Every
authenticated unit collected by the recovery snapshot belongs to notes.

## When it can make commercial sense

The shape may suit a borrower whose balance sheet, revenue or risk capital worsens when BTC falls.
It pays more in ordinary states and may reduce its net liability in the defined crash state. That
is closer to buying a put from lenders than to finding cheaper debt.

The hedge is imperfect unless the borrower's loss matches the exact BTC/USD strike, barrier, term
and one-time observation. A business exposed to intraday drawdowns, basis, volatility or a basket
may not be hedged by one European BTC fixing.

## What it costs

Commercial pricing should separate:

- the borrower's plain unsecured Wildcat credit spread;
- the value of the BTC put sold by lenders;
- illiquidity and note-transfer restrictions;
- oracle, settlement and recovery operations;
- protocol, legal, data and distribution costs; and
- any dealer, arranger or hedge costs outside the contracts.

The 12% APR in the example is test data, not a price. A deep barrier does not make the put free.

## Obligations that remain

- Repay principal and accrued Wildcat lender return under the market.
- Meet any protocol fees and delinquency amounts applied by Wildcat.
- Keep the borrower account, identity and operational authorities working through settlement.
- Fund and staff repayment, monitoring, oracle, fallback and incident operations.
- Supply agreed credit reporting and legal documents.
- Accept that the fixed rebate recipient does not automatically follow later borrower-principal
  succession in the identity registry.

The fixed-term hooks block early closure, term reduction and APR or reserve-ratio changes before
maturity. Repaying early does not switch off lender accrual or create an early rebate.

## Normal settlement

Let `N` be face notional, `K` the initial BTC/USD fixing, `B` the barrier and `ST` the maturity
fixing.

```text
rebate = 0                                  when ST > B
rebate = floor(N * (K - ST) / K)           when ST <= B
```

The rebate cannot exceed face. It comes from completely collected Wildcat proceeds. Accrued
Wildcat interest remains for notes. The market need not be formally closed once the vault's lender
supply is zero and its withdrawals are collected.

## Default and recovery

The vault queues its complete position at maturity even if the BTC fixing is delayed. After the
separate `recoveryDelay`, recovery can open only if Wildcat lender supply remains unpaid. At the
write-off snapshot, the vault collects every then-withdrawable recorded batch and fixes the note
pool. There is no borrower rebate, even if BTC is below the barrier.

This makes the product asymmetric in the intended way: BTC downside can earn a rebate after full
performance, but non-payment cannot manufacture the same relief.

## Hedge and treasury questions

- Is the borrower naturally hurt by BTC spot, BTC volatility, crypto credit spreads or something
  else?
- Will the borrower hedge the put it has bought, leave it open or offset another exposure?
- Is a one-time Chainlink BTC/USD fixing close enough to the treasury risk?
- What liquidity is needed to pay Wildcat in full before receiving a possible rebate?
- How will a stablecoin depeg or freeze affect repayment and accounting?
- Does the borrower need to reserve for gross Wildcat debt, the contingent rebate or both?
- How are fair value, hedge accounting, embedded derivative and disclosure questions treated?

Those are questions for the borrower's advisers. The contracts do not answer them.

## Questions to ask prospective lenders

- What plain credit terms would they require without the BTC feature?
- What maximum principal loss and barrier cliff can their mandate accept?
- How do they value the written put and which market data do they use?
- What term, note transfer rule, reporting and recovery timetable do they need?
- Which settlement asset and custody route can they support?
- What external review and legal evidence are funding conditions?

## Questions for the internal approval meeting

1. What liability or business risk does the rebate hedge?
2. Is the payoff large enough in that state and affordable elsewhere?
3. Can the business pay the full Wildcat claim before receiving the rebate?
4. Is the maximum funding cost acceptable if BTC never breaches?
5. Are the oracle, fallback, Wildcat, settlement-token and sanctions dependencies acceptable?
6. Are the data rights and distribution rules settled for every target lender?
7. Who owns each launch, maturity, fallback and recovery action?
8. What happens offchain if the onchain queue horizon is missed or SphereX blocks withdrawal?

## The honest borrower sentence

“I am paying for unsecured funding and buying a defined BTC crash rebate from lenders, but I earn
that rebate only after the Wildcat claim is paid completely.”

The [product terms](../product-terms.md), [oracle survey](../research/reference-assets-and-oracles.md)
and [runbook](../runbook.md) give the contract and operating detail behind that sentence.

Use the [discovery guide](discovery-guide.md) to record the borrower's actual hedge, funding and
governance requirements before anyone changes the example terms.
