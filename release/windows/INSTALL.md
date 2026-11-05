# Poma for Windows — private installation

## Optional explicit focus scheduling (Session 12 builds)

Calendar viewing remains optional and uses the two read permissions. The separate
Windows Calendar page offers Enable focus scheduling, which requests those scopes
plus `calendar.app.created` from the same Desktop client. Declining preserves the
saved reader. Google grants access across eligible app-created calendars; Poma
enforces its own verified-calendar/owned-block restrictions.
Review dedicated Poma Focus creation or calendar recovery separately, then use
Schedule focus block on a task and confirm the complete final preview. Offline
forms save drafts only. Restart/connectivity never silently sends writes.
Pending/checking/failed outcomes remain on the Calendar page; inspect them before
retrying. A remote timeout can mean the block was saved. Stable IDs and outcome
checks prevent blind replacement inserts. Only explicit verified-block deletion
reverses creation. Disable scheduling retains viewing and Google authorization.
Disconnect/reset remove local write data while preserving remote events; an already
transmitted request may still complete. Recover Poma blocks requires explicit review.
The unencrypted `calendar/accounts/<account-key>/focus-blocks.json` stores titles,
times, operation and ownership records. It is separate from credentials and the
seven-date agenda cache. Keep private backups private. Before an installed upgrade,
Quit Poma and back up the closed LocalState. Preserve the existing certificate and
package identity; never replace trust or downgrade onto old profile formats silently.

This kit targets **Windows 11 25H2 x64 (build 26200 or later within 25H2)**.
Earlier Windows releases and ARM64 are not covered. The MSIX includes Flutter,
the application, SQLite, plugin/native assets and application-local Microsoft
C++ runtimes. No Flutter SDK, Visual Studio, Codex, server, sign-in, runtime
download or network connection is required for timers, tasks and history.
Optional Windows Google Calendar needs a default browser, owner-configured
Desktop OAuth client, consent and direct Google access. It remains read-only.
Its cache is unencrypted; review the bundled Windows privacy notice before connecting.

Use the version and SHA-256 in this kit's `RELEASE-NOTES.md`, its
`build-inventory.json` and `ACCEPTANCE.md`. Historical packages are separate
evidence. A loose executable or an extracted MSIX does not provide the installed
identity required by Poma's Windows notifications. Install the complete MSIX.

This is a private acceptance candidate until the accompanying acceptance record
is completed. Keep the kit local; it is not a public release.

## Verify and review the certificate

1. Keep the MSIX, public `Poma-Public.cer`, `certificate-info.txt`, checksums,
   inventory and licenses together. Compare the certificate's **SHA-256** with
   the separate release record supplied by the owner. A checksum inside an
   unknown download does not prove who created it.
2. Review the MSIX Properties → Digital Signatures. The signer is
   **CN=Jyotirmay Singh**. The certificate is private/self-signed, so Windows
   initially reports an untrusted chain. The build/sign scripts never trust it.
3. Optional read-only check in PowerShell: `powershell -NoProfile -File
   .\Verify-Kit.ps1`. If local script policy prevents this, inspect file hashes
   and certificate properties manually; do not weaken machine policy.
4. **Owner/admin step:** double-click the public CER, inspect Details and its
   fingerprint, then Install Certificate → Local Machine → place it only in
   **Trusted People**. Administrator approval may be required. Do not install
   the certificate in Trusted Root Certification Authorities. Never import a
   private PFX from an installation kit; no private key belongs in this kit.
   Follow your organization's policy if certificate trust is managed.

The package is signed offline without an Internet timestamp. Keep the same
certificate for private upgrades and renew/re-sign before its expiry. Securely
back up private signing material separately; it is absent from this kit.

## Install and launch offline

After certificate review/trust, disconnect the network and close development
tools. Double-click the MSIX and choose Install. If App Installer is unavailable,
the built-in PowerShell command `Add-AppxPackage -Path .\Poma-<version>-x64.msix`
installs the local file without downloading dependencies. Run as the intended
standard user. If policy blocks installation, stop and ask the administrator;
do not enable Developer Mode or change security policy as a workaround.

Open **Poma** from Start. Its initial window is about 1080 × 760 logical pixels.
Use Focus, Tasks, History / Insights and Settings. Ctrl+1–4 switches sections,
Ctrl+N adds a task, Tab/Shift+Tab moves focus, and Escape dismisses dialogs or the
tray popup. Each phase starts manually.

Left-click the tray icon to toggle a compact timer, or use Settings → Open compact
timer. Right-click for allowed timer
actions, Open Poma, Settings and Quit. Windows may put the icon in tray overflow;
you can move it using Windows' normal taskbar controls. Close hides Poma in the
tray by default; a first-use explanation makes this clear. Settings can turn
close-to-tray off. Start with Windows is optional and initially off. An OS-disabled
startup task must be re-enabled in Windows Settings by you.

Quit stops resident operation and new alerts. It preserves the running deadline;
reopening after expiry records one completed focus and shows a Ready successor.
No catch-up toast is replayed. Sleep counts as elapsed time, but Poma does not
wake Windows: alert delivery may wait until resume. Windows notification settings
and Do Not Disturb determine presentation/sound. Task names are absent from toasts.
Strict mode restricts Poma controls; it does not prevent Quit or Windows shutdown.

## Connect Google Calendar

Open Poma from Start, then select **Settings** in its left navigation or press
**Ctrl+4** while the main window is focused. The tray's right-click **Settings**
command also opens this page. If Poma is absent from Start, finish installation
first. Saving a setup JSON file does not install or configure an existing build.

Check `public-calendar-client.json`: a configured pilot embeds its Desktop client
settings at compilation. It does not read the owner's setup directory at runtime.
Select **Connect Google** and personally complete browser sign-in, MFA and consent.
Allow only calendar-list and event read access. Poma returns through a temporary
`127.0.0.1` listener, then requires explicit calendar selection before it fetches
event contents. Select only the intended harmless test calendar for acceptance.
Poma never creates, edits or deletes remote events. No Google Tasks or phone sync
is included. Calendar failure does not block local timers, tasks or history.

For an External / Testing project, the signed-in account must be a named Google
test user. Google limits these Calendar grants/refresh tokens to seven days;
reconnect after expiry. Unverified-app warnings and Google's test-user limits may
apply. An Internal client requires an eligible organization. This private pilot
does not establish production approval or verification.

Meeting reminders are initially off. Enable them and the intended source only
for the reminder check, choosing a lead time for an existing future event.
Poma must remain running, possibly hidden in the tray. Reminders skip old/missed
meetings, stop after Quit and cannot wake Windows. Windows notification policy,
Do Not Disturb, sleep and stale/offline calendar data can prevent delivery.

## Local data, backup and recovery

Installed data is under `%LOCALAPPDATA%\Packages\<Poma package family>\LocalState\`.
The actual package family can be read with `Get-AppxPackage
JyotirmaySingh.Poma.Desktop | Select-Object PackageFamilyName`. SQLite is at
`databases\poma.db`; auxiliary `-wal`/`-shm` files can accompany it. Windows native
action receipts contain only opaque IDs in `responses`. Google connection is
optional; no phone sync, telemetry or app-managed cloud backup is included.
Unpackaged developer runs use the separate `%LOCALAPPDATA%\Poma\Development`.

Calendar data lives in the same installed root, separate from the Pomodoro DB:

- `calendar\connection.dpapi`: refresh credentials protected by current-user
  Windows DPAPI. Access tokens stay in memory. `calendar\retired.dpapi` can retain
  a protected account identity after a grant becomes unusable, without a token.
- `calendar\accounts\<account-key>\state.json`: **unencrypted** calendar names,
  selected sources, event cache and preferences. Treat it and backups as private.
- `calendar\accounts\<account-key>\reminders.json`: reminder preferences/receipts.

DPAPI is tied to the Windows user and Poma profile path. Copying its protected
files to another profile is not supported credential recovery. Reconnect there.

Before backup, select **Quit** and verify Poma has stopped. Copy the **whole
LocalState folder**, including any database sidecars, to a secure local location.
Do not copy a live SQLite file alone or edit its tables. A restart uses bounded
UTC recovery when the process was stopped; manual clock changes during that
time can affect recovery. Live timing uses a sleep-inclusive monotonic clock.

If Poma reports a failed save, keep it open and Retry after freeing disk space.
Choosing Quit anyway can lose unsaved edits. An unreadable/future-schema database
is kept; stop Poma and back up the profile before seeking help. Do not delete the
database to make an error disappear. Shutdown/crash callbacks cannot guarantee a
final save, so running state is committed during ordinary actions.

## Remove Google access and cached calendar data

In Poma Settings choose **Disconnect Google**. This stops calendar work/reminders
and removes the protected connection, retired identity and account cache subtree;
it preserves local tasks, timer and history. A nonpersonal `calendar\disconnected`
marker can remain. If cleanup fails, use the visible Retry action and verify it
succeeds before reconnecting. Neither disconnect nor local deletion changes
Google Calendar events.

If offline, local deletion still applies, but remote token revocation may not
reach Google. In your Google Account's third-party connections, remove Poma's
grant as well. Revoke before uninstall if you want remote access removed;
uninstall cannot contact Google after the application is gone.

If Poma cannot open, Quit/stop it first, identify its actual package family, and
remove only that package's `LocalState\calendar` folder to remove protected
credentials and calendar-derived cache. Keep `databases` to retain Pomodoro data.
Remove calendar copies in any backups/development profiles separately. Deleting
local files does not revoke Google's grant and is not a forensic-erasure promise.
The owner-local setup JSON files and signing directory are outside the installed
profile; uninstall does not remove them. Keep or delete them separately as needed,
and keep private signing keys secure if future private upgrades are wanted.

## Upgrade, uninstall and certificate removal

Quit Poma, make a closed-profile backup, then install a higher-version MSIX with
the **same identity, publisher and certificate**. Updates should keep local data;
verify tasks/settings/history with the acceptance checklist. Uninstalling first
removes package-local data. An arbitrary older database/app downgrade is not
supported; restore a closed-profile backup only to a compatible version.

Uninstall through Windows Settings → Apps → Installed apps → Poma. This removes
its package/local data, startup declaration and activation registration. If you
no longer use any Poma package signed by the private certificate, the owner/admin
can remove that **exact certificate** from Local Computer → Trusted People in
the certificate manager, comparing the thumbprint/fingerprint first. Remove no
other certificates. Keep backups only if you intend to retain the data.

Use `build-inventory.json`, `signature-status.json`, `certificate-info.txt` and
`SHA256SUMS.txt` to identify the candidate. Record actual installation, hidden
expiry, sleep/hibernate, restart, notifications, accessibility and upgrade results
in the bundled `ACCEPTANCE.md` and the source workspace's Windows Calendar ledger.
