# Poma private Windows Calendar pilots

## Current private candidate — 1.0.0.2022

The current implementation adds a separate Windows Calendar page and optional,
explicit scheduling on a verified Poma-created secondary calendar. It includes
checked one-off block edits/deletion and reviewed local recovery; no general
editor, attendees, recurring writes or automatic history uploads are included.
The new private build, exact artifacts, hashes and observed/pending checks are
recorded in [Session 12](WINDOWS_CALENDAR_SESSION12.md). The 2020 release evidence
below is preserved for that build and is not a write-enabled acceptance result.

[Complete 2022 private kit](../artifacts/windows/Poma-1.0.0.2022-session12-pilot-private-pilot-kit.zip)
has SHA-256 `00da592fec82561f99dd309f2adfee4abdb84bb442725d8811ab6fc5ae1820ec`. The signed installer has SHA-256
`f4ee904a095a120fe0c26b2e6dd737149c958e2f39fc43a57e86e68dcfb8de90`. Exact source/build checks and open live gates are in the
Session 12 ledger. The kit is private and no certificate trust change occurred.

## Historical read-only pilot — 1.0.0.2020

29 October 2026, Asia/Calcutta. **Build 2020 supersedes 2019. Packaging and
automated checks are complete; installed/live acceptance of 2020 is pending.**
The owner currently has the 2018 rehearsal installed. Its observations retain
their own version and do not certify this repaired build. This is a private,
read-only pilot.

## Exact identity and complete artifacts

| Item | Identity |
| --- | --- |
| Complete folder | `D:\pomodoro\artifacts\windows\Poma-1.0.0.2020-session10-pilot` |
| Installer | `Poma-1.0.0.2020-x64.msix` |
| Installer bytes | 15,845,403 |
| Installer SHA-256 | `92b6bb6084e4c058eee950122aff7a0064d3b9e5777c22996ccd7fd8ad06c35d` |
| Source inputs SHA-256 | `e58035d26beda075d36af1ff85c93b81f7da6684bad05aa305b6069319d69a47` |
| Checkout | `codex/poma-offline-release`, base `cb8b1a1e3f5a376b0121ead5328bb51fbcdc5679`, plus inventoried uncommitted inputs |
| Lockfile SHA-256 | `e2e9b87d0bbec8e9c37beb04b98604537afa7c3c8b5ca0242adf441581891f8d` |
| Toolchain | Flutter 3.44.2 / Dart 3.12.2; existing MSVC v142 / Windows SDK 19041 baseline |
| Mobile version | Unchanged `1.0.0+2007` |
| Package / app | `JyotirmaySingh.Poma.Desktop` / `Poma` |
| Publisher | `CN=Jyotirmay Singh` |
| Application user model ID | `JyotirmaySingh.Poma.Desktop_kz516h6tttq8c!Poma` |
| Toast activator | `970A3EE4-5721-4FC9-8AB1-FA8994C723D7` |
| Tray GUID | `6D191080-C183-49BB-83EE-19426A36D40D` |
| Startup task | `PomaStartup`, declared off by default |

The complete sibling `Poma-1.0.0.2020-session10-pilot-private-pilot-kit.zip` is
the current handoff archive. Its exact digest is in the adjacent `.zip.sha256`;
`SHA256SUMS.txt` identifies every loose kit file. The archive cannot include its
own digest. Historical 2019 folders/ZIPs are preserved and superseded.

Supported pilot scope is **Windows 11 25H2, build 26200, x64**. The observed
owner host is Home Single Language **26200.9711**, 64-bit. No earlier Windows,
ARM64/emulation or broader hardware support is established. The manifest minimum
is `10.0.26200.0`. Clean Windows user/VM/machine checks are unavailable: the
current owner account was chosen; no usable local Sandbox/Hyper-V/VirtualBox
environment was found.

MSIX is required by the implemented notification adapter; unpackaged launches
report notification capability unavailable. Install this complete MSIX. It
contains Flutter engine/AOT/ICU/assets, package-local SQLite/native assets,
notification dependency, matching application-local Microsoft C++ DLLs, icons,
privacy notice and complete generated package/native/runtime licenses. The kit
adds installation/cleanup instructions, public CER/fingerprint and client
summary, release notes, checklist, inventories, public audit summaries and
read-only verification. No development tool, .NET/Windows App SDK/WebView setup,
server or runtime download is required for core use. Clean-machine proof remains
unavailable. Google authorization/refresh needs a browser and network access.

`public-calendar-client.json` identifies the compiled Desktop public client,
Testing audience and exactly two read-only scopes. The optional Desktop client
credential is inherently public in an installed app. Original owner setup JSON,
user tokens, private signing material, personal cache/databases, PDBs and review
controls are excluded. The owner setup directory is not used at runtime.

## Connection repair and current Google result

On 2018 the owner reported “Google connection offline” after browser consent.
Actual profile checks found **no saved protected connection or account cache**.
The message claiming saved refresh credentials were retained was therefore
misleading. Build 2020 reports no new connection saved when no credential exists;
the retained-credential message is used only when a credential really exists.

A second isolated regression reproduced HTTP 403/404 refusals of the primary
Calendar API check being mislabeled offline. They now produce a safe Calendar
API access message directing the owner to check project API enablement and
account access. Other invalid responses are not treated as network outages.
No provider body, token, callback URL or event text is exposed.

The actual owner's HTTP error code/cause has **not** been captured. TCP 443 to
Google's sign-in/token/API hosts and unauthenticated HTTPS with Dart 3.12.2
succeeded; the unauthenticated Calendar endpoint correctly returned 401. This
does not verify the OAuth project's API settings or the installed app's completed
exchange. Confirm Google Calendar API is enabled in the same project as this
Desktop client, then retry and require **Connected to Google Calendar**. Browser
consent alone does not prove Poma completed its identity/credential commit.

## Observed checks, by build

| Check | Actual result and limit |
| --- | --- |
| Current Flutter checks | **304 passed**, including two new regressions; the connection subset passed **28**. Both new regressions failed before the repair. Static analysis is clean; changed Dart formatting and whitespace checks pass. |
| Current configured build | Fresh normal-entry-point Windows release 2020 compiled with one worker and the owner's existing curated settings; no SkipBuild configuration reuse. |
| Current signed payload | 61 signed MSIX members / 37,906,954 uncompressed bytes; all 56 inventoried hashes verified. Thirteen x64 PE files plus AOT, required SQLite/CRT/assets/icons/licenses, public read-only settings and preserved identities verified. |
| Preservation | Only the two Windows Calendar implementation files and their regression test changed since 2019. Native mobile/metadata, locked dependencies and historical 2019 package/ZIP are unchanged. Final inventoried inputs match current files. |
| Current privacy scan | All MSIX members and loose candidate files checked for selected private/token/key/setup/review patterns, with no findings. Exact bounded counts are in PACKAGE-AUDIT.json. Public Desktop settings are expected; this is not every-secret/forensic proof. |
| Installed 2018 | Owner installation succeeded after certificate import. Normal registered-app launch, Focus and Settings rendered. All 56 installed payload hashes match. Flutter, SQLite, notification dependency and required CRT modules resolve from WindowsApps. |
| Installed paths, 2018 | Executable: `C:Program FilesWindowsAppsJyotirmaySingh.Poma.Desktop_1.0.0.2018_x64__kz516h6tttq8cpoma.exe`. Actual data root: `C:UsersJYOTIRMAYAppDataLocalPackagesJyotirmaySingh.Poma.Desktop_kz516h6tttq8cLocalState`. The real Pomodoro DB exists there. |
| Installed notification capability, 2018 | Windows returns Enabled for the preserved application identity. Capability does not prove a visible banner, sound or action delivery. |
| Browser/loopback attempt, 2018 | Poma initiated browser authorization and exposed one IPv4-loopback-only listener; a later check found it closed. Owner reported offline after consent; no usable saved connection/selection was observed. |
| Installed 2020, upgrade, credentials/selection | **Pending**. No installed 2020 launch, preserved grant or calendar-loading result is claimed. |
| Tray/focus persistence/hidden reminders/Quit/offline | **Pending installed walkthrough**, including relevant repeats on final 2020. No simulation is substituted. |
| Broader checks | Explorer recovery, additional monitors/scales, Narrator/high contrast, startup at sign-in, DND/denial, physical lock/sleep/hibernate, live revocation/seven-day expiry and wider account/date comparisons remain open. |

Historical Session 9's 302 Flutter / 211 native checks and Android build/eight
native tests retain their own identities. No new physical mobile/iOS campaign
or native acceptance is inferred. Current fixes are confined to the Windows
Calendar authorization/controller and its tests.

Evidence remains in `D:pomodoroartifactswindowscalendar-session10`, including
before/after regression output, full Flutter result, analysis, source preservation,
2020 build/sign/audit records, the unauthenticated transport probe and separately
labeled 2018 installed observations. Desktop control ended in this turn because
it could not verify Chrome's current URL; the project console check was not
completed. No browser safety check was bypassed.

## Install, upgrade and signing

The same existing private certificate signs this package. On the current owner
account Windows reports **Valid** after the owner's earlier import. No further
trust change is needed there. Certificate SHA-256:
`1CDE2CB78DFABF389C59475EB3684E4837D81AEFADB3723992B02402D328E955`.
Thumbprint: `A4632E6041FA461D3908F4072396A842770DE2DC`; expires
`2031-10-23T19:20:31Z`. Signing is self-signed/offline, without a paid service or
network timestamp. Other private testers must review/trust the exact public CER
in Local Machine / Trusted People per INSTALL.md; do not use Trusted Root.

For the planned upgrade, **Quit Poma** (Close normally hides it), back up the
whole closed LocalState privately, then install 2020 over 2018 using the same
identity/publisher/certificate. Do not uninstall first. Launch Poma from Start;
click Settings or focus the main content and use Ctrl+4. Saving JSON does not
configure an old binary. Retry Connect/Reconnect after checking Calendar API
enablement. The owner handles browser login/MFA/consent. Select calendars
explicitly and save before event contents load. Use ACCEPTANCE.md to record
actual final-build results; do not install superseded 2019 artifacts.

## Testing OAuth and reminder limits

Audience is **External / Testing**. The account must be a named test user;
Google's testing/unverified warnings and user limits apply. These Calendar
grants/refresh tokens expire after **seven days** in Testing; reconnect after
expiry/revocation. Actual elapsed expiry has not been observed. Requested scopes
are calendar-list read and event read only. No event writing, Google Tasks,
automatic import or phone sync is included.

Calendar cache covers seven local dates, with age/coverage and stale warnings
after five minutes. Cache is unencrypted. Google failure does not block core
timers, tasks, settings or history. Meeting reminders initially remain off and
require explicit source/lead choices. Both timer and meeting alerts need installed
identity and Poma running, including hidden in the tray. Windows policy/DND and
sleep can suppress or delay delivery; Poma cannot wake Windows and sends no new
reminders after Quit. Old/missed meetings are skipped. Exactly-once presentation
under arbitrary crashes is not promised. Every next timer phase starts manually.
Cold recovery uses bounded UTC and can be affected by stopped-process wall-clock
changes. Physical reminder/sleep/policy behavior remains unverified here.

## Credentials, cache, disconnect and uninstall

The actual package family above retains this LocalState layout across supported
upgrades (final-upgrade retention still needs observation):

```text
databasespoma.db                         Pomodoro data, with possible -wal/-shm
calendarconnection.dpapi                 current-user DPAPI refresh credentials
calendar
etired.dpapi                    protected retired identity, no usable token
calendaraccounts<account-key>state.json       unencrypted cache/selection/preferences
calendaraccounts<account-key>
eminders.json   reminder preferences/receipts
```

Disconnect Google cancels calendar work/reminders and removes protected
connection/retired identity and account-derived cache, while preserving Pomodoro
tasks/history. A nonpersonal `calendardisconnected` marker can remain. Retry
visible cleanup failures. If Poma cannot open, stop it and remove only the actual
LocalState `calendar` folder; retain `databases` for Pomodoro records. DPAPI is
tied to the Windows user and Poma profile path; copying blobs is not supported
recovery. Reconnect in another profile. Development runs use the separate
`%LOCALAPPDATA%PomaDevelopment` root.

An offline local deletion cannot prove Google received revocation. Google may
also remember consent after a failed local connection. Remove Poma's grant in
Google Account / third-party connections to revoke remote authorization. No
operation changes remote events. Uninstall through Windows Installed apps removes
package-local data/activation/startup registration; it does not remove Google's
grant, external backups, owner setup files or signing material. Review those
separately. Keep signing keys private for future upgrades. The owner can remove
the exact public certificate from Trusted People once no Poma package needs it.
Local deletion is not a forensic-erasure promise; retain backups only deliberately.

## Private-pilot boundary

This remains a private read-only pilot with the pending checks above. Public
release requires a separate decision on Google production/verification and
applicable scope/brand requirements, public privacy/support/contact material,
signing/distribution and wider Windows/CPU/hardware tests. No store upload,
public distribution, signing-service purchase or real calendar event change was
performed. Optional focus-block writing and new write scopes remain a separate
design/authorization decision.
