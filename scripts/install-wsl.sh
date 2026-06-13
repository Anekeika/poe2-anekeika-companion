#!/usr/bin/env bash
# Ставит Linux-рантайм расчётного движка PoB2 в WSL/Ubuntu.
# Запуск как root (в WSL без пароля): wsl -u root bash scripts/install-wsl.sh
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

echo "[1/3] apt: luajit + luarocks + toolchain"
apt-get update -qq
apt-get install -y -qq luajit libluajit-5.1-dev lua5.1 liblua5.1-0-dev luarocks build-essential unzip

echo "[2/3] luarocks: luautf8 (нативный модуль движка) под lua 5.1 / luajit ABI"
luarocks --lua-version=5.1 install luautf8 0.1.6-1

echo "[3/3] sanity: luajit грузит lua-utf8"
luajit -e "require('lua-utf8'); print('lua-utf8 OK')"
echo "[done] WSL-рантайм движка готов"
