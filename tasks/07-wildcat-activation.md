# Task 07: bind and activate the Wildcat market

## Aim

Make the funded vault the only direct lender in a market deployed through `SingletonFixedTermHooks`, then move the series notional only after the vault has verified every policy term on chain.

## Upstream pin

Implement against the reviewed commit of v2-protocol PR 124, currently titled `feat(v2.5): add singleton lender hook variants`. Record the commit in the series manifest; do not build against the PR branch name.

## Market acceptance checks

Before taking an approval or depositing one unit, `activate()` must verify:

- the market address equals the constructor-bound expected address;
- the settlement asset, borrower, notional cap, APR and reserve ratio match the manifest;
- the hook instance identifies as `SingletonFixedTermHooks` from the pinned implementation;
- provider configuration is sealed;
- there is exactly one pull provider, no existing or push provider, and its TTL is zero;
- the singleton provider and factory calculation bind the vault as lender;
- deposit and transfer dispatch are enabled;
- the raw queue-withdrawal access flag is false;
- `fixedTermEndTime` equals note maturity;
- `allowClosureBeforeTerm` and `allowTermReduction` are false;
- market-token transfers are disabled for this series; and
- the stored fixed-term policy prevents APR or reserve-ratio changes before maturity.

PR 124 requires the five-word fixed-term encoding, rejects both early-exit flags, checks the singleton factory runtime code, verifies the provider address and lender, and seals provider configuration during construction. The vault must still read the resulting market and refuse any mismatch.

## Activation transaction

1. Require a successful, finalised raise and the complete series notional.
2. Run every market acceptance check.
3. Record the initial Chainlink fixing through the task 4 adapter.
4. Approve exactly the notional to the market.
5. Deposit from the vault.
6. Clear any remaining allowance.
7. Store `Active` and emit the market, hook, provider, fixing and deposited amount.

The transaction is atomic. A failed deposit or final check must roll back the fixing and approval.

## Tests to add

- A passing deployment from the pinned factories.
- One failing test for every acceptance check.
- Unrelated deposits and market-token recipients.
- Provider creation, addition and removal after construction.
- Pre-maturity closure, term reduction and APR or reserve-ratio change.
- Approval reset and a token requiring zero allowance before a new approval.
- Repeated activation and partial-notional activation.

## Acceptance

- Only the vault can become a direct market lender.
- No investor asset moves before all checks pass.
- After activation, the borrower cannot change the term, close early or reprice the series before maturity.
- The activation event and manifest contain enough information to reproduce the deployment.

## Not in this task

Do not add maturity withdrawals, note redemption or default recovery.
