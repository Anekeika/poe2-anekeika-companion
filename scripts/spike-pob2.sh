#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
src="$root/vendor/PathOfBuilding-PoE2/src"
( cd "$src" && luajit "$root/pob/headless/run_stats.lua" \
    "$root/pob/fixtures/sample.items.json" \
    "$root/pob/fixtures/sample.passives.json" )
