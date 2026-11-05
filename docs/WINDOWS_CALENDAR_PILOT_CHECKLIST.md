# Poma private Windows Calendar pilot — owner's final checklist

## Session 12 candidate checks

Use the separate higher-version focus-scheduling kit and record its exact hash.
Historical checked items below belong to their stated read-only build.
Live acceptance is tracked in [Session 12](WINDOWS_CALENDAR_SESSION12.md): establish
a verified read connection first, exercise declined scheduling consent, inspect the
exact three-scope grant, verify disposable resource boundaries, then create/edit/
reschedule/Busy-Free/delete one disposable block. Confirm retry/restart uniqueness,
remote preservation on disconnect/reset and explicit reviewed recovery. Verify
installed offline timer/tasks/history, agenda/reminders, lock and normal Quit.
No existing personal invitation or ordinary Google event is a test mutation target.

Use only the complete Session 10 kit identified in
[pilot release notes](WINDOWS_CALENDAR_PILOT_RELEASE.md). The final pilot is
**1.0.0.2020**; **1.0.0.2018** is the upgrade rehearsal. Build 2020 supersedes
2019 with corrected connection-error messages. Keep the same Google
Desktop client, package identity and signing certificate for both installations.
Do not uninstall between them. No remote calendar event changes are required.

Before testing, record the package SHA-256, Windows version/build, CPU, current
user versus clean user, available display scales, and the result of each row.
Use a harmless calendar with existing events. Keep tokens, callback URLs,
private event names, meeting links and screenshots of personal events out of
the record. Owner sign-in/MFA/consent is performed personally in the browser.

## Installed private-pilot checks

The observations in the release notes are authoritative. An unchecked item is
pending; this checklist is a procedure, not a claim that it has passed.

- [x] **P01 / O01 — Review and install (2018, current owner account observed).** Verify kit checksums and compare the
  certificate SHA-256 with the separate release record. Trust only the reviewed
  public certificate in Local Machine / Trusted People. Install 2018 as the
  intended Windows user. Do not weaken Windows policy if installation is blocked.
  The owner completed this step; 2018 is registered and its signature now reports
  Valid. This does not establish clean-machine or final-2020 acceptance.
- [ ] **P02 / O01, O14 — Standalone launch and paths.** Launch Poma from Start,
  without a Flutter/debug launch. Open Focus, Tasks, History and Settings (Ctrl+4).
  Record the actual installed executable path, package family, LocalState path
  and module-path report. Flutter, SQLite and C++ modules must come from the
  installed package or Windows, with no build-directory dependency. Startup
  begins off. Check that the app does not need the owner setup JSON at runtime.
- [ ] **P03 / O11 — Browser authorization.** In Settings, Connect Google. The
  owner completes browser login and grants only calendar-list and event read
  access. Observe the successful loopback return to Poma, connection status and
  closed temporary listener. Do not record the callback URL or authorization code.
  Denial should leave the core app usable; reconnect explicitly afterward.
- [ ] **P04 / O12 — Select and compare.** Initially no event contents are shown.
  Select only the intended harmless calendar. Confirm loading then the correct
  times/source/counts for existing events, including any available all-day or
  recurring examples. Record match/mismatch and counts without event text.
  Confirm no Google event was created, edited or deleted by Poma.
- [ ] **P05 / O02, O06 — Tray and one owner.** Left-click the tray/overflow icon;
  inspect the popup, Escape and outside dismissal. Right-click Settings and Open
  Poma. Launch Poma repeatedly visible/hidden: one resident owner and one tray
  icon must remain. Close should show its first-use explanation and then hide.
- [ ] **P06 / O08 — Hidden timer.** Choose a one-minute focus with alerts enabled,
  start it, and hide all Poma windows. While Windows is awake, observe the generic
  timer toast and its Open/Dismiss behavior. Reopen: exactly one completion and a
  Ready manual successor. Record sound separately; do not infer presentation
  from a timer callback or a successful notification submission.
- [ ] **P07 / O09 — Hidden meeting reminder.** Use an existing future timed event,
  enable reminders and the selected source, choose a feasible lead, and hide
  Poma. Observe the generic meeting toast and Open agenda/Dismiss. A stale action
  must not start a timer or act on a removed occurrence. Restore the owner's
  reminder preference afterward. No suitable existing event means this stays
  pending; do not create or move a remote event for the check.
- [ ] **P08 / O06, O14 — Quit and persisted state.** Create a fictional local task
  and save a paused focus. Quit normally; tray/process and new reminders stop.
  Relaunch from Start: task, exact paused remainder, history, Google connection
  and selected calendar are retained without a new consent flow.
- [ ] **P09 / O13 — Disconnect rehearsal.** Disconnect Google on 2018. Confirm
  the credential/retired files and accounts subtree are removed, leaving at most
  `calendar\disconnected`; Pomodoro tasks/history survive and remote events are
  unchanged. Reconnect personally and reselect the test source before upgrade.
  Distinguish local removal from Google's best-effort remote revocation.
- [ ] **P10 / O14 — Upgrade.** Quit and back up the whole closed LocalState.
  Install final 2020 over 2018 with the same identity/publisher/certificate.
  Confirm actual installed version/path, same package family, retained task,
  paused timer/history, protected Google connection and selected calendar.
  A successful installation alone does not establish retained credentials.
- [ ] **P11 / O01, O14 — Offline restart.** The owner disconnects networking or
  uses an equivalent isolated environment. Quit/relaunch the installed final
  pilot. Focus/tasks/history/settings must work; saved calendar data must be
  labeled cached/stale/unavailable as appropriate, without a login blocker.
  Restore networking and check an explicit refresh. Record whether this was a
  real network disconnect, a fresh user profile or a simulated transport check.
- [ ] **P12 — Final identity.** Confirm all observed results refer to the final
  MSIX SHA-256. Repeat affected launch/tray/notification checks after upgrade.
  Keep any rehearsal-only observation labeled 2018.

Current Google outcome: the owner reported an offline message after browser
consent on 2018; no protected credential file or calendar account cache was saved.
The claim that saved credentials were retained was misleading. Build 2020 fixes
that message and distinguishes Calendar API access refusal from a network outage.
Check that Google Calendar API is enabled for the Desktop client's project, then
retry and require the actual Connected status before closing P03/P04/P08. Basic
TCP and unauthenticated Dart HTTPS checks passed; these do not prove project/API
permissions or a successful installed OAuth exchange.

## Separate environment and broader acceptance

- [ ] Clean standard-user or clean VM launch/install, with no development tools
  or preinstalled app runtimes. Current-account first installation establishes
  a fresh Poma profile only if observed; it is not a clean Windows machine.
- [ ] O03 Explorer restart/tray recovery; O04 additional monitors/scales/200% text;
  O05 keyboard, Narrator and high contrast.
- [ ] O07 actual disabled/enabled startup at Windows sign-in; O08 notification
  denial/Do Not Disturb; O10 physical lock/sleep/hibernate and overdue recovery.
- [ ] O11 live grant revocation, partial grants and actual seven-day Testing
  expiry; O12 wider timezone/DST/recurrence/account comparisons; O13 disposable
  profile reset/account replacement. Fixture passes remain separate evidence.

Mark unavailable hardware/environments explicitly. Do not convert a pending row
to pass because an automated test or static package check passed.

## Cleanup and decision boundary

Disconnect in Poma to remove protected credentials and the unencrypted account
cache while retaining Pomodoro data. If Poma cannot open, stop it and remove only
its actual `LocalState\calendar` folder. Remove the Poma grant in Google Account
third-party connections to remove remote authorization, including after an
offline disconnect. Uninstall removes package-local data; separately review
backups, the developer profile and owner setup files. See bundled `INSTALL.md`.

This checklist stops at a private read-only pilot. Public release requires a
separate decision on Google production/verification, public privacy/support
material, signing and broader Windows/hardware testing. Optional focus-block
writing and additional OAuth scopes are a separate design/authorization decision.
