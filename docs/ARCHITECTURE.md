# Architecture decisions

## Scope and choice

Poma targets Android and iOS and works entirely offline after installation, with no signup, login, backend, or app-managed cloud sync. Settings, tasks, and history are remembered on the phone. Flutter shares UI and domain logic across both platforms. It carries an engine cost, so it is not assumed to produce the smallest possible binary. Two independently native apps could reduce some runtime overhead but would duplicate implementation and testing; Kotlin Multiplatform with native UI is a valid alternative if later measurements justify that cost.

Flutter + system SQLite + a small state controller is the selected baseline. No backend service, hosting, authentication provider, or embedded Go/Python/Ruby runtime is needed. The only direct production packages beyond Flutter are `sqflite` and `path`; `sqflite_common_ffi` is for database tests on the host.

## State and clock

The domain state is `phase × ready/running/paused`, with the original duration, remaining microseconds, completion count, session identity, and task snapshot. A monotonic elapsed-time anchor drives a running process. A saved UTC deadline recovers a running timer after restart. Paused timers save remaining duration. A delayed tick finishes only the current phase and leaves the next phase ready. History uses the calculated completion instant rather than the time the user reopened the app.

Manual controls reconcile an overdue phase before acting. Strict mode locks in-app pause, reset, skip, and phase changes while running; it does not enforce operating-system restrictions. Changing durations preserves the active session's original duration. Completed rounds are capped at the configured cycle length and reset after a long break.

UTC deadlines cannot distinguish elapsed time from manual clock changes across a dead process. Native monotonic/boot identity storage and an explicit reboot/time-change policy need evaluation before release. A timezone change affects local day grouping, not the timer duration. Paused wall time is excluded from focus duration but the stored start/end span can include pauses.

## Persistence

SQLite schema version 1 has `app_state`, ordered `tasks`, and `sessions` with a unique session ID and an end-time index. A transaction commits the updated countdown and completed history together. Repeated insertion of the same completion is ignored by primary key. Writes are queued in user-action order. Errors retain in-memory state, expose a retry, and do not erase an unreadable database.

For this small starter, saves replace the task list and attempt idempotent inserts of known sessions, and history loads into memory. Incremental writes, paginated history, retention/export, migration fixtures, and fault-injection tests are needed before large-scale use. This baseline is intended for a small local history.

## Resource policy

No downloaded fonts, videos, raster illustration bundle, analytics, ads, background polling, or one-second database writes. A visible running timer uses one callback per second. The callback is cancelled when the app is inactive or the timer is idle. The custom dial repaints on progress changes. Native notifications should replace continuous background execution; a foreground service must have a measured, platform-compliant reason.

Provisional engineering targets, not established results: compressed arm64 release APK at or below 20 MiB, p95 frames within the 60 Hz frame budget on the chosen baseline phone, and a median cold launch under 1.5 seconds on that phone. Record device, OS, build mode, ABI, sample count, and methods. Debug build size and simulator speed are not release measurements. Battery and memory budgets need real-device baselines before setting a defensible numeric limit.

## Offline product contract

All Pomodoro functions must remain usable in airplane mode: focus and break cycles, custom durations, start/pause/resume/reset/skip, strict mode, tasks, history, appearance settings, and native local alerts once implemented. Persist state in SQLite so restarting the app does not require a server or an account. Notification permission is a local OS choice and must not depend on signup or remote push registration.

Do not introduce accounts, personal-profile collection, remote storage, cloud synchronization, sync contracts, pending upload queues, analytics, ads, or network-dependent configuration. Installation and optional store updates are separate from offline app use. Developer tooling is separate from the installed app.

Settings, tasks, and history are retained on the phone without requesting identity information. Export/import, if added, must be an explicit local user action. The starter currently inherits OS backup defaults; review those choices against the local-data intent before production and describe actual behavior accurately. Do not claim OS backups are disabled until that is implemented and verified.

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
