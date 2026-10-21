# Release evidence — Session 6

This report distinguishes source checks, packaged facts, attached physical-device
measurements, and disconnected acceptance. Missing measurements are not passes.
The existing Session 5 implementation and uncommitted work are preserved.

## Identity and reproduction

- Baseline HEAD: `fbbb0e0870716f2d4c4fca96c95437730fd38eaf`.
- Original working-tree fingerprint: `f40a4908f2c6282af603e0d6d59ac9dc1d193b139a5958268fb318dcfa8b7a4f`.
- Original source manifest and binary patch: ignored
  `artifacts/session-6/baseline/source.json` and `tracked-changes.patch`.
- Flutter 3.44.2 / Dart 3.12.2, Java 17, Android build tools 36.0.0 and the existing
  lockfile remain the baseline. No app service or network dependency is added.
- Physical target: **Motorola moto g54 5G, Android 15**. Exact build, SDK, security
  patch, ABI, settings, battery and thermal observations are retained locally in
  `artifacts/session-6/device-environment.json`. The device serial is not needed
  in this public report.
- The initial phone inventory had no installed `dev.poma.poma` package. All
  profiling fixtures are synthetic. Do not clear or uninstall an existing user's
  installation to resolve a certificate conflict.

Use `scripts/release_evidence.py source` before each release build to retain an
exact source manifest, and `archive` to retain member sizes and SHA-256 digests.
Use `scripts/profile_android.py` with an explicit device serial and labeled
fixture. Prefix shell commands with RTK as described in the project instructions.
Raw generated evidence belongs under ignored `artifacts/session-6/`; credentials,
local SDKs and tool binaries remain excluded.

### Build metadata issue found

The first `--release --no-pub` build failed because a debug-generated native
registrant referenced `integration_test`, which the Android release Gradle graph
excluded. Flutter 3.44.2's `flutter_command.dart` skips native tooling regeneration
when `shouldRunPub` is false. Release builds therefore retain the normal pub and
platform-tooling stage, with lockfile enforcement checked separately. Generated
registrants are not hand-edited, and SDK/framework versions are not changed.
This is a development-host issue, not an installed-app runtime dependency.

A subsequent build's Gradle daemon exited with a native memory-allocation error.
The retry scopes a 2 GiB Gradle heap, 768 MiB metaspace and one worker to the build
process. Machine policy, global environment and app runtime settings are not
changed. Host build failures and retries are retained separately from phone
performance evidence.

## Artifact size and packaged evidence

Fresh release values will be filled only from completed builds and verified
artifacts. Historical Session 1 optimized APKs and Session 5 debug APKs do not
establish current release size or performance.

| Item | Status |
| --- | --- |
| Per-ABI optimized APK bytes/hash/signature | Pending fresh builds |
| App Bundle bytes/hash | Pending fresh build |
| G54-specific bundletool download estimate | Unmeasured |
| Actual Play-reported download/installed size | Unmeasured; no store submission |
| iOS signed IPA / App Store estimate | Unmeasured; signing/distribution gated |

The provisional arm64 artifact budget is **20 MiB** (20,971,520 bytes). APK file
bytes, bundletool's compressed split-download estimate, installed footprint and
actual store-reported size must occupy different fields.

REA 6.7.0 supports built-in archive inventory here without a disassembler. Export
its complete evidence bundle, root/member hashes, manifest IDs, evidence IDs,
tool identity and limitations for each fresh artifact. Archive inventory does
not prove runtime dependency use, alert delivery, energy consumption, signature
validity or absence of network activity. Android SDK tools independently decode
the manifest/resources and verify alignment/signatures. Native decompilers are
not installed to list archive members.

## Performance method and findings

### Demonstrated redundant repository work

Before optimization, a counted real controller/repository seam produced two
summary reads on creation, first foreground entry, resumed entry and forced
calendar-change reconciliation. Unchanged events produced zero summary reads,
history pages or state writes. Native synchronization occurred once per
meaningful event. The focused baseline suite passed 23 tests. Raw counts, source
hash and method are in `startup-work-baseline.json` and `startup-work-method.md`.
These are host call counts, not physical-phone latency or battery measurements.

The optimization target is duplicate read requests only. Timer recovery,
transactional completion, native action ingestion and alert repair remain in
the serialized safety path. Native alert bootstrap and whole-app tick rebuilds
are candidates for profiling; they are not removed on an assumed speed benefit.

### Physical measurement protocol

Collect 30 process-cold and 30 warm launches for empty and 100,000-session
fixtures. Cold means the background process was actually killed using ordinary
`am kill` and its absence was verified; no force-stop is substituted. Warm means
activity recreation while the process stays alive, with Android's reported
`LaunchState` retained. Report hot resumes separately if observed. First-install
launch is a separate observation, not silently included in the sample set.

Record Android initial-display timestamps separately from the first usable timer
frame. A one-shot `reportFullyDrawn()` marker is sent after the restored app
screen paints. It does not wait on extra work, poll, write SQLite or determine
timer behavior. Missing or ambiguous marker correlations remain unmeasured.

Use Perfetto FrameTimeline and scheduler/process counters, plus Android memory
statistics, to report actual frame durations, RSS, separately labeled PSS, CPU,
I/O and wakes. Record refresh rate and instrumentation overhead. At 60 Hz the
provisional frame target is p95 ≤16.67 ms; also report the actual display's frame
budget rather than treating a 120 Hz run as 60 Hz. The provisional median cold
usable-launch target is <1.5 s.

Compare active, paused, completed and idle states, including locked/background
operation. An active phase must outlast its measurement window. Energy requires
three matched 20-minute windows per comparison, stable brightness/refresh/radios,
thermal/battery state and an unplugged power source. Separate available power
rails, modeled batterystats values and coarse battery changes. Include a
collector/device-idle baseline; do not invent a numeric memory/energy budget or
claim a saving smaller than measurement variability.

The initial observed phone was USB powered, 100% charged and 37.0 °C, with an
active 120 Hz display. That condition cannot establish unplugged battery use.

| Metric | Current result |
| --- | --- |
| Cold/warm initial display and usable timer | Unmeasured |
| First-install launch | Unmeasured |
| Frame p50/p95/p99 and missed deadlines | Unmeasured |
| RSS / PSS / CPU by state | Unmeasured |
| Idle/background polling, I/O and wakes on phone | Unmeasured |
| Matched unplugged energy windows | Unmeasured |

## Offline and privacy acceptance

See [privacy and dependencies](PRIVACY_REVIEW.md) for source findings and the
remaining package/OS checks. Source evidence supports bounded startup/history,
transition-only writes, stopped inactive tickers and manual successors. It does
not replace the following installed-package observations.

For **disconnected acceptance**, install the exact hash-recorded release-mode
APK first, stop developer tools/servers, enable airplane mode, explicitly turn
off Wi-Fi/mobile data, and physically disconnect the computer. Record operator
steps, screenshots/video/timestamps and actual outcomes. A developer-attached
integration test or silent airplane-mode trace is insufficient to establish the
whole flow or absence of attempted network access. Connected traffic observation
is a separate experiment.

| Case | Android G54 | iPhone 16 |
| --- | --- | --- |
| First launch without connectivity or computer | Unverified | Gated |
| Focus, short/long break, pause/resume/reset/skip/select/strict | Unverified | Gated |
| Task add/rename/select/complete/reopen/delete | Unverified | Gated |
| History pagination/totals/deletion and settings | Unverified | Gated |
| Restart preserves tasks/settings/history/timer | Unverified | Gated |
| Locked-screen and another-app local alert | Unverified | Gated |
| Proven ordinary process death and recovery | Unverified | Gated |
| Notification denial/revocation and recovery | Unverified | Gated |
| Cancellation, Open/Dismiss, stale/duplicate responses | Unverified | Gated |
| Clear history/full reset/interrupted native cleanup | Unverified | Gated |
| Attributable outbound traffic/log/task-preview review | Unverified | Gated |
| Actual backup/restore and phone-transfer exclusions/sidecars | Unverified | Gated |

For each started focus, verify its original ID/title/deadline is recorded exactly
once after repeated recovery and its successor stays ready. Short/long breaks
produce no focus-history row. Reset/skip do not create completions. Notification
Open/Dismiss never start or skip a phase. A recents swipe alone is not proof of
ordinary OS process termination.

Record force-stop/force-quit, reboot before/after deadline, timezone and manual
clock changes, Doze/Low Power, exact-alarm revocation and DND/Focus/channel policy
in separate rows with observed suppression/latency and recovery. Android
same-boot elapsed recovery differs from reboot/iOS dead-process UTC fallback.
No universal delivery or second-perfect force-stop/reboot guarantee is made.

## iOS and release gates

The user has an iPhone 16 but no Mac or paid Apple Developer membership and wants
indefinite free use. Seven-day personal signing is not a durable distribution
solution; no temporary sideloading or paid service is configured. macOS GitHub CI
can compile the current simulator/unsigned release and run all ten Swift tests.
An unsigned `.app.zip` is inspection-only, not an installable IPA or device test.
Physical Instruments profiling still needs access to a Mac connected to the
iPhone. Signing, installed acceptance, actual backup/transfer behavior, energy,
and iOS store sizes remain gated until those prerequisites exist.

Production signing, owner-controlled identifiers/branding, store policy review
and submission remain separate release gates. No backend, account, cloud sync,
profile collection, paid infrastructure or hosting is introduced.
