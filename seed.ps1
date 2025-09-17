Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$RepoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $RepoRoot

$exe = & $RepoRoot\build.ps1
if (-not $exe -or -not (Test-Path $exe)) { throw "Build failed: executable not found." }

$rid = if ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64') { 'win-arm64' } else { 'win-x64' }
$runtimeDir = Join-Path $RepoRoot "dist/$rid/runtime"
$extractDir = Join-Path $RepoRoot "dist/$rid/extract"
$modelsDir = Join-Path $RepoRoot "dist/$rid/test-models"
New-Item -ItemType Directory -Force -Path $runtimeDir,$extractDir,$modelsDir | Out-Null
$env:WH_RUNTIME_DIR = $runtimeDir
$env:WH_MODELS_DIR = $modelsDir
$env:DOTNET_BUNDLE_EXTRACT_BASE_DIR = $extractDir
$env:DOTNET_BUNDLE_EXTRACT = '1'

Write-Host "Seeding model cache via headless mode..." -ForegroundColor Cyan
$env:WH_HEADLESS = 'seed'
& $exe
if ($LASTEXITCODE -ne 0) { throw "Seeding failed with exit code $LASTEXITCODE" }
Write-Host "Seeding complete." -ForegroundColor Green

