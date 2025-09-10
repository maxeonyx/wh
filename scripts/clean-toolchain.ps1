$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repoRoot = Resolve-Path "$PSScriptRoot/.."
$toolchainRoot = Join-Path $repoRoot '.toolchain'
if (Test-Path $toolchainRoot) {
    Remove-Item $toolchainRoot -Recurse -Force
    Write-Host "Removed toolchain at $toolchainRoot"
} else {
    Write-Host "No toolchain directory found."
}
