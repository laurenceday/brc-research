# Worked example for BD and credit calls

This is the room script for walking interested parties through the note. It abstracts away the
implementation as far as possible. Use “credit facility”, “note issuer”, “investor” and “reference
price” unless the counterparty asks how the prototype is wired.

It is not a term sheet, offer, price, suitability view or legal conclusion.

## The setup

The borrower wants fixed-term funding and also wants protection if BTC falls hard by maturity. The
investors are willing to fund the borrower and sell that downside protection, but only for a return
that pays for both ordinary credit and the option-like risk.

A sample three-path visual is available at [worked-example-paths.png](assets/worked-example-paths.png).
Use it as a slide panel only; keep the exact labels and numbers editable in the deck or handout.

Use these example numbers:

| Term | Example |
| --- | --- |
| Face amount | 1,000,000 USDC |
| Term | 90 days |
| Lender return | 12% APR test input, collected at settlement |
| Assumed proceeds for payoff arithmetic | 1,030,000 USDC |
| Initial BTC/USD level and strike | 100,000 |
| Barrier | 60,000, equal to 60% of strike |
| Observation | One maturity fixing |
| Breach rule | Breach if maturity fixing is at or below 60,000 |
| Settlement | Cash; no BTC delivery and no BTC upside for investors |

The proceeds figure is deliberately round. It is not calculated from the 12% test APR and 90-day
term; live proceeds depend on elapsed seconds and the facility's accrual path.

The borrower must repay the facility before it can receive any BTC-linked rebate. If the borrower
does not fully perform, the BTC formula is switched off and recovered cash belongs to investors.

## The 30-second explanation

“Think of this as fixed-term borrower credit plus a sold BTC downside put. If BTC finishes above
the barrier and the borrower pays, investors receive the collected cash. If BTC finishes at or
below the barrier and the borrower has still paid in full, part of face principal is rebated to the
borrower. If the borrower defaults, there is no BTC rebate; investors receive the recovery pool.”

Then show the three paths.

## Path 1: happy

BTC finishes well above the barrier and the borrower pays the facility in full.

| Item | Result |
| --- | ---: |
| Maturity BTC/USD | 120,000 |
| Barrier result | No breach |
| Borrower rebate | 0 |
| Pool for investors | 1,030,000 USDC |

Talk track:

“This is the ordinary state. The borrower paid a higher funding cost, but the hedge did not pay
out. Investors receive the collected cash. They do not receive extra BTC upside just because BTC
rallied.”

Credit point:

The outcome still depended on borrower performance. A good BTC print does not cure a bad borrower.

## Path 2: neutral, but tight

BTC finishes one unit above the barrier and the borrower pays in full.

| Item | Result |
| --- | ---: |
| Maturity BTC/USD | 60,001 |
| Barrier result | No breach |
| Borrower rebate | 0 |
| Pool for investors | 1,030,000 USDC |

Talk track:

“This is the useful teaching case. It looks dramatic on price, but the barrier was not breached.
Investors still receive the collected cash. The borrower bought protection, but the trigger was
missed by one unit.”

Credit point:

This is where the room should understand the binary observation. The barrier is not a sliding
discount above the trigger.

## Path 3: catastrophic

There are two different catastrophic conversations. Keep them separate.

### 3A. Market crash, borrower still pays

BTC goes to zero, but the borrower has paid the facility in full.

| Item | Result |
| --- | ---: |
| Maturity BTC/USD | 0 |
| Barrier result | Breach |
| Borrower rebate | 1,000,000 USDC |
| Pool for investors | 30,000 USDC |

Talk track:

“This is the maximum BTC-linked note loss after full borrower performance. The face amount is
rebated to the borrower. Investors keep only the collected excess return in this example.”

Credit point:

The investor was paid to accept this. Do not describe the return without showing this row.

### 3B. Borrower default

BTC also falls, but the borrower does not fully repay. Suppose the recovery snapshot collects
650,000 USDC.

| Item | Result |
| --- | ---: |
| Recovered cash | 650,000 USDC |
| BTC formula | Off |
| Borrower rebate | 0 |
| Pool for investors | 650,000 USDC |

Talk track:

“Default is not another way for the borrower to get the rebate. If the facility is not paid in
full, the BTC formula does not run. Whatever has been collected by the recovery snapshot belongs to
investors.”

Credit point:

This is still bad for investors. The no-rebate rule prevents borrower double relief; it does not
make default harmless.

## The cliff row

Show this immediately after the neutral path:

| Maturity BTC/USD | Barrier result | Borrower rebate | Pool for investors |
| ---: | --- | ---: | ---: |
| 60,001 | No breach | 0 | 1,030,000 |
| 60,000 | Breach | 400,000 | 630,000 |

Talk track:

“The one-unit move matters because equality breaches. Once the barrier is hit, the loss is measured
from the 100,000 strike, not from the 60,000 barrier. That is why the first breached value creates a
400,000 rebate.”

## How to handle the first questions

| Question | Answer |
| --- | --- |
| Is the 12% the offered price? | No. It is a test input. A real price separates plain credit spread, option value, liquidity, operations and costs. |
| Is principal protected? | No. Investors can lose face through the BTC formula after full payment, and they can also lose money through borrower default. |
| Does the borrower pay less into the facility when BTC falls? | No. It pays the facility first; the note issuer applies any rebate after collection. |
| Can this reference another asset or index? | Not by changing a ticker. The exact reference, data rights, observation rule, source evidence and code path need review. |
| Where does Wildcat fit? | In the prototype it accounts for the fixed-term credit facility. The commercial explanation does not need to start there. |

## Whiteboard order

1. Write `borrower credit + sold BTC downside`.
2. Write the four numbers: `N = 1,000,000`, `K = 100,000`, `B = 60,000`, `P = 1,030,000`.
3. Walk happy: `ST = 120,000`.
4. Walk neutral: `ST = 60,001`.
5. Walk the cliff: `ST = 60,000`.
6. Walk catastrophic full payment: `ST = 0`.
7. Walk catastrophic default: `650,000` recovery, no rebate.
8. Ask what risk the borrower actually wants to hedge.

Stop there unless the room can repeat the cliff and the no-rebate-on-default rule back to you.

## Deck pairing

Use this page with:

- [one-page](one-page.md) for the meeting handout;
- [infographics](infographics.md) for editable meeting diagrams;
- [lender brief](lender-brief.md) when the investor asks what it is being paid for;
- [borrower brief](borrower-brief.md) when the borrower asks what it is buying; and
- [FAQ](faq.md) for edge cases.
