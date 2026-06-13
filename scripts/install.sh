#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"

if ! command -v luajit >/dev/null 2>&1; then
  echo "luajit не найден в PATH. Установи LuaJIT и повтори." >&2
  exit 1
fi
echo "[ok] luajit: $(command -v luajit)"

cd "$root"
git submodule update --init -- vendor/PathOfBuilding-PoE2
echo "[ok] PoB2 engine инициализирован"
