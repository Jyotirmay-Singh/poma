# Local data and ownership

## Explicit focus scheduling storage — Session 12

The DPAPI credential record gains a versioned scheduling receipt bound to the
client/account, verified exact scopes and credential generation. Its atomic native
envelope carries a separate commit revision, preserved across restart. Legacy
records remain readable with writes disabled; no Pomodoro schema migration occurs.
`calendar/accounts/<account-key>/focus-blocks.json` holds local drafts, canonical
calendar/provisioning identity, immutable operation payloads/IDs, ETags, ownership
snapshots and safe statuses. It is unencrypted, limited to 16 MiB and atomically
replaced under independent revision/generation leases. Corruption blocks scheduling
without recreating an inferred command. Task associations stay local.
Unresolved operations and active/future blocks remain. Terminal payloads/expired
drafts are cleaned up after 30 days from the later of end time or terminal transition;
cleanup runs with journal persistence, never a service after Quit. Non-content
`focus-stopped`/`focus-disabled` markers prevent replay and preserve disablement.
Disconnect/account replacement/reset purge account write data while preserving
remote calendars/events. Disabled scheduling preserves reader data. Explicit
recovery adopts reviewed current blocks without tasks, history or executable commands.

## Windows profile

Session 8 adds `calendar/accounts/<account-key>/reminders.json`, with versioned
reminder preferences, included calendar IDs, hashed occurrence/start attempt
receipts and opaque resident action receipts. It is separate from `state.json`
and `poma.db`, and is unencrypted. Native atomic replacement uses the reader's
current account/revision/scope lease and credential-store mutex. No second cache
binding or Pomodoro database writer is introduced. Attempt receipts are pruned
against the current seven-date window when a reminder document is saved (maximum
4096); old on-disk receipts can remain until that next save. In-memory action
receipts clear on generation changes, and saved documents enforce an 8192-entry
limit. Overflow or write failure stops
reminders with recovery UI rather than risking repeated notifications.
Disconnect/account replacement/full reset purge this account subtree and reject
late writes. Calendar deselection removes reminder inclusion. Disabled reminders
retain occurrence receipts so re-enabling or changing lead time cannot repeat an
attempted occurrence. Cold launch arms future deadlines only, with no catch-up.

Windows uses the existing schema v3, serialized incremental writer, FULL
synchronous SQLite commits and unique completion/action receipts. Production
`sqflite_common_ffi` 2.4.4 loads the bundled `sqlite3` 3.5.2 native build asset.
It does not use a test-host DLL or download SQLite at application runtime.
Mobile sqflite selection is unchanged.

The installed database is `ApplicationData.Current.LocalFolder/databases/poma.db`,
normally `%LOCALAPPDATA%\Packages\<Poma package family>\LocalState\databases\poma.db`.
Unpackaged runs deliberately use `%LOCALAPPDATA%\Poma\Development\databases\poma.db`.
Package updates with the same identity retain the installed profile. Uninstall
removes package-local data. Pomodoro data remains local with no phone sync or
app-managed cloud backup. Optional Google authorization is separate from these
records. The directory is not a roaming folder.

An optional `windowsDesktop` record in `app_state` holds close behavior and
normal window bounds. It has defaults and changes no timer setting or schema.
Startup status is read from Windows' actual StartupTask state rather than a
potentially stale saved checkbox. Full reset clears desktop preferences and
disables that task through the existing retryable native-cleanup barrier.

The native owner lock prevents a second database owner. `responses/*.event`
contains only opaque notification identity/action, never task titles; Dart
ingests it through unique receipts and acknowledges files after persistence.
Quit flushes saved work, stops the display/deadline work, closes SQLite and removes
the tray icon. Failed saves keep the application open unless the user explicitly
chooses to lose unsaved edits. Windows shutdown flushing is best effort.

For backup, **Quit first**, verify the process has stopped and copy the complete
LocalState folder including any SQLite sidecars. Do not edit or replace a live
database. Preserve unreadable/future-schema databases for diagnosis. The current
Pomodoro database has no export/import or encryption feature; arbitrary downgrades are not
supported. See [Windows installation and recovery](../release/windows/INSTALL.md).

The remaining sections retain their original mobile evidence scope.

### Windows Calendar credentials and snapshots — Sessions 5–6

Under that same profile root, `calendar/connection.dpapi` holds a versioned
current-user DPAPI-protected refresh credential, client identity, primary-calendar
identity and verified scopes. Access tokens are not persisted. The protection
context includes the profile path; copying the blob between development and
packaged profiles is not supported recovery. DPAPI does not encrypt `poma.db`,
and protection is not a forensic-deletion or backup guarantee.

`calendar/disconnected` is a durable cleanup marker. Disconnect writes it before
removing credentials, encrypted temporary files and the calendar-only `accounts`
subtree. Startup honors the marker and retries interrupted cleanup rather than
restoring the saved grant. Storage failures are reported; a failure to persist
the marker/delete files is not reported as successful removal.
The marker itself remains after successful cleanup and contains no account or
event content. A later successful connection replaces the disconnected state.

Session 6 adds a versioned **unencrypted** `calendar/accounts/<account-key>/state.json`,
with account keys derived from the OAuth client and verified primary-calendar ID.
It holds calendar IDs/names/access roles/colors/time zones, confirmed selection,
per-calendar coverage and success timestamps, and minimal normalized events.
Event fields include source/instance identity, plain titles, timed UTC instants or
date-only exclusive intervals, supplied zone/recurrence identity, self response and
validated conference/event URLs. Session 7 checks structured video links, then
hangoutLink, location and description for supported literal HTTPS meeting links.
Raw location/description text is discarded after extraction. Descriptions, attachments, attendee
rosters and raw API responses are not stored. Tokens never enter this document.

Only events intersecting today through six local dates ahead are retained.
Startup, midnight, resume and device time-zone changes trim data even offline;
new/uncovered portions remain unavailable until a complete successful snapshot.
No expiry worker runs after Quit. Successful snapshots replace previous ranges
atomically after all pages succeed. A failed page/write preserves prior success
and age. A saved deselection atomically removes its snapshot; failed selection
saves are unconfirmed and visible. Calendar storage failure does not touch SQLite.
The account document has a 16 MiB size ceiling and has no growing snapshot journal.

Expired/revoked grants leave only current-user DPAPI-protected no-token account
identity in `calendar/retired.dpapi`, plus the stale bounded cache. This durable
retirement record prevents restart from restoring an unusable old grant. Reconnect
retains selection only after the same client/account is verified and available
calendar identities/access are revalidated. Explicit Disconnect, account
replacement and full reset clear the account subtree and retired/active credentials;
no disconnected-account data is presented. Cache leases share native credential
cleanup's revision/locking gate, so obsolete workers cannot recreate cleared data.
Atomic-write failures retain committed data; temporary files are overwritten on
successful startup trimming. Deletion and expiry do not promise forensic erasure.

Disconnect preserves tasks, settings and focus history. Full local reset also
invalidates calendar work and retries its local cleanup using the existing reset
barrier. Provider revocation is bounded and best effort: offline local removal
cannot prove that Google access has been revoked. Google Account third-party
connections provides manual removal. Credentials remain until disconnect/reset,
revocation handling, incompatible client replacement or package uninstall;
uninstall itself cannot contact Google to revoke a grant. Development data is
outside the MSIX profile and is not removed by uninstalling that package.

Session 9 combines delayed event responses, formatting and reminder receipts
across disconnect, reset and account replacement, and separately holds snapshot
writes across each boundary. Native DPAPI/atomic-file checks verify the underlying
revision/lease gate. See [acceptance](WINDOWS_CALENDAR_ACCEPTANCE.md) for actual
results and identities; these checks do not establish forensic deletion, removal
from external backups, live Google revocation or installed-owner acceptance.

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

Windows Calendar Session 3 adds only the optional `windowsDesktop.tooltipTitles` presentation preference to the existing namespaced desktop metadata. Old records default to titles enabled, matching the owner's popup/tooltip choice; lock or unknown session state still redacts calendar details. The existing `AppController` persistence owner saves this preference without a schema change. Fictional scenario choice, sample events, date browsing and preview messages remain in memory and disappear on process exit. This session creates no calendar cache, credential store or second Pomodoro database writer.

Export/import is deferred and is not a core offline release requirement. Poma does not currently provide a user backup file. A future export/import must use a versioned, validated format with size limits, defined duplicate rules and a conflict preview before destructive application.

Android backup/device-transfer exclusions and the iOS excluded SQLite directory/sidecars remain in place. Uninstalling Poma or losing the phone has no automatic recovery path. Exclusions cannot erase copies an older version already placed in an OS backup.

Host tests cover fixed migrations, rollback/retry, SQLite FULL via page limits, process exits immediately before commit and after commit before acknowledgement, duplicate callbacks, delayed saves, malformed data and safe diagnostics, 100,000-row history, timezone/midnight ranges, and offline close/reopen. Process probes use isolated local Flutter test hosts so Windows cannot replace the parent's loaded SQLite DLL. These checks are not physical-device or sudden-power-loss measurements.

On each standalone Android/iOS installation, enable airplane mode, create/rename/select tasks, change settings, complete a focus phase, close/kill and reopen without a development server, and verify settings, task order/selection, original title snapshots, history and the ready successor. Also verify denied permissions, locked/background alerts, clearing history during an active phase, full reset, timezone changes and an overnight recovered completion. Record device/OS/build and evidence in the release handoff. iOS compilation/native tests need macOS/Xcode; phone acceptance remains pending until performed.
