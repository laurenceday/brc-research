# Task 01: fix the product specification

This PR pins down what we're building before the contracts make it annoying to change.

## Work

- Write the example commercial terms and exact integer formulae.
- Split Wildcat debt accounting from the vault's BTC option and note accounting.
- Fix the European observation rule and oracle-failure behaviour.
- Fix the normal and default waterfalls.
- Record the trust assumptions, sanctions behaviour and deployment sequence.
- Name the points that still require legal, tax, distribution or data-licensing advice.

## We're done when

- Barrier equality and rounding have one answer.
- `S0` and `ST` each have an onchain selection rule.
- The borrower rebate is unavailable during default recovery.
- Every later task can refer to these documents without inventing another product rule.

## Not in this PR

No Solidity, deployment scripts or production claim here. Upstream v2-protocol PR #124 is still a separate prerequisite.
