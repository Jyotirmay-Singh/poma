# Android acceptance — current-mode UI

This record continues Session 6 on the Motorola moto g54 5G, Android 15/API 35.
All observations below apply only to the identified installation. USB-attached
checks do not establish physically disconnected acceptance. Missing observations
remain unverified.

## Build identity

Source HEAD: `9fa050503f5b63360b2670088138a32c732c1144`. Before-build working-tree
fingerprint: `1c0125f57d7bbc6759a26bef1c86ea5b50910a862c643b7de47ab4dd927c46fc`.
Four existing documentation edits were preserved. Full source manifest, scoped
device conditions and raw evidence are retained under ignored
`artifacts/session-7/`. Device identifiers and generated evidence are not public
source files.

The current-mode source previously passed 163 Flutter tests, analysis and
formatting. The older Session 6 launch, CPU, package and CI observations retain
their original identities; they are not measurements of the updated UI.

## Session 8: reset hang under repair

Physical acceptance of build 2005 later failed: Android displayed “Poma isn't
responding” while a full-reset confirmation was open during a strict phase.
Android recorded an input-dispatch timeout waiting 10,004 ms for a MotionEvent.
No target SQLite error line was captured at that point; the target backtrace
request returned no usable stdout. This establishes a hang, not a fully sampled
root-cause stack. Full reset has **not passed**.

Source inspection identified native SQLite/journal operations on the platform
thread, including receivers, which can contend with sqflite work needing that
thread for replies. The pending revision moves bridge and receiver work to one
serial blocking work queue, uses `goAsync()`/`finish()` for receiver lifetime, and
posts Flutter event notifications back to the platform thread. It adds no timer
polling, foreground service, wake lock or automatic successor start. New native
regressions model a blocked read whose completion needs the caller and verify
serial ordering. Checks and physical retests are pending under
`artifacts/session-8/`. Earlier CI results and package hashes do not cover it.

## Earlier native-connection revision

Build **2005**, optimized ARM64, validation development certificate, is
**18,295,848 bytes (17.45 MiB)**; SHA-256
`043cd518b90b45797d490f5e394678171f2a2970550ae6f7c379c0e0ebf5c47f`.
Before-build source fingerprint:
`07147586aa0f482c90ae66ee9b864e17ae6e53afa0107ff5bb05c5a2117f788d`.
The signed copy passed signature and 16 KiB alignment verification. ARM64
artifact size passes the provisional 20 MiB budget; store sizes are unmeasured.
Other ABI/AAB results from Session 6 remain historical, not refreshed builds.

All **165 Flutter tests and six native tests**, formatting, analysis and locked
offline dependency resolution passed in `checks-native-cache/`. No public API,
SQLite schema, automatic chain, account or backend was introduced. Draft branch
source commit: `ea3b6c6b0fc4ec424cf32a146599d74ef1b7fcc4`; a separate CI workflow
was dispatched for it: [run 39719244904](https://github.com/Jyotirmay-Singh/poma/actions/runs/39719244904).
The preceding shared-Dart revision passed Android and iOS CI in run 39717780053.
Physical retests are retained under `native-cache/`.

| Current build 2005 check | Observed status |
| --- | --- |
| Five start/resume registrations | Passed, attached |
| Another app then return during active phase | Passed, attached; no registration error |
| Effective exact-access revocation | UID mode ignore/package default recorded; running focus restored with explicit delayed availability; pause/reset work |
| Target-process SQLite errors after those cases | Zero matching SQLite-error lines in the scoped supporting sample; not proof against every possible race |
| Inexact delivery timing | Unmeasured; registration/fallback availability is distinct from actual delivery |
| Ordinary process kill and exactly-once recovery | Passed, attached; PID absent before expiry, generic native focus alert posted; history 6 → 7 and remains 7 after second process restart; Short break stays ready, 1 of 2 |
| Locked short-break alert | Posted while keyguard showing/asleep; recovered ready Focus, history remains 7 |
| Force-stop | No alert posted; history 7 → 8 and remains 8 on second reopen; Long break ready |
| Notification revocation / settings link | Denial shown during active focus; actual system settings link opened; no alert; history 8 → 9; grant reflected after Back to app |
| Clear history / task delete / paused restart | Observed; history cleared while task/settings retained, task deleted, paused remaining survived ordinary process death |
| Full reset | FAILED — subsequent input-dispatch ANR; not accepted |
| Disconnected matrix | Unverified |

REA 6.7.0 inventoried 93 ZIP members plus the root, with complete
central-directory coverage and zero integrity contradictions. Inspection ID:
`ev_c21ae554bbc6cd97969606d836859bf777f90151a373be29fddfe0788f49bed5`;
complete export `final/rea-native-cache-evidence.json`, member hashes also in
`final/native-cache-archive-members.json`. Static inventory is not execution,
energy or delivery proof. No disassembler was installed.

The refreshed 30-file source-pattern review has no network/log/secret-marker
hits in its bounded scope. SDK permission inventory and packaged notices are
retained in `native-cache/privacy-refresh.json`. License, backup/transfer,
encryption and traffic limitations from the earlier review still apply.

## Earlier build 2002–2004 acceptance observations

Earlier revised installation: release-mode ARM64 build **2004**, development
certificate, **18,295,848 bytes (17.45 MiB)**, SHA-256
`6f1ed66b56bac9c579cfae1447a21bca8d048e6269e8ee079049f894eec8f86d`.
Source fingerprint before the sequencing build:
`ac2b586ff3c94a5c7258cf145e7e012ed82ed19cabe3fd960ee113586a9b4901`.
The APK passes the provisional 20 MiB ARM64 artifact budget. Its store/bundle
download estimate, new launch samples, app frame timings and energy remain
unmeasured; older estimates/measurements are not substituted.

Final revised-source checks in `checks-sequenced/`: **165 Flutter tests and six
Android native tests passed**, formatting, analysis and offline enforced lockfile
resolution passed. Native JVM source was unchanged. No current iOS build result
is inferred for this later shared-Dart change.

| Scenario | Status | Evidence / boundary |
| --- | --- | --- |
| Release update preserves local data | Observed, attached | Build 2002 preserved two-minute focus, selected task, dark theme, three-round setting and empty history |
| Focus controls | Observed, attached | Start, pause, resume, reset and skip for focus and short break; no history from abandoned phases |
| Build 2004 alert registration | Failed in later lifecycle case | Five start/resume registrations initially passed; later start/re-entry reproduced native SQLite lock. Five-pass sample is not complete acceptance |
| Strict mode | Observed, attached | Short break uses locked In progress control; reset/skip, timing edits and disabling strict are unavailable while active; appearance remains editable |
| Two-round focus/short/long cycle | Observed, attached | Short break → ready Focus, final focus → ready Long break directly, long break → ready Focus with 0 of 2; every start manual; breaks add no focus history |
| Task edits and original history snapshot | Observed, attached | Rename, complete and reopen synthetic task during focus; original title retained by current focus and resulting history |
| Ordinary process death before expiry | Observed, attached | `am kill` after another app foreground; original PID present then absent before expiry; no force-stop/recents removal |
| Native alert after process death | Observed OS posting, attached | “Focus complete” / “Open Poma when you’re ready.”; no synthetic task title; perceived sound and precise latency unmeasured |
| Exactly-once completion after repeated reopen | Observed, attached | History 2 → 3 after recovery, remains 3 after second process restart; Short break stays ready, progress 1 of 2 |
| Another app foreground across focus expiry | Observed, attached | OS posted generic focus alert, final focus prepared ready Long break directly; history 3 → 4 |
| Locked screen | Observed OS posting and recovery, attached | Keyguard showing, unoccluded, screen asleep; generic break alert posted; human unlocked; ready Focus, 0 of 2, history remains 4; sound/precise latency unmeasured |
| Notification revocation and later grant | Observed, attached | Permission revoked during started focus; denial message/settings link shown; no OS notification record after expiry; history 4 → 5 and ready Short break; grant reflected after return. Initial permission-dialog denial remains separate |
| Exact-alarm revocation and fallback | Pending | OS can cancel alarms/kill process on revocation |
| Clear history / full reset / restart | Pending | Synthetic data only |
| Physically disconnected offline matrix | Unverified | Requires operator unplugging and phone-only observations |
| Force-stop, reboot, clock/timezone changes | Unverified | Separate Android restriction scenarios |
| Low-power / Doze / OEM suppression | Unverified | No universal delivery guarantee |
| Backup sidecars / actual transfer | Unverified | Earlier selective backup rejection has narrower scope |
| TalkBack, landscape and 200% phone text | Unverified | Host rendering does not establish phone accessibility |

## Remaining measurement boundaries

The current package requires its own artifact hash, inventory and size. Full
launch sampling, app-attributed frame timings, fresh-process RSS and CPU state
comparisons must be bound to that package. Three matched 20-minute unplugged
energy windows per comparison remain unmeasured. Neither attached USB traces nor
battery percentages establish energy efficiency. Production signing, actual
store sizes and physical iPhone 16 evidence remain separate release gates.

## Failure found by physical acceptance

Build 2002 (18,295,848 bytes, SHA-256
`ea3769e9d24c2905f4f432e3ef0f9ffc7538826976c5af75f96f7ccc931720c7`)
showed intermittent completion-alert registration failure on focus and short
break start/resume. Target-process Android logs identify
`SQLiteDatabaseLockedException`, `SQLITE_BUSY`, compiling `PRAGMA journal_mode`
while the native adapter opens the shared database. A later start succeeded with
the explicitly delayed/inexact availability; this is an intermittent race, not
a universal scheduling failure.

The three read-only repository transactions (startup snapshot, history page,
day summaries) previously used the same exclusive mode as writes. Their revised
policy retains consistent transactions with `exclusive: false`; mutations remain
exclusive and the database schema is unchanged. A regression holds an exclusive
read transaction and observes a second connection's journal read fail, then
checks the actual three production read operations with the same probe. The
phone retest of build 2003 reproduced the same lock: the read-mode change alone
was insufficient. Build 2003 is 18,295,848 bytes, SHA-256
`22547c3f3f12d309339a355ee748efe4dfffa6f29a99809f5be0cb1a5fcf50ab`.

The follow-up sequences optional refreshes after the native alert safety barrier,
including the refresh previously started by a successful save. Read results are
still asynchronous and do not block painting the running timer. Host regressions
assert zero optional reads while native initialization/synchronization is held,
then one coalesced refresh after it completes, alongside unchanged tick/write and
inactive-ticker checks. This follow-up requires another physical release retest;
no delivery or battery improvement is inferred from the host tests.

Build 2004 subsequently reproduced `SQLiteDatabaseLockedException` during a
later lifecycle/permission probe. The read-mode and sequencing changes alone do
not fully resolve native connection setup contention. The next native revision
opens one SQLite handle during configuration and reuses it for state/receipt
operations throughout that process, rather than repeatedly running Android's
connection journal setup. It retains no Activity context, adds no polling or
scheduled background work, and closes/replaces the handle if the configured path
changes. A custom corruption callback preserves the database instead of invoking
Android's default file-deleting handler. Physical verification is pending.

The interrupted exact-access probe set a package app-op to ignore while an
allowed UID app-op remained. It does **not** establish effective revocation or
fallback behavior. The next probe must change/record the effective UID operation.

Before this fix, the current-mode source passed 163 Flutter tests and six Android
native tests, locked offline resolution, formatting and analysis in
`artifacts/session-7/checks/`. These checks preceded the concurrency change.

REA 6.7.0 inspected build 2002: 93 ZIP members plus the root occurrence, complete
central-directory inventory, zero integrity contradictions. Complete evidence is
retained in `final/rea-package-evidence.json`; inspection ID
`ev_de33f2fda99fbfaf16de5bbc96153071b4cb84d3c7f3ac881640b48372bb59c2`.
Signatures/alignment were checked separately. No disassembler was installed.
Inventory does not establish runtime scheduling or network behavior.

The approved draft branch was updated to
`978dba75f1519b7f6c8464cb284805c13efe03b4`, preserving local HEAD/index and
existing edits. [CI run 39717780053](https://github.com/Jyotirmay-Singh/poma/actions/runs/39717780053)
was explicitly dispatched; results are pending. [Draft PR #1](https://github.com/Jyotirmay-Singh/poma/pull/1)
remains open and unmerged. Generated evidence and credentials were excluded.

Build 2004 was also inspected with REA: 93 ZIP members plus root, complete
central-directory inventory, zero integrity contradictions; complete evidence
`final/rea-sequenced-evidence.json`, inspection ID
`ev_f9ad69caf134d90863fc0fc1297edd2371a3b62d2317b4e2912b4d995e5fcbe5`.
Its Android SDK permission inventory declares notifications, scheduled exact
alarms, boot reception, vibration and the protected dynamic receiver permission;
no INTERNET, network-state, app wake-lock or foreground-service permission.

The refreshed bounded source review examined 30 production Dart/Kotlin/Swift
files and found no matches for its network-API/URL, app-log-call or secret-marker
patterns (`privacy-refresh.json`). This is a pattern review, not whole-program
proof. Packaged notices remain present. Dependencies/versions were not changed;
the earlier network-capable transitive dependency and unresolved native-license
clearance remain documented in PRIVACY_REVIEW.md.

The installed build 2004 selective non-incremental backup probe returned
“Package dev.poma.poma with result: Backup is not allowed.” The overall command
also prints “Success”; that does not mean the package was backed up. This is
current selective eligibility only, not all OEM/cloud/transfer paths, nonempty
SQLite sidecar behavior or erasure of older backups.
