Param(
    [int]$TimeoutSeconds = 120
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$RepoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $RepoRoot

# Build for current arch using default compiler selection
$exe = & $RepoRoot\build.ps1
if (-not $exe -or -not (Test-Path $exe)) { throw "Build failed: executable not found." }

$wav = Join-Path $RepoRoot 'assets\audio\hello.wav'
if (-not (Test-Path $wav)) { throw "Missing test asset: $wav" }

# Use repo-local debug runtime/extract to observe single-file behavior
$rid = if ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64') { 'win-arm64' } else { 'win-x64' }
$runtimeDir = Join-Path $RepoRoot "dist/$rid/runtime"
$extractDir = Join-Path $RepoRoot "dist/$rid/extract"
New-Item -ItemType Directory -Force -Path $runtimeDir,$extractDir | Out-Null
$env:WH_RUNTIME_DIR = $runtimeDir
$env:DOTNET_BUNDLE_EXTRACT_BASE_DIR = $extractDir
$env:DOTNET_BUNDLE_EXTRACT = '1'

# Seed a tiny dummy model in the same place the app will read it from
$modelsDir = if (-not [string]::IsNullOrWhiteSpace($env:WH_MODELS_DIR)) {
  $env:WH_MODELS_DIR
} elseif (-not [string]::IsNullOrWhiteSpace($env:WH_RUNTIME_DIR)) {
  Join-Path $env:WH_RUNTIME_DIR 'models'
} else {
  Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'wh\models'
}

$modelName = 'ggml-tiny.en.bin'
$modelPath = Join-Path $modelsDir $modelName
$manifestPath = Join-Path $modelsDir ($modelName + '.manifest.json')
if (-not (Test-Path $modelPath)) {
  New-Item -ItemType Directory -Force -Path $modelsDir | Out-Null
  # Write small dummy model
  [IO.File]::WriteAllBytes($modelPath, [byte[]](1..64))
  # Compute sha256
  $sha256 = Get-FileHash -Algorithm SHA256 -Path $modelPath | Select-Object -ExpandProperty Hash
  $manifest = @{ FileName = $modelName; Sha256 = $sha256.ToLower(); Size = (Get-Item $modelPath).Length } | ConvertTo-Json
  Set-Content -Path $manifestPath -Value $manifest -Encoding UTF8
}

Write-Host "Launching E2E: $exe --e2e-wav $wav" -ForegroundColor Cyan
$proc = Start-Process -FilePath $exe -ArgumentList "--e2e-wav `"$wav`"" -PassThru

try {
    # Wait for window
    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    $win = $null
    do {
        Start-Sleep -Milliseconds 250
        $proc.Refresh()
        if ($proc.HasExited) { throw "Process exited early with code $($proc.ExitCode)" }
        if ($proc.MainWindowHandle -ne 0) { $win = $proc.MainWindowHandle }
    } while (-not $win -and (Get-Date) -lt $deadline)

    if (-not $win) { throw "Timed out waiting for main window" }

    Add-Type -AssemblyName UIAutomationClient, UIAutomationTypes | Out-Null
    $ae = [System.Windows.Automation.AutomationElement]::FromHandle($win)
    $cond = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::AutomationIdProperty, 'TranscriptText')

    $found = $null
    do {
        Start-Sleep -Milliseconds 500
        $found = $ae.FindFirst([System.Windows.Automation.TreeScope]::Descendants, $cond)
        $name = if ($found) { $found.Current.Name } else { $null }
        Write-Host "Observed transcript: '" -NoNewline
        Write-Host ($name) -ForegroundColor Yellow -NoNewline
        Write-Host "'"
        if ((Get-Date) -gt $deadline) { throw "Timed out waiting for transcript" }
    } while (-not $found -or [string]::IsNullOrWhiteSpace($name))

    $expected = 'hello'
    if ($name -ne $expected) {
        throw "Expected transcript '$expected' but saw '$name'"
    }

    Write-Host "E2E passed: transcript '$name'" -ForegroundColor Green
}
finally {
    if (-not $proc.HasExited) { $proc.Kill() | Out-Null }
}
