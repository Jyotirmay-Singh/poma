# Day Clock repair verification — 10 November 2026

**Poma 1.0.0.2029 is installed and its existing-event Google sync passed.**
The owner explicitly authorized the local upgrade and sync check. The repaired
installed UI, two existing saved-event reveals, manual refresh and shared Calendar
view passed live checks. Tasks, history, settings and full timer state match the
pre-upgrade backup. The owner chose **Test existing events only**; no live event
was created, modified or deleted. No external publication was performed.

The owner approved [the repair plan](DAY_CLOCK_REPAIR_PLAN.md). This report records
fresh repair evidence; the Session 1–3 results in the older progress/verification
documents remain historical.

## Confirmed baseline and causes

- Checkout: `D:/pomodoro`, HEAD `26fb1acfa26158942a53ba6da96b10048b0d418f`.
  The audit and its two screenshots were already untracked and were preserved.
- Independently inspected running/installed Poma **1.0.0.2028**, package status Ok.
  All **76 installed payload files** matched its existing package inventory.
  Its configured Calendar client matched the existing private build configuration.
- The installed UI reported **Viewing: Connected**, **Task creation enabled**,
  **No calendars selected**, and **Saved to Google Calendar / calendar hidden**.
  This is current visibility evidence, not evidence that the writer failed.
- Read-only private journal/cache inspection matched the current account and the
  persisted operation/calendar/event identities. Saved endpoints matched the
  frozen intent, and destinations remained listed as owned. Records were within
  retained dates; at least one was on a different date from the current view.
  Account identifiers, titles, event IDs and endpoints are excluded from shareable
  evidence. This local receipt inspection was **not fresh live Google readback**.
- `showCalendar` only added the destination to the reader selection. It did not
  navigate to the saved event's local date/AM–PM half or select/reveal its row.
  After closing Saved, the only operation recovery was in a lower disclosure.
- The old page required 900 usable content units for columns and sized the dial
  from width alone, after a tall heading/status/control stack. The complete circle
  extended below the first viewport at normal and maximized desktop heights.

Before changes, three existing visibility/refresh regressions passed. New
failing-first tests then reproduced **four failures**: the old date remained after
the hidden-calendar save, and the circle exceeded client heights 724, 770 and 816.
The 1000-high case passed, demonstrating why the earlier tall fixtures missed it.
[Failing-first log](../artifacts/day-clock/repair/baseline-failing.log).

## Implemented behavior

The form now includes a default-on **Show on Day Clock after saving** choice in
the reviewed fields. It is a backward-compatible optional draft preference and
does not change the immutable Google payload or its hash. Deliberately unchecking
it preserves browsing and calendar selection while retaining a truthful Saved
result and an obvious Show action.

The Saved dialog and persistent main-page receipt use one `revealSaved` operation:

1. Validate the unlocked current account and persisted Saved operation identity.
2. Coordinate the existing reader's transitions and an earlier refresh; perform a
   fresh read, verify destination access and add it without discarding other valid
   selected calendars.
3. Find the actual event in shared provider snapshots, resolve its current local
   start date and AM/PM, navigate there and select its stable identity.
4. Highlight its sector and agenda row and scroll that row into view. Preserve a
   visible keyboard action: Add task when still visible, otherwise the selected row.

The operation never calls create, submit or an insertion retry. Repeated pending
Show actions share one reconciliation. Account/session changes, lock, newer Show
actions, manual calendar changes and manual browsing supersede obsolete work.
Minute updates, refresh, restart and later browsing do not replay the reveal.

The compact receipt survives closing the dialog, page navigation and beginning a
new draft. It contains the saved event's date/time, current display explanation,
**Show on Day Clock** and a validated **Open in Google Calendar** action. Saved
remains distinct from refreshing, refresh needed, hidden, inaccessible, absent,
outside coverage, available and selected states. A successful save followed by
read failure stays Saved; a missing reader event never becomes an invented sector.

## Visual result

The desktop composition now measures usable width **and remaining height**.
Columns begin at 744 content units: a 400-unit dial, 320-unit agenda and 24-unit
gap. The clock grows to 680 where space permits. A bounded scrolling side column
keeps the complete circle and primary controls visible while retaining access to
the entire agenda. Narrow, short and enlarged-text layouts stack and scroll.

The repair retains the still sky and opaque navy surfaces, Sora display/time
typography and Source Sans 3 reading text. Numerals and central time are more
legible; the small opaque centre has a restrained lavender outline. Short sector
labels use measured fitting positions, including two-line Deep work. Now/Next,
agenda rows, colour swatches and selected states are deliberately aligned with
the concept. Google-assigned event colours remain authoritative. Existing exact
projection, overlap lanes, hit testing and static-face/hand repaint isolation remain.

The controlled comparison uses exactly **Lunch 12:30–13:30, Deep work 13:30–14:30,
Travel 15:00–16:00, Meeting 16:30–17:30 and Reading 21:00–22:00**, fixed at **15:20**.
The original HEAD was rendered in an isolated local source copy, without swapping
the current implementation. The same fixture/date/time is used in the repaired
production widgets. All four original-source comparison renders passed their
fixture checks; their screenshots intentionally retain the old cropped layout.

[Open the before/after review gallery](../artifacts/day-clock/repair/review.html).

| Approximate whole window, logical units | Flutter client capture | Before | After |
| --- | --- | --- | --- |
| 1067×754 | 1067×724, 30-unit chrome allowance | [Original](../artifacts/day-clock/repair/baseline/controlled/concept-1067-724.png) | [Repaired](../artifacts/day-clock/repair/screenshots/concept-1067-724.png) |
| 1280×800 | 1280×770, 30-unit allowance | [Original](../artifacts/day-clock/repair/baseline/controlled/concept-1280-770.png) | [Repaired](../artifacts/day-clock/repair/screenshots/concept-1280-770.png) |
| 1536×840 | 1536×816, 24-unit maximized allowance | [Original](../artifacts/day-clock/repair/baseline/controlled/concept-1536-816.png) | [Repaired](../artifacts/day-clock/repair/screenshots/concept-1536-816.png) |
| 1536×1024 | 1536×1000, 24-unit allowance | [Original](../artifacts/day-clock/repair/baseline/controlled/concept-1536-1000.png) | [Repaired](../artifacts/day-clock/repair/screenshots/concept-1536-1000.png) |

These are **first-viewport production-widget host captures**, without native
chrome, at text scale 100% and capture pixel ratio 1. The whole-window allowances
are explicit, not claims that a Flutter client screenshot includes its title bar.
Separate regressions simulate device ratios **1.25 and 2.0** with the same logical
client bounds. The earlier Windows process probe returned 120 DPI, but a zero-area
client; its raw frame/client dimensions remain excluded from layout evidence.
Later installed checks below directly observed complete normal and maximized
windows. They establish the visible layout, not an independent client/DPI measure.

Necessary differences from the illustration: Poma retains its shared navigation,
native window chrome, practical controls, connection guidance and visible source
labels. The illustration's wedge/hand positions are approximate; production uses
exact start/end minutes. A real Google colour can differ from the fictional palette.
At short heights, the agenda scrolls independently; at larger text, the page stacks.

Representative current results:

![Repaired desktop clock](../artifacts/day-clock/repair/screenshots/concept-1536-816.png)

![A saved 10–11 PM event and its selected agenda row](../artifacts/day-clock/repair/screenshots/revealed-evening.png)

Additional inspected evidence:

- [Hidden-calendar receipt after closing Saved](../artifacts/day-clock/repair/screenshots/receipt-hidden.png).
- [Receipt reveal without another insertion](../artifacts/day-clock/repair/screenshots/receipt-revealed.png).
- [Selected late row scrolled into view](../artifacts/day-clock/repair/screenshots/selected-scrolled-agenda.png).
- [Normal empty](../artifacts/day-clock/repair/screenshots/empty-1067.png),
  [hidden](../artifacts/day-clock/repair/screenshots/hidden-1067.png),
  [retained stale](../artifacts/day-clock/repair/screenshots/stale-1067.png).
- [200% light reviewed choice](../artifacts/day-clock/repair/screenshots/review-640-200-light.png),
  [200% high-contrast Saved](../artifacts/day-clock/repair/screenshots/saved-1067-200-dark-contrast.png).

The final gallery contains **307 current PNGs and four controlled before PNGs**;
all PNG chunk checksums passed. Viewing and creation each cover 36 combinations:
640/1067/1536 widths × 100/150/200% text × light/dark × standard/high contrast,
using 724/816 client heights. Additional captures cover the four comparison sizes,
empty/hidden/stale states, the persistent receipt, reveal, scrolling and DPI cases.

## One-event / one-sector / one-agenda acceptance

Observed using actual production form fields, controller, Google HTTP adapter and
shared reader against the isolated **fictional Google transport**:

| Check | Result |
| --- | --- |
| Initial state | No selected calendars; browsing another date in AM |
| Reviewed event | Fictional repair evening; owned synthetic-primary destination; 10 November 2026, 22:00–23:00, India Standard Time |
| Exact UTC endpoints | 16:30Z–17:30Z, UTC+05:30 at both ends; exactly 60 minutes |
| Remote result | Exactly one ordinary default event, including rapid double Save |
| Revealed view | Correct 10 November PM half, one sector at 600–660 half-day minutes, sweep π/6 |
| Agenda | Exactly one matching shared-reader item with the same stable identity; selected and visible |
| Explicit opt-out | Saved remains truthful; browsing/selection stays unchanged; later receipt Show reveals without resubmitting |
| Existing saved operation | Repeated Show performs reads/reconciliation, never another insertion |
| Refresh failure/recovery | Saved and Google link retained; no fabricated sector; later Show recovers |

The 100 new repair cases also cover another selected calendar, a pre-existing
refresh, actual moved event times, superseding account/calendar/view changes,
lock, removed events, inaccessible destinations, out-of-window dates, later minute
updates/manual browsing, noon/midnight/overnight/timezone changes, receipt/page
survival, scroll-to-selection, form focus, reduced motion and responsive appearance.
Existing timeout/readback, stable ID, duplicate prevention, journals, credential
receipts, DST, event colours, dense overlap, long-title and Focus checks also pass.

## Fresh checks and exact candidate identity

| Check | Result | Evidence |
| --- | --- | --- |
| Complete Flutter suite | **809 passed**, 4m 06s reporter time | [Log](../artifacts/day-clock/repair/flutter-final.log) |
| Expanded affected checks | **228 passed** before the additional short-form matrix | [Log](../artifacts/day-clock/repair/feature-second.log) |
| Short-window form/Saved matrix | **36 passed**, 44s reporter time; included again in full suite | [Log](../artifacts/day-clock/repair/forms-final.log) |
| Static analysis | **No issues**, 8.2s | [Log](../artifacts/day-clock/repair/analysis-final.log) |
| Changed/affected Dart formatting | **13 files, 0 changes** | [Log](../artifacts/day-clock/repair/format-affected.log) |
| Patch whitespace | Passed | [Log](../artifacts/day-clock/repair/patch-whitespace.log) |
| Native Windows | **4/4 executables, 331 assertions** | [Log](../artifacts/day-clock/repair/native-final.log) |
| Configured Windows Release compilation | Passed, **134.8s** | [Build/signing log](../artifacts/day-clock/repair/windows-candidate.log) |
| Signature / package audit | **Valid**, same retained signer; **76 payload hashes**, no selected privacy-scan findings | [Audit](../artifacts/day-clock/repair/package-audit.json) |
| Source/capture integrity | **376 source inputs match the candidate**; all 311 controlled/current PNG checksums valid | [Manifest](../artifacts/day-clock/repair/verification-manifest.json) |

Counts from overlapping runs are not additive. Early failures exposed the expected
baseline defect, fixture scroll/contrast scoping assumptions and an actual focus
race after scrolling removed the header. These were corrected and superseded by
the complete 809-test pass. A broad formatting-only check also proposed changes in
three unchanged pre-existing tests; those unrelated files were preserved. The
final affected-file formatting check above passed.

Flutter **3.44.2**, Dart **3.12.2**, Windows x64 Release, entrypoint `lib/main.dart`.
Source remains the approved uncommitted repair on the HEAD above. The source
package version is unchanged; **2029 is the local Windows build override**.

- Candidate: [Poma-1.0.0.2029-x64.msix](../artifacts/windows/Poma-1.0.0.2029-day-clock-repair/Poma-1.0.0.2029-x64.msix).
- Package family: `JyotirmaySingh.Poma.Desktop_kz516h6tttq8c`.
- Installer SHA-256: `8d8d6bf3e1990e052a73e24eca536d4efeed27fd5c76dacd2cb2f9f406ee01f0`.
- Source input SHA-256: `9b16600aa3103eec17392f32910424e242e1503aaf9e020f856f94707a5e924e`.
- `poma.exe` SHA-256: `0804b5ae94ff3c175abebe7d2c282d0bb51462bbcacb49f74e551529b883bf36`.
- `data/app.so` SHA-256: `9e7ff4bb10740b48f55b6dd01cd16a3aec1de695509ed54be6da7e3373cbdafd`.

The existing Desktop Calendar configuration and trusted signer were reused. No
Google scope, dependency, certificate trust or Focus ownership rule was broadened.
The credential owner, both Google writers, protected creation store, native
credential/journal implementation, Focus controller/model and dependency manifests
are unchanged from HEAD; the evidence manifest records those preservation checks.

## Installed application and live Google checks

The owner requested installation into the locally present Poma application and a
Google Calendar sync check, then explicitly selected **Test existing events only**.
All live checks below used installed **1.0.0.2029**, its existing authorization and
the shared Poma reader. They did not use the fictional transport or connector
credentials, and did not submit an event creation, edit or deletion.

### Upgrade and preservation

- Quit Poma using its normal Quit action. Created an owner-private closed-profile
  backup outside the repository and verified all **7 profile files**.
- Installed the audited signed MSIX in place. Windows reported version
  **1.0.0.2029**, status **Ok**; all **76 installed payloads** matched the candidate.
  All **7 profile files** were byte-identical before first launch.
- Verified that the running executable came from the installed 2029 package and
  reported file version **1.0.0.2029**. See the [runtime receipt](../artifacts/day-clock/repair/installed/runtime.json).
- After live checks and another clean quit, the complete task/history rows,
  settings, selected task and full stored timer matched the pre-install
  fingerprints. The profile had **0 tasks and 0 history rows** before and after.
  All seven files remain present. Reader cache/selection and normal runtime stores
  changed during use; this is not a claim of byte-identical files after testing.
- Saved operations and destinations remained unchanged, with **2 Saved operations**
  before and after. The two existing drafts retained their content; their only
  metadata change was the backward-compatible default-on `showOnDayClock` field.
  See the [preservation comparison](../artifacts/day-clock/repair/installed/preservation.json).
- Reopened Poma and visually confirmed **paused 24:59, 0/4 completed rounds**,
  matching the original observation. Left it open on the repaired Day Clock.
  See the [restart result](../artifacts/day-clock/repair/installed/restart.json).

### Live read/reveal results

| Check | Observed result |
| --- | --- |
| Initial installed state | Existing authorization usable; no reconnect. No calendars selected; Saved receipt persisted. |
| First existing saved event | Explicit Show selected its destination; fresh shared-reader success followed the action; exactly one matching calendar/event identity; actual endpoints matched its saved intent. Correct date/PM, highlighted sector and selected agenda row. |
| Second existing saved event | Opened its read-only Saved receipt and used Show. Fresh Google read matched its identity and endpoints exactly once. Navigated to its different date and correct PM half; matching sector and agenda row selected. |
| Manual refresh while browsing | Fresh read succeeded, with one matching event; date, half and highlighted selection remained unchanged. |
| Shared Calendar screen | Schedule verified; both existing events visible on their correct days and times. |
| Actual normal and maximized windows | Complete dial and primary controls visible at helper-reported whole-window sizes **1067×754** and **1536×840**. These include native chrome. |
| Restart | Paused timer preserved; Saved receipt and verified schedule available; restart did not replay an old reveal. |
| Remote mutations by this test | **0 creations, 0 edits, 0 deletions**. Saved-operation count unchanged. |

Private-safe result receipts: [first event](../artifacts/day-clock/repair/installed/existing-event-first.json),
[second event and refresh](../artifacts/day-clock/repair/installed/existing-event-second.json),
[shared Calendar](../artifacts/day-clock/repair/installed/shared-calendar.json).
Real populated screens were inspected without saving their private account labels,
event titles or contents into shareable screenshot evidence. Result receipts contain
aggregate checks, not private event identities or endpoints.

**Scope:** live Google reading/reveal and refresh passed for both pre-existing saved
events. New-event creation in 2029 was **not live-tested**, following the owner's
choice. Its deterministic creation/readback coverage is recorded separately above.
Physical Narrator, hardware input and actual DPI/resume acceptance remain distinct.

## Files and handoff

Runtime changes are limited to the Day Clock controller/screen/dial/form, creation
status text, the draft view preference and the shared reader's guarded reveal
coordination. Existing test helpers accept real height/device ratio; two new test
files contain the repair cases. Generated screenshots, logs, command receipts,
comparison source and manifests remain in ignored local artifact/tool directories.

| Evidence category | Current status |
| --- | --- |
| Source implementation / fictional provider acceptance / host visual review | Complete as recorded above |
| Signed configured local package | Installed, **1.0.0.2029**, status Ok; 76 payloads verified |
| Local install / profile backup and preservation fingerprints | **Passed**; 7 files preserved through installation; task/history/settings/full timer fingerprints unchanged after testing |
| Installed 2029 layout and existing saved events | **Passed** normal/maximized UI, both live read/reveals, manual refresh and shared Calendar checks |
| New live Google creation | **Not tested by owner choice: existing events only**; no new event or replacement created |
| Physical Narrator, actual DPI/resume and hardware input acceptance | Pending; host semantics and simulated DPI are supporting evidence |
| External publication | Not performed |

The authorized installation and existing-event acceptance are complete. Existing
seven-date and owned-calendar limits remain explicit. No live creation test is
pending within the owner's selected scope; a future creation test would need a
separately authorized disposable owned calendar and named test event.
