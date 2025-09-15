Param(
    [ValidateSet('x64','arm64')][string]$Arch
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$RepoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $RepoRoot

if (-not $Arch) {
    switch ($env:PROCESSOR_ARCHITECTURE) {
        'ARM64' { $Arch = 'arm64' }
        default { $Arch = 'x64' }
    }
}
$RID = if ($Arch -eq 'arm64') { 'win-arm64' } else { 'win-x64' }
$exe = Join-Path $RepoRoot "ui/wh/publish/$RID/wh.exe"
if (-not (Test-Path $exe)) {
    Write-Host "Executable not found at $exe. Building…" -ForegroundColor Yellow
    & $RepoRoot\build.ps1 -Arch $Arch | Out-Null
}
Start-Process -FilePath $exe

