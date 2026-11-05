[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$CandidateDirectory,
      [Parameter(Mandatory=$true)][string]$SigningDirectory)
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSHOME 'Modules/Microsoft.PowerShell.Utility/Microsoft.PowerShell.Utility.psd1')
Import-Module (Join-Path $PSHOME 'Modules/Microsoft.PowerShell.Security/Microsoft.PowerShell.Security.psd1')
$projectRoot = Split-Path -Parent $PSScriptRoot
$rtkPath = Join-Path $projectRoot '.tools/rtk/rtk.exe'
if (-not (Test-Path -LiteralPath $rtkPath)) { $rtkPath = (Get-Command rtk -ErrorAction Stop).Source }
$candidate = (Resolve-Path -LiteralPath $CandidateDirectory).Path
$packages = @(Get-ChildItem -LiteralPath $candidate -Filter '*.msix')
if ($packages.Count -ne 1) { throw 'Select one prepared candidate containing one MSIX.' }
Add-Type -AssemblyName System.Security
$passwordBytes = [Security.Cryptography.ProtectedData]::Unprotect(
  [IO.File]::ReadAllBytes((Join-Path $SigningDirectory 'password.dpapi')), $null,
  [Security.Cryptography.DataProtectionScope]::CurrentUser)
$password = [Text.Encoding]::UTF8.GetString($passwordBytes)
$key = [Security.Cryptography.X509Certificates.X509Certificate2]::new(
  (Join-Path $SigningDirectory 'Poma-Private.pfx'), $password,
  ([Security.Cryptography.X509Certificates.X509KeyStorageFlags]::EphemeralKeySet -bor
   [Security.Cryptography.X509Certificates.X509KeyStorageFlags]::Exportable))
# SignTool has no stdin password interface. A short-lived passwordless PFX in
# the owner-only signing folder avoids exposing a password in process/RTK logs.
$temporaryKey = Join-Path (Resolve-Path -LiteralPath $SigningDirectory).Path ('Poma-Temporary-' + [guid]::NewGuid().ToString('N') + '.pfx')
$sdkBin = Get-ChildItem -LiteralPath (Join-Path ${env:ProgramFiles(x86)} 'Windows Kits/10/bin') -Directory |
  Where-Object { $_.Name -match '^10\.' -and (Test-Path -LiteralPath (Join-Path $_.FullName 'x64/signtool.exe')) } |
  Sort-Object { [version]$_.Name } -Descending | Select-Object -First 1
$signtool = Join-Path $sdkBin.FullName 'x64/signtool.exe'
try {
  [IO.File]::WriteAllBytes($temporaryKey, $key.Export([Security.Cryptography.X509Certificates.X509ContentType]::Pfx, ''))
  # No network timestamp or OS trust alteration.
  & $rtkPath proxy $signtool sign /fd SHA256 /f $temporaryKey $packages[0].FullName
  if ($LASTEXITCODE) { throw 'Package signing failed.' }
} finally {
  if (Test-Path -LiteralPath $temporaryKey) { Remove-Item -LiteralPath $temporaryKey -Force }
  $key.Dispose(); [Array]::Clear($passwordBytes, 0, $passwordBytes.Length); $password = $null
}
Copy-Item -LiteralPath (Join-Path $SigningDirectory 'Poma-Public.cer') -Destination $candidate
Copy-Item -LiteralPath (Join-Path $SigningDirectory 'certificate-info.txt') -Destination $candidate
$signature = Get-AuthenticodeSignature -LiteralPath $packages[0].FullName
if (-not $signature.SignerCertificate) { throw 'The MSIX has no readable signature.' }
$expected = [Security.Cryptography.X509Certificates.X509Certificate2]::new((Join-Path $candidate 'Poma-Public.cer'))
if ($signature.SignerCertificate.Thumbprint -ne $expected.Thumbprint) { throw 'The package signer does not match the supplied public certificate.' }
$signature | Select-Object Status,StatusMessage,@{Name='Signer';Expression={$_.SignerCertificate.Subject}},@{Name='Thumbprint';Expression={$_.SignerCertificate.Thumbprint}} |
  ConvertTo-Json | Set-Content -LiteralPath (Join-Path $candidate 'signature-status.json') -Encoding UTF8
$hashes = Get-ChildItem -LiteralPath $candidate -File -Recurse | Where-Object { $_.Name -ne 'SHA256SUMS.txt' } | Sort-Object FullName |
  ForEach-Object { (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant() + '  ' + $_.FullName.Substring($candidate.Length + 1).Replace('\','/') }
$hashes | Set-Content -LiteralPath (Join-Path $candidate 'SHA256SUMS.txt') -Encoding ASCII
Write-Output "Signed private candidate: $($packages[0].FullName)"
Write-Output "Signature trust status before owner certificate review: $($signature.Status)"
Write-Output 'No certificate trust or package installation was performed.'
