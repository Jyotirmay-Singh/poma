# Windows planner implementation and acceptance

## Product contract and retained baseline

The 11 November 2026 owner request governs Tasks, Calendar and Day Clock. The
implementation builds on the existing uncommitted Day Clock repair. Historical
repeated review, future-only ordinary creation and seven-date planner browsing
limits are superseded. The focus writer keeps its existing ownership checks,
time restrictions and journal.

## Implemented workflow

- Tasks, Calendar and Day Clock use `PlannerController` and the shared editor.
  Unscheduled Tasks receive no arbitrary calendar time. Timed creation opens a
  draft and one Save commits the task, schedule and outbox transaction before
  delivery. Explicit local saves retain their local policy.
- SQLite v4 adds schedules, stable remote links, immutable attempted operations,
  account preferences, raw drafts, legacy-import receipts and occurrence
  completion. Migration retains the existing task, timer and history tables.
- Scheduled-task syncing starts disabled. Owned-calendar authorization is reused.
  Account changes and lock cancel active attempts. Retry reconciles the original
  event identity. Legacy uncertain saves require explicit retry and retain their
  original payload receipts.
- The ordinary writer revalidates ownership, checks event capability, fetches the
  current event, merges non-overlapping changes and uses conditional PATCH or
  DELETE. Field conflicts retain the proposed changes for review. Dedicated
  focus blocks route to Focus blocks. Guest-changing consequences appear in the
  editor. Unrelated Google fields remain preserved.
- Grid range creation, movement, resizing, Escape cancellation and conditional
  inverse Undo share the coordinator. Deletion has a durable ten-second delay.
  Day Clock supports click-to-add, overlap selection and selected-sector changes.
- Repeat authoring supports daily, weekdays, selected weekdays, monthly and
  custom intervals, with count or date endings. Occurrence and series operations
  retain instance/master identity. Unsupported recurrence rules are preserved.
  Completion records use original occurrence starts.
- The range-aware reader shares a calendar catalog and cache with the resident
  tray/reminder range. Browsing supports Day, Week, Month and Agenda. Fetches use
  bounded seven-date chunks and at most two simultaneous source requests.
- Clock modes include 12-hour, 24-hour and three/six-hour windows. Busy intervals
  merge before gap calculation. Fresh complete source coverage is required for
  confirmed availability. Pending changes conservatively reserve time.

## Automated verification

Source and widget checks use fictional data. Google protocol and recovery checks
use mocked transport. The gallery contains rendered production widgets.

| Check | Recorded result | Evidence |
| --- | --- | --- |
| Complete regressions for installed 2032 | 870 passed | [Run log](../artifacts/windows-planner/flutter-2032.log) |
| Complete regressions for final candidate 2033 source | 879 passed in 5 minutes 29 seconds | [Final run log](../artifacts/windows-planner/flutter-2033-final.log) |
| Fresh-version deletion and queued-update recovery | 57 planner checks passed | [Recovery log](../artifacts/windows-planner/deletion-verified.log) |
| Repeated-hour placement, movement through DST, midnight, boundary resizing and Escape | 6 widget regressions passed | [Clock log](../artifacts/windows-planner/drag-resumed.log) |
| Deletion Undo deadline with accessible navigation enabled | Passed through the Tasks menu | [Deadline log](../artifacts/windows-planner/undo-deadline-2033.log) |
| Final interface and recovery capture run | 57 passed | [Feature log](../artifacts/windows-planner/features-final.log) |
| Corrected timezone, planner, recovery and interface checks | 54 passed | [Timezone log](../artifacts/windows-planner/timezone-verified.log) |
| Native Windows checks rerun for 2033 source | 4 executables, 331 assertions passed | [Native log](../artifacts/windows-planner/native-2033.log) |
| Final source analysis | No issues found | [Analysis log](../artifacts/windows-planner/analysis-2033-final.log) |
| Production-engine Windows startup, pause/reopen, one completion and strict successor | Passed in 69 seconds using an isolated development profile | [Integration log](../artifacts/windows-planner/integration-2033.log) |
| Fictional production-widget gallery | Normal/maximized client sizes, 100/150/200 percent text, light/dark/high contrast, dense Unicode, draft, waiting, conflict and saved states | [Gallery](../artifacts/windows-planner/screenshots-2033/) |

The restricted test attempt could not open the Flutter loopback connection.
The successful runs used the required local test connection. The first native
attempt received Access denied during its process/IPC checks. Its permitted
rerun passed all four executables.

## Installed findings and correction

The configured, signed 1.0.0.2033 package was installed on 11 November 2026 after
a verified closed-app backup. Windows reported status Ok. Seven profile files
matched before first launch, and all 80 installed payloads matched the audited
package. The retained package identity, signer and Google configuration matched.
The installer SHA-256 is
`855ea5477f23f93f14d2b5e2ad382d0f7cdb05ec3e92cd925e209a6bd5b0c993`.

After the preceding 2032 upgrade and live-test cleanup, task, session, settings
and complete stored-timer fingerprints matched the original profile. It contains
zero tasks and sessions and a Ready 25-minute timer with zero completed rounds.
Post-launch retention checks for 2033 remain pending.

The installed 10 PM click exposed legacy CLDR link names missing from the pinned
timezone database. Eight mappings now resolve to supported IANA locations.
Unknown device mappings preserve the inspected local fields while requiring an
explicit timezone. Regression checks cover every mapping and the native India
timezone response. The installed corrected build opens a 10 PM click as
22:00–23:00 in Asia/Kolkata. Pending overlays now retain core UTC DateTime
conversion and show the same device-local time as the acknowledged event.

Live recurrence deletion exposed a stale local link after a whole-series edit.
The current source retains the freshly fetched schedule for deletion, preserves
an earlier queued update through deletion Undo, and reuses repeated removal
intents. The two recovery regressions pass. Build 2032 required Use Google and a
fresh retry for the first occurrence deletion. Its eventual acknowledged deletion
is recorded separately from the source fix's live acceptance.

Current source also resolves clock dragging through the displayed timezone.
Spring gaps retain an unsaved proposal. Repeated times offer numeric UTC-offset
choices. Midnight movement and end-handle resizing carry their actual date.
Build 2033 includes these deletion and clock corrections. Fresh installed/live
validation of those corrections remains pending.
The pinned Flutter version also keeps action snackbars persistent by default.
Deletion notices now use the stored Undo deadline and close when that deadline
expires. The durable pending-operation panel retains its state-based controls.

Actual normal-window measurements used GetWindowRect, DWM extended-frame bounds,
GetClientRect and GetDpiForWindow. The physical outer rectangle measured
1350 by 950 pixels. The visible frame measured 1334 by 942, and the client measured
1332 by 903 at 120 DPI. This gives a 1065.6 by 722.4 logical client area. Windows
text scaling was 100 percent. The maximized visible frame measured 1920 by 1050
physical pixels and its client measured 1920 by 1021, giving 1536 by 816.8 logical
client units. Flutter engine-reported DPR and text scaling require separate
verification. Healthy Day Clock controls and the complete dial fit both measured
clients. The wide editor replaces the agenda while retaining the complete dial.

The current production-engine Windows integration run reports a 1332 by 903
physical client, DPR 1.25, 1065.6 by 722.4 logical client, and text scale 1.0 at
16-point text. This independently matches the normal-window measurements.
It uses an isolated development profile. Installed release engine metrics remain
a separate acceptance item.
The integration run completed successfully. Its original development profile was
hash-verified and restored after archiving the fictional test data.
[Integration receipt](../artifacts/windows-planner/windows-integration-2033.json)

## Observed live Google acceptance

The retained owned-calendar permission is enabled in the installed account.
Source, mocked transport, installed Windows and live Google results retain their
observed evidence levels.

| Journey | Observed result | Evidence |
| --- | --- | --- |
| One-off creation from Day Clock | One Save created one acknowledged ordinary event at 22:00–23:00 | [Creation receipt](../artifacts/windows-planner/installed/oneoff-created-2031.json) |
| Ordinary title edit | Renaming retained the original event ID | [Edit receipt](../artifacts/windows-planner/installed/oneoff-renamed-2031.json) |
| One-off completion | Local completion retained the Google event | [Completion receipt](../artifacts/windows-planner/installed/oneoff-completed-2031.json) |
| Delayed deletion Undo | Undo restored the task and cancelled dispatch | [Undo receipt](../artifacts/windows-planner/installed/oneoff-delete-undone-2031.json) |
| One-off cleanup | A subsequent deletion was acknowledged and removed the temporary event/task | [Deletion receipt](../artifacts/windows-planner/installed/oneoff-deleted-2031.json) |
| Recurring creation | Daily, count three created a master and three 22:00–23:00 occurrences in Asia/Kolkata | [Routine receipt](../artifacts/windows-planner/installed/routine-created-2032.json) |
| This-occurrence edit | The first instance retained its instance and original-start identity and the next occurrence retained its title | [Occurrence receipt](../artifacts/windows-planner/installed/routine-occurrence-edited-2032.json) |
| Whole-series edit | Updating the master refreshed all three instance titles | [Series receipt](../artifacts/windows-planner/installed/routine-series-edited-2032.json) |
| Shared Calendar presentation | Week view displayed the routine's three instances | [Shared-state receipt](../artifacts/windows-planner/installed/routine-shared-calendar-2032.json) |
| Occurrence completion | Tasks recorded the displayed occurrence and retained the series and future occurrences | [Completion receipt](../artifacts/windows-planner/installed/routine-occurrence-completed-2032.json) |
| This-occurrence deletion | After conflict reconciliation and retry, November 11 was deleted and November 12/13 remained. Tasks displayed an incomplete November 12 occurrence | [Cleanup receipt](../artifacts/windows-planner/installed/routine-occurrence-cleanup-2032.json) |
| Whole-series and local-task cleanup | All temporary schedules are removed, zero temporary Tasks remain, no actionable operations remain, and the refreshed reader retains zero temporary events | [Cleanup receipt](../artifacts/windows-planner/installed/routine-series-cleanup-2032.json) |

Scheduled-task syncing was initially Off, enabled for these temporary journeys,
then returned to Off after the queue became terminal. Existing ordinary-event
editing authorization remains available. The original task, session, settings
and complete stored-timer fingerprints matched again after cleanup.

Receipts use controlled fictional task titles and hashed calendar identities.
Existing personal events were left intact. The Google results above were observed
through locally installed Poma with its retained owned-calendar permission.

## Remaining acceptance

Build 2033 is installed after all 879 regressions passed. Opening it for final
acceptance was interrupted when the user stopped computer control with Escape.
Fresh installed/live validation must cover the latest deletion and clock fixes.
Physical Narrator speech, Flutter engine-reported metrics, all live recurrence
presets and end conditions, live grid/dial move/resize with Undo, live external
edit conflicts, live account/access changes, and installed offline/failed-storage
journeys still need their required acceptance. Source and mock coverage is
recorded in the test logs and does not establish those physical/live results.

Every design-gallery capture uses fictional accounts and events. Installed
personal-calendar observations are excluded from the fictional design gallery.
