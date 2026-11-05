# Poma privacy policy

Effective date: 22 October 2026. Owner: Jyotirmay Singh.
Applies to Poma 1.0.0 for Android and iOS.

Poma is an offline timer. It needs no account, internet connection, development
server or computer after installation. Poma includes no advertising, analytics,
tracking, remote configuration, cloud sync or app-operated backend. Poma does
not collect or transmit your tasks, settings or focus history to its owner.

## Information kept on your phone

Poma stores task titles, task order/completion, timer preferences and state,
appearance, selected tasks and focus history in private local SQLite storage.
History includes the task title captured when a focus phase starts. Renaming
or deleting a task does not change that historical snapshot.

Local alert records contain opaque session/action identifiers and a local
database location. Android stores native scheduling metadata in private
preferences; iOS stores native response metadata in UserDefaults. The OS also
manages notification permission, channel settings and delivered notifications.
Generic completion alerts do not contain task titles. They can reveal that
Poma was used. Your phone controls alert previews, sound and delivery.

## Retention, deletion and backups

History stays until you delete individual sessions, clear history or delete all
local data in Settings. Full reset stops the active phase, clears tasks/history
and preferences, and cancels Poma alerts. Notification permission remains an OS
setting. Deletion is logical deletion, not guaranteed forensic erasure from
flash, SQLite sidecars or old backups. Unsaved edits after a reported storage
failure can be lost if Poma closes.

Poma requests exclusion from automatic backups: Android declares legacy/cloud
backup and device-transfer exclusions; iOS excludes the SQLite directory and
its sidecars. The iOS directory flag does not cover standard UserDefaults
metadata. System/OEM backup and phone-transfer behavior can vary. Older backups
can retain previously copied information; Poma cannot erase them. Poma offers
no export/import or automatic recovery after uninstalling it or losing a phone.

Poma does not encrypt the database itself. OS sandboxing and device-level
protection depend on the phone. Poma does not hide task content from screenshots
or the OS app-switcher. OS/store diagnostics and backups are governed by their
providers and your settings; they are separate from app-operated data collection.

## Permissions and optional support

Notification permission is optional. Android precise-alarm access is optional
and supports the precise completion-alert mode; otherwise alerts can be delayed.
Denial leaves the timer usable. Reboot, force-stop, powered-off time, Focus/DND,
low-power settings and OS policies can delay or suppress alerts. Poma does not
run a continuous background countdown or automatically start subsequent phases.

Installation and store updates can use the network independently of app use.
The support address below is optional; Poma displays it without making a network
request. If you choose to visit GitHub, GitHub's own privacy policy applies.
Public issues are visible to others: do not post private task text, credentials,
personal notifications or unredacted device logs. Poma requests no child-specific
or other profile information.

## Contact and changes

For support or privacy questions, contact Jyotirmay Singh through
https://github.com/Jyotirmay-Singh/poma/issues . Use a description without private
data. Updated policies will identify their effective date and applicable release.
This policy is also bundled in the app and available offline.

## Windows Calendar private pilot addendum — 26 October 2026

The preceding policy retains its Android/iOS 1.0.0 scope. The Windows private
pilot adds an optional direct Google Calendar connection. Timers, tasks and
history still work offline without an account. See the bundled Windows notice
at [privacy-windows.txt](../mobile/assets/legal/privacy-windows.txt) and
[local retention](LOCAL_DATA.md) for the full Windows behavior.

Poma uses the default browser and a temporary loopback-only callback for Google
authorization, requests only calendar-list/event read scopes, and contacts Google
directly for authorization, token refresh, metadata, explicitly selected calendar
events and best-effort revocation. No Poma backend, analytics, event writes,
automatic task import or phone synchronization is added. Location/description
text may be read transiently to extract a supported meeting link; raw descriptions,
attachments and attendee rosters are not retained.

Refresh credentials use current-user DPAPI. Access tokens stay in memory. Calendar
metadata, selected sources, normalized event titles/identities/times, validated
URLs, freshness/coverage and reminder preferences/receipts are kept separately
from Pomodoro records and are not encrypted by Poma. Event snapshots cover today
through six local dates ahead; trimming occurs while resident and on next launch,
with no expiry service after Quit. Reminder attempts are pruned on document saves.
Windows account/device protection and external backups are separate boundaries.

Titles may appear in the unlocked popup and tooltip; tooltip titles can be
disabled. Locked/unknown lock state redacts calendar details. Optional meeting
reminders default off and always use generic text with opaque action payloads.
Windows policy controls delivery. Missed reminders are skipped after sleep/restart;
Poma generates none after Quit. Previously submitted notifications can survive a crash.

Disconnect disables access immediately and removes calendar-derived local files
and credentials, preserving tasks/history. Full reset also clears the existing
Pomodoro data. Old asynchronous results cannot restore the cleared account.
Deletion failures are visible/retryable; a non-personal disconnected marker can
remain. Expired/revoked grants retain protected no-token account identity and
bounded stale cache until reconnect, disconnect or reset. External Testing access
may expire after seven days. Local removal/uninstall cannot establish Google
revocation or erase external backups; no operation deletes remote calendar events.

Session 9 uses synthetic and isolated checks. Actual Google consent, installed
desktop delivery, signing/trust, clean-profile operation and owner accessibility
observations retain explicit gates in [calendar acceptance](WINDOWS_CALENDAR_ACCEPTANCE.md).
This local document is not a confirmed hosted policy or public-release approval.


## Windows explicit scheduling addendum — private Session 12 builds

This addendum applies to the optional Windows feature; the Android/iOS policy
above retains its platform scope. Calendar viewing requests the two read scopes.
Focus scheduling separately requests `calendar.app.created` with those read scopes.
Google's grant covers eligible app-created calendars, including resource operations
and unrelated events there. Poma exposes dedicated-calendar creation and checked
one-off Poma block management only, with a final title/time/Busy-Free confirmation.
No task notes, task IDs, attendees or focus history are uploaded. Decline preserves
the saved reader. Task changes never synchronize automatically.
Drafts, immutable operation payloads/IDs, ownership snapshots and ETags are stored
unencrypted in a separate account journal. Credentials and a versioned capability
receipt use current-user DPAPI. Unresolved/active future records remain; terminal
payloads and expired drafts are cleaned up 30 days after the later of end time or
terminal transition. External backups can outlive deletion. No automatic offline,
restart or connectivity replay occurs. Disable stops scheduling locally without
revoking Google access. Disconnect/reset purge local calendar data and preserve
remote events. Already sent requests may complete; recovery requires explicit
review and restores no commands/tasks/history. See the bundled Windows privacy
notice and Session 12 release record for implemented behavior and acceptance limits.
