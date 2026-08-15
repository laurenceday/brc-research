# Task 06: take subscriptions and make failed raises boring

## What we're building

Eligible investors put USDC into one fixed BRC series and receive the same number of note base units. If the raise does not clear its minimum, the current note holders burn their notes and pull the USDC back themselves.

## Funding states

The state machine starts `Funding`, then goes to either `Funded` or `Cancelled`. Later PRs add activation and settlement; this one cannot skip into them.

- Subscriptions stop at the hard cap or funding deadline, whichever comes first.
- The hard cap is the series notional.
- A full-cap raise can be finalised early. A partly filled successful raise waits until the deadline.
- After the deadline, anyone can finalise a raise at or above the minimum, or cancel one below it.
- Cancellation is terminal and opens pull refunds.

## Notes

One settlement-asset base unit mints one note base unit, and the note copies the asset's decimals. The transfer policy is fixed at deployment.

Restricted notes check the payer and mint recipient during subscription. Direct transfers check sender and recipient; delegated transfers also check the operator. Eligibility can change, but it never gates a cancellation refund. Losing a credential is not a licence to confiscate somebody's USDC.

Every subscription, finalisation, cancellation and refund emits the post-action note total.

## Asset accounting

The vault checks the actual token movement instead of trusting an ERC-20 return value. Standard `true` returns and old no-return tokens are accepted; false returns, malformed returns and non-exact balance deltas revert.

Outstanding notes are the liability. The vault must hold at least that much USDC, but it may hold more: anyone can send a token directly to any ERC-20 recipient, so an unsolicited one-unit donation cannot be allowed to freeze the raise. Surplus never mints notes and remains outside subscription accounting. A deficit, inbound fee or short-paid refund still stops the transaction.

There is no token approval, Wildcat deposit, arbitrary call, delegate-call or sweep function here.

## Cases covered

- Partial fill, exact cap, over-cap and deadline boundaries.
- Early full-cap finalisation, post-deadline finalisation and underfunded cancellation.
- Refunds after notes move between investors, including the last holder.
- Repeated transitions and repeated refunds.
- Restricted sender, recipient and operator paths, plus unrestricted transfers.
- False-return, no-return, fee-charging and rebasing token behaviour.
- Unsolicited settlement-token surplus before subscriptions, finalisation and refunds.
- Refunds after the controller revokes a holder's eligibility.

## Accounting rules

- Note supply never exceeds notional.
- Minting `x` notes requires this call to increase vault assets by exactly `x`.
- During Funding and Cancelled, vault assets cover every outstanding note; surplus is ignored and deficits fail closed.
- A successful refund decreases both the holder's notes and their outstanding asset claim by the same amount.

## Not in this PR

No Wildcat market verification or deposit, no `S0`, no maturity price and no note settlement.
