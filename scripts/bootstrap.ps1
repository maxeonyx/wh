$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# Set up local toolchain directory under the repository
$repoRoot = Resolve-Path "$PSScriptRoot/.."
$toolchainRoot = Join-Path $repoRoot '.toolchain'
New-Item -ItemType Directory -Force -Path $toolchainRoot | Out-Null

# Download portable CMake if not present
$cmakeVersion = '3.29.6'
$cmakeZip = "cmake-$cmakeVersion-windows-x86_64.zip"
$cmakeUrl = "https://github.com/Kitware/CMake/releases/download/v$cmakeVersion/$cmakeZip"
$cmakeDest = Join-Path $toolchainRoot 'cmake'

if (!(Test-Path $cmakeDest)) {
    Write-Host "Downloading CMake $cmakeVersion..."
    $zipPath = Join-Path $toolchainRoot $cmakeZip
    Invoke-WebRequest $cmakeUrl -OutFile $zipPath
    Expand-Archive $zipPath -DestinationPath $toolchainRoot
    Rename-Item (Join-Path $toolchainRoot "cmake-$cmakeVersion-windows-x86_64") $cmakeDest
    Remove-Item $zipPath
}

# Download Ninja
$ninjaVersion = '1.12.1'
$ninjaZip = "ninja-win-$ninjaVersion.zip"
$ninjaUrl = "https://github.com/ninja-build/ninja/releases/download/v$ninjaVersion/$ninjaZip"
$ninjaDest = Join-Path $toolchainRoot 'ninja'

if (!(Test-Path $ninjaDest)) {
    Write-Host "Downloading Ninja $ninjaVersion..."
    $zipPath = Join-Path $toolchainRoot $ninjaZip
    Invoke-WebRequest $ninjaUrl -OutFile $zipPath
    Expand-Archive $zipPath -DestinationPath $ninjaDest
    Remove-Item $zipPath
}

# Install .NET SDK locally
$dotnetDest = Join-Path $toolchainRoot 'dotnet'
if (!(Test-Path $dotnetDest)) {
    Write-Host 'Installing .NET SDK...'
    $installer = Join-Path $toolchainRoot 'dotnet-install.ps1'
    Invoke-WebRequest 'https://dot.net/v1/dotnet-install.ps1' -OutFile $installer
    & powershell -ExecutionPolicy Bypass -File $installer -InstallDir $dotnetDest -NoPath
    Remove-Item $installer
}

# Fetch whisper.cpp source
$thirdParty = Join-Path $PSScriptRoot '..\third_party'
$whisperDest = Join-Path $thirdParty 'whisper.cpp'
if (!(Test-Path $whisperDest)) {
    Write-Host 'Fetching whisper.cpp...'
    New-Item -ItemType Directory -Force -Path $thirdParty | Out-Null
    $whisperZip = Join-Path $toolchainRoot 'whisper.zip'
    $whisperUrl = 'https://github.com/ggerganov/whisper.cpp/archive/refs/tags/v1.5.4.zip'
    Invoke-WebRequest $whisperUrl -OutFile $whisperZip
    Expand-Archive $whisperZip -DestinationPath $thirdParty
    Rename-Item (Join-Path $thirdParty 'whisper.cpp-1.5.4') $whisperDest
    Remove-Item $whisperZip
}

# Add toolchain to PATH for the current session
$env:PATH = "$cmakeDest\bin;$ninjaDest;$dotnetDest;" + $env:PATH

Write-Host "Bootstrap complete."
