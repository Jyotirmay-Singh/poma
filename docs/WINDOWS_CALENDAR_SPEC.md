# Poma Windows Calendar specification — Session 1

Date: 25 October 2026. Status: **design complete; calendar implementation not started**.

This specification defines the optional, read-only Windows calendar pilot. Session 1 changes documentation only: no application code, dependencies, Windows settings, Google Cloud configuration, credentials, or calendar events are changed. See the [progress and Session 2 handoff](WINDOWS_CALENDAR_PROGRESS.md) and the [original session sequence](GOOGLE_CALENDAR_WINDOWS_SESSION_PROMPTS.md).

## 1. Source, product, and platform baseline

- Repository: `D:\pomodoro`, branch `codex/poma-offline-release`, HEAD `cb8b1a1e3f5a376b0121ead5328bb51fbcdc5679`.
- That committed baseline contains Android/iOS targets and no Windows runner. The current working tree contains substantial **uncommitted Windows desktop implementation**. Preserve all of it; the original plan's missing-runner and development-only FFI assumptions are historical, not current work orders.
- Mobile retains `1.0.0+2007`. Windows private candidate **1.0.0.2009** uses Flutter **3.44.2 / Dart 3.12.2**. Existing mobile release evidence does not certify Windows, and Windows observations do not certify a new mobile build.
- Initial supported scope is **Windows 11 25H2, build 26200, x64**, matching the recorded host build 26200.9711. The candidate manifest has minimum/tested version `10.0.26200.0` and x64 architecture. Windows 10, earlier Windows 11 versions, x86, ARM64, and emulated configurations receive no initial support claim.
- Preserve package `JyotirmaySingh.Poma.Desktop`, publisher `CN=Jyotirmay Singh`, application `Poma`, existing tray/notification identities, and the owner's signing certificate. A later calendar package must have a higher Windows version than 1.0.0.2009.
- Current-user discovery found zero installed Poma packages and zero running Poma processes. The known signed package and extracted runtime trace to this checkout's working-tree source inventory. No separate installed application was identified; this does not inventory other users or arbitrary portable applications. If another executable becomes relevant, establish its path, version/hash, package identity, and source provenance before changing it.

The 2009 build inventory contains 220 source inputs; all matched during Session 1. The candidate MSIX SHA-256 is `2f6d11c245111446c14d663f3fb2950753c87ffc637c932c5a458df252424803`; the offline-kit ZIP is `bea9a16c5144ce55f19404fc886d3b927e48349d83cfa04cebe3042d02aa5399`; the lockfile is `cc6af285af5a44c115f82dfe6a2771f5bfdc9f21eba8b825e829e2a828c08a85`.

The existing desktop foundation is implemented and privately packaged, with supporting extracted-package observations. Trusted installation, clean-profile offline operation, sleep/hibernate, real tray placement, startup, notification policy/actions, and accessibility retain their recorded acceptance gates. See [desktop progress](WINDOWS_DESKTOP_PROGRESS.md), [release identity and reproduction](WINDOWS_DESKTOP_RELEASE.md), and [desktop acceptance](WINDOWS_DESKTOP_ACCEPTANCE.md).

## 2. Architecture and composition

Preserve the existing dependency direction: UI → application → domain; data/native code implements application ports. The pure timer domain gains no Google, Flutter, storage, or networking effects.

| Concern | Existing composition point | Calendar extension |
| --- | --- | --- |
| Startup | `PomaLoader` in [main.dart](../mobile/lib/main.dart) initializes the Windows environment, repository, clock, alerts, `AppController`, and `DesktopController`. | Start calendar services independently after core restoration. Network, cache, or credential failures cannot block the offline main window. |
| Storage | [NativeWindowsHost.repository](../mobile/lib/data/windows_platform.dart) supplies `databaseFactoryFfi` and `databases/poma.db`; [SqliteRepository](../mobile/lib/data/local_repository.dart) implements the application repository port. | Keep calendar cache/preferences in a separate account-scoped store under the same profile root. Preserve authoritative Pomodoro schema v3 and its single writer. |
| Storage policy | [LocalStoragePolicy](../mobile/lib/data/local_storage_policy.dart) invokes backup preparation only on iOS. Windows uses package LocalState or the separate development profile. | Preserve platform guards and profile isolation; do not invoke mobile privacy channels on Windows. |
| Clock | [NativeTimerClock](../mobile/lib/data/timer_clock.dart) uses `dev.poma.poma/timer_clock`. The [Windows host](../mobile/windows/runner/desktop_host.cpp) supplies UTC, sleep-inclusive `QueryInterruptTimePrecise` elapsed values, and null boot identity. | Use injectable wall time and local-date boundaries for calendar selection. Do not replace or reinterpret timer elapsed authority. |
| Alerts | `WindowsLocalAlerts` implements `LocalAlerts` and `CompletionPresenter`; the controller presents a resident completion only after successful persistence. | Keep meeting reminder settings, identities, receipts, and cancellation separate from timer completions. |
| Lifecycle | [DesktopController](../mobile/lib/application/desktop_controller.dart) receives visibility, deadline, resume, time-change, and Quit through `DesktopShell` and `dev.poma.poma/windows_desktop`. | Trigger calendar work independently; HTTP must not occupy the timer command queue. Add native workstation lock/unlock handling. |
| UI | [DesktopScope](../mobile/lib/ui/desktop_scope.dart), Flutter `AppShell`, and the native Win32 popup share the same authoritative timer controller. | Extend the existing native popup and Flutter Settings. `secondarySections` is currently an empty reserved display field, **not an implemented agenda renderer**. |

Add a separate `CalendarController` with ports for Google access, cache, protected credentials, external links, and calendar time. Keep normalization and Now/Next selection pure and testable. Calendar state may own its separate cache writer, but never a second timer engine or `poma.db` owner.

Extend the existing display snapshot with read-only calendar sections and opaque calendar actions. Do not serialize tokens or authoritative timer state into a new calendar owner. Calendar actions validate account identity, selection generation, and event identity against current state; timer actions retain run/revision checks. Late results after disconnect, reset, account replacement, or deselection cannot repopulate cleared data.

### Dependency compatibility decisions

The following findings are metadata/API checks from Session 1, not successful installation, resolution, compilation, or live authorization of new dependencies.

| Component | Decision | Required implementation check |
| --- | --- | --- |
| SDK and database | Retain Flutter 3.44.2/Dart 3.12.2, production `sqflite_common_ffi` 2.4.4, and `sqlite3` 3.5.2. | Preserve mobile factory selection; verify packaged SQLite resolution, production creation/reopen, and storage errors. |
| Tray/window management | Retain the native implementation. Current [tray_manager 0.8.0](https://pub.dev/packages/tray_manager) requires Flutter 3.47/Dart 3.13, above this baseline. [window_manager 0.5.2](https://pub.dev/packages/window_manager/versions/0.5.2) documents native-library migration. | No tray/window package or SDK upgrade merely to reproduce existing behavior. Revisit only for a demonstrated gap with equivalent ownership/lifecycle tests. |
| OAuth | Candidate [oauth2 2.0.5](https://pub.dev/packages/oauth2/versions/2.0.5): minimum Dart 3.4 fits; the [grant constructor](https://pub.dev/documentation/oauth2/2.0.5/oauth2/AuthorizationCodeGrant/AuthorizationCodeGrant.html) exposes PKCE. | Resolve against the lockfile; verify S256, state validation, refresh, denial/cancellation/timeout, and callback cleanup using mocked endpoints before live authorization. |
| HTTP/crypto | Reuse locked `http` 1.6.0 and `crypto` 3.0.7. | Promote a package to a direct dependency when application code imports it. Inspect resulting graph/licenses; do not equate network-capable dependencies with observed network traffic. |
| Protected credentials | Select current-user [DPAPI](https://learn.microsoft.com/en-us/windows/win32/api/dpapi/nf-dpapi-cryptprotectdata) through the native host. [flutter_secure_storage](https://pub.dev/packages/flutter_secure_storage) documents an ATL requirement absent from the recorded toolchain, so it is not selected. | Verify native build/linking, atomic protected replacement, packaged/development isolation, unreadable credentials, deletion, and no plaintext fallback. Do not use machine-wide protection. |
| Google sign-in | Do not select standard [google_sign_in](https://pub.dev/packages/google_sign_in): its listed platforms exclude Windows. | Use the desktop browser/loopback flow instead of assuming a mobile plugin supplies Windows support. |
| Lock/link adapters | Use Windows session notifications and native validated browser launching. | Verify registration/unregistration, initial lock-state detection, native linking, and packaged behavior. |

Retain the recorded VS Build Tools 2019/MSVC v142, CMake 3.20, and Windows SDK 19041 baseline unless a demonstrated failure requires a documented change. The existing notification dependency's build-local ATL compatibility treatment is not proof that a new ATL-dependent plugin will build. Record exact adopted versions, licenses, native requirements, and results in the implementation session.

## 3. Product scope and reference patterns

The first release adds optional direct Google calendar reading to Windows. Offline focus, tasks, settings, history, and supported timer alerts remain usable without an account or network. No Poma backend, analytics, phone synchronization, Google Tasks import, automatic event-to-task conversion, general calendar editor, or event mutation is introduced.

These official product descriptions are UX references, not hands-on installation, security-audit, or performance evidence for Poma.

| Reference | Platform and pattern adopted |
| --- | --- |
| [Calendar Flyout](https://leptuch.com/apps/calendar-flyout/index.html) | Windows agenda at a glance and explicit meeting access; event editing is outside Poma's pilot. |
| [ZefirCalendar](https://zefircalendar.com.br/en/) | Windows tray flyout, chronological rows, browser connection, and account settings outside the agenda. Vendor privacy claims are not Poma verification. |
| [MeetingBar](https://github.com/leits/MeetingBar) | macOS current/next priority and quick joining. Translate status-bar text into a Windows tooltip and popup. |
| [Dato](https://sindresorhus.com/dato) | macOS keyboard access, progressive detail, and calendar controls. Its macOS Calendar account bridge is not a Windows integration strategy. |
| [TickTick](https://help.ticktick.com/articles/7055781593733922816) | Treat calendar reading and task/calendar writing as separate capabilities and choices. |
| [Trevor AI](https://www.trevorai.com/integrations/google-calendar) | Reference for later explicit focus-block scheduling, not a tray implementation model. |

Poma owns its own notification-area icon and popup. It does not replace Explorer's clock flyout or inject arbitrary meeting text into the Windows taskbar. No macOS status-bar API, system account bridge, or fullscreen alert behavior is imported as a Windows requirement.

## 4. Compact popup and Windows interaction

Fictional content; at 14:22 in this example:

```text
Poma                     Today ▾       Settings
──────────────────────────────────────────────
Focus · running                  18:42
[Pause]                       [Open Poma]

NOW   Design review              ends in 8 min
14:00–14:30 · Work                       [Join]
2 overlapping events                  [Show all]

NEXT  Project planning           in 38 min
15:00–15:30 · Team                       [Join]
──────────────────────────────────────────────
TODAY
All day  Planning day · Personal
15:00    Project planning · Team    [Open event]
16:30    Catch-up · Work            [Open event]

Updated 2 min ago        [Refresh]
[Open Google Calendar]
```

Timer status/actions come first, then Now/Next, then the selected day's agenda and update status. Today, Tomorrow, and date selection cover the cached seven dates without a full calendar editor. Reopening defaults to Today. Day selection changes the agenda only; Now/Next always describes actual current time.

| Interaction | Contract |
| --- | --- |
| Left-click or keyboard activation | Toggle one compact popup. No second process, engine, or timer owner is created. |
| Right-click | Native menu: Open Poma, permitted timer controls, Refresh calendar, Calendar settings, Quit. Disable unavailable actions with meaningful state. |
| Escape or outside activation | Dismiss the popup. Keep focus predictable; opening settings or a dialog must not cause an unusable dismiss/reopen cycle. |
| Main-window Close | Follow the existing close-to-tray preference, enabled by default, with its first-use explanation. If disabled, use normal Quit behavior. |
| Quit | Stop calendar requests/triggers and resident reminders, disarm runtime deadlines, flush saved work, remove the tray icon, and exit. Preserve saved timer state/deadlines. Retain the unsaved-change confirmation; do not wait indefinitely for network work. |
| Start with Windows | Retain the disabled-by-default StartupTask and show actual Windows state. Do not enable startup as a side effect of connecting Google. |

Begin at 380 logical pixels wide, with height constrained to the monitor work area. Anchor to the actual tray-icon rectangle and its monitor, prefer above then below, and clamp within the work area. If the icon rectangle is unavailable, use the tray activation point; a Settings entry point falls back to the main-window monitor. Recalculate for mixed DPI, tray overflow, auto-hide, display removal, and Explorer restart. Never restore an unreachable popup.

Honor Windows text scaling without reducing it to fit. Measure wrapped rows and controls, provide vertical scrolling, and keep focused controls visible. Verify at least 200% text and available display scales. Long titles may use a measured compact preview, with the full title available in accessible detail; truncation must preserve Unicode correctly. Support Tab/Shift+Tab, Enter/Space, Escape, visible focus, Narrator names, high contrast, and calendar names alongside colors. Countdown updates are not continuous live announcements.

## 5. Account, authorization, and data contract

### Connection and calendar selection

Support one Google account and multiple explicitly selected calendars. Initially select none and fetch no event contents until selection is confirmed. Calendar-list metadata may be fetched to present the picker. Show calendar names, colors, and provider access roles. Disable calendars with insufficient event access. An owner/writer role does not make Poma writable: the application still requests read access only.

Use [Google's desktop OAuth guidance](https://developers.google.com/identity/protocols/oauth2/native-app): external default browser, authorization-code flow, PKCE S256, fresh unguessable state, and a temporary loopback-only callback listener. Handle denial, cancellation, timeout, malformed callbacks, and listener cleanup. Treat the desktop client as public; a packaged client secret is not a confidentiality boundary. Poma authorization is independent of Codex/MCP connector credentials.

Request only these [Calendar scopes](https://developers.google.com/workspace/calendar/api/auth):

- `https://www.googleapis.com/auth/calendar.calendarlist.readonly`
- `https://www.googleapis.com/auth/calendar.events.readonly`

Any additional scope requires a separate justification. Sessions 11–12, if requested later, design and authorize writing separately. No password or pasted refresh token is requested from the owner.

### Credentials and cache

Persist refresh credentials using current-user DPAPI protection; keep access tokens in memory where practical. No plaintext fallback, token logging, SQLite token storage, or credential inclusion in artifacts/handoffs is allowed. A protection/read failure leaves the core app usable and shows a connection-specific recovery state.

Store account-scoped calendar cache/preferences separately from `poma.db`, under the existing package LocalState root or separate development root. Keep only identities, titles, dates/times, source calendar presentation/access metadata, self-response state, and validated event/conference fields needed by the agenda/actions/reminders. Omit descriptions, attachments, and attendee rosters; discard unnecessary response fields after normalization.

Cache seven local dates, today through six days ahead. Construct individual local midnight boundaries and convert them to UTC rather than assuming seven 24-hour periods. Trim expired/out-of-window ranges even when offline and report uncovered dates. Timed events retain UTC instants and format with device locale/time preference. Date-only events retain provider dates and exclusive end dates without timezone shifting; multi-day all-day events appear on each applicable date.

The event cache is **not encrypted by Poma**. Explain this before connection; credential protection does not encrypt event storage. Windows account/device protection and external backups remain separate boundaries. Do not claim forensic deletion or portable recovery of DPAPI credentials.

Deselection purges that calendar's cache and reminders. Disconnect, account replacement, and full local reset invalidate pending work, remove relevant credentials/calendar-derived local data, and reject late responses. Disconnect preserves Pomodoro records; full reset retains its existing documented Pomodoro deletion semantics. Remote calendar events remain unchanged. Any later best-effort Google grant revocation must not delay local disconnection or imply remote revocation succeeded while offline.

## 6. Selection, refresh, and failure states

### Deterministic Now/Next

- Eligible entries come from selected calendars, have valid timed intervals, and are neither cancelled nor declined. All-day events appear separately, without countdowns or default meeting reminders. Tentative/unanswered invitations have visible labels.
- **Now:** `start <= now < end`. Show simultaneous events and their count; choose the headline by earliest end, then start, calendar order, and stable event identity.
- **Next:** earliest eligible start strictly after now; ties use end, calendar order, and stable identity. Show it alongside Now when both exist.
- Preserve account/calendar/event-instance identities. Identical-looking entries from different calendars remain separate; title equality is never a deduplication rule. Recurrence exceptions/moved instances retain source identity for actions.
- Recompute on relevant event boundaries, refresh, resume, and time/date changes. Date browsing does not simulate a different current time. Empty coverage and verified absence of events are distinct states.

### Snapshot refresh

Use Calendar's [event-instance expansion and paginated list API](https://developers.google.com/workspace/calendar/api/v3/reference/events/list). Fetch a bounded rolling window and replace a calendar's cached range only after all pages succeed. A failed page preserves the previous successful snapshot; successful calendars can update independently while failed calendars are identified. Removed events disappear after successful replacement. Defer incremental sync tokens; do not casually combine rolling-window parameters with `syncToken`.

Refresh on stale popup opening, resume, relevant time/date changes, manual Refresh, and approximately every five minutes while connected and resident. Coalesce requests, use bounded retry/backoff on failures, and avoid retrying authorization errors as transient outages. Timer ticks never initiate HTTP or calendar storage work. Use boundary/minute updates for calendar display and tooltip countdowns rather than hidden per-second rendering.

Data older than five minutes is stale. Show per-calendar last-success state, affected sources, and available coverage. Cached entries may remain visible with an explicit warning; they are not a freshly verified schedule.

| State | Calendar presentation/recovery |
| --- | --- |
| Client configuration unavailable | Explain that connection is not configured; retain offline timer controls. |
| Disconnected | Offer Connect Google; show no prior disconnected-account event data. |
| Connecting | Show progress and Cancel; preserve core app use. |
| Connected, no selection | Offer Choose calendars; do not fetch event contents yet. |
| Initial load | Show loading, not a false empty agenda. |
| Fresh, empty | State no eligible events within the selected/verified range. |
| Refreshing with cache | Keep prior content and last-success status visible. |
| Offline/stale | Label saved data and age/coverage; offer Refresh. No cache means unavailable data, not no events. |
| Partial-calendar failure | Identify affected calendars and their freshness while retaining successful results. |
| Revoked/expired authorization | Offer Reconnect; stop authenticated polling/reminder generation until repaired. Any retained cache stays explicitly stale and remains removable. |

No failure state may block core timer startup, tasks, history, settings, or locally supported alerts. Errors use safe categories, not raw response bodies, SQL, tokens, or event text.

## 7. Privacy, external actions, and reminders

**Owner decision:** show event titles in the opened popup and unlocked tray tooltip. Provide a setting to disable tooltip titles. Shorten tooltip content safely to Windows limits; title text is plain display data, never executable markup or commands.

On workstation lock, hide the popup and redact calendar details across Poma surfaces, including native tooltip/control text. Unknown lock state fails closed. Restore the selected policy after unlock. Add proper Windows session registration/unregistration and test initial state as well as transitions. This calendar protection does not retrospectively claim screenshot/app-switcher protection for all existing Poma task content.

Keep tokens, private event text, and meeting URLs out of logs, notification payloads, evidence screenshots, and handoff documents. Use fictional or redacted UI evidence.

Join appears only for a validated supported HTTPS meeting link, preferring structured conference data. Initially support Google Meet, Microsoft Teams, and Zoom using exact hostnames or correctly bounded provider subdomains; reject deceptive suffixes, embedded credentials, script/file/custom schemes, and unsafe URLs. Unsupported meetings retain Open event. Open event uses a validated Google event URL; Open Google Calendar uses Google's calendar site. Browser launching requires an explicit click and never happens during refresh, sign-in completion, or timer actions.

**Meeting reminders default off.** Enabling begins with a five-minute lead and separate per-calendar inclusion controls. Reminders use generic wording, independent identities/receipts, and one-shot deadlines. Cancel obsolete reminders after event changes, calendar deselection, disconnect/reset, or settings changes. Suppress expired reminders and stale-data catch-up storms. Respect Windows notification policy/DND; no service, wake task, guaranteed delivery after Quit, or exact sleeping delivery is promised.

Before a new focus that overlaps a meeting, offer Continue or Cancel and revalidate the timer action before applying it. Do not silently shorten durations, pause an active session, bypass strict mode, auto-start a successor, create a task, or rewrite task/history snapshots.

## 8. Timer invariants and product-document obligations

Preserve the [architecture](ARCHITECTURE.md), [local data](LOCAL_DATA.md), and [notification](NOTIFICATIONS.md) contracts:

- One timer engine/controller and ordered persistence owner; rendering is not authority.
- Reconcile expiry before controls. Reject stale run/revision actions; an expiry-consuming click cannot start or skip the Ready successor.
- Live elapsed time includes sleep. Windows provides no reliable persisted boot identity, so cold recovery retains the bounded UTC fallback and its manual-clock limitation.
- Exact pause/resume remainder, fixed segment completion timestamps, original duration, and task-title snapshots survive persistence/reopen.
- Recover at most one existing completion, never an unattended chain. Every successor starts manually.
- Completion, successor, cycle progress, and desired timer-alert state commit atomically. Unique completion/action identities suppress duplicates.
- Strict running phases retain their control restrictions. Full local reset is a separate explicit operation.
- Timer presentation follows persistence. Calendar outages never block core app use or become timer clock failures.
- No per-second storage/network work, new timer-domain effects, or second timer database writer.

The following are future implementation obligations; do not rewrite historical release evidence or claim networking exists merely because this design is saved.

| Material | Required update when behavior is implemented |
| --- | --- |
| [README](../README.md), [architecture](ARCHITECTURE.md), and package description | Describe optional Windows calendar networking alongside offline Pomodoro. Scope blanket no-account/no-network/no-polling statements to actual platform/release behavior. |
| [Local data](LOCAL_DATA.md) and bundled [Windows privacy notice](../mobile/assets/legal/privacy-windows.txt) | Describe account/cache fields, paths, retention, DPAPI boundary, disconnect/reset/uninstall, backups, and unencrypted cache. |
| [Notifications](NOTIFICATIONS.md) | Separate timer completion from opt-in meeting reminders; explain lock, stale data, sleep, Quit, cancellation, and policy limits. |
| [Privacy policy](PRIVACY_POLICY.md) and [privacy review](PRIVACY_REVIEW.md) | Add Windows release-specific Google access, direct Google requests, loopback authorization, local caching, diagnostics, and inspection results. Preserve the mobile policy's historical scope. |
| [Release checklist](RELEASE_CHECKLIST.md), [Windows release](WINDOWS_DESKTOP_RELEASE.md), [desktop acceptance](WINDOWS_DESKTOP_ACCEPTANCE.md), and [installation guide](../release/windows/INSTALL.md) | Revise offline/connection assertions for the new release; record package/network/credential/reminder tests and complete runtime contents. Keep candidate 2009 evidence intact. |
| [Third-party notices](../THIRD_PARTY_NOTICES.md), bundled notices/licenses, and [store materials](STORE_MATERIALS.md) | Record adopted dependencies/licenses and accurate platform-specific disclosures. Do not broaden mobile store/network claims unless mobile behavior changes. |

## 9. Dependency-ordered delivery and acceptance

| Session | Deliverable and completion gate |
| --- | --- |
| 2 | Verify existing offline Windows composition, production database reopen/errors, clock/recovery, lifecycle, and single ownership; repair demonstrated gaps. Do not regenerate the runner or replace implemented alerts with placeholders. Keep actual installed-owner gates open. |
| 3 | Extend the native popup with fictional fixtures, calendar display/actions, accessibility, and lock redaction. One state owner; no Google connection or real calendar reads. |
| 4 | Prepare the owner-operated Google project/API/consent/Desktop-client runbook. Configuration and account actions are a separate session. |
| 5 | Implement browser authorization, protected persistence, cancellation, reconnect, and disconnect. Check candidate dependency compatibility before live authorization. |
| 6 | Implement explicit selection, fully paginated reads, bounded cache, and refresh/recovery. Prove partial failure and late-response rejection. |
| 7 | Connect real data, deterministic agenda/Now/Next, and safe meeting/event actions. Compare only owner-prepared harmless events. |
| 8 | Add optional resident reminders and explicit focus-overlap warnings. Reuse existing timer alerts and preserve their identities/invariants. |
| 9 | Verify resilience/privacy and affected mobile behavior; record automated and owner-observed results separately. Complete the product-document updates for actual behavior. |
| 10 | Produce a higher-version private MSIX pilot with preserved identity/certificate and complete runtime/license files. Validate without development tools; do not publish or change certificate trust automatically. |

Optional Sessions 11–12 require a separate writing specification and explicit owner authorization. General event editing, automatic focus logging, and two-way task sync remain outside this pilot.

Future acceptance must cover database creation/reopen and failures; unavailable protected storage; offline startup; strict/stale/duplicate timer controls; hidden expiry, sleep/restart recovery and manual successors; recurrence exceptions, overlaps, equal titles, all-day events, deletion, pagination, DST/midnight/timezones; revoked access, account replacement and cleanup races; unsafe URLs; stale coverage and reminder cancellation; real tray/overflow, mixed monitors/DPI, large text, Narrator, lock redaction, Explorer restart, close/Quit/startup; and complete private package operation without development tools.

Carry existing results only for their exact source/build identity. Run affected checks after implementation; documentation-only Session 1 does not require replaying historical Flutter/mobile campaigns. No additional owner product choice is required to complete Session 1. Installed-desktop observations, later Google client/sign-in prerequisites, and implementation-time compatibility results remain open as detailed in the [handoff](WINDOWS_CALENDAR_PROGRESS.md).
