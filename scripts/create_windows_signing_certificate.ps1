[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$Directory)
$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot)).TrimEnd('\') + '\'
$Directory = [IO.Path]::GetFullPath($Directory)
if ($Directory.StartsWith($projectRoot, [StringComparison]::OrdinalIgnoreCase)) {
  throw 'Keep private signing files outside this repository and all release artifacts.'
}
if ((Test-Path -LiteralPath $Directory) -and @(Get-ChildItem -LiteralPath $Directory -Force).Count -gt 0) {
  throw 'Signing directory already contains files. Reuse its certificate; do not silently replace it.'
}
New-Item -ItemType Directory -Path $Directory -Force | Out-Null
$acl = [IO.Directory]::GetAccessControl($Directory, [Security.AccessControl.AccessControlSections]::Access)
$acl.SetAccessRuleProtection($true, $false)
$ownerSid = [Security.Principal.WindowsIdentity]::GetCurrent().User
foreach ($sid in @($ownerSid, [Security.Principal.SecurityIdentifier]::new('S-1-5-18'))) {
  $acl.AddAccessRule([Security.AccessControl.FileSystemAccessRule]::new($sid,
    [Security.AccessControl.FileSystemRights]::FullControl,
    [Security.AccessControl.InheritanceFlags]'ContainerInherit,ObjectInherit',
    [Security.AccessControl.PropagationFlags]::None, [Security.AccessControl.AccessControlType]::Allow))
}
[IO.Directory]::SetAccessControl($Directory, $acl)
# File-based, ephemeral key generation: no certificate-store import, trust change,
# registry setting, or administrator privilege. Only the public CER is distributed.
$rsa = [Security.Cryptography.RSACng]::new(3072)
$request = [Security.Cryptography.X509Certificates.CertificateRequest]::new(
  'CN=Jyotirmay Singh', $rsa, [Security.Cryptography.HashAlgorithmName]::SHA256,
  [Security.Cryptography.RSASignaturePadding]::Pkcs1)
$request.CertificateExtensions.Add([Security.Cryptography.X509Certificates.X509BasicConstraintsExtension]::new($false,$false,0,$true))
$request.CertificateExtensions.Add([Security.Cryptography.X509Certificates.X509KeyUsageExtension]::new([Security.Cryptography.X509Certificates.X509KeyUsageFlags]::DigitalSignature,$true))
$oids = [Security.Cryptography.OidCollection]::new()
[void]$oids.Add([Security.Cryptography.Oid]::new('1.3.6.1.5.5.7.3.3'))
$request.CertificateExtensions.Add([Security.Cryptography.X509Certificates.X509EnhancedKeyUsageExtension]::new($oids,$true))
$certificate = $request.CreateSelfSigned([DateTimeOffset]::Now.AddDays(-1), [DateTimeOffset]::Now.AddYears(5))
$random = New-Object byte[] 32
$rng = [Security.Cryptography.RandomNumberGenerator]::Create(); $rng.GetBytes($random); $rng.Dispose()
$password = [Convert]::ToBase64String($random)
[IO.File]::WriteAllBytes((Join-Path $Directory 'Poma-Private.pfx'), $certificate.Export([Security.Cryptography.X509Certificates.X509ContentType]::Pfx, $password))
Add-Type -AssemblyName System.Security
$protected = [Security.Cryptography.ProtectedData]::Protect([Text.Encoding]::UTF8.GetBytes($password), $null,
  [Security.Cryptography.DataProtectionScope]::CurrentUser)
[IO.File]::WriteAllBytes((Join-Path $Directory 'password.dpapi'), $protected)
[IO.File]::WriteAllBytes((Join-Path $Directory 'Poma-Public.cer'), $certificate.Export([Security.Cryptography.X509Certificates.X509ContentType]::Cert))
$fingerprint = [BitConverter]::ToString([Security.Cryptography.SHA256]::Create().ComputeHash($certificate.RawData)).Replace('-','')
@("Subject: $($certificate.Subject)", "SHA-256 certificate fingerprint: $fingerprint", "SHA-1 store thumbprint: $($certificate.Thumbprint)",
  "Expires: $($certificate.NotAfter.ToUniversalTime().ToString('o'))", 'Private key and DPAPI password are for this Windows user only. Back up securely; never distribute.') |
  Set-Content -LiteralPath (Join-Path $Directory 'certificate-info.txt') -Encoding UTF8
$certificate.Dispose(); $rsa.Dispose(); $password = $null
Write-Output "Private signing material created outside the repository: $Directory"
Write-Output "Public certificate SHA-256: $fingerprint"
Write-Output 'No certificate was trusted or imported. The owner reviews the public certificate before installation.'
