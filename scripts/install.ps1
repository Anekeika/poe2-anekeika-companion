#Requires -Version 7
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot

# 1. luajit
$luajit = Get-Command luajit -ErrorAction SilentlyContinue
if (-not $luajit) {
  Write-Error "luajit не найден в PATH. Установи LuaJIT и повтори."
}
Write-Host "[ok] luajit: $($luajit.Source)" -ForegroundColor Green

# 2. сабмодуль движка
Push-Location $root
try {
  git submodule update --init -- vendor/PathOfBuilding-PoE2
  Write-Host "[ok] PoB2 engine инициализирован" -ForegroundColor Green
} finally { Pop-Location }
