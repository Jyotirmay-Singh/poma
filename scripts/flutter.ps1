$FlutterArguments = @($args)
$FlutterSdk = $env:POMA_FLUTTER_SDK
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
if (-not $FlutterSdk) {
  $flutterCommand = Get-Command flutter -ErrorAction Stop
  $FlutterSdk = Split-Path -Parent (Split-Path -Parent $flutterCommand.Source)
}
$rtkPath = Join-Path $projectRoot '.tools/rtk/rtk.exe'
if (-not (Test-Path -LiteralPath $rtkPath)) {
  $rtkPath = (Get-Command rtk -ErrorAction Stop).Source
}
$dartPath = Join-Path $FlutterSdk 'bin/cache/dart-sdk/bin/dart.exe'
$snapshotPath = Join-Path $FlutterSdk 'bin/cache/flutter_tools.snapshot'
if (-not (Test-Path -LiteralPath $snapshotPath)) {
  throw 'Initialize your Flutter SDK first so its tool snapshot is available.'
}
Push-Location (Join-Path $projectRoot 'mobile')
$previousTemp = $env:TEMP
$previousTmp = $env:TMP
$previousJavaOptions = $env:JAVA_TOOL_OPTIONS
$previousFlutterRoot = $env:FLUTTER_ROOT
try {
  # Short socket paths avoid Java NIO failures in Windows sandbox profiles.
  $shortTemp = Join-Path $projectRoot '.tools/tmp'
  New-Item -ItemType Directory -Path $shortTemp -Force | Out-Null
  $env:TEMP = $shortTemp
  $env:TMP = $shortTemp
  $env:FLUTTER_ROOT = $FlutterSdk
  $env:JAVA_TOOL_OPTIONS = ($previousJavaOptions + ' -Djdk.net.unixdomain.tmpdir="' + $shortTemp + '"').Trim()
  & $rtkPath proxy $dartPath $snapshotPath @FlutterArguments
  $result = $LASTEXITCODE
} finally {
  $env:TEMP = $previousTemp
  $env:TMP = $previousTmp
  $env:JAVA_TOOL_OPTIONS = $previousJavaOptions
  $env:FLUTTER_ROOT = $previousFlutterRoot
  Pop-Location
}
exit $result
