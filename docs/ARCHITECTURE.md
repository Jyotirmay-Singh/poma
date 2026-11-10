# Architecture decisions

## Windows Day Clock creation — Session 2

Day Clock reuses the existing reader, cache, selected calendars, regional agenda
presentation and refresh cadence. Its browsing controller owns manual date/half
and selection. `CalendarCreationController` owns a separate durable command lane;
the form retains raw fields and validates exact device-local endpoints through
the existing native resolver. The timer, task completion and focus history are
independent. Only the final reviewed action can send an ordinary event.

The existing Desktop credential owner now supports exact read/focus/creation
combinations with separate receipts in backward-compatible version 4 credentials.
Owned creation requests `calendar.events.owned`; full-set upgrades preserve prior
verified capabilities and local enablement. Candidate refresh/promotion is
serialized against credential changes. The focus writer's provenance/ownership
checks remain unchanged; it does not accept generic Day Clock events.

`GoogleCalendarEventWriter` implements owner-role preflight, create and exact-ID
readback only. Distinct `pomadc` IDs and Day Clock markers prevent confusion with
focus ownership. Native creation journal methods share the existing profile,
atomic-write helpers and credential/account invalidation owner, but have separate
leases, revisions, disablement and files. No creation operation enters the agenda
cache as a pending event or becomes a timer command. After Saved, a refresh starts
after any earlier in-flight read. Only shared Google snapshots produce sectors;
refresh failure remains Saved with a notice and event link. See DAY_CLOCK_PROGRESS.md.

## Main-window calendar schedule

The Windows Calendar page has explicit Schedule, Focus blocks and Calendar
settings destinations. Schedule presents the existing reader's retained Google
snapshots without owning credentials, persistence or timer state. Its event
adapter preserves source/instance identity, UTC timing and date-only exclusive
ends. The rolling timeline starts at the reader's first date; Day navigation
stays inside its seven-date window. Compact layouts use Day; enlarged text
defaults to an agenda. The calendar frame and view controls remain visible
before selection, with unloaded dates explicitly marked as availability unknown.

View, header, body and event interaction settings disable direct creation,
rescheduling and resizing. Reviewed focus-block operations retain the independent
write workflow. Both calendar presentations share freshness, regional formatting
and validated browser actions. Lock, account/scope invalidation and deselection
clear tiles and open details. See [Schedule behavior](CALENDAR_SCHEDULE.md).

## Windows focus scheduling — Session 12

`CalendarWriteCapability` is independent of the read connection. A separate
Desktop authorization adapter stages the exact requested full capability set
(the original read pair plus app-created access, retaining owned creation if
already granted), verifies the
same client/account and refresh lineage, then atomically promotes a DPAPI record.
Native protected commit revisions reject competing stale credential saves without
rebinding the agenda cache. Old records grant no inferred scheduling capability.
`FocusBlockController` owns a separate serialized journal lane, with immutable
confirmed operations, per-block exclusion and independent native generation/CAS
leases. It never enters the timer command queue or adds a Pomodoro database owner.
The checked Google adapter freshly verifies calendar eligibility/provenance and
event ownership, uses deterministic IDs and ETags, and exposes no general editor.
Native timezone rules resolve local endpoints and reject gaps/folds. Lock, suspend,
Quit and connection changes close outgoing work; read-only reconciliation cannot
cause a mutation. See [the implementation record](WINDOWS_CALENDAR_SESSION12.md).

## Windows desktop extension

Session 9 acceptance is recorded separately in
[Windows Calendar acceptance](WINDOWS_CALENDAR_ACCEPTANCE.md). Automated fixtures,
isolated developer runtime observations and installed owner observations have
different evidence scopes. Core restoration completes before calendar credential
restoration is started without awaiting it; calendar HTTP and cache work never
join the timer command queue. Disconnect/reset invalidate application generations
and native storage leases before asynchronous cleanup; failures remain retryable.

Calendar Session 8 adds `CalendarReminderController` with independent injectable
calendar reminder store/platform ports and no timer-domain effects. Native WinRT
toasts share package identity/COM transport but have separate groups, tokens,
response queues and cancellation. The existing timer delivery receipt and atomic
completion/successor/outbox protocol remain authoritative. A reminder document
uses the reader's current cache capability and the native account-store mutex;
it never rebinds the reader or writes `poma.db`.

The desktop Start coordinator is shared by Flutter, popup and tray controls.
It carries rendered revision/run/action, reconciles before controls, and places
permission/conflict dialogs outside serialized command queues. A full-duration
overlap warning is checked again after confirmation; lock or changed timer state
cancels Start, and changed conflicts require a fresh confirmation. Calendar
outages retain offline timer use. No task conversion or history mutation occurs.

The Windows candidate targets Windows 11 25H2 x64 and retains Flutter 3.44.2 /
Dart 3.12.2. `main.dart` selects `NativeWindowsHost`, `WindowsLocalAlerts` and
the production FFI database factory only for Windows. Mobile factory, storage
preparation, native scheduling and lifecycle behavior retain their existing
platform guards. The sections below describe mobile choices unless stated otherwise.

One Flutter engine and `AppController` own Pomodoro state. `DesktopController` projects
display snapshots to a native Win32 tray/popup and routes revision/run checked
commands back. Native code never writes SQLite or calculates authoritative
remaining time. A per-user mutex, exclusive owner lock and SID-restricted local
named pipe are acquired before Flutter/SQLite startup. Secondary launches and
COM activation relays forward to that owner.

`QueryInterruptTimePrecise` supplies sleep-inclusive microseconds. A non-waking
one-shot native trigger requests reconciliation independently of display ticking
and alert permission. Resume invalidates/re-arms relative timers using that clock;
early callbacks are also re-armed. Cold-process recovery uses the existing bounded
UTC fallback with no invented boot count.

Optional completion presentation follows the successful controller commit.
A unique delivery-attempt receipt precedes a toast. Failed saves retain the effect
for in-process retry; reset invalidates it; cold recovery suppresses toast replay.
Exactly-once history is required, but a crash between receipt and submission can
lose a notification. Native opaque action files feed the existing receipt protocol.
Open reveals Focus; neither Open nor Dismiss starts a successor.

MSIX declares the full-trust application, COM activator and disabled StartupTask.
App-owned C++/WinRT notifications avoid initializing the locked package's Windows
registry-setting adapter. No service, wake task, scheduled future toast or external
runtime is installed. Quit stops resident work, clears notifications and drains
and closes storage. SQLite's native asset and licensed C++ runtimes are packaged.

Popup `secondarySections` carries the read-only agenda display model. Calendar
state/credentials/cache/reminder identities stay separate from Pomodoro records
and authority. Historical candidate 2009 has no Google connection.
Sessions 5–6 add independent authorization and selected-calendar snapshot
controllers described below. Poma uses direct Google requests without an
app-operated network service.

See [Windows progress](WINDOWS_DESKTOP_PROGRESS.md),
[release reproduction](WINDOWS_DESKTOP_RELEASE.md) and
[observed versus pending acceptance](WINDOWS_DESKTOP_ACCEPTANCE.md).

## Scope and choice

### Windows Calendar reading and presentation — Sessions 6–7

`CalendarReadController` owns only calendar metadata, confirmed selection and
normalized event snapshots. Provider, cache, clock and scheduler interfaces are
injected at Windows composition after the core restoration barrier. Mobile
factories, the pure timer domain and authoritative SQLite schema/writer remain
unchanged. `CalendarAgendaController` derives the ordinary tray agenda from the
reader and connection; `CalendarController` supplies only the explicit fictional
Settings preview. Neither presentation controller owns timer state or persistence.

Now uses inclusive start/exclusive end, ordered by end, start, ordinal calendar
ID and stable instance identity. Next uses start, end and those identities.
All-day exclusive dates remain separate. The native selector retains a date key
while browsing and resets to Today on opening. Boundary jobs, minute age changes,
midnight and regional/time-zone changes update presentation independently of timer
ticks. Windows formats actual local times using its user short-time pattern.

Rows carry multiple named actions with opaque tokens. Activation revalidates the
current generation, account/scope, selected calendar, unchanged event and URL.
Native launch independently checks generation, unlocked state and provider URL
rules. Only a click opens the default browser; failed refreshes never launch it.
Structured video links precede hangoutLink and literal location/description
fallbacks. Raw location/description text is transient and never cached or rendered
as HTML. Both Dart and native consume the same URL safety corpus. WTS redaction
clears native rows, accessible names, preview contents and tooltip independently.

The HTTP adapter uses fixed Google HTTPS endpoints, read scopes, explicit rolling
bounds, server-expanded recurring instances and every continuation page. Calendar
IDs remain provider identities, including across pages and equal display names.
Only a saved explicit selection permits event requests. Seven device-local dates
are retained; transport bounds also cover those dates in each calendar's zone so
all-day entries at the edges are not lost. Timed instants remain UTC, all-day dates
and exclusive ends remain date values. The already-locked `timezone` 0.11.2 is a
direct dependency; no SDK/package version upgrade is introduced.

All pages stage before a per-calendar replacement. Successful calendars commit
independently; failure retains previous successful data/age/coverage. Empty
coverage differs from a successfully fetched empty snapshot. Startup, midnight,
resume and time-zone changes trim out-of-window entries even offline. An
independent five-minute resident schedule and meaningful/manual triggers coalesce
requests; minute age updates perform no storage/network work. A 401 permits one
forced coalesced token refresh/replay. Permission 403 pauses affected automatic
reads, while rate-limit 403/429 and transient errors use at most two retries,
exponential jitter and Retry-After. No sync token is requested or retained.

One versioned account document is stored under `calendar/accounts/<account-key>/`.
Native cache workers share the credential store's mutex and revision gate;
account/scope leases reject writes after account, selection, window or Quit
invalidation. Atomic flushed temporary-file replacement commits selection and
deselected-data removal together. Account documents/staging are capped at 16 MiB
and response pages at 4 MiB; excess is an explicit failure, never a truncated
successful snapshot. No timer command waits for calendar HTTP or cache workers.

The verified client/primary-calendar identity survives transient token loss.
Unusable grants are replaced by protected no-token identity metadata, allowing
stale cache and same-account reconnect selection to survive; fresh Google account
verification and a complete catalog pass precede reconnect event loading.
Explicit disconnect/account replacement/reset still clear calendar-derived data.
Details and picker controls are redacted when Windows lock state is unknown or
locked. This Sessions 6–7 behavior added no event writes, reminders, imports or
automatic browser actions; resident reminders are the separate Session 8 layer.

### Windows Calendar authorization — Session 5

`CalendarConnectionController` is independent of `AppController`'s timer command
queue and database. Windows composition injects compile-time client settings,
`DesktopGoogleAuthorization`, native browser launching and a protected credential
port. Missing configuration opens no listener or network connection. Settings
keeps actual Google status and the real agenda separate from the labelled
fictional Settings preview.

Pinned `oauth2` 2.0.5 implements code exchange/S256. Poma supplies secure random
state/verifier values, a temporary IPv4 loopback listener, cancellation/deadlines,
raw grant validation and sanitized errors. Only the two approved Calendar read
scopes are requested. One primary-calendar identity request (`id,primary`) avoids
profile scopes. Session 5 implemented authorization only; Session 6 supplies
selection and event requests through the separate reader described above.
Google/token endpoints are fixed; tests inject transports, not production URLs.

Refreshes coalesce outside timer work. Account/client identity and epochs gate
every asynchronous result. Native revision checks reject obsolete writes after
disconnect. Access tokens remain in memory; protected refresh metadata uses
current-user DPAPI with a profile-bound context and atomic ciphertext replacement.
The native store uses Windows SDK Crypt32, not an ATL-dependent storage plugin.
Disconnect persists a marker before deletion, clears calendar-only data and
attempts bounded remote revocation. A failed cleanup stays visible/retryable.
An optional local-reset participant performs this cleanup without awaiting remote
revocation on the timer queue. Core offline use, mobile adapters and schema v3
remain unchanged. Live sign-in is an owner-participation gate, not a fixture pass.

### Mobile core

Poma targets Android and iOS and works entirely offline after installation, with no signup, login, backend, or app-managed cloud sync. Settings, tasks, and history are remembered on the phone. Flutter shares UI and domain logic across both platforms. It carries an engine cost, so it is not assumed to produce the smallest possible binary. Two independently native apps could reduce some runtime overhead but would duplicate implementation and testing; Kotlin Multiplatform with native UI is a valid alternative if later measurements justify that cost.

Flutter + SQLite + a small state controller is the selected baseline. No backend service, hosting, authentication provider, or embedded Go/Python/Ruby runtime is needed. Direct production packages beyond Flutter are `sqflite`, `path`, exactly pinned `flutter_local_notifications` 22.3.2, `intl` 0.20.2 (matching the pinned SDK's `flutter_localizations`), and `sqflite_common_ffi` 2.4.4. FFI is used for production Windows storage and host database tests; Android/iOS retain their existing sqflite factory. SDK `integration_test` remains development tooling. English resources and bundled calendar formatting work offline. Mobile notification permission/settings APIs are wrapped in data; app-owned adapters supply mobile one-shot scheduling and Windows resident completion presentation. See [native alert protocol and device evidence](NOTIFICATIONS.md).

Dependency direction: UI → application → domain; data implements the application's `LocalRepository` port and uses domain records. The entry point chooses SQLite. The application never imports the data layer, and domain code imports neither Flutter nor database packages. Existing row/JSON mapping helpers are pure Dart; storage execution and platform calls remain in data/native code.

## Verified compatibility baseline

Retain Flutter 3.44.2 / Dart 3.12.2, matching the [official stable tag](https://github.com/flutter/flutter/releases/tag/3.44.2) at `c9a6c484230f8b5e408ec57be1ef71dee1e77020`. Official pub.dev metadata checked on 20 October 2026 confirms the locked direct package versions: [sqflite 2.4.4+2](https://pub.dev/packages/sqflite/versions/2.4.4+2), [path 1.9.1](https://pub.dev/packages/path/versions/1.9.1), and development-only [sqflite_common_ffi 2.4.4](https://pub.dev/packages/sqflite_common_ffi/versions/2.4.4) / [flutter_lints 6.0.0](https://pub.dev/packages/flutter_lints/versions/6.0.0). Their SDK requirements fit this baseline; newer incompatible transitive versions alone do not justify upgrading.

Android uses minimum API 24, compile/target API 36, build tools 36.0.0, NDK 28.2.13676358, AGP 9.0.1, Gradle 9.1.0, Kotlin 2.3.20, and Java 17. Retain the existing legacy Kotlin/DSL compatibility flags for this SDK. See [AGP compatibility](https://developer.android.com/build/releases/agp-9-0-0-release-notes) and [Flutter's version-specific Kotlin guidance](https://docs.flutter.dev/release/breaking-changes/migrate-to-built-in-kotlin/for-app-developers).

iOS retains the pinned Flutter SDK's iOS 13 deployment target, its UIScene/implicit-engine setup, and Swift Package Manager integration. The SQLite plugin supplies a Swift package; a Podfile is not missing work. Flutter 3.44 defaults to [SwiftPM](https://docs.flutter.dev/packages-and-plugins/swift-package-manager/for-app-developers) and requires Xcode 15 or newer (16 recommended in its release notes). Do not apply the current Flutter 3.47 support matrix retroactively to this pinned SDK. iOS compilation and native tests require macOS/Xcode; Windows Android results cannot establish them.

## State and clock

The domain state is `focus/shortBreak/longBreak × ready/running/paused`. Timer fields are read-only outside the engine. `TimerEngine.apply` and `reconcile` are synchronous operations over one supplied `ClockReading`; they perform no Flutter, storage, clock-channel, or background work. The application injects `TimerClock.sample()`, which returns UTC time and continuous elapsed microseconds. Rendering reads the last reconciled state rather than sampling clocks from getters.

### Timer transition table

Every phase control reconciles expiry first. Expiry consumes that control, including phase selection; it never starts or skips the successor. An action targeting an old revision/session returns `stale`. UI callbacks retain the revision and status of their rendered frame, so an old Pause callback cannot become Start after completion.

| Event | Allowed state / result | History and cycle |
| --- | --- | --- |
| Start | Ready → running; capture ID, start time, original duration and task snapshot | No completion |
| Resume | Paused → running; retain ID, start, duration, task and exact remaining microseconds | No completion |
| Pause | Non-strict running → paused; save exact remaining and clear deadline | No completion |
| Focus expires | Prepare short break, or long break when earned progress reaches the target; successor is ready | Record original ID once and increment progress |
| Short break expires | Prepare focus, ready | No focus history; retain progress |
| Long break expires | Prepare focus, ready | No focus history; clear progress |
| Reset | Non-strict running/paused → same phase ready, using current settings | Abandon ID; retain progress; already-ready reset is unchanged |
| Skip | Any unlocked state → successor ready | Record focus once and increment progress only for a started running/paused focus whose original duration exceeds five minutes and precise remaining time is strictly between zero and five minutes; otherwise abandon without credit. Skipping long break clears progress |
| Select phase (engine/controller API) | Any unlocked state → selected phase ready | Abandon active ID without completion; retain progress. Selecting the same active phase resets it; the same ready phase is unchanged. The Focus screen exposes no phase selector |
| Duration settings | Apply immediately to ready phases; running/paused original duration remains fixed | No completion or phase advance |
| Cycle target | Apply to subsequent phase transitions; never replace the current phase | Preserve earned progress; cap visible progress at the target |
| Strict mode | Enabling during a running phase locks immediately. All running strict phases lock pause/reset/skip/selection, timing settings and disabling strict mode | Appearance and task edits remain available; expiry still reconciles |

Start on an already active phase, Resume outside paused, and Pause outside running are unchanged. Settings commands reconcile first and then apply configuration; they cannot cause another phase transition. Default durations remain 25/5/15 minutes with four rounds. The cycle counter saturates at eight, the maximum configurable target, even if manual selections repeatedly bypass a long break; every actual focus completion still has its own history row. Only completing or skipping a long break clears the counter. Lowering and then raising a target does not discard progress. Resetting a long break or manually selecting another phase preserves it.

`canFinishEarly` exposes the shared eligibility rule without sampling a new clock or mutating state. Crossing the threshold alone never completes a phase. Skip checks eligibility after sampling the action's clock and applying expiry, revision/session and strict-mode guards. Both normal expiry and early Skip use the same focus-completion routine. `TimerTransition.completedEarly` is transient and defaults to false; an eligible Skip sets both it and `completedPhase`, preserving the existing inline completion notice while suppressing a user-triggered desktop completion toast. The shared Focus controls show localized guidance only while eligible; desktop Skip uses the same engine rule without a new action or wire format.

An early completion retains the original session ID, start and task snapshot, records the Skip instant as its UTC end, and stores actual active focus time rounded down to whole seconds. Paused time is excluded using original duration minus precise remaining time. The completion, earned progress, ready successor and alert retirement commit atomically through the existing queue. Pending deadline alerts are cancelled; failed saves and cancellations retain their existing retry/recovery behavior. Existing history, timer snapshots and the database schema are unchanged.

### Clock sources and recovery invariants

Android `dev.poma.poma/timer_clock` → `sample` uses `SystemClock.elapsedRealtimeNanos() / 1000` and supplies nullable Settings.Global.BOOT_COUNT; iOS uses `clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW) / 1000` without asserting a boot identity. Responses contain integer `utcMicros` and `elapsedMicros`. Both elapsed sources include device sleep. Missing/malformed/regressing readings produce a visible, retryable clock error; there is no live wall-clock fallback. The ticker stops on a clock error and reconciliation can recover on retry.

This choice follows the pinned Dart 3.12.2 source: [Stopwatch delegates to OS monotonic ticks](https://github.com/dart-lang/sdk/blob/3.12.2/runtime/lib/stopwatch.cc), [Android uses CLOCK_MONOTONIC](https://github.com/dart-lang/sdk/blob/3.12.2/runtime/vm/os_android.cc), and [iOS/macOS use CLOCK_MONOTONIC_RAW](https://github.com/dart-lang/sdk/blob/3.12.2/runtime/vm/os_macos.cc). Android CLOCK_MONOTONIC excludes deep sleep. [Android's SystemClock guidance](https://developer.android.com/reference/android/os/SystemClock) specifies elapsedRealtime for intervals spanning sleep. [Apple's continuous-clock documentation](https://developer.apple.com/documentation/kernel/1646199-mach_continuous_time) identifies CLOCK_MONOTONIC_RAW as the equivalent sleep-inclusive clock. These are source/API findings, not measured phone results.

Invariants:

- Live remaining = segment remaining − continuous elapsed since its anchor. Callback counts and wall time never drive it. Only displayed seconds round upward; storage, pause/resume and dial progress retain microseconds.
- Each start/resume captures a fixed UTC segment deadline. Delayed expiry and live wall-clock changes do not move its expiry history timestamp; an eligible early Skip records its own sampled UTC instant. Pausing retains the original session start; the start/end span includes pauses while `focusSeconds` excludes paused time.
- Across a dead process on the same known Android boot, running recovery compares persisted elapsed deadlines with the native elapsed clock. After reboot, on iOS process restoration, or for legacy snapshots without identity, recovery uses the saved UTC deadline. Paused recovery uses saved remaining microseconds. Overdue recovery records at the saved deadline and advances one phase only. A future deadline beyond the original duration is capped and checkpointed once.
- Only an explicitly started phase can complete. Breaks have IDs for future alerts but never create focus history. Reset and selection abandon rather than complete; Skip completes only an eligible focus session. Every successor is ready.
- Task identity/title and duration are captured at start and survive task rename, completion, deletion, reselection, settings edits and paused recovery.
- UTC fallback cannot distinguish elapsed time from manual wall-clock changes around reboot or an iOS process restart. Android snapshots now persist boot count, elapsed deadline and a running-segment number; different/unknown boot identities never reuse elapsed values. Android receivers explicitly reconcile boot, package replacement, time/timezone changes and exact-access grants. iOS observes significant-time/timezone changes while running and repairs on launch/resume; it has no boot receiver or claimed reboot-proof identity. These combinations remain physical-device release gates.
- Timezone changes do not change UTC deadlines or duration. History is grouped from each completion instant in the current local timezone, so a timezone change can legitimately move its day grouping. Tests inject a local-time conversion to avoid depending on the host timezone.

### Reconciliation and Session 3 integration

`AppController.reconcile()` is awaitable and is used on launch, foreground entry and refresh. `handleTimerAction(action, runId: ...)` supports explicit pause/resume/reset/skip with a nonempty persisted session ID. Sampling and commands are serialized; queued UI controls also carry a revision. A stale action can reconcile an independently overdue current phase, but its requested control never affects another session.

`ReconciliationResult` contains the snapshot, typed transition/outcome, optional focus completion, clock status, persistence status, alert availability and optional `TimerAlertIntent`. `TimerTransition.previousRunId` preserves cancellation identity even for a completed break. The running intent includes session/phase/remaining, a wall projection, and optional persisted notification ID/generation when alerts are enabled. That projection can differ from the fixed history/recovery deadline after a live clock adjustment. The serialized coordinator owns OS effects and uses the committed outbox with native elapsed/interval scheduling; callers must not schedule directly from an uncommitted result.

`PersistenceOutcome.saved` means this operation's transaction succeeded; `notRequired` means no write was needed and there is no known outstanding save failure; `failed` includes outstanding failed saves on unchanged reconciliation. Do not treat a successful Future alone as proof of durability. On clock/save failure, retain state and retry before assuming an alert is durably backed. `alert == null` after successful reconciliation means cancel obsolete requests and leave the successor ready. On clock failure it means scheduling information is unavailable, not evidence that a running phase ended.

Native notifications are integrated through the application's LocalAlerts port and serialized AlertCoordinator. Desired requests include persisted session/generation/notification identity and timing anchors. Reconciliation results also expose notification identity and typed availability. Native alarm/response handlers do not run an independent Dart timer owner: Android posts directly from a short receiver, iOS delivery is system-owned, and Open/Dismiss events use native journals plus unique SQLite action receipts. Dismiss never starts a phase. No automatic chains, polling, foreground service or additional/headless Flutter engine is installed. The full registration/cancellation crash protocol, OS constraints and unobserved device matrix are in [NOTIFICATIONS.md](NOTIFICATIONS.md).

## Persistence

SQLite schema version 3 retains `app_state`, ordered `tasks`, unique `sessions`, and the v2 `notification_state`/`notification_receipts` native contract. Explicit v1→v2→v3 migrations validate legacy state and backfill numeric completion microseconds in bounded batches inside one transaction. V3 adds a completion-time/ID index, task-position/ID index, and commit revision/identity/cleanup metadata. Opening is shared and closing waits for opening. Each app connection uses SQLite synchronous FULL. Unsupported schema versions and malformed data fail safely without deleting or recreating the database.

`LocalRepository.loadInitial`, `commit`, `readHistoryPage` and `readDaySummaries` separate bootstrap, incremental mutations, and bounded reads. Writes carry only dirty task IDs, deleted IDs, new completions and small state checkpoints. Append positions are allocated transactionally; deletion leaves gaps rather than renumbering unrelated tasks. Completion, advanced timer/cycle progress and desired alerts commit atomically. Identical session duplicates are idempotent; conflicting contents are rejected. Native receipt insertion remains unique and independent of application commit revisions.

The ordered writer retains failed requests and later changes in memory, acknowledges only committed changes, and uses commit tokens/revisions to resolve uncertain acknowledgements and reject stale saves. A confirmed reset is a barrier which supersedes older unsaved data, invalidates old callbacks/reads, and preserves later task edits. OS effects occur after the database commit; an opaque reset marker repairs interrupted native alert/journal cleanup on retry/reopen. Ordinary edits remain available on save failure with a persistent unsaved warning. Diagnostics contain safe failure categories rather than user text or SQL arguments.

Both running and paused restored timers must have a nonempty identity and start time; running requires a deadline, while paused forbids a deadline and requires positive remaining time. Ready snapshots require full duration and no session metadata. Numeric bounds, remaining ≤ original duration, task ID/title pairs, enum names, timestamp types, calendar components and UTC offsets are validated without silently clamping corruption. Valid version-1 snapshots and the SQLite schema/location remain supported. Invalid snapshots fail at startup without rewriting database bytes. Startup retry keeps its synchronous `setState` callback and reopens existing data.

Startup does not enumerate history. Indexed local-day aggregates return today or at most seven days; Insights holds one 50-session page. Cursor queries use separate timestamp and equal-timestamp/ID seeks, avoiding OFFSET and tie-related rescans. Async read generations reject obsolete results after navigation, mutation, reset and timezone changes. Local calendar midnights determine UTC ranges, including daylight-saving days; completion timestamps never change to the reopen date. Foreground midnight refresh is a single-shot timer, not periodic database polling. See [local retention, deletion, recovery and verification](LOCAL_DATA.md); export/import is deliberately deferred.

## Resource policy

No downloaded fonts, videos, raster illustration bundle, analytics, ads, or one-second database writes are introduced. Mobile performs no background polling. Connected Windows Calendar has a coalesced five-minute resident refresh, minute presentation-age updates, midnight/event-boundary jobs and one-shot reminder deadlines; these are independent of timer ticks. A foreground running timer uses one callback per second and at most one pending rendering refresh. It samples the native clock but saves only if a timer/desired-alert transition occurs. User/settings/task changes and leaving an active foreground session checkpoint state; repeated unchanged lifecycle events do not write. Native alert status/synchronization runs on meaningful transitions and explicit reconciliation events, not each ticker callback. The ticker is cancelled immediately on inactivity, pause, completion, clock error or disposal. A delayed clock response checks current lifecycle/disposal state before restarting anything. The custom dial repaints on progress changes. Mobile uses OS-scheduled local alerts; Windows uses resident deadlines and presentation. No service or app-held wake lock is added. Quit stops Windows refresh, reminder and expiry jobs. Session 9 resource samples describe their exact synthetic host conditions and establish no performance or battery guarantee.

Provisional engineering targets, not established results: compressed arm64 release APK at or below 20 MiB, p95 frames within the 60 Hz frame budget on the chosen baseline phone, and a median cold launch under 1.5 seconds on that phone. Record device, OS, build mode, ABI, sample count, and methods. Debug build size and simulator speed are not release measurements. Battery and memory budgets need real-device baselines before setting a defensible numeric limit.

Session 6 retains the startup alert/restoration safety barrier and reduces a
demonstrated duplicate summary read from two to one per meaningful startup or
foreground/calendar event. Unchanged events read/write nothing. A native
one-shot fully-drawn marker reports the first restored screen separately from
Android's initial-display timestamp; it does not control the timer. Fresh G54
release results, accounting scopes, collector limitations and remaining gates
are in [release evidence](RELEASE_EVIDENCE.md). No framework rewrite, assumed
battery benefit or numeric memory/energy promise follows from source structure.

## Offline product contract

All Pomodoro functions must remain usable in airplane mode: focus and break cycles, custom durations, start/pause/resume/reset/skip, strict mode, tasks, history, appearance settings, and native local alerts subject to OS permission/delivery policy. Persist state in SQLite so restarting the app does not require a server or an account. Notification permission is a local OS choice and must not depend on signup or remote push registration.

The offline mobile/core boundary excludes accounts, personal-profile collection,
remote storage, cloud synchronization, pending upload queues, analytics, ads and
network-dependent configuration. Optional Windows Calendar authorization is a
separate, explicitly enabled boundary. Installation and optional store updates
are separate from offline app use. Developer tooling is separate from the app.

Settings, tasks, and history are retained on the phone without requesting identity information. History stays until explicitly deleted; confirmed per-session deletion, clear history and full local reset are available. Export/import is deferred. The selected database backup-exclusion policy is retained; uninstalling the app or losing the phone has no automatic recovery path. The database path is unchanged; schema v3 preserves the v2 native alert contract. Native response journals contain only opaque session/generation/action identifiers and the app-private database locator, never task text; SQLite is authoritative when rejecting restored/stale responses.

Android sets `allowBackup=false`, declares full-backup exclusions for older devices, and supplies explicit cloud-backup and device-transfer exclusions for Android 12+. All supported app-storage domains are excluded. This follows [Android's backup rules](https://developer.android.com/identity/data/autobackup), including the need for transfer rules beyond `allowBackup=false` on some devices. Packaged configuration can be checked on Windows; actual backup/transfer behavior remains a device release gate, including OEM and future cross-platform-transfer behavior.

Before SQLite opens on iOS, `LocalStoragePolicy` calls `dev.poma.poma/local_storage` → `excludeFromBackup` with a `directory` string. Swift registers the channel in `didInitializeImplicitFlutterEngine`, canonicalizes the path, rejects the container root/outside paths, creates the directory if needed, sets and reads back `URLResourceValues.isExcludedFromBackup=true`, and returns success or a platform error. Directory exclusion covers `poma.db` and its journal/WAL/SHM companions, including newly created sidecars. Missing bridge or native errors stop startup with a privacy-specific retry message; no database is opened or erased. Android uses manifest rules and makes no iOS bridge call. Tests use injected storage policy/platform seams without adding runtime services.

See [Apple's backup guidance](https://developer.apple.com/documentation/foundation/optimizing-your-app-s-data-for-icloud-backup). The Swift implementation and native tests are present but must be compiled and exercised on macOS/iOS before claiming runtime verification. Exclusions do not erase copies made by an older version, promise encryption, or override every OS/OEM backup mechanism. Reapply the directory flag on each database open; revisit it if a later feature replaces or moves the directory.

## Design intent

Screen refinement retains SQLite v3 and native alert wire identities unchanged. The controller exposes read-only active task snapshot metadata, save-failure kind and a transient completed-run/phase notice. Only actual completion transitions set this notice, including overdue launch recovery; subsequent effective timer controls/full reset clear it. It is not inferred from history or persisted as a new schema field. Ready timers reopened after an already-saved completion do not claim a fresh completion. The shell limits live-region presentation to the first viewing of a completed run; the dial countdown is not a live region.

The 22 October 2026 Focus update presents only the current phase in the dial, with no mode chips or large-text dropdown. A fresh cycle starts in focus; each completed focus prepares a short break until the configured final round, which prepares a long break. Short breaks prepare focus; a completed long break resets cycle progress and prepares focus. Every successor remains ready for its phase-specific Start action. Tab navigation and process restoration display the existing saved phase rather than forcing focus. The controller's phase-selection API remains available to internal callers and tests; removing its UI controls changes no public interface, schema, settings, or native alert identity.

Each screen's errors and content share one scroll region. Measured navigation labels wrap when required. The larger countdown uses tabular figures; its full text block is measured against the dial's circular inner bounds, including its corners. If it would crowd the tick marks, the countdown flows below the ring without clamping accessibility scaling. History and settings controls reflow; exact daily text accompanies the supplementary chart. App-only strict-mode limits and actual alert availability are stated plainly, with OS-settings/retry actions. No rendering callback schedules an alert, writes data or requests permission.

English ICU resources include placeholders/plurals and safety messages. Product locales remain English only; device calendar locale and 12/24-hour preference are formatted separately from the supported translation list, with bundled locale data and safe fallback. Native alert content uses Android/iOS English string resources. There is no schema migration, translated task data or change to the persisted UTC instants. See [screen verification](UI_VERIFICATION.md) and the [accessibility ledger](ACCESSIBILITY.md).

Palette: paper silver `#F8F9FD`, slate `#252D43`, muted slate `#5F687E`, iris `#6854C8`, teal `#147D80`; dark surface `#1C2332`. System typography avoids network and font payload. Timer digits use tabular figures. The instrument-like dial is the single visual emphasis. All primary actions are literal and use native controls.

The layout is a vertically scrollable, left-aligned page with a centered timer, round progress, primary action, selected task, and daily totals. The primary Start/Pause/Resume action sits above the Reset/Skip row. Four stable destinations expose focus, tasks, insights, and settings. The phase name and countdown share one semantic readout, with ready/running/paused state and remaining time. No decorative gradients or looping animations are required.

```text
Focus                     Tasks / Insights / Settings
  heading                   heading
      current-phase dial    content and real empty states
      countdown             native controls
      cycle count
  primary start / pause / resume
  reset / skip
  selected task
  daily totals
---------------- bottom navigation -----------------
```

## Windows fictional calendar preview — Session 3

The existing native popup now renders typed `secondarySections` from an in-memory `CalendarController`, owned by `DesktopController`. It has no repository, provider, credentials, HTTP or browser port. A Settings selector exposes nine explicitly fictional scenarios and resets to disconnected after process exit. Only the original `AppController` owns the timer and ordered Pomodoro writes; native timer commands keep run/revision checks, while calendar preview actions use their own generation and opaque action IDs.

The Win32 shell keeps one tray GUID, popup and Flutter engine. Popup Escape/outside/Alt+F4 hide its window; Open Poma returns to Focus, and Calendar settings resets the full Settings page to its preview section. Main Close/Quit/startup retain their separate existing contracts. WTS session notifications and initial session inspection independently gate calendar controls/tooltips in the native host; locked and unknown states redact details, separately from timer strict mode. Calendar presentation updates use a minute cadence rather than per-second storage/network work. Real provider/cache/link/reminder work remains outside Session 3. See [the calendar handoff](WINDOWS_CALENDAR_PROGRESS.md) for exact build identity and observed versus unobserved desktop cases.
