$ErrorActionPreference = 'Stop'
$spikeArguments = @($args)
$workspace = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$spikeSdk = 'D:/SDKs/flutter'
$oldRoot = $env:FLUTTER_ROOT
$oldTemp = $env:TEMP
$oldTmp = $env:TMP
try {
  $env:FLUTTER_ROOT = $spikeSdk
  $env:TEMP = Join-Path $workspace '.tools/tmp'
  $env:TMP = $env:TEMP
  New-Item -ItemType Directory -Path $env:TEMP -Force | Out-Null
  $manifest = Join-Path $PSScriptRoot '.flutter-plugins-dependencies'
  if (Test-Path -LiteralPath $manifest) {
    $linkRoot = Join-Path $PSScriptRoot 'windows/flutter/ephemeral/.plugin_symlinks'
    New-Item -ItemType Directory -Path $linkRoot -Force | Out-Null
    foreach ($plugin in (Get-Content -Raw -LiteralPath $manifest | ConvertFrom-Json).plugins.windows) {
      $link = Join-Path $linkRoot $plugin.name
      if (-not (Test-Path -LiteralPath $link)) {
        New-Item -ItemType Junction -Path $link -Target ([IO.Path]::GetFullPath($plugin.path)) | Out-Null
      }
    }
  }
  Push-Location $PSScriptRoot
  & (Join-Path $workspace '.tools/rtk/rtk.exe') proxy (Join-Path $spikeSdk 'bin/cache/dart-sdk/bin/dart.exe') (Join-Path $spikeSdk 'bin/cache/flutter_tools.snapshot') @spikeArguments
  $code = $LASTEXITCODE
} finally {
  Pop-Location
  $env:FLUTTER_ROOT = $oldRoot
  $env:TEMP = $oldTemp
  $env:TMP = $oldTmp
}
exit $code
