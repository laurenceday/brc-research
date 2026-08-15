# Task 11: produce the security and operational package

## Aim

Test the complete series as one system, state the remaining assumptions, and give operators a rehearsal-backed procedure for deployment, maturity and failure handling.

## Stateful properties

Add a handler that explores subscriptions, cancellation, activation, market payments, queueing, oracle submissions, recovery, note transfers, redemptions and fallback proposals in adversarial order. Check throughout that:

- assets leave only through subscription refunds, note redemption or a valid full-performance borrower rebate;
- no borrower rebate is available before complete Wildcat performance;
- `S0`, `ST`, activation and settlement are each written at most once;
- noteholder claims do not exceed assets reserved for them;
- the vault is the only direct market lender and provider configuration remains sealed;
- caller timing cannot improve the accepted maturity price;
- changing note ownership or redemption order cannot increase total claims; and
- terminal accounting reconciles subscriptions, Wildcat proceeds, borrower rebate, note redemptions and stated dust.

## Test programme

- Unit and fuzz suites from every preceding task.
- Differential payoff tests against an independent high-precision model.
- Stateful tests with long mixed action sequences.
- Mainnet-fork tests against the pinned Wildcat factories, hook template, settlement asset and Chainlink proxy.
- Historical Chainlink fixtures spanning proxy phases, stale periods and missing rounds.
- Wildcat delinquency, partial repayment, late closure, withdrawal expiry and sanctions cases.
- Oracle shutdown, fallback challenge and ratifier-compromise exercises.
- Gas measurements for permissionless maturity and recovery calls, including worst expected evidence sizes.

## Review packet

Prepare:

- contract scope and pinned commit list;
- series state diagram and authority table;
- asset-flow accounting specification;
- known limitations and rejected alternatives;
- upstream dependency and upgrade assumptions;
- legal questions covering note distribution, oracle licensing, sanctions and cash-settled option treatment;
- deployment verifier output from a mainnet fork; and
- an external-audit issue list with each finding tied to a commit.

## Operations

Turn `docs/runbook.md` into executable checklists for:

- pre-deployment review and borrower sign-off;
- deployment and independent verification;
- funding finalisation and activation;
- feed, market and sanctions monitoring during the term;
- maturity-round proof, Wildcat closure and redemption opening;
- delinquency and partial recovery;
- oracle fallback proposal, challenge and ratification; and
- incident communication and contract-specific evidence retention.

Assign an owner, expected time and escalation route to every manual step. Rehearse the maturity and recovery checklists on a fork with someone who did not write the contracts.

## Release gate

- All test suites and the deployment verifier pass at the release commit.
- The runbook rehearsal produces no unresolved execution gap.
- Contract assumptions match the legal term sheet and series manifest.
- External review findings are fixed, accepted with written reasoning or marked as deployment blockers.
- Monitoring and keeper accounts are funded and tested without holding settlement authority.

This task may establish audit readiness. It must not describe unaudited contracts as audited or a research series as suitable for public distribution.
