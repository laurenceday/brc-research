#!/usr/bin/env bash
set -euo pipefail

brc_notional=1000000
brc_strike=100000
brc_barrier=60000
brc_proceeds=1030000

check_case() {
  local maturity_price="$1"
  local expected_slash="$2"
  local expected_pool="$3"
  local actual_slash

  if ((maturity_price > brc_barrier || maturity_price >= brc_strike)); then
    actual_slash=0
  else
    actual_slash=$((brc_notional * (brc_strike - maturity_price) / brc_strike))
  fi

  local actual_pool=$((brc_proceeds - actual_slash))
  if ((actual_slash != expected_slash || actual_pool != expected_pool)); then
    echo "primer vector failed for ST=$maturity_price: slash=$actual_slash pool=$actual_pool" >&2
    exit 1
  fi
}

check_case 120000 0 1030000
check_case 60001 0 1030000
check_case 60000 400000 630000
check_case 40000 600000 430000
check_case 0 1000000 30000

brc_rounding_slash=$((1000001 * (3 - 2) / 3))
if ((brc_rounding_slash != 333333)); then
  echo "primer rounding vector failed: slash=$brc_rounding_slash" >&2
  exit 1
fi

echo "checked 6 primer payoff vectors"
