#!/usr/bin/env bash
# Гейт-проверка движка PoB2: гоняет расчётные spec'и форка в Linux-рантайме (WSL).
# Зелёный прогон = движок считает DPS и выживание для билдов PoE2.
# Запуск внутри WSL/Linux: bash scripts/spike-pob2.sh
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root/vendor/PathOfBuilding-PoE2"
busted --lua=luajit \
  ../spec/System/TestDefence_spec.lua \
  ../spec/System/TestAttacks_spec.lua \
  ../spec/System/TestSkills_spec.lua
