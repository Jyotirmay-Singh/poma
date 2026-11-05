# Windows desktop implementation progress

Started 23 October 2026 from `cb8b1a1e3f5a376b0121ead5328bb51fbcdc5679` on `codex/poma-offline-release`.

**Current candidate: 1.0.0.2009**. See the release record for its kit/hash; all 2008 packages are superseded.

## Agreed contract

- Private Windows 11 25H2 x64 MSIX release; Flutter 3.44.2 / Dart 3.12.2.
- One controller, timer engine and repository owner; Flutter main window plus native tray popup.
- Close to tray by default. Optional startup defaults off. Quit stops alerts but preserves the saved timer deadline.
- Native sleep-inclusive clock, resident deadline reconciliation, post-commit notifications; no wake service or scheduled toast after Quit.
- Offline/local storage only. Google authorization/calendar synchronization and phone synchronization are excluded.
- Preserve the existing untracked `GOOGLE_CALENDAR_WINDOWS_SESSION_PROMPTS.md` and mobile release evidence.

## Milestones

1. Windows runner, build and package identity — implemented; release builds passed.
2. Production database/path and native clock — implemented; SQLite and clock checks passed.
3. Single owner, resident reconciliation and safe shutdown — implemented; Dart/native coordination checks passed. Real installed/sleep acceptance remains open.
4. Desktop UI, native tray/popup and opt-in startup — implemented; host layout/keyboard checks passed. Physical tray/accessibility/startup checks remain open.
5. Windows notifications/actions — implemented; protocol/COM checks passed. Packaged notification presentation and Windows-policy checks remain open.
6. Complete signed private release kit — assembly/signing verified; final replacement candidate is recorded in the release document. Owner certificate trust/install remains open.
7. Automated checks and handoff — 193-test full run, final 27-case desktop run and 56 native checks passed. Packaged/manual acceptance is pending.

## Evidence rules

Planning established that this host has accepted VS Build Tools 2019, MSVC v142, CMake 3.20 and Windows SDK 19041. New builds and runtime checks are recorded below as they occur. No historical mobile pass certifies this Windows build. Owner-only desktop, sleep, trust and clean-profile checks remain open until observed.

## Implementation log

- Initial diff checked: no tracked changes; existing Calendar document retained.
- SDK/template generation started. No SDK upgrade or OS configuration change requested.

### Implementation and verification — 23–24 October 2026

- Added only the Windows scaffold from the pinned SDK, preserving Android/iOS
  runner configuration. Production promotion retains `sqflite_common_ffi` 2.4.4,
  `sqlite3` 3.5.2 and all locked versions. Schema stays v3; desktop preferences
  are optional namespaced state.
- Windows composition supplies package-local/development-separated data paths,
  bundled SQLite, sleep-inclusive native clock and app-owned notifications.
  No mobile-only channel is selected on Windows. Main window/tray/popup share
  one controller, timer engine and repository writer.
- Added per-user instance ownership/IPC, COM response forwarding, resident
  reconciliation, post-commit effects, reset cleanup and safe Quit. Hardened
  overlapped listener cancellation, worker reaping, early callback re-arming and
  resume before expiry. Delivery receipts favor duplicate suppression; cold
  recovery intentionally never replays completion toasts.
- Added adaptive navigation, desktop Focus/history layouts, keyboard actions,
  numeric duration entry, Windows-specific copy/privacy, high contrast, native
  accessible popup controls, work-area/DPI clamping, scrolling/focus visibility,
  Explorer icon recovery, close explanation and optional StartupTask integration.
  Calendar extension points carry no calendar dependency or mock content.
- Installed toolchain successfully builds release `poma.exe`. Missing symlink
  privileges are handled with generated workspace junctions. Missing ATL is
  handled by a build-local string-conversion compatibility copy; neither needs
  OS configuration changes or dependency upgrades.
- Automated native checks passed 56 assertions outside the restricted execution
  sandbox. The normal-user object test needed that token; no IPC ACL was weakened.
- Initial full Flutter test run: 184 passed / 6 failed. Four mobile semantic
  failures came from nested Focus grouping; two crash tests omitted declared
  assets in their isolated child fixture. Both causes were fixed. Full rerun:
  **193 passed**. A subsequent desktop-only re-arming refinement passed all
  **26** desktop tests. Final formatting checked 53 files without changes;
  static analysis reported no issues.
- Launched the unpackaged release and observed dark Focus, desktop settings,
  navigation and the normal Settings → Quit flow. Some computer-use edit/keyboard
  interactions could not be confirmed because cached accessibility targeting
  failed. Those are not recorded as passes. The pre-final visible resource/module
  sample is preserved with its probing/short-duration limits.
- MakeAppx validated the stable manifest and assembled an initial complete MSIX.
  SignTool signed it; expected chain verification fails until owner trust.
  File/signer checks passed. A final rebuild supersedes initial packages after
  the last accessibility/resume refinements.
- Package auditing now excludes the development `native_assets.json` containing
  build paths and validates production `NativeAssetsManifest.json` resolves the
  bundled SQLite basename. Complete runtime assets, multiscale icons, app-local
  licensed CRT and readable Flutter/package/native/runtime notices are included.
- Signing keys are file-based outside source/artifacts; only public CER and
  fingerprint enter the kit. No trust, startup or notification OS settings were
  changed. Nothing was committed, pushed, uploaded or published.

### Candidate 2008 handoff (superseded)

- Final release build and signing succeeded for
  `artifacts/windows/Poma-1.0.0.2008-rc6/Poma-1.0.0.2008-x64.msix`.
  SHA-256 `b14bf90ce292fcfbc469c1a3fe15a8b600bd2fc05a76dbe10d09985cf60e2c0b`;
  size 15,273,655 bytes. Earlier candidate directories are superseded evidence.
- The Windows rebuild initially hit host commit/memory exhaustion after an
  Android build failure. A verified task-owned orphaned Gradle worker was stopped;
  unrelated applications were left alone. The Windows release script now scopes
  compiler parallelism to one worker by default and restores the prior environment.
- Android ARM64 debug compatibility assembly and **8 native unit tests passed**
  with one worker, in-process Kotlin, a 1 GB heap and short temporary directory.
  This process-local retry changed no Android source/SDK/OS configuration. The
  promoted native SQLite asset was present in the APK. Evidence:
  `artifacts/windows/android-compatibility-2008.json`. macOS/iOS compilation remains
  unavailable here; no historical phone campaign was repeated.
- The signed package's extracted files launched and reached Focus / Ready in the
  accessibility tree. Module inspection verified package-local SQLite, Flutter,
  notification dependency and VC runtime DLLs, with no build-directory resolution.
  The capture tool returned black for that fixture; no final visual claim is made
  from it. The task-owned startup fixture was closed before installed acceptance.
- `Verify-Kit.ps1` passes recursive checksums/signer matching before owner trust.
  Certificate trust, installed launch and W01–W15 manual cases remain pending.
  The read-only current-user package query returned no installed Poma package.

### Final candidate 2009

- Corrected the native runner to forward focus to Flutter only on activation,
  preventing it from taking focus away from the independent popup. Added Settings
  → Open compact timer as an accessible alternate entry point. No second timer
  owner or engine was introduced.
- All 27 affected desktop tests passed, including opening the popup without
  creating/starting another run. Final analysis is clean; formatting checked
  53 files with zero changes.
- Built/signed `artifacts/windows/Poma-1.0.0.2009-rc1/Poma-1.0.0.2009-x64.msix`
  (15,274,162 bytes), SHA-256
  `2f6d11c245111446c14d663f3fb2950753c87ffc637c932c5a458df252424803`.
  Same public certificate; 2008 is superseded. The 2009 native popup/keyboard
  interaction remains a manual acceptance gate because computer-use captures
  were black and input targeting unreliable.

The completed private kit is
`artifacts/windows/Poma-1.0.0.2009-rc1-offline-kit.zip`, SHA-256
`bea9a16c5144ce55f19404fc886d3b927e48349d83cfa04cebe3042d02aa5399`.
Recursive loose-file/signer checks and ZIP content/integrity/private-file checks
pass. Installation and the remaining acceptance cases are still pending owner
observations. The signing certificate is unchanged from the 2008 candidate.

### Continuation verification — 24–25 October 2026

- Rechecked the current working tree and preserved the Calendar document. All
  220 source inputs listed in the candidate inventory still match their recorded
  hashes. No application, dependency or OS configuration changes were made in
  this continuation; no replacement binary was needed.
- The structured continuation record, host identity and evidence hashes are in
  `artifacts/windows/continuation-2009-20261024.json`. Evidence filenames retain
  the date this continuation began.
- Rehashed the 2009 MSIX and offline ZIP: both match the final hashes above.
  Recursive kit checksums and signer matching pass. The current-user package
  query still returns no installed Poma package; certificate trust is unobserved
  and Windows still reports an untrusted signature chain.
- Codex's inherited PowerShell module search path exposed incompatible PowerShell
  7 modules to Windows PowerShell 5.1. Explicitly importing the two built-in
  modules from that process's `$PSHOME` made the read-only verification work.
  This was a process-local tool invocation, with no profile or OS changes.
- Extracted the exact 2009 signed package into the ignored
  `.tools/windows-acceptance-20261024/extracted-2009` directory and backed up the
  closed development profile first. The main window rendered correctly. Visual
  targeting and ordinary number-key input allowed a one-minute focus to be set.
  Flutter accessibility indexes and modifier/text injection remained unreliable;
  Ctrl shortcuts, general typing and keyboard-only use remain unconfirmed.
- Started that focus without enabling completion alerts. Close displayed its
  first-use tray explanation; acknowledging it hid every Poma window. Before
  any reopening, a read-only SQLite observation found exactly one 60-second
  focus completion at its original deadline and a five-minute Short break in
  Ready state. Evidence: `artifacts/windows/hidden-expiry-2009-20261024.json`.
- Five real additional launches all exited successfully while the original
  process remained the sole owner. Reopening showed the same Ready break and
  one completed focus. Evidence:
  `artifacts/windows/repeated-launches-2009-20261024.json`.
- Settings → Open compact timer displayed the native popup, the matching
  five-minute Ready break and accessible action controls, with focus initially
  on Start. Returning to the main window dismissed it. This verifies that entry
  point and outside activation only; real tray clicks, popup keyboard use and
  monitor/overflow placement remain open.
- Paused a manually started break, Quit normally, verified no Poma process
  remained, and reopened it. The paused snapshot, run identity and exact
  294314492-microsecond remainder were preserved. Resume retained the same run.
  After intentionally terminating only this verified test process, reopening
  recovered the running break with the same UTC deadline and elapsed time
  applied. No additional focus completion appeared. Evidence is in the
  `pause-before-restart`, `pause-after-restart`, `resume-after-restart` and
  `crash-recovery` JSON files suffixed `2009-20261024` under `artifacts/windows`.
- Final-candidate runtime inspection confirms Flutter, SQLite and required
  Microsoft C++ runtime modules load from the extracted package, with no module
  loaded from the development build directory. The visible/hidden ten-second
  resource samples are descriptive only; they do not establish rendering,
  network, write-rate or performance guarantees. See
  `runtime-extracted-package-2009-20261024.json` and
  `runtime-extracted-hidden-2009-20261024.json` under `artifacts/windows`.
- Paused the test break and closed the fixture through normal Quit. No Poma
  process remains. Test data is confined to the separate development profile;
  its pre-test backup is under `.tools/windows-acceptance-20261024/development-before`.
  These extracted-file observations do not close installed-package acceptance.

## Remaining owner gates and next session

Use the final package/hash in [Windows release](WINDOWS_DESKTOP_RELEASE.md) and
the numbered [acceptance checklist](WINDOWS_DESKTOP_ACCEPTANCE.md). Review and trust
the public certificate, install offline, and report actual outcomes. S3/hibernate,
clean profile, fully disconnected/tools-closed launch, upgrade, startup,
notification denial/DND/actions, Narrator and real tray/display placement remain
open until observed. Do not repeat historical phone campaigns.

The next implementation session should inspect the current diff, retain the
untracked Calendar document, read these three Windows documents and the relevant
owner results, then fix only observed failures and regenerate a higher-version
candidate if a package was already installed. Preserve the package identity,
publisher and signing certificate. Repeat affected checks for a replacement hash.
No Google setup or phone synchronization belongs in this acceptance work.
