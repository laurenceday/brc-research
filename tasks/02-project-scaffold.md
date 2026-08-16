# Task 02: establish the Foundry project

Status: implemented and merged. This page records the project and dependency baseline used by the rest of the prototype.

## What shipped

The repository gained an explicit Foundry layout, compiler profile, remappings and CI job. The build pins:

- `v2-protocol` at the commit recorded in `config/dependencies.env`;
- `forge-std` at its recorded commit;
- the source commit and SHA-256 for the vendored Chainlink `AggregatorV3Interface`; and
- Solidity `0.8.28`, Cancun, optimisation with 200 runs, via IR and no bytecode metadata hash.

Production imports resolve either to those pinned dependencies or to the local interfaces whose upstream source is recorded beside them. Test-only mocks stay under `test/mocks`.

The scaffold also added fixtures for:

- ERC-20 decimals, transfer failures, no-return calls, transfer fees and rebases;
- positive, negative, stale, future and incomplete Chainlink rounds, including proxy phase changes; and
- Wildcat deposits, withdrawals, repayment and closure.

`script/check-dependencies.sh` checks the dependency and interface pins. CI checks those pins, formatting, compilation, tests and the bounded gas snapshots.

## Evidence

`test/Scaffold.t.sol` proves that the basic token, market and feed fixtures can express both success and failure. The later suites use the same fixtures for funding, oracle, activation and settlement tests.

A fresh checkout must initialise submodules recursively before running Foundry. The pin check fails when a checked-out dependency no longer matches `config/dependencies.env`.

## Boundary of this step

Task 02 established the workshop. It did not add payoff logic, note issuance, oracle selection or Wildcat activation. Those arrived in tasks 03 through 07.

Next implementation record: [Task 03, payoff math](03-payoff-math.md).
