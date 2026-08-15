# Task 01: fix the product specification

Status: implemented and merged. This page records the first step in the prototype stack. The current repository code and the pinned `v2-protocol` revision are the working baseline.

## What shipped

This step fixed the product before contract work began:

- a 90-day, USDC-denominated example note linked to BTC/USD;
- one vault as the sole lender in a fixed-term Wildcat market;
- one note base unit for each settlement-asset base unit subscribed;
- a European barrier observed once at maturity;
- `K = S0`, `B = 60% × S0` and a breach when `ST <= B`;
- integer rounding towards zero in the principal-slash calculation;
- a normal waterfall that pays the borrower rebate only after complete Wildcat performance;
- a recovery waterfall that reserves every recovered asset for noteholders;
- a fixed Chainlink proxy with a delayed ratifier fallback if the primary proof remains unavailable; and
- the legal, tax, distribution, sanctions and data-licensing questions that code cannot settle.

The specification also split responsibilities cleanly. Wildcat accounts for debt, interest, liquidity and delinquency. The BRC vault accounts for subscriptions, note ownership, the BTC-linked rebate and note redemption.

## Evidence

The implemented terms live in `docs/product-terms.md`. `docs/architecture.md`, `docs/runbook.md` and `docs/threat-model.md` carry the same observation rule, waterfall and trust assumptions into the technical and operational material.

Later contract tests fix the boundary cases first stated here: barrier equality, rounding, one-shot `S0` and `ST`, and the absence of a borrower rebate in recovery.

## Boundary of this step

Task 01 shipped documents only. It did not add Solidity or deployment tooling, and it made no production-readiness claim. The singleton fixed-term market design remained dependent on `wildcat-finance/v2-protocol#124`; the repository now pins the exact reviewed commit used by the prototype.
