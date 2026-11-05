# Poma Windows Calendar progress

Updated: 3 November 2026 (Asia/Calcutta). **Session 12 implements optional explicit focus scheduling and a separate Windows Calendar page. Automated verification: 414 Flutter tests, 233 native checks, 1 production Windows integration and clean analysis. Signed private build 2022 and owner-assisted live acceptance are tracked in section 18 and the Session 12 ledger. Historical pilot 2020 and its acceptance limits are preserved.**

Authoritative design: [Windows Calendar specification](WINDOWS_CALENDAR_SPEC.md). Sequence: [original Windows Calendar session prompts](GOOGLE_CALENDAR_WINDOWS_SESSION_PROMPTS.md). Existing desktop history: [progress](WINDOWS_DESKTOP_PROGRESS.md), [release](WINDOWS_DESKTOP_RELEASE.md), and [acceptance](WINDOWS_DESKTOP_ACCEPTANCE.md).

Current owner plan: [Google Calendar setup](GOOGLE_CALENDAR_SETUP.md). Latest design/handoff: Session 11 in section 17 and the [optional focus-block write specification](WINDOWS_CALENDAR_WRITES_SPEC.md). Read-only pilot continuation and unresolved gates remain in section 16 and [calendar acceptance](WINDOWS_CALENDAR_ACCEPTANCE.md). Earlier session handoffs below are historical.

## 1. Baseline and provenance — verified

| Item | Identity / finding |
| --- | --- |
| Checkout | `D:\pomodoro`; `codex/poma-offline-release`; HEAD `cb8b1a1e3f5a376b0121ead5328bb51fbcdc5679`. |
| Original planning baseline | Committed Android/iOS targets; no Windows runner in HEAD. |
| Current working tree | Extensive uncommitted Windows implementation and release records already exist. Preserve tracked modifications and untracked files. No separate application is assumed to be owned by this checkout. |
| Versions | Mobile `1.0.0+2007`; private Windows candidate `1.0.0.2009`; Flutter 3.44.2 / Dart 3.12.2. |
| Windows scope | Windows 11 25H2, build 26200, x64. Recorded host 26200.9711. Earlier Windows, x86, ARM64, and emulated configurations are outside the initial support claim. |
| Package identity | `JyotirmaySingh.Poma.Desktop`; publisher `CN=Jyotirmay Singh`; application `Poma`; existing identity/certificate preserved. |
| Source inventory | All 220 candidate source inputs match their recorded hashes. The document-writing continuation rechecked this before editing. |
| Installed provenance | Session 1 current-user inventory found zero Poma packages and zero running Poma processes. Known signed/extracted artifacts trace to this checkout's source inventory. This is not a claim about other users or undiscovered portable installations. |

Known artifact directory: `artifacts/windows/Poma-1.0.0.2009-rc1`.

| Artifact | SHA-256 |
| --- | --- |
| `Poma-1.0.0.2009-x64.msix` | `2f6d11c245111446c14d663f3fb2950753c87ffc637c932c5a458df252424803` |
| `artifacts/windows/Poma-1.0.0.2009-rc1-offline-kit.zip` | `bea9a16c5144ce55f19404fc886d3b927e48349d83cfa04cebe3042d02aa5399` |
| `mobile/pubspec.lock` | `cc6af285af5a44c115f82dfe6a2771f5bfdc9f21eba8b825e829e2a828c08a85` |
| Build source input digest | `bc38e8afb86a239f0e30122062d5c9885bce46c4da299239bf5a45e3eb1ca79d` |

Existing extracted-package observations support hidden expiry, one owner, Settings-based popup entry, pause/Quit restoration, and running recovery for the recorded candidate. They do not close trusted-install, clean-profile offline, sleep/hibernate, real tray/overflow/monitor, startup, notification-policy/action, or accessibility gates. Consult the desktop ledger rather than turning those pending cases into passes.

## 2. Agreed decisions — delivery status in the session handoffs

| Decision | Agreed contract |
| --- | --- |
| Runtime | Extend the existing Flutter/Win32 desktop foundation; one engine, timer controller, and Pomodoro database writer. |
| Composition | Independent `CalendarController` and Google/cache/credential/link/time ports; pure normalization/selection; existing `secondarySections` requires a native agenda renderer. |
| Desktop behavior | One 380-logical-pixel starting-width popup; left-click/keyboard toggles; right-click native menu; Escape/outside dismisses; close-to-tray preference and true Quit retained. |
| Platform | Existing Windows 11 25H2 x64 support boundary and private MSIX distribution. |
| Privacy — owner answered | **Event titles in popup and unlocked tray tooltip.** Offer a tooltip-title switch. Hide/redact calendar details on lock; unknown lock state fails closed. |
| Accounts | One Google account, multiple explicitly selected calendars; none initially selected; no event fetching before selection. |
| Permissions | Only calendar-list read-only and event read-only scopes. No event mutations, task imports, or phone sync. |
| Credentials/cache | Current-user native DPAPI credentials; separate unencrypted account-scoped calendar cache under the existing profile root; seven local dates. |
| Dependencies | Retain SDK/database/native tray. Session 5 adopts `oauth2` 2.0.5 and promotes locked HTTP/crypto to direct dependencies. Standard `google_sign_in` is not selected; the DPAPI adapter adds only Windows SDK Crypt32, with no ATL requirement. |
| Selection | Now uses active timed events, earliest-end headline and conflict count; Next uses earliest future start; preserve source identities and all-day date semantics. |
| Refresh | Fully paginated per-calendar snapshot replacement; coalesced five-minute resident refresh and lifecycle/manual triggers; data older than five minutes is stale. |
| Meeting actions | Explicit validated HTTPS actions only; no automatic joining. |
| Meeting reminders | **Off by default**, generic text if enabled, initial five-minute lead, per-calendar controls, separate identities and cancellation. No guaranteed delivery during sleep or after Quit. |
| Focus behavior | Explicit Continue/Cancel overlap warning only; no shortening, automatic pause/start, strict-mode bypass, or snapshot changes. |

The specification records the text wireframe, professional Windows/macOS reference distinctions, monitor/text/accessibility behavior, failure states, timer invariants, product-document obligations, dependency gates, and Sessions 2–10 order. These are designs, not implemented calendar features.

## 3. Completed work and actual checks

### Session 1 discovery

- Read RTK, the original session brief, current architecture/local-data/notification/privacy material, desktop progress/release/acceptance, and relevant release/accessibility documents.
- Inspected actual platform targets, startup/factory composition, timer engine/controller, native Windows clock/alerts/lifecycle/tray/popup, repository, dependency manifests/lockfile, and candidate manifest/source inventory.
- Confirmed current-user package/process counts with read-only Windows inventory; restricted attempts did not establish absence until the successful inventory did.
- Checked candidate dependency metadata/API documentation and official product/reference material. Compatibility beyond metadata remains pending; no package was added or resolved.
- Rehashed all 220 source inputs and the identified MSIX, ZIP, and lockfile; they matched their recorded identities.
- Excluded TokenSave results because its index referred to another project. It was not used as evidence for Poma and was not rebuilt.

### Document delivery

- Created only `docs/WINDOWS_CALENDAR_SPEC.md` and this progress document.
- Preserved existing tracked and untracked application/release work and the original Calendar session brief.
- Documentation verification passed: all 35 local Markdown links resolve; required design/handoff content is present; all 253 pre-existing non-ignored files retain their hashes; the only additions are the two requested documents. All 220 candidate source inputs still match, as do the MSIX, offline ZIP, and lockfile hashes. No new application tests or builds are needed for this documentation-only change.

No Google Cloud configuration, sign-in, credential access, live calendar reads, event changes, dependency installation, application build, certificate trust, Windows installation/startup change, or publication was performed in Session 1. Prior desktop/mobile test counts remain historical results associated with their existing source/build records.

## 4. Completion criteria and evidence status

| Criterion | Status |
| --- | --- |
| Baseline distinguishes mobile HEAD from current uncommitted Windows foundation | Complete — verified source and inventory. |
| Relevant installed application provenance addressed | Complete for discovered current-user scope — no installed/running match; known artifacts traced to source. Recheck if another binary is supplied. |
| Windows/CPU scope and architecture composition explicit | Complete — specification sections 1–2. |
| Candidate compatibility findings and remaining gates explicit | Complete as design — no new native/library runtime verification claimed. |
| Wireframe, interaction, monitors, large text, privacy, account/selection and stale states defined | Complete as design — specification sections 3–7. |
| Read-only access and reminders-off defaults recorded | Complete — owner title choice also recorded separately. |
| Timer invariants and future product-document changes recorded | Complete — specification section 8. |
| Two cross-linked documents saved with dependency order, acceptance scenarios and Session 2 handoff | Complete — documentation delivery. |
| Calendar application functionality | Sessions 5–6 implement independently tested authorization, selection and bounded read snapshots. Live connection/event comparison are unrun; tray preview is fictional. Real agenda/actions and reminders remain Sessions 7–8. |
| Installed-desktop acceptance | Pending owner observation — retain existing desktop gates. |

Future checks must distinguish automated fixtures, native/package inspection, extracted runtime observations, and owner-observed installed behavior. Required scenarios are listed in specification section 9; no fixture, old build, successful scheduling call, or source claim closes a real delivery/accessibility/platform gate.

## 5. Unresolved questions and prerequisites

No further owner product choice blocks Session 1 or the offline foundation review. The title-privacy question is resolved: popup and unlocked tooltip titles are allowed; reminders remain generic and disabled initially.

| Open item | Owner / next stage |
| --- | --- |
| Trusted installed launch, clean-profile offline use, upgrade and remaining desktop matrix | Owner observations against the exact candidate; keep missing results open. |
| Sleep/hibernate, actual tray/overflow/mixed-DPI placement, Narrator/keyboard, startup and DND/denied notifications | Real desktop acceptance; do not infer from native unit tests or extracted launch. |
| OAuth resolution, S256/state/refresh and DPAPI compatibility | Session 5 independent checks/build passed; owner live authorization and installed/package behavior remain unverified. |
| Google project/API/consent/Desktop client, test-user/work-account approval and sign-in | Session 4 runbook delivered; owner console steps remain unverified. Session 5 implements authorization; live tests require owner participation and configuration. |
| Real event/meeting comparison and reminder behavior | Later sessions using harmless owner-prepared data; no personal event content in handoffs. |
| Broader Windows/ARM64/public distribution or calendar writing | Deferred scope; requires a later explicit decision and evidence. |

## 6. Session 1's adapted Session 2 handoff — historical instruction

The original Session 2 prompt assumes a missing Windows runner and potentially missing Windows alerts. **Those assumptions have been superseded by the current desktop working tree.** Apply the adapted instruction below instead of recreating that work.

```text
Implement Windows Calendar Session 2 in D:\pomodoro. Read RTK.md,
docs/GOOGLE_CALENDAR_WINDOWS_SESSION_PROMPTS.md,
docs/WINDOWS_CALENDAR_SPEC.md, this progress document, and the existing
WINDOWS_DESKTOP_PROGRESS/RELEASE/ACCEPTANCE records. Inspect the current diff
and any new owner observations before making changes.

Verify the existing offline Windows foundation and fix only demonstrated gaps.
Preserve the uncommitted desktop implementation, mobile configuration, existing
package identity/publisher/signing certificate and the original session brief.
Do not regenerate the runner, replace the native tray/window implementation,
or downgrade implemented Windows alerts to placeholders.

Confirm platform composition for production FFI SQLite/path/storage policy,
native sleep-inclusive clock, alerts, lifecycle and UI. Verify database
creation/reopen and safe errors, single timer/repository ownership, saved timer
recovery, exact pause/resume, strict mode, unique completion and manual successor
starts. Prevent mobile-only channel calls on Windows. Keep installed-owner
acceptance gaps open rather than treating extracted-package results as passes.

Reuse completed checks when source inputs still match; run affected checks for
changes or unresolved risks. Complete independent verification while owner-only
desktop observations remain pending. Preserve offline core use and document
actual checks, limitations, changed files and source/build identities.

Do not add OAuth, Google API calls, calendar fixtures, dependency upgrades without
a demonstrated compatibility reason, Google Cloud configuration, or publication.
Update this handoff and stop after Session 2; Session 3 adds fictional calendar UI.
```

If a replacement Windows artifact is needed later, use a version above 1.0.0.2009, retain identity/publisher/certificate, and bind checks to its new input/artifact hashes. Do not silently relabel the existing offline package as a calendar-enabled build or repeat historical phone campaigns merely because a new session started.

## 7. Session 2 — implemented and independently verified

### Changes and retained choices

- Preserved the existing runner, native tray/window/notification implementation, single timer/controller/repository owner, schema v3, package identities, and signing material. No runner regeneration, mobile configuration change, dependency upgrade, Google authorization/API/fixture, certificate trust, startup setting, installation, signing, or publication occurred.
- Retained Flutter 3.44.2 / Dart 3.12.2, production `sqflite_common_ffi` 2.4.4 and `sqlite3` 3.5.2, VS Build Tools 2019/MSVC v142 14.29.30133 and Windows SDK 19041. Normal-user `flutter doctor -v` confirmed Windows prerequisites; no installation was necessary. SDK-cache access restrictions were execution permissions, not incompatibility.
- Fixed one demonstrated production gap in `mobile/lib/data/windows_platform.dart`: directory creation happened outside the repository's error boundary. A blocked `databases` path produced a raw `PathExistsException`. Windows directory errors now become existing safe `StorageFailure` categories, including Windows disk-full codes 39/112, without exposing paths/native error text or replacing data.
- Added `mobile/test/windows_foundation_test.dart`: actual `NativeWindowsHost.repository` creation/reopen, exact pause/recovery, settings/tasks/history, corruption/future-schema retention, blocked-path repair/retry, real SQLite FULL rollback/idempotent retry, Windows storage policy, and visible unavailable/denied/failed alert states.
- Added guarded `mobile/integration_test/windows_offline_test.dart`. It invokes the real `main`/`PomaLoader` without injected services, requires `POMA_WINDOWS_SMOKE=true` and a marked isolated development profile, and rejects packaged execution. The existing mobile integration test is unchanged and was not used as Windows evidence.
- Added `--clock-sample` to the native test executable: JSON UTC, production sleep-inclusive elapsed counter, awake-only counter, and null boot identity. The opt-in probe creates no state or service. An ordinary `Sleep(20)` native test is explicitly not a real suspend test. See [Microsoft's interrupt-time contract](https://learn.microsoft.com/en-us/windows/win32/sysinfo/interrupt-time). Windows cold recovery still uses bounded UTC and retains its manual-clock limitation.
- Added `scripts/windows_session2_profile.ps1` to verify a closed-profile backup, isolate fictional test data, and restore the original profile only after all test processes exit. It refuses unmarked data deletion and preserves before/after evidence. The script imports its running PowerShell version's Utility module to avoid the documented inherited-module-path problem.

### Actual checks and evidence

| Check | Result / precise scope |
| --- | --- |
| Full Flutter regression | **205 passed**, no failures/skips; `artifacts/windows/calendar-session2-flutter-tests.json`. Includes the ten new foundation cases and existing domain/controller/repository/durability/clock/alert/desktop regressions. |
| Initial new-test failures | Blocked directory exposed the production error-boundary gap and was fixed. Alert widget assertions initially targeted content below the viewport, then an ambiguous rail/page scrollable; the fixtures now scroll the Settings page explicitly. These targeting failures were not classified as notification defects. |
| Static checks | Analysis clean; formatting checked **55 files**, zero changes. `artifacts/windows/calendar-session2-analysis.log`. |
| Native coordination | **56 checks passed** with the new probe compiled. Native CTest log: `.tools/windows-native-tests/Testing/Temporary/LastTest.log`. Awake probe returned valid microsecond counters and `bootCount: null`; no suspend pass is inferred. |
| Windows live integration | **1 passed**, about 68 seconds after the Debug build. Real production startup created SQLite, UI task/settings actions persisted, pause/reopen preserved **57,362,893 microseconds** exactly, and resume kept the run identity. One 60-second focus completion retained the resumed deadline and task-title snapshot; Short break stayed Ready. Reopen retained history, and the explicitly started successor rejected pause under strict mode. `artifacts/windows/calendar-session2-integration.log` and `calendar-session2-smoke.json`. The Debug host reported version 1.0.0.2007 from the unchanged mobile default; this is distinct from the release verification build. |
| Fresh Windows release | **1.0.0.2010**, built successfully with one worker. MakeAppx and the existing release audit verified 13 x64 PE files, the x64 AOT snapshot, 55 payload files, native SQLite manifest resolution, complete runtime/assets and licenses. `artifacts/windows/calendar-session2-build.log`. |
| Relocated launch | Extracted the new verification MSIX to `.tools/windows-calendar-session2-20261025/runtime-2010`; launched its `poma.exe` and observed the rendered Focus / Ready window and accessibility state. A fresh fictional development database was created. Loaded SQLite, Flutter and required VC runtime DLLs resolve from this relocated folder, not the development build directory. `artifacts/windows/calendar-session2-runtime.json`. Its five-second resource sample is descriptive, not a performance/network/rendering guarantee. |
| Mobile checks | Android/iOS configuration and the dependency lockfile match the 2009 inventory. Shared Flutter regressions ran; the prior Android build/device campaign was not repeated for this Windows-only repair. **iOS/Xcode compilation and execution: unrun — macOS tooling unavailable.** |
| Owner disconnected check | Owner explicitly reported **“All offline steps passed”** for the supplied disconnected tasks/settings, start/pause, Quit/reopen/resume, hidden completion, one history completion, Ready break, and persistence walkthrough. `artifacts/windows/calendar-session2-owner-observations.json`. The agent resumed desktop control before the reply arrived, confounding the sequence. Later marked-profile readback contained one task, zero completions, and a Ready one-minute focus; it does not independently corroborate the reported completion. Preserve the owner report, but require a clean repeat for independent acceptance. Network disconnection was not instrumented; the runtime was extracted, not trusted-installed. |
| Real sleep measurement | Owner reported **“Sleep completed; timer counted the sleeping time.”** The probes captured 35.066246 seconds of UTC, 35.065859 seconds of production elapsed, and 35.066245 seconds of awake-only time: no measurable suspend bias. Poma was not running at after-state inspection. `artifacts/windows/calendar-session2-sleep-measurement.json` and `calendar-session2-profile-after-owner.json`. This preserves the owner-observed result but does **not** verify an instrumented S3 interval. |
| Other owner desktop checks | A coordinated real S3 repeat, hibernation, installed toast presentation/DND/actions, trusted installation, startup, accessibility, and physical tray/display acceptance remain open. This host reports S3 and Hibernate available; availability is not a successful suspend check. |

### Build identity and notification limits

- Verification output: `artifacts/windows/Poma-1.0.0.2010-session2`; **unsigned, not installed, not a replacement signed pilot kit**. Package/publisher/application identities are preserved. Mobile remains `1.0.0+2007`; the signed 2009 MSIX and offline ZIP remain unchanged.
- 2010 MSIX SHA-256: `1c6a236edd8c742b8ae02b6cf00e456e357032bb928c3e4ac604f74747857d9e`.
- 223 source inputs; digest `fa76ac44dc221935c478dd1b1c4608e6bf8a987bad31836971defd2f9d7f7ca7`; lockfile SHA-256 remains `cc6af285af5a44c115f82dfe6a2771f5bfdc9f21eba8b825e829e2a828c08a85`. Compared with the prior 220 inputs, only the Windows platform adapter and native test source changed; three verification files were added.
- Existing native Windows alerts were retained. Unpackaged/extracted runs explicitly report **unavailable** when enabled, with visible Settings status. Installed availability depends on package identity and Windows policy; no toast presentation, sound, DND, or activation pass is claimed from a successful API call or mocked status.
- Completion effects remain post-commit and resident-only. Quit stops alerts; sleep can delay delivery; cold recovery never replays a completion toast. Every successor still starts manually.

### Owner observations and next session

The owner confirmed all disconnected walkthrough steps passed and later reported the timer counted sleeping time. Before the disconnected confirmation arrived, the agent had resumed desktop input; this was a coordination mistake. The owner clarified “you checked it after taking pc's access.” Preserve those reports with the sequence limitations above rather than presenting the later database readback as a clean observation of the owner's steps. No further UI control was taken after this clarification.

Connected standalone observations established task creation using ordinary keys and saving a one-minute focus setting. Computer Use Unicode text injection did not populate the Flutter field after one refocused retry; ordinary key input worked. Cached accessibility text sometimes lagged screenshots. Those tool limitations are not app failures or keyboard/accessibility acceptance passes. The owner stopped Computer Use with Escape; automation stopped immediately in that turn.

The development profile was copied and hash-verified before isolation. After confirming no Poma process remained, `scripts/windows_session2_profile.ps1 -Action Restore` verified the original hashes, archived the marked test profile under `.tools/windows-calendar-session2-20261025/development-after`, and restored the original `Poma/Development` directory. Its independent backup remains under `development-before`; `profile-state.json` records `restored: true`. No installed profile was changed. Final aggregate evidence is `artifacts/windows/calendar-session2-evidence.json`.

Next implementation session: **Session 3**, extending the existing native popup with fictional calendar UI, accessibility, and lock redaction. Do not recreate the tray or introduce Google configuration/sign-in/API reads. Carry unfinished owner acceptance explicitly; no installed/suspend gate is closed by this session's automated fixtures or relocated connected launch.

```text
Implement Windows Calendar Session 3 in D:\pomodoro. Read RTK.md, the original
Windows-calendar session prompts, WINDOWS_CALENDAR_SPEC.md, and this progress
document, including Session 2's exact source/build identities and evidence limits.
Preserve the existing uncommitted desktop implementation, pinned SDK/dependencies,
mobile configuration, native tray/window/alerts, single timer/database owner,
package identities, signing material, and the signed 2009 kit.

Extend the existing native popup with fictional Now/Next/agenda sections and
explicit fixture actions, plus accessibility and lock redaction per the spec.
No Google configuration, authorization, real calendar reads, event writes, or
publication. Keep timer controls tied to current run/revision and every successor
manual. Coordinate desktop ownership explicitly before taking input control;
never overlap an owner walkthrough. Keep unfinished installed/suspend gates open.
Run affected checks, update this handoff, and stop after Session 3.
```

## 8. Session 3 — fictional calendar popup

### Implemented boundaries and ownership

- Read the handoff before implementation. Preserved all pre-existing tracked/untracked work, Flutter 3.44.2 / Dart 3.12.2, the existing Win32 tray/window/alerts, package identity, signing material and earlier packages. No dependency or SDK upgrade was needed. The only additional native link is Windows SDK `wtsapi32`; it introduces no ATL requirement or redistributed library.
- One resident process, Flutter engine, `AppController`, timer engine and `poma.db` writer remain authoritative. `CalendarController` is an in-memory fixture source with an injectable wall clock and minute-level display updates; it has no repository, credentials, HTTP or browser capability. Hidden timer deadlines remain native and independent of visible Flutter rendering.
- The owner chose **Settings demo selector**, disconnected at each launch. Nine labelled fictional scenarios cover disconnected, connecting, empty, normal, overlaps, long Unicode titles, all-day, stale and error states. Connection/cancellation/retry/refresh/join/event/calendar actions remain local previews. No Google setup, authorization, connector calendar access, real data read, browser opening, event write, calendar cache or meeting reminder was added.
- Added typed fixture event/section models. `secondarySections` now carries display rows; accompanying `calendarGeneration`, date/date-label choices, refresh availability and redacted tooltip text are presentation only. `calendarAction(actionId, generation)` rejects obsolete fixture actions. Timer commands retain their separate run/revision checks. Popup day browsing is native presentation state, resets to Today on reopening, and does not change Now/Next time.
- Retained one tray GUID and the existing process/profile coordination. The popup starts at 380 logical pixels, uses icon bounds, then a tray activation point, or the main-window work area for Settings fallback. It wraps full titles, bounds height and scrolls; timer-only publishes retain agenda controls/focus. Reset/Skip remain in the native context menu alongside Open Poma, Refresh calendar (demo), Calendar settings and Quit.
- Main Close retains the enabled-by-default close-to-tray preference and persisted first-use explanation. Popup Escape/Close/Alt+F4 hide the same window. Open Poma navigates to full Focus, while Calendar settings resets Settings to its preview section. Quit retains flush/discard handling, disarms deadlines, cancels fixture updates, removes the icon and exits. Startup stays disabled in the manifest; the existing explicit toggle reports actual Windows states and remains unavailable in an extracted build.
- Added current-session WTS registration/unregistration and initial `WTSSessionInfoEx` inspection. Lock or unknown state redacts calendar sections and tooltip text in Dart and independently in native controls; a late display publish cannot restore details while native state is locked/unknown. This is distinct from the timer's strict-mode `locked` flag. `windowsDesktop.tooltipTitles` is saved through the existing persistence owner, defaults on for old records, and requires no schema change. Real lock/unlock observation remains an owner gate.

### Actual checks and review evidence

Evidence directory: [Session 3 review](../artifacts/windows/calendar-session3/). Only fictional content was captured. The owner explicitly answered **“Yes, review it now”** before desktop control; no simultaneous owner walkthrough was requested or claimed.

| Check | Observation / evidence limit |
| --- | --- |
| Flutter regression | Final complete suite: **213 passed**, no failures/skips, after the desktop-observed Dart UI fixes. `checks.json` and `flutter-tests.jsonl`. The earlier 211-pass run preceded the two added regression cases. |
| Calendar-specific tests | **8 passed** after the final fixes: nine fixture states, seven dates, overlap boundaries, all-day exclusive dates, Unicode preservation, local action transitions/stale rejection, lock redaction, title preference, shared timer identity/Focus navigation, and Settings return with 200% text + high contrast in both Flutter appearances. |
| Native checks | **75 passed**, including production popup anchor/geometry helpers with negative coordinates, missing/invalid icon bounds, constrained/auto-hide work areas and simulated 96/120/144/192 DPI with enlarged content; Unicode tooltip limits; real native focused-button Enter activation and disabled-control rejection; existing IPC/coordination/clock/activation checks. `native-tests.log`. Geometry inputs are simulations, not physical monitor observations. |
| Static checks | Final analysis clean; Dart formatting checked **55 files**, zero changes. `analysis.log`. `git diff --check` also passed. |
| Native compatibility / packaging | Built with existing VS 2019/MSVC v142 and Windows SDK 19041. MakeAppx audited 13 x64 PE files, the x64 AOT snapshot and 55 payload files. Complete runtime includes application-local SQLite/CRT and licenses. `wtsapi32.dll` resolves as a Windows System32 static import; import audit alone is not a lock-state runtime test. |
| Normal-scale desktop rendering | Agent observed the actual extracted runtime at the unchanged desktop scale. Dark disconnected/overlap/Tomorrow and long-title views, light agenda/all-day/footer states, native scrollbars and visible button focus were captured. The final complete candidate's screenshots use `complete-`; earlier `final-` images precede the last two Dart fixes. No numeric physical DPI or hardware inventory is inferred from screenshot dimensions. |
| Keyboard / closing | Tab moved from primary timer control to Open Poma; Space returned to Focus. The first build exposed Enter doing nothing on an owner-drawn native button; fixed and checked with a real native-button regression plus observed Enter return to Focus. Escape dismissed the popup and restored Settings focus. Shift+Tab reached the final Calendar settings control and scrolled it into view. On the final complete candidate, popup Alt+F4 left main Settings visible, outside activation dismissed the popup, Calendar settings returned to the preview from scrolled Settings, and local Refresh changed stale to normal without starting the Ready break. `review-record.json` and `complete-*.png`. |
| Calendar settings / stale review fixes | Review found that the offscreen lazy Settings preview could not scroll itself into view, and stale status was only below the agenda. Settings now gets a fresh page key for calendar navigation, covered by two widget regressions. Stale warning now precedes Now/Next. Superseded screenshots/packages are retained as preliminary evidence and are not the final candidate. |
| Hidden completion | Actual one-minute focus, alerts off, main Close explanation acknowledged, then all Poma windows hidden. **Before reopening**, read-only inspection of the marked fictional SQLite profile found exactly one 60-second completion and a Ready 300-second Short break. `hidden-before-reopen.json`; `final-running-before-hide.png`, `final-close-to-tray-explanation.png`, `final-hidden-completion-reopened.png`. No successor started. |
| Second launch | While hidden, another launch reopened the same main HWND **4916936**, with the same sole owner PID **3736**, from the relocated final native review runtime. A normal-user process inspection confirmed the retained owner. A restricted-token process query returned no rows earlier; that result was not evidence of an exit. No Poma crash event was found in the bounded Application log check. |
| Tool limitations | Flutter accessibility trees sometimes lagged screenshots; some element IDs expired and injected Unicode text/modifier editing did not populate the field. Ordinary BackSpace/number/Return keys set the one-minute duration. These are recorded input-tool limitations, not general keyboard/Narrator passes or application failures. |

### Review boundaries and owner points

Actual tray left/right clicks, icon count/overflow, Explorer restart, auto-hidden taskbar behavior, physical mixed-DPI/multiple monitors and monitor removal are **unobserved**: the available Computer Use window inventory did not expose Explorer/taskbar windows. Real Windows high contrast, native 200% text/scaling, Narrator speech and lock/unlock are also **unobserved**. Flutter high-contrast/200% Settings tests and native geometry calculations do not close these gates. Startup eligibility/login remains installed-owner-only; no OS startup setting, installation, certificate trust or notification policy was changed. Sleep/hibernation and installed toast gates from Session 2 remain open.

Owner review points, against the exact final candidate:

1. At your normal scale, select a fictional scenario in Settings → Calendar preview. Check density/readability and the warning above stale meetings. Open Poma should return to Focus with the same timer.
2. From the actual Poma icon, verify repeated left-click toggles one popup, right-click shows the short menu, and Escape/outside activation closes only the popup. Check visible/overflow icon placement and auto-hide if available.
3. Check native 200% text, high contrast, Narrator, any second monitor/mixed scale, and display removal. Record unavailable cases rather than marking them passed.
4. Lock/unlock Windows: popup closes and calendar titles disappear from native controls/tooltips; after unlock, the permitted fictional display returns. Unknown lock state should leave timer use available with calendar details hidden.
5. Close-to-tray should explain residency once. With that preference disabled, main Close should Quit. Installed Startup remains a separate explicit opt-in check; no startup enablement is part of this session.

### Final identity, profile restoration and next handoff

Final artifact identity and source-input hashes are recorded in `identity.json`; `REVIEW.md` identifies the final package/runtime and distinguishes superseded review builds. The signed 2009 kit, its offline ZIP, the unsigned Session 2 2010 package and the dependency lockfile retain their previously recorded hashes. The mobile version remains `1.0.0+2007`.

- Final unsigned package: [Poma 1.0.0.2011](../artifacts/windows/Poma-1.0.0.2011-session3-complete/Poma-1.0.0.2011-x64.msix). SHA-256: `bc98c0bfc122d8c64fd1c7272bd8afce8ab4698dd7b95b46f78902c615e47175`.
- **226** source inputs; source digest `fdede8f0ec44d01713813fcc2ae67830ef9ec1ac9a430e5a00912480cd2675e9`. The final source matches the build inventory, all extracted runtime payload hashes match the package, and Android/iOS configuration plus pubspec/lockfile/metadata match Session 2. The exact 12 changed/added implementation inputs are listed in `identity.json`.
- Native compatibility repairs used `INT_PTR` for menu/control IDs and negated supported Flutter value equality instead of unsupported C++17 inequality. The host's default Python lacked `hashlib.file_digest`; packaging used the existing `C:/Python311/python.exe`. No toolchain/dependency upgrade or software installation was performed. Restricted SDK-cache/IPC attempts were retried with normal-user access. One new widget test initially awaited a fake-time timer without pumping; the test was corrected, and the final complete suite passed.

The original closed development profile was copied and hash-verified before being set aside. All interactive test writes targeted a marked fictional replacement. After final explicit Quit, restoration verified the original hashes and restored the original profile; `profile-state.json` records `restored: true`. The fictional before/after evidence remains under `.tools/windows-calendar-session3-20261025`, and restoration is also recorded in `identity.json` / `review-record.json`. No installed profile was modified. Desktop input control was explicitly handed back to the owner after restoration; no further desktop input was taken.

Next requested implementation stage is **Session 4: Google project/setup runbook**, not live authorization or calendar reads. Stop after this fixture UI session. Preserve owner-only gates and the latest final source/build identity when continuing.

## 9. Session 4 — owner setup plan and configuration contract

### Delivered scope and retained identity

- Read RTK, the original Windows Calendar plan, specification and Sessions 1–3 handoffs before preparing the setup plan. The owner then requested a concrete plan; this session remains documentation/configuration preparation, not authorization implementation.
- Created [GOOGLE_CALENDAR_SETUP.md](GOOGLE_CALENDAR_SETUP.md) with the owner-operated project/API, Google Auth Platform Branding/Audience/Data Access, tester and Desktop-client sequence. Checked current official Google sources on 25 October 2026, including the OAuth overview, native desktop flow, Calendar setup/scopes, audience rules, client management and verification guidance. Source links are next to the relevant instructions.
- Preserved all pre-existing tracked/untracked application and release work. Checkout remains `codex/poma-offline-release`, HEAD `cb8b1a1e3f5a376b0121ead5328bb51fbcdc5679`. No application code, dependency, SDK, build script, product privacy notice, package identity or signing material was changed. The last Windows build is the Session 3 **1.0.0.2011** candidate and its recorded source/artifact identities in section 8; it is not an OAuth-enabled build. Mobile remains `1.0.0+2007`.
- The available browser inventory exposed no Google Cloud Console tab. Account authentication, chosen project and management permissions were not established. No browser sign-in, cloud resource creation, API enablement, OAuth/test-user change, credential download, real calendar read/change, local profile change, package build, installation or publication was performed.

### Setup decisions for the next session

- Personal Gmail/mixed-organization private testing uses **External + Testing**, with the actual sign-in account explicitly added as a test user even if it owns the project. Internal is an alternative only for a qualifying organization-owned deployment and eligible members; administrator restrictions still apply.
- Declare and later request exactly `https://www.googleapis.com/auth/calendar.calendarlist.readonly` and `https://www.googleapis.com/auth/calendar.events.readonly`. No broad calendar/write, Gmail, Drive, Tasks or unneeded identity permissions. Any additional identity scope needs separate justification. The app's selection limits event fetching, not the OAuth scope's provider-wide read boundary.
- Use a **Desktop app** OAuth client, independent of Codex/MCP. No Web, Android, UWP, service-account or embedded-browser substitution. Preserve external default-browser authorization code + PKCE S256 + unpredictable state + a temporary loopback-only callback on an OS-assigned port. This is specified, not implemented or exercised.
- Store any owner-downloaded original `installed` JSON and curated build settings outside the repository, at the suggested `%LOCALAPPDATA%\Poma\Setup\GoogleCalendar\PrivateTest\` location. No file there was created or read here. Client/project IDs are public application identifiers; an extractable Desktop client secret is not a confidential authentication boundary. User tokens/passwords/codes never belong in the setup file, source, logs or handoff.
- Configuration contract: `POMA_GOOGLE_CLIENT_ID`, optional `POMA_GOOGLE_DESKTOP_CLIENT_SECRET` compatibility material, and `POMA_GOOGLE_OAUTH_AUDIENCE` (`external_testing`, `internal`, `external_production`). Read compile-time values at Windows composition and inject validated configuration. Development and release compilation use the same curated external `--dart-define-from-file` JSON; future packaging carries the public settings in the executable, without depending on developer environment variables or the setup file at runtime. The reader and release-script forwarding remain unimplemented. Missing/invalid configuration must show **not configured**, disable Connect and perform no authorization/network work while offline Poma remains usable.
- **External Testing Calendar authorizations/refresh tokens expire after seven days.** Identity-only exceptions do not apply to the chosen Calendar scopes. Explain the setup limitation, stop automatic authorization retries and provide user-initiated Reconnect with context. Do not label every `invalid_grant` as proven seven-day expiry; revocation/account policy can also invalidate credentials. This behavior was researched, not observed in Poma.
- Existing mobile/offline Windows privacy notices do not disclose this planned Calendar connection. Owner support/contact email, accurate Calendar disclosures and any required hosted policy/domain are still needed. Private testing is separate from public brand/scope verification; no fake URL, public verification or production switch is part of this session.

### Owner-only prerequisites still outstanding

| Prerequisite | Recorded status / next action |
| --- | --- |
| Account and project | Not supplied/verified. Owner selects the account and Cloud project and completes password/MFA directly with Google. |
| Calendar API | Enable/confirm in that project; not observed. |
| Support/privacy details | Supply monitored support/developer email and truthful Windows Calendar disclosures; no email, hosted policy URL or domain confirmed. |
| Branding, audience and scopes | Save the intended private-test configuration and the two exact scopes; not observed. |
| Test users or Internal eligibility | Add the actual tester, or confirm organization eligibility and any Workspace/admin approval; not observed. |
| Desktop client and local configuration | Create/confirm Desktop client, immediately retain the download outside source and prepare curated defines. No client ID/download supplied or inspected. |
| Session 5 live flow | Authorization, actual scope grants, protected storage, refresh, expiry/revocation, restart and disconnect are all **unrun**. Independent configuration/mock checks can proceed before these live prerequisites are available. |

Owner sequence: follow setup-plan steps **1–7**, then report readiness, the audience and local file path. Do not paste the downloaded JSON or any user credentials. The build-settings schema in step 8 is for the next implementation session and does not make the current fictional UI connect to Google.

### Verification and evidence limits

Documentation checks **passed**: all **15** local Markdown links resolve, the single intentionally unconfigured JSON example validates, document whitespace and `git diff --check` are clean, and comparison against **261** pre-existing non-ignored files found only this handoff changed. The other **260** existing files retain their baseline hashes; the setup plan is the sole new non-ignored file. Review evidence is [Session 4 documentation review](../artifacts/windows/calendar-session4/review.json). No historical Flutter/native pass is reused as a new test of authorization.

No Flutter, native, Android or iOS application test/build is required or claimed for this documentation-only session. Earlier installed/tray/monitor/accessibility/lock/suspend/notification acceptance gaps stay open. In particular, no live Google sign-in or packaged-client configuration result is claimed.

### Exact next stage — Session 5

```text
Implement Windows Calendar Session 5 in D:\pomodoro. Read RTK.md, the original
Windows Calendar session plan, WINDOWS_CALENDAR_SPEC.md, GOOGLE_CALENDAR_SETUP.md
and the latest progress handoff. Preserve existing uncommitted Windows work,
mobile configuration, package identity/signing material, the single timer and
database owner, and the Session 3 source/build evidence and remaining owner gates.

Implement read-only Desktop Google authorization and secure disconnect, not
event fetching/cache, event writes or agenda synchronization. Wire the Session 4
configuration contract at Windows composition, including a useful unconfigured
state. Verify compatible library behavior and actual PKCE S256/state handling;
use the external default browser and a temporary loopback-only listener with
callback validation, cancellation, denial/timeout cleanup and no callback logging.

Request only the two approved scopes and verify actual grants. Use current-user
DPAPI-protected refresh credentials, no plaintext fallback, serialized refresh,
safe retention when refresh responses omit a refresh token and late-response
rejection after disconnect/account replacement. Explain External Testing's
seven-day expiry; do not loop browser prompts or misclassify every invalid_grant.
Disconnect clears local calendar-derived data/credentials immediately, attempts
provider revocation with honest offline limits and preserves Pomodoro records.

Add Connect/status/Reconnect/Disconnect and meaningful configuration, callback,
partial-grant, refresh, protection-error, restart and race tests. Complete
independent mocked checks while owner setup is pending. Before live consent,
confirm the owner's Desktop client/audience/tester readiness and accurate privacy
disclosures. Real sign-in requires owner participation; never request passwords,
access tokens or refresh tokens. If a prerequisite is missing, record it and
leave the live flow unrun. Update the handoff and stop after Session 5.
```

## 10. Session 5 — authorization and protected credential lifecycle

### Implemented boundaries

- Read RTK, the original session plan, specification, setup guide and historical/latest handoffs before changes. Preserved pre-existing Windows work, package identity/signing material, mobile target configuration, the single Pomodoro controller/database writer and earlier release artifacts. No Google Console changes, owner credential inspection, real sign-in, event access/write, installation, signing or publication occurred.
- Added an independent `CalendarConnectionController` and injected provider/storage/browser/time ports. It exposes connection/capability state and actions; credentials never enter Flutter/native display snapshots. Windows initializes/restores it asynchronously after core restoration. Calendar HTTP does not enter the timer command queue.
- Implemented the Session 4 compile-time configuration contract. Missing/malformed client settings or audience disable Connect and perform no authorization/listener/API work. The default verification build is unconfigured. The owner selected a **separate labelled demo section**: fictional preview actions still never invoke real sign-in or Google data.
- Adopted Dart-team `oauth2` **2.0.5** (BSD-3-Clause), with direct locked `http` **1.6.0** and `crypto` **3.0.7**. Resolution added only OAuth and changed HTTP/crypto dependency classification; no existing package version or SDK upgrade was required. Inspected the library's S256 generation, public-client request behavior, state validation, scope fallback, refresh-token preservation and error-body risks. Standard `google_sign_in` lists no Windows support and was not used. Sources: [OAuth package/API](https://pub.dev/packages/oauth2), [Google Sign-In platforms](https://pub.dev/packages/google_sign_in), [Google desktop OAuth](https://developers.google.com/identity/protocols/oauth2/native-app).
- The default-browser adapter uses a fresh secure-random state and verifier, S256, exact read scopes, offline authorization code exchange and optional extractable Desktop compatibility material. A temporary listener binds **127.0.0.1 only**, on an assigned port. Callback method/host/absolute authority/path, duplicates, state and code/error exclusivity are validated. Invalid unsolicited callbacks do not exchange codes and leave the legitimate attempt pending. A valid return closes the listener before exchange. Denial, Cancel, browser failure, five-minute callback timeout and Quit close resources. Network requests have deadlines; raw provider exceptions/bodies and callback values are never shown/logged.
- Actual token-response grants are checked before the OAuth library can substitute requested scopes. Both approved scopes are required; refresh scope omission inherits only previously verified scopes. Account identity uses only CalendarList's primary `id,primary` fields, under the already-approved list scope. **This is a minimal identity read, not event loading or a calendar picker.** No profile/email/OpenID permission was added. Account keys include client and primary-calendar identity.
- Added native current-user DPAPI with `CRYPTPROTECT_UI_FORBIDDEN`, profile-bound context, ciphertext-only temporary files and atomic replacement. Refresh metadata uses `calendar/connection.dpapi`; access tokens stay in memory. Native revision checks reject obsolete writes. A durable `calendar/disconnected` marker precedes credential/account-data deletion and prevents restart restoration after interrupted cleanup. Failed protection/read/write/delete is explicit and retryable, with no plaintext fallback or false removal claim. If even the marker cannot be written, removal is reported incomplete rather than promising restart disconnection.
- Refreshes coalesce, preserve omitted refresh credentials only for the verified same client/account and reject late results. Transient failures retain saved refresh credentials; invalid/revoked grants retire them and require explicit Reconnect, with Testing's possible seven-day expiry explained. Disconnect invalidates access immediately, cancels authorization/refresh work, clears calendar-only local data and attempts bounded provider revocation without delaying local disconnection. Unconfirmed/offline revocation directs the owner to Google Account third-party connections. Fresh consent waits for revocation transport completion/cancellation. Quit cannot start a late revocation after cleanup finishes.
- Connected Settings includes status, Connect/Reconnect, Cancel, Disconnect and cleanup recovery plus pre-connection disclosures. Disconnect preserves local tasks/history/timer state. Full local reset has an optional Windows cleanup participant using the existing durable cleanup barrier; its queue awaits local cleanup only, never provider revocation. Existing reset deletion/strict-mode semantics remain intact.
- `build_windows_release.ps1 -CalendarDefinesPath <curated owner-local JSON>` validates the three allowed settings without printing values and forwards them to release compilation. It rejects configuration with `-SkipBuild`. It does not copy the setup JSON into the runtime. Updated README, architecture, local-data/privacy review, Windows bundled notice, Windows-only copy, package description, notices and setup guidance to match actual behavior. No event cache exists yet; later agenda storage remains explicitly unencrypted.

### Observed checks

Evidence: [Session 5 review](../artifacts/windows/calendar-session5/REVIEW.md) and [machine-readable review](../artifacts/windows/calendar-session5/review.json).

| Check | Actual result and limit |
| --- | --- |
| Complete Flutter regression | **239 passed**, no failures/skips, including **26 new Calendar tests**. `flutter-tests.log` is the final complete run. Core regression checks include existing durability, process-crash, SQLite, timer/strict-mode and mobile/shared behavior; this is not a new phone campaign. |
| Authorization and races | Real local loopback requests with mocked Google replies cover S256/verifier matching, fresh state, exact scopes/redirect, wrong/missing state, duplicate/malformed parameters, host/path/method/absolute-authority rejection, denial, cancellation, browser failure, timeout and closed-port reuse. Tests also cover partial/missing grants, malformed replies, public-client refresh, omitted/rotated tokens, coalescing, invalid_grant/network errors, restart, protected-storage failures, incompatible clients, account replacement, late exchange/identity/refresh/storage/request results, revocation gating, task/history preservation and full-reset retry. No real Google access is inferred. |
| Native Windows checks | **92 passed**, compiled with existing MSVC v142 / Windows SDK 19041. Real current-user DPAPI round-trip/reopen, non-plaintext bytes, copied-profile rejection, injected protection failure, locked-file atomic replacement/deletion failure, durable marker/restart cleanup, stale revision rejection, account-data purge, corruption and blocked-directory recovery are covered. Profiles contain synthetic data and are removed. Separate-user DPAPI behavior and installed MSIX behavior remain unrun. |
| Build configuration | **11 checks passed** against the actual release-script guard: absent/default and valid curated settings, malformed JSON, original `installed` schema, placeholder ID, invalid audience/compatibility type/control characters, unexpected credential keys, missing file and `SkipBuild` conflict. No build/account/publication side effect from these guard checks. |
| Static checks | Analysis **clean**, formatting **60 files / zero changes**, and `git diff --check` passed. |
| Windows compilation | Final **1.0.0.2012** release compilation passed in **55.3 seconds**, using the existing toolchain. Four build-output PE files are x64; Crypt32 import-name inspection and the built OAuth license notice passed. This is developer build output, **not a newly packaged/private MSIX or clean-machine standalone acceptance**. |
| Identity preservation | **81 Android/iOS/metadata inputs** match the final Session 3 inventory. Mobile version remains **1.0.0+2007**; pubspec adds the stated dependency/classification changes. The signed 2009 MSIX/offline ZIP and final Session 3 2011 MSIX retain their recorded SHA-256 hashes. |
| Bounded privacy review | No app-owned logging calls in the new credential/provider paths, callback URLs or synthetic credential values in retained check logs, synthetic credential markers in executable/AOT output, or original/curated owner setup JSON in the build runtime. OAuth's license is present in built notices. This does not establish complete dependency safety or live network behavior. |

Initial failures were test/tool issues: script execution/SDK-cache restrictions required the existing helper's normal-user access; Flutter's widget HTTP override initially returned synthetic HTTP 400 for loopback requests. The test client now explicitly opts out only for its own loopback connection. The additional absolute-URI test initially needed an explicit socket stream cast. Static checks found and corrected missing test braces. Final checks above passed after those corrections. Source review additionally fixed a potential post-Quit revocation and a blocked-directory classification gap; both have regression coverage.

Final verification identity (not the older package-inventory digest format): **103 source/native/test/helper inputs**, SHA-256 **`0e0d1cd7a4f0669eb04c1f52df45cc44cc87a9ce467109d1402ecb1712c6d259`**. The complete list is in `review.json`. Final `poma.exe` SHA-256: **`95aee0328760989fdcded646644c576762dc3468bcfcec9ae535a40cfb13f57e`**; AOT snapshot SHA-256: **`84ccd31009ae3689fcc1b874c7aac00320f4dd96000ba14a8f8841f0f7619a8f`**. These identify the unconfigured verification build, not an OAuth-accepted installed release.

### Owner prerequisites and remaining gates

No owner client configuration was supplied or inspected. Project/API readiness, branding/audience, tester/admin eligibility, Desktop client and truthful owner disclosures must be confirmed using the setup guide. Prepare the curated defines outside source control and report readiness/audience/path only; never paste the original download, tokens, codes or callback URL. The updated bundled Windows notice describes implemented Session 5 behavior; any console-required hosted privacy/support material remains an owner responsibility.

**Live sign-in, actual grants, live refresh/rotation, Testing expiry, revocation, real account replacement and restart after live consent: unrun.** They require owner participation. No default browser was opened for real Google sign-in. No installed profile or Google calendar was modified. Earlier tray/overflow, mixed-DPI/monitor, Narrator/real high contrast/text scale, lock/unlock, Explorer restart, installed startup/toasts, sleep/hibernate and clean-install gates remain open. iOS/Xcode and a new physical Android campaign are unrun; shared tests and the Windows build do not close those gates.

### Exact next stage — Session 6

```text
Implement Windows Calendar Session 6 in D:\pomodoro only when requested. Read
RTK.md, the plan/specification, GOOGLE_CALENDAR_SETUP.md and this Session 5 handoff.
Preserve existing Windows/mobile work, package identity/signing material, single
timer/database ownership, separate fictional demo and all recorded owner gates.

Reuse the protected credential lifecycle and account/generation-checked access
port. Add explicit calendar selection (none selected initially), fully paginated
read-only event-instance snapshots, bounded seven-local-date account-scoped cache,
atomic per-calendar replacement, stale/partial/offline handling and coalesced
refresh. Do not request extra scopes, add writes/reminders or turn fixtures into
real-account data. Keep access errors separate from core Pomodoro startup.

Test pagination failure, retention, permissions, account replacement, selection
changes and disconnect/reset races. Implement calendar-derived storage only under
the cleanup-owned calendar account subtree. Late requests must never repopulate
disconnected data. Review the authorization port's epoch checks and keep all
network/storage work off the timer command queue.

Owner Google setup and live Session 5 consent remain unverified. Complete
independent work with synthetic data; real Google checks require readiness and
owner participation. Record actual results and unrun gates without including
private event contents or credentials. Update this handoff and stop at Session 6.
```

## 11. Session 6 — selected-calendar snapshots and bounded account cache

### Implemented behavior and boundaries

- Re-read RTK and the plan/specification/setup/latest handoff, inspected existing
  changes, and retained the offline timer owner, Pomodoro database/schema, mobile
  factories, package/signing identities and separate fictional demo. Owner setup
  was explicitly reported **pending**. No owner configuration/profile was read,
  Google sign-in initiated, live events fetched, cloud resources changed, or
  package installed/signed/published.
- Added independent `CalendarReadController` with provider/cache/clock/scheduler
  ports and normalized source/date/event/coverage records. Windows composes it
  after core restoration; neither HTTP nor cache workers enter the timer queue.
  Real event state is exposed for Session 7; the existing tray remains fictional.
- Settings lists every CalendarList page, including hidden sources, retaining real
  IDs, display names, role, colors and time zone. Availability-only/unknown roles
  are disabled; reader/private-access restrictions retain provider redactions.
  Multiple checkboxes are drafts until **Save selection**. A new account selects
  none, and provider `selected` flags never authorize event fetching. Source
  identity is never derived from names, colors or the `primary` alias.
- Event fetching uses fixed Google HTTPS endpoints, minimal fields, explicit
  rolling bounds, `singleEvents=true`, `showDeleted=false` and every continuation
  page, including empty continuation pages. Repeated tokens, malformed intervals
  or oversized results fail without committing a partial snapshot. No sync token
  is used. Each calendar replaces only after all pages and its storage commit
  succeed; successful sources update independently and removed/moved events
  disappear on replacement.
- Retained coverage is today through six local dates ahead, with individual
  midnight-to-UTC boundaries. The transport envelope additionally covers the same
  dates in the source calendar's zone, preventing all-day edge loss across zones.
  The already-locked `timezone` **0.11.2** (BSD-2-Clause) is now direct; no package
  or SDK version upgrade was introduced. Timed intervals retain UTC instants and
  supplied zones; date-only intervals preserve exclusive ends. Ongoing entries,
  recurrence/exception identity and self-response survive normalization; declined
  and cancelled events are ineligible, and hidden private details use generic text.
- Only normalized identities, titles, times/dates, source metadata, self response
  and validated structured meeting/event URLs are retained. Descriptions,
  attachments, attendee rosters and raw provider bodies are excluded. Retrieval
  limits attendees and stores only the self response. No remote HTML rendering,
  automatic browser launch, event write, task import or reminder was added.
- Added one versioned unencrypted account document at
  `calendar/accounts/<account-key>/state.json`, separate from `poma.db`.
  Account keys remain the Session 5 client/verified-primary-calendar digest.
  Native workers use the credential store's mutex and revision gate, plus account
  scope leases; obsolete writes after selection/account/window/reset/Quit changes
  fail before recreating data. Flushed atomic replacement commits selection and
  deselected-source removal together. Responses are capped at 4 MiB and staged
  snapshots/account documents at 16 MiB; excess fails without truncating success.
  Malformed cached color values are discarded before presentation while valid
  selection/data survive.
- Session 5 active credential version 1 remains readable. Invalid grants now
  retire to protected no-token identity in `calendar/retired.dpapi`, invalidating
  pending work while retaining removable stale cache. Restart prefers retirement
  over any interrupted old-credential cleanup. Explicit Reconnect retains selection
  only after the same client/account is verified and a complete calendar catalog
  revalidates IDs/roles. Different accounts begin empty. Explicit Disconnect,
  account replacement and full reset still purge calendar-derived local data.
- Five-minute resident refresh, stale content opening, resume, clock/zone changes,
  selection/connection changes and manual refresh coalesce independently. Midnight
  and lifecycle changes trim expired data even offline; uncovered tails are not
  claimed empty. Minute age updates perform no network/storage work. Settings
  shows age, available/partial coverage and source failures, with lock/unknown-state
  redaction. A 401 forces one coalesced refresh/replay; repeated rejection requires
  explicit Reconnect. Permission 403 pauses affected automatic reads; rate-limit
  403/429 and transient failures get at most two retries with exponential jitter
  and Retry-After. Manual refresh honors active backoff. Quit cancels transports,
  scheduled retries and cache leases without waiting for network completion.

### Changed inputs and documentation

The machine-readable review lists **19 changed/added verification inputs** against
Session 5, including seven new reader/ports/time/provider/cache/domain/test files.
Existing edits are confined to connection/credential lifecycle, Windows
composition/lifecycle, Settings, pubspec classification/description, native
credential/cache plumbing, targeted tests and the bundled Windows privacy notice.
No unrelated Session 5 verification input changed. README, third-party notices,
architecture, local-data/privacy review, setup guidance and this handoff now
describe implemented Session 6 behavior. Full exact paths/hashes are in the
[review JSON](../artifacts/windows/calendar-session6/review.json).

### Observed checks and identity

Evidence: [Session 6 review](../artifacts/windows/calendar-session6/REVIEW.md).

| Check | Actual result and limit |
| --- | --- |
| Complete Flutter regression | **263 passed**, including **24 new Session 6 tests**. Final complete run includes the saved-color recovery guard. Existing timer, strict-mode, durability, process-crash, repository, desktop and shared/mobile regressions remain covered; this is not a new phone campaign. |
| Reader/transport/cache cases | Synthetic data covers pagination/empty continuation, page failure, atomic write failure, independent calendar success, explicit selection, restricted access, source removal, same/different-account reconnect, retired restart, late HTTP/storage after selection/account/window/disconnect/reset, offline retention, UTC aliases, DST 167/169-hour weeks, all-day exclusive ends, recurrence identity, ongoing/cancelled/declined/private events, minimal retained fields, unsafe URLs, 401/403/429/backoff/cancellation, coalescing, minute IO absence and Settings/lock presentation. |
| Native Windows storage | **113 checks passed** on the existing MSVC v142 / Windows SDK 19041 toolchain. New cases exercise actual atomic cache replacement failure, old-document preservation, deselection document replacement, account/scope/revision isolation, retirement/reopen, size limits, durable disconnect and post-Quit rejection, alongside existing DPAPI/native checks. Synthetic isolated profiles are used. |
| Static checks | Analysis **clean**; formatting **70 files / zero changes**; `git diff --check` passed. |
| Windows compilation | Final developer build **1.0.0.2013** passed in **41.4 seconds**, one worker. Four build-output PE files are x64; the built notices include timezone's license. No newly packaged/installed/standalone-runtime acceptance is claimed. |
| Preservation | All **81 Android/iOS/metadata inputs** match the Session 3 inventory. Mobile remains **1.0.0+2007**. The signed 2009 MSIX/offline ZIP and final Session 3 2011 MSIX retain their Session 5 recorded hashes. |
| Bounded privacy inspection | No app-owned logging call was found in the inspected reader/connection/cache/model paths, and no selected synthetic private markers appeared in executable/AOT output. Owner configuration was not supplied/read. This is a bounded source/runtime check, not complete dependency or live-network proof. |

Initial check failures were corrected and are recorded in the review: a fixture
constant, timezone UTC lookup, widget layout timing, and style diagnostics.
Restricted SDK/DPAPI attempts required normal-user tool access. Final source
review found and fixed malformed saved-color handling, then repeated the full
suite, static checks and Windows build. No failed preliminary result is presented
as a live provider or installed desktop pass.

Checkout remains `codex/poma-offline-release`, HEAD
`cb8b1a1e3f5a376b0121ead5328bb51fbcdc5679`, with preserved uncommitted work.
Final verification identity: **110 source/native/test/helper inputs**, SHA-256
**`1576178750b3dd68458b0f06ae0847633c1716bc0e5db32d9fddf9253bf979ee`**.
Executable SHA-256:
**`f180ae9605c0fd2c5c8ca61effdc41f9eff663fc5cba7fc878a7a4f6d2788824`**.
AOT snapshot SHA-256:
**`a4993fc08556f2bb8a9cdd761d53bf45cc50c4f4cf66726f732ee2ac309c4141`**.
The complete input/payload identities are in the review JSON. These identify an
unconfigured developer compilation, not an OAuth-accepted installed release.

### Owner prerequisites and remaining limits

**Live Google configuration, sign-in, actual grants/refresh/revocation/Testing
expiry, real account replacement and owner-prepared event comparison: unrun.**
Follow the setup guide, prepare the curated owner-local build settings and harmless
events (recurrence, all-day, move/delete), then report readiness/audience/path
without credentials or event contents. Codex connector access is not Poma consent.

Retention operates while Poma is resident and at next startup; no expiry service
runs after Quit. The cache is unencrypted, and deletion is not forensic erasure.
Four-/sixteen-MiB ceilings produce an explicit failure retaining prior valid data.
Earlier installed tray/overflow, Explorer restart, physical monitor/DPI,
Narrator/high contrast/text scale, lock/unlock, startup, sleep/hibernate, toast
policy and clean-install gates stay open. iOS/Xcode and a new physical Android
campaign are unrun. No installation, certificate trust, signing or publication
was performed.

### Exact next stage — Session 7

```text
Implement Windows Calendar Session 7 in D:\pomodoro only when requested. Read
RTK.md, the plan/specification/setup and this Session 6 handoff. Preserve the
uncommitted Windows/mobile work, separate fictional demo, timer/database ownership,
read scopes, cache leases/account isolation and all recorded owner acceptance gates.

Consume CalendarReadController's real selected-calendar snapshots in the tray
agenda. Implement deterministic Now/Next, overlaps, Today/Tomorrow/day browsing,
all-day and invitation labels, age/coverage and failure/reconnect presentation.
Keep event-instance identities; never merge entries merely because titles match.

Add explicit validated Open event/Open Calendar/Join actions with current account,
selection generation and event revalidation. Preserve lock redaction, large text,
keyboard and Unicode behavior. Do not launch URLs during refresh or add writes,
reminders, task conversion or timer-domain effects. Reuse the sole timer owner.

Owner setup and live consent remain pending. Complete independent synthetic work
and compare only harmless owner-prepared events after readiness and participation
are supplied. Record actual checks and limitations without credentials/private
event contents. Update this handoff and stop after Session 7.
```

## 12. Session 7 — real tray agenda and explicit meeting actions

### Implemented boundaries and behavior

- Preserved the uncommitted Windows/mobile foundation, read scopes, account/cache
  isolation, package/signing identities and the sole timer/database owner. No
  event writes, reminders, focus-overlap policy, task conversion, owner
  configuration inspection, Google sign-in or live event access was added.
- Added `CalendarAgendaController`, deriving the normal tray from Session 6.
  Deterministic Now/Next retains every source instance, shows simultaneous
  conflicts, invitation labels and verified-versus-saved absence. Ordinal calendar
  IDs break ties before event/recurrence identity; titles never determine identity.
  Duplicate source names receive stable calendar-number qualifiers.
- Today/Tomorrow/the remaining cached dates filter only the agenda. Reopening
  defaults to Today; refreshing preserves an available selected date by key.
  All-day events retain provider date values and exclusive ends. Boundary jobs,
  midnight/window changes and regional/time-zone notifications refresh grouping
  independently of the timer. Windows formats local times using the actual user
  short-time preference, including overrides; formatting is not timer-tick IO.
- Loading, no selection, unconfigured, disconnected, connecting, offline/stale,
  partial source failure, storage trouble and reconnect states have safe recovery
  actions. Saved content remains visibly unverified after failure/age/auth loss.
  Individual calendar age/coverage/failure is available below the agenda. Missing
  coverage never proves an empty schedule.
- Rows can expose both Open event and Join, with full accessible names. Opaque
  action tokens revalidate account/scope, generation, selection, unchanged source
  instance and current URL. Native launch additionally checks unlocked state,
  generation, HTTPS host/route and URL syntax. Refresh/startup/timer work never
  launches a meeting URL. Safe browser failure text is recoverable.
- Structured conference video links precede hangoutLink, then literal location
  and description fallbacks. Raw fallback text is transient and is not cached or
  rendered as HTML. Cache version 1 remains compatible; saved URLs are revalidated.
  Meet, Teams and bounded Zoom hosts use recognized meeting routes. Script/file/
  custom schemes, deceptive hosts, credentials, unsafe ports, encoded controls
  and malformed URLs are rejected. Unsupported meetings retain Open event.
- The real agenda is the normal tray source. The explicitly labelled fictional
  Settings preview is isolated, cannot invoke real actions and does not replace
  normal tray behavior. Tooltip-title preference persists through the original
  owner. Lock/unknown state clears native real/preview rows, tooltip details and
  accessible event names. Controls are reused to preserve focus across updates.

### Actual verification and evidence

Evidence: [Session 7 review](../artifacts/windows/calendar-session7/REVIEW.md),
[machine-readable identity](../artifacts/windows/calendar-session7/review.json),
and seven fictional native popup screenshots linked by the review.

| Check | Actual result and limit |
| --- | --- |
| Complete Flutter regression | **276 passed**, including **13 new agenda tests**. Covers deterministic boundaries/conflicts, equal-title source identities, invitations/date-only spans, stale/missing/partial coverage, reconnect/account/privacy races, IO-free boundary updates, formatting preferences, DST/midnight/timezone regrouping, fallback safety and timer/fixture isolation. Existing storage, strict/stale controls and process-crash checks remain included. |
| Native Windows checks | **199 passed** on MSVC v142 / Windows SDK 19041. The **41-case shared URL corpus** runs in Dart and native validation. Actual Windows formatting and prior native storage/one-owner/geometry/keyboard checks also pass. |
| Static checks and compilation | Analysis **clean**; formatting **74 files / zero changes**; `git diff --check` passed. Final production developer build **1.0.0.2014** passed in **58.4 seconds**, one worker. Four PE files are x64; file version is independently checked and review-only mode is absent. |
| Native fictional UI | Real reader/presenter/native popup pipeline observed with memory-only adapters, an in-memory timer database, isolated native profile and a blocked browser adapter. Now/Next, long Unicode titles, conflicts, Today/Tomorrow keyboard selection, accessible action names, Tab/Shift+Tab/Enter/Escape, focus scrolling, partial-source recovery and injected native 200% text were observed. No Windows scale/privacy setting was changed. This is not live Google, installed runtime, actual OS 200% or Narrator-speech acceptance. |
| Preservation/privacy | All **81 Android/iOS/metadata inputs** match the earlier inventory; mobile stays **1.0.0+2007**. Historical 2009 MSIX/offline ZIP and final 2011 MSIX hashes remain unchanged. Bounded logging/runtime-marker checks found no inspected app-owned logging or selected review/private markers in production payloads. |

The review records preliminary SDK/DPAPI access limits, native compiler/linker and
query-parser issues, and Settings-test scrolling/timing corrections separately
from final passes. The fictional review was quit and its window disappeared;
desktop input control was handed back, with no later input. No owner profile was
loaded or modified by the review target.

Checkout remains `codex/poma-offline-release`, HEAD
`cb8b1a1e3f5a376b0121ead5328bb51fbcdc5679`, with prior uncommitted work preserved.
Final **116-input** verification fingerprint:
**`a69052019ba374017056139c1061c676e6daf112dcd0feb3ab182da534f326bb`**.
Executable SHA-256:
**`90a511a1090425b37c306744db427c021c9626d7c1d09b6998ae70dc097f59bf`**.
AOT SHA-256:
**`f7a1020c3e78d925162347145e731acffb331bd44c79b6a4515499f795e2b7ca`**.
The separate synthetic screenshot runtime has its own hashes and precedes the
final nonvisual widget-key/fallback-boundary refinement; do not equate it with the
production target or live acceptance.

### Owner prerequisites and next handoff

**Google setup, live Poma authorization and owner-prepared event comparison remain
unrun.** Follow [the setup guide](GOOGLE_CALENDAR_SETUP.md), report readiness,
audience and the local curated build-settings path without credentials, then sign
in personally and choose calendars. Compare harmless recurring/all-day/conflicting
events, source identities, a moved/deleted instance and explicit meeting links.
Coordinate a separate owner/agent desktop walkthrough; retain only fictional or
redacted evidence.

Positive real default-browser opening, actual meeting links, Narrator speech,
actual Windows 200% setting, lock/unlock, physical tray/overflow/monitor/DPI and
Explorer restart remain unverified. Earlier trusted installation/clean-profile,
startup, sleep/hibernate and toast-policy gates remain open. No package was
signed, installed or published, and no new physical Android/iOS campaign ran.

Session 7 stops here. The next application stage, only if requested, is **Session
8: resident reminders and calendar-aware focus behavior**, retaining all existing
timer, notification, privacy, account/cache and owner acceptance constraints.

## 13. Session 8 — resident reminders and calendar-aware focus

### Implemented behavior

- Added independent reminder preferences/controller/store/platform ports. The
  initial policy is **off**, no included calendars, five-minute lead; available
  leads are 1/5/10/15/30 minutes. Calendar inclusion is separate from agenda
  selection and timer alerts. Only fresh committed, readable selected sources
  can remind; all-day/cancelled/declined entries are excluded.
- Native C++/WinRT MSIX notification transport is retained for timer completions
  and extended for meetings. The `timer` and `calendar` groups, identity spaces,
  action queues and cancellation are independent. Disabling timer alerts now
  removes only timer notifications. Normal Quit/reset clear both. Unsupported
  unpackaged runs report unavailable; Windows denial/errors remain visible.
- Meeting notification text is always generic: “Meeting coming up” / “Open Poma
  to see your schedule.” Payloads contain only opaque resident token/generation
  and expiration. Open agenda revalidates the current occurrence, account,
  settings, freshness and unlocked state. Dismiss changes no timer/calendar
  event. Repeated and obsolete actions cannot open the agenda.
- `calendar/accounts/<account-key>/reminders.json` is a separate version-1,
  unencrypted preference/receipt document. It reuses the reader's current
  revision/scope lease and native mutex/atomic replacement without rebinding the
  reader or touching `poma.db`. An attempt receipt is flushed before presentation;
  native resident deduplication provides another barrier. A crash after the
  receipt can lose an alert. Occurrence/start identities preserve equal-title
  source separation; moving an occurrence permits one new future reminder.
- One native one-shot deadline covers the next reminder. Source updates/removals,
  selection/account/setting changes, disconnect/reset and lifecycle events revoke
  obsolete jobs/toasts/tokens. Failure stops calendar reminders with safe retry
  UI and leaves the offline timer usable. Reminder effects never enter the timer
  command queue or run on per-second timer ticks.
- **Owner-selected wake/restart behavior: skip missed reminders.** Suspend clears
  native calendar deadlines. Resume/restart, clock and setting changes schedule
  future deadlines only, with no old-meeting backlog. Uninterrupted message-loop
  jitter gets at most 30 seconds; already-started meetings are skipped and toast
  expiration is the meeting start. No service, wake task or OS future toast is
  registered. Fully exited Poma generates no reminders; exact sleeping delivery
  is unsupported.
- Flutter, popup and tray controls share one desktop action coordinator. Captured
  revision/run/explicit action reach the original controller; native popup input
  also captures identity at press, so a held Pause cannot turn into successor
  Start after expiry. A new Ready focus overlapping an ongoing/upcoming selected
  meeting gets Continue/Cancel for its **full original configured duration**.
  Dialogs run outside serialized commands, conflicts are checked again after
  confirmation, changed conflicts require renewed confirmation, and lock/timer
  changes cancel the start. Strict mode, manual successors, exact remainder,
  fixed completion timestamps and task/history snapshots are preserved. The
  pure timer engine, alert coordinator, repository schema and Google scopes did
  not change. Calendar events never become tasks.

### Checks and actual observations

Evidence: [Session 8 review](../artifacts/windows/calendar-session8/REVIEW.md),
[source/package identities](../artifacts/windows/calendar-session8/review.json),
and [isolated runtime observations](../artifacts/windows/calendar-session8/runtime-observations.json).

| Check | Actual result and scope |
| --- | --- |
| Complete Flutter regression | **292 passed**, including **16 new Session 8 tests**. Covers defaults, source/lead changes, move/cancellation/deselection/disconnect, stale/denied sources, duplicate attempts/actions, receipt/write races, failed setting save/retry, skipped missed deadlines, strict controls, overlap boundaries/reconfirmation and real Flutter warning/lock redaction. Existing hidden expiry, retry, cold recovery, durability and mobile/shared cases remain included. |
| Native Windows tests | **211 checks passed**, including actual isolated DPAPI, independent reminder documents, failed atomic replacement, stale lease/disconnect write rejection and separate/malformed activation parsing. These are host tests, not installed toast observations. |
| Static/format | Analysis **clean**. Formatting checked **78 files, zero changes**, without rewriting. |
| Windows production build | **1.0.0.2016**, release compiled with one worker; full runtime/import audit and unsigned MSIX packing completed. No review-only mode is present in the production payload. |
| Real hidden runtime | A separate isolated synthetic unpackaged build ran for 70 seconds with a memory-only timer database. One native timer deadline committed one completion at its original identity/deadline, left Short break Ready, kept the foreground ticker off, and repeated reconciliation retained one history row. One directly armed native calendar-deadline probe fired. This probe is not an end-to-end provider reminder or delivered toast. |
| Actual capability | Current-user inventory found **zero installed Poma packages** before review. The runtime reported **unavailable** notification capability, correctly for unpackaged execution. No Windows toast display, sound or activation pass is claimed. |
| Preservation | All **81 Android/iOS/metadata inputs** retain the previous hashes. Mobile remains **1.0.0+2007**. The signed 2009 MSIX/offline ZIP and final 2011 MSIX are unchanged; the existing uncommitted work is preserved. |

The synthetic 2015 runtime has its own payload hashes. It precedes the final held-button
guard, failed-settings retry repair and test-diagnostic annotation; it is not the final 2016 production MSIX. No owner
profile was loaded/modified, desktop input automated, Google configuration read,
sign-in initiated, event fetched/written, certificate trusted, package installed,
startup/notification policy changed, artifact signed or publication performed.

Preliminary restricted SDK/DPAPI attempts failed and were rerun in the normal-user
tool context. Static style/test-only diagnostic findings were corrected. A widget
fixture initially waited on a fake-clock timer and was corrected to await the
event directly. Packaging required the host PowerShell Utility module imported
in its own process and the extracted license passed from the actual staging
path; the compiled application was reused. These attempts do not constitute OS
delivery failures or successful physical observations.

### Remaining delivery limits and exact next stage

Windows settings, Do Not Disturb, sleep, process termination and crashes can delay
or suppress notifications. Successful submission is not proof of presentation or
sound. Already submitted notifications can remain in Windows history after a
crash. Remote event moves/cancellations are known only after successful refresh;
stale/failed data suppresses reminders rather than claiming a current schedule.
No reminder backlog is replayed when data, settings or the process recover.

**Installed toast presentation/actions, actual DND/denial, physical lock/unlock,
S3 sleep/hibernate and live Google/event comparison remain unrun.** Earlier
physical tray/Explorer/display/accessibility/startup/clean-install gates remain
open. iOS/Xcode and a new physical Android campaign were not run. Follow the
Google setup guide for owner configuration/consent and harmless disposable test
events; do not borrow Codex credentials. Coordinate one operator for any future
physical desktop walkthrough, preserving the earlier observation limits.

Session 8 stops here. The exact next stage is **Session 9: risk-based reliability,
privacy and regression acceptance**, using these exact source/build identities and
recording installed-owner observations separately. Signing/trust/installation and
public distribution remain their explicit existing gates; no event writes or new
features are authorized by this handoff.

## 14. Session 9 — resilience, privacy and mobile regression acceptance

### Completed engineering work

- Created [Windows Calendar acceptance](WINDOWS_CALENDAR_ACCEPTANCE.md), with
  reproducible steps, expected/actual outcomes and separate automated, isolated
  runtime and owner-observed sections. All O01–O14 owner cases remain unrun.
- Added ten focused regressions for combined late-response/format/receipt races,
  account replacement, reset/disconnect, queued cache writes, paginated partial
  failure, GET-only requests, HTTP-date rate limits, offline tasks/history/timer
  use during stalled credentials, and cleanup failure/retry.
- Reproduced one product defect: failed calendar credential deletion in full
  reset misleadingly reported only local-alert cleanup. Both initial failure
  and Retry now report remaining local data; cleanup/reconnect behavior is
  unchanged and is verified by the new regression. No API/schema/dependency,
  timer-domain, scope or event-operation change was introduced.
- Updated architecture, privacy policy/review and bundled Windows disclosure,
  local retention, dependencies/licenses, notifications, release/installation
  guidance and README to actual platform behavior. Windows resident refresh is
  explicit; receipt pruning occurs on saves and no expiry service runs after Quit.
- Preserved all unrelated working-tree files, all 81 Android/iOS/metadata inputs,
  the lockfile and historical signed 2009/offline ZIP, final 2011 and 2016 packages.

### Actual checks and bounded observations

Evidence: [Session 9 review](../artifacts/windows/calendar-session9/REVIEW.md),
[machine record](../artifacts/windows/calendar-session9/review.json), and
[acceptance](WINDOWS_CALENDAR_ACCEPTANCE.md).

| Check | Actual result / limit |
| --- | --- |
| Flutter regression | **302 passed**, including ten new resilience cases; baseline 292 also passed before additions. Existing strict/stale controls, deduplication, durability/process-crash, recovery and manual successors remain included. |
| Native/configuration | **211 native Windows checks** including actual isolated DPAPI and **11 build-configuration checks** passed. These do not certify installed desktop or Google behavior. |
| Static/format | Analysis clean; 82 Dart files checked, zero changes; whitespace validation passed. |
| Android | Post-fix ARM64 debug build and **eight native unit tests** passed. SQLite ARM64 native asset present. Mobile remains `1.0.0+2007`; no physical campaign or installation ran. |
| Windows production | Normal entry point, one-worker release **1.0.0.2017** compiled. Final unsigned MSIX verifies complete payload hashes, x64 runtimes/AOT, identity, disabled startup and required notices. It is unconfigured for live Google and was not installed. |
| Isolated runtime | Five secondary launches exited zero with the same sole owner. Twenty-four CPU/memory samples compare disconnected and synthetic-calendar visible/hidden states; a six-minute hidden interval observed one list/two event reads and three cache writes with ticker off. Resource figures are descriptive, with instrumentation/background-tool limits. |
| Hidden expiry | Separate awake 70-second probe: original run/deadline completed once, Short break Ready, ticker off and one native calendar-deadline probe. Two timer callbacks/repeated reconciliation did not duplicate history. Unpackaged notification capability was unavailable. |
| Disconnect/Quit | Isolated disconnect removed account documents and protected credentials, leaving only the non-personal disconnected marker. Process exited after normal Quit; its exit code was not captured and remains unknown. Initial/corrected sampler metadata are both preserved. |
| Bounded privacy/license inspection | All **58 package members / 37,899,341 uncompressed bytes**, 26 selected logs and calendar/native logging paths checked: no selected credential/private/review markers, private configuration/development payloads or app-owned logging calls found. Locked package/runtime notices present. No personal event content was loaded. |

Initial script-policy/SDK-cache/DPAPI access attempts, a fixture identity assertion,
two helper style diagnostics and Android informational-stderr handling are recorded
separately. Normal-user tests passed without weakening credential ACLs or machine
policy. The reset-message defect has its own failing-before/passing-after record.

### Final source and artifact identity

Checkout remains `codex/poma-offline-release`, HEAD
`cb8b1a1e3f5a376b0121ead5328bb51fbcdc5679`, with preserved uncommitted work.
Final implementation inventory: **256 inputs**, SHA-256
**`d34810a6bbddd1e79b76736fe260a644c555b2bc93c0b8373bde448b069ec6f4`**.

- [Unsigned verification MSIX](../artifacts/windows/Poma-1.0.0.2017-session9-final/Poma-1.0.0.2017-x64.msix):
  **`618bab9bec69787b33d84ca3e3b698ff0696b04b688a1e836cb5ff1b4d115325`**.
- Executable: **`fa70adb93f0a843ea143bdbd3b32fa3d58427f7bf67488384967be8ff57c98a7`**.
- AOT: **`ba949eb52b6104aedfa83eaae0bf2693a6214b2bb8156bbfff6e75ec5340b395`**.
- Lockfile: **`e2e9b87d0bbec8e9c37beb04b98604537afa7c3c8b5ca0242adf441581891f8d`**.

The earlier isolated review binary has its own input/payload hashes; it precedes
the final reset-error wording and two helper style fixes. Final packing reused
the unchanged compiled production application after a sampler-only correction;
the auditor checks every compiled mobile input against the compilation inventory.
Both preliminary and final packages remain preserved. No review-only controls or
synthetic tokens/event markers are present in the production package.

### Remaining gates and exact Session 10 handoff

Engineering Session 9 is complete; **private-pilot acceptance is not complete**.
Owner cases O01–O14 name the procedures and owner. Live Poma Google setup/consent,
actual Testing expiry/revocation/account/event comparisons, signed/trusted
installation, clean user/standalone/upgrade, Explorer/tray/physical displays and
scales, Narrator/high contrast, lock/sleep/hibernate, enabled/disabled startup at
sign-in, and installed toast/DND/denial/actions remain unrun. iOS/Xcode and physical
mobile checks could not run in this Windows host campaign. No live credentials
were borrowed from Codex, no event write occurred, and no Windows preference,
trust, signing, installation, publication or public distribution changed.

```text
Complete Windows Calendar Session 10 in D:\pomodoro only when requested. Read
RTK.md, the plan/specification/setup, Session 9 acceptance/review and this handoff.
Preserve existing working-tree work, read-only scopes, one timer/database owner,
account/lease cleanup, skip-missed reminders, original package identity/certificate
and every unresolved owner gate. Do not add features or remote event writes.

Prepare a complete private MSIX pilot with a higher Windows version than
1.0.0.2017 (use 1.0.0.2018 if still unused). MSIX identity is required by the
implemented notification transport. Include all audited runtime/native/database,
legal/license and installation files; never distribute a lone executable.

Session 9's final unsigned verification artifact and exact hash are linked above;
it is not an installed/signed/live-Google acceptance result. Obtain owner readiness
and curated configuration/consent for live tests. Configuration requires a fresh
compilation, never SkipBuild. Keep credentials/private configuration out of source,
artifacts and diagnostics. Do not change trust or install silently.

Bind final source/build/package hashes and preserve identity/certificate for
upgrade. Coordinate one operator for O01–O14. Record installed path/modules,
clean launch, live authorization/selection, hidden notifications/actions, startup,
offline restart, cleanup, upgrade, Quit and remaining accessibility/hardware gates.
Close only actually observed checks. Produce private-pilot notes and the owner
checklist. No store/public distribution, signing-service purchase or optional
focus-block writing is included. Stop after the private-pilot handoff.
```

## 15. Session 10 — configured private Windows pilot, installed acceptance pending

Prepared 28–29 October 2026, Asia/Calcutta. **Complete signed packaging is ready;
the installed/live walkthrough is not complete.** The owner supplied matching
Desktop-client JSON and curated configuration at their private Setup directory.
Actual names have `.json.json` suffixes; both parse, match and declare
`external_testing`. Values were not displayed; private input files are not in
the artifacts. Saving JSON cannot configure an existing executable.

### Final complete artifacts

- [Complete private pilot ZIP](../artifacts/windows/Poma-1.0.0.2019-session10-pilot-final-private-pilot-kit.zip)
  — **15,983,960 bytes**, SHA-256
  **`2945ada6e8379773a5bf101fc5b736d6ef42f50bf8a94269b36136a513005b58`**;
  [checksum](../artifacts/windows/Poma-1.0.0.2019-session10-pilot-final-private-pilot-kit.zip.sha256).
- [Complete local folder / installation guide](../artifacts/windows/Poma-1.0.0.2019-session10-pilot-final/INSTALL.md),
  with [signed final MSIX](../artifacts/windows/Poma-1.0.0.2019-session10-pilot-final/Poma-1.0.0.2019-x64.msix)
  — **1.0.0.2019**, **15,845,077 bytes**, SHA-256
  **`e4655487877719a7db47244e4e2e0ab3a7437e27c823e0465a8529a7bcd3e86b`**.
- [Pilot release notes](WINDOWS_CALENDAR_PILOT_RELEASE.md),
  [owner's final checklist](WINDOWS_CALENDAR_PILOT_CHECKLIST.md), and
  [updated acceptance](WINDOWS_CALENDAR_ACCEPTANCE.md).
- [2018 upgrade rehearsal](../artifacts/windows/Poma-1.0.0.2018-session10-rehearsal2/Poma-1.0.0.2018-x64.msix)
  — SHA-256 **`9c788386399a979c3e539d4785b3478fac2124614a9b4f70d7605e6bd651ab4b`**.
  Install first only for the planned upgrade. The incomplete first rehearsal
  folder and `Poma-1.0.0.2019-session10-pilot` are superseded intermediates.
  Do not install the intermediate 2019 package: final has the same Windows
  version and cannot upgrade it in place.

The final folder/ZIP include the complete signed runtime/assets/icons/licenses,
public certificate/fingerprint and client summary, privacy/installation/cleanup
instructions, release notes, owner checklist, source/payload inventories, public
audits, verification and recursive checksums. No original setup files, signing
keys/passwords, tokens, calendar cache, databases, PDBs or review controls occur.

### Actual work and evidence

MSIX is required by the implemented reminder transport, which reports capability
unavailable unpackaged. Identity `JyotirmaySingh.Poma.Desktop`, publisher
`CN=Jyotirmay Singh`, application `Poma`, toast activator, tray GUID and initially
disabled `PomaStartup` are retained. Existing certificate SHA-256 is
`1CDE2CB78DFABF389C59475EB3684E4837D81AEFADB3723992B02402D328E955`.
No paid signing service, timestamp, automatic trust or installation was used.

Fresh configured normal-entry-point builds of 2018 and final 2019 passed with
one worker and unchanged toolchain. Packaging emits a public client summary;
finalization accepts pilot-specific notes/checklists, avoiding the legacy
offline-only text/test counts. Scripts explicitly import the running
PowerShell's own modules to fix the demonstrated inherited-module-path failure
without machine changes. The new `scripts/verify_windows_pilot.py` audits signed
payloads, public configuration, licenses, privacy markers and archive completeness.

Final MSIX: **61 members / 37,906,954 uncompressed bytes**, all **56 inventoried
hashes** verified; thirteen x64 PE files plus AOT, package-local SQLite/CRT,
icons/notices, read-only scopes and disabled startup verified. All **20 kit files**
match the ZIP; Verify-Kit passed checksums/signer comparison. Bounded privacy
scan: **80 files / 39,466,962 bytes**, no selected token/key/private/review marker
findings. These are static checks, not installed/runtime or all-secret proof.

**11 current configuration checks** and syntax/whitespace checks passed. All
**209 application inputs**, lockfile, mobile `1.0.0+2007` and Session 9 MSIX are
unchanged. Final source digest is
`666305d4dcd0c84bf68efc4c171b67d783c88e5032f8f7c6462ee47ec8dec8e4`;
all inventoried final inputs match current files. Historical 302 Flutter / 211
native passes retain Session 9 identity; no new mobile campaign is claimed.

Evidence: [final kit audit](../artifacts/windows/calendar-session10/final-kit-audit.json),
[preservation](../artifacts/windows/calendar-session10/source-preservation.json),
[environment](../artifacts/windows/calendar-session10/environment.json),
[kit verification](../artifacts/windows/calendar-session10/kit-verification.log),
[trust diagnostic](../artifacts/windows/calendar-session10/signature-chain.log),
[config checks](../artifacts/windows/calendar-session10/config-check-final.log).
Build/sign logs and attempts remain adjacent. The initial build compiled but
packaging lacked Get-FileHash; the initial auditor incorrectly demanded unused
googleapis notices. Both tooling issues were corrected. The final package was
freshly assembled with the corrected audit source inventory.

### Owner handoff and remaining checks

Read-only owner-account queries found **zero installed Poma packages and zero
running processes**; no targetable Poma window existed. This explains the report
that Settings could not be opened. No Settings product defect has been reproduced.
The owner received the signed 2018 installer, public certificate/fingerprint,
Trusted People instructions and Start → Poma → Ctrl+4 directions. **The owner
review/trust/installation response is pending.**

Current SignTool verification exits 1 because the self-signed chain terminates
at an untrusted root; Windows reports UnknownError before trust. Both Trusted
People stores initially lacked the certificate. This is not a trusted-signature
pass. Do not silently import certificates, use Trusted Root or weaken policy.

Continue with the [final owner checklist](WINDOWS_CALENDAR_PILOT_CHECKLIST.md):
owner review/trust and 2018 install; standalone Start/Settings and actual installed
module/package/data paths; owner Google login/MFA/consent/loopback; explicit
harmless source selection; credential restart; tray/one instance/focus persistence;
hidden timer/meeting reminders; Quit/disconnect/reconnect; closed-profile backup;
2018 → **final** 2019 upgrade; final identity and real offline restart. Record
each version/hash/result without tokens, callback URLs or personal event text.
Owner replied “working” to the test-calendar question; this establishes no event
readiness/live comparison. Clarify source choice at selection if needed. Do not
create/change remote events to stage a reminder test.

Current owner account is the chosen environment. Clean Windows user/machine
checks are **unavailable/unrun**: no usable Windows Sandbox, Hyper-V management
or VirtualBox tooling was found and no new profile/VM was created. Other
Explorer/monitor/scale/Narrator/high-contrast/startup/lock/sleep/DND/denial,
real revocation/seven-day Testing expiry and wider event/account comparisons
retain their O01–O14 gates. Synthetic/automated checks do not close them.

Notes/INSTALL identify actual-family LocalState, `databases\poma.db`, protected
`calendar\connection.dpapi`/retired identity, unencrypted account state/reminders,
the separate development root, Disconnect/retry, stopped-profile calendar-only
removal, offline revocation/Google grant removal, backups, upgrade and uninstall.
No event changes, public release/store distribution, signing-service purchase
or optional focus-block writing occurred. Google production/verification,
public privacy/support, signing/distribution and broader hardware testing remain
separate public-release gates. Stop at the private read-only pilot.

### Installation follow-up — 29 October 2026

Owner reported installation error **0x800B010A** on the signed 2018 rehearsal.
The exact package hash/signer remain correct. Read-only normal-user checks found
the supplied certificate absent from all checked Current User/Local Machine
Trusted People, Root, CA and My stores; signature status reports an untrusted
root chain. The certificate is currently valid. The next concrete step is owner
review/import of the supplied public CER into **Local Machine / Trusted People**
using the certificate wizard, then retry the same MSIX. Detailed wizard steps
were supplied. No certificate/security setting, package or immutable final kit
was changed; installed/live acceptance remains pending.
[Diagnostic](../artifacts/windows/calendar-session10/installation-trust-diagnostic-20261029.json).

### Installed rehearsal continuation — 29 October 2026

The owner completed installation. **2018** is registered under family
`JyotirmaySingh.Poma.Desktop_kz516h6tttq8c`, and signature trust now reports Valid.
Normal registered-app activation launches the installed executable. Focus and
Settings render. All 56 inventoried installed payload hashes match; Flutter,
SQLite, the notification dependency and required C++ DLLs load from WindowsApps.
The real LocalState/database paths have been observed. Current-user notification
capability for the installed AUMID is Enabled; no delivered toast is inferred.

At this cold-launch checkpoint the app shows Disconnected and no protected
connection or calendar account state exists. No persistence bug is established:
the owner's earlier Reconnect/Disconnect button report alone does not establish
successful credential commit. A new Connect Google flow is pending owner browser
sign-in/consent. Poma has one IPv4-loopback-only authorization listener. The agent
does not operate authentication dialogs. Continue after successful actual consent
with selection, credential restart, timer/tray/hidden reminders, Quit, closed-profile
backup, 2018 → final 2019 upgrade and real offline restart. If the current flow
times out, restart it explicitly when the owner is ready; do not borrow connector
tokens or record callback URLs. Existing clean-machine/hardware gates remain open.

See the dated installed-observation section in [acceptance](WINDOWS_CALENDAR_ACCEPTANCE.md)
and the adjacent `installed-2018-*` evidence under `artifacts/windows/calendar-session10`.

The later authorization checkpoint observed the temporary listener closed and
still no protected connection saved. No successful browser return/credential
commit is established. Background accessibility text retained Connecting, so no
specific timeout/provider error is inferred from it. Await the owner's actual
browser completion/foreground status before using the desktop again; restart
Connect Google explicitly if necessary. [Checkpoint](../artifacts/windows/calendar-session10/installed-2018-authorization-checkpoint.json).

## 16. Session 10 continuation — owner offline report, repaired pilot 2020

29 October 2026, Asia/Calcutta. The owner reported an offline connection message
after browser consent on installed 2018. No protected credential/account cache
was saved. Google TCP and unauthenticated Dart HTTPS checks passed; the actual
authenticated failure code is unknown. Calendar API enablement for the owner's
Desktop project remains a required check, not an inferred root cause.

Reproduced and repaired two defects: first-connect network failure incorrectly
claimed saved credentials were retained, and Calendar API identity-check 403/404
refusals were mislabeled offline. The controller now states no new connection
was saved when appropriate; API refusals give safe project/account recovery
guidance. No raw response, token or callback data is exposed. Only
`calendar_connection_controller.dart`, `google_calendar_authorization.dart` and
their regression test changed. Scope/schema/timer/dependency contracts and native
mobile/metadata inputs remain unchanged. **304 Flutter / 28 connection tests
passed**, static analysis clean, format/whitespace checks passed. Both new
regressions failed before the fix; evidence links are in acceptance.

### Current complete local artifacts — 2020 supersedes 2019

- [Complete private kit](../artifacts/windows/Poma-1.0.0.2020-session10-pilot-private-pilot-kit.zip),
  15,985,090 bytes, SHA-256
  **`e9c074c4cf732ab73540e8037eab0ad0f70a26067d0c6d082613ae9cb9152789`**;
  [checksum](../artifacts/windows/Poma-1.0.0.2020-session10-pilot-private-pilot-kit.zip.sha256).
- [Complete folder / INSTALL](../artifacts/windows/Poma-1.0.0.2020-session10-pilot/INSTALL.md),
  with [signed installer](../artifacts/windows/Poma-1.0.0.2020-session10-pilot/Poma-1.0.0.2020-x64.msix),
  15,845,403 bytes, SHA-256
  **`92b6bb6084e4c058eee950122aff7a0064d3b9e5777c22996ccd7fd8ad06c35d`**.
- [Current release notes](WINDOWS_CALENDAR_PILOT_RELEASE.md),
  [owner's final checklist](WINDOWS_CALENDAR_PILOT_CHECKLIST.md), and latest
  [acceptance](WINDOWS_CALENDAR_ACCEPTANCE.md).
- Source input digest
  **`e58035d26beda075d36af1ff85c93b81f7da6684bad05aa305b6069319d69a47`**,
  257 inputs, all matching; [preservation](../artifacts/windows/calendar-session10/source-preservation-2020.json).

Fresh configured normal-entry-point release, same package/publisher/certificate
and client, one worker. Signature now Valid on the owner account; the agent did
not import trust. All 56 payload hashes, x64 AOT/13 PE runtimes, package-local
SQLite/CRT, licenses/icons/public read-only client and disabled startup verified.
All 21 kit files match ZIP; bounded privacy scan has no selected findings across
81 package/loose files (39,468,057 bytes). [Audit](../artifacts/windows/calendar-session10/kit-2020-audit.json),
[verification](../artifacts/windows/calendar-session10/kit-2020-verification.log).
No original config, user credentials, cache/database or signing keys are in the
kit. Historical 2019 artifacts are unchanged and superseded.

**2020 has not yet been installed/live accepted.** The observed registered launch,
installed/module/data paths, signature trust and enabled notification capability
are labeled 2018 only. Core hidden reminders/tray/persistence/normal Quit/upgrade/
real offline restart are still pending. Google browser consent alone has not
produced a verified committed connection/selection. No clean-user/machine result
or physical hardware/accessibility/startup/sleep/policy pass is inferred.

Computer Use ended while attempting the Google Cloud check because Chrome's
current URL could not be confidently verified. No further UI interaction occurred
in that turn; shell-only regression/build/sign/audit work was completed. The
owner was asked whether Calendar API shows Enable or Manage in project
`poma-windows-calendar-pilot`. Do not bypass that browser safety stop or borrow
Google connector tokens. Resume UI work in a later user turn with current window
observations. The owner handles authentication/consent.

Next concrete sequence: confirm Calendar API enabled for the same Desktop client
and account access; Quit 2018 and privately back up the closed LocalState; install
2020 over 2018; retry Google with both read scopes; require actual Connected and
saved protected credentials, explicitly select the harmless calendar; finish
credential restart, tray/one-owner, focus persistence, hidden timer/meeting toasts,
normal Quit and real offline restart. Record final hash/build per case. Keep
remaining owner/hardware cases open. Stop at the private read-only pilot: no
public distribution/store/signing-service purchase, remote event mutation or
optional focus-block writing is included.

## 17. Session 11 — explicit focus-block write specification

1 November 2026, Asia/Calcutta. **Documentation only; optional writes remain
unimplemented and no write permission was requested.** The owner approved the
Session 11 plan. The [write specification](WINDOWS_CALENDAR_WRITES_SPEC.md)
defines the optional Session 12 contract while preserving the existing read-only
pilot, offline timer/tasks/history, account selection, package identity and all
unresolved acceptance gates.

### Owner decisions — confirmed

| Choice | Recorded decision |
| --- | --- |
| Destination | Dedicated Poma-created secondary **Poma Focus** calendar, never the primary/existing planning calendars. |
| Busy/Free | Busy by default; Free selectable for each confirmed block. |
| Management | Explicit title/timing/Busy-Free edits, rescheduling and deletion of verified Poma-owned one-off blocks. |
| Offline | Save a draft; fresh online preview and confirmation required. |
| Reconnection/reset recovery | Offer reviewed recovery of eligible existing Poma blocks; never restore commands, local tasks or history. |

### Delivered design and boundaries

- Wrote `docs/WINDOWS_CALENDAR_WRITES_SPEC.md` with the complete title/task,
  account/calendar, date, timezone/offset, start/end and Busy/Free preview;
  separate consent, calendar setup and event confirmation; ordinary default
  events compatible with personal accounts; and the explicit excluded scope.
- Evaluated `calendar.app.created` against current official Google documentation.
  Its app-created-calendar boundary includes unrelated events users add there
  and is not limited to Poma's ownership markers or one calendar name. Calendar
  resource methods accept the scope too. Poma must enforce its narrower checked
  event boundary; no broad write scope is justified. Live boundary tests remain
  **unrun**.
- Specified fresh Desktop authorization for the complete approved three-scope
  set rather than installed-app incremental authorization. Candidate scope/
  identity/refresh verification and atomic protected credential replacement are
  separate from read connection state. Decline/failure retains a working reader;
  upgrade cleanup must not revoke project grants. Local scheduling disablement
  is distinct from full Google disconnect.
- Defined persistent calendar provisioning markers, stable operation/block/event
  identities, immutable confirmed payloads, account-scoped journals, GET-first
  uncertain-result recovery, ETag preconditions, explicit retries, offline
  drafts, durable lifecycle invalidation and reviewed remote-block recovery.
- Defined W01–W18 automated fault/restart cases and L01–L05 owner-assisted
  personal-account gates before production write implementation. They are
  requirements, **not executed tests or acceptance passes**.

### Session 11 verification and unchanged pilot

Documentation verification covers local Markdown links, required design/test
coverage, whitespace and a before/after SHA-256 comparison of all pre-existing
non-ignored files plus the complete 2020 private-pilot folder and ZIP. Only this
progress document and the new write specification are permitted changes.

**Actual documentation checks passed:** all 59 local Markdown links resolve;
UTF-8, fences, whitespace, required content and W01–W18/L01–L05 matrix checks
passed. The pre-existing session history reconstructs to its original hash after
restoring the two updated summary/handoff paragraphs. Of 318 baseline files,
317 retain their hashes and only this progress file changed; the sole new file
is the write specification. All 22 inspected 2020 pilot files (21 folder files
plus the ZIP) are unchanged, and the kit/MSIX hashes match section 16.

No application test campaign/build, dependency change, credential/configuration
inspection, Google consent, event mutation, installation, certificate trust,
Windows preference change or publication forms part of this session.

The current complete read-only candidate remains **1.0.0.2020**, recorded in
section 16:

- Private kit SHA-256:
  `e9c074c4cf732ab73540e8037eab0ad0f70a26067d0c6d082613ae9cb9152789`.
- Signed MSIX SHA-256:
  `92b6bb6084e4c058eee950122aff7a0064d3b9e5777c22996ccd7fd8ad06c35d`.
- Recorded build input digest:
  `e58035d26beda075d36af1ff85c93b81f7da6684bad05aa305b6069319d69a47`,
  257 inputs; this historical identity is not a new Session 11 build.

**2020 installation/live acceptance, Calendar API/project readiness, verified
Poma credential commit and selected-calendar comparison remain unverified.**
Keep the existing tray/reminder/persistence/upgrade/offline-restart,
clean-user/machine, accessibility, monitor, startup, sleep and policy gates open.
The write design does not establish that the read-only pilot's owner walkthrough
has passed.

### Exact next optional stage — Session 12

~~~text
Implement optional Windows Calendar Session 12 in D:\pomodoro only when requested.
Read RTK.md, the existing Windows-calendar design/setup, this section 17 handoff
and docs/WINDOWS_CALENDAR_WRITES_SPEC.md, especially its section 11 instructions.
Preserve existing work, read-only pilot 2020 and every unresolved owner gate.

Add the specified failure/restart tests before production write handlers.
Implement only explicit one-off focus-block creation and checked title/time/
Busy-Free editing/deletion on the verified Poma Focus calendar. Preserve reading
when write consent is declined; use safe staged desktop credential replacement.
Provision/recover the calendar without blind inserts, persist operations before
sending, reconcile uncertain responses with stable event IDs and protect edits/
deletes with ETags. No automatic offline/restart replay or completion uploads.
Recover existing owned blocks only through user review; never recover commands
or recreate local tasks.

Complete independent synthetic work while owner readiness remains pending.
Only with owner participation, verified exact grants and disposable personal
Google data perform the live boundary/create/edit/delete/recovery checks and
inspect results in Google Calendar. Never borrow Codex connector credentials.
Keep all unobserved tests unrun. Update implemented privacy/setup/scope/retention/
release disclosures, rerun affected read-only/offline/shared/native regressions,
and prepare a separate higher-version private build with recorded identities.
Preserve 2020 artifacts; do not publish or broaden permissions automatically.
~~~

## 18. Session 12 — explicit scheduling implementation

3 November 2026, Asia/Calcutta. The approved write workflow now has independent
consent/capability, staged exact-scope Desktop credential replacement, a verified
dedicated-calendar binding, durable immutable operations and deterministic Google
event IDs. GET reconciliation handles unknown outcomes; owned-block edits/deletes
use fresh snapshots and ETags. Lifecycle invalidation and durable local disablement
stop pending work while preserving remote events. The separate Calendar page
contains focus blocks, operation status and calendar preferences. No general
editor, attendee/recurring writes, automatic history upload or publication exists.

Actual automated checks: 414 complete Flutter tests, 230 native Windows checks,
one real production Windows offline/persistence integration and 11 configuration
checks passed; static analysis is clean. Four child-process exits reopen durable
operation/server state. The isolated development profile was restored after both
attempts; all 22 recorded 2020 pilot files retain their hashes. See
[Session 12 evidence and open gates](WINDOWS_CALENDAR_SESSION12.md).

The owner confirmed Calendar API and a disposable personal test user are ready.
This is readiness, not proof of a saved connection, exact live write grant or
provider resource boundary. No live Google mutation has yet been observed.
Build/sign/audit a separate higher-version private pilot with the existing client,
package and certificate, then perform owner-assisted L01-L05. Do not infer passes
for earlier installed, hardware, policy, startup, sleep or accessibility gates.

Final Session 12 private kit: **1.0.0.2022**, superseding the retained 2021
intermediate candidate. SHA-256 `00da592fec82561f99dd309f2adfee4abdb84bb442725d8811ab6fc5ae1820ec`;
installer SHA-256 `f4ee904a095a120fe0c26b2e6dd737149c958e2f39fc43a57e86e68dcfb8de90`. Final native checks: **233 passed**,
including native account replacement invalidation before Dart acknowledgement.
Kit audit verified all 56 payload hashes and had no selected privacy findings.
2021 was installed/launched and its package-local runtime/saved reader observed;
2022 installed and live write gates are still pending. The installed closed-data
backup succeeded after the 2021 package upgrade, before first launch, following
a helper module error; it is not a pre-upgrade backup. The owner was asked to
confirm the disposable account and exercise declined write consent. No live
focus-block creation or reversal is claimed. No publication or trust change ran.
