# Poma test completion ledger

## Owner-ID release candidate continuation

The authorized release implementation prepares `com.jyotirmaysingh.poma`
1.0.0+2007. Baseline core/lockfile inputs are guarded by
`scripts/check_release_scope.py`; About/legal/build changes have focused new
checks. Existing 183 results, 120 launch samples and build-2006 phone scopes
remain closed for their recorded inputs. See RELEASE_CANDIDATE.md for new
artifact receipts and blocked device/signing scopes. A new final-package smoke
test is justified by the changed ID/signing/launch assets; it is not a request
to repeat old-build acceptance or the historical test cohorts.

Updated 22 October 2026. This is the authoritative continuation index. It records existing results; documentation work ran **zero app tests, builds or phone actions**. Read this before planning verification. Detailed raw methods, hashes, tool versions and REA evidence IDs remain in [release evidence](RELEASE_EVIDENCE.md), [Android acceptance](ANDROID_ACCEPTANCE_2026_10_22.md), and the ignored evidence directories below.

## Reuse completed work

Completed rows are closed for their recorded source, artifact and conditions. **Do not rerun them because a new session starts, documentation changes, or an older handoff says “next”, “pending” or “run”.** This ledger supersedes those historical instructions. Do not rebuild/reinstall, reseed 100,000 rows, repeat 120 launches, repeat the renderer diagnostic, or replay passed offline flows by default.

If an implementation, dependency, artifact, OS or test condition later changes, record the concrete change and affected IDs before proposing only the relevant regression checks. A new failure may also justify an affected check. Preserve original evidence and append new results rather than overwriting them. Missing evidence is a separate gap, not permission to repeat a completed flow. Ask for remembered alert details before scheduling any new alert observation.

## Recorded baseline

- Tested draft app source: `2613cbcb552095c5a37573729d2086def3ed81a8`; [successful CI 39729543402](https://github.com/Jyotirmay-Singh/poma/actions/runs/39729543402). Later report-only commits do not invalidate it.
- Before-build working-tree fingerprint: `6ef5bd65b064aa3b58ff9988af2d34aedbd94f7092a0c48e8e312b63d377a011`. Local HEAD `9fa050503f5b63360b2670088138a32c732c1144` alone does not identify the tested uncommitted implementation.
- Canonical optimized ARM64 release build **2006**, development certificate: **18,295,848 bytes (17.45 MiB)**; SHA-256 `6edb098ce0389a6f5c970189e4708a18f703d3678e9dfada78e7d143984baa88`. Immutable local APK: `artifacts/session-8/final/poma-arm64-worker-validation.apk`; installed hash was verified after diagnostics.
- Motorola **moto g54 5G**, Android **15/API 35**. Flutter 3.44.2, Dart 3.12.2, Java 17, Android build tools 36.0.0. iOS results use macOS CI and a simulator; no physical iPhone result is inferred.
- SQLite v3, manual phase starts, one-shot native alerts, local settings/tasks/history. No account, backend or automatic phase chain.

All relative evidence paths below start at `artifacts/session-8/` unless stated otherwise. They are ignored local files, not portable repository links; retain them with this workspace. The committed reports preserve summaries if those files are unavailable. Missing raw files do not by themselves authorize reruns.

## Completed checks and observations

| ID | Status / method | Result and scope | Existing evidence |
| --- | --- | --- | --- |
| AUTO-01 | Host/CI passed | **165 Flutter + 8 Android JVM + 10 Swift simulator = 183 distinct passed tests**, zero failures/skips. Every test name has a stable ID in the [automated inventory](AUTOMATED_TEST_RESULTS.md). Earlier suites and CI repeats overlap; do not add their counts. | `checks/`; preserved JVM XML and hashed input index in `documentation/`; `ci/ios-current/native-tests.log` and summary |
| AUTO-02 | Host passed | Formatting, static analysis, offline enforced lockfile resolution. | `checks/results.json` and named logs |
| BUILD-01 | CI/package verified | Three ABI release APKs, AAB, unsigned iOS device release compilation, simulator compilation; separate development-signed Android copies, signature and 16 KiB alignment checks. Unsigned iOS compilation is not installation. | CI above; `final/`; full artifact table in release evidence |
| SRC-01 | Source/host verified | Production SQL pagination plans and bounded startup/history; summary queries 2→1; optional reads wait behind alert-safety barrier; ticks do not commit SQLite or synchronize alerts; inactive tickers stop; serial native queue ordering/nonblocking caller. Included in AUTO-01, not extra tests. | Named inventory tests; architecture and release evidence |
| PKG-01 | Package verified | REA 6.7.0 complete member inventories/hashes for fresh APKs/AAB/iOS ZIP, zero integrity contradictions; focused manifests/assets/permissions/Mach-O review. No disassembler installed. Static scope only. | `final/rea-*.json`; IDs and tool hashes in release evidence |
| SIZE-01 | Measured / modeled separately | ARM64 17.45 MiB meets ≤20 MiB artifact budget. Bundletool 1.18.3 G54 compressed download estimate **8,415,737 bytes**; actual store size unmeasured. | `final/`; release artifact/estimate table |
| DEV-01 | Device observed, attached | Initial/full strict reset, defaults after ordinary restart, confirmation across expiry, responsive Cancel/Delete, one completion, ready successor. Closes the focused build-2005 ANR regression; finite observations do not prove all races absent. | `worker-reset/`, `worker-strict/` |
| DEV-02 | Device observed, attached | Original PID absent before expiry after ordinary background termination; native generic focus alert posts, one completion after repeated reopen, ready Short break. Manually started break with Settings foreground returns ready Focus, no added focus history. | `worker-delivery/` |
| DEV-03 | Device observed, attached | Locked focus alert posts; after human unlock count 1→2, remains 2 after ordinary restart; Short break ready 1/2. Post-alert keyguard showing/unoccluded, power Dozing; no continuous lock timeline or sound proof. | `worker-locked/`, `worker-locked-recovery/` |
| DEV-04 | Device observed, attached | Large synthetic-history full reset; empty Tasks/Insights and default ready Focus 25 min, 0/4 after restart. Pre-delete total inferred as 100,000 seeded + two completions. No forensic/backup erasure claim. | `large-reset/` |
| PERF-01 | Device measured, attached | **120 valid launches**: 30 cold + 30 warm each for empty/100,000 rows. Initial cold/warm medians 466/365 ms empty, 422/401 ms large; usable medians **504/413 ms**, **481/437 ms**. Both cold medians meet <1.5 s. Warm retains process/recreates Activity; not first-install latency. Raw p95 and conditions preserved. | `worker-launches-v3/` |
| PERF-02 | Device measured, attached | Eight 40 s active/paused/completed/idle foreground/background windows. CPU % one core: active 1.544876/0.007108; paused 0.004525/0.004095; completed 0.004580/0.003624; idle 0.005092/0.006419. Process RSS 170.53–176.47 MiB. Background is Home, not locked. | `worker-traces/` |
| PERF-03 | Device measured, attached | Fresh-process/30-recreation memory probe completed. Fresh PSS/RSS/Graphics 424228/543036/362760 KiB; after 30 plus quiet 418506/540383/363131. Driver accounting differs from process RSS; no leak, memory budget or energy conclusion. | `worker-memory/` |
| DIAG-01 | Supporting diagnostic completed, not promoted | Impeller opt-out reduced observed graphics accounting but is deprecated; three supporting traces establish no CPU benefit or frame p95. Original manifest restored byte-for-byte; canonical release reinstalled/hash verified. Do not use diagnostic memory as canonical release memory. | `renderer-diagnostic/`; diagnostic hash in release evidence |
| PRIV-01 | Source/package reviewed | Bounded 31-file scan, no matching network/log/secret markers; no INTERNET/network-state/wake-lock/foreground-service permission. Packaged legacy/cloud/transfer exclusions cover all nine domains at `.`. Not encryption/universal backup proof. | `worker-review/privacy-refresh.json`; fresh package evidence; [privacy review](PRIVACY_REVIEW.md) |
| PRIV-02 | Dependency review completed within stated scope | 52 selected Maven coordinates accounted for; 23 official POM fetches, 22 direct Apache declarations plus Guava parent inheritance. Full linked notices/native/legal clearance remains open. | `final/package-review/` |
| PRIV-03 | Device observed, connected | 540 s coarse Android UID accounting: no Poma rows, zero reported byte/packet delta. Does not establish packet/DNS/socket-attempt coverage. | `worker-review/current-connected-uid-traffic.json` |
| PRIV-04 | Device observed | Selective backup says **“Backup is not allowed”**; overall command Success is not package-backup success. Does not prove all OEM/transfer/sidecar behavior or erase older backups. | `worker-review/android-backup-request.json` |
| OFF-01 | Operator-reported passed, disconnected | Normal reopening after USB-unplug/airplane/Wi-Fi/data-off instructions; no reported startup gate. Conditions not independently inspected during disconnection. Initial fresh-install opening was online. | `offline-operator/offline-reopen.json` |
| OFF-02 | Operator-reported passed, disconnected | Focus/Short break set to 1 min; Focus completes after 90 s lock, Short break Ready, one added history row. Manually started Short break completes with another app in front, Focus Ready, no extra history. **Do not repeat these flows.** Sound/presentation/actual permission choice were not specified. | `offline-operator/offline-focus-break-confirmation.json`; [offline matrix](OFFLINE_PHONE_RUN.md) |

## Historical results retained, not scheduled again

Sessions 5/6 and the initial UI update contain overlapping 150/157/163-test snapshots and 38 host captures (29 refinement tests are inside the suite). They establish their recorded source/host scopes, not additional current physical-phone coverage. Build 2002–2004 SQLite lock failures and build 2005's 10,004 ms ANR remain failed historical evidence; build 2006's focused repairs/retests above supersede their pending instructions. Do not reinstall an old build to replay them.

Build 2005's exact-access/fallback, force-stop suppression/recovery, notification revocation/settings link, clear-history/task deletion and paused-restart observations retain that older-build scope. They are neither current-build passes nor requests to repeat every case. Launch v1/v2 landscape setup failures yielded no performance samples; v3 completed the required set. The seeder observer timeout was resolved by verifying continued completion, without reseeding.

## Open evidence gaps — never label passed

These are distinct unobserved scopes, not a backlog of completed checks to rerun:

- Offline **initial fresh-install** startup and first-install latency (the actual first opening was online). Existing startup logs may be inspected later without reinstalling/restarting.
- Remaining disconnected task/control/strict/long-cycle/settings/deletion/paused-durability cases listed individually in the offline matrix; PID-proven disconnected process death. Attached passes remain valid as attached evidence.
- Alert appearance, sound, precise latency and delayed-status wording; specific initial notification denial/current-build revocation/exact-access cases. Seek remembered observations first; do not repeat OFF-02 just for omitted details.
- Valid Poma frame attribution/p95 (captured app-frame count was zero), 60 Hz ≤16.67 ms budget comparison; three matched 20-minute unplugged energy windows per comparison. Empty power rails and USB CPU traces cannot supply energy results.
- Force-stop, reboot, manual clock/timezone changes and low-power/OEM suppression with their stated build/OS scopes; nonempty WAL/SHM backup and actual OEM/device transfer.
- Physical iPhone 16 installation/acceptance, metadata/directory backup attributes and transfer behavior. No Mac/paid signing; seven-day personal signing is not the requested lasting distribution. CI Swift tests ran on iPhone 17 Pro simulator/iOS 26.4.1.
- Physical accessibility, complete notices/legal review, production signing, actual store-reported sizes and authorized distribution.

No new testing is scheduled by this documentation update. Preserve raw evidence and use [release gates](RELEASE_CHECKLIST.md) to decide future scope. On a later authorized reconnect, only inspect/clean the existing bounded startup collector after verifying its PID/command, and restore saved radio preferences when offline work is finished; do not kill a reused PID or restart tests to recreate missing logs.
