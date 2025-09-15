Param(
    [switch]$Quiet
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-Info($msg) { if (-not $Quiet) { Write-Host "[bootstrap] $msg" -ForegroundColor Cyan } }
function Write-Warn($msg) { Write-Warning $msg }

$RepoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $RepoRoot

$Toolchain = Join-Path $RepoRoot '.toolchain'
New-Item -ItemType Directory -Force -Path $Toolchain | Out-Null

function Add-ToPath($p) {
    if (-not [string]::IsNullOrWhiteSpace($p) -and (Test-Path $p)) {
        if (-not ($env:PATH -split ';' | Where-Object { $_ -eq $p })) {
            $env:PATH = "$p;$env:PATH"
        }
    }
}

function Save-EnvScript {
    param([string]$Content)
    $envPs1 = Join-Path $Toolchain 'env.ps1'
    Set-Content -Path $envPs1 -Value $Content -Encoding UTF8
    Write-Info "Wrote $envPs1 (dot-source this in shells to rehydrate PATH)."
}

function Get-Arch {
    switch ($env:PROCESSOR_ARCHITECTURE) {
        'AMD64' { 'x64'; break }
        'ARM64' { 'arm64'; break }
        default { 'x64' }
    }
}

function Ensure-GitPortable {
    if (Get-Command git -ErrorAction SilentlyContinue) {
        Write-Info "git present: $(git --version)"
        return
    }
    $gitDir = Join-Path $Toolchain 'PortableGit'
    if (-not (Test-Path $gitDir)) {
        Write-Info "Fetching Git for Windows release assets…"
        $rel = Invoke-RestMethod -Uri 'https://api.github.com/repos/git-for-windows/git/releases/tags/v2.51.0.windows.1'
        $arch = if ((Get-Arch) -eq 'arm64') { 'arm64' } else { '64-bit' }
        # Prefer MinGit zip for easy extraction
        $asset = @($rel.assets) | Where-Object { $_.name -match "MinGit-.*$arch.*\.zip$" } | Select-Object -First 1
        if (-not $asset) {
            throw 'MinGit zip asset not found in release metadata'
        }
        $out = Join-Path $Toolchain $asset.name
        Write-Info "Downloading $($asset.name)…"
        Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $out
        Write-Info "Extracting Git…"
        Expand-Archive -Path $out -DestinationPath $gitDir -Force
    }
    # MinGit layout: prefer cmd and mingw64\bin
    Add-ToPath (Join-Path $gitDir 'cmd')
    Add-ToPath (Join-Path $gitDir 'mingw64\bin')
    Write-Info "git installed: $(git --version)"
}

function Ensure-DotNet {
    if (Get-Command dotnet -ErrorAction SilentlyContinue) {
        Write-Info "dotnet present: $(dotnet --version)"
        return
    }
    $dnDir = Join-Path $Toolchain 'dotnet'
    New-Item -Force -ItemType Directory -Path $dnDir | Out-Null
    $installer = Join-Path $Toolchain 'dotnet-install.ps1'
    if (-not (Test-Path $installer)) {
        Write-Info "Downloading dotnet installer…"
        Invoke-WebRequest -Uri 'https://dot.net/v1/dotnet-install.ps1' -OutFile $installer
    }
    Write-Info "Installing .NET SDK (LTS) into toolchain…"
    & powershell -NoProfile -ExecutionPolicy Bypass -File $installer -InstallDir $dnDir -Channel LTS | Write-Verbose
    Add-ToPath $dnDir
    Write-Info "dotnet ready: $(dotnet --version)"
}

function Ensure-MinGW {
    if (Get-Command gcc -ErrorAction SilentlyContinue) {
        Write-Info "gcc present: $(gcc --version | Select-Object -First 1)"
        return
    }
    $arch = Get-Arch
    $winlibsDir = Join-Path $Toolchain 'winlibs'
    New-Item -Force -ItemType Directory -Path $winlibsDir | Out-Null
    Write-Info "Fetching WinLibs release metadata…"
    $rel = Invoke-RestMethod -Uri 'https://api.github.com/repos/brechtsanders/winlibs_mingw/releases/latest'
    $assets = @($rel.assets)
    $pattern = if ($arch -eq 'x64') { 'x86_64' } else { 'arm64|aarch64' }
    $asset = $assets | Where-Object { $_.name -match $pattern -and $_.name -match '\.zip$' } | Select-Object -First 1
    if (-not $asset) { throw "No suitable WinLibs .zip asset found for arch $arch" }
    $zip = Join-Path $winlibsDir $asset.name
    Write-Info "Downloading $($asset.name)…"
    Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $zip
    Write-Info "Extracting WinLibs…"
    Expand-Archive -Path $zip -DestinationPath $winlibsDir -Force
    # Find the extracted bin folder
    $bin = Get-ChildItem -Path $winlibsDir -Directory | ForEach-Object {
        $c1 = Join-Path $_.FullName 'mingw64\bin'
        $c2 = Join-Path $_.FullName 'bin'
        foreach ($c in @($c1,$c2)) { if (Test-Path $c) { $c } }
    } | Select-Object -First 1
    if (-not $bin) { throw "Could not locate MinGW bin folder after extraction" }
    Add-ToPath $bin
    Write-Info "gcc installed: $(gcc --version | Select-Object -First 1)"
}

# Execute
Ensure-GitPortable
Ensure-DotNet
Ensure-MinGW

# Persist env rehydration helper for other scripts
$envContent = @()
if (Test-Path (Join-Path $Toolchain 'PortableGit\bin')) {
    $p = Join-Path $Toolchain 'PortableGit\bin'
    $envContent += ('$env:PATH = "' + $p + ';$env:PATH"')
}
if (Test-Path (Join-Path $Toolchain 'dotnet')) {
    $p = Join-Path $Toolchain 'dotnet'
    $envContent += ('$env:PATH = "' + $p + ';$env:PATH"')
}
$mgBin = (Get-ChildItem -Path (Join-Path $Toolchain 'winlibs') -Recurse -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -eq 'bin' } | Select-Object -First 1)
if ($mgBin) {
    $envContent += ('$env:PATH = "' + $mgBin.FullName + ';$env:PATH"')
}
Save-EnvScript -Content ([string]::Join("`n", $envContent))

Write-Info "Bootstrap complete."
