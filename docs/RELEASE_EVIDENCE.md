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

The fresh Windows builds below use optimized release mode. Separate installable
copies use the existing Android development certificate; production signing is
unconfigured. Their signature and 16 KiB alignment checks passed. The source
fingerprint immediately before the split build was
`4e677001d4df4bfc99c418c6e1a9e5495c7b6750a57e8927fa0a80fb9059e246`.
Later collector/CI/document edits do not change the app sources used in these
artifacts. Historical Session 1 optimized and Session 5 debug outputs remain
historical evidence.

| Fresh artifact | Exact bytes | SHA-256 |
| --- | ---: | --- |
| ARMv7 validation APK | 15,907,884 | `d5a05b53eb9c59256c68758e8730ab8326fa62784a692a30a597c9c2d644d1ea` |
| ARM64 validation APK, installed on G54 | 18,361,384 | `c162a616d26800f3b165670191e1d3f19f4adb610fc1b42cb88d1f1494a13632` |
| x86_64 validation APK | 19,770,402 | `c4203bd523d2d9e6905ed626ee798bd88c42bc00d5f5d30b79b28fa4730d02c3` |
| Unsigned AAB, all supported ABIs | 51,631,477 | `44f82c34318c298fd9cd909155618da8d1b902194d9691dce8250729d390071f` |

| Download/distribution metric | Status |
| --- | --- |
| G54-specific bundletool compressed split estimate | **8,440,294 bytes**, min=max for retained device spec |
| Actual Play-reported download/installed size | Unmeasured; no store submission |
| iOS signed IPA / App Store estimate | Unmeasured; signing/distribution gated |

The provisional arm64 artifact budget is **20 MiB** (20,971,520 bytes). APK file
bytes, bundletool's compressed split-download estimate, installed footprint and
actual store-reported size must occupy different fields.

The ARM64 APK is **17.51 MiB**, passing that artifact budget. Bundletool 1.18.3
SHA-256 is `a099cfa1543f55593bc2ed16a70a7c67fe54b1747bb7301f37fdfd6d91028e29`.
Its generated device splits use the development certificate. Exact certificate
DN/digests, signer output, unsigned source hashes, member hashes, size CSV and
device-spec identity are retained under `artifacts/session-6/final/`.

REA 6.7.0 supports built-in archive inventory here without a disassembler. Export
its complete evidence bundle, root/member hashes, manifest IDs, evidence IDs,
tool identity and limitations for each fresh artifact. Archive inventory does
not prove runtime dependency use, alert delivery, energy consumption, signature
validity or absence of network activity. Android SDK tools independently decode
the manifest/resources and verify alignment/signatures. Native decompilers are
not installed to list archive members.

REA inspected all four fresh archives: each APK has 93 ZIP entries plus its root
occurrence; the AAB has 107 entries plus its root. Complete exported records are
`rea-arm64-evidence.json` and `rea-all-packages.json`. Inspection parent IDs:

- ARM64: `ev_30107e3b5d05844e667c8ae8af57561c33f4ec456d752a2a653abcec188af092`.
- ARMv7: `ev_99cdf08c44191f46be0d9d7ed1a25d62173323b879f5a224b4280bc3cbd511d0`.
- x86_64: `ev_3c56ea2a11bdd957791d2b5b79b0a3d22dbdcc41788e0965550864443a6c9fc2`.
- AAB: `ev_111d302a4bb5acf792d6a04656e2350ef2309e4b1ad21bf4ff12ccfcd69e6f8a`.

ARM64 Flutter identification
`ev_babb9671b75e936b401bec567701a27932dc2ba238a25692b72c700f20348f1f`
observes packaged AOT and engine libraries. It makes no SDK lookup. Root/member
digests and inventory coverage are retained independently of source inspection.

## Performance method and findings

### Demonstrated redundant repository work

Before optimization, a counted real controller/repository seam produced two
summary reads on creation, first foreground entry, resumed entry and forced
calendar-change reconciliation. Unchanged events produced zero summary reads,
history pages or state writes. Native synchronization occurred once per
meaningful event. The focused baseline suite passed 23 tests. Raw counts, source
hash and method are in `startup-work-baseline.json` and `startup-work-method.md`.
These are host call counts, not physical-phone latency or battery measurements.

The implemented change reduces each of those two reads to **one**, with zero
startup history-page reads and zero unchanged-event writes retained. Counted
before/after results are in `startup-work-baseline.json` and
`startup-work-after.json`; the final complete suite has **157 passing Flutter
tests**. Its EXPLAIN check exercises production pagination SQL. This establishes
less repository work; the launch samples below do not establish a phone speedup.
Timer recovery,
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
active 120 Hz display. Later battery, thermal, radio and brightness readings
belong to their individual raw runs; the conditions are not silently equated.
USB-connected measurements cannot establish unplugged battery use.

| Empty-history release launch | Samples | Initial display median / p95 | Usable timer median / p95 |
| --- | ---: | --- | --- |
| Preserved baseline cold | 30 | 460 / 528 ms | Unmeasured; earlier marker ambiguous |
| Preserved baseline warm | 30 | 398 / 443 ms | Unmeasured; earlier marker ambiguous |
| Current APK cold | 30 | 538 / 649 ms | **597 / 729 ms** |
| Current APK warm | 30 | 464 / 543 ms | **516 / 590 ms** |
| Baseline, 100,000 sessions, cold | 30 | 552 / 637 ms | Unmeasured; earlier marker ambiguous |
| Baseline, 100,000 sessions, warm | 30 | 429 / 532 ms | Unmeasured; earlier marker ambiguous |
| Current APK, 100,000 sessions, cold | 30 | 529 / 646 ms | **597 / 689 ms** |
| Current APK, 100,000 sessions, warm | 30 | 444 / 547 ms | **493 / 629 ms** |

The first-install baseline initial display was **700 ms**, kept separately from
the repeated samples. First-install usable latency remains unmeasured. Every
current launch has a unique correlated restored-screen marker and the expected
COLD/WARM state. Current median cold usable latency passes the provisional
1.5-second target. The earlier and later runs are not matched conditions and
must not be described as a demonstrated latency improvement. Raw records:
`baseline/launch-empty-complete.json`, `baseline/first-install-launch.json` and
`final/launch-empty.json`.

The large fixture is exactly 100,000 equal-timestamp synthetic focus sessions,
created through the repository by a separate guarded lab target. Its aggregate
count and bounded 50-row page were verified in the phone UI. A quiescent snapshot
has schema v3, zero tasks, `quick_check=ok`, a 23,711,744-byte main database
(SHA-256 `865faa90b90bc9600ef57ec3afb28dc555e3e7646dcdff8d34b1ba87b3507a06`)
and a zero-byte rollback-journal companion. Host SQLite 3.40.1 inspected that
snapshot; it is not asserted to be Android's SQLite version. No WAL/SHM existed
in that snapshot, so actual exclusion of newly created nonempty WAL/SHM remains
unverified. The debug lab target was replaced by the relevant optimized APK
before every measured run. No lab timing or debug size is release evidence.
Baseline and current large-fixture raw samples are retained in their respective
`launch-100000.json` files, bound to APK hashes. The current 597 ms cold usable
median passes the provisional target with this fixture as well. A small
dependency count or near-equal medians alone does not prove future scaling.

| Metric | Current result |
| --- | --- |
| Empty and 100,000-session cold/warm launch | Measured above, 30 per condition |
| First-install launch | Initial display measured above; usable latency unmeasured |
| Frame p50/p95/p99 and missed deadlines | Unmeasured |
| RSS / PSS / CPU by state | Unmeasured |
| Idle/background polling, I/O and wakes on phone | Unmeasured |
| Matched unplugged energy windows | Unmeasured |

An initial baseline idle foreground trace contains **1.158385 ms** scheduled
Poma CPU in **40.063569 s** (0.002891% of one core), three scheduled slices on
runtime GC/finalizer threads, no rendered Poma frames, and 40 constant process-RSS
samples at **183,263,232 bytes**. It does not establish all idle/background cases
or a frame pass. Android `dumpsys` separately reported about 544,226 KiB total
RSS / 422,495 KiB PSS including 363,138 KiB driver graphics after repeated warm
recreation. These accounting scopes differ; memory remains a measured baseline
and investigation item, not a claimed saving.

Trace SHA-256: `232637af58d03a42e9d4468bff316b18d68c43117265a1d2e1728d7c729b2488`.
Device Perfetto is v46; the official Windows processor is v58.2-add693d8b,
SHA-256 `adfa6bad3d72be3ba9b83fa2b17b69fa13b3ab1cad0f42e52b86188bd5f0f997`.
The trace reports one empty power-rail packet and 198 systrace parse failures;
its available process counters include RSS/swap but no I/O byte counters.
Scheduler observations are retained, while rail energy, complete atrace behavior
and per-second SQLite-write absence cannot be inferred from missing counters.
The corrected summary uses service start/disable timestamps, since raw trace
bounds include older process metadata. Failed collector attempts and the first
incorrect denominator summary remain preserved, labeled and superseded.

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

The approved [draft PR](https://github.com/Jyotirmay-Singh/poma/pull/1) retains the
local Session 5/6 source while leaving the local branch, index and uncommitted
files intact. CI run `39643673748` at `a2a8fc5bb7973b4a981971fe619bbf659cb97718`
passed Android checks/builds, iOS simulator compilation and **all ten Swift
tests**. macOS 26.6.2 / Xcode 26.6 (17F113) / iPhoneOS SDK 26.5 were recorded.
The tests ran on an iPhone 17 Pro **simulator**, iOS 26.4.1; they establish no
iPhone 16 physical behavior. The subsequent unsigned device release build
**failed** with a condensed SwiftCompile error. A verbose diagnostic rerun is
in progress; no unsigned release archive or successful iOS release compilation
is claimed yet. Retained iOS evidence artifact `12366324235`, ZIP SHA-256
`a1d75a1df08472096b2f873e54a067a7ed9f6d125cf250025aaa3e4507eed4b7`,
includes the xcresult, summary, environment and failure log.

An earlier workflow validation failure used an unsupported context in job-level
environment paths. It was corrected to workspace paths; failed run
`39642726025` remains historical. GitHub connector writes were unavailable;
the explicitly approved draft was pushed through the existing Git connection.
No merge or store publication occurred.

Production signing, owner-controlled identifiers/branding, store policy review
and submission remain separate release gates. No backend, account, cloud sync,
profile collection, paid infrastructure or hosting is introduced.
