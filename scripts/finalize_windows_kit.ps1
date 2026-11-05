[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)][string]$CandidateDirectory,
  [string]$ReleaseNotesPath,
  [string]$AcceptancePath,
  [ValidatePattern('^[a-z0-9-]+$')][string]$KitLabel = 'offline-kit'
)
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSHOME 'Modules/Microsoft.PowerShell.Utility/Microsoft.PowerShell.Utility.psd1')
Import-Module (Join-Path $PSHOME 'Modules/Microsoft.PowerShell.Security/Microsoft.PowerShell.Security.psd1')
$root = Split-Path -Parent $PSScriptRoot
$candidate = (Resolve-Path -LiteralPath $CandidateDirectory).Path
$inventory = Get-Content -Raw -LiteralPath (Join-Path $candidate 'build-inventory.json') | ConvertFrom-Json
$packages = @(Get-ChildItem -LiteralPath $candidate -Filter '*.msix')
if ($packages.Count -ne 1) { throw 'Expected one signed MSIX.' }
$package = $packages[0]
$certificate = [Security.Cryptography.X509Certificates.X509Certificate2]::new((Join-Path $candidate 'Poma-Public.cer'))
$signature = Get-AuthenticodeSignature -LiteralPath $package.FullName
if (-not $signature.SignerCertificate -or $signature.SignerCertificate.Thumbprint -ne $certificate.Thumbprint -or
    $signature.Status -eq 'HashMismatch' -or $signature.Status -eq 'NotSigned') { throw 'Package signer/integrity check failed.' }
$packageHash = (Get-FileHash -LiteralPath $package.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
$archive = Join-Path (Split-Path -Parent $candidate) ((Split-Path -Leaf $candidate) + '-' + $KitLabel + '.zip')
if (Test-Path -LiteralPath $archive) { throw 'Existing kit archive preserved; choose a new candidate directory for replacements.' }
if ($ReleaseNotesPath) {
  $notes = [IO.File]::ReadAllText((Resolve-Path -LiteralPath $ReleaseNotesPath).Path)
  if (-not $notes.Contains($package.Name) -or -not $notes.ToLowerInvariant().Contains($packageHash)) {
    throw 'Supplied release notes must identify this exact package filename and SHA-256.'
  }
} else {
  $notes = @"
# Poma $($inventory.version) — private Windows acceptance candidate

Target: Windows 11 25H2 x64 (build 26200). No earlier Windows or ARM64 support claim.
Package: $($package.Name)
Package size: $($package.Length) bytes
Package SHA-256: $packageHash
Source input SHA-256 at assembly: $($inventory.source.sourceTreeSha256)
Source base commit: $($inventory.source.baseCommit) plus uncommitted implementation inputs listed in build-inventory.json.

Includes Flutter 3.44.2/Dart 3.12.2 release output, bundled SQLite, plugin/native
assets, application-local Microsoft C++ runtime, icons and readable licenses.
No development runtime, server, account, Google integration or network download
is needed for core use. See INSTALL.md before trusting/installing this package.

The signature's initial Windows trust status is $($signature.Status). The owner
must compare the public certificate fingerprint in certificate-info.txt with the
separate approved release record and trust that exact certificate in Trusted
People before installation. No machine trust or install is performed by this kit.

Automated evidence: 193-case shared Flutter run passed; the final 27-case desktop
refinement run passed; 56 native checks passed; formatting and analysis passed.
The extracted signed package loaded SQLite and required C++ runtime modules from
its own folder. That is an uninstalled file-level check, not installed acceptance.
Packaged notifications, sleep/hibernate, startup, clean-profile offline launch,
upgrade, Narrator and real tray/display placement remain owner gates in ACCEPTANCE.md.

Closing hides Poma to the tray by default. Startup is optional and initially off.
Quit stops new alerts but retains a running deadline. Every next phase needs
Start. Sleep counts but Poma does not wake Windows. Cold restart recovery uses
bounded UTC and can be affected by wall-clock changes while the process is stopped.
Exactly-once history is required; arbitrary-crash exactly-once toast delivery is not promised.

Keep this candidate private until acceptance is complete. Superseded build
directories are evidence only. A replacement after installation needs a higher
version with the same identity/publisher and the retained signing certificate.
"@
}
[IO.File]::WriteAllText((Join-Path $candidate 'RELEASE-NOTES.md'), $notes, (New-Object Text.UTF8Encoding($false)))
if (-not $AcceptancePath) { $AcceptancePath = Join-Path $root 'docs/WINDOWS_DESKTOP_ACCEPTANCE.md' }
if ([IO.Path]::GetFullPath($AcceptancePath) -ne (Join-Path $candidate 'ACCEPTANCE.md')) {
  Copy-Item -LiteralPath $AcceptancePath -Destination (Join-Path $candidate 'ACCEPTANCE.md')
}
$hashes = Get-ChildItem -LiteralPath $candidate -File -Recurse | Where-Object { $_.Name -ne 'SHA256SUMS.txt' } | Sort-Object FullName |
  ForEach-Object { (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant() + '  ' + $_.FullName.Substring($candidate.Length + 1).Replace('\','/') }
$hashes | Set-Content -LiteralPath (Join-Path $candidate 'SHA256SUMS.txt') -Encoding ASCII
Compress-Archive -LiteralPath @(Get-ChildItem -LiteralPath $candidate | ForEach-Object FullName) -DestinationPath $archive -CompressionLevel Optimal
$archiveHash = (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash.ToLowerInvariant()
($archiveHash + '  ' + [IO.Path]::GetFileName($archive)) | Set-Content -LiteralPath ($archive + '.sha256') -Encoding ASCII
Write-Output "Private installation kit: $archive"
Write-Output "MSIX SHA-256: $packageHash"
Write-Output "Kit SHA-256: $archiveHash"
