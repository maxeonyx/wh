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
$modelsDir = Join-Path $RepoRoot "dist/$rid/test-models"
New-Item -ItemType Directory -Force -Path $runtimeDir,$extractDir | Out-Null
$env:WH_RUNTIME_DIR = $runtimeDir
$env:WH_MODELS_DIR = $modelsDir
$env:DOTNET_BUNDLE_EXTRACT_BASE_DIR = $extractDir
$env:DOTNET_BUNDLE_EXTRACT = '1'

# No seeding: allow first-run model download & verification

Write-Host "Launching E2E: $exe" -ForegroundColor Cyan
$proc = Start-Process -FilePath $exe -PassThru

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

    $expected = 'Hello, this is Spiderman. This is Spiderman.'
    if ($name -ne $expected) {
        throw "Expected transcript '$expected' but saw '$name'"
    }

    Write-Host "E2E passed: transcript '$name'" -ForegroundColor Green
}
finally {
    if (-not $proc.HasExited) { $proc.Kill() | Out-Null }
}
