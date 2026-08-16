# The BTC barrier note in one page

This is a discussion sheet for the research prototype. It is not an offer, recommendation, price,
tax analysis or claim that a live series is ready.

## The trade

Investors fund a fixed-term borrower through one note issuer. They receive notes, not direct
facility positions. The issuer holds the whole lender position and applies a BTC/USD-linked cash
payoff at maturity.

The economic exchange is simple:

- the lender takes borrower credit risk and sells the borrower a BTC downside put;
- the borrower pays the lender return and may earn a cash rebate if BTC finishes at or
  below the barrier; and
- the borrower receives that rebate only after the facility claim has been paid completely.

The lender gets no BTC upside. Borrower default does not create a rebate.

## The implemented example

| Term | Research example |
| --- | --- |
| Face notional | 1,000,000 USDC |
| Term | 90 days |
| Lender return | 12% APR test input, not a price or offer |
| Reference | Ethereum Chainlink BTC/USD Data Feed |
| Strike | BTC/USD at vault deployment |
| Barrier | 60% of the strike |
| Observation | Once at maturity; equality breaches |
| Settlement | Cash in USDC |
| Direct facility lender | The vault only |

The deployable path requires the full notional before activation. The current code supports this
BTC/USD European observation only. It does not support an arbitrary index, continuous barrier,
autocall, physical BTC delivery or a periodic cash coupon.

## What happens at maturity

Assume the strike is 100,000, the barrier is 60,000 and the fully collected facility proceeds are
1,030,000 USDC. The proceeds are a round payoff input, not a 90-day accrual calculation from the 12%
test APR. Live proceeds depend on the market's actual accrual path.

| BTC/USD maturity fixing | Result | Borrower rebate | Pool for notes |
| ---: | --- | ---: | ---: |
| 120,000 | No breach | 0 | 1,030,000 |
| 60,001 | No breach | 0 | 1,030,000 |
| 60,000 | Barrier breached | 400,000 | 630,000 |
| 40,000 | Barrier breached | 600,000 | 430,000 |
| 0 | Barrier breached | 1,000,000 | 30,000 |

The one-unit move from 60,001 to 60,000 is a cliff. Once the barrier is breached, loss is measured
from the 100,000 strike. Accrued facility return remains in the note pool. For a call script, use
the [worked example](worked-example.md).

If the Wildcat claim remains partly unpaid and enters recovery, the BTC formula does not run. The
borrower rebate is zero and the authenticated assets collected by the recovery snapshot belong to
notes. Later payments and donations do not enlarge that fixed pool.

## Why either side might discuss it

For a borrower, the contingent rebate can reduce liabilities in a BTC crash after complete loan
performance. That may match a business whose own balance sheet deteriorates when BTC falls. The
cost is a higher funding requirement than plain credit might carry, plus operating, legal and hedge
work.

For a lender, the return may compensate for ordinary borrower credit, the written BTC put,
illiquidity and operating risk. It is not “BTC yield” and cannot be assessed from APR alone.

## Questions for the first call

1. What risk is the borrower trying to hedge?
2. What exact asset, index, ETF, future, NAV or rate should the note reference?
3. What term, barrier and maximum principal loss can each side accept?
4. Which maturity time, market session and holiday rule should govern?
5. Which settlement asset, noteholders and transfer rules are contemplated?
6. How should the ordinary credit spread and option premium be priced and hedged?
7. What oracle, fallback evidence and data rights are available for that exact reference?
8. Which legal entities, jurisdictions, documents, accounting and tax advisers are involved?

## Present status

The contracts and operating material are a research prototype. There is no external audit, legal
sign-off, approved manifest, index licence, live deployment or secondary market. Read the
[worked example](worked-example.md), [primer](../primer.md), [lender brief](lender-brief.md),
[borrower brief](borrower-brief.md) and [reference-asset survey](../research/reference-assets-and-oracles.md)
before turning a discussion into proposed terms.

Choose the lender or borrower route from those links; do not use this page by itself for diligence
or approval.
