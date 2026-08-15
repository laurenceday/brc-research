#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 2 ]]; then
  echo "usage: $0 MANIFEST RECORD [forge script options...]" >&2
  exit 64
fi

manifest_path=$1
record_path=$2
shift 2

for option in "$@"; do
  case "$option" in
    --root|--root=*|-C|-C*|--contracts|--contracts=*|-R|-R*|--remappings|--remappings=*|--remappings-env|--remappings-env=*|--lib-paths|--lib-paths=*|--hardhat|--hh|--config-path|--config-path=*|--use|--use=*|--no-auto-detect|--via-ir|--no-metadata|--evm-version|--evm-version=*|--optimize|--optimize=*|--optimizer-runs|--optimizer-runs=*|--revert-strings|--revert-strings=*|--libraries|--libraries=*|--dynamic-test-linking|--skip|--skip=*|-o|--out|--out=*|--cache-path|--cache-path=*|--use-literal-content|--private-key|--private-key=*|--private-keys|--private-keys=*|--mnemonics|--mnemonics=*|--mnemonic-passphrases|--mnemonic-passphrases=*)
      echo "unsupported deployment option: $option" >&2
      exit 64
      ;;
  esac
done

for command_name in git jq forge; do
  if ! command -v "$command_name" >/dev/null 2>&1; then
    echo "missing required command: $command_name" >&2
    exit 69
  fi
done

if [[ ! -f "$manifest_path" ]]; then
  echo "manifest not found: $manifest_path" >&2
  exit 66
fi

repo_root=$(git rev-parse --show-toplevel)
cd "$repo_root"

manifest_brc_commit=$(jq -er '.build.brcResearchCommit' "$manifest_path")
manifest_v2_commit=$(jq -er '.build.v2ProtocolCommit' "$manifest_path")
actual_brc_commit=$(git rev-parse HEAD)
actual_v2_commit=$(git -C lib/v2-protocol rev-parse HEAD)

check_equal() {
  local field=$1
  local expected=$2
  local actual=$3
  if [[ "$expected" != "$actual" ]]; then
    echo "preflight mismatch: $field (manifest=$expected actual=$actual)" >&2
    exit 65
  fi
}

check_equal build.brcResearchCommit "$manifest_brc_commit" "$actual_brc_commit"
check_equal build.v2ProtocolCommit "$manifest_v2_commit" "$actual_v2_commit"

if [[ -n "$(git status --porcelain --untracked-files=no)" ]]; then
  echo "preflight mismatch: brc-research checkout has tracked changes" >&2
  exit 65
fi
if [[ -n "$(git -C lib/v2-protocol status --porcelain)" ]]; then
  echo "preflight mismatch: v2-protocol checkout is dirty" >&2
  exit 65
fi

foundry_config=$(forge config --json)
check_equal build.sourceDirectory "src" "$(jq -er '.src' <<<"$foundry_config")"
check_equal build.scriptDirectory "script" "$(jq -er '.script' <<<"$foundry_config")"
check_equal build.libraryDirectories '["lib"]' "$(jq -cer '.libs' <<<"$foundry_config")"
check_equal build.remappings "$(<remappings.txt)" "$(forge remappings)"
check_equal build.compilerVersion \
  "$(jq -er '.build.compilerVersion' "$manifest_path")" \
  "$(jq -er '.solc' <<<"$foundry_config")"
check_equal build.evmVersion \
  "$(jq -er '.build.evmVersion' "$manifest_path")" \
  "$(jq -er '.evm_version' <<<"$foundry_config")"
check_equal build.optimizer \
  "$(jq -er '.build.optimizer|tostring' "$manifest_path")" \
  "$(jq -er '.optimizer|tostring' <<<"$foundry_config")"
check_equal build.optimizerRuns \
  "$(jq -er '.build.optimizerRuns|tostring' "$manifest_path")" \
  "$(jq -er '.optimizer_runs|tostring' <<<"$foundry_config")"
check_equal build.viaIR \
  "$(jq -er '.build.viaIR|tostring' "$manifest_path")" \
  "$(jq -er '.via_ir|tostring' <<<"$foundry_config")"
check_equal build.bytecodeHash \
  "$(jq -er '.build.bytecodeHash' "$manifest_path")" \
  "$(jq -er '.bytecode_hash' <<<"$foundry_config")"

echo "build preflight: ok"
echo "brc-research revision: $actual_brc_commit"
echo "v2-protocol revision: $actual_v2_commit"
echo "compiler: $(jq -er '.solc' <<<"$foundry_config")"

forge script script/DeployBRC.s.sol:DeployBRC \
  --sig "run(string,string)" \
  "$manifest_path" \
  "$record_path" \
  "$@"
