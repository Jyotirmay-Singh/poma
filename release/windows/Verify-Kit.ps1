$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSHOME 'Modules/Microsoft.PowerShell.Utility/Microsoft.PowerShell.Utility.psd1')
Import-Module (Join-Path $PSHOME 'Modules/Microsoft.PowerShell.Security/Microsoft.PowerShell.Security.psd1')
# Read-only verification. This does not install Poma or alter certificate trust.
foreach ($line in Get-Content -LiteralPath (Join-Path $PSScriptRoot 'SHA256SUMS.txt')) {
  if ($line -notmatch '^([a-fA-F0-9]{64})  ([a-zA-Z0-9._ /-]+)$') { throw 'Malformed checksum entry.' }
  $file = Join-Path $PSScriptRoot $Matches[2]
  if (-not [IO.Path]::GetFullPath($file).StartsWith($PSScriptRoot.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'Checksum path leaves the kit.' }
  if ((Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash -ne $Matches[1]) { throw "Checksum mismatch: $file" }
}
$packages = @(Get-ChildItem -LiteralPath $PSScriptRoot -Filter '*.msix')
if ($packages.Count -ne 1) { throw 'Expected one MSIX.' }
$signature = Get-AuthenticodeSignature -LiteralPath $packages[0].FullName
$public = [Security.Cryptography.X509Certificates.X509Certificate2]::new((Join-Path $PSScriptRoot 'Poma-Public.cer'))
if ($signature.SignerCertificate.Thumbprint -ne $public.Thumbprint) { throw 'Package signature and public certificate differ.' }
if ($signature.Status -eq 'HashMismatch' -or $signature.Status -eq 'NotSigned') { throw 'Invalid package signature.' }
$sha = [Security.Cryptography.SHA256]::Create()
$fingerprint = [BitConverter]::ToString($sha.ComputeHash($public.RawData)).Replace('-','')
$sha.Dispose()
Write-Output 'File checksums and package signer match this kit.'
Write-Output "Public certificate SHA-256: $fingerprint"
Write-Output "Windows signature trust status: $($signature.Status)"
Write-Output 'Compare the fingerprint with the separate owner-approved release record before trusting this certificate.'
Write-Output 'Trust/installation, clean-profile launch, and runtime acceptance are separate manual checks.'
