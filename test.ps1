Param(
    [int]$TimeoutSeconds = 10
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$RepoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $RepoRoot

# Ensure no stale processes are locking publish outputs
Get-Process -Name 'wh','TextSink' -ErrorAction SilentlyContinue | ForEach-Object {
    try { Stop-Process -Id $_.Id -Force -ErrorAction Stop } catch { }
}
Start-Sleep -Milliseconds 200

# Build for current arch using default compiler selection
$exe = & $RepoRoot\build.ps1
if (-not $exe -or -not (Test-Path $exe)) { throw "Build failed: executable not found." }

$wav = Join-Path $RepoRoot 'assets\audio\hello.wav'
if (-not (Test-Path $wav)) { throw "Missing test asset: $wav" }

# Use repo-local debug runtime/extract to observe single-file behavior
$rid = if ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64') { 'win-arm64' } else { 'win-x64' }
$runtimeDir = Join-Path $RepoRoot "dist/$rid/runtime"
$extractDir = Join-Path $RepoRoot "dist/$rid/extract"
$modelsDir = Join-Path $RepoRoot "dist/$rid/test-models"
New-Item -ItemType Directory -Force -Path $runtimeDir,$extractDir | Out-Null
$env:WH_RUNTIME_DIR = $runtimeDir
$env:WH_MODELS_DIR = $modelsDir
$env:DOTNET_BUNDLE_EXTRACT_BASE_DIR = $extractDir
$env:DOTNET_BUNDLE_EXTRACT = '1'

# Build TextSink test target (separate app with a text box)
$dotnet = Join-Path $RepoRoot '.toolchain/dotnet/dotnet.exe'
if (-not (Test-Path $dotnet)) { throw ".toolchain/dotnet/dotnet.exe missing. Run ./bootstrap.ps1." }
$sinkProj = Join-Path $RepoRoot 'tools/TextSink/TextSink.csproj'
if (-not (Test-Path $sinkProj)) { throw "Missing test sink project at $sinkProj" }
$sinkOut = Join-Path $RepoRoot "dist/$rid/test-sink"
New-Item -ItemType Directory -Force -Path $sinkOut | Out-Null
$null = (& $dotnet publish $sinkProj -c Release -r $rid -o $sinkOut `
    -p:SelfContained=true `
    -p:PublishSingleFile=true `
    -p:IncludeNativeLibrariesForSelfExtract=true 2>&1 | ForEach-Object { Write-Host $_ })
if ($LASTEXITCODE -ne 0) { throw "dotnet publish for TextSink failed" }
$sinkExe = Join-Path $sinkOut 'TextSink.exe'
if (-not (Test-Path $sinkExe)) { throw "TextSink.exe not found at $sinkExe" }

# Compute expected text using a separate, quick headless pass.
# This requires the model to already be present locally.
$model = Join-Path $modelsDir 'ggml-tiny.en.bin'
if (-not (Test-Path $model)) {
    throw "Model not present at $model. Seed once outside tests: `$env:WH_HEADLESS='seed'; & $exe"
}
$env:WH_HEADLESS = 'transcribe'
$expectedFile = Join-Path $RepoRoot "dist/$rid/expected.txt"
Remove-Item -Force -ErrorAction SilentlyContinue $expectedFile | Out-Null
$env:WH_HEADLESS_OUT = $expectedFile
& $exe | Out-Null
if ($LASTEXITCODE -ne 0) { throw "wh.exe headless transcribe failed with code $LASTEXITCODE" }
$env:WH_HEADLESS = ''
$env:WH_HEADLESS_OUT = ''
if (-not (Test-Path $expectedFile)) { throw "Expected transcript file not created at $expectedFile" }
$expected = (Get-Content $expectedFile -Raw).Trim()
if ([string]::IsNullOrWhiteSpace($expected)) { throw "Expected transcript was empty" }

$env:WH_E2E_EXE = $exe
$env:WH_E2E_EXPECTED = $expected
$env:WH_E2E_TIMEOUT = [string]$TimeoutSeconds
$captureFile = Join-Path $RepoRoot "dist/$rid/e2e-capture.txt"
$env:WH_E2E_CAPTURE = $captureFile

Write-Host "Launching TextSink controller: $sinkExe" -ForegroundColor Cyan
$sink = Start-Process -FilePath $sinkExe -PassThru

if (-not $sink.WaitForExit($TimeoutSeconds * 1000)) {
    try { $sink.Kill() | Out-Null } catch { }
    throw "Timed out waiting for TextSink to complete"
}

if ($sink.ExitCode -ne 0) {
    if (Test-Path $captureFile) {
        Write-Host "--- E2E capture ---" -ForegroundColor Yellow
        Get-Content $captureFile | ForEach-Object { Write-Host $_ }
        Write-Host "-------------------" -ForegroundColor Yellow
    }
    throw "TextSink reported failure with exit code $($sink.ExitCode)"
}

Write-Host "E2E passed under TextSink control" -ForegroundColor Green
