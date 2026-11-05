[CmdletBinding()]
param([Parameter(Mandatory=$true)][ValidateSet('Prepare','Restore')][string]$Action)
$ErrorActionPreference = 'Stop'
# Codex can inherit PowerShell 7 module paths when invoking Windows PowerShell.
Import-Module (Join-Path $PSHOME 'Modules/Microsoft.PowerShell.Utility') -Force
$projectRoot = Split-Path -Parent $PSScriptRoot
$recordRoot = [IO.Path]::GetFullPath((Join-Path $projectRoot '.tools/windows-calendar-session2-20261025'))
$profileRoot = [IO.Path]::GetFullPath((Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'Poma/Development'))
$originalRoot = $profileRoot + '.Session2Original-20261025'
$stateFile = Join-Path $recordRoot 'profile-state.json'
if (@(Get-Process -Name poma -ErrorAction SilentlyContinue).Count -ne 0) {
  throw 'Close Poma normally before changing the development test profile.'
}
function Hash-Profile([string]$Directory) {
  $basePath = [IO.Path]::GetFullPath($Directory).TrimEnd('\') + '\'
  @(Get-ChildItem -LiteralPath $Directory -Recurse -File | Sort-Object FullName | ForEach-Object {
    [ordered]@{ path=$_.FullName.Substring($basePath.Length); sha256=(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash }
  })
}
function Assert-Paths {
  $expected = [IO.Path]::GetFullPath((Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'Poma/Development'))
  if ($profileRoot -ne $expected -or $originalRoot -ne ($expected + '.Session2Original-20261025')) { throw 'Unexpected profile path.' }
  $allowed = [IO.Path]::GetFullPath((Join-Path $projectRoot '.tools')).TrimEnd('\') + '\'
  if (-not $recordRoot.StartsWith($allowed, [StringComparison]::OrdinalIgnoreCase)) { throw 'Unexpected backup path.' }
}
Assert-Paths
if ($Action -eq 'Prepare') {
  if (Test-Path -LiteralPath $stateFile) { throw 'A Session 2 backup already exists. Restore it before preparing again.' }
  if (Test-Path -LiteralPath $originalRoot) { throw 'An original profile is already set aside; inspect it before continuing.' }
  New-Item -ItemType Directory -Path $recordRoot -Force | Out-Null
  $existed = Test-Path -LiteralPath $profileRoot
  $hashes = @()
  if ($existed) {
    $hashes = @(Hash-Profile $profileRoot)
    Copy-Item -LiteralPath $profileRoot -Destination (Join-Path $recordRoot 'development-before') -Recurse
    $copyHashes = @(Hash-Profile (Join-Path $recordRoot 'development-before'))
    if (($hashes | ConvertTo-Json -Depth 4 -Compress) -ne ($copyHashes | ConvertTo-Json -Depth 4 -Compress)) { throw 'Backup hash verification failed.' }
  }
  [ordered]@{ preparedUtc=[DateTime]::UtcNow.ToString('o'); existed=$existed; profile=$profileRoot; original=$originalRoot; hashes=$hashes; restored=$false } |
    ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $stateFile -Encoding UTF8
  if ($existed) { Rename-Item -LiteralPath $profileRoot -NewName ([IO.Path]::GetFileName($originalRoot)) }
  New-Item -ItemType Directory -Path $profileRoot -Force | Out-Null
  Set-Content -LiteralPath (Join-Path $profileRoot '.session2-test-profile') -Value 'Isolated fictional Session 2 data; restore using windows_session2_profile.ps1.'
  Write-Output 'Development profile backed up and isolated. No installed profile was changed.'
} else {
  $state = Get-Content -LiteralPath $stateFile -Raw | ConvertFrom-Json
  if ($state.restored) { throw 'The original profile has already been restored.' }
  if ($state.profile -ne $profileRoot -or $state.original -ne $originalRoot) { throw 'Backup record path mismatch.' }
  if (-not (Test-Path -LiteralPath (Join-Path $profileRoot '.session2-test-profile'))) { throw 'Refusing to remove a profile without the test marker.' }
  if ($state.existed) {
    $currentHashes = @(Hash-Profile $originalRoot)
    if (($currentHashes | ConvertTo-Json -Depth 4 -Compress) -ne (@($state.hashes) | ConvertTo-Json -Depth 4 -Compress)) { throw 'Original profile hashes changed; preserve both profiles for review.' }
  }
  Copy-Item -LiteralPath $profileRoot -Destination (Join-Path $recordRoot 'development-after') -Recurse
  # The exact resolved profile and marker were verified above; only task-created data is removed.
  Assert-Paths
  Remove-Item -LiteralPath $profileRoot -Recurse
  if ($state.existed) { Rename-Item -LiteralPath $originalRoot -NewName 'Development' }
  $state.restored = $true
  $state | Add-Member -NotePropertyName restoredUtc -NotePropertyValue ([DateTime]::UtcNow.ToString('o'))
  $state | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $stateFile -Encoding UTF8
  Write-Output 'Original development profile restored; before/after test evidence retained.'
}
