$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$powerToysPath = Join-Path $env:LOCALAPPDATA 'Microsoft/PowerToys'
if (Test-Path (Join-Path $powerToysPath 'PowerToys.exe')) {
    Start-Process (Join-Path $powerToysPath 'PowerToys.exe')
    Write-Host 'Open PowerToys > Keyboard Manager to remap Win+H to Win+Shift+H.'
} else {
    Write-Host 'PowerToys is not installed. Download it from https://aka.ms/powertoys.'
}
