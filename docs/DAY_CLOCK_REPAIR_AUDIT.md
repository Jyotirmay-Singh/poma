# Day Clock repair audit

Inspected on 10 November 2026, Asia/Calcutta, after the owner reported that the implemented Day Clock differs from the selected concept and a created event is missing from the dial. This is an audit and handoff for a repair session; production source was not changed. No event was created, edited or deleted, no Google consent was changed, and calendar selection was left unchanged. Poma's window was inspected at normal and maximized size and restored to its normal size on Day Clock.

**Inputs and current state**

- Current source HEAD: `26fb1ac` (Record installed Day Clock verification), with a clean tracked working tree before this audit.
- Running app selected through the Windows app inventory: `JyotirmaySingh.Poma.Desktop_kz516h6tttq8c!Poma`, one Poma window.
- Historical installation documentation identifies the configured local build as **1.0.0.2028** from runtime source commit `f9c849f`. This audit did not independently establish the current executable's file/package version: package queries were unavailable and the shell process inventory did not expose the UI's process. Verify the actual installed artifact in the appropriate Windows context during repair; do not assume a source build has updated it.
- The existing 709-test/168-feature-test results and prior live-acceptance limitations are recorded in DAY_CLOCK_VERIFICATION.md. They were read as historical evidence, not rerun or claimed as fresh repair results.

**Images the repair session must open**

1. [Selected visual target](design/day-clock-concept.png): the owner-selected conceptual Poma screen, with a full dial, substantial coloured event sectors, generous central time, a compact date/AM/PM toolbar and balanced Now/Next plus agenda at right.
2. [Original clock reference](design/day-clock-reference.png): conventional 12-hour sector-clock structure.
3. [Running normal-size Poma](design/day-clock-audit-2026-11-10-normal.jpg): approximately 1067×754 window, with no selected calendars and the dial extending below the viewport.
4. [Running maximized Poma](design/day-clock-audit-2026-11-10-wide.jpg): approximately 1536×840 window; the agenda is alongside the dial, but the bottom of the dial still lies below the first viewport.
5. [Existing populated Flutter render](../artifacts/day-clock/session3/screenshots/viewing/ordinary-1440-100-dark.png): a fictional-provider populated screen, 1440×1100; it demonstrates that the current painter already draws filled sectors.
6. [Existing fictional 10–11 PM result](../artifacts/day-clock/session3/screenshots/creation/gesture-clock-colour.png): historical deterministic save-to-sector evidence; it is not live Google acceptance.

The new audit screenshots contain no account identifiers or event contents. The Calendar settings screen was inspected but not saved as shareable evidence because it displayed the account identifier.

**Observed missing-event boundary**

The running Day Clock stated **No calendars selected** and **Choose and save calendars before events are loaded**. Its accessibility state reported **0 timed events** and an availability-unknown empty agenda.

Opening Choose calendars showed Calendar settings with **Viewing: Connected**, **Task creation enabled**, and the message:

> Saved to Google Calendar. Its calendar is hidden. Choose Show calendar to display it.

This is current in-app evidence that selection/visibility is blocking display. It does not independently prove a new Google API save/readback in this audit, and it does not establish that every missing event has the same cause. Reconcile any specific existing saved operation by its account/calendar/event IDs before creating another event or diagnosing the writer as broken.

The earlier installed test recorded expired access, but today's running UI is connected and creation-enabled. Do not treat the earlier expired-access observation as the current root cause.

**Source evidence and the remaining UX gap**

- `mobile/lib/application/calendar_event_creation_controller.dart:516` checks whether the created event's calendar is selected. Lines around 521 and 550 explicitly explain a saved event with a hidden destination.
- `mobile/lib/application/calendar_event_creation_controller.dart:568` implements `showCalendar`. It merges the target into `reader.selected` and calls `reader.select`; it does **not** browse to the event's date/AM-PM period or select its sector.
- `mobile/lib/ui/day_clock_task_form.dart:233` offers **Show calendar** in the Saved dialog when its destination is hidden. Once the dialog is closed, there is no equivalent prominent event-specific **Show on Day Clock** action at the top of Day Clock.
- `mobile/lib/application/day_clock_controller.dart:177` submits a reviewed task and returns the result. It does not navigate to the saved event's start date/half. `_sync` near line 299 projects the currently browsed date/half from the shared agenda.
- `mobile/lib/ui/day_clock_screen.dart:740` puts task drafts/operations in a lower expansion panel after the dial, agenda and coverage sections. Recovering the saved operation is less discoverable when those sections are already far below the first viewport.
- `mobile/lib/ui/settings_screen.dart:683` labels the calendar-selection action **Save selection**. The current user workaround is Calendar → Calendar settings → select the saved event's destination → Save selection → Day Clock → the event's local date and correct AM/PM half → refresh if necessary. The Saved dialog's Show calendar can perform the selection portion, but it still does not choose the event's date/half.

The earlier requirement deliberately preserved selection while permitting writes to an owned calendar that was not selected for viewing. That explains how a saved task can coexist with an empty clock. The repair must complete the product experience rather than weaken authorization or recreate the event.

**Observed visual boundary**

At normal size, a large status panel and separate date controls push the dial down; the bottom of the full circle and the agenda require scrolling. At maximized size, the side-by-side layout appears but the circle is still below the available viewport. This differs from the selected concept's balanced, complete first-screen dial.

Relevant implementation:

- `mobile/lib/ui/day_clock_screen.dart:538` renders the status before the controls; around line 632 it creates the dial/agenda layout.
- `mobile/lib/ui/day_clock_screen.dart:700` requires **900 logical pixels of content width** for two columns. A roughly 1067-pixel whole window loses the rail and page margins first, so this branch is not reached.
- `mobile/lib/ui/day_clock_dial.dart:115` chooses `min(620, constraints.maxWidth)` for the square dial. Available viewport height is not part of this calculation.
- `mobile/test/calendar_creation_ui_test.dart:50` mounts a **1100-pixel-tall** viewport. Existing 1440×1100 captures cannot establish that the main circle is visible in a 1067×754 or 1536×840 installed window.

The painter already supports substantial sectors, Google colour resolution, measured numeral geometry and a separate hand layer. Preserve working geometry and data identity. The main confirmed presentation defect is composition and sizing at actual desktop heights, combined with an empty-data state caused by selection.

**Repair contract**

1. Add a clear **Show on Day Clock** outcome for a saved event, exposed in the Saved dialog and a persistent, compact main-page receipt after closing it. One action must verify account authority, include the target calendar without discarding other selections, refresh through the shared reader, browse to the event's local start date and half, select its stable identity and reveal its agenda row. It must never POST a second event.
2. Make the save-to-display expectation explicit in the form, for example a clearly labelled **Show on Day Clock after saving** choice. A default-on checked choice can be reviewed with the rest of the form; a deliberate unchecked choice must retain a truthful Saved/hidden explanation and an obvious Show action. This is a UI decision to resolve in the repair plan, not permission to silently undo later manual selections.
3. Coordinate refresh completion, race guards and the view transition. Do not jump back to the created event on every subsequent minute/network update. Preserve manual browsing after the one-time reveal. If refresh fails after Google accepted creation, retain Saved and a retry/show action.
4. Outside retained coverage, cancelled/deleted events, changed account and permission loss need honest, non-destructive explanations. Do not fabricate a verified sector from a local draft or duplicate receipt/provider entries.
5. Fit the full clock and primary controls into the first viewport at ordinary text sizes for actual desktop windows. Account for both content width and available height. Move secondary diagnostics/receipts below or into compact disclosures; keep the essential connection/calendar-selection state clear. Use a lower content-width split when measured usable dial/agenda widths allow it. Preserve readable minimum sizes and stack/scroll accessibly at genuinely narrow/enlarged-text layouts.
6. Match the selected image's proportions, centre treatment, short sector labels, restrained starfield, filled wedges, shared colour swatches, Now/Next and agenda hierarchy using actual Flutter components. Compare using the same fictional event set and date/half. A blank real schedule is not valid evidence of populated visual fidelity. Actual Google-assigned event colours may differ from the concept palette; do not silently recolour them.
7. Keep existing creation IDs, ownership boundaries, journals, caches, scope receipts and focus scheduling intact. Do not clear credentials/data, broaden permissions or replace stable mechanisms to solve a visibility/layout problem.

**New acceptance scenarios**

- Begin with **no calendars selected** and the clock on a different date or AM half. Create a future task at **10–11 PM** on an owned calendar, finish the explicit save/show choice, and prove one remote event, one PM sector, one agenda row, correct date/half and visible selected event without a manual settings detour.
- Repeat with another calendar already selected; preserve it while revealing the new target. Repeat from the Saved receipt after closing/reopening the form or page, including an existing saved operation. Showing never creates another event.
- Exercise a pending earlier refresh, post-save refresh failure/recovery, target removed, consent/account changes, rapid double action and out-of-window creation. Keep Saved distinct from display/freshness state.
- Capture full first viewports at **1067×754**, **1280×800**, **1536×840** and the concept's **1536×1024** comparison size. State whether these are whole-window or Flutter client dimensions, actual text scaling and display DPI; do not silently substitute a tall viewport or cropped full-page render. Add narrow and 150%/200% text/high-contrast reflow checks separately.
- Inspect before/after images with the matching fictional Lunch, Deep work, Travel, Meeting and Reading example, plus the new 10–11 PM event, dense overlaps, empty and stale states. Use current screenshots, not only historical captures.
- Run meaningful new failing-first regression cases and affected existing checks; compile the corrected Windows candidate. Keep live Google, host renders and installed-app evidence distinct. Once a local update is authorized, verify the exact new installed build and the UI the owner actually opens.

No new tests were run in this audit because production behavior was not changed. Historical tests and source were inspected to identify the coverage gap. The next repair session must implement and verify the new acceptance cases.
