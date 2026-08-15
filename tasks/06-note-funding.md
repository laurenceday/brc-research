# Task 06: implement note funding and cancellation

## Aim

Let eligible investors subscribe USDC into a fixed BRC series, mint matching note claims, and recover funds exactly if the raise does not proceed.

## Funding states

Use an explicit state machine: `Funding`, `Funded`, `Cancelled`, then the activation and settlement states introduced by later tasks. No external call may skip a state.

- Subscriptions close at the earlier of the hard cap or funding deadline.
- The hard cap is the series notional.
- A minimum raise may be set in immutable terms.
- After the deadline, anyone may finalise a successful raise or cancel an underfunded one.
- Cancellation enables pull-based refunds and permanently disables activation.

## Note token

- Mint one note unit per settlement-asset unit subscribed, using a stated decimal convention.
- Burn notes on refunds and, later, redemption.
- Decide transfer policy at deployment. If transfers are restricted, enforce the rule in mint, transfer and transfer-from paths rather than relying on the Wildcat market hook.
- Emit subscription, funding-finalisation, cancellation and refund records with post-action totals.

## Asset handling

- Use balance-delta accounting when receiving the settlement asset, or reject fee-on-transfer and rebasing assets explicitly.
- Enforce checks before token movement.
- Do not approve or deposit into Wildcat in this task.
- Do not add a general call, delegate-call or arbitrary token sweep function.
- Permit recovery of an unrelated token only under a narrow rule that cannot select the settlement asset, notes or future market tokens.

## Tests to add

- Partial, exact-cap and over-cap subscriptions.
- Subscription at and after the deadline.
- Successful finalisation and underfunded cancellation.
- Refunds in every order, including a final dust holder.
- Repeated finalisation, cancellation and refund attempts.
- Restricted-transfer checks for sender, recipient and operator paths.
- Tokens that return false, return no value, charge a fee or rebase.

## Accounting properties

- During funding, settlement assets held equal outstanding note supply.
- Cancellation refunds exactly the accepted subscription amount in aggregate.
- No account can mint notes without increasing accepted assets by the matching amount.
- No successful series can exceed its immutable notional.

## Not in this task

Do not verify or fund a Wildcat market, record `S0`, calculate a maturity price or settle the notes.
