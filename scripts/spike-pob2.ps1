#Requires -Version 7
$ErrorActionPreference = 'Stop'
# Движок PoB2 живёт в Linux-рантайме (WSL). Эта обёртка вызывает gate-проверку там.
$sh = Join-Path $PSScriptRoot 'spike-pob2.sh'
$shWsl = (& wsl wslpath -a "$sh").Trim()
& wsl -e bash $shWsl
