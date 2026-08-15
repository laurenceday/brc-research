#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$repo_root/config/dependencies.env"

check_git_pin() {
  local name="$1"
  local path="$2"
  local expected="$3"
  local actual
  actual="$(git -C "$repo_root/$path" rev-parse HEAD)"
  if [[ "$actual" != "$expected" ]]; then
    echo "$name: expected $expected, got $actual" >&2
    exit 1
  fi
  echo "$name: $actual"
}

check_git_pin "v2-protocol" "lib/v2-protocol" "$V2_PROTOCOL_COMMIT"
check_git_pin "forge-std" "lib/forge-std" "$FORGE_STD_COMMIT"

chainlink_interface="$repo_root/src/interfaces/AggregatorV3Interface.sol"
chainlink_hash="$(shasum -a 256 "$chainlink_interface" | awk '{print $1}')"
if [[ "$chainlink_hash" != "$CHAINLINK_AGGREGATOR_V3_SHA256" ]]; then
  echo "Chainlink interface: expected $CHAINLINK_AGGREGATOR_V3_SHA256, got $chainlink_hash" >&2
  exit 1
fi

echo "Chainlink contracts: $CHAINLINK_CONTRACTS_COMMIT"
echo "Chainlink AggregatorV3Interface.sol: $chainlink_hash"
