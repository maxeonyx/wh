Param(
    [ValidateSet('x64','arm64')][string]$Arch,
    [switch]$Debug
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$RepoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $RepoRoot

function Write-Info($msg) { Write-Host "[run] $msg" -ForegroundColor Cyan }

# Require toolchain PATH
$envScript = Join-Path $RepoRoot '.toolchain/env.ps1'
if (-not (Test-Path $envScript)) { throw ".toolchain/env.ps1 missing. Run ./bootstrap.ps1 first." }
. $envScript

if (-not $Arch) {
    switch ($env:PROCESSOR_ARCHITECTURE) {
        'ARM64' { $Arch = 'arm64' }
        default { $Arch = 'x64' }
    }
}
$RID = if ($Arch -eq 'arm64') { 'win-arm64' } else { 'win-x64' }
$exe = Join-Path $RepoRoot "dist/$RID/wh.exe"
if (-not (Test-Path $exe)) {
    Write-Info "Executable not found at $exe. Building..."
    $exe = & $RepoRoot\build.ps1 -Arch $Arch
    if (-not $exe -or -not (Test-Path $exe)) {
        throw "Build did not produce an executable at $exe. See build output above for details."
    }
}

if ($Debug) {
    $runtimeDir = Join-Path $RepoRoot "dist/$RID/runtime"
    $extractDir = Join-Path $RepoRoot "dist/$RID/extract"
    New-Item -ItemType Directory -Force -Path $runtimeDir,$extractDir | Out-Null
    $env:WH_RUNTIME_DIR = $runtimeDir
    $env:DOTNET_BUNDLE_EXTRACT_BASE_DIR = $extractDir
    $env:DOTNET_BUNDLE_EXTRACT = '1'
    Write-Host "Debug runtime: $runtimeDir" -ForegroundColor Cyan
    Write-Host "Bundle extract: $extractDir" -ForegroundColor Cyan
}

Write-Info "Launching $exe"
Start-Process -FilePath $exe
