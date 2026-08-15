# Task 02: establish the Foundry project

## Aim

Set up the smallest reproducible Solidity project we can sensibly build the BRC contracts on. Pin every protocol dependency used to interpret a series, and make the repo fail if one of those pins moves.

## Work

- Add `foundry.toml`, remappings and the standard `src`, `test` and `script` layout.
- Pin the v2-protocol revision that contains the reviewed singleton fixed-term hook implementation.
- Pin the Chainlink contracts revision used for `AggregatorV3Interface` and proxy-round helpers.
- Only add a local interface when importing the upstream package would drag in unrelated code. Put the upstream file and commit beside every local copy.
- Add mock ERC-20, Wildcat market and Chainlink proxy/aggregator fixtures for later tasks.
- Add commands for formatting, compilation, unit tests and checking the dependency pins.
- Run those commands in CI on every pull request.

## Repo rules

- Production contracts may only import pinned dependencies or local interfaces tied to a recorded upstream revision.
- Test mocks must not be reachable from production source paths.
- The build must not fetch a moving branch or tag.
- Compiler version, optimiser settings and EVM target must be explicit.

## Acceptance

- A clean checkout can run `forge build` and `forge test` without somebody fiddling with it first.
- A script prints and checks the v2-protocol and Chainlink commit identifiers.
- CI runs formatting, build, tests and the pin check.
- The first test suite shows that each mock can express the success and failure cases later tasks need.

## Tests to add

- ERC-20 decimal and transfer-failure fixtures.
- Chainlink negative answer, zero answer, stale round, future timestamp and phase-change fixtures.
- Wildcat deposit, queued withdrawal, partial repayment and closure fixtures.

## Not in this task

No BRC payoff logic, oracle selection, note issuance or Wildcat activation yet. This branch is just the workshop; later branches add the product.
