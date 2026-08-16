# Wildcat BRC prototype

![Abstract fixed-term credit note with one reference-price trigger](docs/bd/assets/one-loan-one-trigger.png)

**One borrower. One facility. One crash trigger.**

This repository implements a cash-settled barrier reverse convertible around a fixed-term Wildcat
market. The example links a USDC note to BTC/USD. The vault is the market's sole lender;
noteholders hold claims against the vault rather than Wildcat market tokens.

[Walk the $1m BTC example](docs/bd/worked-example.md) ·
[Open the BD field kit](docs/bd/README.md) ·
[Read the architecture](docs/architecture.md)

This is research code. It has no external audit, legal approval, live series or approved release
commit. Nothing here is an offer, price, tax view or suitability assessment.

## The product

| Seat | What it gets | What it gives up |
| --- | --- | --- |
| Investor | A fixed-term claim on a named borrower, plus the priced return for selling BTC downside. | Principal can be rebated to the borrower after full payment if BTC finishes at or below the barrier. |
| Borrower | Fixed-term funding and a defined crash-state cash rebate. | The facility must be paid in full before the BTC payoff can run. |
| Note issuer | One lender position, one note ledger and one maturity waterfall. | No discretion to move the trigger, change the payoff or rescue a missed term. |

![Three-path barrier illustration](docs/bd/assets/barrier-cliff.png)

The short version: this is borrower credit plus a sold BTC downside put. If BTC finishes above the
barrier and the borrower pays, investors receive the collected cash. If BTC finishes at or below
the barrier and the borrower has paid in full, part of face principal is rebated to the borrower.
If the borrower defaults, the BTC formula is off and investors receive the recovery pool.

## Behaviour that matters

- One lender position exists: the vault owns the whole fixed-term Wildcat claim.
- Investors receive note balances, not Wildcat market tokens.
- The implemented trigger is European: one BTC/USD observation at maturity.
- Equality breaches: `ST <= B` triggers the slash.
- The cliff is real: after breach, loss is measured from strike `K`, not from barrier `B`.
- The borrower receives a rebate only after complete facility performance.
- Recovery fixes the borrower rebate at zero.
- Settlement is cash in USDC. There is no BTC delivery and no BTC upside for investors.
- Data rights are a product term, not a dev toggle.

## Payoff

Let `N` be face notional, `K` the initial BTC/USD fixing, `B` the barrier and `ST` the maturity
fixing.

```text
principal slash = 0                                when ST > B
principal slash = floor(N * (K - ST) / K)         when ST <= B and ST < K
```

After complete Wildcat performance, the borrower may claim the slash and noteholders receive the
remaining authenticated proceeds, including collected Wildcat interest. In recovery, the borrower
receives no rebate and noteholders share the fixed recovery pool. Noteholders take borrower credit
risk and BTC downside risk without receiving BTC upside.

The [worked example](docs/bd/worked-example.md) walks through the happy, neutral and catastrophic
paths with the same numbers a BD or credit room can repeat.

## What ships here

| Area | Files |
| --- | --- |
| Note and payoff | `src/BRCNoteVault.sol`, `src/BRCMath.sol` |
| Deployment and identity | `src/BRCVaultFactory.sol`, `src/BRCBorrowerAccount.sol`, `src/BRCDeployment.sol` |
| BTC/USD fixing | `src/BtcUsdFixingOracle.sol` |
| Tests | `test/` unit, fuzz, deployment, recovery and invariant coverage |
| Operations | `script/`, `config/series.example.json`, `docs/runbook.md`, `docs/operations-checklists.md` |
| Product and BD | `docs/bd/`, `docs/product-terms.md`, `docs/primer.md`, `docs/research/` |

Generated build output, controller records and temporary renders do not belong in the authored
tree. Deployment records are series artefacts and remain untracked unless a release process says
otherwise.

## Run the prototype

The repository pins its dependencies in `config/dependencies.env`.

```bash
git submodule update --init --recursive
./script/check-dependencies.sh
FOUNDRY_PROFILE=ci forge test --summary
./script/check-markdown.sh
./script/check-primer-examples.sh
./script/check-mermaid.sh
```

The Foundry profile uses Solidity 0.8.28, the Cancun EVM, 200 optimiser runs and via IR. Production
contracts were last changed in `efb880e3d79ba12709d68c850b9321eeb19d7cfb`. That commit is a code
baseline, not a release approval. A real series must name one frozen, externally reviewed release
commit in its manifest.

The Wildcat integration is pinned to `wildcat-finance/v2-protocol` commit
`99bb85840a77a56fa5f64504a60ec126b6047cf5`, selected from
[`v2-protocol` PR 124](https://github.com/wildcat-finance/v2-protocol/pull/124). The commit is the
build input regardless of the pull request's later state.

## Current edge

The repository can deploy and exercise the BTC/USD research series in tests. A live series still
needs an external contract review, legal and regulatory advice, data and product-rights clearance,
a completed manifest, approved counterparties, a mainnet-fork verifier run and independent maturity,
fallback and recovery rehearsals.

The prototype has no continuous barrier, physical BTC delivery, generic oracle switch,
contract-wallet fallback ratifiers, wrapper, upgrade path, pause or administrator sweep. Wildcat
governance, SphereX, sanctions handling, borrower-identity changes, the settlement token and
Chainlink feed administration remain external assumptions. Payments or donations arriving after the
recovery snapshot do not enlarge noteholder claims and may remain trapped in the vault.

## Reading order

- Product or credit discussion: [BD field kit](docs/bd/README.md) →
  [one-page](docs/bd/one-page.md) → [worked example](docs/bd/worked-example.md).
- Lender discussion: [lender brief](docs/bd/lender-brief.md) →
  [FAQ](docs/bd/faq.md) → [review packet](docs/review-packet.md).
- Borrower discussion: [borrower brief](docs/bd/borrower-brief.md) →
  [product terms](docs/product-terms.md) → [discovery guide](docs/bd/discovery-guide.md).
- Technical review: [architecture](docs/architecture.md) →
  [threat model](docs/threat-model.md) → [validation evidence](docs/validation-evidence.md).
- Deployment: [deployment tooling](docs/deployment-tooling.md) →
  [runbook](docs/runbook.md) → [operator checklists](docs/operations-checklists.md).
- Reference research: [instrument history](docs/research/instrument-history.md) →
  [reference assets and oracles](docs/research/reference-assets-and-oracles.md) →
  [source index](docs/research/sources.md).
