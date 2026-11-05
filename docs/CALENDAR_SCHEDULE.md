# Calendar schedule in the main window

Windows Calendar opens on **Schedule**, with **Focus blocks** and **Calendar
settings** as explicit section destinations. Settings and native agenda/tray
setup actions open Calendar settings. Completing a reviewed focus operation
opens Focus blocks. Ctrl+1–5 follow the visual navigation order: Focus, Tasks,
Calendar, History / Insights, Settings. Android and iOS keep their four offline
destinations.

The sufficiently wide layout shows a rolling **Next 7 days** timeline, anchored
to the reader's first local date rather than Monday. **Day** offers bounded
previous/next controls. Normal desktop windows show the seven-day grid; compact
windows default to Day, and enlarged text defaults to **Agenda**. View controls
and the calendar frame remain available before calendars are selected. Unloaded
cells say **Not loaded**, with an explicit availability-unknown notice. The
seven-day timeline is disabled where its columns would be unreadable.
Today returns to the first retained date. Month and unrestricted navigation are
deferred; no reader, cache or credential scope is expanded.

The existing calendar reader remains the only source of Google snapshots for
both the main window and compact native tray agenda. Status and per-source
freshness/coverage distinguish verified empty days from missing, partial or stale
data. Refresh keeps retained events visible. Viewing requires no focus-write
consent. Only retained Google events become schedule tiles; local drafts and
uncertain write operations stay in Focus blocks, avoiding journal/snapshot
duplicates.

Presentation identity combines calendar ID, event ID, recurring series ID and
original instance start. Titles and display names are not identifiers. Timed
events preserve their UTC instants. Date-only events preserve the original dates
and exclusive end; their rendering uses device-midnight boundaries, including
daylight-saving changes. Overlaps use side-by-side columns. Source color is
paired with contrasting text and a source label; event details retain full
Unicode titles, status and validated Open event / Join actions.

Event creation, rescheduling and resizing are disabled at the view, header,
body and individual-event levels. Creating, changing or deleting Poma focus
blocks continues through the existing preview, confirmation, ownership and
recovery flow. Schedule viewing never starts a timer or changes focus history.

The main page owns scrolling for notices, controls and the agenda. A bounded
400–640 logical-pixel viewport owns timeline scrolling. Controllers persist
through refreshes, timer rebuilds and Calendar section changes, and are disposed
with their page. Lock, account/scope invalidation, deselection and removed or
changed events invalidate open details and obsolete actions. Fictional preview
continues to use its separate native preview path.

Dates and weekdays use the device calendar locale independently of English
product copy. Times reuse the native Windows regional formatter, including its
12/24-hour choice. The Dart runtime obtains local timezone rules from Windows;
the existing resume/time/settings events refresh boundaries, formatting and
date-only presentation. No separate timezone preference or timezone database
owner is added.

Verification uses isolated fictional accounts/events in
`mobile/test/calendar_schedule_test.dart` and the existing reader, connection,
agenda, resilience, focus-block, navigation and mobile refinement suites.
Screenshot capture is opt-in with `POMA_SCHEDULE_SCREENSHOTS`; it uses fictional
data. Live Google consent/data comparison, installed-package behavior and native
screen-reader acceptance remain separate checks. The initial source-verification
step did not install or publish a release; the later owner-requested local
upgrade is recorded below.

## Verification — 5 November 2026

- Complete Flutter suite: **439 passed**, including calendar reading, connection,
  agenda, resilience, write consent, focus scheduling, crash recovery, desktop
  navigation and mobile/offline refinement. [Final log](../artifacts/windows/schedule-review/flutter-final.log).
- Final Schedule suite: **20 passed** after high-contrast grid styling. Coverage
  includes stable/recurring identity, exact UTC and date-only DST mapping, range
  bounds, all six width/text combinations, dark/high-contrast rendering, overlap
  geometry, disabled gestures, retained refreshes, lock/deselection/disconnect
  cleanup, controller persistence and both shortcut paths.
  [Focused log](../artifacts/windows/schedule-review/schedule-final.log).
- Static analysis: **no issues**. [Log](../artifacts/windows/schedule-review/analysis-final.log).
- Windows release compilation: **passed**, 64.8 seconds, using Flutter 3.44.2 /
  Dart 3.12.2. [Build log](../artifacts/windows/schedule-review/windows-build.log).
  This verifies compilation, not signing, installation or live Google acceptance.
- Fictional-data screenshots were rendered and inspected in light/dark and high
  contrast, including 200% text. The host font fixture lacks full Unicode/emoji
  fallback; exact Unicode model/UI text assertions pass. Native font and screen
  reader acceptance remain separate.
- The full run exposed a pre-existing cancellation gap after asynchronous focus
  time preflight. Create/edit now retain and recheck the original cancellation
  generation before starting a mutation; the existing cancellation regression
  test passes. The old connection-settings test now uses its explicit section.
- The original package MIT text is preserved in both source and bundled legal
  notices. Dependency resolution added four packages and upgraded no existing
  package or SDK. Ordinary UI and feature documentation contain no upstream
  GitHub links or promotional branding.

## Initial installed local update — 5 November 2026

At the owner's request, the installed Windows app was upgraded in place from
**1.0.0.2021 to 1.0.0.2024** using the same package family, publisher, signing
certificate and compiled Google Desktop client. The new installer was signed
with the existing trusted certificate; no certificate trust or Windows security
setting was changed. All 56 packaged payload hashes passed the package audit.

Poma was quit through its own Quit action before a private, owner-only LocalState
backup. All five saved data files matched that verified backup after installation
and before the new app launched. All 56 installed payload hashes also matched.
The backup and its detailed data manifest remain outside the repository.

The updated app was reopened and its main **Calendar → Schedule** screen was
observed. It retained its saved Google connection and showed **No calendars
selected**, preserving the prior selection. No calendars were selected on the
owner's behalf and no focus/calendar events were created or changed. The app
was left running on Schedule. Event loading still requires an explicit calendar
selection; this observation is not live-event comparison or screen-reader
acceptance.

The running executable resolved to the installed 2024 WindowsApps package, with
Flutter and SQLite loaded from that same package. See the
[installed-update receipt](../artifacts/windows/schedule-review/installed-update.json),
[package audit](../artifacts/windows/schedule-review/update-package-audit.json) and
[runtime observation](../artifacts/windows/schedule-review/installed-2024-runtime.json).

## Visible calendar grid — installed 1.0.0.2025

The owner reported that the installed application still did not look like a
calendar. Build 2024 hid the calendar frame until calendar selection and used
Agenda at common desktop widths. Build **1.0.0.2025** keeps view controls and the
calendar frame visible before selection. At normal text size, content widths
of at least 700 logical pixels default to **Next 7 days**; narrower windows
default to **Day**. Enlarged text defaults to Agenda. The heading and controls
were compacted so the desktop grid begins within the first screenful.

The focused Schedule suite passed **26** checks, including six new width/text
cases without selected calendars. All **173 affected regression checks** passed,
and static analysis found no issues. These runs overlap; their counts are not
additive. The earlier full-suite result above belongs to the preceding build.
See the [grid tests](../artifacts/windows/schedule-review/grid-tests.log),
[regression log](../artifacts/windows/calendar-grid-review/regression.log),
[analysis](../artifacts/windows/calendar-grid-review/analysis.log) and
[configured build log](../artifacts/windows/calendar-grid-review/build.log).

Poma was quit cleanly, its complete closed LocalState was backed up privately,
and the signed 2025 package was installed over 2024 using the existing trusted
signer and identity. All **five data files** were unchanged before launch; all
**56 installed payload hashes** matched the audited build. No certificate trust,
Google configuration, consent scope or calendar selection was changed.

The registered installed app was reopened and **Calendar → Schedule** was
visually checked. **Next 7 days**, all seven date columns and the timed grid
were visible immediately, alongside **No calendars selected**, per-day
**Not loaded** labels and the explicit availability-unknown notice. The app
was left open on this screen. Actual event display still requires the owner to
choose and save calendars; no live event comparison is claimed.

See the [installed-grid receipt](../artifacts/windows/calendar-grid-review/installed-update.json)
and [signed package audit](../artifacts/windows/calendar-grid-review/package-audit.json).
