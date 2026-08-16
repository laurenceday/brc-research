# Task 05: pick the maturity price without picking the price

Status: implemented and merged. This step made `ST` the first valid Chainlink BTC/USD observation at or after maturity, rather than a round chosen by the settlement caller.

## What shipped

A caller supplies a candidate proxy round and a pre-maturity predecessor. The oracle accepts the candidate only when:

- its answer and timestamp satisfy the task-04 checks;
- `updatedAt >= maturity`;
- `updatedAt <= maturity + maxObservationDelay`; and
- the predecessor and intervening round history prove that no earlier eligible post-maturity round exists.

The stored record includes the answer, proxy round ID, underlying aggregator, local aggregator round ID and update time. It can be written once.

The proof understands Chainlink proxy phases. Within one phase it checks every local ID between the predecessor and candidate. Across a phase change it proves that the predecessor is the old aggregator's tail, resolves the next phase from the proxy and starts at local round one. The candidate aggregator must match the expected decimals and description.

The walk may inspect at most 32 intervening IDs. An unreadable ID fails closed because a revert cannot distinguish an unpublished round from unavailable historical data.

Anybody may submit the proof and pay the gas. Waiting for a later favourable answer does not help: an earlier eligible round causes the transaction to revert.

## Evidence

`test/BtcUsdMaturityFixing.t.sol` covers ordinary rounds, an update exactly at maturity, later candidates, oversized and unreadable rounds, phase transitions, changed metadata, false predecessors, observation-window and future-skew boundaries, repeated submission and the maximum accepted walk. The maximum-walk gas test is also pinned in `.gas-snapshot`.

## Boundary of this step

Task 05 added no committee override. A sparse, retired or unreadable history can leave the primary route stuck. Task 09 added a delayed and contestable fallback without weakening the ordinary proof.

Next implementation record: [Task 06, note funding](06-note-funding.md).
