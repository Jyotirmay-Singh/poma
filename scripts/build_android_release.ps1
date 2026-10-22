param([string]$SigningDirectory = (Join-Path $env:USERPROFILE '.poma/signing'))
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$rtk = Join-Path $root '.tools/rtk/rtk.exe'
if (-not (Test-Path $rtk)) { $rtk = (Get-Command rtk -ErrorAction Stop).Source }
$credential = Import-Clixml -LiteralPath (Join-Path $SigningDirectory 'credentials.xml')
$names = @('POMA_ANDROID_KEYSTORE_FILE','POMA_ANDROID_KEY_ALIAS','POMA_ANDROID_STORE_PASSWORD','POMA_ANDROID_KEY_PASSWORD','JAVA_HOME','PATH')
$previous = @{}
foreach ($name in $names) { $previous[$name] = [Environment]::GetEnvironmentVariable($name, 'Process') }
try {
  $env:POMA_ANDROID_KEYSTORE_FILE = Join-Path $SigningDirectory 'poma-upload.p12'
  $env:POMA_ANDROID_KEY_ALIAS = $credential.UserName
  $env:POMA_ANDROID_STORE_PASSWORD = $credential.GetNetworkCredential().Password
  $env:POMA_ANDROID_KEY_PASSWORD = $env:POMA_ANDROID_STORE_PASSWORD
  $java = Get-ChildItem -Path 'D:/Android/jdk/*/bin/java.exe' -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($java) { $env:JAVA_HOME = Split-Path -Parent (Split-Path -Parent $java.FullName); $env:PATH = "$env:JAVA_HOME/bin;$env:PATH" }
  & $rtk proxy python (Join-Path $root 'scripts/prepare_release.py') --check
  if ($LASTEXITCODE -ne 0) { throw 'Release metadata is stale.' }
  & $rtk proxy pwsh -NoProfile -File (Join-Path $root 'scripts/flutter.ps1') build apk --release --target-platform android-arm64
  if ($LASTEXITCODE -ne 0) { throw 'Release APK build failed.' }
  & $rtk proxy pwsh -NoProfile -File (Join-Path $root 'scripts/flutter.ps1') build appbundle --release
  if ($LASTEXITCODE -ne 0) { throw 'Release AAB build failed.' }
} finally {
  foreach ($name in $names) { [Environment]::SetEnvironmentVariable($name, $previous[$name], 'Process') }
  $credential = $null
}
