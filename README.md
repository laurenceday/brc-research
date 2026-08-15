# Wildcat BRC research prototype

This repository contains a cash-settled, BTC/USD-linked barrier reverse convertible built around a
fixed-term Wildcat market. It is research code, not an audited product, an offer, a tax analysis or
a production deployment.

The implemented example gives one vault the only direct lender position in the Wildcat market.
Investors hold notes issued by that vault. Wildcat accounts for ordinary settlement-asset debt and
interest; the vault accounts for subscriptions, the BTC-linked payoff, borrower rebate, recovery
and note redemption.

## What is implemented

- A full-raise note subscription and cancellation flow with optional transfer eligibility.
- A European barrier observed once at maturity. The strike is the initial BTC/USD fixing, and
  equality with the barrier counts as a breach.
- A Chainlink AggregatorV3 BTC/USD primary oracle with pinned metadata, proxy-phase handling and a
  deterministic first-valid-round rule.
- A delayed fallback fixing with immutable ECDSA ratifiers, threshold signatures, a challenge
  window and a one-ratifier veto.
- A sealed singleton-lender Wildcat market whose term, APR, reserve ratio and early-close policy
  are checked before the vault deposits.
- Normal settlement after complete Wildcat lender payment and collection. Formal market closure is
  not required.
- A recovery path for a completely queued claim that remains partly unpaid after the contractual
  recovery delay. Recovery proceeds belong only to noteholders.
- Deterministic deployment, manifest hashing, atomic borrower-account execution and read-only
  verification tooling.

The code does not support a continuous barrier, autocall, physical BTC delivery, generic oracle
selection, contract-wallet fallback ratifiers, an admin sweep, an upgrade path or a live series.
Alternative reference assets and oracle products are research subjects until a new adapter and
observation rule are implemented and reviewed.

## Read this first

Choose the route that matches the job:

| Reader | Start here | Then read |
| --- | --- | --- |
| Product or BD | [Primer](docs/primer.md) | [Instrument history](docs/research/instrument-history.md) and [product terms](docs/product-terms.md) |
| Engineer or reviewer | [Architecture](docs/architecture.md) | [Threat model](docs/threat-model.md), [review packet](docs/review-packet.md) and [validation evidence](docs/validation-evidence.md) |
| Deployment or operations | [Deployment tooling](docs/deployment-tooling.md) | [Runbook](docs/runbook.md) and [operator checklists](docs/operations-checklists.md) |
| Contributor | [Project study](docs/research/project-study.md) | [Delivery plan](docs/research/delivery-plan.md) and the [merged implementation records](tasks/01-product-spec.md) |

## Payoff in one minute

Let `N` be notional, `K` the initial BTC/USD fixing, `B` the barrier and `ST` the maturity fixing.

```text
principal slash = 0                                when ST > B
principal slash = floor(N * (K - ST) / K)         when ST <= B and ST < K
```

On complete Wildcat performance, the borrower may claim the slash and noteholders receive all
remaining collected principal plus accrued Wildcat interest. In recovery, the borrower receives
nothing and every settlement-asset unit collected before finalisation goes to noteholders. The
lender therefore takes borrower credit risk and BTC downside risk while receiving the fixed
Wildcat lender yield and no BTC upside.

## Build and test

The repository pins dependencies in `config/dependencies.env`. Initialise them recursively, then
check the pin set before running the CI profile:

```bash
git submodule update --init --recursive
./script/check-dependencies.sh
FOUNDRY_PROFILE=ci forge test --summary
./script/check-markdown.sh
```

The Foundry configuration uses Solidity 0.8.28, the Cancun EVM, optimizer runs of 200 and via IR.
The current integrated documentation and test baseline is
`9b97787927ee2f9fab2907a9d3762862133fd5cd`. The production-contract baseline in the review packet
is recorded separately because the final merged step added tests and operating material without
changing `src/`.

## Dependency state

The Wildcat integration is pinned to `wildcat-finance/v2-protocol` commit
`99bb85840a77a56fa5f64504a60ec126b6047cf5`, the head of
[`v2-protocol` PR 124](https://github.com/wildcat-finance/v2-protocol/pull/124) as checked on
16 August 2026. The commit is the build input; the pull request's later state is not.

The example manifest names the Ethereum mainnet Chainlink BTC/USD proxy published at
[`data.chain.link`](https://data.chain.link/feeds/ethereum/mainnet/btc-usd). A real series still
needs its live address, code hash, feed metadata, governance state and product terms checked and
signed in the completed manifest. The deployment and verifier scripts perform those checks against
the supplied values; the example file is deliberately incomplete.

## Repository map

- `src/` contains the vault, fixing oracle, payoff library, borrower account and deployment logic.
- `test/` contains unit, fuzz, deployment, recovery and stateful invariant coverage.
- `script/` contains the manifest parser, deployer, verifier and release checks.
- `config/series.example.json` is an incomplete example, not a deployable series.
- `docs/` contains current terms, architecture, operating controls and review evidence.
- `docs/primer.md` explains the trade and its worked lender and borrower outcomes.
- `docs/research/` contains the sourced instrument history, source index, project study and delivery
  plan.
- `tasks/` records what each of the eleven merged implementation PRs delivered.

The original eleven-PR stack is merged. The task pages remain as the build record; they are no
longer an instruction to review or merge branches from the bottom.
