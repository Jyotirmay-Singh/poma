# Release evidence — current Session 8 and historical records

Read [the test completion ledger](TEST_LEDGER.md) before planning checks. Completed results are reusable; a new session or documentation edit does not require repeats. [All 183 automated tests](AUTOMATED_TEST_RESULTS.md) are indexed by name and stable ID.

## Current Session 8 evidence — 22 October 2026

The current [Android acceptance record](ANDROID_ACCEPTANCE_2026_10_22.md)
supersedes historical status statements below for the identified worker revision.
Build 2005 exposed a 10,004 ms input-dispatch ANR during strict full reset.
Build 2006 moves native SQLite/receiver work to a serial worker, with receiver
`goAsync` lifetime and main-thread Flutter event delivery. Immediate strict reset,
confirmation across expiry, durable defaults, native delivery after ordinary
process termination and exactly-once recovery passed on the G54. This is a
correctness repair supported by an observed hang and source contention analysis;
no sampled root-cause stack or matched numeric speed/energy improvement is claimed.

Source revision on the approved draft: `2613cbcb552095c5a37573729d2086def3ed81a8`.
Local HEAD/index and existing edits are preserved. Before-build fingerprint:
`6ef5bd65b064aa3b58ff9988af2d34aedbd94f7092a0c48e8e312b63d377a011`.
Local checks: 165 Flutter tests, eight Android JVM tests, formatting, analysis
and offline enforced lockfile resolution passed. [CI 39729543402](https://github.com/Jyotirmay-Singh/poma/actions/runs/39729543402)
passed Android and macOS, including ten Swift tests, simulator compilation and
unsigned device release compilation. The latter is not an installable IPA or
physical iPhone validation.

| Current artifact | Bytes | SHA-256 |
| --- | ---: | --- |
| Installed Windows ARM64 validation, versionCode 2006 | 18,295,848 | `6edb098ce0389a6f5c970189e4708a18f703d3678e9dfada78e7d143984baa88` |
| CI unsigned ARM64, versionCode 1 | 18,282,149 | `ec7296c19c0f5a8297d00acde40f401c51419c429ada677938e1b41da766dcca` |
| CI unsigned ARMv7, versionCode 1 | 15,842,313 | `945d443bdc9dc1a1cde499853b70691555f369e01b8afebf9420697ceb4c59fd` |
| CI unsigned x86_64, versionCode 1 | 19,755,671 | `c4341c72f52070aa524cd3e0617c12539770ed4e306952dcb72c1aaf739259b0` |
| CI unsigned AAB | 51,480,238 | `035adef72ab9cdfd24b3e572d5855f5e2c1ec6badae6fac24eb6f2eaedef3055` |
| Unsigned iOS .app ZIP | 7,415,982 | `07535cae0e1a601c0911da25c019a127837bd07116c46fd800f974e32954e40f` |

Separate development-certificate CI validation copies passed signature and
16 KiB alignment checks: ARM64 18,295,848 bytes / SHA-256
`7dda2b6d7b3589a99f38fb27908a57dbfed8ac82659c6dac94e81fb2b1dfcaf6`;
ARMv7 15,858,732 /
`38082015a53ac60b1a7442c36159a06c9fc648e99224217687cf7ff7990a14b4`;
x86_64 19,770,402 /
`24e65e0a91e1ee1356852326f44e3e35c162ecb7ae2be8d9ccb22d5cc91cc08e`.
Development signing is distinct from optimized build mode and production signing.
The installed ARM64 size is 17.45 MiB, below the provisional 20 MiB budget.
Bundletool 1.18.3 estimates **8,415,737 bytes** compressed download for the current
G54 spec and AAB. Tool SHA-256 is
`a099cfa1543f55593bc2ed16a70a7c67fe54b1747bb7301f37fdfd6d91028e29`.
Actual store sizes remain unmeasured.

REA 6.7.0 complete central-directory inventories/member hashes and limitations
are exported under ignored `artifacts/session-8/final/rea-*.json`. No disassembler
was installed. Inspection IDs: installed validation
`ev_590c9845a266fcba103cbc32f265abe5928549decaedd0bef617c0ce9584d086`;
CI ARM64 `ev_2dc18d0d5ef98e65b0f2355798da318939b39739fecea9c07a9b7881a1fe9218`;
ARMv7 `ev_6a2117c368bd8ea5fe1e9f8f67e5886eb2196a33945e319ebfbb7835a5856234`;
x86_64 `ev_adc5a7932bf87cd51914e34dd90d444a1a03213c7cc32e66999b19f06d02ab96`;
AAB `ev_e25d5f0d1a6bebd2b67f61db6678df2a133802b98cd6e68ef95cc6ad599858ee`;
iOS `ev_fde40f80ecbee34590adcc8d5eb443ec7a7cbe2877389ecb67c50c3ee429ebb0`.
Inventories have zero integrity contradictions: unsigned APKs 90 members each,
installed signed APK 93, AAB 107, iOS ZIP 78 including directories; root
occurrences are additional. Static evidence does not establish runtime behavior.

The refreshed iOS focused review retains three Mach-O load-command inventories
and four privacy manifests; root ATS overrides and UIBackgroundModes are absent.
No XCTest load reference was found in that bounded inventory; plugin metadata
alone does not establish whether integration-test code is reachable. The source
privacy review covers 31 production files with zero bounded network/log/secret
pattern hits. No dependencies changed; existing transitive network-capability,
unresolved native-license, backup/transfer and traffic limitations still apply.

Current launch/performance raw samples are retained under
`artifacts/session-8/worker-launches-v3/`. Empty fixture: 30 valid process-cold
and 30 valid process-retained warm activity launches. Median initial display is
466/365 ms cold/warm, p95 583/432 ms. Median usable timer is **504/413 ms**,
p95 613/477 ms, with a unique restored-UI marker in every sample. Measurements
are USB-attached on Motorola moto g54 5G / Android 15, portrait and requested
60 Hz; conditions, battery/thermal/radios, commands, hashes and meminfo are in
the raw evidence. Ordinary background termination is used, not force-stop.
Warm samples recreate the activity and retain the process. Collector overhead
is separate from Android display/fully-drawn timestamps. State CPU/RSS and the
large-fixture samples are complete below. First-install latency, frame p95 and
matched unplugged energy remain unmeasured; historical values are not substituted.

The large fixture has exactly 100,000 synthetic equal-timestamp sessions, a
23,711,744-byte main database and a zero-byte journal, integrity OK in a
quiescent host SQLite 3.50.4 read-only check. No WAL/SHM existed in that snapshot;
nonempty sidecar backup behavior is unverified. A debug lab entry point created
the rows; the exact release APK was restored before any large-fixture timing.
The initial bounded host observer timed out while the phone seeder continued;
the fixture was not restarted, and a subsequent observation verified completion.
All 30 large-fixture cold and 30 warm samples were valid with unique usable-UI
markers: initial-display median **422/401 ms**, p95 **536/465 ms**; usable-timer
median **481/437 ms**, p95 **606/490 ms**. Both fixtures satisfy the provisional
cold-launch budget. Different runs/thermal conditions and small differences do
not establish a speed improvement or a statistical history-size penalty.

The fresh production dependency graph has 52 selected Maven coordinates. The
23 uncached POMs were obtained from official Maven repositories, with URLs and
hashes; 22 declare Apache 2.0 directly and listenablefuture inherits the parent
Guava declaration. This resolves missing POM metadata, not complete linked
code/notice/legal clearance. Records are in final/package-review/.

Eight current-release 40-second Perfetto windows compare the same retained
process, large fixture and foreground/background states. All before/after PIDs
match. Completed means a ready successor following a real focus expiry; idle
means a ready phase after reset. Background has Home in front; it is not locked
screen. Active Long break was 15 minutes, longer than both active windows.

| State | Foreground CPU, % of one core | Background CPU, % of one core |
| --- | ---: | ---: |
| Active | 1.544876 | 0.007108 |
| Paused | 0.004525 | 0.004095 |
| Completed / successor ready | 0.004580 | 0.003624 |
| Idle / reset ready | 0.005092 | 0.006419 |

Process RSS counters span **170.53–176.47 MiB** in these windows. Android meminfo
accounts for driver graphics separately: active foreground reports total PSS
432,670 KiB, total RSS 554,533 KiB and Graphics 374,785 KiB. These accounting
scopes must not be conflated. A fresh ordinary-process restart and 30 explicit
warm activity recreations retained the synthetic data. Fresh idle at five
seconds reported PSS 424,228 KiB / RSS 543,036 KiB / Graphics 362,760 KiB;
after 30 recreations plus quiet time, 418,506 / 540,383 / 363,131 KiB. The
large graphics-accounted baseline therefore is not explained mainly by that
recreation sequence. This does not establish a leak, low-RAM suitability,
energy saving or numeric memory budget. A separate fresh-idle Perfetto window
has process RSS 184,778,752–186,232,832 bytes and 0.004205% of one core.

Perfetto 58.2 processor SHA-256:
`adfa6bad3d72be3ba9b83fa2b17b69fa13b3ab1cad0f42e52b86188bd5f0f997`.
CPU is scheduled Poma time divided by the tracing-service collection interval
on one core, not device CPU or energy. OS process/battery counters are sampled
each second by the collector, not by app code. Conditions, UI state, thermal
status, raw meminfo, trace hashes, SQL, per-thread results and health counters
are under `worker-traces/` and `worker-memory/`. An APK identity read overlapped
the completed foreground window; external collection/OS overhead remains a
limitation. No ftrace data loss was reported by the selected health query;
systrace parse failures and empty power-rail packets are retained. Poma-attributed
FrameTimeline samples remain **zero**, so frame p95 and the 16.67 ms budget are
**unmeasured**, not passed. USB traces and unavailable power rails do not replace
three matched 20-minute unplugged energy windows per comparison.

Source/host counts establish bounded startup/history, one coalesced optional
summary read, transition-only SQLite commits and stopped inactive tickers.
These OS traces establish scheduling/RSS for their windows; absent I/O counters
do not establish zero SQL writes. The awaited restoration/alert-safety barrier
remains. No whole-app/theme or native-initialization speed/energy benefit is
claimed without attributable cost evidence. The native serial worker blocks
while idle and introduces no app polling timer, wake lock or foreground service.

Current connected UID accounting over **540 seconds** observed no Poma rows and
zero reported byte/packet delta, with Wi-Fi/data enabled. This is coarse Android
accounting, not packet/DNS/attempted-socket coverage. A current selective
non-incremental backup request returned **Backup is not allowed** for Poma;
overall command Success does not mean the package was backed up. Nonempty
WAL/SHM backup and actual OS/OEM transfer paths remain unverified. Neither probe
changed the backup transport/settings or erased older copies.

Locked-screen recovery on the canonical package subsequently passed after
operator unlock: today count increased from one to two and remained two after
ordinary process termination/reopen; Short break stayed ready at progress1/2.
Perceived sound remains unreported. Full reset of the large synthetic fixture
then passed explicit empty Tasks/Insights and default Focus after restart.
The package was freshly installed with airplane mode enabled, Wi-Fi/data off
and no active default network. Poma was left unopened for the operator to
physically disconnect USB before first Open. These preparation facts do not
establish disconnected acceptance. The operator subsequently reported normal
offline reopen and passed the disconnected focus-locked/manual-break-other-app
sequence with ready successors and one added focus-history record only. These
are operator-reported scoped passes (OFF-01/OFF-02), not independently inspected
conditions, full-matrix completion or alert sound/presentation proof. First
opening was reported online, so offline initial initialization remains unverified.
See [the offline record](OFFLINE_PHONE_RUN.md). A bounded on-phone, package-filtered platform
startup capture may support a separate first-install measurement after reconnect;
no such latency result is claimed yet. See the Android record for methods.

### Renderer diagnostic, separate from the release

A reversible ARM64 release-mode diagnostic changed only Android manifest
`io.flutter.embedding.android.EnableImpeller=false`. Original manifest bytes
were restored immediately after building; no renderer source change was
promoted. Diagnostic before-build fingerprint:
`490a376f25e69e962c6ed0585baaf074365fc791d44a64f7f0f63a445c17126d`.
Development-signed diagnostic APK: 18,295,848 bytes, SHA-256
`6de42e76275f7e35d8fbd8671a34fb0a84430c2a753fafe2f5ee5057de6ea1e9`.
It is distinct from canonical release SHA-256 `6edb098c…`; its measurements must
not be substituted for the installed release results above.

| Fresh idle, Android-reported KiB | Default release | Diagnostic opt-out |
| --- | ---: | ---: |
| Total PSS | 424,228 | 129,787 |
| Total RSS including driver accounting | 543,036 | 250,072 |
| Graphics | 362,760 | 81,492 |

Each column is one fresh-process observation on the same G54, ready Long break,
same appearance and large fixture. The diagnostic has separate condition,
thermal, screenshot, log and trace records in `renderer-diagnostic/`. Visual
inspection of the two ready screens found the same layout/content. The default
process explicitly logs Vulkan/Impeller; the diagnostic explicitly logs
**Impeller opt-out deprecated**. Its active foreground CPU was 1.554473% of
one core in one 40-second window versus the earlier default 1.544876%; no CPU
improvement or statistical difference is established. FrameTimeline still has
zero app-attributed samples. Diagnostic launch, battery, full UI and alert
acceptance are not measured by this comparison.

This identifies a renderer-dependent graphics-accounting candidate, not a
framework-removal benefit or release-wide memory promise. The deprecated
override requires a compatibility decision and matched launch/frame regression
validation before adoption. Retain the pinned default while those facts are
unverified. REA complete inventory has 93 members plus root and zero integrity
contradictions, inspection ID
`ev_d05c438267253996e141629284c01affb22be36cbf8e27300b09b48d19a14aea`;
complete export is `renderer-diagnostic/rea-evidence.json`.

Disconnected acceptance, actual backup/transfer behavior, physical iPhone 16,
production signing and distribution remain release gates. No encryption,
forensic deletion, universal backup prevention or older-backup erasure is claimed.

This report distinguishes source checks, packaged facts, attached physical-device
measurements, and disconnected acceptance. Missing measurements are not passes.
The existing Session 5 implementation and uncommitted work are preserved.

The subsequent [22 October Android acceptance record](ANDROID_ACCEPTANCE_2026_10_22.md)
contains the updated UI's release identities, newly discovered registration race,
fix verification and current device status. Earlier observations below retain
their original source/artifact scope.

## Later UI source update — 22 October 2026

The [current-mode Focus update](../CHANGELOG.md) removes the three-mode selector, enlarges the countdown, and improves large-text fit while retaining the existing timer cycle and manual starts. Its local source verification passed **163 Flutter tests**, including **29 refinement tests**, plus static analysis and formatting. The **38 host-rendered captures**, manifest, and test log are retained under ignored `artifacts/current-mode/`; see [UI verification](UI_VERIFICATION.md).

The package hashes, 157-test result, CI runs, and device measurements in this Session 6 report describe their recorded earlier snapshots. The recorded evidence for the later UI update consists of local Flutter tests, analysis, formatting, and host rendering. Build and record a fresh source/package identity before extending native package, CI, or device evidence to the updated UI.

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
