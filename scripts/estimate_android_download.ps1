param(
  [Parameter(Mandatory=$true)][string]$Bundle,
  [Parameter(Mandatory=$true)][string]$DeviceSpec,
  [Parameter(Mandatory=$true)][string]$OutputDirectory,
  [string]$SigningDirectory = (Join-Path $env:USERPROFILE '.poma/signing')
)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$rtk = Join-Path $root '.tools/rtk/rtk.exe'
if (-not (Test-Path $rtk)) { $rtk = (Get-Command rtk -ErrorAction Stop).Source }
$java = (Get-ChildItem -Path 'D:/Android/jdk/*/bin/java.exe' | Select-Object -First 1).FullName
$tool = Join-Path $root '.tools/bundletool-all-1.18.3.jar'
$toolHash = (Get-FileHash -LiteralPath $tool -Algorithm SHA256).Hash.ToLowerInvariant()
if ($toolHash -ne 'a099cfa1543f55593bc2ed16a70a7c67fe54b1747bb7301f37fdfd6d91028e29') { throw 'Unexpected bundletool binary.' }
$output = [IO.Path]::GetFullPath($OutputDirectory)
if (Test-Path -LiteralPath $output) { throw 'Refusing to overwrite an existing modeled-download run.' }
New-Item -ItemType Directory -Path $output | Out-Null
$specCopy = Join-Path $output 'g54-recorded-device-spec.json'
Copy-Item -LiteralPath $DeviceSpec -Destination $specCopy
$apks = Join-Path $output 'poma-upload-signed-device-splits.apks'
$credential = Import-Clixml -LiteralPath (Join-Path $SigningDirectory 'credentials.xml')
$secretFile = Join-Path ([IO.Path]::GetFullPath($SigningDirectory)) ('bundletool-' + [Guid]::NewGuid().ToString('N') + '.tmp')
try {
  # The parent is the user-only signing directory. No secret enters argv or logs.
  [IO.File]::WriteAllText($secretFile, $credential.GetNetworkCredential().Password)
  & $rtk proxy $java -jar $tool build-apks "--bundle=$Bundle" "--output=$apks" "--device-spec=$specCopy" "--ks=$(Join-Path $SigningDirectory 'poma-upload.p12')" "--ks-key-alias=$($credential.UserName)" "--ks-pass=file:$secretFile" "--key-pass=file:$secretFile" > (Join-Path $output 'build-apks.log') 2>&1
  if ($LASTEXITCODE -ne 0) { throw 'bundletool build-apks failed; inspect its retained log.' }
} finally {
  if (Test-Path -LiteralPath $secretFile) { Remove-Item -LiteralPath $secretFile }
  $credential = $null
}
$size = & $rtk proxy $java -jar $tool get-size total "--apks=$apks" "--device-spec=$specCopy"
if ($LASTEXITCODE -ne 0) { throw 'bundletool size estimate failed.' }
$size | Set-Content -LiteralPath (Join-Path $output 'download-size.csv')
$record = @{
  bundleSha256 = (Get-FileHash -LiteralPath $Bundle -Algorithm SHA256).Hash.ToLowerInvariant()
  deviceSpecSha256 = (Get-FileHash -LiteralPath $specCopy -Algorithm SHA256).Hash.ToLowerInvariant()
  bundletoolSha256 = $toolHash
  apksSha256 = (Get-FileHash -LiteralPath $apks -Algorithm SHA256).Hash.ToLowerInvariant()
  sizeCsv = @($size)
  signing = 'Owner upload certificate; no debug key used'
  device = 'Previously recorded Motorola G54 Android 15/API 35 spec; reused for modeling only'
  limitations = 'Modeled compressed device download, not store-reported size, installed footprint or a new physical-phone observation'
}
$record | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $output 'size.json')
$record | ConvertTo-Json -Depth 5
