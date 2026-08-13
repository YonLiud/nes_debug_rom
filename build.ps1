$ErrorActionPreference = 'Stop'

$localBin = Join-Path $PSScriptRoot 'tools\cc65\bin'
$ca65 = Join-Path $localBin 'ca65.exe'
$ld65 = Join-Path $localBin 'ld65.exe'
if (-not (Test-Path $ca65) -or -not (Test-Path $ld65)) {
    $ca65Command = Get-Command ca65 -ErrorAction SilentlyContinue
    $ld65Command = Get-Command ld65 -ErrorAction SilentlyContinue
    if (-not $ca65Command -or -not $ld65Command) {
        throw 'Missing cc65. Extract its Windows ZIP to tools\cc65, or put ca65.exe and ld65.exe on PATH.'
    }
    $ca65 = $ca65Command.Source
    $ld65 = $ld65Command.Source
}

New-Item -ItemType Directory -Force -Path '.\build' | Out-Null
& $ca65 .\debug.asm -g -o .\build\debug.o
& $ld65 -C .\nes.cfg .\build\debug.o -o .\build\debug.nes -m .\build\debug.map

$rom = Get-Item .\build\debug.nes
if ($rom.Length -ne 24592) {
    throw "Unexpected ROM size: $($rom.Length) bytes (expected 24592)."
}

$bytes = [System.IO.File]::ReadAllBytes($rom.FullName)
if ($bytes[0] -ne 0x4E -or $bytes[1] -ne 0x45 -or $bytes[2] -ne 0x53 -or $bytes[3] -ne 0x1A) {
    throw 'Invalid iNES header.'
}
if ($bytes[4] -ne 1 -or $bytes[5] -ne 1) {
    throw 'Unexpected PRG/CHR bank count.'
}

Write-Host "Built $($rom.FullName) ($($rom.Length) bytes)"
