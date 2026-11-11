# Day Clock progress

## Windows planner implementation, 11 November 2026

Implementation builds on the uncommitted Day Clock repair. The current product
contract is the owner's shared Windows planner request. SQLite v4 adds durable
task schedules, operation identities, account preferences, raw editor drafts and
occurrence completion. The ordinary writer supports owned-calendar creation,
conditional updates, deletion and scoped recurrence. The new shared planner
connects Tasks, Calendar and Day Clock through one Save workflow.

Current acceptance, exact toolchain, rendered fictional examples, package
identity and remaining installed/live checks are recorded in
[WINDOWS_PLANNER_VERIFICATION.md](WINDOWS_PLANNER_VERIFICATION.md). Earlier
Session 1–3 and repair results below retain their original scope and dates.

The resumed source passes 879 Flutter regressions, clean analysis and all four
native executables with 331 assertions. Installed 2032 completed live one-off
creation, rename, completion, delayed deletion Undo, recurring occurrence/series
edits, occurrence completion and cleanup. All temporary Google events and Tasks
are cleared and scheduled-task syncing is Off again. The original task, history,
settings and complete stored-timer fingerprints match after cleanup. Build
1.0.0.2033 is installed with seven profile files preserved and 80 installed
payloads verified. It includes fresh-version deletion recovery, clock DST gesture
corrections and deadline-bound deletion Undo notices. Final installed/live and
Narrator acceptance remain pending after the user stopped computer control.

## Approved repair — 10 November 2026

The owner approved the inspected repair plan. The Day Clock now provides a reviewed
default-on save/show choice, one guarded account-scoped reveal action and a persistent
saved-event receipt. The desktop layout uses available width and height, with a
complete dial and a scrolling agenda; narrow/enlarged-text layouts remain readable.

Fresh evidence: **809 Flutter tests passed**, including **100 new repair cases**;
analysis is clean; affected-file formatting is clean; native checks passed **4/4
executables / 331 assertions**. Matching five-event before/after captures cover the
four requested window sizes; **307 current PNGs** and four controlled before PNGs
passed integrity checks. The configured **1.0.0.2029** Release candidate compiled,
has a **Valid** retained signature and passed its **76-payload** package audit.

Source/package identity, screenshots and results are in
[DAY_CLOCK_REPAIR_VERIFICATION.md](DAY_CLOCK_REPAIR_VERIFICATION.md). The owner then
authorized installation and sync testing: **1.0.0.2029 is installed**, status Ok,
with all 76 payloads verified and all 7 profile files unchanged before first launch.
After testing, task/history/settings/full timer fingerprints still match the
private backup; restart retains paused **24:59, 0/4 rounds**.

Live Google read/reveal passed for **both existing saved events**, including their
different dates, exact saved endpoints, highlighted sectors and selected agenda
rows. Manual refresh preserved browsing/selection; the shared Calendar view showed
both events. The full dial fits actual normal 1067×754 and maximized 1536×840
windows. The owner chose **Test existing events only**: no Google event was created,
edited or deleted, and new-event creation was not live-tested. No external
publication was performed. Private-safe receipts are under
`artifacts/day-clock/repair/installed/`.

The entries below retain their original Session 1–3 evidence and dates.

## Committed source and authorized local update — 10 November 2026

Sessions 1–3 were committed and pushed to `origin/main` as
[`f9c849f74fc770c51b2ca5f1f7feb383a12125ef`](https://github.com/Jyotirmay-Singh/poma/commit/f9c849f74fc770c51b2ca5f1f7feb383a12125ef).
The owner then explicitly approved updating the locally present Poma for testing.
The installed **1.0.0.2027** package was updated in place to **1.0.0.2028**, built
from that commit using a local version override and the existing Calendar
configuration/signer. No runtime source or source package version was changed.

- Configured Release compilation passed in **70.1s**; MSIX signature **Valid**.
  The package audit verified **76 payload hashes** with no selected privacy-scan
  findings. Installer SHA-256:
  `b8245b8e6511ed0678fd940cfeaf941c6f7fb8a65421e3ce9fe7d246472d54f2`.
- A closed-profile backup preceded installation. **Five profile files** matched
  before first launch; **76 installed payload files** matched the package and
  installed status was **Ok**. After testing, database fingerprints for tasks,
  sessions, settings and the complete stored timer matched the backup exactly.
- Observed installed behavior: six navigation shortcuts using right-Control;
  PM/future-date browsing retained across navigation; Now restores current AM
  and the hand; wide/normal layouts and form/page scrolling; Enter/Tab/ordinary
  key entry; Escape returns focus to Add task. Existing Focus remained paused
  at **24:59**, 0/4 rounds, and the original window size/Focus page was restored.
- Entered fictional `plan` on **11 November 2026, 10–11 PM**. Check task showed
  **60 minutes**, India Standard Time and **UTC+05:30 at both endpoints**.
  Expired access was reported consistently in Calendar/Day Clock; availability
  stayed unknown, fields remained intact and Google Save stayed unavailable.
  No reconnection, consent change, kept draft or Google event was submitted.
- Live disposable-calendar save/readback and installed failure/recovery remain
  **pending**. Actual notifications/tray, DPI/sleep-resume, physical keyboard and
  assistive acceptance were not established. No publishing was performed.

The [local application verification](DAY_CLOCK_VERIFICATION.md#local-application-follow-up--10-november-2026)
records the observed boundaries and
[separate package/evidence hashes](../artifacts/day-clock/session3/local-app/evidence-manifest.json).
Representative unmodified installed captures:
[PM browsing](../artifacts/day-clock/session3/local-app/screenshots/installed-pm-browsing.jpg),
[Now](../artifacts/day-clock/session3/local-app/screenshots/installed-following-now.jpg),
[preserved Focus](../artifacts/day-clock/session3/local-app/screenshots/installed-focus-preserved.jpg).
The fictional-account form and Saved captures remain in the Session 3 evidence
below. Historical source-only results and the original unconfigured 2007 runtime
receipt are retained; the configured 2028 build reused the build output path.

## Session 3 — final refinement and verification — 9–10 November 2026

Status: **Session 3 complete in source, deterministically verified and compiled;
ready for review.** The owner approved the final plan and selected fictional test
data only. At source completion, live Google, installed-app and physical
assistive acceptance were pending. No installation, publication, Google
configuration or personal-calendar testing was performed in that source-only
stage; the later authorized installed checks are recorded above.
The full scenario matrix, actual Flutter screens and
acceptance boundaries are in [Day Clock verification](DAY_CLOCK_VERIFICATION.md).

- Re-read repository instructions, the feature/plan/progress/visual/design-system
  documents and current production/controller/test sources. Inspected actual
  ordinary, dense, high-contrast, form and Saved Flutter captures against the
  selected concept.
- Verified all Session 2 manifest hashes: 168 inputs, 44 runtime files, 18 PNGs
  and five logs match. Fresh baseline: **116 focused tests passed in 1m 20s**,
  including four real-process exit/recovery cases. These are baseline results,
  not final Session 3 acceptance.
- Implemented refinements: measured numeral/sector geometry shared with
  hit testing; separate static/hand repaint boundaries; compact healthy status;
  quiet agenda dividers with focus/selection outlines; reduced-motion dialog and
  explicit focus restoration; one immutable Saved summary. Late outcome checking
  is also guarded against changed draft/account/lifecycle authority.
- Final expanded feature run: **168 tests passed in 1m 49s**, including actual
  form-field/double-click/timeout readback, visible focus recovery from a scrolled
  dial, static-layer retention, 24 creation appearances and the four real-process
  exit/recovery boundaries. Native checks passed **4/4 executables, 331 assertions**.
  Formatting checked **134 Dart files, 0 changes**. The final results below
  supersede this milestone and other intermediate runs.
- The complete suite passed **709 tests** (52 more than Session 2). Review also
  caught persisted Saved notices surviving successful Show calendar/refresh;
  targeted regression assertions demonstrated the issue, and current-reader
  notices now clear after recovery. Enlarged validation captions now wrap without
  ellipsis, verified from rendered text. The replacement complete run passed
  **709 tests in 3m 15s**, with clean analysis (**17.1s**) and formatting
  (**134 files, 0 changes**). Viewing/creation captures were regenerated into
  separate folders to avoid shared form filenames colliding; intermediate PNGs
  were preserved in the ignored evidence directory. The final **168-test** feature
  rerun passed in **1m 35s**, produced **284 PNGs**, and used the same final Dart
  source as the complete suite and build. Representative renders were inspected
  again, including complete enlarged error captions and the Saved 10–11 PM result.

### Final Session 3 evidence

Counts from overlapping runs are not additive. All data in the captures and
provider observations is fictional; compilation is separate from installation.

| Check | Final observed result | Evidence |
| --- | --- | --- |
| Complete Flutter regressions | **709 passed**, 3m 15s; **52 additional Session 3 cases** | [Full log](../artifacts/day-clock/session3/flutter-final.log) |
| Final feature/capture suite | **168 passed**, 1m 35s; includes four real-process exits | [Feature log](../artifacts/day-clock/session3/captures-final.log) |
| Static analysis | **No issues**, 17.1s | [Analysis](../artifacts/day-clock/session3/analysis-verified.log) |
| Formatting | **134 files checked, 0 changes**, 0.98s | [Formatting](../artifacts/day-clock/session3/format-final.log) |
| Windows native checks | **4/4 executables, 331 assertions**: 248 desktop, 43 font, 15 audio guard, 25 mobile safety | [Native log](../artifacts/day-clock/session3/native-tests.log) |
| Windows Release compilation | **Passed**, 77.7s; lib/main.dart; unconfigured | [Build log](../artifacts/day-clock/session3/windows-final.log) |
| Actual Flutter visual evidence | **284 PNGs**: 129 creation, 155 viewing; all chunk checksums valid | [Final gallery](../artifacts/day-clock/session3/screenshots/) |
| Source/evidence integrity | Source/runtime/capture/documentation hashes and final-capture provenance recorded; local links audited | [Manifest](../artifacts/day-clock/session3/verification-manifest.json), [audit](../artifacts/day-clock/session3/final-audit.json) |

The actual-pointer acceptance case double-clicks Save with a timeout after the
fictional provider commits: **one event**, exact **22:00–23:00 / UTC+05:30**
endpoints (**16:30Z–17:30Z**), **60 minutes**, correct title/owned destination,
**one 600–660-minute PM sector** and **one shared-reader agenda entry**. Both an
explicit Google colour and calendar-default fallback pass. Recovery tests retain
the original event ID and truthful Saved/unknown states; restored access does not
replay a draft or retain an obsolete hidden/refresh warning.

### Source and build identity

- Base commit: `c3625a68774f0478146f4abb84e5b039d52465f9`; all existing work
  was preserved. Sessions 1–3 were uncommitted during these runs and were later
  committed/pushed as recorded above.
- Flutter **3.44.2**, Dart **3.12.2**, framework
  `c9a6c484230f8b5e408ec57be1ef71dee1e77020`.
- The manifest inventories **205 source/test/native/asset/workflow inputs** and
  **44 runtime files**. Source-input set SHA-256:
  `c4c5704e3072585ae137b07557338b9ebeb32ab4cc4e2686b64445016dfb83ce`.
- Release executable: mobile/build/windows/x64/runner/Release/poma.exe; verified
  file version **1.0.0.2007**; SHA-256
  `bf3d74c7a2928d5e8b9f49d15a9b4bb910404257ada3ed4669d8e23c59ce8e93`.
- Compiled data/app.so SHA-256:
  `21aad6f36b54fdad1f1d02065efd2f5bd23f22402073449f967b8789d9a7254d`.
  The native runner is unchanged; this Dart image identifies the new UI build.
- No private Google defines were supplied. This compilation does not replace
  installed 1.0.0.2027, modify its profile or establish live Google acceptance.

Session 3 changed the dial/screen/form and the two Day Clock/creation controllers,
extended four existing test/support files and added day_clock_completion_test.dart
and the repeatable evidence recorder. Nine existing Session 2 input hashes changed
as expected; the remaining **159** match, including focus writer/ownership,
shared reader, authorization/consent, native runner, fonts and dependencies.
There is no new permission, runtime dependency or persistence migration.

### Representative final renders

These are production Flutter components/fonts with fictional providers, not
installed-app or live-account screenshots.

- [Ordinary wide clock](../artifacts/day-clock/session3/screenshots/viewing/ordinary-1440-100-dark.png)
- [Dense high contrast / 200%](../artifacts/day-clock/session3/screenshots/viewing/finished-dense-640-200-dark-contrast.png)
- [Reviewed creation form](../artifacts/day-clock/session3/screenshots/creation/gesture-reviewed-colour.png)
- [Saved immutable result](../artifacts/day-clock/session3/screenshots/creation/gesture-saved-colour.png)
- [One 10–11 PM sector and agenda entry](../artifacts/day-clock/session3/screenshots/creation/gesture-clock-colour.png)
- [Narrow Saved / 200%](../artifacts/day-clock/session3/screenshots/creation/saved-640-200-dark-bottom.png)
- [Enlarged error recovery](../artifacts/day-clock/session3/screenshots/viewing/finished-form-error-1080-150-dark-contrast.png)

### Remaining acceptance

Live Poma OAuth/consent and disposable-calendar create/readback, physical
Narrator/assistive operation, actual system DPI and sleep/resume, and real
notification/tray observations remain **pending**. Basic configured-package
installation and UI checks were subsequently observed as recorded above.
The automated regressions and native checks support the remaining acceptance
steps without claiming them. Publishing remains separate. Existing
owned-calendar, seven-date coverage and custom label-colour limitations are
recorded in the verification report.

## Session 2 — Google creation integration — 9 November 2026

Status: **Session 2 complete in source, tested and compiled.** The owner approved
the plan after inspecting the actual uncommitted Session 1 working tree.
No installed Poma profile, live Google account, consent grant or personal calendar
has been modified. Poma's own configured Desktop flow is the production route.

### Implemented behavior

- Separate owned-calendar creation capability using `calendar.events.owned`;
  exact full-set Desktop upgrades and backward-compatible capability receipts
  preserve independently enabled focus scheduling. The existing focus writer's
  provenance, app-created calendar and focus-event checks remain intact.
- Creation-only Google adapter with fresh owner-role checks, ordinary timed
  events, Busy/Free, supported palette IDs and label version 0. Exact offset-
  qualified endpoints avoid treating a Windows timezone name as an IANA name.
  Visibility/reminders follow calendar defaults; no attendees or recurrence.
- Independent native creation journal/leases under the same calendar storage
  owner, account-bound kept drafts, immutable reviewed operations, stable valid
  `pomadc` IDs and private markers distinct from focus ownership. Local calendar
  data remains unencrypted; credentials/receipts use the existing DPAPI storage.
- Add task form connected to consent, final confirmation, checking and explicit
  same-ID retry. Raw fields survive decline/recoverable failure. Keep draft and
  consent persist forms; no startup/connectivity callback sends them.
- Shared-reader post-save refresh waits for any pre-insert refresh. Drafts and
  pending journal entries never become sectors. Saved results retain validated
  Google links, hidden-calendar actions and honest out-of-window/refresh notices.
- Now/Next empty summaries and clock gaps now distinguish incomplete/unverified
  coverage from known empty time. Session 1's visual structure is retained.

### Activity and verification history

- Inspected baseline: **73** projection, consent, focus-writer and reader tests
  passed before implementation. Public Google discovery confirms the owned
  insertion scope and label-version/colorId semantics.
- Native checks: **4/4 executables passed**, including **248 desktop assertions**
  (15 new creation-storage checks), 43 font, 15 audio guard and 25 mobile safety
  host assertions. Evidence: `artifacts/day-clock/session2/native-tests.log`.
- Initial integrated run completed the core creation/consent tests and all four
  genuine child-process exit boundaries (kept draft, Sending, server committed,
  acknowledgement). Its widget fixture stalled before rendering; the mixed
  real/simulated-time setup was corrected and the run was stopped rather than
  recorded as a complete pass. Final results below will supersede this run.
- The next widget run exposed a fixture completion/timer issue. Lifecycle setup
  and the actual bound final-action callback now run in the fixture's real async
  context; production submit logic was not weakened. The focused run then passed
  **50 tests** and produced the first 18 integration captures.
- Visual review corrected the fictional regional formatter so captured agenda
  times match the displayed IST zone, made frozen saved values readable and
  excluded the newly saved event from its own overlap advisory. Added final-
  preflight time verification, HTTP Gone/tombstone protection, lost-acknowledgement
  recovery, disconnect-during-send and cancel-during-credential-commit coverage.
- Source analysis found no issues. The first **complete Flutter suite passed
  657 tests in 2m 30s**, including **58 new Session 2 tests** and existing focus,
  reader, timer, task/history, mobile/offline and real-process recovery regressions.
- The first Windows Release compilation passed in **62.6 seconds**. No private Google
  build defines were supplied. No installation or publication was performed.
- Final capture review found that kept-draft status could replace a declined-
  consent explanation. Corrected message precedence, added a visible-explanation
  assertion and repeated final analysis, the full suite and Release compilation.
  The replacement **657-test suite passed in 2m 31s** and analysis was clean in
  **6.9s**; its Release rebuild passed in **46.1s**. The final evidence table and
  hashes below identify this version.

### Final Session 2 evidence

These final results supersede partial/intermediate runs. Overlapping counts are
not additive. Generated evidence is local and ignored by Git.

| Check | Observed result | Evidence |
| --- | --- | --- |
| Full Flutter regression suite | **657 passed**, 2m 31s; 58 new Session 2 tests | [Final test log](../artifacts/day-clock/session2/flutter-final.log) |
| Static analysis | **No issues**, 6.9s | [Analysis](../artifacts/day-clock/session2/analysis-final.log) |
| Dart formatting | **133 files checked, 0 changes** | [Formatting](../artifacts/day-clock/session2/format-final.log) |
| Native Windows checks | **4/4 executables passed**, **331 assertions**: 248 desktop, 43 fonts, 15 audio guard, 25 mobile safety host; 15 new creation-storage assertions | [Native log](../artifacts/day-clock/session2/native-tests.log) |
| Windows Release compilation | **Passed**, 46.1s; `lib/main.dart` | [Build log](../artifacts/day-clock/session2/windows-final.log) |
| Actual Flutter integration renders | **18 PNGs** with fictional Google transport; wide/narrow, dark/light/high contrast, 100/150/200% text, reviewed and Saved forms, declined consent and stale Now | [Capture directory](../artifacts/day-clock/session2/screenshots/) |
| Source preservation | Dial, projection, theme, shell, event model/colour reader, focus writer and focus ownership model match their Session 1 SHA-256 values | [Verification manifest](../artifacts/day-clock/session2/verification-manifest.json) |
| Patch whitespace | `git diff --check` passed | Final repository check |
| Evidence integrity | Manifest hashes match; local documentation links resolve | [Final audit](../artifacts/day-clock/session2/final-audit.json) |

| Acceptance case | Automated observation |
| --- | --- |
| Future 10–11 PM, owned primary calendar | Production creation writer sends one ordinary event with `22:00+05:30`–`23:00+05:30`, exactly `16:30Z`–`17:30Z`; one 600–660-minute PM sector and one agenda item. |
| Double action, timeout after commit, restart | Stable original event ID, matching marker/payload verification and one server event; startup does not insert. |
| Four actual child-process exits | Kept draft, durable Sending, independent server commit and Saved acknowledgement reopen real journal/server files; checks never replay a mutation. Explicit absent-event Retry retains the original ID. |
| Decline, partial/extra scopes, wrong account, candidate/commit failures | Previous valid reader and focus grant remain usable; creation is not inferred. Creation/focus receipt enablement survives combined grants and refresh independently. |
| Local time and access | Explicit overnight date, noon/midnight, expired start, invalid local resolution, timezone changes during final preflight and owner-role loss prevent invalid submission. Existing DST projection/resolver regressions pass. |
| Conflict/deletion and uncertain acknowledgement | Foreign or changed payloads are not adopted or overwritten; HTTP Gone cannot authorize resurrection; repaired/reopened durable acknowledgement recovers Saved without another insert. |
| Shared reader and availability | Post-save refresh waits for an earlier read; hidden/outside-window cases remain honest; refresh failure stays Saved with link/notice; no draft or uncertain operation becomes a sector. |
| Lock/disconnect and focus independence | Late journal/HTTP results cannot restore cleared authority or account records. An already transmitted event can remain in Google; no compensating delete occurs. Focus ownership safeguards and independent timer/history regressions pass. |

The event/server observations above use fictional providers and the real
production HTTP adapter/controller seams. They are **not live Google evidence**.

### Source and build identity

- Base commit: `c3625a68774f0478146f4abb84e5b039d52465f9`. Session 1 and Session 2
  remain uncommitted working-tree changes; pre-existing work was preserved.
- Flutter **3.44.2**, Dart **3.12.2**, framework
  `c9a6c484230f8b5e408ec57be1ef71dee1e77020`.
- The [manifest](../artifacts/day-clock/session2/verification-manifest.json)
  records **168 source/test/native inputs**, **44 runtime files**, **18 captures**
  and the final verification logs. Source-input set SHA-256:
  `76230b6c06bfb413d42dfbbd43f8703531b8e2c75eda880e022d5a086026b50b`.
- Compiled executable: `mobile/build/windows/x64/runner/Release/poma.exe`, inherited
  file version **1.0.0.2007**, SHA-256
  `bf3d74c7a2928d5e8b9f49d15a9b4bb910404257ada3ed4669d8e23c59ce8e93`.
- Compiled Dart image `data/app.so`, SHA-256
  `841f538bba7da68dc36fa7525543f001b56ec16c17ffe386fb60bae23339902a`.
- This is an **unconfigured compilation**, not a replacement of installed
  1.0.0.2027. Production creation is wired to Poma's credential owner, but Connect
  requires the owner's existing Desktop configuration in a separately configured
  build. Installed application/profile and Google console settings were untouched.

### Session 2 file map

New production files:

- `mobile/lib/application/calendar_event_creation_controller.dart`
- `mobile/lib/data/google_calendar_event_writer.dart`
- `mobile/lib/data/windows_calendar_creation_store.dart`

Extended existing creation domain/ports, Day Clock controller/form/screen, shared
reader post-save refresh, Desktop lifecycle/composition, connection/capability
receipts, Desktop authorization and Calendar settings. Native additions are in
`mobile/windows/runner/calendar_credentials.h`, `desktop_host.cpp` and the existing
desktop native test. The focus writer and focus ownership model are unchanged.

New tests: `calendar_event_creation_test.dart`, `calendar_creation_consent_test.dart`,
`calendar_creation_process_test.dart`, `calendar_creation_ui_test.dart`, isolated
`calendar_creation_support.dart` and `probes/calendar_creation_crash_probe.dart`,
all under `mobile/test/`. README, architecture, schedule/setup, this progress log,
the approved plan and bundled Windows privacy disclosure describe the feature.
No dependency, timer/history database schema, mobile navigation or installed
package identity was changed.

### Reviewed Session 2 captures

- [Saved 10–11 PM sector and matching agenda](../artifacts/day-clock/session2/screenshots/clock-1440-100-dark.png)
- [Reviewed form, light / 150%](../artifacts/day-clock/session2/screenshots/review-1440-150-light-bottom.png)
- [Saved result, narrow dark / 200%](../artifacts/day-clock/session2/screenshots/saved-640-200-dark-bottom.png)
- [Saved result, narrow high contrast / 200%](../artifacts/day-clock/session2/screenshots/saved-640-200-light-contrast-bottom.png)
- [Declined consent with retained fields](../artifacts/day-clock/session2/screenshots/consent-declined-fields-retained.png)
- [Stale Now with unknown availability](../artifacts/day-clock/session2/screenshots/stale-now-unknown.png)

### Configuration and Session 3 boundaries

The same Poma Google project's Calendar API, Desktop client, named testers/
audience, accurate disclosures and owner-local build defines are prerequisites.
Data Access must declare owned-event creation alongside the read pair and retain
`calendar.app.created` when focus scheduling is used. See GOOGLE_CALENDAR_SETUP.md.
Google console declarations alone are not grants. No connector token is reused.

Live same-account consent/decline, exact actual grants, disposable primary/owned-
secondary creation and readback, installed package behavior and physical assistive
operation remain **unrun**. Session 3 must compare the real Google event, correct
displayed-zone timing and single sector/agenda identity, exercise installed
refresh/restart/disconnect, and produce DAY_CLOCK_VERIFICATION.md. Host captures,
synthetic transport and compilation do not establish those live passes.

Session 3 owner-assisted checklist:

- Verify Poma's configured Desktop client/project, actual exact grants, same-account
  candidate refresh and protected restart. Exercise creation decline with focus
  already enabled, then combined enablement and independent disablement.
- On explicitly authorized disposable primary/owned-secondary data, compare one
  future 10–11 PM ordinary event in Google with one PM sector and one agenda row,
  exact timezone/offsets, Busy/Free, explicit colour and calendar-default colour.
- Exercise live refresh, a hidden destination, a date outside retained coverage,
  original-ID outcome checking and expired retry. Do not create replacement IDs
  for uncertain sends or delete unrelated events as cleanup.
- Verify lock, suspend, restart and disconnect in an installed configured build,
  including preserved remote events, rejected stale submissions and independent
  timer/tasks/history/focus behavior. Installation requires a separately prepared
  higher-version private package; this session did not install the 2007 compile.
- Inspect actual keyboard/screen-reader operation, native Open event launching,
  light/dark/high contrast and enlarged text. Record observations, source/build
  identity and unresolved cases in DAY_CLOCK_VERIFICATION.md; do not infer these
  physical/installed passes from host-rendered fixtures.

## Session 1 — 9 November 2026

Status: **Session 1 complete in source, tested and compiled.** Shared Calendar
viewing is connected; Google task creation remains explicitly unavailable for
Session 2. No live Google writes, consent changes, installation or publication
were performed.

### Activity log

1. Read RTK.md, feature brief, visual direction, circular calendar research,
   UI design system and Calendar schedule documentation; inspected both PNGs.
2. Mapped navigation/shortcuts, calendar reader/cache, Desktop authorization,
   focus writer, native time resolver, design tokens and Flutter capture workflow.
3. Consulted documented product/Flutter references and Google colour/label API
   semantics. Chose independent Flutter implementation; no upstream code reuse.
4. Confirmed owner decisions: real viewing in Session 1; visual-order shortcuts;
   drafts retained while Poma runs; Google saving/consent remains Session 2.
5. Ran baseline calendar schedule/read/desktop tests: **88 passed** (39 seconds),
   source c3625a68774f0478146f4abb84e5b039d52465f9. Earlier results in other docs
   remain historical, not verification of this implementation.
6. Created DAY_CLOCK_PLAN.md and this activity/progress record before code edits.

### Implementation and verification

- Projection/model milestone: added half-day/time-slice projection, UTC clipping,
  deterministic retained overlap lanes, all-day separation, interval-union totals,
  hand angles and generic creation intent/writer types.
- Shared-reader milestone: optional event colour/label IDs and palette cache;
  palette refresh uses existing cadence/scope and fails independently of events.
- UI milestone: Windows destination 5, visual-order Ctrl+1–6, desktop-owned state,
  real reader/agenda binding, dial, agenda/details and complete in-memory form.
  The production creation capability is explicitly disconnected. Existing Desktop
  authorization and GoogleFocusWriter have not been broadened.
- Early verification exposed a painter expression typo during formatting,
  corrected before behavioral tests. Final screenshots and results are below.
- First complete new-feature run: **50 tests passed** (21 seconds), including
  projection DST cases, real reader/cache integration through fictional providers,
  draft validation, linked selection, keyboard dismissal, lock redaction and the
  first visual matrix. Two earlier combined runs were stopped after discovering
  test-fixture futures needed `tester.runAsync`; corrected fixture handling, not
  production synchronization. The existing 88-test regression files completed
  during those runs; the final complete-suite evidence below supersedes partial runs.
- Native Windows verification passed all four executables: **233 desktop,
  43 font, 15 audio-guard and 25 mobile-safety host assertions**. This is host
  verification, not installed notification/audio/assistive acceptance.
- Inspected actual wide/narrow light/dark, crowded, form and high-contrast renders.
  Refinements: Source Sans 3 dropdown text, readable disabled save action,
  explicit high-contrast chip/rail selection; added checked-form and scrolled
  enlarged-text captures. No static concept image is used as the implemented UI.
- Complete Flutter regression run: **593 passed** (2m 28s), including timer,
  history, tasks, mobile/offline, consent/focus scheduling, real-process recovery,
  Calendar/tray and 52 Day Clock tests. Windows release compilation passed in
  **134.2 seconds**. No installation or publication was performed. Form coverage
  was subsequently extended to 150% and high contrast for the final record.
- The extended keyboard check found wide-form reading order interleaved start and
  end controls. Set an explicit widget-order traversal policy so the complete
  start endpoint precedes the end endpoint at every width. Extended capture
  helpers now scroll to rebuild a lazily removed header before reopening forms.
- Added partial/retained, empty-AM and unselected-calendar renders. Verified that
  explicit disconnect closes an open account draft immediately. Lane occupancy
  checks are bounded to each lane, and retained lanes compact when an overlap
  group shrinks, restoring substantial full-depth sectors for a surviving event.
- Closed the session with **599 passing Flutter tests**, clean static analysis,
  clean formatting, the native checks, a final Windows compilation, **83 captures**
  and a hashed source/runtime receipt. Reviewed representative new 150%, high-
  contrast form, partial-data and empty-AM captures. All **19 local evidence links**
  resolved, and final patch whitespace validation passed. No required Session 1
  implementation work remains; the separately scoped integration checklist is below.

### Evidence location

`artifacts/day-clock/session1/` (ignored generated artifacts; fictional events only).
Installed/live-Google/native-screen-reader acceptance remains unobserved.

## Final verification

Final source checks supersede the intermediate run results in the activity log.
Counts from overlapping runs are not additive.

| Check | Observed result | Evidence |
| --- | --- | --- |
| Complete Flutter suite | **599 passed**, 2m 24s; includes **58 new Day Clock tests** | [Final test log](../artifacts/day-clock/session1/flutter-final.log) |
| Static analysis | **No issues**, 12.3s | [Analysis](../artifacts/day-clock/session1/analysis-final.log) |
| Dart formatting | **124 files checked, 0 changes** | [Formatting](../artifacts/day-clock/session1/format-final.log) |
| Windows native checks | **4/4 executables passed**, 316 assertions: 233 desktop, 43 fonts, 15 audio guard, 25 mobile safety host | [Native log](../artifacts/day-clock/session1/native-tests.log) |
| Windows Release compilation | **Passed**, 88.1s; `lib/main.dart` | [Build log](../artifacts/day-clock/session1/windows-final.log) |
| Actual Flutter review captures | **83 PNGs**, fictional events; wide/narrow, ordinary/crowded, partial/empty, selected details, forms, light/dark/high contrast, 100/150/200% text | [Capture directory](../artifacts/day-clock/session1/screenshots/) |
| Read-data / fixture separation | No preview-support imports, preview account or preview build marker in `mobile/lib` | Source audit plus GET-only mock and no-write/controller tests |
| Patch whitespace | `git diff --check` passed | Final repository check |

The regression suite covers the existing timer, tasks, history, offline/mobile
behavior, notifications, consent/focus scheduling, Calendar, tray coordination,
cache invalidation and real-process recovery. Day Clock checks additionally cover
UTC clipping, gaps/folds, stable/compacting lanes, merged durations, retained refresh,
manual/Now behavior, advisory overlaps, colour compatibility, keyboard AM/PM,
labelled actions, painted contrast and closing private drafts on lock/disconnect.

### Source/build identity

- Base commit: `c3625a68774f0478146f4abb84e5b039d52465f9`; implementation remains
  an uncommitted working-tree change for review.
- Pinned Flutter **3.44.2**, Dart **3.12.2**; framework revision
  `c9a6c484230f8b5e408ec57be1ef71dee1e77020`.
- [Verification manifest](../artifacts/day-clock/session1/verification-manifest.json)
  records SHA-256 for **126 source/input files**, **42 runtime payload files** and
  **83 captures**. This identifies the working tree without relying on an old
  installed-package version or historical test result.
- Executable: `mobile/build/windows/x64/runner/Release/poma.exe`; file version
  **1.0.0.2007**, inherited from the unchanged source manifest. This is compilation
  evidence, not a new installer version or a replacement of installed 1.0.0.2027.
- Executable SHA-256:
  `6e95f9d55a5dc9e746a7c66d53b8ebc1528f22648d1d11a40a8ee1a9e83a29b8`.
- Compiled Dart image `data/app.so` SHA-256:
  `94cf07d827d368fb362944d019ba7bcef39a00c9cf5903e2f880d7d8a111f796`.
- No private Google Desktop build defines were supplied to this compilation.
  Shared viewing is implemented and mock-verified; live viewing/consent remains
  an installed, configured-build acceptance item. Installed Poma and its saved
  configuration/data were not touched.

### Remaining acceptance boundaries

Session 2 still owns Google creation consent, durable drafts/intent recovery,
real writer/readback and save reconciliation. Session 3 owns the final integrated
verification document. Live Google comparison/create/readback, installed-package
behavior, actual screen-reader operation, physical device behavior and any custom
calendar-label colour support are not claimed by these host results. Unknown
label-only colour assignments are explicitly shown as unavailable in Session 1.

## Implemented components and decisions

- `DayClockWindow` splits the device's actual UTC day into offset-constant AM/PM
  slices. `DayClockProjection` clips intervals, maps civil minutes to angles,
  separates all-day items, merges elapsed totals and retains non-conflicting lanes.
  Repeated wall-clock occurrences remain separate sectors with UTC offsets;
  skipped spans are hatched. Dense clusters show four lanes and an overflow rim.
- `DayClockController` belongs to `DesktopController`, so manual date/half, sector
  selection, lane assignments and raw draft fields survive page reconstruction.
  Now follows date/half; expired manual dates stay selected and explicitly unloaded.
  The existing reader's minute notifications move the hand without I/O.
- Event identity is shared by Calendar, native agenda and Day Clock through
  `calendarEventIdentity`. Details use the shared agenda's regional formatting and
  validated Open event/Join action path. Selected details stay near the dial.
- `CalendarPaletteProvider` is an optional additive reader capability. A palette
  is fetched on the existing refresh path when absent, failed or a day old; there
  is no extra polling timer. Optional palette/colour fields retain cache version 1.
  Bad optional palette data cannot discard otherwise valid cached events.
- Standard event colour IDs resolve to Google's retained palette, then source
  colour applies only without an explicit override. Unknown IDs / label-only
  assignments receive a visible colour-unavailable indication; label IDs are never
  interpreted as global colour IDs. New custom calendar-label authoring is absent.
- The form uses explicit endpoint dates and AM/PM, device rules via
  `WindowsFocusTime`, computed elapsed duration, owned calendars, Google palette
  choices, Busy/Free and optional selected-task title association. A new empty-dial
  position updates times while retaining an existing draft's title/options/duration.
- Drafts remain in memory only. Closing the form, navigation, refresh and recoverable
  validation failure retain them; lock hides them and invalidates review. Explicit
  disconnect/full reset clears account drafts and remembered destinations. A changed
  account cannot silently adopt another account's draft or target.
- `CalendarEventCreationController` and `CalendarEventCreationWriter` expose review,
  submit and reconcile boundaries. The production controller reports disconnected;
  direct submit returns unavailable, and reconcile reports unconnected checking.
  No HTTP writer, new consent, generic operation journal or optimistic event exists.
  Final Add to Google Calendar remains visible, labelled and disabled with a reason.
- No dependency, font asset, Google focus ownership rule, native tray protocol,
  timer/history storage schema or mobile navigation destination was changed.
  High-contrast rail selection now uses opaque primary/on-primary colours.

## Files changed

New runtime files:

- `mobile/lib/domain/day_clock.dart`
- `mobile/lib/domain/calendar_event_creation.dart`
- `mobile/lib/application/day_clock_controller.dart`
- `mobile/lib/application/calendar_event_creation_ports.dart`
- `mobile/lib/ui/day_clock_dial.dart`
- `mobile/lib/ui/day_clock_screen.dart`
- `mobile/lib/ui/day_clock_task_form.dart`

Updated runtime files:

- `mobile/lib/domain/calendar_data.dart`
- `mobile/lib/application/calendar_agenda_controller.dart`
- `mobile/lib/application/calendar_read_controller.dart`
- `mobile/lib/application/calendar_read_ports.dart`
- `mobile/lib/application/desktop_controller.dart`
- `mobile/lib/data/google_calendar_reader.dart`
- `mobile/lib/ui/calendar_schedule_adapter.dart`
- `mobile/lib/ui/app_shell.dart`
- `mobile/lib/ui/theme.dart`
- `mobile/lib/main.dart`

Tests: new `day_clock_projection_test.dart`, `day_clock_test.dart` and isolated
`day_clock_support.dart`; updated Calendar/desktop shortcut expectations in
`calendar_schedule_test.dart` and `desktop_test.dart`. All are under `mobile/test/`.
Documentation: DAY_CLOCK_PLAN.md, this progress log and CALENDAR_SCHEDULE.md.
The owner's pre-existing briefs/research/reference images were preserved.

## Visual evidence

These are actual Flutter widget renders with production fonts and fictional
accounts/providers. They are not screenshots of the installed app or live data.

| Review | Capture |
| --- | --- |
| Wide dark clock | [1440 / 100%](../artifacts/day-clock/session1/screenshots/ordinary-1440-100-dark.png) |
| Wide light clock | [1440 / 100%](../artifacts/day-clock/session1/screenshots/ordinary-1440-100-light.png) |
| Narrow dark clock | [640 / 100%](../artifacts/day-clock/session1/screenshots/ordinary-640-100-dark.png) |
| Enlarged narrow dial | [640 / 200%, scrolled](../artifacts/day-clock/session1/screenshots/ordinary-640-200-light-dial.png) |
| Crowded / selected overflow | [Wide dark](../artifacts/day-clock/session1/screenshots/crowded-1440-dark.png) |
| Dense chronological agenda | [Scrolled agenda](../artifacts/day-clock/session1/screenshots/crowded-1440-dark-agenda.png) |
| Checked 10–11 PM form | [Wide dark](../artifacts/day-clock/session1/screenshots/form-1440-100-dark-top.png) |
| Form at 150% | [Wide light](../artifacts/day-clock/session1/screenshots/form-1440-150-light-top.png) |
| Form at 200% | [Narrow top](../artifacts/day-clock/session1/screenshots/form-640-200-dark-top.png), [bottom](../artifacts/day-clock/session1/screenshots/form-640-200-dark-bottom.png) |
| High-contrast dense dial | [Dark / 200%](../artifacts/day-clock/session1/screenshots/high-contrast-1440-dark-dial.png) |
| High-contrast form | [Narrow dark](../artifacts/day-clock/session1/screenshots/form-high-contrast-640-dark-bottom.png) |

## Exact Session 2 integration work

1. **Capability/consent owner:** extend the existing Desktop authorization and
   protected credential owner with `calendar.events.owned`. Recognize verified
   read-only, read+focus, read+creation and read+focus+creation combinations, using
   distinct account/client/generation-bound capability receipts. Validate raw
   returned scope evidence and candidate account before committing. Preserve
   working read/focus grants on denial, partial consent or wrong-account selection.
   Document the Google project's required Data Access configuration; use Poma's
   credentials, never connector credentials. Keep installed-app PKCE/loopback flow.
2. **Creation controller:** replace the unavailable submit/reconcile implementation
   behind `CalendarEventCreationController`, preserving raw form fields through
   consent and recoverable errors. Recheck account, owned destination, capability,
   future start, timezone fingerprint/offsets and reviewed-field revision immediately
   before confirmation. Only the explicit final action authorizes creation.
3. **Durable intent:** add a separate protected generic draft/operation journal,
   with backward-compatible reset/disconnect handling. Persist exact reviewed
   account/calendar, frozen UTC endpoints/offsets, title, Busy/Free, optional colour,
   operation ID, payload hash and stable Google event ID before sending. A suitable
   valid distinct ID is `pomadc` plus an unhyphenated random UUID's lowercase hex;
   keep generic private operation markers separate from focus ownership markers.
4. **Writer:** implement `validateDestination`, `create`, `readBack`, `cancel` for
   owned calendars including the actual primary-calendar ID. Create one ordinary
   `eventType: default` event, with transparency and optional supported `colorId`;
   set `eventLabelVersion=0`. Do not route generic payloads through GoogleFocusWriter
   or add invitations, recurrence, arbitrary edits/deletes or sharing.
5. **Recovery:** disable double submission, reuse the operation/event ID, and
   verify matching markers and exact intent on timeout/conflict readback. An
   unrelated existing event is not success. Persist sending/checking/saved/failed
   results truthfully. Do not replay offline drafts automatically or perform a
   compensating delete. Lock/disconnect/account/capability changes invalidate
   submission authority while preserving honest recovery of a possible saved event.
6. **Shared-reader reconciliation:** refresh the same CalendarReadController after
   verified save. Never add journal drafts/unknown operations to confirmed sectors.
   Prevent pending/confirmed duplicates. A refresh failure after success remains
   Saved with a refresh notice. Offer to show a hidden target calendar explicitly;
   for an out-of-window save expose the event link and coverage explanation.
7. **Evidence:** mock consent/store/provider faults, timeout-after-commit, restart,
   duplicate submissions, read-only/shared destinations, palette fallback, timezone
   change and refresh failure. Then use an explicitly authorized disposable Google
   calendar for live create/readback. Keep installed, screen-reader and physical
   acceptance separate; do not create personal-calendar test events implicitly.
