# BRC infographic sourcebook

These diagrams are source-controlled meeting aids. They explain relationships; they are not legal
structure charts, transaction confirmations or proof that a series is ready. Copy the Mermaid
source into a deck only with the boundary and labels intact.

## 1. Money flow

```mermaid
flowchart LR
  L[Lenders] -->|settlement asset| V[BRC vault]
  V -->|sole lender deposit| W[Wildcat market]
  W -->|borrow| B[Borrower]
  B -->|repayment and lender return| W
  W -->|withdrawal proceeds| V
  V -->|note redemption| L
  V -->|rebate only after full payment and breach| B
```

The vault, not each noteholder, is the sole direct Wildcat lender. The borrower rebate is a vault
settlement payment after complete Wildcat performance.

## 2. Barrier cliff

```mermaid
flowchart LR
  A[ST above barrier] -->|slash zero| N[Notes keep all collected proceeds]
  C[ST one unit above barrier] -->|slash zero| N
  D[ST equals barrier] -->|loss measured from strike| E[Cliff: 40% face slash at a 60% barrier]
  F[ST falls further] -->|slash grows| G[Up to all face at ST zero]
```

This is a European maturity observation. Equality breaches. The lender receives no BTC upside and
the slash applies to face, not collected interest.

## 3. Contract lifecycle and independent oracle track

```mermaid
flowchart LR
  D[Deploy and store S0] --> F[Full raise]
  F --> A[Activate sole-lender market]
  A --> Q[Queue complete position at maturity]
  D -. primary or fallback evidence .-> O[Store ST]
  Q --> P{Wildcat lender supply zero?}
  O --> N[Normal settlement gate]
  P -->|Yes| N
  P -->|No, after recovery delay| R[Recovery]
  N --> X[Redeem notes and claim any rebate]
  R --> Y[Redeem fixed recovery pool; no rebate]
```

Queueing does not wait for `ST`. Recovery does not use the BTC payoff.

## 4. Normal and recovery waterfalls

```mermaid
flowchart TB
  A[Authenticated Wildcat proceeds] --> B{Full lender performance?}
  B -->|Yes| C{BTC barrier breached?}
  C -->|No| D[All proceeds to note pool]
  C -->|Yes| E[Face-linked rebate to fixed borrower recipient]
  E --> F[Remaining proceeds to note pool]
  B -->|No, recovery path| G[Collect then-withdrawable recorded batches]
  G --> H[All snapshot proceeds to note pool]
  H --> I[Borrower rebate fixed at zero]
```

Normal settlement preserves any earned borrower rebate. Recovery deliberately does not.

## 5. Reference and oracle selection

```mermaid
flowchart TD
  A[What economic loss should be linked?] --> B[Name exact asset, index, ETF, future, NAV, rate or reserve]
  B --> C[Fix quote, units, session, calendar and corporate actions]
  C --> D[Find exact source, chain, address or report ID]
  D --> E{Implemented BTC/USD route?}
  E -->|Yes| F[Verify live proxy, history, metadata and rights]
  E -->|No| G[Design source-specific adapter and evidence rule]
  F --> H[Specify fallback and incident operations]
  G --> H
  H --> I[Obtain data and product rights]
  I --> J[Credit, pricing, legal and operational approval]
```

Do not start with a ticker search. Technical availability and permission to settle a financial
product are separate.

## 6. The risk exchange

```mermaid
flowchart LR
  subgraph Lender
    L1[Supplies fixed-term funding]
    L2[Takes borrower credit]
    L3[Sells BTC downside]
    L4[Takes liquidity, oracle, protocol and token risk]
  end
  subgraph Borrower
    B1[Pays Wildcat lender return]
    B2[Owes complete Wildcat claim]
    B3[May receive crash-state rebate after full payment]
    B4[Takes hedge basis and operating cost]
  end
  L1 --> B1
  L3 --> B3
  B2 --> L2
  L4 --- B4
```

The economic shorthand is unsecured borrower credit plus a put sold by lenders. Neither side
should reduce the discussion to headline APR.

## Presentation notes

- Put the barrier-cliff diagram beside the example payoff table from the [one-page](one-page.md).
- Use the waterfall diagram when explaining why default cannot create a rebate.
- Use the oracle-selection diagram before discussing a new reference asset.
- Keep “BTC/USD implemented; all other sources require review” on any extracted slide.
- Keep the prototype status and missing external audit, legal approval and live series on the final
  slide or follow-up page.
