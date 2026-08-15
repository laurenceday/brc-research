# Fiat audit log

## Step 1, round 1 -- 16 August 2026

This round reviewed the documentation and CI diff in commit
`01b2f239e40cee697d1583360b29e2a052a4fac3`. It did not rerun the Solidity security suite because
the step changed no Solidity. The review compared published lifecycle, settlement, oracle, funding
and hook-policy claims with the current contracts and tests, then exercised the new Markdown gate.

| id | severity | file | finding | status |
| --- | --- | --- | --- | --- |
| S1-R1-01 | low | `docs/runbook.md`, `docs/architecture.md`, `docs/research/project-study.md` | Several recovery references still called `recoveryDelay` a grace period. That could be confused with Wildcat's separate `delinquencyGracePeriod` during series preparation or default operations. | fixed on the step audit branch |

Leads not pursued: the Markdown checker deliberately does not validate external links, anchors,
Mermaid rendering or factual accuracy. Those checks remain part of the final reader-path and prose
step rather than being represented as CI guarantees.

## Step 1, round 2 -- 16 August 2026

This round reviewed the fixed tree at
`301656b7f7516e20f1d6a4400a9f3e35e8e2986a`. It repeated the lifecycle terminology search, checked
the implementation-status pages against the contract-backed baseline, ran the authored-Markdown
gate and ran Imprimatur across all 23 authored Markdown files.

| id | severity | file | finding | status |
| --- | --- | --- | --- | --- |
| -- | -- | -- | No finding. | clean |

Leads not pursued: external-link and rendered-diagram checks remain assigned to step 5. No Solidity
changed in this step, so Solidity audit and fuzz-suite generation were not applicable to this diff.

## Step 2, round 1 -- 16 August 2026

This round reviewed commit `7b8931ddf3e611f00b4f2cde57408576bf9e1201`. It checked the six
published payoff vectors against `BRCMath.sol`, compared the lifecycle and recovery examples with
`BRCNoteVault.sol`, opened the cited sources, and reviewed every return, tax and product-origin
statement for scope.

| id | severity | file | finding | status |
| --- | --- | --- | --- | --- |
| S2-R1-01 | low | `README.md` | The payoff summary called the Wildcat lender yield fixed. `SingletonFixedTermHooks` freezes APR and reserve ratio only until maturity, while actual payment remains subject to borrower performance and settlement. | fixed on the step audit branch |

Leads not pursued: automated requests to the cited SEC pages receive `403` responses, but the pages
were opened and read through the browser. The research source index records that access limitation.
The step changed no Solidity, so a new Solidity audit or fuzz harness was not applicable.

## Step 2, round 2 -- 16 August 2026

This round reviewed the fixed tree at
`3279ba78d720a9ea9d422e32dfe0a45e8640e61a`. It repeated the historical-attribution, tax-language
and return-claim searches, ran all six published vectors, and reran the 229-test CI profile and
authored-Markdown check.

| id | severity | file | finding | status |
| --- | --- | --- | --- | --- |
| -- | -- | -- | No finding. | clean |

Leads not pursued: the documents do not price the option or make suitability, tax or legal claims.
Those decisions require a real counterparty, jurisdiction, series and professional advice.

## Step 3, round 1 -- 16 August 2026

This round reviewed commit `63fec9b2209cb1eb2caa17233e32728d40bd1a73`. It compared every
compatibility label with the current oracle interface, checked the BTC/USD round rules against
`BtcUsdFixingOracle.sol`, and opened the cited first-party provider and index-rights pages.

| id | severity | file | finding | status |
| --- | --- | --- | --- | --- |
| S3-R1-01 | low | `docs/research/reference-assets-and-oracles.md`, `docs/research/sources.md` | The dated QQQ/SPY and RedStone Live catalogue claims did not have an adjacent first-party source. A reader could not distinguish verified catalogue evidence from a broad provider summary. | fixed on the step audit branch |

Leads not pursued: no provider contract, private catalogue or commercial entitlement was
available. Candidate labels therefore remain discovery evidence rather than security or
availability findings. The step changed no Solidity, so a Solidity audit and new fuzz harness were
not applicable.
