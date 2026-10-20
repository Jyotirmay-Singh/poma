# Architecture decisions

## Scope and choice

Poma targets Android and iOS and works entirely offline after installation, with no signup, login, backend, or app-managed cloud sync. Settings, tasks, and history are remembered on the phone. Flutter shares UI and domain logic across both platforms. It carries an engine cost, so it is not assumed to produce the smallest possible binary. Two independently native apps could reduce some runtime overhead but would duplicate implementation and testing; Kotlin Multiplatform with native UI is a valid alternative if later measurements justify that cost.

Flutter + system SQLite + a small state controller is the selected baseline. No backend service, hosting, authentication provider, or embedded Go/Python/Ruby runtime is needed. The only direct production packages beyond Flutter are `sqflite` and `path`; `sqflite_common_ffi` is for database tests on the host.

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
| Skip | Any unlocked state → successor ready | Never record focus; skipping long break clears progress |
| Select phase | Any unlocked state → selected phase ready | Abandon active ID without completion; retain progress. Selecting the same active phase resets it; the same ready phase is unchanged |
| Duration settings | Apply immediately to ready phases; running/paused original duration remains fixed | No completion or phase advance |
| Cycle target | Apply to subsequent phase choices; never replace the current phase | Preserve earned progress; cap visible progress at the target |
| Strict mode | Enabling during a running phase locks immediately. All running strict phases lock pause/reset/skip/selection, timing settings and disabling strict mode | Appearance and task edits remain available; expiry still reconciles |

Start on an already active phase, Resume outside paused, and Pause outside running are unchanged. Settings commands reconcile first and then apply configuration; they cannot cause another phase transition. Default durations remain 25/5/15 minutes with four rounds. The cycle counter saturates at eight, the maximum configurable target, even if manual selections repeatedly bypass a long break; every actual focus completion still has its own history row. Only completing or skipping a long break clears the counter. Lowering and then raising a target does not discard progress. Resetting a long break or manually selecting another phase preserves it.

### Clock sources and recovery invariants

Android `dev.poma.poma/timer_clock` → `sample` uses `SystemClock.elapsedRealtimeNanos() / 1000`; iOS uses `clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW) / 1000`. Responses contain integer `utcMicros` and `elapsedMicros`. Both elapsed sources include device sleep. Missing/malformed/regressing readings produce a visible, retryable clock error; there is no wall-clock fallback. The ticker stops on a clock error and reconciliation can recover on retry.

This choice follows the pinned Dart 3.12.2 source: [Stopwatch delegates to OS monotonic ticks](https://github.com/dart-lang/sdk/blob/3.12.2/runtime/lib/stopwatch.cc), [Android uses CLOCK_MONOTONIC](https://github.com/dart-lang/sdk/blob/3.12.2/runtime/vm/os_android.cc), and [iOS/macOS use CLOCK_MONOTONIC_RAW](https://github.com/dart-lang/sdk/blob/3.12.2/runtime/vm/os_macos.cc). Android CLOCK_MONOTONIC excludes deep sleep. [Android's SystemClock guidance](https://developer.android.com/reference/android/os/SystemClock) specifies elapsedRealtime for intervals spanning sleep. [Apple's continuous-clock documentation](https://developer.apple.com/documentation/kernel/1646199-mach_continuous_time) identifies CLOCK_MONOTONIC_RAW as the equivalent sleep-inclusive clock. These are source/API findings, not measured phone results.

Invariants:

- Live remaining = segment remaining − continuous elapsed since its anchor. Callback counts and wall time never drive it. Only displayed seconds round upward; storage, pause/resume and dial progress retain microseconds.
- Each start/resume captures a fixed UTC segment deadline. Delayed completion and live wall-clock changes do not move its history timestamp. Pausing retains the original session start; the start/end span includes pauses while `focusSeconds` excludes paused time.
- Across a dead process, running recovery uses the saved UTC deadline; paused recovery uses saved remaining microseconds. Overdue recovery records at the saved deadline and advances one phase only. A future deadline beyond the original duration is capped and checkpointed once.
- Only an explicitly started phase can complete. Breaks have IDs for future alerts but never create focus history. Reset, skip and selection abandon rather than complete. Every successor is ready.
- Task identity/title and duration are captured at start and survive task rename, completion, deletion, reselection, settings edits and paused recovery.
- UTC deadlines cannot distinguish elapsed time from manual wall-clock changes across restarts. Reboot recovery still uses UTC; boot-relative readings are not persisted or compared between processes. A wall-clock change followed by process death can affect recovery and calendar timestamps. Native boot identity, time-change notification handling and reboot alert rescheduling remain Session 3/release work.
- Timezone changes do not change UTC deadlines or duration. History is grouped from each completion instant in the current local timezone, so a timezone change can legitimately move its day grouping. Tests inject a local-time conversion to avoid depending on the host timezone.

### Reconciliation and Session 3 integration

`AppController.reconcile()` is awaitable and is used on launch, foreground entry and refresh. `handleTimerAction(action, runId: ...)` supports explicit pause/resume/reset/skip with a nonempty persisted session ID. Sampling and commands are serialized; queued UI controls also carry a revision. A stale action can reconcile an independently overdue current phase, but its requested control never affects another session.

`ReconciliationResult` contains the snapshot, typed transition/outcome, optional focus completion, clock status, persistence status and optional `TimerAlertIntent`. `TimerTransition.previousRunId` preserves cancellation identity even for a completed break. The alert intent exists only for running state and includes ID, phase, exact remaining and a deadline projected against the current wall sample. That scheduling projection can differ from the fixed history/recovery deadline after a live clock adjustment. Session 3 should choose OS elapsed/interval scheduling where supported and always reconcile before scheduling.

`PersistenceOutcome.saved` means this operation's transaction succeeded; `notRequired` means no write was needed and there is no known outstanding save failure; `failed` includes outstanding failed saves on unchanged reconciliation. Do not treat a successful Future alone as proof of durability. On clock/save failure, retain state and retry before assuming an alert is durably backed. `alert == null` after successful reconciliation means cancel obsolete requests and leave the successor ready. On clock failure it means scheduling information is unavailable, not evidence that a running phase ended.

There are currently no native notification handlers, permissions, scheduled alerts or automatic chains. Session 3 must reconcile pending OS requests and database/OS crash gaps, register the clock bridge for any additional/headless Flutter engine, and coordinate a single state owner across background actions. The current bridge is registered with the app's normal engine. A locked phone does not need Dart execution or per-second saves for later recovery; delivery of an alert while closed still requires Session 3.

## Persistence

SQLite schema version 1 has `app_state`, ordered `tasks`, and `sessions` with a unique session ID and an end-time index. A transaction commits the updated countdown and completed history together. Repeated insertion of the same completion is ignored by primary key. Writes are queued in user-action order. Errors retain in-memory state, expose a retry, and do not erase an unreadable database.

Both running and paused restored timers must have a nonempty identity and start time; running requires a deadline, while paused forbids a deadline and requires positive remaining time. Ready snapshots require full duration and no session metadata. Numeric bounds, remaining ≤ original duration, task ID/title pairs, enum names, timestamp types, calendar components and UTC offsets are validated without silently clamping corruption. Valid version-1 snapshots and the SQLite schema/location remain supported. Invalid snapshots fail at startup without rewriting database bytes. Startup retry keeps its synchronous `setState` callback and reopens existing data.

For this small starter, saves replace the task list and attempt idempotent inserts of known sessions, and history loads into memory. Incremental writes, paginated history, retention/export, migration fixtures, and fault-injection tests are needed before large-scale use. This baseline is intended for a small local history.

## Resource policy

No downloaded fonts, videos, raster illustration bundle, analytics, ads, background polling, or one-second database writes. A foreground running timer uses one callback per second and at most one pending rendering refresh. It samples the native clock but saves only if a timer transition occurs. User/settings/task changes and leaving an active foreground session checkpoint state; repeated unchanged lifecycle events do not write. The ticker is cancelled immediately on inactivity, pause, completion, clock error or disposal. A delayed clock response checks current lifecycle/disposal state before restarting anything. The custom dial repaints on progress changes. Native OS-scheduled local alerts are required in session 3 and replace continuous background execution; no service or wake lock is added here.

Provisional engineering targets, not established results: compressed arm64 release APK at or below 20 MiB, p95 frames within the 60 Hz frame budget on the chosen baseline phone, and a median cold launch under 1.5 seconds on that phone. Record device, OS, build mode, ABI, sample count, and methods. Debug build size and simulator speed are not release measurements. Battery and memory budgets need real-device baselines before setting a defensible numeric limit.

## Offline product contract

All Pomodoro functions must remain usable in airplane mode: focus and break cycles, custom durations, start/pause/resume/reset/skip, strict mode, tasks, history, appearance settings, and native local alerts once implemented. Persist state in SQLite so restarting the app does not require a server or an account. Notification permission is a local OS choice and must not depend on signup or remote push registration.

Do not introduce accounts, personal-profile collection, remote storage, cloud synchronization, sync contracts, pending upload queues, analytics, ads, or network-dependent configuration. Installation and optional store updates are separate from offline app use. Developer tooling is separate from the installed app.

Settings, tasks, and history are retained on the phone without requesting identity information. Export/import, if added, must be an explicit local user action. The selected policy excludes Poma data from automatic backups; uninstalling the app or losing the phone has no automatic recovery path. The database path and schema are unchanged, and no existing local data is deleted or migrated.

Android sets `allowBackup=false`, declares full-backup exclusions for older devices, and supplies explicit cloud-backup and device-transfer exclusions for Android 12+. All supported app-storage domains are excluded. This follows [Android's backup rules](https://developer.android.com/identity/data/autobackup), including the need for transfer rules beyond `allowBackup=false` on some devices. Packaged configuration can be checked on Windows; actual backup/transfer behavior remains a device release gate, including OEM and future cross-platform-transfer behavior.

Before SQLite opens on iOS, `LocalStoragePolicy` calls `dev.poma.poma/local_storage` → `excludeFromBackup` with a `directory` string. Swift registers the channel in `didInitializeImplicitFlutterEngine`, canonicalizes the path, rejects the container root/outside paths, creates the directory if needed, sets and reads back `URLResourceValues.isExcludedFromBackup=true`, and returns success or a platform error. Directory exclusion covers `poma.db` and its journal/WAL/SHM companions, including newly created sidecars. Missing bridge or native errors stop startup with a privacy-specific retry message; no database is opened or erased. Android uses manifest rules and makes no iOS bridge call. Tests use injected storage policy/platform seams without adding runtime services.

See [Apple's backup guidance](https://developer.apple.com/documentation/foundation/optimizing-your-app-s-data-for-icloud-backup). The Swift implementation and native tests are present but must be compiled and exercised on macOS/iOS before claiming runtime verification. Exclusions do not erase copies made by an older version, promise encryption, or override every OS/OEM backup mechanism. Reapply the directory flag on each database open; revisit it if a later feature replaces or moves the directory.

## Design intent

Palette: paper silver `#F8F9FD`, slate `#252D43`, muted slate `#5F687E`, iris `#6854C8`, teal `#147D80`; dark surface `#1C2332`. System typography avoids network and font payload. Timer digits use tabular figures. The instrument-like dial is the single visual emphasis. All primary actions are literal and use native controls.

The layout is a vertically scrollable, left-aligned page with a centered timer, primary action, selected task, and daily totals. Four stable destinations expose focus, tasks, insights, and settings. Large text stacks timer controls vertically. No decorative gradients or looping animations are required.

```text
Focus                     Tasks / Insights / Settings
  heading                   heading
  phase choices             content and real empty states
      timer dial            native controls
      cycle count
  reset / start / skip
  selected task
  daily totals
---------------- bottom navigation -----------------
```
