# Windows Calendar acceptance ledger

Current private-pilot packaging: **Session 10 / 1.0.0.2020**, in the appended
Session 10 record below. See the [pilot release notes](WINDOWS_CALENDAR_PILOT_RELEASE.md)
and [owner's final checklist](WINDOWS_CALENDAR_PILOT_CHECKLIST.md). The Session 9
evidence below retains its original date/source/build scope.

26 October 2026, Asia/Calcutta. This is an evidence ledger for the read-only first
release. **Engineering verification and installed-owner acceptance are separate.**
Synthetic provider checks and an isolated unpackaged runtime are authorized here;
Google setup/consent, installation/signing/trust, Windows settings and real desktop
walkthroughs remain owner gates. No remote event writes are part of this session.

## Identity and evidence rules

Checkout: `D:\pomodoro`, branch `codex/poma-offline-release`, base HEAD
`cb8b1a1e3f5a376b0121ead5328bb51fbcdc5679`, plus preserved uncommitted implementation.
Mobile stays `1.0.0+2007`; Windows verification version is **1.0.0.2017**. Retain
Flutter 3.44.2 / Dart 3.12.2, MSVC v142, Windows SDK 19041 and the locked packages.
Initial support remains Windows 11 25H2 build 26200 x64.

The [Session 9 review](../artifacts/windows/calendar-session9/REVIEW.md) and
[machine record](../artifacts/windows/calendar-session9/review.json) bind source
inputs, lockfile, commands, results, executable/AOT/package hashes, preservation,
privacy inspection and resource measurements. The [review runtime identity](../artifacts/windows/calendar-session9/review-runtime-identity.json)
identifies the separate synthetic entry point. It cannot certify the production
payload. Historical 2009/2011/2016 results retain their original identities.

Use these status meanings: **automated pass**, **isolated runtime observed**,
**owner unrun**, or **blocked with reason**. A successful build, a mocked lock,
an armed deadline or a toast submission is not an installed desktop observation.
Record failures and corrected fixture/tooling attempts alongside final results.

## Automated checks

Prerequisites: use the pinned SDK and local RTK from `RTK.md`, cached dependencies,
the existing C++ tools and Java 17/Android SDK. Tests use fictional data and isolated
stores. These commands run from the repository root; substitute the local RTK
absolute path when it is absent from PATH.

```powershell
rtk proxy powershell -NoProfile -ExecutionPolicy Bypass -File scripts/flutter.ps1 --suppress-analytics --no-version-check test --no-pub --reporter json
rtk proxy powershell -NoProfile -ExecutionPolicy Bypass -File scripts/test_windows_native.ps1
rtk proxy powershell -NoProfile -ExecutionPolicy Bypass -File scripts/test_windows_calendar_config.ps1
rtk proxy powershell -NoProfile -ExecutionPolicy Bypass -File scripts/flutter.ps1 --suppress-analytics --no-version-check analyze --no-pub
rtk proxy C:/flutter/bin/cache/dart-sdk/bin/dart.exe format --output=none --set-exit-if-changed mobile/lib mobile/test mobile/integration_test mobile/tool
rtk git diff --check
```

For a focused reproduction, pass the named test file instead of running the full
suite. The full [Flutter result](../artifacts/windows/calendar-session9/flutter-tests-final.json)
records **302 passing tests**, including ten new cross-component cases. The
unchanged baseline passed 292 tests before adding those cases. Native checks
passed **211**, including actual isolated current-user DPAPI, and configuration
checks passed **11**. These are host/fixture results.

| ID / reproducible scenario | Expected result | Actual observation and evidence |
| --- | --- | --- |
| A01 Offline core during calendar failure: run `calendar_resilience_test.dart`, pending/failed restoration case; hold credential read while creating a task, completing a hidden phase and reading history; then fail the read. | Desktop initialization returns without waiting; tasks/save/history and timer work; exactly one completion, Ready manual successor; sanitized storage error. | Automated pass. New test exercised pending restoration and failure, duplicate deadline reconciliation, two saved tasks and one completion. No foreground ticker remained. |
| A02 Denial, revocation and simulated Testing expiry: run `calendar_connection_test.dart` and `calendar_read_test.dart`; inject denied consent, partial scopes, `invalid_grant`, repeated 401 and offline refresh. | No partial permission access; one forced refresh/replay; unusable grant retired; polling/reminders stop; bounded stale cache stays removable; reconnect is explicit. | Automated pass. Fixtures cover these states, including retirement/restart and same-account selection recovery. `invalid_grant` models expiry handling; it does not prove a real seven-day Google expiry. |
| A03 Secure storage: run connection/resilience tests plus native checks; fail protected read/write/delete, atomic replacement and retirement; retry cleanup/reopen. | No plaintext fallback or enabled access after failed save; original committed data retained; failed deletion visible and retryable; disconnected restart cannot restore the grant. | Automated pass. Native checks use DPAPI, corrupt/cross-profile ciphertext, held files and revision rejection. The new reset-error regression verifies repeated deletion failure and successful retry. Deletion leaves only the non-personal disconnected marker on success. |
| A04 Cleanup interleavings: run `calendar_resilience_test.dart`; hold an event result, formatting result and reminder receipt across each of Disconnect, full reset and account replacement; release them afterward. | Old account cache, rows, tokens/deadlines/receipts and credentials stay cleared; replacement starts with no selection; no browser/notification effect; Disconnect preserves tasks. | Automated pass for all three boundaries. Separate tests hold snapshot writes across each boundary and verify old leases cannot repopulate storage. Full-reset task removal follows the existing controller. |
| A05 Authorization/HTTP cancellation: run connection/read/agenda/reminder tests; delay browser consent, token refresh, authorized response, event page, formatting, receipt and retry sleep; disconnect/reset/Quit. | Generations revoke obsolete effects immediately; transport/backoff stop; no late credential/cache/action restoration. Local reset does not wait for provider revocation. | Automated pass. Existing authorization races and cancellation cases complement the combined Session 9 tests. Real provider/network cancellation remains an owner check. |
| A06 Partial pagination/unavailable sources: run read/resilience tests; return a nonempty first event page then fail the second, update a different source successfully, and remove/downgrade catalog access. | Previous failed-source snapshot and success time survive; other sources update; failed catalog cannot prove absence; verified loss of access removes selection/data. | Automated pass. New test uses the real paginated adapter and captures only GET requests to the fixed Google API host; no event mutation request occurs. |
| A07 Rate limits: run read/resilience tests; inject 429 and rate-limit 403 with seconds and HTTP-date `Retry-After`, repeated manual refresh, network backoff and cancellation. | Bounded retries honor cooldown; manual refresh cannot hammer; ordinary permission 403 does not retry; cancelled waits never restart. | Automated pass, including a new HTTP-date/cancellation case. No live quota pressure was generated. |
| A08 Stale cache/coverage: run read/agenda/reminder tests; fail refresh, advance beyond five minutes and across midnight/timezone boundaries offline. | Saved content has age/coverage and failure state; missing coverage differs from verified empty; expired events trim; stale sources do not remind. | Automated pass. Retention runs resident/on next startup; no expiry service operates after Quit. Reminder receipts prune on saves, not continuously. |
| A09 Recurrence, moved/deleted events and equal titles: run read/agenda/reminder/resilience tests with expanded instances, original-start identities, cancelled/moved occurrences and successful empty replacement. | Source/instance identities survive; moved/deleted entries and old reminder actions disappear after successful refresh; equal titles remain separate. | Automated pass, including adapter pagination followed by moved-instance and empty snapshots. Actual owner-prepared Google events remain unrun. |
| A10 Date/time correctness: run read/agenda tests at start/end/midnight boundaries, New York spring/autumn DST and device-zone changes; include multi-day all-day and declined/tentative events. | Inclusive start/exclusive end; seven local dates can span 167/169 hours; all-day dates never shift and exclusive ends remain exclusive; Now/Next uses actual current time. | Automated pass. Deterministic timezone fixtures are not physical clock/sleep observations. |
| A11 Unsafe URLs/privacy: run agenda/read/native tests and the shared `calendar_links.tsv` corpus; exercise structured/fallback links, stale actions, redaction and failure bodies. | Only explicit validated HTTPS actions; reject unsafe schemes, credentials, deceptive hosts/ports/controls; no refresh launch; no raw response/event text in errors or notification payloads. | Automated pass, including the 41-case shared Dart/native corpus. Package/log inspection is recorded separately below. Narrator speech/real lock remain owner checks. |
| A12 Timer/mobile regression: full Flutter suite plus native Windows and Android compatibility checks. | Strict/stale controls, exact remainder, fixed completion deadline, one completion, sleep/restart recovery and manual successors retain prior contracts. Calendar adapters remain Windows-only. | Flutter: 302 passed; Windows native: 211 passed. Android build/native outcomes and unrun platform checks are bound in the review. No physical mobile or iOS/Xcode result is inferred. |

The first new pagination test incorrectly required the same in-memory snapshot
object after a valid catalog refresh. The assertion was corrected to compare
persisted contents; this was a test expectation error, not a repaired product bug.
The product defect was separate: credential deletion failure during full reset
reported only local-alert cleanup. `reset-defect-before.json` reproduces that
misleading error. Both initial deletion and Retry now report remaining local
data; cleanup stays pending and reconnect disabled until actual deletion succeeds.
Initial script-policy, SDK-cache and restricted DPAPI failures are preserved as
tooling/access attempts. No credential ACL or machine policy was weakened.

## Isolated Windows runtime, resources and package inspection

Reproduction uses the explicit `tool/calendar_session9_review.dart` target. Build
with `--release --no-pub --build-name 1.0.0 --build-number 2017`, copy the complete
Windows Release folder to a fresh workspace `.tools` directory, then run:

```powershell
rtk proxy powershell -NoProfile -ExecutionPolicy Bypass -File scripts/measure_windows_calendar_session9.ps1 -RuntimeDirectory D:/pomodoro/.tools/windows-calendar-session9-runtime
```

Close Poma normally first. The helper refuses an existing profile, requires its
review-only native guard and writes only its adjacent `fictional-review-profile`.
It uses an in-memory Pomodoro database, synthetic authorization/provider data,
real native clock/cache and no Google transport. It does not automate desktop
input or change startup, notification policy, certificate trust or Windows scales.

| Check | Method / expected outcome | Actual evidence and limit |
| --- | --- | --- |
| Launch and ownership | Launch the isolated executable, activate it five more times, require relay exits and the same sole owner; use fictional task and calendar state. | See runtime summary/observations. This covers an unpackaged review profile, not installed Start/COM activation, clean-machine operation or tray-icon counting. |
| Resource baseline | Same executable: disconnected visible/hidden, then 20 fictional events across two selected sources visible/hidden. Settle 30 seconds and sample three times for 30 seconds per condition. | Raw CPU time, percent of one core, working set/private bytes, handles/threads and observed window visibility are in `resource-samples.json`; numeric comparisons are in the review. No performance promise or mobile energy claim follows. |
| Hidden cadence | Another 30-second settling period then twelve 30-second hidden samples, spanning six minutes. Compare request/cache/presentation/deadline counters and ticker state. | Counter deltas and raw samples are retained. Synthetic adapter calls do not measure network packets; storage counters do not replace OS disk tracing, and ticker state does not count rendered frames. |
| Hidden expiry | After resource sampling, start a one-minute focus, stay hidden 70 seconds, then reconcile twice. Separately arm a short native calendar-deadline probe. | Require one original completion identity/deadline, Short break Ready and no ticker; see runtime observations. A native deadline probe is not a delivered meeting reminder/toast. |
| Disconnect/Quit | Disconnect the synthetic account, inspect its isolated calendar subtree, then normal Quit and process exit. | Observed only `calendar/disconnected`, no credentials/account documents, and process exit. The original sampler did not retain the exit code: it remains unknown, with original and corrected metadata summaries preserved. Main Close behavior remains an owner check. |
| Production package | Rebuild normal `lib/main.dart` as 1.0.0.2017 with review controls absent; audit x64 imports, SQLite/CRT, assets/licenses, manifest identity and disabled StartupTask; pack unsigned. | Final package/hash/audit and scanner findings are in the review. No signing/install/upgrade/clean-machine pass is claimed. |

The sampler performs a one-second acknowledgement-file probe equally in each
condition. Background tool activity, host scheduling, cache warmth, synthetic
provider work and instrumentation limit comparisons. Report actual observations;
do not treat lower hidden CPU as a guaranteed saving or isolated samples as a budget.
Android compilation, Flutter tests and static analysis overlapped parts of this
campaign. Visible-window DPI was 120 (125%); one monitor was inventoried with a
1536×864 Windows Forms coordinate rectangle and 1536×840 work area. This is not a
physical mixed-monitor or actual scale-change acceptance pass.

| Condition | Samples | Median CPU, % of one core | Median working set, MiB | Median private bytes, MiB |
| --- | ---: | ---: | ---: | ---: |
| Disconnected visible | 3 × 30 s | 0.781 | 99.61 | 96.84 |
| Disconnected hidden | 3 × 30 s | 0.833 | 25.25 | 99.78 |
| Synthetic calendar visible | 3 × 30 s | 0.781 | 46.65 | 103.09 |
| Synthetic calendar hidden | 3 × 30 s | 0.677 | 40.02 | 96.02 |
| Synthetic calendar hidden, refresh window | 12 × 30 s | 0.651 | 32.41 | 98.48 |

During the six-minute hidden window, counters increased by one calendar-list
read, two event reads, three cache writes and 23 native publications; formatting
did not repeat, and the foreground ticker stayed off. Publications do not count
rendered frames. The separate probe observed two timer deadline callbacks but
one original history completion and one calendar deadline callback. Notification
availability was **unavailable**, as expected without installed MSIX identity.

Inspect the production payload and logs for credential values, authorization
returns, private configuration files and selected synthetic private markers.
Record scanner scope/counts without copying matched sensitive values. Public
OAuth client settings and source field names are not user credentials. License
inspection must include the locked OAuth/HTTP/crypto/timezone texts, Flutter,
SQLite and matching C++ runtime notices. There is no live personal event capture
in this campaign; absence of selected markers is a bounded check, not proof about
all dependencies, OS diagnostics or external backups.

## Owner desktop and live Google checklist — all unrun

Owner prerequisite: Session 10 supplies an identified signed/configured private
pilot and reviewed installation instructions. Use a disposable standard-user
profile/VM and harmless owner-prepared calendar data. Record date, artifact hash,
OS/build, monitors/scales, settings, steps, result and anomaly without credentials
or event text. Coordinate one desktop operator. Restore changed settings afterward.

| ID | Reproducible owner steps | Expected outcome | Actual / gate owner |
| --- | --- | --- | --- |
| O01 Clean launch/offline | Install the identified pilot after certificate review; close development tools, disconnect network, launch from Start in a fresh user profile; open Focus, Tasks, History and Settings. | No runtime download/account dependency; core controls and persistence work. Calendar failure is separate. | **Owner unrun** — owner, Session 10. |
| O02 One instance | Launch repeatedly from Start while main window is visible and hidden; inspect processes/tray, reopen existing window. | One sustained owner/engine/database writer and one tray icon; relays exit. | **Owner unrun** — owner. Isolated relays do not close this installed gate. |
| O03 Explorer recovery | With Poma resident and saved, restart Windows Explorer using Task Manager; activate Poma's restored tray icon. | Tray returns; popup and main remain reachable and agree; timer identity/history survive. | **Owner unrun** — owner. No Explorer restart performed here. |
| O04 Monitors/scales | Record actual available displays/work areas/DPI. Open from tray/overflow and Settings at each available scale, including 200% text; test mixed/negative coordinates, auto-hide and display removal where available. | Popup clamps to the tray monitor work area, scrolls enlarged text and retains reachable focused controls; no unreachable restored window. Record unavailable hardware. | **Owner unrun** — owner. Simulated geometry/text tests are separate. |
| O05 Keyboard/Narrator | Keyboard-only main/tray/popup: Tab/Shift+Tab, Enter/Space, Escape, shortcuts, date browsing and scrolling. Read long Unicode rows/actions with Narrator and high contrast. | Predictable focus, full useful names and source labels; no continuous countdown announcements; no accidental timer/link action. | **Owner unrun** — owner. Accessible trees/native button tests do not prove speech. |
| O06 Close/Quit | Test default first-close explanation and close-to-tray; disable close-to-tray and Close; reopen, start/pause a phase and Quit normally. | Hiding keeps residency; true Quit flushes, cancels calendar jobs/alerts, removes tray/process; reopen preserves saved timer state without replay. | **Owner unrun** — owner. Isolated normal Quit only is separate. |
| O07 Startup off/on | In a clean installed profile confirm startup off; sign out/in. Explicitly enable, sign out/in and observe hidden tray start; disable and repeat. Compare Windows Startup Apps blocked/policy state where possible. | No implicit enabling on Google connection; actual Windows state shown; disabled startup produces no process; enabled starts one resident owner. Full reset disables it. | **Owner unrun** — owner; no startup preference changed here. |
| O08 Hidden timer toast | Allow notifications, start a one-minute focus, hide all Poma windows; observe toast/sound, Open/Dismiss and repeated/stale actions. Repeat alerts off and Windows denial/DND. | One history completion, manual Ready break; generic content; no action starts a phase; policy suppression never blocks timer. | **Owner unrun** — owner; requires installed MSIX identity. |
| O09 Meeting reminders | Explicitly select a harmless calendar, enable reminders/source/lead; hide Poma across a future reminder. Test Open agenda/Dismiss, stale/duplicate action, source deselection and settings changes. | Generic toast, current account/occurrence validation, independent timer cancellation; old jobs/actions revoked. No reminders after Quit. | **Owner unrun** — owner; isolated native probe is insufficient. |
| O10 Lock/sleep/restart | Lock/unlock, suspend/resume and hibernate where supported across a timer deadline and meeting lead. Restart an overdue saved timer; repeat reconciliation. | Calendar details redact on lock/unknown state; at most one completion, original deadline, manual successor; missed meetings skipped without backlog. | **Owner unrun** — owner. Record supported sleep states; simulated recovery is separate. |
| O11 Google denial/revocation/expiry | With owner configuration, personally sign in, deny/partially grant access, reconnect correctly, revoke from Google Account, and refresh. For actual External Testing expiry, record grant age and test after Google's expiry interval. | Safe denial/reconnect state; unusable credentials retired; no authenticated polling/reminders until explicit repair; core app usable. | **Owner unrun** — owner Google setup/consent and elapsed expiry required. |
| O12 Provider/date comparison | Compare owner-prepared recurring exceptions, all-day/DST/midnight, moved/deleted and overlapping events in Google versus Poma, including different calendar/device zones. Explicitly open safe event/meeting links. | Instance/source identity and dates match; successful refresh removes old entries; unsafe links unavailable; refresh alone opens nothing. | **Owner unrun** — owner-prepared harmless data. Poma performs no writes. |
| O13 Account/cleanup | Start a read, disconnect offline, reopen, then connect another account. Separately full-reset a disposable profile; inspect calendar files and request results. Compare remote calendars through Google's UI. | Calendar-derived files/credentials removed; late results rejected; Disconnect preserves tasks/history; full reset clears them; remote events unchanged. | **Owner unrun** — owner. Automated/native/isolated cleanup evidence remains separate. |
| O14 Upgrade/standalone | Back up a closed disposable profile, install higher-version pilot with same identity/certificate, and run without development tools. Verify modules, timer/account persistence, offline restart and recovery guidance. | Complete runtimes/licenses, retained supported data, no build-folder dependencies; honest DPAPI/uninstall/revocation limits. | **Owner unrun** — Session 10 packaging/owner. |

## Session 9 packaging handoff — historical

Session 10 must use this ledger and the latest calendar progress, preserve all
open gates, and produce a higher-version complete private MSIX with the existing
identity/certificate. The Session 9 unsigned artifact is verification evidence.
Owner OAuth configuration is still absent from this campaign. No installation,
public distribution, signing/trust change, new platform support or optional event
writing is authorized by a passing automated row. iOS/Xcode and physical mobile
checks remain unrun for these working-tree changes.

## Session 10 — configured private-pilot packaging and current acceptance

28–29 October 2026, Asia/Calcutta. The owner supplied a matching Desktop-client
download and three-key curated build input under their private Setup directory.
Both files parse and validate; their actual names end in `.json.json`. Configuration
values were not printed or copied into the kit as private setup files.

**Packaging is complete. Installed/live acceptance remains pending.** This is a
reviewable private MSIX, not a public release or a claimed fully accepted pilot.
MSIX is required because the implemented native notification adapter returns
unavailable without installed package identity.

### Exact artifacts and reproduced package checks

- [Complete final kit](../artifacts/windows/Poma-1.0.0.2019-session10-pilot-final-private-pilot-kit.zip),
  **15,983,960 bytes**, SHA-256
  `2945ada6e8379773a5bf101fc5b736d6ef42f50bf8a94269b36136a513005b58`.
  [Adjacent checksum](../artifacts/windows/Poma-1.0.0.2019-session10-pilot-final-private-pilot-kit.zip.sha256).
- [Final signed MSIX](../artifacts/windows/Poma-1.0.0.2019-session10-pilot-final/Poma-1.0.0.2019-x64.msix),
  **15,845,077 bytes**, SHA-256
  `e4655487877719a7db47244e4e2e0ab3a7437e27c823e0465a8529a7bcd3e86b`.
- Final source digest
  `666305d4dcd0c84bf68efc4c171b67d783c88e5032f8f7c6462ee47ec8dec8e4`;
  [inventory](../artifacts/windows/Poma-1.0.0.2019-session10-pilot-final/build-inventory.json).
  Same branch/base and locked Flutter/Dart/native tools as Session 9.
- [Signed 2018 rehearsal](../artifacts/windows/Poma-1.0.0.2018-session10-rehearsal2/Poma-1.0.0.2018-x64.msix),
  SHA-256 `9c788386399a979c3e539d4785b3478fac2124614a9b4f70d7605e6bd651ab4b`.
  Same client/publisher/certificate/identity; install before final only for upgrade.

| Current check | Actual observation / limit |
| --- | --- |
| Configured production builds | Fresh normal-entry-point 2018 and final 2019 Windows release builds passed with one worker. Configuration was compiled, not supplied via SkipBuild. Mobile version remains `1.0.0+2007`. |
| Payload audit | Final signed MSIX has 61 members, 37,906,954 uncompressed bytes; all 56 inventoried payload hashes verified. Thirteen x64 PE files plus x64 AOT, package-local SQLite/CRT, icons, licenses, disabled startup and package/toast identities verified. |
| Kit audit | All 20 loose kit files match the archive. `Verify-Kit.ps1` passed recursive checksums and signer comparison. No installation/trust change is performed by verification. |
| Privacy | Bounded package/loose-kit scan: 80 files, 39,466,962 scanned bytes, no selected token/key/private/review marker findings. Public compiled Desktop client settings are expected. No live event cache was read. |
| Config/syntax/whitespace | 11 configuration cases passed after final packaging changes; PowerShell parsing and whitespace validation passed. |
| Source preservation | All 209 application inputs/lockfile and Session 9 package retain their hashes. Final inventoried inputs match the current source. Packaging/instructions and a new package auditor are the only implementation changes; no new Flutter/mobile campaign was needed or claimed. |
| Signature/trust | Existing owner certificate retained. SignTool processed the package but failed trust verification because the self-signed chain terminates at an untrusted root; exit 1 is **not a trusted-signature pass**. Windows reports UnknownError before trust. No certificate import/install was performed. |
| Settings report | Read-only owner-account query: zero installed Poma packages and zero running processes. No targetable Poma window was present. Owner was given the signed rehearsal installer, certificate/fingerprint and Ctrl+4 instructions. No Settings product defect has been reproduced. |

Reproduce static checks from the workspace after extracting the complete kit:

```powershell
rtk proxy C:/Python311/python.exe scripts/verify_windows_pilot.py artifacts/windows/Poma-1.0.0.2019-session10-pilot-final --version 1.0.0.2019 --kit artifacts/windows/Poma-1.0.0.2019-session10-pilot-final-private-pilot-kit.zip --output artifacts/windows/calendar-session10/recheck.json
rtk proxy powershell -NoProfile -ExecutionPolicy Bypass -File artifacts/windows/Poma-1.0.0.2019-session10-pilot-final/Verify-Kit.ps1
```

Evidence: [final kit audit](../artifacts/windows/calendar-session10/final-kit-audit.json),
[preservation](../artifacts/windows/calendar-session10/source-preservation.json),
[environment](../artifacts/windows/calendar-session10/environment.json),
[kit verification](../artifacts/windows/calendar-session10/kit-verification.log),
[signature trust diagnostic](../artifacts/windows/calendar-session10/signature-chain.log),
[configuration results](../artifacts/windows/calendar-session10/config-check-final.log).
Build/sign logs are adjacent. Initial module-loading and audit-dependency-list
mistakes are retained separately; the final source-matched build supersedes the
intermediate 2019 package. Never install that same-version intermediate package.

### Installed and live checks — not run

| Requested pilot check | Status and next prerequisite |
| --- | --- |
| Standalone installed Start launch; actual installed/module/LocalState paths; notification identity | **Pending owner review/trust/install.** Package metadata alone cannot close O01/O14. |
| Browser authorization/loopback; credential persistence; selected-calendar events | **Pending owner browser login/MFA/consent and explicit test-source choice.** JSON validity does not establish the Google Console audience/API/test-user settings. |
| Tray/one instance/Settings; focus persistence; hidden timer and meeting reminders; Quit | **Pending installed walkthrough.** No uninstalled launch or successful toast submission is substituted for O02/O06/O08/O09. |
| Disconnect preserving Pomodoro, reconnect, 2018 → final 2019 upgrade | **Pending installed rehearsal.** Both signed versions are prepared; no retained-credential/selection pass is inferred. |
| Real offline restart and reconnect | **Pending installed test and owner network isolation.** No Windows network setting changed automatically. |
| Fresh Windows user/clean machine | **Unavailable.** Owner chose current account; no Windows Sandbox, Hyper-V management or VirtualBox tooling found. Fresh Poma-data/clean-machine results are not claimed. |
| Other O01–O14 conditions | All remaining physical Explorer/monitor/scale/Narrator/high-contrast/startup/lock/sleep/DND/denial, Google revocation/seven-day expiry/account/date comparisons remain explicitly open. |

Use [P01–P12](WINDOWS_CALENDAR_PILOT_CHECKLIST.md) for the final operator procedure;
record version/hash for each observed result. O01–O14 historical rows remain
unrun unless a later dated result explicitly closes the applicable subcase.

The kit's INSTALL and release notes document protected credentials, unencrypted
cache, Disconnect, offline revocation limits, manual stopped-profile calendar
cleanup, uninstall/backups and the separate development profile. No remote event
was changed. No public distribution/store upload, signing-service purchase,
machine trust/policy change or optional focus-block writing occurred. Public
Google production/verification, public privacy/support, signing/distribution and
broader hardware gates are separate from this private pilot.

### Installation follow-up — 29 October 2026

The owner attempted the 2018 rehearsal installation and reported publisher
verification failure **0x800B010A**. Read-only normal-user diagnosis confirmed
the package retains SHA-256
`9c788386399a979c3e539d4785b3478fac2124614a9b4f70d7605e6bd651ab4b` and its signer
matches the supplied public certificate. No matching certificate exists in
Current User or Local Machine Trusted People, Root, CA or My. The actual signature
status is UnknownError with an untrusted-root-chain message. The certificate is
within its validity interval. This is an owner certificate-trust prerequisite;
no altered installer or additional signing purchase is indicated by this result.

The owner was given explicit wizard instructions: public CER → Install
Certificate → Local Machine → Place all certificates in the following store →
Browse → Trusted People → Finish, then retry the same MSIX. The owner must
review the signer/fingerprint and approve any administrator prompt. No trust,
security policy, installed application or final immutable kit was changed by
this diagnosis. Installed/live checks remain pending. See
[diagnostic record](../artifacts/windows/calendar-session10/installation-trust-diagnostic-20261029.json).

### Installed rehearsal observations — 29 October 2026

The owner subsequently completed installation and reported attempting Google
connection. The registered package and live process were observed as **2018**,
family `JyotirmaySingh.Poma.Desktop_kz516h6tttq8c`. A later normal Windows app
activation launched the same installed version after no Poma process was running.
Focus and Settings rendered; the Settings navigation click worked. These close
only the current-account installed-launch/path subcases, not O01's clean/offline
environment or the entire desktop checklist.

- Installed executable:
  `C:\Program Files\WindowsApps\JyotirmaySingh.Poma.Desktop_1.0.0.2018_x64__kz516h6tttq8c\poma.exe`.
  All **56 inventoried payload hashes** match the installed files, with zero
  mismatches. The live process loads Flutter, SQLite, notification dependency and
  all three required C++ DLLs from this installed package. No developer-build
  module dependency was observed. See [installed payload audit](../artifacts/windows/calendar-session10/installed-2018-payload.json)
  and [runtime modules](../artifacts/windows/calendar-session10/installed-2018-runtime-after-restart.json).
- Actual current-user data root:
  `C:\Users\JYOTIRMAY\AppData\Local\Packages\JyotirmaySingh.Poma.Desktop_kz516h6tttq8c\LocalState`.
  The real Pomodoro database is present. Aggregate-only inspection found a Ready
  25-minute focus, no tasks/history, no protected Google connection/retired file
  and no calendar account documents at this checkpoint. No credential was
  decrypted or event text captured. [Profile checkpoint](../artifacts/windows/calendar-session10/profile-2018-auth-pending.json).
- Windows now reports **Valid** signature trust. A read-only notifier query for
  `JyotirmaySingh.Poma.Desktop_kz516h6tttq8c!Poma` reports **Enabled**. This confirms
  installed notification capability, not banner/sound/action delivery.
  [Capability record](../artifacts/windows/calendar-session10/installed-2018-notification-capability.json).
- The current cold launch showed **Disconnected**. The prior owner's report of
  Reconnect/Disconnect buttons alone does not establish a committed connection;
  that button pair also appears for successful connections. No persistence defect
  is inferred without first observing a committed successful connection.
- Connect Google was initiated from installed Poma. The app shows Connecting,
  and one owned TCP listener is bound only to IPv4 loopback. The owner was asked
  to complete browser sign-in/consent personally. [Authorization-start record](../artifacts/windows/calendar-session10/installed-2018-authorization-start.json).
  Success, loopback return, credentials, selected-calendar reads and subsequent
  persistence are still pending that actual browser completion.

Normal Quit, tray actions, hidden notification presentation, focus persistence,
upgrade and real offline restart are not yet closed by these observations.

### Connection failure repair and replacement 2020 — 29 October 2026

The owner reported **Google connection offline / saved refresh credentials are
retained** after browser consent on installed 2018. Rechecking its actual
LocalState found no protected credential or calendar account document. The
retention claim was misleading; successful connection/persistence is not proven.
Basic TCP 443 to Google's three hosts passed, and the same Dart 3.12.2 transport
completed unauthenticated TLS/HTTP requests (Calendar returned expected 401).
These checks do not establish the owner's API project settings or the actual
authenticated provider failure code. [Transport evidence](../artifacts/windows/calendar-session10/google-transport-probe.json).

Two isolated regressions failed before the repair:

1. A first connection's network failure claimed saved credentials existed, even
   though there was no committed credential and zero protected writes.
2. HTTP 403/404 refusals of the primary Calendar API identity check were mapped
   to offline. They now produce a distinct safe API-access refusal with project/
   account recovery guidance. No provider body or private value reaches the UI.

The controller now claims retention only when a credential actually exists;
otherwise it states no new connection was saved. No scope, event operation,
database schema, timer rule or dependency changed. Only the authorization
adapter, connection controller and their regression test changed since 2019.
[Before](../artifacts/windows/calendar-session10/connection-defects-before.json),
[connection tests after](../artifacts/windows/calendar-session10/connection-after.json),
[full Flutter output](../artifacts/windows/calendar-session10/flutter-after-connection-fix.json),
[test summary](../artifacts/windows/calendar-session10/connection-fix-test-summary.json),
[analysis](../artifacts/windows/calendar-session10/analysis-connection-fix.log).
**304 Flutter tests and the 28-test connection subset passed**, analysis is clean,
and changed-file formatting/whitespace checks pass. Native/mobile metadata and
lockfile are unchanged; historical native/Android results remain historical.

The replacement **1.0.0.2020** is freshly configured, signed with the same owner
certificate and packaged completely. It supersedes 2019; the old package/ZIP
remain immutable. Current Windows trust is **Valid**. The replacement is **not
installed or live-accepted yet**.

| Artifact / current audit | Exact identity / observation |
| --- | --- |
| [Complete 2020 kit](../artifacts/windows/Poma-1.0.0.2020-session10-pilot-private-pilot-kit.zip) | 15,985,090 bytes; SHA-256 `e9c074c4cf732ab73540e8037eab0ad0f70a26067d0c6d082613ae9cb9152789`; [adjacent checksum](../artifacts/windows/Poma-1.0.0.2020-session10-pilot-private-pilot-kit.zip.sha256). |
| [Signed 2020 MSIX](../artifacts/windows/Poma-1.0.0.2020-session10-pilot/Poma-1.0.0.2020-x64.msix) | 15,845,403 bytes; SHA-256 `92b6bb6084e4c058eee950122aff7a0064d3b9e5777c22996ccd7fd8ad06c35d`. |
| Source inputs | 257 inventoried inputs, digest `e58035d26beda075d36af1ff85c93b81f7da6684bad05aa305b6069319d69a47`; every inventoried input matches. [Preservation](../artifacts/windows/calendar-session10/source-preservation-2020.json). |
| Runtime/payload | All 56 payload hashes verified; 61 signed package members / 37,906,954 uncompressed bytes; same x64 runtimes, identity, disabled startup, public read-only client, icons and licenses. |
| Archive/privacy | All 21 loose files match ZIP; bounded package/kit scan of 81 files / 39,468,057 bytes has no selected findings. [Audit](../artifacts/windows/calendar-session10/kit-2020-audit.json). |
| Kit verification | Recursive checksums/signer match; current signature Valid. [Verification](../artifacts/windows/calendar-session10/kit-2020-verification.log). |

Browser inspection of the Google Cloud API page could not be completed:
Computer Use ended because it could not confidently establish Chrome's current
URL. No further UI input was attempted in that turn. The owner was asked whether
Google Calendar API shows Enable or Manage for the Desktop client's project.
The actual authenticated failure code/cause remains unknown; mock 403/404
reproduction is not substituted for a live diagnosis.

Next: confirm API enablement/account access, Quit and privately back up the
closed profile, upgrade 2018 → 2020 with the same identity/certificate, personally
retry browser consent, require Connected, explicitly select the harmless source,
then finish credential restart, tray/focus/hidden reminders, Quit and real offline
restart. Clean-user/machine and broader hardware/accessibility/policy gates stay
open. See the [current release notes](WINDOWS_CALENDAR_PILOT_RELEASE.md) and
[owner checklist](WINDOWS_CALENDAR_PILOT_CHECKLIST.md). No event write, trust/policy
change by the agent, public publication or optional focus-block work occurred.

## Session 12 — implementation verification

3 November 2026. Final automated verification: **414 Flutter tests passed**,
**230 native checks passed**, **1 Windows production integration passed**,
**11 build-configuration checks passed**, and static analysis is clean. The
Windows integration used an isolated fictional development profile and restored
the original hashes. These are not installed/live Google acceptance claims.
Current evidence, failures corrected during verification, artifact identities and
open L01-L05 gates are in [the Session 12 ledger](WINDOWS_CALENDAR_SESSION12.md).
All earlier results above retain their stated build/source identity.

Final native account-replacement follow-up: **233 native checks passed**; the
new barrier rejects queued old-account focus saves before Dart publishes the
replacement identity. Final private candidate 2022 is signed and statically
audited. Installed launch/runtime/reader observations belong to intermediate
2021 only; live consent, mutation, reversal and recovery remain pending.
