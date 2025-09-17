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
$nativeOutDir = Join-Path $RepoRoot 'native/build'
New-Item -ItemType Directory -Force -Path $nativeOutDir | Out-Null

# whisper.cpp vendored sources
$whRoot = Join-Path $RepoRoot 'native/whisper.cpp'
$whInc = $whRoot
$whC = @(
  (Join-Path $whRoot 'ggml.c'),
  (Join-Path $whRoot 'ggml-alloc.c'),
  (Join-Path $whRoot 'ggml-backend.c'),
  (Join-Path $whRoot 'ggml-quants.c')
)
$whCpp = @(
  (Join-Path $whRoot 'whisper.cpp'),
  (Join-Path $RepoRoot 'native/src/wh.cpp')
)
$nativeDll = Join-Path $nativeOutDir 'wh.dll'

if ($Compiler -eq 'mingw') {
    $gcc = (Get-Command gcc -ErrorAction Stop).Source
    $gpp = (Get-Command g++ -ErrorAction Stop).Source
    Write-Info "gcc: $gcc"
    Write-Info "g++: $gpp"
    $objs = @()
    foreach ($c in $whC) {
        $obj = Join-Path $nativeOutDir ((Split-Path $c -Leaf) + '.o')
        $objs += $obj
        $exit = Invoke-Tool { & $gcc `
            '-O2' '-DNDEBUG' '-DGGML_USE_K_QUANTS' '-D_CRT_SECURE_NO_WARNINGS' '-pthread' `
            '-I' $whInc `
            '-c' $c `
            '-o' $obj }
        if ($exit -ne 0) { throw "Native C compile failed for $c (gcc exit $exit)." }
    }
    foreach ($cpp in $whCpp) {
        $obj = Join-Path $nativeOutDir ((Split-Path $cpp -Leaf) + '.o')
        $objs += $obj
        $exit = Invoke-Tool { & $gpp `
            '-O2' '-DNDEBUG' '-DGGML_USE_K_QUANTS' '-D_CRT_SECURE_NO_WARNINGS' '-pthread' `
            '-std=c++17' `
            '-I' $whInc `
            '-c' $cpp `
            '-o' $obj }
        if ($exit -ne 0) { throw "Native C++ compile failed for $cpp (g++ exit $exit)." }
    }
    $implib = Join-Path $nativeOutDir 'libwh.a'
    $linkArgs = @()
    $linkArgs += '-shared'
    $linkArgs += $objs
    $linkArgs += @('-static','-static-libgcc','-static-libstdc++','-pthread')
    $linkArgs += @('-o', $nativeDll)
    $linkArgs += @('-Wl,--out-implib,' + $implib)
    $exit = Invoke-Tool { & $gpp @linkArgs }
    if ($exit -ne 0) { throw "Native link failed (g++ exit $exit). See errors above." }
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
    $srcs = @($whC + $whCpp) -join ' '
    $cmd = '"' + $vsdev + '" -arch=' + $archArg + ' && cl /nologo /O2 /DNDEBUG /DGGML_USE_K_QUANTS /D_CRT_SECURE_NO_WARNINGS /EHsc /LD /I "' + $whInc + '" ' + $srcs + ' /Fe:"' + $nativeDll + '"'
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
