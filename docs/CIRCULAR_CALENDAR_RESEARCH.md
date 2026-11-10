# Day Clock: circular Google Calendar research

Researched on 9 November 2026. This is a feasibility and implementation recommendation, based on public websites, GitHub repository metadata, selected upstream source files, and Poma's current source. No app feature was implemented, no upstream application was installed or executed, and no personal Google Calendar events were accessed during this research.

Yes: Poma can have a separate **Day Clock** tab that displays Google Calendar events as sectors on a clock. For the current Windows app, the most practical approach is a Flutter view over the existing calendar reader and cache. The clock does not require another Google connection or a new server. Android and iOS would require separate calendar connection work because Poma currently keeps those platforms offline.

Calendar events describe scheduled activities. They do not establish that an activity happened or how long someone actually worked. Completed Poma focus sessions could become an additional, clearly labelled layer later.

**Subsequent owner-selected direction — 9 November 2026**

The owner selected a **12-hour dial with AM/PM switching**, substantial filled event sectors, event colours and a current-time hand, using the attached Sectograph-style clock as a visual reference. This supersedes the initial 24-hour-first recommendation. The chosen celestial palette, reference and concept are recorded in [Day Clock visual direction](DAY_CLOCK_VISUAL_DIRECTION.md).

The latest request additionally requires creating a timed task/event from Day Clock in Google Calendar, including a 10:00–11:00 PM example. [The current feature brief](DAY_CLOCK_FEATURE_BRIEF.md) supersedes earlier read-only-only scope statements for Day Clock and distinguishes the new creation capability from Poma's restricted focus writer. The remaining research below retains its original viewing-first context.

**The closest existing product**

[Sectograph](https://sectograph.com/) is the direct reference: it maps calendar events onto a 12- or 24-hour circular timeline. Its [official Google Play listing](https://play.google.com/store/apps/details?id=prox.lab.calclock) describes device-calendar and Google Calendar reading, event durations, gaps, interactive sectors, widgets, and a current-time display. It is a useful interaction reference; the independently maintained GitHub project named `yumauri/sectograph` below is a different application.

**GitHub projects worth studying**

The activity dates below are GitHub's repository `pushed_at` values, not promises of maintenance, release quality, or compatibility. Licenses were checked through GitHub metadata and the repositories' own documentation. These are research references, not qualified dependencies.

| Project | Useful contribution | Stack / license | Last repository push | Fit for Poma |
| --- | --- | --- | --- | --- |
| [miltolstoy/RoundCalendar](https://github.com/miltolstoy/RoundCalendar) | A particularly close example: Google/device calendar events on a 24-hour clock. | Android Java / GPL-3.0 | 20 Apr 2021 | Strong visual and geometry reference. Reads Android's calendar provider; its sync code cannot be used directly on Windows. |
| [tyichye/daily-calendar-clock-widget](https://github.com/tyichye/daily-calendar-clock-widget) | A daily circular Google Calendar widget, calendar selection, and screenshots of configuration. | Android Java / GPL-3.0 | 29 Jun 2021 | Another close Android example, with a similar source layout to RoundCalendar. Useful for interactions and widget ideas; old platform tooling needs assessment. |
| [yumauri/sectograph](https://github.com/yumauri/sectograph) | A desktop clock with timed sectors, all-day items around the dial, and selection when events overlap. | Python / PyQt, repository MIT | 4 Oct 2021 | Good desktop behavior reference. Educational prototype; its README explicitly leaves Google/system calendar integration as future work. |
| [pyjoku/radial-calendar-plugin](https://github.com/pyjoku/radial-calendar-plugin) | A 24-hour time-block renderer, SVG arc helpers, concentric day/week/month views, and iCalendar import. | TypeScript / Obsidian, MIT | 20 Apr 2026 | Useful drawing and multi-ring references. Its Google integration fetches private iCal URLs, rather than using Google's authenticated Calendar API. |
| [sinanawad/gcal-glance](https://github.com/sinanawad/gcal-glance) | Flutter desktop Google Calendar display with overlapping events, current-time indication, multiple calendars, RSVP handling, and refresh behavior. | Dart / Flutter for Linux, Apache-2.0 | 7 Apr 2026 | Best same-language companion reference. Its timeline is horizontal, rather than circular; Linux-specific credential handling is not a Windows integration. |

For direct code reuse, preserve the applicable license and notices. Copying GPL implementation code requires assessing GPL obligations for the resulting distribution. For Poma, independently implementing the dial using Flutter and studying these projects' behavior is the straightforward option. An MIT label on Python source also does not change the licensing of its PyQt runtime dependencies.

Specific upstream files inspected or identified for a later implementation review:

- RoundCalendar's [ClockView.java](https://github.com/miltolstoy/RoundCalendar/blob/master/app/src/main/java/com/miltolstoy/roundcalendar/ClockView.java) draws the dial and event arcs. [CalendarAdapter.java](https://github.com/miltolstoy/RoundCalendar/blob/master/app/src/main/java/com/miltolstoy/roundcalendar/CalendarAdapter.java) demonstrates that its events come from Android's calendar provider.
- The Obsidian plugin's [TimeBlockRenderer.ts](https://github.com/pyjoku/radial-calendar-plugin/blob/main/presentation/codeblock/TimeBlockRenderer.ts) contains time-to-angle conversion and arc construction. Its [GoogleCalendarSync.ts](https://github.com/pyjoku/radial-calendar-plugin/blob/main/src/infrastructure/sync/GoogleCalendarSync.ts) confirms the ICS-fetching approach. The presence of both root and `src` trees warrants checking the build entry point before porting any implementation.
- The gcal-glance README identifies `lib/widgets/timeline_strip.dart`, `lib/models/calendar_event.dart`, and `lib/services/google_calendar_service.dart` as relevant areas. Its behavior and security claims were read from its documentation, not independently validated by running it.

[BetaNumeric/spiral](https://github.com/BetaNumeric/spiral) is an additional visual experiment, with one day per spiral turn and local browser event storage. Its README states that events do not automatically sync between devices. No license was identified in GitHub metadata, so it is a visual reference, not a code-reuse recommendation.

**What Poma already supplies**

The existing Windows implementation substantially reduces the scope:

| Existing component | Reuse in Day Clock |
| --- | --- |
| `mobile/lib/ui/app_shell.dart` | Add the separate destination alongside the existing Calendar destination. Update navigation order and shortcuts deliberately. |
| `mobile/lib/application/calendar_connection_controller.dart` | Reuse the selected account and the existing `calendar.calendarlist.readonly` and `calendar.events.readonly` permissions. Viewing does not require focus-write consent. |
| `mobile/lib/application/calendar_read_controller.dart` | Share selected calendars, retained events, cache ownership, connection state, refresh status, and invalidation. It schedules network refreshes every five minutes and presentation notifications every minute. |
| `mobile/lib/data/google_calendar_reader.dart` | Already pages through results and requests `singleEvents=true`, expanding recurring events into instances. |
| `mobile/lib/domain/calendar_data.dart` | Preserve event identity, UTC instants, date-only events, eligibility, recurring-series information, and source metadata. |
| `mobile/lib/ui/calendar_schedule.dart` and `calendar_schedule_adapter.dart` | Follow the existing presentation rules, stable identities, details invalidation, source colors, and validated event actions. Extract shared presentation helpers where useful. |
| `mobile/lib/data/calendar_time.dart` | Reuse local-day boundaries and the rolling seven-date window: today plus the following six dates. |

Poma already uses `kalender` for its conventional calendar. The package documents Day, Multi-day, Month and Schedule views; it does not advertise a circular clock view. Keep that dependency for the existing schedule and implement the dial with Flutter's [CustomPainter](https://api.flutter.dev/flutter/rendering/CustomPainter-class.html), which supports drawing, hit testing and accessibility semantics. This is a design recommendation, not a completed rendering benchmark. [Kalender project](https://github.com/werner-scholtz/kalender).

The existing model retains calendar/source colors but does not retain an event-specific `colorId`. The selected feature includes individual Google event colors, so implementation must extend the selected API fields, event model and cache serialization, and resolve the [Google color palette](https://developers.google.com/workspace/calendar/api/v3/reference/colors/get), retaining source colors as fallback. Google documents `colorId` on its [event resource](https://developers.google.com/workspace/calendar/api/v3/reference/events).

**Recommended first version**

Add a Windows **Day Clock** tab, sharing the same calendar selection and connection as Calendar:

1. A 12-hour dial, with 12 at the top, substantial colored timed-event sectors, explicit AM/PM selection and a current-time hand. Follow the owner's selected [visual direction](DAY_CLOCK_VISUAL_DIRECTION.md).
2. Today and date selection within the existing loaded window. Earlier historical dates need a separate cache/window decision; they are not already supported by the current reader.
3. Separate radial lanes for simultaneous events, with stable ordering and a chronological event list for dense days. Keep short events selectable even when their sectors are narrow.
4. All-day events displayed as labelled items outside the dial. Clip overnight and multi-day timed events to the selected date, retaining their full times in details.
5. Click or keyboard selection to show title, source, exact times, and the existing Open event / Join actions. Retain a usable list at large text sizes and with a screen reader.
6. Last-refreshed and stale/offline indicators, manual refresh, and explicit missing/partial-data states. An empty circle means no scheduled events only when coverage is verified.

Place events by their actual start/end positions on the clock. A normal pie chart that normalizes durations to fill the circle would lose unscheduled intervals and mishandle overlaps. If displaying a scheduled-time total, calculate the union of intervals so overlapping meetings do not count twice. Call gaps unscheduled time rather than claiming they are confirmed availability.

Preserve local wall-clock meaning across midnight and timezone changes. On daylight-saving transitions, repeated/skipped clock hours need explicit treatment; converting every day to a fixed 86,400,000 milliseconds is insufficient. Keep exact UTC instants for details and elapsed durations.

**Google synchronization choices**

For Windows, reuse the current authenticated, bounded snapshot reader. A second tab does not need separate polling, credentials, or a parallel event store. The minute presentation update can move the current-time indicator without making a Google request. The five-minute network cadence, manual refresh and existing lifecycle refreshes provide the initial synchronization behavior; this is not instantaneous push sync.

Google's [events.list reference](https://developers.google.com/workspace/calendar/api/v3/reference/events/list) supports read-only access, recurring-instance expansion, pagination and date bounds. A viewing feature fits the existing narrowly scoped read permissions; Google's [scope guidance](https://developers.google.com/workspace/calendar/api/auth) explains scope selection and public-app verification.

If refresh volume later justifies incremental synchronization, design it as a separate reader change. Google's [incremental sync guide](https://developers.google.com/workspace/calendar/api/guides/sync) covers sync tokens, deleted events and invalid-token recovery. The events endpoint disallows combining a sync token with `timeMin`/`timeMax` and with `showDeleted=false`; tokens cannot simply be appended to Poma's current bounded query. An invalid token requires rebuilding the relevant calendar cache, not deleting Poma's unrelated offline data.

Google [push notifications](https://developers.google.com/workspace/calendar/api/guides/push) require a reachable HTTPS webhook, expiring notification channels and renewal. Notifications signal that something changed; the app must still fetch the changed data. That infrastructure is unnecessary for the initial local desktop feature.

For a later Android/iOS version, choose between direct Google OAuth and reading device calendars already synchronized by the OS. [device_calendar](https://pub.dev/packages/device_calendar) is an example of the latter; its published platform support is Android/iOS and its license is BSD-3-Clause. It is not a Windows solution, and current permission/platform behavior would need validation before adopting it. The private iCal URL approach used by the Obsidian plugin is another read-only import option, but adds no clear benefit to Poma's existing API connection.

**Implementation and verification outline**

Build a pure daily-interval projection first, then a Flutter painter and accessible event list, then wire the new tab to the existing reader. Avoid coupling the projection to `kalender`'s grid event class. Reuse the existing details/action policy and the reader's account/scope invalidation behavior.

Validate clock positions and selection with fixed fictional events: overlapping blocks, short events, cross-midnight spans, recurrence exceptions, all-day exclusive ends, cancelled/declined events, and DST transitions. Check refresh failures, retained stale data, midnight rollover, lock/disconnect/deselection, large text and high contrast. Then compare the selected real Google calendar against the dial in an installed Windows build. The source review establishes feasibility; it does not establish that live sync or the proposed UI has passed acceptance.

The recommended scope is a read-only Windows clock tab with the owner's selected 12-hour display and per-event colors. Historical browsing, actual-focus overlays, event editing and phone syncing remain separate extensions.
