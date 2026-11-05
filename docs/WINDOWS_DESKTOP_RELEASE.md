# Private Windows release candidate

## Current private Calendar pilot — Session 10

The complete configured signed **1.0.0.2020** Calendar pilot is now packaged.
Use the [pilot release notes](WINDOWS_CALENDAR_PILOT_RELEASE.md),
[owner checklist](WINDOWS_CALENDAR_PILOT_CHECKLIST.md) and latest
[calendar handoff](WINDOWS_CALENDAR_PROGRESS.md). Final installed/live-Google,
notification/upgrade and offline acceptance remain pending the upgrade and a
successful browser connection; clean-user/clean-machine checks are unavailable.
The owner has 2018 installed; 2020 supersedes 2019 with repaired connection error
messages. Installed 2018 paths/capability are observed, but its Google attempt
failed before a credential was saved. Final 2020 live/upgrade checks remain open.
The offline 2009 and unsigned Session 9 records below retain their own historical
scope and must not be used as final-pilot installed results.

## Calendar verification supplement

Session 9 adds an unsigned, uninstalled Windows Calendar verification build
1.0.0.2017. Its exact source/payload identity and remaining owner gates are in
[calendar acceptance](WINDOWS_CALENDAR_ACCEPTANCE.md). It is unconfigured for live
Google and is not an installable signed pilot. Session 10 must prepare and validate
the private pilot with the preserved identity/certificate and complete runtimes.
The 2009 candidate, signature, hashes and observations below remain historical.

## Product and release status

Windows implementation is ready for owner installation/acceptance, not certified
as a finished public release. Support target is **Windows 11 25H2 x64**, matching
the inspected host (build 26200.9711). The minimum manifest build is 26200. Earlier
Windows and ARM64 are outside the initial support claim.

Windows version is **1.0.0.2009**. The mobile default remains `1.0.0+2007`;
Windows scripts supply their own build version. Executable resources, native About
environment and MSIX identity use the same four-component Windows version.
The original source commit is `cb8b1a1e3f5a376b0121ead5328bb51fbcdc5679` on
`codex/poma-offline-release`; implementation is in the current working tree.
`build-inventory.json` records all implementation input hashes, the input digest,
lockfile, SDK identity, PE imports and packaged-file inventory.

The final candidate location/hash is recorded below.
Only that identified candidate should be installed; earlier `rc*` directories are
intermediate build evidence and may be incomplete or superseded.

## Fixed identities and local signing

- Package: `JyotirmaySingh.Poma.Desktop`; publisher `CN=Jyotirmay Singh`.
- Application: `Poma`; startup task: `PomaStartup`, disabled by default.
- Toast activator: `970A3EE4-5721-4FC9-8AB1-FA8994C723D7`.
- Tray GUID: `6D191080-C183-49BB-83EE-19426A36D40D`.
- Public certificate SHA-256:
  `1CDE2CB78DFABF389C59475EB3684E4837D81AEFADB3723992B02402D328E955`.
- Certificate store thumbprint: `A4632E6041FA461D3908F4072396A842770DE2DC`.

Preserve these identities and the signing certificate across upgrades. Private
signing material is outside source/artifacts in the owner's local Poma Signing
directory. Its PFX password is protected for the current Windows user by DPAPI.
The signing scripts use ephemeral cryptographic keys, not an imported trusted
certificate. Only the public CER/fingerprint enters the kit. No machine trust,
Developer Mode, startup preference or notification preference was changed.
Signing is offline without an Internet timestamp; re-sign/renew before expiry.
The owner should securely back up the signing key using a separately secured
portable password; copying its DPAPI password file to another user is insufficient.

The kit's [installation instructions](../release/windows/INSTALL.md) explain
certificate review/trust, offline install, launch, upgrade, uninstall, data backup
and certificate removal. Trust only the exact public certificate in **Trusted
People** after review; never import a private key or weaken Windows policy.

## Reproduce locally

Use Flutter **3.44.2 / Dart 3.12.2** and locked dependencies. This host builds with
VS Build Tools 2019 16.11.26, MSVC v142 14.29.30133 (compiler 19.29.30148), CMake
3.20 and Windows SDK 10.0.19041. No missing core prerequisite was identified.
ATL was absent: CMake builds a local compatibility copy of the locked Windows
notification dependency, replacing only its three ATL string conversions. The
pub cache and package versions are unchanged. The app-owned toast adapter is used.

RTK commands below assume it is on PATH; on this host use the absolute local
`D:/pomodoro/.tools/rtk/rtk.exe`. Run from the repository root:

```powershell
rtk proxy powershell -NoProfile -ExecutionPolicy Bypass -File scripts/flutter.ps1 --suppress-analytics --no-version-check pub get --enforce-lockfile
rtk proxy powershell -NoProfile -ExecutionPolicy Bypass -File scripts/flutter.ps1 --suppress-analytics --no-version-check analyze --no-pub
rtk proxy powershell -NoProfile -ExecutionPolicy Bypass -File scripts/flutter.ps1 --suppress-analytics --no-version-check test --no-pub
rtk proxy powershell -NoProfile -ExecutionPolicy Bypass -File scripts/test_windows_native.ps1
rtk proxy powershell -NoProfile -ExecutionPolicy Bypass -File scripts/build_windows_release.ps1 -Version 1.0.0.2009 -Python C:/Python314/python.exe
```

The build helper creates generated plugin junctions under ignored workspace state,
so Developer Mode is not required. It discovers the installed licensed x64 CRT
redistributable directory, copies the full release tree/native assets, extracts
the matching redistributable license without running its installer, decompresses
Flutter's notices and validates x64 imports. Supply `-RuntimeDirectory` and
`-RuntimeLicense` if those origins differ. 7-Zip is needed only for automatic
license extraction; no compression/development tool is needed by installed Poma.

The script validates the SDK and executable/package version, preserves existing
candidate directories, and prints the new MSIX location. Build staging and license
extraction live under ignored `.tools`, outside the installation kit. `-SkipBuild`
is only for repackaging an already verified executable of the requested version.

Create signing material **once**, outside the repository/artifacts, or reuse the
existing owner signing directory. The script refuses to overwrite existing keys:

```powershell
rtk proxy powershell -NoProfile -ExecutionPolicy Bypass -File scripts/create_windows_signing_certificate.ps1 -Directory <owner-private-signing-folder>
rtk proxy powershell -NoProfile -ExecutionPolicy Bypass -File scripts/sign_windows_release.ps1 -CandidateDirectory <new-candidate-folder> -SigningDirectory <owner-private-signing-folder>
```

The signing script writes public certificate information, read-only signature
status and recursive SHA-256 checksums. Before owner trust, Windows reports an
untrusted-chain error; that does not establish a trusted installed package. Run
`Verify-Kit.ps1` for file/signer checks and then the manual acceptance procedure.
Do not publish, upload private keys, or distribute a candidate as accepted merely
because it builds/signs. The Windows CI workflow compiles/tests only and uploads
no Windows release artifacts.

## Kit contents and operating limits

The candidate contains signed MSIX, public CER/fingerprint, checksums,
`build-inventory.json`, signature status, offline instructions, a read-only
verification script and readable licenses. The package bundles the Flutter engine,
AOT snapshot/assets, SQLite, notification dependency DLL and matching app-local
Microsoft C++ runtime files. No .NET, Windows App SDK, WebView, runtime installer,
development path, server, Codex connection or Internet download is required by Poma.

Quit stops alerts but retains a running deadline. Resume counts sleep; Poma does
not wake the machine. A cold restart uses bounded UTC recovery, which can be
affected by manual wall-clock changes while stopped. Every successor starts
manually. Exactly-once toast sound/presentation is not promised under crashes or
Windows suppression. Installed data is local to the Windows profile; uninstall
removes package-local data. Google sign-in/calendar/phone synchronization remain
outside this release. See [acceptance observations and checklist](WINDOWS_DESKTOP_ACCEPTANCE.md).

## Final candidate

Build 2009 corrects native focus forwarding on deactivation, preserving popup
keyboard focus, and adds Settings → Open compact timer as an accessible entry
point. The final affected desktop run passed 27 cases. All 2008 candidates are
superseded; the same signing certificate is retained.

Use **`D:\pomodoro\artifacts\windows\Poma-1.0.0.2009-rc1`**.

The complete archive is
`D:\pomodoro\artifacts\windows\Poma-1.0.0.2009-rc1-offline-kit.zip`.
ZIP SHA-256: `bea9a16c5144ce55f19404fc886d3b927e48349d83cfa04cebe3042d02aa5399`.
It includes the installer, public certificate, install/recovery instructions,
release notes, acceptance checklist, inventories, verification script and licenses.

- MSIX: `Poma-1.0.0.2009-x64.msix`, **15,274,162 bytes**.
- MSIX SHA-256: `2f6d11c245111446c14d663f3fb2950753c87ffc637c932c5a458df252424803`.
- Source input digest at assembly: `bc38e8afb86a239f0e30122062d5c9885bce46c4da299239bf5a45e3eb1ca79d`.
- Lockfile SHA-256: `cc6af285af5a44c115f82dfe6a2771f5bfdc9f21eba8b825e829e2a828c08a85`.
- Public fingerprint is the SHA-256 listed above; Windows currently reports
  `UnknownError` for the untrusted self-signed chain. SignTool specifically reports
  that the root is untrusted. Certificate trust/install was not performed.
- Static inventory: 13 PE binaries plus the ELF64 x64 AOT snapshot, 55 listed
  payload files before the self-referential inventory. MakeAppx/signing add their
  own integrity metadata. The recursive kit checksums include all loose licenses.

The final release build succeeded with one compiler worker after a host-memory
failure. No toolchain upgrade or OS configuration change was needed. The Android
ARM64 debug compatibility package and eight native tests also passed after a
bounded-memory retry; no phone campaign was run. iOS compilation needs macOS and
remains unobserved for these changes.

The preceding 2008 signed MSIX's extracted runtime was launched and its actual SQLite/VC runtime
modules resolved from the extracted package folder. This is recorded separately
from installed/offline/clean-profile acceptance. No installed Poma package was
returned by the read-only current-user package query at handoff preparation.

`scripts/finalize_windows_kit.ps1 -CandidateDirectory <candidate>` adds build-specific
release notes, a copy of the acceptance checklist and recursive checksums, then
creates the private offline-kit ZIP alongside the candidate directory. It does
not re-sign or change the MSIX hash, trust certificates, install or publish.
All `1.0.0.2008` candidate directories are superseded intermediate evidence.

## Continuation verification — 24–25 October 2026

The 2009 MSIX, original offline ZIP and public signer were rechecked and are
unchanged. All 220 source inputs in the inventory still match. No application
fix or rebuild was needed. The current-user Windows package query again returned
no installed Poma package; trusted installation remains the next owner step.

Files extracted from the exact signed 2009 package now have direct host
observations for visible rendering, numeric duration entry, a hidden one-minute
focus completion with alerts off, the Ready successor, five additional launches
retaining one owner, the Settings popup entry and outside dismissal, paused-state
recovery after normal Quit, and running-break recovery after forced termination.
Final runtime modules also resolve from the extracted package. The detailed
evidence and remaining limits are in `WINDOWS_DESKTOP_ACCEPTANCE.md`.
These observations use development data and do not establish installed
notification/startup integration, clean-profile offline operation, real sleep,
tray placement or accessibility acceptance. No Poma test process remains running.
The kit's bundled checklist retains its original assembly-time baseline; the
workspace acceptance ledger contains these subsequent observations.

When a Codex process inherits PowerShell 7 module paths but launches Windows
PowerShell 5.1, built-in verification commands may fail to auto-load. Import
Utility and Security from that process's `$PSHOME\Modules` before running
`Verify-Kit.ps1`. This scopes the workaround to that verification process;
the installed application has no PowerShell dependency and no system setting
needs to change.

## Definition of done and next handoff

The code/build portion is implemented, checked and privately packaged. Full
completion still requires the final package's recorded owner results: trusted
offline installation in a standard/clean profile, persistence/upgrade, hidden
expiry, real sleep/hibernate, restart/repeated launches, tray placement, startup,
notification actions/policy and accessibility. See the W01–W15 acceptance table.
Compilation, mocks and this host's extracted-file checks do not close those gates.

The next session can begin by reading this file, `WINDOWS_DESKTOP_PROGRESS.md`,
`WINDOWS_DESKTOP_ACCEPTANCE.md`, RTK and the current diff. Preserve the untracked
Calendar session document and private signing material. Record owner observations
against the exact MSIX hash; fix confirmed failures and run affected checks. If a
candidate has already been installed, raise the Windows version for replacements,
retain identity/publisher/certificate and retest the replacement package. Mobile
defaults remain unchanged; Google/phone sync/public publication remain excluded.
