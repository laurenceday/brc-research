# Task 02: establish the Foundry project

## Aim

Create the smallest reproducible Solidity project on which the BRC contracts can be built. Pin every protocol dependency used to interpret a series, and make the repository fail when those pins drift.

## Work

- Add `foundry.toml`, remappings and the standard `src`, `test` and `script` layout.
- Pin the v2-protocol revision that contains the reviewed singleton fixed-term hook implementation.
- Pin the Chainlink contracts revision used for `AggregatorV3Interface` and proxy-round helpers.
- Add local interfaces only where importing the upstream package would pull in unrelated code. Record the upstream file and commit beside every local copy.
- Add mock ERC-20, Wildcat market and Chainlink proxy/aggregator fixtures for later tasks.
- Add commands for formatting, compilation, unit tests and dependency-pin verification.
- Run those commands in CI on every pull request.

## Repository rules

- Production contracts may import only pinned dependencies or local interfaces tied to a recorded upstream revision.
- Test mocks must not be reachable from production source paths.
- The build must not fetch a moving branch or tag.
- Compiler version, optimiser settings and EVM target must be explicit.

## Acceptance

- A clean checkout can run `forge build` and `forge test` without manual edits.
- A script prints and checks the v2-protocol and Chainlink commit identifiers.
- CI runs formatting, build, tests and the pin check.
- The initial suite proves that each mock can express the success and failure cases needed by later tasks.

## Tests to add

- ERC-20 decimal and transfer-failure fixtures.
- Chainlink negative answer, zero answer, stale round, future timestamp and phase-change fixtures.
- Wildcat deposit, queued withdrawal, partial repayment and closure fixtures.

## Not in this task

Do not add BRC payoff logic, oracle selection, note issuance or Wildcat activation. This branch supplies the workshop; later branches supply the product.
