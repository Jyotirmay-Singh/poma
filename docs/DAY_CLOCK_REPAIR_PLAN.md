# Day Clock repair plan — 10 November 2026

Status: approved by the owner on 10 November 2026; implementation, deterministic
verification and the authorized local installation of **1.0.0.2029** are complete.
Both existing saved-event live Google read/reveals, manual refresh and installed
normal/maximized layouts passed. Tasks, history, settings and full timer state
match the pre-upgrade backup. The owner chose **Test existing events only**; no
Google event was created, edited or deleted. See DAY_CLOCK_REPAIR_VERIFICATION.md.

The baseline inspection below did not change source, calendar selection, consent,
Google events or timer state. The later authorized Show actions selected the saved
destination calendar. Poma is open on the repaired Day Clock with its timer paused.

## Independently established baseline

- Checkout: `D:/pomodoro`, HEAD
  `26fb1acfa26158942a53ba6da96b10048b0d418f`. No tracked changes at the start.
  The repair audit and its two screenshots were already untracked; preserve them.
- Running executable and installed package: **1.0.0.2028**, package status **Ok**,
  family `JyotirmaySingh.Poma.Desktop_kz516h6tttq8c`. All **76 installed payload
  files** match the existing 2028 candidate inventory. The existing private build
  configuration matches the installed public Calendar configuration; no values
  were printed or copied into shareable evidence.
- The attached selected concept is byte-identical to the repository concept.
  All six requested concept/reference/audit/historical production images were
  opened and inspected, together with current installed normal/wide views.
- Current installed UI: viewing **Connected**, task creation **Enabled**,
  **No calendars selected**, and a **Saved to Google Calendar / calendar hidden**
  notice. This differs from historical expired-access evidence.
- Read-only private journal/cache inspection confirms saved operation, event and
  destination identities agree; the journal matches the current UI account;
  destinations remain listed as owned; saved endpoints agree with frozen intents.
  The records are within the current retained dates, and at least one saved event
  is on a different date from the current view. Private identities, titles and
  endpoints are excluded from this report. This is local receipt evidence,
  **not fresh remote Google readback**.
- Fresh installed screenshots reproduce the cropped dial at the helper's reported
  whole-window sizes **1067×754** and **1536×840**. Those dimensions must not be
  confused with a Flutter client viewport or an independently measured DPI value.
- Three existing fictional-transport regressions passed: hidden-calendar selection
  preservation, refresh failure after Saved, and refresh after an earlier in-flight
  request. Existing creation fixtures start already browsing the destination date
  and PM and use 1100-pixel height; those passes do not establish the requested flow.
- Baseline evidence: `artifacts/day-clock/repair/baseline/baseline.json`,
  `installed-normal.png`, and `installed-wide.png` in the same directory.

## Confirmed causes and preserved mechanisms

1. `CalendarCreationController.showCalendar` only unions the destination into the
   reader selection. It does not choose the event date/half or select its identity.
   The creation controller correctly distinguishes Saved from hidden/refresh state.
2. `DayClockController.submitReviewed` does not perform a save-to-display transition.
   The Saved dialog has Show calendar; the main screen has no prominent persistent
   event-specific reveal action. The operation history is below the primary content.
3. `DayClockScreen` requires 900 content units for columns, after navigation/margins.
   Its heading, full status panel and separate controls consume height before the
   dial. `DayClockDial` uses width-only `min(620, maxWidth)` inside a scrolling page.
4. Filled sectors, exact projection, measured numeral clearance, stable overlap
   lanes, Google colour resolution, hit testing and hand repaint isolation already
   work. Repair their composition and relevant presentation; preserve those rules.

The inspection does not establish a failed Google writer, current remote deletion,
or stale credentials. No replacement event is warranted by the observed evidence.

## 1. Reproduce the owner's flow before changing production behavior

Add a focused failing regression using production form/controller/HTTP adapter and
the existing fictional transport. Start with no calendars selected and another
date/AM selected. Enter a future 22:00–23:00 task through actual form fields, use
the reviewed save/show choice, and assert one ordinary remote event, exact owned
destination/title/timezone/endpoints/duration, correct PM/date, one 600–660-minute
sector, one matching agenda item, selected styling and a visible selected row.

Add first-viewport geometry checks at realistic heights that fail on the old
composition. Parameterize capture helpers with height and pixel ratio instead of
making 1100 pixels the only desktop assumption. Retain useful existing tests.

## 2. Complete one explicit save/show transaction

- Add a default-on **Show on Day Clock after saving** choice to the reviewed form.
  It is a view preference, separate from the immutable Google event payload. If
  retained with a draft, use an optional backward-compatible draft field. Old saved
  operations must never auto-reveal merely because they were loaded or recovered.
- Add one account-scoped `DayClockController` reveal entry point for the post-save
  choice, Saved dialog and main-page receipt. It accepts a current persisted Saved
  operation and never calls create, submit or an insertion retry.
- Validate unlocked/current account and current journal membership before work and
  after each asynchronous boundary. Coordinate through the existing shared reader,
  its selection transition and `refreshAfterCreation`; await an older refresh and
  confirm a subsequent fetch. Add a small reader reconciliation helper only where
  existing methods cannot safely express this coordination.
- Verify the destination remains readable, preserve every other selected calendar,
  and include the destination only for this explicit action. Detect superseding
  account/calendar changes rather than reapplying an obsolete selection.
- Locate the shared-reader event by stable identity. Use its actual current local
  start to choose date and AM/PM, then select its sector and agenda row. Do not
  synthesize a confirmed sector from a draft or receipt when the reader lacks it.
- Use a reveal request token plus manual-browsing revision so a late result cannot
  override a subsequent Show, manual date/half/Now action, account change or lock.
  Minute ticks, ordinary refreshes, navigation and restart do not repeat a reveal.
- Signal selection to the screen once. Scroll the selected agenda row into its own
  visible area; in stacked layouts use the page scroll as needed. Keep stable row
  keys and restore sensible keyboard focus after closing the modal.

## 3. Keep Saved and display status independently visible

Place a compact persistent receipt near the top of the dashboard, using the latest
saved operation for the current account; keep all other operations in the existing
disclosure. It remains available after closing the dialog, leaving/reopening Day
Clock or beginning another draft. Include date/time, Saved, current display status,
**Show on Day Clock** and validated **Open in Google Calendar** actions.

Distinguish displaying/selected, hidden calendar, refreshing, refresh needed,
outside seven-date coverage, account unavailable, inaccessible calendar and an
event absent from a freshly verified snapshot. A failed refresh preserves Saved
and the Google link. Retained stale content remains labelled. Missing/inaccessible
events produce explanations rather than invented sectors. Repeated Show is safe.

## 4. Recompose the actual Flutter dashboard around usable width and height

Design direction: retain midnight `#0D1528`, opaque dial `#111C31`, panels/centre
`#18233B`, primary `#EDF2FF`, secondary `#B8C5DC` and lavender `#B9A7FF`, with the
existing pearl hand and still sky. Sora carries heading/numerals/time; Source Sans 3
carries controls and agenda. Keep Google colours authoritative.

The complete clock is the main visual element. A compact heading/date/controls area
sits above a dial and a readable side column, with receipt, Now/Next and agenda:

```text
Day Clock / date                  AM | PM   Now   Add task
compact connection / selection / refresh guidance
complete 12-hour dial            saved-event receipt (when present)
                                 Now / Next
                                 Agenda with visible selection
                                 secondary status/history disclosures
```

- Obtain bounded content width **and height** before entering a scroll view. Size
  the dial from both remaining height and its column width; keep every numeral,
  centre and circle edge inside the first viewport at ordinary desktop text.
- Start the two-column rule at **744 usable content units**: 400 for a readable
  dial, 320 for the agenda and 24 for the gap. Validate those minimums with actual
  font metrics/captures and raise the breakpoint if needed. At the normal audited
  width, the existing rail/margins leave roughly 802 units, so columns are feasible.
- Target a generous dial up to approximately 680 units when space allows. Use a
  bounded independently scrollable agenda on desktop so long schedules cannot
  enlarge/crop the dial. The agenda stays visible and all entries remain reachable.
- Keep essential setup/recovery guidance concise and visible; place coverage,
  totals and operation details in restrained disclosures. Avoid stacking several
  large banners above the clock. Preserve application storage/error notices.
- At genuinely narrow widths, insufficient height or enlarged text, use natural
  stacked scrolling with readable text and the existing practical control targets.
- Match the concept's filled sectors, short fitting labels, legible central time,
  restrained centre outline, slender hand, quiet AM/PM control, shared swatches and
  balanced Now/Next/agenda. Refine font/centre proportions through measured painter
  geometry and screenshots, retaining overlap lanes and hit-test agreement.

## 5. Verify behavior, visual fidelity and accessibility

- Cover another selected calendar, existing saved-operation reveal without insertion,
  closing Saved and using the receipt, earlier refresh in flight, failed post-save
  refresh/recovery, repeated Show, rapid double Save, account/calendar changes,
  removed/inaccessible events, out-of-window saves and manual browsing after reveal.
- Exercise actual local noon/midnight/overnight/timezone transitions and retain DST,
  palette, old cache, dense overlap and long-title coverage.
- Render production Flutter first viewports corresponding to whole windows
  **1067×754, 1280×800, 1536×840** and **1536×1024**. Record native chrome, Flutter
  client size, device pixel ratio and text scale separately. Include window-equivalent
  host renders; do not present a client-size render as an installed window capture.
- Use exactly the fictional Lunch 12:30–13:30, Deep work 13:30–14:30, Travel
  15:00–16:00, Meeting 16:30–17:30 and Reading 21:00–22:00 schedule, fixed at 15:20.
  Compare with the concept, iterate on avoidable differences, and also capture the
  new 22:00–23:00 event. Preserve exact geometry where the illustration is approximate.
- Include populated, empty, hidden, stale, creation, Saved and revealed states;
  light/dark/high contrast; 150%/200% reflow; keyboard/focus restoration; semantics
  and reduced motion. Keep physical Narrator acceptance distinct from host semantics.
- Run new/affected regressions, then the full Flutter suite, analysis, formatting,
  applicable native checks and the established configured Windows Release build.
  Record fresh results and exact source/runtime/capture hashes.

## 6. Prepare the concrete candidate, then request local-install approval

Use existing Desktop Calendar configuration, package identity and trusted signing
workflow. Prepare a higher-version candidate (expected **1.0.0.2029**, after checking
installed/candidate versions again), with package audit, valid signer and hashes.
Do not replace the installed app before the owner approves the tested candidate.

After that approval, use the existing clean-close/private-backup/in-place-upgrade
process, compare tasks/history/settings/full timer fingerprints and installed
payloads, and inspect the actual installed layout. First read/reveal the owner's
already-saved operation through its existing identity; never create it again.

Live new-event testing requires a specifically authorized disposable owned calendar
and named test event. Until supplied, complete fictional-provider creation tests
and authorized existing-event reading independently. If live access requires user
authentication, identify the exact pending acceptance step without weakening consent.
No external publication is part of this repair.

## Expected source and evidence changes

Primary: `day_clock_controller.dart`, `calendar_event_creation_controller.dart`,
`day_clock_screen.dart`, `day_clock_task_form.dart`, `day_clock_dial.dart`; narrowly
scoped reader/domain/token changes if required by the transactions/layout above.
Preserve credentials/receipts, journals, stable IDs, focus ownership and existing
timer/task/history behavior. Add no second reader, permission expansion or cache reset.

Extend existing creation/Day Clock fixtures and tests; add focused repair tests and
capture support. Keep generated evidence under `artifacts/day-clock/repair/`.
Create `docs/DAY_CLOCK_REPAIR_VERIFICATION.md` with confirmed causes, changes, exact
identities, fresh results, matching before/after screenshots, full save/display result
and separate installed/live/assistive status. Append repair results to the existing
progress/verification/plan documents without rewriting their historical evidence.

Success means a complete readable first-screen clock and an explicit save/show
action producing **one event, one correctly placed sector and one visible selected
agenda item**, with truthful recovery and no repeated creation.
