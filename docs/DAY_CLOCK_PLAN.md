# Day Clock — Session 1 plan

## Approved Session 3 completion — 9 November 2026

Implement the owner-approved final refinement and deterministic verification
plan against the existing Session 1/2 working tree. Preserve filled sectors and
the celestial identity; measure enlarged numerals, quiet the healthy status and
agenda, group form details and present one immutable Saved summary. Isolate hand
painting from static dial/background layers, honour reduced motion and restore
keyboard focus. Extend actual-gesture creation, lifecycle/recovery, accessibility
and visual matrices, then run analysis, full Flutter/native regressions and the
established Windows Release compilation. Record exact evidence and source/build
identity in DAY_CLOCK_VERIFICATION.md and DAY_CLOCK_PROGRESS.md.

The owner selected fictional deterministic providers only. Live Google,
installed-app and physical assistive acceptance remain pending; installation,
publishing and personal-calendar tests are separate. Session 3 starts with a fresh
116-test focused pass and matching Session 2 source/runtime/capture hashes.

Session 3 outcome, 10 November 2026: **709 Flutter tests passed**, final **168-test**
feature/capture run passed, **284 actual Flutter PNGs**, clean analysis/formatting,
**4/4 native executables / 331 assertions**, and successful Windows Release
compilation. Source/build hashes, fixes, review captures and pending live,
installed and assistive acceptance are recorded in DAY_CLOCK_VERIFICATION.md and
DAY_CLOCK_PROGRESS.md. Source is ready for review; no installation or publishing
was performed.

Later follow-up, 10 November 2026: the owner requested commit/push and explicitly
authorized a local update for testing. Source was pushed as `f9c849f`; configured
Poma **1.0.0.2028** was installed with data preservation and its Day Clock/form
were exercised. The detailed installed observations and remaining live Google
and assistive acceptance are in the verification report's local application
follow-up. This extends the earlier installation boundary; no publishing or
personal-calendar event testing was performed.

## Approved Session 2 implementation — 9 November 2026

The owner approved connecting the existing form through an independent owned-
calendar creation controller/writer/journal, retaining Session 1's appearance and
shared reader. Unfinished forms persist on Keep draft and before consent; reviewed
operations always persist before transmission. Runtime drafts otherwise remain
in memory. Session 1's completed plan and historical evidence follow below.

Implementation uses the existing Desktop OAuth/DPAPI credential owner, exact
read/focus/creation capability combinations and separate receipts. Creation adds
only `calendar.events.owned`; focus calendar provenance and ownership remain
unchanged. The same native calendar owner holds a separate leased creation
journal with stable `pomadc` event IDs, immutable reviewed payloads, separate
markers, readback/retry and lifecycle invalidation. No queued draft sends itself.

The form saves ordinary events using explicit endpoint dates, uniquely resolved
future device-local times, Google palette IDs and Busy/Free. Calendar defaults
apply to visibility/reminders. Only the final Add to Google Calendar action sends.
After verification, a refresh begins after any earlier in-flight reader refresh;
only shared provider snapshots become sectors. Saved remains Saved if refresh
fails, with hidden/out-of-window explanations and a validated event link.

Verification includes permission combinations/decline, actual child-process
exits, durable/native storage barriers, duplicate prevention, exact 22:00–23:00
projection, responsive production-widget captures, full Flutter regressions,
analysis and Windows compilation. Actual outcomes, source/build identity and
remaining live/installed/assistive checks are recorded in DAY_CLOCK_PROGRESS.md.

Session 2 outcome: **657 Flutter tests passed**, clean analysis and formatting,
**4/4 native executables** (331 assertions), **18 integration captures** with
representative visual review,
and a successful Windows Release compilation. Source/build hashes and exact
evidence are in the progress log. Live Google consent/create/readback and
installed/physical assistive acceptance remain unrun; installation/publication
were not performed.

Approved 9 November 2026. Authority: DAY_CLOCK_FEATURE_BRIEF.md and the selected
DAY_CLOCK_VISUAL_DIRECTION.md. Starting source: c3625a68774f0478146f4abb84e5b039d52465f9.

## Agreed scope

Windows Day Clock destination with shared real Calendar viewing, independently
testable half-day projection, accessible agenda and complete Add task form.
Google creation/consent is Session 2. Drafts live only for this application run.
Ctrl+1–6 follow Focus, Tasks, Calendar, Day Clock, History, Settings. Destination
IDs remain stable; Day Clock is 5. Mobile keeps four offline destinations.

## Repository map and implementation boundaries

- `AppShell` and `PomaApp` both bind desktop shortcuts. `DesktopController` owns
  navigation/lifecycle; it will also own Day Clock browsing and draft state.
- `CalendarReadController` owns selected calendars, seven-date retained snapshots,
  cache leases, five-minute refresh and minute presentation updates. Reuse this
  owner; no second polling, cache or credential owner.
- `CalendarAgendaController` supplies status, regional formatting, source labels,
  Now/Next and validated links. Extract shared identity/details presentation.
- `CalendarConnectionController` owns Desktop OAuth and protected credentials.
  Its exact scope/receipt checks remain unchanged in Session 1.
- `GoogleFocusWriter` accepts only verified Poma-created focus operations. Generic
  creation will have separate ports, operation identity and capability receipts.
- Reuse `PomaPage`, `ScreenHeading`, `PomaSpace`, `PomaLayout`, `PomaType`,
  `pomaTheme` and the still `PomaBackdrop`. Fonts are already bundled/licensed.
- Extend event/cache data with optional colour IDs and a retained Google palette.
  Colours fail independently of schedule snapshots. Existing caches remain valid.

## Clock contract

Pure `DayClockWindow` / `DayClockProjection`: exact UTC clipping and local civil
angles, AM midnight–noon / PM noon–midnight, exclusive ends, stable identities,
concentric overlap lanes, separate all-day list, chronological agenda and merged
UTC-duration totals. Angle is -pi/2 + local minutes within half * 2pi/720.
Split at offset transitions, mark skipped/repeated wall-clock spans and retain
offsets; never assume 720 elapsed minutes. Manual date/half stays fixed, including
an explicit unloaded state after coverage rolls forward. Now follows real time.
Only the actual current half shows a hand; hand and sectors share the scale.

Substantial sectors, opaque hub (~22% radius), conventional numerals, outlined
slender hand. Up to four visible lanes with accessible overflow and selected-event
highlight. Full details always remain in the agenda. Wide content >=900 at <150%
text uses two columns; otherwise stack/scroll. Light/dark/high contrast and
100/150/200% text retain Poma's tokens and meaningful selection beyond colour.

## Creation foundation

Labelled Add task and empty-dial prefill (five-minute snap, one-hour initial
duration). Title, endpoint dates, explicit AM/PM times, device timezone, elapsed
duration, verified account, owned destination including primary, supported Google
colour ID and Busy/Free. Optional explicit selected-local-task title association.
Validate future start, positive duration, real dates, minute precision, access and
unique Windows wall-time resolution. Never infer an overnight manual endpoint.
Known overlaps are advisory; incomplete/stale/out-of-window data is unknown.
Raw fields survive dismissal/navigation/errors during this run. Lock hides
sensitive content; account changes never silently transfer a draft's authority.

Separate draft/review/result and writer ports; final Add to Google Calendar stays
visible but unavailable with an explanation. Production has no generic writer.
Session 2 uses colour-ID creation with eventLabelVersion=0, not label-ID semantics.

## Evidence and acceptance

Baseline: 88 existing calendar schedule/read/desktop tests passed before edits.
Add pure projection, reader/cache/palette, lifecycle, form and keyboard tests,
including 22:00–23:00, DST gaps/folds, dense overlap and no-write assertions.
Render production Flutter components/fonts with isolated fictional fixtures at
640/1080/1440 widths, 100/150/200% text, light/dark and representative high contrast.
Review ordinary/crowded schedules, selected event and form; refine actual widgets.
Run focused/full Flutter suites, analysis, formatting, native checks and Windows
release compilation. Save logs/captures in artifacts/day-clock/session1/.
Installation/publication/live writes/physical assistive checks are separate.

## Session 1 outcome

Completed against this plan; the full activity log, exact changed-file inventory,
83 actual Flutter captures, final source/build receipt and Session 2 implementation
checklist are in DAY_CLOCK_PROGRESS.md. Final verification: 599 Flutter tests
(58 new Day Clock tests), clean analysis, 124 formatted Dart files, four passing
native test executables and a successful Windows Release compilation. Production
Google creation and consent remain disconnected as planned. No installation or
publication was performed.

Review refinements include explicit keyboard traversal, high-contrast selection,
readable unavailable actions, details near the dial, retained-draft time updates
from a new dial position, disconnect privacy and compaction when overlaps vanish.

## References and licensing

Consulted Sectograph (https://sectograph.com/), RoundCalendar (GPL-3.0,
https://github.com/miltolstoy/RoundCalendar), yumauri/sectograph (MIT), gcal-glance
(Apache-2.0), kalender (existing MIT dependency), and Flutter CustomPainter docs.
Independent implementation with Flutter primitives; no upstream code is copied.
Existing notices remain. Google references:
https://developers.google.com/workspace/calendar/api/v3/reference/colors/get
https://developers.google.com/workspace/calendar/api/v3/reference/events/insert

## Session 2 handoff contract

Add owned-calendar creation consent (`calendar.events.owned`) using the existing
credential owner; validate allowed capability combinations and separate receipts
without weakening focus ownership. Preserve working reading/focus on declined or
partial/wrong-account consent. Add protected account-bound draft/intent journal,
stable valid Google event IDs, separate generic markers, frozen reviewed UTC/zone
context, duplicate suppression and exact readback/recovery after timeout/conflict.
Never automatically replay offline drafts or compensate with deletion. Invalidate
stale submission authority on lock/disconnect/account/capability changes. Reconcile
the shared reader after save; distinguish Saved with refresh warning, hidden
target and outside-window saves. Live disposable-calendar verification is later.
