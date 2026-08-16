# Task 07: bind and activate the Wildcat market

Status: implemented and merged. This step made the funded vault the only direct lender in a market deployed through `SingletonFixedTermHooks`.

## Upstream baseline

The implementation uses `v2-protocol` commit `99bb85840a77a56fa5f64504a60ec126b6047cf5` from PR 124. The repository, manifest and dependency check pin the commit rather than a branch name.

## What shipped

Before moving settlement assets, `activate()` checks:

- the constructor-bound market address and factory calculation;
- settlement asset, operational borrower, registered borrower principal and empty pending-borrower slot;
- notional cap, APR, reserve ratio, delinquency fee, delinquency grace period and withdrawal-batch duration;
- fee recipient and activation-time protocol fee;
- the `SingletonFixedTermHooks` identity and administrator;
- a sealed provider configuration with one pull provider, no push provider and a zero TTL;
- the singleton provider, its factory code hash and its calculation with the vault as lender;
- deposit, transfer, queue-withdrawal, close-market and APR/reserve hook dispatch;
- deposit and transfer access, disabled market-token transfers and no withdrawal credential requirement;
- `fixedTermEndTime == maturity`; and
- disabled early closure and term reduction.

The two withdrawal flags have different jobs. `HooksConfig.useOnQueueWithdrawal()` is true so the fixed-term hook receives the call and can enforce maturity. `HookedMarket.withdrawalRequiresAccess` is false so the vault's exit is not separately credential-gated.

Activation then reads the precommitted initial fixing, approves exactly the notional, deposits it, clears the allowance and records the scaled market position. It checks the vault and market token deltas and starts from an empty market with no existing vault position.

The whole activation is one transaction. A failed check or deposit rolls back the deposit and allowance. It does not alter the `S0` stored when the vault was deployed.

## Evidence

`test/BRCActivation.t.sol` deploys the pinned singleton fixed-term stack and covers the passing path, delegated borrower identity, permissionless activation, approval-reset tokens, scale rounding and rejection of transfer-fee assets. It mutates every market, hook, provider and fixed-term condition checked by activation. It also proves that unrelated lenders, market-token recipients, early closure, term reduction, repricing and provider mutation are blocked.

## Boundary of this step

Task 07 deposited the note proceeds but did not add maturity withdrawals, redemptions or default recovery. Wildcat governance, SphereX, sanctions and borrower-identity administration remain external trust assumptions recorded by the manifest; activation does not freeze them.

Next implementation record: [Task 08, normal settlement](08-normal-settlement.md).
