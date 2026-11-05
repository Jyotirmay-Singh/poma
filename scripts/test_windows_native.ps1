$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$rtkPath = Join-Path $projectRoot '.tools/rtk/rtk.exe'
if (-not (Test-Path -LiteralPath $rtkPath)) { $rtkPath = (Get-Command rtk -ErrorAction Stop).Source }
$vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio/Installer/vswhere.exe'
$vsRoot = & $vswhere -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
if (-not $vsRoot) { throw 'Install the Visual Studio C++ desktop build tools.' }
$cmake = Join-Path $vsRoot 'Common7/IDE/CommonExtensions/Microsoft/CMake/CMake/bin/cmake.exe'
$ctest = Join-Path (Split-Path -Parent $cmake) 'ctest.exe'
$buildRoot = Join-Path $projectRoot '.tools/windows-native-tests'
& $rtkPath proxy $cmake -S (Join-Path $projectRoot 'mobile/windows/tests') -B $buildRoot -A x64
if ($LASTEXITCODE) { throw 'Native check configuration failed.' }
& $rtkPath proxy $cmake --build $buildRoot --config Release
if ($LASTEXITCODE) { throw 'Native check compilation failed.' }
& $rtkPath proxy $ctest --test-dir $buildRoot -C Release --output-on-failure --verbose
if ($LASTEXITCODE) { throw 'Native checks failed.' }
