# Validation evidence

This file records what the repository test gate proves and what still needs a real series or another
reviewer. Refresh the figures and attach the raw command output after changes to contracts,
dependencies, deployment inputs or published technical claims.

## Pinned inputs

| Input | Pin |
| --- | --- |
| `v2-protocol` | `99bb85840a77a56fa5f64504a60ec126b6047cf5` |
| `forge-std` | `467ffd422ca01fed5797a4c766a1e4e3a5327902` |
| Chainlink contracts source | `f82d1ac09fc5d3190600d308be99a4a509854686` |
| `AggregatorV3Interface.sol` SHA-256 | `b173e1e92b4148d7f09464c09b52cd4aca1552a4689afd276d80b9b5e50c7945` |
| Foundry | `1.7.1` (`4072e48705af9d93e3c0f6e29e93b5e9a40caed8`) |
| Solidity | `0.8.28`, Cancun, optimiser 200 runs, via IR, no bytecode metadata hash |

`script/check-dependencies.sh` checks these values. `script/deploy-brc.sh` separately checks the BRC repository commit, the v2-protocol commit, Foundry settings and remappings before it will prepare a deployment.

## Repository gate

The release gate is strict by default. It requires the fork RPC, final manifest and deployment record:

```bash
MAINNET_RPC_URL="$MAINNET_RPC_URL" \
BRC_MANIFEST_PATH=config/series.json \
BRC_RECORD_PATH=deployments/series.json \
./script/release-gate.sh
```

The latest local CI-profile run on 16 August 2026 built the repository and passed 229 tests, with no
failures and one skipped opt-in mainnet-fork test. It ran 1,000 cases for each fuzz test and 256 runs
of each stateful invariant. The build printed an `unresolved symbol locals` diagnostic from the
pinned SphereX source but exited successfully; this run does not establish that the diagnostic is
harmless. No final manifest, deployment record, RPC-backed verifier run or strict release gate was
present. This is development evidence, not release approval.

The authored-Markdown check also passed on 16 August 2026. It checks non-vendored Markdown files for
an H1 heading, nonempty content and resolvable local Markdown links. It does not check factual
accuracy, external links, rendered diagrams or prose quality.

The explicit development-only form is:

```bash
BRC_ALLOW_INCOMPLETE_VALIDATION=1 \
./script/release-gate.sh
```

Never paste the RPC URL into an evidence file. Keep the command output, release commit and resulting manifest hash together in the restricted series folder.

## Coverage map

| Concern | Evidence |
| --- | --- |
| Payoff rounding and monotonicity | `test/BRCMath.t.sol` uses an independent full-width reference calculation and fuzzed redemption bounds. |
| Initial and maturity fixing | `test/BtcUsdFixingOracle.t.sol` and `test/BtcUsdMaturityFixing.t.sol` cover stale, future, missing, oversized, phase-transition and predecessor evidence. |
| Fallback authority | `test/BtcUsdFallback.t.sol` covers waiting and challenge times, quorum, veto, replacement, replay domains and primary cancellation. |
| Funding and activation | `test/BRCNoteVault.t.sol` and `test/BRCActivation.t.sol` cover token behaviour, cancellation, exact funding, immutable market policy and singleton-lender checks. |
| Normal settlement | `test/BRCSettlement.t.sol` covers queueing before `ST`, full performance, barrier equality, interest, borrower rebate and redemption order. |
| Default | `test/BRCRecovery.t.sol` covers partial payment, write-off timing, paid batches, sanctions batches, zero rebate and late Wildcat payments. |
| Deployment | `test/BRCDeployment.t.sol` covers canonical encoding, every manifest and record field, deterministic addresses, counterfeit initcode, salt ownership, stale nonce/governance state and post-deadline verification. |
| Mixed actions | `test/BRCSystemInvariant.t.sol` mixes funding, cancellation, activation, borrowing, repayment, queueing, primary and fallback oracle actions, recovery, transfers and redemptions over 128-call sequences. It checks funding conservation, lifecycle transitions, rebate gating, reserves and terminal claims. Deterministic mixed sequences prove primary settlement, fallback settlement and recovery can each reach terminal redemption. |
| Differential payoff | `BRCSystemPayoffDifferentialTest` checks the contract result against independent exact-rational quotient bounds over fuzzed full-width inputs. |
| Bounded gas cases | `.gas-snapshot` pins cold-state `recordMaturityFixing` with the maximum accepted 32-round proof walk at 526,475 gas and cold-state `finalizeRecovery` while it executes eight paid adopted batches and checks the unpaid live batch at 628,307 gas in the local test environment. The tests enforce respective ceilings of 650,000 and 1,500,000 gas; setup and assertions are outside the metered sections. |

## Fork evidence

The opt-in `BRCDeploymentMainnetForkTest` passed separately on 15 August 2026 against the live Ethereum BTC/USD proxy. It checks live feed metadata and the pinned factory/template artefacts deployed on the fork.

This is not a production deployment-verifier record. PR 124's singleton fixed-term stack does not yet have approved production addresses recorded in this repository, and no final borrower, USDC notional, maturity, ratifier set or manifest has been signed. A release needs the filled manifest, the resulting deployment record and successful `VerifyBRC` output from the chosen fork block.

## Findings and rehearsals

The implementation PRs used repeated internal adversarial review passes. Their fixed issues and commits are listed in `docs/review-packet.md`. These passes are development evidence, not an external audit.

The following remain release blockers until evidence is attached:

- independent external contract review and disposition of every finding;
- legal sign-off on distribution, oracle licensing, sanctions and the cash-settled option;
- a final manifest and deployment record for the chosen chain and borrower;
- a mainnet-fork deployment and verifier run at the release commit;
- maturity, partial-recovery and fallback rehearsals led by somebody who did not write the contracts; and
- funded monitoring and keeper accounts with no settlement-asset custody authority.
