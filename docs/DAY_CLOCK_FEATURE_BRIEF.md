# Day Clock: current feature brief

Updated 9 November 2026. This is the current owner-requested scope for the next three implementation sessions. It adds task/event creation to the earlier clock-view plan. No Day Clock feature, Google consent change or live event creation has been performed by writing this brief.

The requested result is a Windows Day Clock tab, compatible with the existing Poma app, with a beautiful 12-hour filled-sector calendar, event colours, a current-time hand, and an Add task flow that saves a timed event to Google Calendar. A task scheduled from 10:00 PM to 11:00 PM must become a real one-hour Google Calendar event and appear at 10–11 on the PM dial.

**Authority and starting evidence**

Read the repository instructions, RTK.md, UI_DESIGN_SYSTEM.md, CALENDAR_SCHEDULE.md, DAY_CLOCK_VISUAL_DIRECTION.md and CIRCULAR_CALENDAR_RESEARCH.md. Inspect current source before implementing; historical verification results apply only to their recorded changes/builds. The current code is authoritative about what already exists.

The owner-provided reference is [day-clock-reference.png](design/day-clock-reference.png); the selected generated design concept is [day-clock-concept.png](design/day-clock-concept.png). The concept is a visual reference with fictional events, not an accurate or verified production renderer.

The latest creation request supersedes the earlier Day Clock read-only restriction for the new feature. Existing focus scheduling keeps its own ownership and management boundaries. Old focus specifications must not be interpreted as a permanent prohibition on implementing the newly requested, separately consented event-creation capability.

**Visual and clock contract**

- Use substantial filled clock sectors with a small opaque centre and conventional 12/3/6/9 placement. Preserve the selected celestial style, Sora/Source Sans 3 typography, existing spacing/corner/control tokens, opaque reading surfaces and still star background.
- The dark palette uses background `#0D1528`, dial `#111C31`, panels/centre `#18233B`, primary text `#EDF2FF`, secondary text `#B8C5DC`, and outlined pearl-white hand `#F4F7FF`. Example event accents are lavender `#B9A7FF`, mint `#64D8CB`, cyan `#6CCBFF`, amber `#F2C078` and rose `#E89AB5`. Preserve Poma's light and high-contrast equivalents. Actual Google event colours remain authoritative when explicitly assigned.
- Show an explicit AM/PM selector: AM is midnight–noon, PM is noon–midnight. Each ordinary clock hour spans 30 degrees; the schedule hand uses the same scale. Keep gaps and actual start/end positions; do not normalize durations to fill a pie.
- Follow today/current half by default. Manual date/half selection stays stable across refreshes. Now resumes following time across noon and midnight. Show the actual-time hand only in the real current half-day.
- Clip events to the selected window; retain full details and identity for cross-noon, overnight and multi-day events. Use stable overlap lanes, accessible overflow handling and a chronological agenda. All-day items sit outside the timed dial.
- Put full titles and exact times in the agenda/details; label sectors only where text fits. Link sector and agenda selection. Include current/next summaries when following Now, keyboard/touch equivalents for hover, source labels, validated Open event/Join actions, and totals that merge overlapping intervals.
- Wide windows place the dial beside the agenda; narrow/enlarged-text layouts stack and scroll. All controls and forms support keyboard, visible focus, screen-reader semantics, reduced motion and 100%/150%/200% text. Render and inspect actual Flutter screens.

**Viewing, colours and synchronization**

Reuse the existing account, selected calendars, reader and cache. They currently provide a rolling seven-date window, five-minute network refresh and minute-level presentation updates. The hand must not create network or storage traffic. Preserve missing/partial coverage, last-successful-refresh, offline/stale indicators and retained events while refreshing.

Retain individual event `colorId` values with backward-compatible cache changes and resolve Google's actual palette. Use source-calendar colour when there is no event override. A creation colour picker must display supported Google palette IDs/swatches; arbitrary hex strings are not Google event colour IDs. Respect the current API's colour/label-version semantics. Keep per-event selection visible across all colours and high contrast.

Use exact UTC instants, exclusive interval ends and existing local-time rules. Handle repeated/skipped hours explicitly; do not assume each local half-day is 720 elapsed minutes. Keep bounded browsing honest about unloaded dates. If creation accepts a future date outside the retained reader window, saving can still succeed: expose the Google event link and explain that it lies outside current clock coverage, instead of pretending it was not saved.

**Add task experience**

Provide a prominent but restrained Add task button. Also support clicking an empty dial position to prefill the selected date/half and a sensible editable start/duration. A range-drag enhancement may be included if it does not compromise reliable selection or accessibility; explicit time fields are always available. A dial gesture opens the form and never creates an event by itself.

The form contains title, date, explicit start/end with AM/PM, visible endpoint dates and current device timezone, duration, target Google calendar, optional supported event colour and Busy/Free. An existing Poma task may supply a title through the established local association pattern. Treat the requested time block as an ordinary Google Calendar event, not a Google Tasks API item or a completed Pomodoro. Do not automatically change task completion/history or start a timer.

Make the account and actual target calendar visible. Offer eligible owned calendars including the user's primary calendar. Remember a destination only within its verified account; require a valid target at save time. Validate title, strictly positive duration, future-start policy, supported time resolution and access. Support explicit overnight endpoint dates rather than silently rolling an earlier end time into tomorrow. Reject nonexistent/ambiguous local times with actionable guidance, following the existing scheduling policy.

Show known selected-calendar overlaps as advisory information. Missing/stale coverage means availability unknown. Let the user make an informed overlapping booking. The final form/review action, labelled Add to Google Calendar or equally clear wording, explicitly authorizes that event creation; preserve draft fields across first-time Google consent and recoverable failures.

After a verified save, show success and refresh/reconcile the shared reader so Calendar and Day Clock agree. If the target is not currently visible, offer to show its calendar without silently changing unrelated selections. Prevent duplicate pending/confirmed renderings. A successful save followed by refresh failure remains Saved with a refresh notice, not a failed creation.

**Creation permissions and existing writer boundaries**

Source review found `focusWriteScope = calendar.app.created` in `mobile/lib/domain/focus_blocks.dart`. `GoogleFocusWriter` validates a specific Poma-created calendar and focus-operation ownership. It already creates ordinary `eventType: default` events, but it is not a general writer for primary or arbitrary calendars. `CalendarConnectionController` also has exact scope-set checks and persisted focus-write receipts.

Plan a distinct event-creation capability with the narrowest scope required for the chosen destinations. For the owned-calendar scope above, Google's `calendar.events.owned` supports creation on calendars the user owns, including primary. Shared calendars may still be viewed; adding shared-calendar writes would require a deliberately broader destination/scope design, not an accidental permission escalation.

Reuse the existing Desktop authorization and credential owner. Request creation access only when the user enables it. Verify account identity and candidate credentials; preserve working reading and focus behavior if consent is declined or incomplete. Adapt capability-specific scope/receipt validation with tests; do not simply append a scope or remove ownership checks. Installed-app OAuth follows the existing Desktop flow, not a web application's incremental-authorization assumptions. Document any required Google project Data Access changes. Use app-owned credentials, not a Codex connector's tokens.

Implement a separate or carefully factored creation writer/operation type rather than allowing generic events through focus ownership checks. Preserve existing focus edit/delete rules. The new requested operation is ordinary one-off event creation; invitations, sharing, arbitrary remote editing/deletion and recurrence authoring are separate scope.

**Durability and truthful results**

Persist the exact reviewed create intent before sending, with its original account/calendar, payload, operation identity and a stable valid client-generated Google event ID. Keep generic event markers distinct from focus ownership markers. Freeze resolved UTC instants/offsets at confirmation.

Disable double submission. Reuse the same event ID when checking/retrying an uncertain operation. On timeout or conflict, read back and verify matching operation identity/payload before declaring success; never adopt an unrelated existing event. Account/calendar/capability changes and lock/disconnect must invalidate stale submission authority without blindly undoing an event Google may already have saved.

Offline creation preserves a clearly labelled draft. Do not display an offline draft as Google-saved or silently publish it later without renewed review. Distinguish draft, sending, checking/unknown, saved and failed states. Reuse proven journal/recovery mechanisms where compatible, with backward-compatible local persistence. No automatic compensating delete.

**Required acceptance evidence**

| Scenario | Expected result |
| --- | --- |
| Future selected date, task 10:00–11:00 PM | One ordinary event at 22:00–23:00 in the displayed device timezone; correct owned destination and title; one 10–11 PM sector; one agenda item. |
| Save twice / timeout after server commit / restart and retry | One remote event; stable ID; truthful checking/recovery states and no duplicate sector. |
| Consent declined / partial grant / changed account / read-only target | No unauthorized submission; draft preserved as appropriate; ordinary reading and existing focus scheduling retain their documented behavior. |
| Explicit colour / calendar default / old cache | Correct actual swatch and fallback; old data remains readable. |
| Noon, midnight, overnight, recurrence, DST and resume | Correct clock projection and exact times; stable manual browsing; invalid create times rejected clearly. |
| Target hidden / outside reader window / refresh fails after save | Saved event remains identified as saved, with a way to open/show it and an honest coverage/refresh explanation. |
| Dense overlaps, empty/partial data, light/dark/high contrast, 200% text | Readable actual Flutter render, complete accessible agenda and usable creation form. |

Use mocked provider/store tests and actual Flutter visual captures, then an authorized disposable Google test calendar for live create/readback evidence when available. Only create/delete specifically authorized test events; no development test should silently write to the owner's personal schedule. Complete code, tests and build independently of unavailable live consent; mark live/installed/assistive checks pending until observed.

Maintain DAY_CLOCK_PLAN.md and DAY_CLOCK_PROGRESS.md across sessions, and produce DAY_CLOCK_VERIFICATION.md in Session 3. Include file changes, source/build identity, test evidence, screenshots and unresolved acceptance items. Build through the repository's established workflow; installation and publication remain separate actions.

**Official API references checked for planning**

- [Create an event](https://developers.google.com/workspace/calendar/api/v3/reference/events/insert): ordinary timed events, target calendar, authorization and valid client event IDs.
- [Calendar API scopes](https://developers.google.com/workspace/calendar/api/auth): `calendar.events.owned`, read scopes and `calendar.app.created` cover different capabilities.
- [CalendarList resource](https://developers.google.com/workspace/calendar/api/v3/reference/calendarList): calendar identity, metadata and access roles.

GitHub reference projects and licensing notes remain in CIRCULAR_CALENDAR_RESEARCH.md. Use Sectograph/RoundCalendar as clock behavior references and Flutter/native primitives for Poma's implementation; qualify any actual upstream code reuse separately.
