Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$RepoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $RepoRoot

# Build for current arch using default compiler selection
$exe = & $RepoRoot\build.ps1

if (-not $exe -or -not (Test-Path $exe)) {
    throw "Test failed: built executable not found."
}
Write-Host "Test passed: Found $exe" -ForegroundColor Green
