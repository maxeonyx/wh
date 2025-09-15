Param(
    [ValidateSet('msvc','mingw')][string]$Compiler,
    [ValidateSet('x64','arm64')][string]$Arch,
    [ValidateSet('Debug','Release')][string]$Configuration = 'Release'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$RepoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $RepoRoot

# Ensure toolchain in PATH
if (Test-Path .\.toolchain\env.ps1) { . .\.toolchain\env.ps1 }
& $RepoRoot\bootstrap.ps1 -Quiet | Out-Null

function Write-Info($msg) { Write-Host "[build] $msg" -ForegroundColor Green }

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
$nativeSrc = Join-Path $RepoRoot 'native/src/wh.c'
$nativeOutDir = Join-Path $RepoRoot 'native/build'
New-Item -ItemType Directory -Force -Path $nativeOutDir | Out-Null
$nativeDll = Join-Path $nativeOutDir 'wh.dll'

if ($Compiler -eq 'mingw') {
    $gcc = Get-Command gcc -ErrorAction Stop | Select-Object -ExpandProperty Source
    Write-Info "gcc: $gcc"
    & $gcc `
        $nativeSrc `
        '-shared' `
        '-o' $nativeDll `
        '-DUNICODE' `
        '-D_UNICODE' `
        ('-Wl,--out-implib,' + (Join-Path $nativeOutDir 'libwh.a')) | Write-Host
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
    $cmd = '"' + $vsdev + '" -arch=' + $archArg + ' && cl /nologo /LD "' + $nativeSrc + '" /Fe:"' + $nativeDll + '"'
    cmd.exe /c $cmd | Write-Host
}

if (-not (Test-Path $nativeDll)) { throw "Native build failed: $nativeDll missing" }
Write-Info "Native built: $nativeDll"

# Build UI single-file
$proj = Join-Path $RepoRoot 'ui/WH/WH.csproj'
$pubDir = Join-Path $RepoRoot "ui/WH/publish/$RID"
dotnet restore $proj | Write-Host
dotnet publish $proj -c $Configuration -r $RID -p:PublishSingleFile=true -p:SelfContained=true -p:IncludeNativeLibrariesForSelfExtract=true -o $pubDir | Write-Host

$exe = Join-Path $pubDir 'WH.exe'
if (-not (Test-Path $exe)) { throw "Publish failed: $exe not found" }
Write-Info "Published single-file: $exe"
Write-Output $exe
