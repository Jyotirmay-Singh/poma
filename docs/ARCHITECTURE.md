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

The domain state is `phase × ready/running/paused`, with the original duration, remaining microseconds, completion count, session identity, and task snapshot. A monotonic elapsed-time anchor drives a running process. A saved UTC deadline recovers a running timer after restart. Paused timers save remaining duration. A delayed tick finishes only the current phase and leaves the next phase ready. History uses the calculated completion instant rather than the time the user reopened the app.

Manual controls reconcile an overdue phase before acting. Strict mode locks in-app pause, reset, skip, and phase changes while running; it does not enforce operating-system restrictions. Changing durations preserves the active session's original duration. Completed rounds are capped at the configured cycle length and reset after a long break.

UTC deadlines cannot distinguish elapsed time from manual clock changes across a dead process. Native monotonic/boot identity storage and an explicit reboot/time-change policy need evaluation before release. A timezone change affects local day grouping, not the timer duration. Paused wall time is excluded from focus duration but the stored start/end span can include pauses.

## Persistence

SQLite schema version 1 has `app_state`, ordered `tasks`, and `sessions` with a unique session ID and an end-time index. A transaction commits the updated countdown and completed history together. Repeated insertion of the same completion is ignored by primary key. Writes are queued in user-action order. Errors retain in-memory state, expose a retry, and do not erase an unreadable database.

Both running and paused restored timers must have a nonempty session identity and a start time; running timers also require a deadline. Incomplete snapshots fail at startup without overwriting the saved database, rather than crashing later during completion. Valid paused sessions resume with their original identity and task snapshot. Startup retry uses a synchronous `setState` callback; asynchronous loading is stored as a future.

For this small starter, saves replace the task list and attempt idempotent inserts of known sessions, and history loads into memory. Incremental writes, paginated history, retention/export, migration fixtures, and fault-injection tests are needed before large-scale use. This baseline is intended for a small local history.

## Resource policy

No downloaded fonts, videos, raster illustration bundle, analytics, ads, background polling, or one-second database writes. A visible running timer uses one callback per second. The callback is cancelled when the app is inactive or the timer is idle. The custom dial repaints on progress changes. Native OS-scheduled local alerts are required in session 3 and replace continuous background execution; a foreground service must have a measured, platform-compliant reason.

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
