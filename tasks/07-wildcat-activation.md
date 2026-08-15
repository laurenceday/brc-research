# Task 07: bind and activate the Wildcat market

## What this does

The funded vault becomes the only direct lender in a market deployed through `SingletonFixedTermHooks`. The USDC stays put until the vault has checked the live market against the series terms.

## Upstream pin

This branch uses reviewed v2-protocol commit `99bb85840a77a56fa5f64504a60ec126b6047cf5`, from PR 124. The commit goes in the manifest; a moving branch name does not.

## Market acceptance checks

Before it approves or deposits a single unit, `activate()` checks:

- the market address equals the constructor-bound expected address;
- the settlement asset, operational borrower, registered borrower principal, empty pending-borrower slot, notional cap, APR, reserve ratio, delinquency fee, delinquency grace period and withdrawal-batch duration match the manifest;
- the fee recipient and activation-time protocol fee match the manifest;
- the hook instance identifies as `SingletonFixedTermHooks` from the pinned implementation;
- provider configuration is sealed;
- there is exactly one pull provider, no existing or push provider, and its TTL is zero;
- the singleton provider and factory calculation bind the vault as lender;
- the provider factory runtime matches the artifact hash recorded in the manifest;
- deposit and transfer dispatch are enabled;
- the raw queue-withdrawal access flag is false;
- `fixedTermEndTime` equals note maturity;
- `allowClosureBeforeTerm` and `allowTermReduction` are false;
- market-token transfers are disabled for this series; and
- the stored fixed-term policy prevents APR or reserve-ratio changes before maturity.

PR 124 does most of the construction work: five complete fixed-term words, no early-exit flags, a checked singleton-factory runtime, the expected provider and lender, and a sealed provider set. The vault still reads it all back. If the deployed market and the manifest disagree, the money does not move.

## Activation transaction

1. Require a successful, finalised raise and the complete series notional.
2. Run every market acceptance check.
3. Read the initial Chainlink fixing precommitted when the vault was deployed.
4. Approve exactly the notional to the market.
5. Deposit from the vault.
6. Clear any remaining allowance.
7. Store `Active` and emit the market, hook, provider, fixing and deposited amount.

It is one transaction. A failed deposit or final check rolls back the market deposit and allowance, but not the `S0` investors saw before funding.

## Tests to add

- A passing deployment from the pinned factories.
- A passing deployment through an operational borrower account whose registered principal administers the hook.
- One failing test for every acceptance check.
- Unrelated deposits and market-token recipients.
- Provider creation, addition and removal after construction.
- Pre-maturity closure, term reduction and APR or reserve-ratio change.
- Approval reset and a token requiring zero allowance before a new approval.
- Repeated activation and partial-notional activation.

## Done when

- Only the vault can become a direct market lender.
- No investor asset moves before all checks pass.
- After activation, the borrower cannot change the term, close early or reprice the series before maturity.
- The vault address and manifest identify the deployment and every constructor-level distribution control.
- The manifest records the Wildcat ArchController, SphereX admin, operator and current engine, and says plainly that they can change after activation.
- The manifest records the activation-time protocol fee, fee recipient, 10% ceiling, ArchController owner and update authority. The terms also say that accrued protocol fees rank ahead of an unpaid withdrawal in default.

## Not in this task

Do not add maturity withdrawals, note redemption or default recovery.
