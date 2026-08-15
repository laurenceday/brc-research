#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

./script/check-dependencies.sh
forge fmt --check
forge build
FOUNDRY_PROFILE=ci forge test
forge snapshot --check \
  --match-test 'testGasRecordsMaturityAfterMaximumProofWalk|testGasFinalizesRecoveryWithMaximumAdoptedBatches'

allow_incomplete=${BRC_ALLOW_INCOMPLETE_VALIDATION:-0}

if [[ -n "${MAINNET_RPC_URL:-}" ]]; then
  MAINNET_RPC_URL="$MAINNET_RPC_URL" \
    forge test --match-contract BRCDeploymentMainnetForkTest
  echo "mainnet fork: passed"
elif [[ "$allow_incomplete" == "1" ]]; then
  echo "mainnet fork: not run (set MAINNET_RPC_URL)"
else
  echo "mainnet fork: MAINNET_RPC_URL is required" >&2
  exit 1
fi

manifest_path=${BRC_MANIFEST_PATH:-}
record_path=${BRC_RECORD_PATH:-}
if [[ -n "$manifest_path" || -n "$record_path" ]]; then
  if [[ -z "$manifest_path" || -z "$record_path" || -z "${MAINNET_RPC_URL:-}" ]]; then
    echo "series verifier: BRC_MANIFEST_PATH, BRC_RECORD_PATH and MAINNET_RPC_URL are all required" >&2
    exit 1
  fi
  forge script script/VerifyBRC.s.sol:VerifyBRC \
    --rpc-url "$MAINNET_RPC_URL" \
    --sig "run(string,string)" \
    "$manifest_path" \
    "$record_path"
  echo "series verifier: passed"
elif [[ "$allow_incomplete" == "1" ]]; then
  echo "series verifier: not run (set BRC_MANIFEST_PATH and BRC_RECORD_PATH)"
else
  echo "series verifier: BRC_MANIFEST_PATH and BRC_RECORD_PATH are required" >&2
  exit 1
fi
