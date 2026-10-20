# Local data and ownership

Poma's installed Android and iOS apps use local SQLite. Timers, tasks, settings, history, and OS-scheduled completion alerts need no computer, server, account, or internet. A phase starts only when the person starts it. There is no sync service, upload queue, telemetry, or remote configuration.

## Retention and deletion

History is retained indefinitely until explicitly deleted. Task deletion does not remove the task identity/title already captured by an active or completed focus session. Rename, completion, and selection changes do not rewrite those snapshots.

Insights offers individual session deletion. Settings offers **Clear focus history** and **Delete all local data**, each with confirmation. Clearing history removes completed sessions and changes displayed totals, without resetting the active timer or earned cycle progress. A still-active session can finish afterward and add a new history entry. An overdue session is reconciled before clearing history, so reopening cannot attribute it to the deletion/reopen date.

Full local reset abandons the active phase without counting it, including in strict mode, clears tasks/history/app preferences and old action receipts, and restores app defaults. It cancels Poma's pending/delivered alerts and clears native response/scheduling journals. System notification permission is controlled by the OS and is not revoked by an app reset. An opaque cleanup marker remains until native cleanup and its acknowledgement succeed; retry and reopening resume unfinished cleanup. New timer starts wait for this cleanup. Edits dispatched after the reset boundary are retained.

Deletion is logical SQLite deletion, not a promise of forensic erasure from flash, journal files, or older OS backups. Freed database pages can be reused; Poma does not run automatic vacuuming or age-based pruning. Full reset uses the existing database transactionally; an unreadable database is never automatically deleted or recreated.

## Saves, failures, and recovery

The database is authoritative. Ordinary writes contain only dirty task rows, scalar state changes, and new completions. A focus completion, advanced timer/cycle progress, and desired alert state commit atomically. Task IDs, session IDs, append order, UTC completion instants, and title snapshots survive reopening.

Writes are serialized. Failed, unacknowledged changes remain in memory in action order and retain their identities on retry. Later edits cannot hide an earlier failed completion. Commit identity/revision checks recognize an acknowledged-lost transaction and reject stale saves. A confirmed full reset can supersede earlier unsaved data without replaying it. Duplicate completion IDs with different contents are rejected rather than overwritten.

After a failed write, controls and ordinary edits remain available with an unsaved warning. **Unsaved changes may be lost if the app closes.** Reopening reads the last committed state, and a previously saved running timer can recover its original completion at the saved deadline. Free storage and use Retry; never assume an error banner means the change was saved. Deletion success is reported only after required persistence/cleanup succeeds.

Startup/open, privacy preparation, migration, history reads, and writes have real error/retry states. A failed history query is not an empty history or a zero total. Existing cached history remains visible on a read failure. Errors expose safe categories, not task contents, raw JSON, SQL arguments, or raw platform exceptions. The database is not encrypted by this implementation.

## Schema and bounded reads

Explicit SQLite migrations run sequentially through v3, within sqflite's migration transaction. Fixed v1 fixtures and v2 alert fixtures exercise upgrades. A failed migration rolls back data, schema, and user_version; future versions are rejected without downgrade/reset. Existing database paths and backup exclusions are unchanged. Legacy validation/backfill is one-time work, performed in batches of 250 rows without materializing all history.

Schema v3 adds integer UTC completion microseconds, the `(ended_at_utc_micros DESC, id DESC)` index, the task position/ID index, and opaque commit/cleanup metadata. Original UTC text timestamps and snapshots are preserved. Ordinary startup loads settings, timer, alerts and tasks, without enumerating sessions. Today uses an indexed range aggregate; Insights reads at most seven daily aggregates and one 50-session page. Newer/Older use two index seeks per cursor, including equal-time IDs, without OFFSET or growing page caches.

Daily boundaries come from the current local calendar, converted individually to UTC, rather than assuming every day lasts 24 hours. Totals refresh on completion/deletion, foreground entry, midnight and timezone events. Changing timezone can legitimately regroup older completions, but never changes their UTC completion instant. No rendering callback writes history or repeatedly scans it.

## Export, backups, and verification

Export/import is deferred and is not a core offline release requirement. Poma does not currently provide a user backup file. A future export/import must use a versioned, validated format with size limits, defined duplicate rules and a conflict preview before destructive application.

Android backup/device-transfer exclusions and the iOS excluded SQLite directory/sidecars remain in place. Uninstalling Poma or losing the phone has no automatic recovery path. Exclusions cannot erase copies an older version already placed in an OS backup.

Host tests cover fixed migrations, rollback/retry, SQLite FULL via page limits, process exits immediately before commit and after commit before acknowledgement, duplicate callbacks, delayed saves, malformed data and safe diagnostics, 100,000-row history, timezone/midnight ranges, and offline close/reopen. Process probes use isolated local Flutter test hosts so Windows cannot replace the parent's loaded SQLite DLL. These checks are not physical-device or sudden-power-loss measurements.

On each standalone Android/iOS installation, enable airplane mode, create/rename/select tasks, change settings, complete a focus phase, close/kill and reopen without a development server, and verify settings, task order/selection, original title snapshots, history and the ready successor. Also verify denied permissions, locked/background alerts, clearing history during an active phase, full reset, timezone changes and an overnight recovered completion. Record device/OS/build and evidence in the release handoff. iOS compilation/native tests need macOS/Xcode; phone acceptance remains pending until performed.
