$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$mobileRoot = Join-Path $projectRoot 'mobile'
$manifest = Join-Path $mobileRoot '.flutter-plugins-dependencies'
if (-not (Test-Path -LiteralPath $manifest)) { throw 'Resolve Flutter dependencies first.' }
$plugins = (Get-Content -Raw -LiteralPath $manifest | ConvertFrom-Json).plugins.windows
$linkRoot = Join-Path $mobileRoot 'windows/flutter/ephemeral/.plugin_symlinks'
New-Item -ItemType Directory -Path $linkRoot -Force | Out-Null
foreach ($plugin in $plugins) {
  $target = [IO.Path]::GetFullPath($plugin.path)
  $link = Join-Path $linkRoot $plugin.name
  if (-not (Test-Path -LiteralPath $target)) { throw "Missing cached plugin: $($plugin.name)" }
  if (Test-Path -LiteralPath $link) {
    $existing = Get-Item -LiteralPath $link -Force
    if (-not ($existing.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
      throw "Expected a generated plugin link: $link"
    }
    continue
  }
  # Directory junctions need no Developer Mode or administrator privileges.
  # This is generated workspace state; the target package remains read-only.
  New-Item -ItemType Junction -Path $link -Target $target | Out-Null
}
