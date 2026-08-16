# Delivery runbook: current code, researched product, usable BD package

The five pull requests form one stack from `main` at
`9b97787927ee2f9fab2907a9d3762862133fd5cd`. Each step keeps the Solidity behaviour unchanged.
The contracts remain a research prototype throughout this run.

## Step 1: reconcile the implementation and documentation baseline

**Goal.** Make the repository describe the code that is already present and preserve the Fiat study
and delivery plan as reviewable repository documents.

**Entry.** `main` at `9b97787927ee2f9fab2907a9d3762862133fd5cd`, with the submodules hydrated at
the commits in `config/dependencies.env`.

**Exit.** The README opens with current status and navigation; every existing technical,
operational and task document agrees with the implemented state machine and current PR stack;
`docs/research/project-study.md` and `docs/research/delivery-plan.md` contain the prose-reviewed
copies of this study and runbook. `FOUNDRY_PROFILE=ci forge test --summary`, link checking,
`git diff --check` and the Markdown lint all succeed or record an exact external precondition.

**Files.** `README.md`, all current `docs/*.md`, all `tasks/*.md`,
`docs/research/project-study.md`, `docs/research/delivery-plan.md`, and any small local link or
Markdown validation script needed to make the checks repeatable.

**Tests.** Refresh the current Foundry count from a clean recursive checkout. Add a repository-local
Markdown/link check if none exists. Verify the settlement text against
`BRCNoteVault.finalizeSettlement()`, the fixing text against `BtcUsdFixingOracle.sol`, and the
deployment text against `BRCBorrowerAccount.deploySeries()` and `BRCDeploymentVerifier.verify()`.

## Step 2: add the instrument history and practical primer

**Goal.** Give a professional reader a sourced account of reverse convertibles and a worked guide to
the exact example implemented here.

**Entry.** The step-1 branch and its reconciled documentation baseline.

**Exit.** `docs/research/instrument-history.md` covers the evidenced history, GOAL attribution
conflict, Swiss tax framework and international analogues without turning tax history into product
advice. `docs/primer.md` explains the parties, short-put economics, barrier cliff, Wildcat credit
risk, worked cash flows, lifecycle, vocabulary and principal failure cases. All formulas match
`BRCMath.sol` on exact-boundary examples, and cited links resolve.

**Files.** `docs/research/instrument-history.md`, `docs/primer.md`, `README.md`, and the source index
introduced by the step if one is useful.

**Tests.** Add deterministic example vectors covering no breach, exact-barrier breach, deep breach,
zero price, complete borrower performance and recovery. Compare every published number with the
existing `BRCMathTest` vectors or a small checked calculation. Run Foundry, Markdown/link and prose
checks.

## Step 3: map reference assets and onchain oracle routes

**Goal.** Separate what the BTC/USD adapter supports now from the asset and data-source choices that
would require a new adapter, source contract, commercial agreement or market convention.

**Entry.** The step-2 branch and its primer vocabulary.

**Exit.** `docs/research/oracle-landscape.md` contains an as-of date, research method, Chainlink
product and feed catalogue, alternative-provider comparison, asset-class matrix, market-hours and
corporate-action analysis, index/data-rights warnings, source-selection scorecard and questions for
providers. Each row is labelled implemented, address-verified candidate, catalogue candidate or
inquiry only. The example BTC/USD address remains the only implemented primary source.

**Files.** `docs/research/oracle-landscape.md`, the research source index, `README.md`, and any
checked machine-readable feed snapshot that can be reproduced without credentials.

**Tests.** Recheck all time-sensitive source claims against primary vendor documentation on the day
of the PR. Confirm that no unimplemented source is described as manifest-configurable. Run Foundry,
Markdown/link and prose checks.

## Step 4: build the lender, borrower and discovery package

**Goal.** Equip BD to explain the product to either side, ask for the information needed to design a
series, and leave a balanced written record after the call.

**Entry.** The step-3 branch, including the primer and source-labelled oracle catalogue.

**Exit.** The lender brief explains yield, issuer credit, short-put exposure, liquidity, oracle and
recovery risk. The borrower brief explains funding, crash-contingent liability relief, full-payment
obligation, hedge/accounting questions and default consequences. The discovery guide covers term,
barrier, reference asset, observation, settlement, transfer, jurisdiction, hedging, reporting and
fallback choices. An FAQ handles likely objections. The infographic page contains reusable Mermaid
or source-controlled vector diagrams for money flow, payoff, lifecycle, normal versus recovery
waterfalls, oracle selection and the lender/borrower risk exchange.

**Files.** `docs/bd/lender-brief.md`, `docs/bd/borrower-brief.md`,
`docs/bd/discovery-guide.md`, `docs/bd/faq.md`, `docs/bd/one-page.md`,
`docs/bd/infographics.md`, and `README.md`.

**Tests.** Check every commercial claim against the primer or a named source, render or parse every
diagram, verify all links, and run the Foundry and prose checks. A cold reader should be able to
state both sides' maximum principal outcome and the conditions for a borrower rebate without using
another document.

## Step 5: cold-read every Markdown file and run the reader paths

**Goal.** Rewrite the entire authored Markdown set in one consistent Fiat register and prove the
technical, lender and borrower reading paths work from a clean checkout.

**Entry.** The step-4 branch with all requested content present.

**Exit.** Every tracked, non-vendored `*.md` file has been read in full, corrected, passed through
the Imprimatur lint and Vulgate voice mask, and checked for current links, terminology, status,
dates and cross-document contradictions. The README exposes three tested routes: technical review,
lender discussion and borrower discussion. `docs/validation-evidence.md` records the frozen commit,
current Foundry result, Markdown/link result, diagram result and the evidence still absent. The
demonstration is a clean-clone rehearsal of all three routes plus
`./script/release-gate.sh <manifest> <record>` where real series inputs exist; without a signed
series, the no-RPC repository gate runs and the missing fork/deployment evidence remains an explicit
release blocker.

**Files.** Every authored Markdown file returned by
`git ls-files '*.md' ':!:lib/**'`, plus the smallest validation script or CI adjustment needed for
repeatable checks.

**Tests.** Run the CI Foundry profile, repository dependency check, Markdown/link checker,
Imprimatur over the complete authored set, diagram validation, `git diff --check`, and a manual
cold-read checklist. Record exact counts and skipped external exercises; do not carry forward old
evidence as if it ran against the final tree.
