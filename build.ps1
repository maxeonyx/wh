Param(
    [ValidateSet('msvc','mingw')][string]$Compiler,
    [ValidateSet('x64','arm64')][string]$Arch,
    [ValidateSet('Debug','Release')][string]$Configuration = 'Release'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$RepoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $RepoRoot

# Require toolchain env; bootstrap must be run beforehand
$envScript = Join-Path $RepoRoot '.toolchain/env.ps1'
if (-not (Test-Path $envScript)) {
    throw ".toolchain/env.ps1 missing. Run ./bootstrap.ps1 first."
}
. $envScript

function Write-Info($msg) { Write-Host "[build] $msg" -ForegroundColor Green }
function Invoke-Tool([scriptblock]$cmd) {
    & $cmd 2>&1 | ForEach-Object { Write-Host $_ }
    return $LASTEXITCODE
}

if (-not $Arch) {
    switch ($env:PROCESSOR_ARCHITECTURE) {
        'ARM64' { $Arch = 'arm64' }
        default { $Arch = 'x64' }
    }
}

if (-not $Compiler) {
    $Compiler = if (Get-Command cl -ErrorAction SilentlyContinue) { 'msvc' } else { 'mingw' }
}

$RID = if ($Arch -eq 'arm64') { 'win-arm64' } else { 'win-x64' }
Write-Info "Compiler=$Compiler Arch=$Arch RID=$RID Config=$Configuration"

# Build native DLL
$nativeSrc = Join-Path $RepoRoot 'native/src/wh.cpp'
$nativeOutDir = Join-Path $RepoRoot 'native/build'
New-Item -ItemType Directory -Force -Path $nativeOutDir | Out-Null
$nativeDll = Join-Path $nativeOutDir 'wh_native.dll'

if ($Compiler -eq 'mingw') {
    $gpp = Get-Command g++ -ErrorAction Stop | Select-Object -ExpandProperty Source
    Write-Info "g++: $gpp"
    $exit = Invoke-Tool { & $gpp `
        $nativeSrc `
        '-shared' `
        '-static-libgcc' `
        '-static-libstdc++' `
        '-o' $nativeDll `
        '-DUNICODE' `
        '-D_UNICODE' `
        ('-Wl,--out-implib,' + (Join-Path $nativeOutDir 'libwh_native.a')) }
    if ($exit -ne 0) { throw "Native build failed (g++ exit $exit). See errors above." }
} else {
    # MSVC: locate VsDevCmd and invoke cl in that environment
    $vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
    if (-not (Test-Path $vswhere)) { throw "vswhere.exe not found; ensure Visual Studio Build Tools installed." }
    $vsroot = & $vswhere -latest -property installationPath
    if (-not $vsroot) { throw "Visual Studio installation not found." }
    $vsdev = Join-Path $vsroot 'Common7\Tools\VsDevCmd.bat'
    if (-not (Test-Path $vsdev)) { throw "VsDevCmd.bat not found at $vsdev" }
    $archArg = if ($Arch -eq 'arm64') { 'arm64' } else { 'x64' }
    Write-Info "Using MSVC via $vsdev ($archArg)"
    $cmd = '"' + $vsdev + '" -arch=' + $archArg + ' && cl /nologo /EHsc /LD "' + $nativeSrc + '" /Fe:"' + $nativeDll + '"'
    cmd.exe /c $cmd | Write-Host
}

if (-not (Test-Path $nativeDll)) { throw "Native build failed: $nativeDll missing" }
Write-Info "Native built: $nativeDll"

# Build UI single-file
$proj = Join-Path $RepoRoot 'ui/wh/wh.csproj'
$pubDir = Join-Path $RepoRoot "dist/$RID"
New-Item -ItemType Directory -Force -Path $pubDir | Out-Null

# Use toolchain dotnet explicitly
$dotnet = Join-Path $RepoRoot '.toolchain/dotnet/dotnet.exe'
if (-not (Test-Path $dotnet)) { throw ".toolchain/dotnet/dotnet.exe missing. Run ./bootstrap.ps1." }
Write-Host "[build] dotnet: $dotnet" -ForegroundColor Green
$null = (& $dotnet --info 2>&1 | ForEach-Object { Write-Host $_ })
$sdks = & $dotnet --list-sdks
if ($LASTEXITCODE -ne 0) { throw "dotnet SDK not available; run ./bootstrap.ps1" }
if (-not $sdks -or [string]::IsNullOrWhiteSpace(([string]::Join('', $sdks)).Trim())) {
  throw "dotnet --list-sdks returned no SDKs; ensure 8.0 LTS is installed via ./bootstrap.ps1"
}
$null = (& $dotnet restore $proj 2>&1 | ForEach-Object { Write-Host $_ })
if ($LASTEXITCODE -ne 0) { throw "dotnet restore failed. See output above. Try './bootstrap.ps1' if SDKs are missing." }
$null = (& $dotnet publish $proj -c $Configuration -r $RID `
  -p:PublishSingleFile=true `
  -p:SelfContained=true `
  -p:IncludeNativeLibrariesForSelfExtract=true `
  -o $pubDir 2>&1 | ForEach-Object { Write-Host $_ })
if ($LASTEXITCODE -ne 0) { throw "dotnet publish failed. See errors above. If you recently added Windows Forms, ensure <UseWindowsForms>true</UseWindowsForms> is set in ui/wh/WH.csproj." }

$exe = Join-Path $pubDir 'wh.exe'
if (-not (Test-Path $exe)) { throw "Publish failed: $exe not found. The build likely failed." }
Write-Info "Published single-file: $exe"
Write-Output $exe
