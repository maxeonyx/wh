$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repoRoot = Resolve-Path "$PSScriptRoot/.."
$toolchainRoot = Join-Path $repoRoot '.toolchain'

$cmake = Join-Path $toolchainRoot 'cmake/bin/cmake.exe'
$ninja = Join-Path $toolchainRoot 'ninja/ninja.exe'
$dotnet = Join-Path $toolchainRoot 'dotnet/dotnet.exe'

if (!(Test-Path $cmake) -or !(Test-Path $ninja) -or !(Test-Path $dotnet)) {
    Write-Error "Toolchain missing. Run scripts/bootstrap.ps1 first."
}

# Configure and build engine
& $cmake -S "$repoRoot/engine" -B "$repoRoot/engine/build" -G Ninja -DCMAKE_MAKE_PROGRAM=$ninja -DCMAKE_BUILD_TYPE=Release
& $cmake --build "$repoRoot/engine/build" --config Release

# Build UI as a single executable including native engine
New-Item -ItemType Directory -Force -Path "$repoRoot/dist" | Out-Null
& $dotnet publish "$repoRoot/ui/wh.csproj" -r win-x64 -c Release /p:PublishSingleFile=true /p:IncludeNativeLibrariesForSelfExtract=true -o "$repoRoot/dist"

Write-Host "Build complete."
