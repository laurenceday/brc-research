# Task 11: produce the security and operational package

Status: implemented and merged as an audit-readiness package. This step did not turn the prototype into an audited or production-approved product.

## Verification shipped

`test/BRCSystemInvariant.t.sol` adds handlers that mix subscriptions, cancellation, activation, market activity, withdrawal queueing, primary and fallback oracle actions, recovery, note transfers and redemptions. The properties check:

- funding assets and claims reconcile;
- assets leave through a valid refund, redemption or full-performance borrower rebate;
- no borrower rebate is available before complete Wildcat performance;
- `S0`, `ST`, activation and settlement do not move backwards or repeat;
- noteholder claims stay within the reserved assets;
- the vault remains the singleton lender and provider configuration stays sealed;
- ownership and redemption order do not enlarge aggregate claims; and
- terminal settlement reconciles the rebate, reserve, redemptions and dust.

Deterministic mixed sequences reach terminal normal settlement with a primary fixing, normal settlement with a fallback fixing, and recovery. A separate differential test compares the payoff with exact rational bounds.

Cold-state gas tests cover the maximum accepted 32-round maturity proof and recovery finalisation with eight adopted batches. `.gas-snapshot` records the expected bounds used by CI.

## Review and operations material shipped

The step added:

- `docs/review-packet.md`, with scope, dependencies, state diagram, authority map, accounting rules, limitations, legal questions and internal findings;
- `docs/validation-evidence.md`, with the pinned inputs, recorded test evidence and outstanding work;
- `docs/operations-checklists.md`, with named roles, evidence outputs, time budgets and escalation routes; and
- `script/release-gate.sh`, which requires dependency checks, formatting, build, CI-profile tests, gas snapshots, a mainnet fork and a series verifier unless development-only incomplete validation is explicitly allowed.

## Recorded evidence

The last evidence recorded in the repository on 15 August 2026 reports 229 passing test executions, no failures and one skipped test under the CI profile. That count includes inherited test contracts and is not a count of unique scenarios. Each fuzz test ran 1,000 cases and each stateful invariant ran 256 runs at depth 128.

The same record says the strict release gate did not pass: the development run omitted the RPC-backed mainnet fork and final series verifier. A separate live-feed fork exercise passed, but it did not use approved production Wildcat addresses or produce a signed deployment record.

## Work still open

The following items were specified for release but were not completed by task 11:

- an external security audit and disposition of every finding;
- written legal advice and reconciliation with the terms and manifest;
- replay of historical Chainlink data across real phase changes and unavailable rounds;
- a mainnet-fork deployment and verifier transcript using approved live dependencies;
- an explanation or removal of the pinned SphereX compiler diagnostic;
- maturity, fallback, sanctions and recovery rehearsals led by an independent operator; and
- funded keeper, monitoring and incident-response assignments.

Until those items are closed, the repository is a tested research target and audit package. It is not release approval, an offer document or evidence that the contracts are safe for production capital.
