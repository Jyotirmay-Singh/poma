param([string]$SigningDirectory = (Join-Path $env:USERPROFILE '.poma/signing'))
$ErrorActionPreference = 'Stop'
if ($env:OS -ne 'Windows_NT') { throw 'This helper uses Windows DPAPI; on other hosts supply signing through secure environment variables.' }
$root = Split-Path -Parent $PSScriptRoot
$rtk = Join-Path $root '.tools/rtk/rtk.exe'
if (-not (Test-Path $rtk)) { $rtk = (Get-Command rtk -ErrorAction Stop).Source }
$keytool = (Get-ChildItem -Path 'D:/Android/jdk/*/bin/keytool.exe' -ErrorAction SilentlyContinue | Select-Object -First 1).FullName
if (-not $keytool) { $keytool = 'keytool' }
if (-not (Test-Path $keytool)) { $keytool = (Get-Command keytool -ErrorAction Stop).Source }
$directory = [IO.Path]::GetFullPath($SigningDirectory)
if ($directory.StartsWith([IO.Path]::GetFullPath($root), [StringComparison]::OrdinalIgnoreCase)) { throw 'Signing material must be outside the source checkout.' }
$key = Join-Path $directory 'poma-upload.p12'
$credentials = Join-Path $directory 'credentials.xml'
if ((Test-Path $key) -or (Test-Path $credentials)) { throw 'Signing material already exists; refusing to replace it.' }
New-Item -ItemType Directory -Path $directory -Force | Out-Null
& $rtk proxy icacls $directory /inheritance:r /grant:r "$($env:USERDOMAIN)\$($env:USERNAME):(OI)(CI)F" | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'Could not restrict signing-directory access.' }
$password = [Convert]::ToBase64String([Security.Cryptography.RandomNumberGenerator]::GetBytes(36))
$securePassword = ConvertTo-SecureString $password -AsPlainText -Force
$credential = [PSCredential]::new('poma-upload', $securePassword)
# Persist the recoverable DPAPI credential before key creation; never print it.
$credential | Export-Clixml -LiteralPath $credentials
$oldPassword = $env:POMA_ANDROID_STORE_PASSWORD
try {
  $env:POMA_ANDROID_STORE_PASSWORD = $password
  & $rtk proxy $keytool -genkeypair -keystore $key -storetype PKCS12 -alias poma-upload -keyalg RSA -keysize 3072 -validity 10000 -dname 'CN=Jyotirmay Singh, OU=Poma, O=Poma' -storepass:env POMA_ANDROID_STORE_PASSWORD -keypass:env POMA_ANDROID_STORE_PASSWORD
  if ($LASTEXITCODE -ne 0) { throw 'Key creation failed; preserve the credential file and inspect the keystore before retrying.' }
} finally { $env:POMA_ANDROID_STORE_PASSWORD = $oldPassword; $password = $null }
Write-Output "Upload key created at $key; DPAPI credential: $credentials. Back up both securely; DPAPI is tied to this Windows user/machine."
