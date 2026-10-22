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

## Acceptance status

Current revised installation: release-mode ARM64 build **2004**, development
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
| Revised release alert registration | Observed, attached | Five start/resume registrations, no failure banner; no SQLite lock entries in target process log at the supporting sample |
| Strict mode | Pending | Real native clock and SQLite |
| Two-round focus/short/long cycle | Pending | Every successor must remain ready |
| Task edits and original history snapshot | Observed, attached | Rename, complete and reopen synthetic task during focus; original title retained by current focus and resulting history |
| Ordinary process death before expiry | Observed, attached | `am kill` after another app foreground; original PID present then absent before expiry; no force-stop/recents removal |
| Native alert after process death | Observed OS posting, attached | “Focus complete” / “Open Poma when you’re ready.”; no synthetic task title; perceived sound and precise latency unmeasured |
| Exactly-once completion after repeated reopen | Observed, attached | History 2 → 3 after recovery, remains 3 after second process restart; Short break stays ready, progress 1 of 2 |
| Locked screen / another app | Pending | Attached observations labelled separately |
| Notification denial and revocation | Pending | Timer/history correctness independent of presentation |
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

Before this fix, the current-mode source passed 163 Flutter tests and six Android
native tests, locked offline resolution, formatting and analysis in
`artifacts/session-7/checks/`. These checks preceded the concurrency change.

REA 6.7.0 inspected build 2002: 93 ZIP members plus the root occurrence, complete
central-directory inventory, zero integrity contradictions. Complete evidence is
retained in `final/rea-package-evidence.json`; inspection ID
`ev_de33f2fda99fbfaf16de5bbc96153071b4cb84d3c7f3ac881640b48372bb59c2`.
Signatures/alignment were checked separately. No disassembler was installed.
Inventory does not establish runtime scheduling or network behavior.

Build 2004 was also inspected with REA: 93 ZIP members plus root, complete
central-directory inventory, zero integrity contradictions; complete evidence
`final/rea-sequenced-evidence.json`, inspection ID
`ev_f9ad69caf134d90863fc0fc1297edd2371a3b62d2317b4e2912b4d995e5fcbe5`.
Its Android SDK permission inventory declares notifications, scheduled exact
alarms, boot reception, vibration and the protected dynamic receiver permission;
no INTERNET, network-state, app wake-lock or foreground-service permission.
