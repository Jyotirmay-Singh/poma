# Poma + Google Calendar: Windows tray session prompts

Prepared on 22 October 2026. Planning baseline: commit `cb8b1a1` on `codex/poma-offline-release` in `D:\pomodoro`.

This is a plan and a set of prompts for future chats. No application code, Google Cloud configuration, or calendar events were changed while preparing it.

The confirmed target is **a Windows system-tray icon with a compact calendar popup**. The recommended sequence is **10 sessions for a read-only first release**, followed by **2 optional sessions for writing focus blocks to Google Calendar**. A session is a bounded piece of work, not a promise that it fits in a particular number of hours.

## What the current project actually supports

- The repository currently ships Flutter Android/iOS Poma, version `1.0.0+2007`, using Flutter 3.44.2 / Dart 3.12.2. There is no `mobile/windows` target in this checkout. An existing Windows executable, if you have one from somewhere else, has not been identified or inspected by this planning work.
- `mobile/lib/main.dart` constructs `SqliteRepository`, `NativeTimerClock`, and `NativeLocalAlerts`. Those defaults cannot simply be assumed to work on Windows.
- `mobile/lib/domain/timer_engine.dart` and `models.dart` contain reusable timer logic and records. `mobile/lib/application/app_controller.dart` coordinates timer actions and persistence. Preserve those boundaries.
- `mobile/lib/data/timer_clock.dart` calls a native channel whose shipped implementations are mobile-specific. `local_alerts.dart` initializes Android/iOS notification settings and an app-owned channel. Both need Windows treatment.
- SQLite is already behind a repository port with a database-factory injection point. `sqflite_common_ffi` is currently a development dependency for host tests; Windows production database support needs an explicit dependency, packaging, and storage decision.
- No Google Calendar authorization or synchronization implementation was found in the inspected application. Existing product documents describe an entirely offline app; this new request authorizes an optional Windows calendar feature. Update those claims deliberately as implementation proceeds, while retaining offline Pomodoro use.

Relevant local reading: [README](../README.md), [architecture](ARCHITECTURE.md), [local data](LOCAL_DATA.md), [notifications](NOTIFICATIONS.md), and [existing mobile session prompts](SESSION_PROMPTS.md). The Windows sessions below are a separate sequence; do not overwrite the mobile release history.

The Google Calendar connector in this chat returned four calendars: two with owner access and two with reader access. That supports planning for calendar selection and access roles. No personal events were fetched. These connector credentials are **not** Poma credentials: the installed application will need its own Google OAuth client and user authorization, and must work without Codex or an MCP connection.

## Professional application patterns to borrow

These are documented product behaviors from official sources checked for this plan, not hands-on installation, security-audit, or performance results. The final column is a recommendation for Poma.

| Application | Platform and documented integration | Pattern to borrow for Poma |
| --- | --- | --- |
| [Calendar Flyout](https://leptuch.com/apps/calendar-flyout/index.html) | Windows 11 agenda flyout with Google and Microsoft calendars, event management, and quick Teams meeting access. | A small agenda that is useful immediately when opened from the taskbar area. Keep event editing out of Poma's first release. |
| [ZefirCalendar](https://zefircalendar.com.br/en/) | Windows 11 tray flyout combining Google, Outlook, and iCloud events. Its official page describes browser sign-in, a chronological agenda, meeting joining, and Windows-protected credentials. | Direct provider authorization, account settings outside the main agenda, and a compact list with explicit Join actions. Its privacy design is a vendor claim, not something audited here. |
| [MeetingBar](https://github.com/leits/MeetingBar) | macOS menu-bar app with direct Google Calendar and macOS Calendar providers; current/next meeting, countdowns, event filters, and one-click joining. | Prioritize Now/Next, shorten long titles, and filter declined/all-day events out of the meeting countdown. |
| [Dato](https://sindresorhus.com/dato) | macOS menu-bar calendar using calendars already connected through the macOS Calendar app, including Google. It documents upcoming events, keyboard actions, meeting joining, and duplicate-event handling. | Progressive detail, keyboard access, and per-calendar control. Its macOS account bridge is not a Windows implementation strategy. |
| [TickTick](https://help.ticktick.com/articles/7055781593733922816) | Its Google integration settings distinguish calendar subscription from bidirectional list/calendar integration, with explicit list and calendar selection. | Make reading calendars and writing task blocks separate product choices. Do not turn every Google event into a Poma task. |
| [Trevor AI](https://www.trevorai.com/integrations/google-calendar) | Google Calendar integration centers on scheduling tasks into calendar time blocks. This is a scheduling-workflow reference, not a tray-UI reference. | Treat optional focus-block scheduling as a later workflow with a clear target calendar. |

## Recommended first-release experience

Poma should own its own tray icon and popup. Windows documents notification icons, context menus, and rich flyouts as supported shell integration points. Do not plan to replace Explorer's clock flyout or inject arbitrary meeting text into the Windows taskbar. The macOS status-bar text pattern should become a Windows tooltip and popup countdown. See Microsoft's [NotificationIcon sample](https://learn.microsoft.com/en-us/windows/win32/shell/samples-notificationicon).

Proposed popup, using fictional content:

```text
Poma                         Today       Settings

Focus   18:42 remaining                 Open timer

NEXT    Design review                  in 12 min
14:30–15:00  ·  Work calendar               Join

TODAY
14:30   Design review                  Open event
16:00   Project planning                    Join

Tomorrow / choose a day
Updated 2 min ago       Refresh     Open Calendar
```

Recommended behavior:

- Left-click toggles the popup. Right-click opens a short native menu: Open Poma, timer controls when allowed, Refresh calendar, Calendar settings, and Quit.
- Start around 380 logical pixels wide, with height constrained to the available monitor work area. This is a design starting point to validate at different Windows display scales, not a fixed pixel requirement.
- Keep the current focus timer visible, then the next eligible meeting, then today's agenda. Allow tomorrow and a day within the next week without adding a full calendar editor.
- Support one Google account and several selected calendars initially. Show calendar names/colors and distinguish read-only calendars. Require selection before fetching event contents; do not enable every shared calendar automatically.
- Use a privacy-friendly tooltip such as “Meeting in 12 min.” Event titles in tray tooltips and toasts should be an explicit setting. Hide or redact titles while the workstation is locked.
- Hide declined/cancelled events from Now/Next. Show all-day events in their own agenda section, without countdowns or default meeting reminders. Label tentative invitations and handle simultaneous meetings explicitly.
- Join opens a validated meeting URL only after a click. Open event goes to Google's event page. Signing in, synchronizing, or starting a timer must never launch a meeting automatically.
- Meeting reminders start disabled; the user can enable them and choose a lead time. This avoids immediately duplicating existing Google reminders.
- Close-to-tray and start-with-Windows are explained choices. Quit actually exits. Do not promise that reminders will fire while Poma is exited or the computer is asleep.
- Calendar failures show a last-updated/stale state. Tasks, timers, history, settings, and locally supported alerts remain usable without signing in or going online.
- Calendar events remain calendar events. Google Tasks integration, automatic task import, full two-way editing, AI scheduling, and phone-to-desktop Poma data synchronization are outside the first release.

## Technical decisions for the prompts

| Area | Recommended decision and reason |
| --- | --- |
| Runtime | Extend the existing Flutter project with a Windows host and platform-specific factories. Reuse domain/application code; avoid a framework rewrite. First verify whether any separately installed Poma binary belongs to another source tree. |
| Tray and windows | Evaluate Windows-compatible tray/window libraries against the pinned SDK and actual native build. [tray_manager](https://pub.dev/packages/tray_manager) and [window_manager](https://pub.dev/packages/window_manager) are candidates, not preselected versions. Their current documentation includes native-library migration changes, so verify compatibility together. |
| Timer portability | Supply a Windows clock with documented sleep-inclusive elapsed behavior. Microsoft's [Windows time guidance](https://learn.microsoft.com/en-us/windows/win32/sysinfo/windows-time) distinguishes clocks that include sleep from those that do not. Preserve existing reconciliation, strict mode, unique completion, and manual next-phase behavior. Do not claim a resolution or restart identity that was not measured or established. |
| Authorization | A native desktop authorization-code flow using the external browser, PKCE S256, state validation, and a temporary loopback callback. Follow [Google's desktop OAuth guide](https://developers.google.com/identity/protocols/oauth2/native-app). The standard [google_sign_in package](https://pub.dev/packages/google_sign_in) currently lists Android, iOS, macOS, and web, not Windows; do not select it assuming Windows support. |
| Read permissions | Start with `calendar.calendarlist.readonly` and `calendar.events.readonly`, using their full Google scope URLs in the application. These support calendar selection and event reading without event edits. Justify any additional scope separately. See [Calendar API scopes](https://developers.google.com/workspace/calendar/api/auth). |
| Credentials | Keep refresh credentials in Windows-protected storage, such as Credential Manager/DPAPI through a verified library. Keep access tokens in memory where practical. Never put user tokens in SQLite, logs, screenshots, source, or handoff files. See [Google OAuth best practices](https://developers.google.com/identity/protocols/oauth2/resources/best-practices). A packaged desktop client secret is not a confidentiality boundary. |
| Calendar storage | Keep a small, account-scoped calendar cache separate from the authoritative Pomodoro database. Store only fields needed for the agenda, meeting action, and reminders. Retain at most the selected upcoming-week window; purge replaced ranges and disconnected-account data. Do not claim the event cache is encrypted merely because tokens are protected. |
| Refresh | For the first release, use a bounded rolling window with fully paginated snapshot replacement per calendar. Refresh when opening stale content, after resume, on manual refresh, and approximately every five minutes while resident and connected. Coalesce requests, back off on errors, and avoid network work per timer tick. |
| Recurrence and deletion | Use Calendar's event-instance expansion and account/calendar/event identity. Replace a cached range only after every page succeeds; this makes removed events disappear without losing good data on a failed request. Preserve the last successful range on partial failure and label it stale. See [Events: list](https://developers.google.com/workspace/calendar/api/v3/reference/events/list). |
| Incremental sync | Defer it until data volume justifies it. A rolling time-bounded request must not casually be combined with `syncToken`; Google's [sync guide](https://developers.google.com/workspace/calendar/api/guides/sync) documents parameter restrictions and invalid-token recovery. Recovery must affect only calendar cache, never Poma history. |
| Hosting | Direct desktop-to-Google requests; no Poma backend, polling server, or webhook service for this release. Public homepage/privacy material may still be needed for Google production requirements; that is distinct from hosting an application backend. |
| Optional writes | Later, prefer a dedicated Poma-created “Poma Focus” calendar and evaluate `calendar.app.created` for that boundary. Use ordinary calendar events so personal accounts are supported. Do not depend on Workspace-only focus-time capabilities. |

## Your role and the implementation agent's role

**Your role:** product owner, Google Cloud project owner, and desktop acceptance tester. You do not need to write code. Choose the popup/privacy behavior, create or approve Google app configuration, complete sign-in/MFA yourself, and exercise the installed build on your real desktop. If a work account requires administrator approval, arrange that approval. For public distribution, own the app identity, privacy/support details, and any signing credentials.

**The agent's role:** inspect the real source, make the platform/dependency choices concrete, implement the selected session, test it, update documentation, package reviewable artifacts, and distinguish automated evidence from your observed desktop results. The agent should guide you through account-console actions; it should never ask for your Google password or a pasted refresh token.

| Session | Agent deliverable | Your part | Completion gate |
| --- | --- | --- | --- |
| 1 | Source/runtime audit and Windows UX specification | Choose display/privacy defaults; identify another installed Poma if relevant | Platform assumptions and acceptance criteria are explicit |
| 2 | Windows app that preserves offline Poma behavior | Supply a Windows test machine; approve/install missing build tools if necessary | Real Windows launch and database reopen work |
| 3 | Tray shell and popup using fictional fixtures | Review placement, click/close behavior, text size, and appearance | One process, one state owner, usable popup |
| 4 | Google Cloud/OAuth setup runbook | Configure the project/API/consent/test user and Desktop client | Correct client configuration exists without exposed user credentials |
| 5 | Google connection and secure credential lifecycle | Sign in and test cancel/disconnect/reconnect | Read-only authorization survives an app restart safely |
| 6 | Selected-calendar refresh and bounded cache | Prepare harmless test events in a test calendar | Calendar changes, pagination, and offline stale data behave correctly |
| 7 | Real agenda and meeting actions | Compare the popup against Google Calendar | Correct events, times, roles, and join actions |
| 8 | Resident reminders and calendar-aware timer UX | Choose reminders; try meeting/focus overlaps and sleep/resume | Reminders respect settings; timer invariants hold |
| 9 | Reliability, privacy, and regression evidence | Run the supplied real-desktop test script | Important failures recover without data loss or unwanted actions |
| 10 | Private Windows pilot package and release notes | Install/run the package without development tools | Standalone Windows pilot works; public-release gates are documented |
| Optional 11 | Focus-block writing specification and permission design | Decide whether writing is useful and authorize that future scope | Target calendar and preview/re-consent behavior are agreed |
| Optional 12 | Explicit focus-block creation with recovery tests | Grant the new permission and verify disposable focus events | No duplicate or unintended event writes; read-only mode still works |

## How to run these sessions

Use one prompt per chat, in order, against `D:\pomodoro`. The first ten prompts produce the read-only pilot. Run optional sessions 11–12 only if you decide to add calendar writes. Do not paste the whole sequence as one implementation request.

Every session should read this plan, `RTK.md`, relevant existing documentation, and the latest Windows-calendar handoff. In session 1 create `docs/WINDOWS_CALENDAR_PROGRESS.md`; later sessions maintain it. That file should contain the source/build identity, completed behavior, changed files, actual checks and results, remaining risks, your next action, and the exact next session number. Do not include personal event contents or credentials.

Shared requirements for all implementation sessions:

- Follow applicable repository instructions. Use RTK; if it is absent from PATH, `RTK.md` documents the local executable. Preserve unrelated work and inspect the current changes before editing.
- Implement only the named session. Do not skip ahead or automatically begin the next session.
- The owner's request authorizes an optional Windows calendar connection. Preserve the mobile app's offline behavior and do not introduce phone synchronization, analytics, or a mandatory account.
- Keep platform/network/storage effects out of the pure timer domain. A calendar outage must not block startup or offline focus controls.
- Maintain one timer/state owner and ordered persistence. Do not create a second controller or writable database owner just to show a popup.
- Add meaningful tests for new platform, authorization, synchronization, and lifecycle risks. Run the checks appropriate to changed code; do not rerun historical release checks merely for editing documentation.
- State exactly which checks ran on Windows, Android, and iOS. Do not turn a fixture, mock, host test, or old mobile build into a claim of real Google/Windows verification.
- If an owner-only account step is missing, complete independent work with fixtures and document the missing prerequisite. Do not mark the dependent live flow passed.
- Update privacy/product claims when network access or desktop data storage is added. Keep existing mobile release evidence separate.
- At the end, update the Windows-calendar handoff and report the deliverable, verification, remaining issues, and the owner's next action. Do not publish, distribute publicly, register paid services, or change the owner's real events as a side effect of development.

## Session 1 — Confirm the runtime, architecture, and popup design

Your role: choose whether tray/tooltips may show event titles and confirm the proposed popup priorities. If the Poma currently on your taskbar is a separate Windows build, identify its executable/source location so it can be reconciled with this checkout.

Copy this prompt into the first implementation chat:

```text
Plan Windows Calendar Session 1 for Poma in D:\pomodoro. Read RTK.md and docs/GOOGLE_CALENDAR_WINDOWS_SESSION_PROMPTS.md, then inspect the current checkout and relevant architecture, notification, privacy, and release documents. This session is discovery/design only: do not implement application code or configure Google Cloud.

Confirm the shipped platform targets and the composition points for storage, clocks, alerts, lifecycle, and UI. The planning baseline had no Windows target. If a separately installed Windows Poma is relevant, identify its provenance before proposing changes to a different application; do not assume the mobile checkout owns that binary.

Produce docs/WINDOWS_CALENDAR_SPEC.md with a dependency-ordered Windows plan, supported Windows/CPU scope, candidate dependency compatibility checks, and a text wireframe for the compact tray popup. Use the professional references in the plan as UX patterns, separating Windows behavior from macOS status-bar behavior. Define tray click/right-click, close versus Quit, multiple-monitor placement, large text, privacy, one-account/multiple-calendar selection, stale/offline states, and the Now/Next selection rules. Default reminders off and calendar access read-only.

Record the existing timer invariants and the product-document changes required for optional networking. Create docs/WINDOWS_CALENDAR_PROGRESS.md with the baseline, decisions, completion criteria, unresolved questions, and Session 2 handoff. Resolve routine design details yourself; ask only for material owner choices. The result must make the implementation concrete without changing application code.
```

## Session 2 — Make Poma run correctly on Windows offline

Your role: provide the Windows machine for a real launch and allow installation of missing Windows build prerequisites if required. No Google account setup is needed yet.

```text
Implement Windows Calendar Session 2 in D:\pomodoro. Read RTK.md, docs/GOOGLE_CALENDAR_WINDOWS_SESSION_PROMPTS.md, docs/WINDOWS_CALENDAR_SPEC.md, and the latest Windows-calendar progress. Implement only the Windows offline foundation; do not add Google authorization or calendar APIs.

Add the Windows Flutter target without regenerating or overwriting unrelated Android/iOS configuration. Retain the pinned SDK unless a demonstrated compatibility issue requires a documented decision. Introduce platform composition for the SQLite factory/path, native clock, local storage policy, and alerts. Select and package a real Windows SQLite implementation; test production database creation/reopen and error handling rather than assuming the host-test dependency is enough.

Implement a Windows clock with verified sleep-inclusive elapsed semantics and honest boot/restart behavior. Preserve pause/resume, strict mode, saved deadlines, at-most-one recovered completion, and manual starts for subsequent phases. Prevent mobile-only method-channel calls on Windows. Where Windows alerts are not yet implemented, supply an explicit capability result and visible unavailable status rather than pretending notifications work.

Launch the real Windows application. Exercise tasks, settings, timer start/pause/resume, close/reopen, and history persistence without internet. Run relevant domain/controller/repository tests and platform build checks. Record any iOS check that requires unavailable macOS tooling as unrun. Update the Windows-calendar handoff with package choices, actual launch evidence, notification limitations, and the next session.
```

## Session 3 — Build the tray icon and fixture-driven popup

Your role: review the popup on your monitor at your normal display scale, including how it closes and how you return to the full timer.

```text
Implement Windows Calendar Session 3 in D:\pomodoro. Read RTK.md, the Windows-calendar plan/specification, and its latest handoff. Build only the tray/window shell and calendar UI with fictional fixtures; do not connect Google or read real calendar data.

Verify a compatible tray/window-management approach against the existing Flutter SDK, Windows host, and native dependencies. Add one Poma tray icon, a short context menu, and a compact popup anchored to the icon's monitor/work area, with a safe fallback when icon bounds are unavailable. Left-click should toggle the same popup; right-click should show the context menu. Explain and implement close-to-tray, explicit Quit, and an opt-in start-with-Windows setting without silently changing OS startup settings.

Keep one process, one AppController, and one authoritative persistence owner. A second launch must activate the existing instance. Reuse the state owner for popup and full Poma views; do not create an independent timer or database writer. Handle hidden-window lifecycle separately from a dead application.

Use fictional fixtures for disconnected, connecting, empty, normal agenda, overlapping meetings, long titles, all-day events, stale data, and errors. Check keyboard/Escape/focus behavior, light/dark/high-contrast appearance, large text, auto-hidden taskbars, and available multi-monitor/scaling cases. Mark unobserved desktop cases honestly. Update the handoff with screenshots or other reviewable UI evidence and the owner's review points.
```

## Session 4 — Prepare the Google project and connection setup

Your role: own the Google Cloud project, enable Calendar API access, supply the app's support/privacy details, add yourself as a test user when applicable, and create the Desktop OAuth client. Complete password/MFA steps yourself.

```text
Prepare Windows Calendar Session 4 for Poma in D:\pomodoro. Read RTK.md and the Windows-calendar plan/specification/progress. This is account/setup documentation and configuration preparation, not authorization implementation. Do not change calendars or create cloud resources silently.

Check current official Google instructions and write docs/GOOGLE_CALENDAR_SETUP.md with an owner-friendly sequence for selecting a Google Cloud project, enabling Google Calendar API, configuring Google Auth Platform branding/audience/data access, selecting the appropriate testing audience, adding test users where needed, and creating a Desktop app OAuth client. Specify the two read-only calendar scopes from the plan. Do not substitute a web, Android, service-account, or embedded-browser flow for the Windows desktop flow.

Explain which values are public application identifiers and where any downloaded client configuration should be stored locally outside source control. Never request a Google password, access token, or refresh token. Define configuration injection that works in both development and the future packaged Windows build, with a clear unconfigured state.

Document the desktop loopback redirect approach, testing-mode token-expiration expectations, account/admin restrictions, and the difference between a private test build and public OAuth verification. Explain that connecting Calendar inside Codex does not configure Poma. Guide owner-only console steps when access is available; otherwise finish the runbook and record precisely what remains. Update the handoff without claiming live authorization has been tested.
```

Google documents refresh-token expiry for external apps in Testing mode, including the seven-day behavior applicable to calendar scopes. Treat this as a setup limitation rather than repeatedly prompting the user to reconnect without explanation. See [Google's OAuth overview](https://developers.google.com/identity/protocols/oauth2/).

## Session 5 — Implement read-only sign-in and secure disconnect

Your role: use your browser to sign in, grant the displayed read permissions, and try cancelling and reconnecting. No event-writing permission is needed.

```text
Implement Windows Calendar Session 5 in D:\pomodoro. Read RTK.md, the Windows-calendar plan/specification/progress, and docs/GOOGLE_CALENDAR_SETUP.md. Implement a Windows-capable native Google authorization flow and credential lifecycle; do not add event writing or the agenda synchronization engine.

Use a maintained, compatible authorization approach with the external default browser, authorization-code flow, PKCE S256, a fresh unguessable state value, and a temporary callback listener bound only to loopback. Validate the callback/state, handle denial/cancellation/timeouts, and close the listener after completion. Treat the desktop client as public. Verify Windows support instead of assuming the standard google_sign_in plugin supports it.

Request only the approved read scopes. Verify actual grants before enabling features. Store refresh credentials through Windows-protected storage, serialize refreshes, preserve a valid existing refresh token when a token response omits one, and recover cleanly from revocation/invalid_grant. Do not log tokens or authorization callback URLs. Keep account data isolated, and reject late responses from a disconnected or replaced account.

Add Connect, connection status, Reconnect, and Disconnect to settings. Disconnect must immediately disable calendar operations and clear account credentials and calendar-derived local data; attempt provider revocation and explain any offline revocation limitation. It must preserve local tasks and focus history.

Test wrong-state callbacks, cancellation, partial grants, refresh failures, secure-storage errors, restart, and disconnect races. Perform real sign-in only with owner participation. If configuration is missing, finish independent tests and document the live-flow prerequisite. Update the handoff with observed results.
```

## Session 6 — Read selected calendars and maintain a bounded cache

Your role: select the calendars to display. Prepare harmless test events in a calendar you control, including a recurring event, an all-day event, and one you can move or delete during testing.

```text
Implement Windows Calendar Session 6 in D:\pomodoro. Read RTK.md and the Windows-calendar plan/specification/setup/progress. Build read-only calendar selection, event fetching, and a bounded local cache behind application interfaces. Do not implement event writes, Google Tasks, or automatic task import.

List and page through calendars, preserving real calendar identity, access role, color, and time-zone information. Require explicit calendar selection before event contents are fetched. Support several selected calendars for one connected account. Keep cache and selection namespaced to that account and separate from authoritative Pomodoro records.

Implement the plan's rolling upcoming-week snapshot strategy, with explicit time bounds, recurrence-instance expansion, and complete pagination. Atomically replace each calendar's fetched range only after all pages succeed. Preserve valid cached data and show its age on partial/offline failure. Expire out-of-window data, clear deselected-calendar data, and invalidate in-flight work when the account or selection changes. Retain the same selected-calendar identity across a reconnect only when it is verified to be the same account.

Handle ongoing events, all-day exclusive end dates, DST/device timezone changes, recurring exceptions, moved/deleted events, declined/cancelled entries, pagination, restricted calendars, 401/403/429 responses, and retry backoff. Fetch minimal fields; do not retain full attendee lists or raw descriptions unnecessarily. Extract a meeting URL safely if needed without rendering remote HTML.

Refresh on meaningful lifecycle/manual triggers and the agreed resident cadence, never on every timer tick. Do not combine rolling time bounds with an improvised syncToken implementation. Test atomic replacement, account isolation, stale response rejection, and bounded retention. Compare against owner-prepared events when authorized and update the handoff.
```

## Session 7 — Connect the real agenda and meeting actions

Your role: compare the popup to Google Calendar and confirm that the right calendars, times, and meeting links appear. Check your usual Windows display scale.

```text
Implement Windows Calendar Session 7 in D:\pomodoro. Read RTK.md and the Windows-calendar plan/specification/progress. Connect the existing tray popup to the real calendar state from Session 6. Keep Google Calendar read-only and preserve the existing timer state owner.

Implement Now/Next and Today/Tomorrow/day selection within the cached week. Define deterministic behavior for active meetings, simultaneous meetings, identical-looking events from different calendars, all-day events, tentative invitations, and no upcoming event. Keep declined/cancelled items out of Now/Next. Do not merge unrelated events just because their titles match; retain source calendar identities for actions.

Show loading, empty, stale/offline, partial-calendar failure, unconfigured, and reconnect states with useful recovery actions. Keep cached content visible when appropriate and distinguish it from a freshly verified schedule. Format times using the device preference, preserve date-only events, and refresh grouping at midnight/timezone changes.

Implement explicit Open event/Open Calendar actions and Join only when a valid supported meeting URL is present. Prefer structured conference data, with carefully validated fallbacks. Accept supported HTTPS meeting hosts only; reject script/file/custom-scheme payloads and misleading hostname matches. Open the default browser only after the user's action. Never auto-join or auto-open a URL during refresh.

Apply the privacy settings to the tray tooltip and any visible status text. Test long titles, Unicode, keyboard/screen-reader access, large text, meeting conflicts, and URL safety. Compare the real popup with owner-prepared Google events. Update the handoff with screenshots using fictional or redacted data and the actual results.
```

## Session 8 — Add resident reminders and calendar-aware focus behavior

Your role: choose whether to enable Poma meeting reminders and their lead time. Try a meeting that overlaps a focus session, strict mode, and sleep/resume.

```text
Implement Windows Calendar Session 8 in D:\pomodoro. Read RTK.md and the Windows-calendar plan/specification/progress, including existing timer/alert invariants. Implement resident Windows reminders and the small calendar-aware focus experience. Do not write calendar events or add automatic task conversion.

Provide real Windows notification capability where supported by the selected packaging/runtime, including the Windows timer-alert adapter left incomplete in Session 2. Keep calendar reminders separate from timer completion identities and the existing alert protocol. Both paths must be idempotent and must reject stale notification actions. Default calendar reminders off; allow a lead time, per-calendar inclusion, and privacy-friendly text. Do not bypass Windows Do Not Disturb or claim guaranteed delivery.

Use one-shot deadlines and lifecycle reconciliation instead of per-second background storage/network work. On event move/cancellation, disconnect, calendar deselection, or reminder setting changes, cancel obsolete reminders. Define wake/restart catch-up behavior that avoids a storm of old meeting notifications. Clearly document that the pilot guarantees no reminders while Poma is fully exited and no exact delivery while Windows is asleep.

Connect popup timer controls to the existing controller with current revision/run identity. Before a new focus session that overlaps the next meeting, show the conflict and let the user continue or cancel. Do not silently shorten configured durations, pause an active session, auto-start a successor, or bypass strict mode. Calendar context does not become a task or alter historical task snapshots.

Test hidden-window timer expiry, repeated notifications, stale actions, lock-screen privacy, reminder changes, strict mode, and sleep/resume. Update the handoff with actual Windows observations and remaining delivery limitations.
```

## Session 9 — Verify resilience, privacy, and mobile regression

Your role: follow the supplied real-desktop checklist, including disconnecting the internet, locking the workstation, sleeping/resuming, and changing a harmless test event in Google Calendar.

```text
Complete Windows Calendar Session 9 in D:\pomodoro. Read RTK.md and the Windows-calendar plan/specification/progress. Perform risk-based verification and fix demonstrated defects within the agreed first-release scope. Do not add new product features or event writes.

Create docs/WINDOWS_CALENDAR_ACCEPTANCE.md with reproducible steps, expected outcomes, actual observations, source/build identity, and a clear separation between automated checks and owner-observed desktop checks. Cover clean launch, one-instance behavior, tray recovery after Explorer restart, popup bounds at available display scales/monitors, keyboard/Narrator access, close/Quit, disabled and enabled startup, and notifications while hidden.

Exercise denied/revoked access, testing-mode token expiry, account replacement, secure-storage failures, disconnect during a request, partial pagination failure, rate limiting, unavailable calendars, stale cache, recurrence exceptions, all-day/DST/timezone/midnight cases, moved/deleted events, and unsafe meeting URLs. Verify that disconnect and full local reset cancel calendar work and remove calendar-derived local data/credentials without deleting remote events. Prevent a late response from repopulating cleared data.

Confirm that calendar failure never blocks offline Poma startup, local tasks/history, or timer controls. Recheck strict mode, no duplicate completions, sleep/restart recovery, and manual phase starts. Run relevant existing Flutter/mobile checks for changed shared code and report platform checks that could not run. Inspect logs and package contents for leaked credentials or personal event text. Measure resident/hidden resource behavior against an observed baseline without inventing performance promises.

Update architecture, privacy, retention, dependency/license, and notification documents to describe actual behavior. Record unresolved release gates and update the handoff for packaging.
```

## Session 10 — Package and validate a private Windows pilot

Your role: install or extract the complete pilot package and test it without a Flutter development session. Decide later whether you want public distribution; provide signing identity and production app details only if that path is chosen.

```text
Complete Windows Calendar Session 10 in D:\pomodoro. Read RTK.md and the Windows-calendar plan/specification/progress/acceptance documents. Prepare a reviewable private Windows pilot of the read-only integration. Do not publish to a store, distribute publicly, buy signing services, or change real calendar events.

Choose the distribution format based on verified runtime requirements: a complete portable folder/archive or an MSIX/installer if application identity is needed for the implemented notification behavior. Include every required Flutter/native/database runtime file, licenses, icons, public client configuration, and installation instructions. Do not deliver a lone executable that depends on the build folder or developer machine. Keep user credentials and private local configuration out of artifacts.

Verify a clean package launch outside development tooling, Google browser authorization and loopback return, credential persistence, selected-calendar loading, tray interaction, focus persistence, hidden-window reminders, Quit, and an offline restart. Check the installed path, notification identity, upgrade behavior, and local data paths. Exercise a clean user profile or equivalent isolated environment when available, and clearly mark unavailable clean-machine checks.

Write Windows pilot release notes with the exact artifact/build identity, supported Windows/CPU scope, observed checks, reminder and testing-mode OAuth limitations, disconnect/uninstall guidance, and remaining issues. Explain how users can remove protected credentials and calendar cache. Separate this private pilot from public-release gates: Google production/verification requirements, public privacy/support material, signing, and broader hardware testing.

Update the handoff with links to the complete local artifacts and the owner's final pilot checklist. Stop at the private pilot; optional focus-block writing is a separate decision.
```

## Optional Session 11 — Design explicit focus-block writing

Your role: decide whether writing focus blocks is useful. Choose the desired Busy/Free behavior and confirm that Poma should use its own dedicated calendar rather than your primary or existing planning calendars.

```text
Plan optional Windows Calendar Session 11 in D:\pomodoro. Read RTK.md, the Windows-calendar plan/specification/progress, and the verified read-only pilot limitations. This session defines the optional write feature; do not implement writes or request write permission yet.

Design an explicit “Schedule focus block” flow that previews the task/title, date, timezone, start/end, calendar, and Busy/Free behavior before a user confirms it. Use a dedicated Poma-created “Poma Focus” calendar and ordinary event types compatible with personal Google accounts. Evaluate the narrow calendar.app.created permission and document its actual access boundary. Do not request broad full-calendar access merely for convenience, and do not use Workspace-only focus-time semantics as the baseline.

Write docs/WINDOWS_CALENDAR_WRITES_SPEC.md covering supported operations, ownership markers, local operation identity, retries, conflicts, offline behavior, and disconnect/reset semantics. Scope the first write release to explicit one-off focus-block creation and management of those Poma-owned blocks only. Editing invitations, attendee changes, recurring-series edits, automatic completion uploads, full two-way task synchronization, and silent focus-session logging stay out of scope.

Plan the additional user consent using current desktop OAuth guidance. Do not assume the web incremental-authorization pattern is supported for installed apps. Preserve working read-only use if the user declines the additional grant, and define how replacement credentials and granted scopes are verified safely.

Specify meaningful duplicate-prevention and failure-recovery tests before coding. Record the owner's choices and the Session 12 handoff. Keep the existing read-only pilot fully usable.
```

## Optional Session 12 — Implement focus-block writes and verify recovery

Your role: grant the additional permission only if you want this feature, then create and inspect disposable focus blocks through Poma's confirmation flow. Verify results in Google Calendar before using real planning data.

```text
Implement optional Windows Calendar Session 12 in D:\pomodoro. Read RTK.md, the Windows-calendar plan/progress, and docs/WINDOWS_CALENDAR_WRITES_SPEC.md. Implement only the approved explicit focus-block workflow. Do not add general event editing, recurring writes, attendee notifications, or automatic session-history uploads.

Add the separate write consent/capability state. A declined or incomplete write grant must leave calendar reading and offline Poma intact. Create or recover the dedicated Poma Focus calendar without producing a new calendar on every retry. Validate the target calendar identity and access boundary before every write. Show the final preview and require a user action before sending the operation.

Persist each confirmed operation before sending it. Use a stable operation identity and a Google-compatible deterministic event ID or an equally verified idempotency strategy. Handle an uncertain response by looking up and verifying the intended event, not blindly inserting another one. A conflict must not overwrite unrelated remote data. For any permitted edit/delete of a Poma-owned block, verify ownership and use concurrency protection; do not touch arbitrary Google events.

Keep pending/failed/sent status visible. Do not silently replay time-sensitive offline operations after their usefulness has expired. Disconnect/reset must stop pending writes and preserve existing remote events unless the user explicitly requests their deletion. Protect against late account-switched responses and crashes around local acknowledgement.

Test repeated clicks, timeout-after-server-success, restart, duplicate IDs, permission denial, changed/deleted remote blocks, expired times, and disconnect races. With owner participation, verify one creation and any explicitly supported reversal on disposable events. Rerun affected end-to-end checks, update privacy/scope/setup/release documentation, and rebuild a private pilot. Do not publish it automatically.
```

## First-release acceptance in one checklist

- Poma launches as a standalone Windows app and remains an offline Pomodoro app when Google is disconnected.
- Its own tray icon opens one compact popup on the correct monitor; a second launch does not create another timer owner.
- The owner can connect one Google account, choose calendars, see the correct upcoming events, and disconnect cleanly.
- Calendar reading handles timezones, recurrence, all-day events, deletion, pagination, partial failures, and stale/offline data.
- Meeting links open only when clicked; title visibility and reminders follow the owner's settings.
- Hidden-window and sleep/resume behavior is observed and documented without promising delivery after Quit.
- Local timers, tasks, history, and strict mode retain their established behavior and durability.
- The first-release build requests read access only and sends no calendar event mutations.
- The complete private package runs without Flutter tooling, Codex, MCP, a development server, or a Poma backend.

Start with **Session 1**. The only preparation needed beforehand is deciding your title-privacy preference and, if relevant, identifying the source of a separately installed Windows Poma.
