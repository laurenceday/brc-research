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
