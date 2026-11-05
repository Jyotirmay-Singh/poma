[CmdletBinding()]
param(
  [ValidatePattern('^\d+\.\d+\.\d+\.\d+$')][string]$Version = '1.0.0.2009',
  [string]$OutputDirectory,
  [string]$Python,
  [string]$RuntimeDirectory,
  [string]$RuntimeLicense,
  [string]$CalendarDefinesPath,
  [ValidateRange(1,8)][int]$MaxWorkers = 1,
  [switch]$SkipBuild
)
$ErrorActionPreference = 'Stop'
# A PowerShell 7 parent can pass module paths to Windows PowerShell 5.1.
# Load that process's own modules without changing the machine configuration.
Import-Module (Join-Path $PSHOME 'Modules/Microsoft.PowerShell.Utility/Microsoft.PowerShell.Utility.psd1')
Import-Module (Join-Path $PSHOME 'Modules/Microsoft.PowerShell.Security/Microsoft.PowerShell.Security.psd1')
$projectRoot = Split-Path -Parent $PSScriptRoot
if ($CalendarDefinesPath) {
  if ($SkipBuild) { throw 'Calendar configuration requires a fresh Flutter compilation; do not combine it with SkipBuild.' }
  $CalendarDefinesPath = [IO.Path]::GetFullPath($CalendarDefinesPath)
  try {
    $calendarDefines = [IO.File]::ReadAllText($CalendarDefinesPath) | ConvertFrom-Json
    $allowedKeys = @('POMA_GOOGLE_CLIENT_ID', 'POMA_GOOGLE_DESKTOP_CLIENT_SECRET', 'POMA_GOOGLE_OAUTH_AUDIENCE')
    if (@($calendarDefines.PSObject.Properties | Where-Object { $_.Name -notin $allowedKeys }).Count) { throw 'Invalid keys.' }
    if ($calendarDefines.POMA_GOOGLE_CLIENT_ID -notmatch '^\d+-[A-Za-z0-9_-]+\.apps\.googleusercontent\.com$' -or
        $calendarDefines.POMA_GOOGLE_CLIENT_ID -match 'placeholder' -or
        $calendarDefines.POMA_GOOGLE_OAUTH_AUDIENCE -notin @('external_testing','internal','external_production') -or
        $calendarDefines.POMA_GOOGLE_DESKTOP_CLIENT_SECRET -isnot [string] -or
        $calendarDefines.POMA_GOOGLE_DESKTOP_CLIENT_SECRET -match '[\r\n]') { throw 'Invalid values.' }
  } catch { throw 'Calendar defines file must contain only the three curated Session 4 settings, with a valid client ID and audience. Values are not printed.' }
}
$rtkPath = Join-Path $projectRoot '.tools/rtk/rtk.exe'
if (-not (Test-Path -LiteralPath $rtkPath)) { $rtkPath = (Get-Command rtk -ErrorAction Stop).Source }
function Invoke-LocalTool([string]$Tool, [string[]]$Arguments) {
  & $rtkPath proxy $Tool @Arguments
  if ($LASTEXITCODE) { throw "$([IO.Path]::GetFileName($Tool)) failed ($LASTEXITCODE)." }
}
$parts = $Version.Split('.') | ForEach-Object { [int]$_ }
if ($parts | Where-Object { $_ -gt 65535 }) { throw 'Each Windows version component must be at most 65535.' }
if ($parts[0] -eq 0) { throw 'The MSIX major version must be nonzero.' }
$flutterSdk = $env:POMA_FLUTTER_SDK
if (-not $flutterSdk) { $flutterSdk = Split-Path -Parent (Split-Path -Parent (Get-Command flutter).Source) }
$dart = Join-Path $flutterSdk 'bin/cache/dart-sdk/bin/dart.exe'
$flutterTool = Join-Path $flutterSdk 'bin/cache/flutter_tools.snapshot'
$sdkJson = (& $rtkPath proxy $dart $flutterTool --suppress-analytics --no-version-check --version --machine | Out-String)
if ($LASTEXITCODE) { throw 'Cannot read the pinned Flutter SDK.' }
$sdk = $sdkJson | ConvertFrom-Json
if ($sdk.frameworkVersion -ne '3.44.2' -or $sdk.dartSdkVersion -notmatch '^3\.12\.2') {
  throw 'Poma requires Flutter 3.44.2 / Dart 3.12.2. Do not upgrade automatically.'
}
if (-not $Python) { $Python = (Get-Command python -ErrorAction Stop).Source }
$vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio/Installer/vswhere.exe'
$vsRoot = & $rtkPath proxy $vswhere -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
if (-not $vsRoot) { throw 'Visual Studio C++ desktop tools are missing.' }
if (-not $RuntimeDirectory) {
  $RuntimeDirectory = (Get-ChildItem -LiteralPath (Join-Path $vsRoot 'VC/Redist/MSVC') -Directory |
    Where-Object { $_.Name -match '^\d+\.\d+\.\d+$' } |
    Sort-Object { [version]$_.Name } -Descending | Select-Object -First 1).FullName
}
$crt = Join-Path $RuntimeDirectory 'x64/Microsoft.VC142.CRT'
if (-not (Test-Path -LiteralPath $crt)) {
  $crt = Join-Path $RuntimeDirectory 'x64/Microsoft.VC143.CRT'
}
if (-not (Test-Path -LiteralPath $crt)) { throw 'Matching licensed x64 Visual C++ runtime files are required.' }
$sdkBin = Get-ChildItem -LiteralPath (Join-Path ${env:ProgramFiles(x86)} 'Windows Kits/10/bin') -Directory |
  Where-Object { $_.Name -match '^10\.' -and (Test-Path -LiteralPath (Join-Path $_.FullName 'x64/makeappx.exe')) } |
  Sort-Object { [version]$_.Name } -Descending | Select-Object -First 1
if (-not $sdkBin) { throw 'Windows SDK MakeAppx is missing.' }
if (-not $OutputDirectory) {
  $OutputDirectory = Join-Path $projectRoot ('artifacts/windows/Poma-' + $Version + '-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
}
$OutputDirectory = [IO.Path]::GetFullPath($OutputDirectory)
if (Test-Path -LiteralPath $OutputDirectory) { throw 'Choose a new output directory; existing candidates are preserved.' }
$stage = Join-Path $projectRoot ('.tools/windows-release-stage/' + $Version + '-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $OutputDirectory | Out-Null
New-Item -ItemType Directory -Path $stage -Force | Out-Null
if (-not $SkipBuild) {
  # Use a separate process because the Flutter helper exits with the SDK result.
  $previousParallel = $env:CMAKE_BUILD_PARALLEL_LEVEL
  try {
    $env:CMAKE_BUILD_PARALLEL_LEVEL = "$MaxWorkers"
    $calendarBuildArguments = @()
    if ($CalendarDefinesPath) { $calendarBuildArguments = @("--dart-define-from-file=$CalendarDefinesPath") }
    Invoke-LocalTool 'powershell' (@('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File',
      (Join-Path $PSScriptRoot 'flutter.ps1'), '--suppress-analytics', '--no-version-check',
      'build', 'windows', '--release', '--no-pub', "--build-name=$($parts[0]).$($parts[1]).$($parts[2])", "--build-number=$($parts[3])") + $calendarBuildArguments)
  } finally { $env:CMAKE_BUILD_PARALLEL_LEVEL = $previousParallel }
}
$release = Join-Path $projectRoot 'mobile/build/windows/x64/runner/Release'
$exe = Get-Item -LiteralPath (Join-Path $release 'poma.exe')
if ($exe.VersionInfo.FileVersion -ne $Version) { throw 'The executable version does not match this package. Rebuild it.' }
# Complete Flutter output, including build-hook native assets. Never select only the EXE.
Get-ChildItem -LiteralPath $release | Where-Object { $_.Extension -ne '.pdb' -and $_.Name -ne 'native_assets.json' } |
  Copy-Item -Destination $stage -Recurse
Get-ChildItem -LiteralPath $crt -Filter '*.dll' | Copy-Item -Destination $stage
Copy-Item -LiteralPath (Join-Path $projectRoot 'release/windows/Assets') -Destination $stage -Recurse
$manifest = [IO.File]::ReadAllText((Join-Path $projectRoot 'release/windows/AppxManifest.xml.in')).Replace('@VERSION@', $Version)
[IO.File]::WriteAllText((Join-Path $stage 'AppxManifest.xml'), $manifest, (New-Object Text.UTF8Encoding($false)))
$publicCalendarClient = [ordered]@{
  schemaVersion = 2
  configured = [bool]$CalendarDefinesPath
  clientType = 'desktop-public'
  clientId = $null
  audience = 'unconfigured'
  scopes = @(
    'https://www.googleapis.com/auth/calendar.calendarlist.readonly',
    'https://www.googleapis.com/auth/calendar.events.readonly'
  )
  focusSchedulingScopes = @(
    'https://www.googleapis.com/auth/calendar.calendarlist.readonly',
    'https://www.googleapis.com/auth/calendar.events.readonly',
    'https://www.googleapis.com/auth/calendar.app.created'
  )
  authorization = 'External default browser; authorization code; PKCE S256; temporary IPv4 loopback callback'
  credentialNotice = 'Desktop client settings are public application metadata. User tokens and the private build-input file are never included.'
}
if ($CalendarDefinesPath) {
  $publicCalendarClient.clientId = $calendarDefines.POMA_GOOGLE_CLIENT_ID
  $publicCalendarClient.audience = $calendarDefines.POMA_GOOGLE_OAUTH_AUDIENCE
}
$publicCalendarClient | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $stage 'public-calendar-client.json') -Encoding UTF8
$licenses = Join-Path $stage 'Licenses'
New-Item -ItemType Directory -Path $licenses | Out-Null
Copy-Item -LiteralPath (Join-Path $projectRoot 'THIRD_PARTY_NOTICES.md') -Destination $licenses
Copy-Item -LiteralPath (Join-Path $projectRoot 'mobile/assets/licenses/windows-native.txt') -Destination $licenses
Copy-Item -LiteralPath (Join-Path $flutterSdk 'LICENSE') -Destination (Join-Path $licenses 'Flutter-LICENSE.txt')
if (-not $RuntimeLicense) {
  # Extract the existing authorized redistributable, without executing/installing it.
  $sevenZip = (Get-Command '7z.exe' -ErrorAction SilentlyContinue).Source
  if (-not $sevenZip) { $sevenZip = Join-Path $env:ProgramFiles '7-Zip/7z.exe' }
  if (-not (Test-Path -LiteralPath $sevenZip)) { throw 'Supply -RuntimeLicense from the matching redistributable, or install 7-Zip for extraction.' }
  $extract = Join-Path $projectRoot ('.tools/windows-runtime-license/' + [guid]::NewGuid().ToString('N'))
  Invoke-LocalTool $sevenZip @('x', (Join-Path $RuntimeDirectory 'vc_redist.x64.exe'), "-o$extract", '-y')
  [xml]$burn = Get-Content -Raw -LiteralPath (Join-Path $extract '0')
  $payload = $burn.BurnManifest.UX.Payload | Where-Object { $_.FilePath -eq 'license.rtf' }
  if (-not $payload) { throw 'The runtime license was not found in this redistributable.' }
  $RuntimeLicense = Join-Path $extract $payload.SourcePath
}
Copy-Item -LiteralPath $RuntimeLicense -Destination (Join-Path $licenses 'Microsoft-Visual-C-Runtime.rtf')
[IO.File]::WriteAllText((Join-Path $stage 'flutter-sdk.json'), $sdkJson)
$runtimeFiles = Get-ChildItem -LiteralPath $crt -Filter '*.dll' | ForEach-Object {
  [ordered]@{ name=$_.Name; version=$_.VersionInfo.FileVersion; sha256=(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash }
}
$runtimeFiles | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $stage 'runtime-source.json') -Encoding UTF8
Invoke-LocalTool $Python @((Join-Path $PSScriptRoot 'windows_release.py'), $stage, '--version', $Version)
$msix = Join-Path $OutputDirectory "Poma-$Version-x64.msix"
Invoke-LocalTool (Join-Path $sdkBin.FullName 'x64/makeappx.exe') @('pack', '/d', $stage, '/p', $msix, '/o')
Copy-Item -LiteralPath (Join-Path $projectRoot 'release/windows/INSTALL.md') -Destination $OutputDirectory
Copy-Item -LiteralPath (Join-Path $projectRoot 'release/windows/Verify-Kit.ps1') -Destination $OutputDirectory
Copy-Item -LiteralPath (Join-Path $stage 'build-inventory.json') -Destination $OutputDirectory
Copy-Item -LiteralPath (Join-Path $stage 'public-calendar-client.json') -Destination $OutputDirectory
Copy-Item -LiteralPath $licenses -Destination $OutputDirectory -Recurse
Write-Output "Unsigned package prepared: $msix"
Write-Output 'Sign with scripts/sign_windows_release.ps1. This script does not trust certificates or install packages.'
