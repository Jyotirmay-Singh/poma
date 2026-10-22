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
