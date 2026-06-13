#Requires -Version 7
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$src  = Join-Path $root 'vendor/PathOfBuilding-PoE2/src'
$harness  = Join-Path $root 'pob/headless/run_stats.lua'
$items    = Join-Path $root 'pob/fixtures/sample.items.json'
$passives = Join-Path $root 'pob/fixtures/sample.passives.json'

Push-Location $src
try {
  luajit $harness $items $passives
} finally { Pop-Location }
