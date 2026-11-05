# Windows desktop acceptance

This is an evidence ledger, not a claim that compilation completes the release.
Initial support scope: Windows 11 25H2 x64. Base source is
`cb8b1a1e3f5a376b0121ead5328bb51fbcdc5679` plus the implementation working tree.
Final package identity, source-input digest and SHA-256 are in
[the release record](WINDOWS_DESKTOP_RELEASE.md). Mobile evidence retains its
original source/build and device scope.

## Automated observations, 24 October 2026

| Check | Observation / evidence |
|---|---|
| Shared Flutter regression | **193 tests passed**; `artifacts/windows/flutter-tests-2008.json`. Includes timer/controller, strict controls, pause/resume, migrations, FULL rollback, unreadable/future-schema retention, unique completions, process exits before/after commit, mobile semantics/layout and desktop cases. |
| Final desktop refinement | **27 tests passed** covering early hidden callback re-arming, resume before expiry, hidden expiry with alerts disabled, post-commit delivery, duplicate events, retry, cold recovery without toast replay, break completion, reset invalidation, failed-save Quit, real SQLite preferences, Windows-only channels, keyboard entry, populated table and 640/1080/1440 widths with 100/200% text in both appearances. `artifacts/windows/desktop-tests-2009.json`. |
| Native coordination | **56 checks passed**, including epoch/clock units, monotonic advance, top/bottom/negative-coordinate geometry, malformed action rejection, Unicode forwarding, single ownership, secondary IPC, immediate/blocked-read shutdown and COM activation. CTest log: `.tools/windows-native-tests/Testing/Temporary/LastTest.log`. These are automated host checks, not tray-placement or real-sleep observations. |
| Windows release build | Pinned Flutter 3.44.2 / Dart 3.12.2 and installed VS 2019 v142 / SDK 19041 successfully compile the runner and SQLite native asset. No Flutter upgrade, ATL installation or Developer Mode change was needed. |
| MSIX assembly | MakeAppx validates manifest/resources and creates the x64 package. Static audit covers the x64 PE binaries, ELF64 x64 Dart snapshot, assets, notices and application-local CRT. No package dependency/runtime download is declared. |
| Signing | SignTool signs the MSIX using file-based private material outside the workspace. Public CER matches the package signer. Before owner trust, SignTool reports an untrusted self-signed chain; this is not an observed trusted installation. No private key is distributed. |
| Final static checks | Analysis: no issues. Formatting: 53 files checked, zero changes. |
| Affected Android checks | ARM64 debug build and **8 native unit tests passed**, with the promoted production FFI asset present as `libsqlite3.so`. `artifacts/windows/android-compatibility-2008.json`. The initial build exhausted memory; a single-worker, 1 GB heap retry with the short temporary-path workaround succeeded. No phone installation or old campaign repeated. |
| iOS checks | Windows cannot compile/run Xcode/iOS checks. Existing macOS CI remains configured; it was not dispatched or claimed passed for these working-tree changes. |

The initial regression run had six failures: four mobile semantics regressions
from grouping the Focus sliver children, and two crash-fixture failures due to
omitted assets. The mobile layout was preserved and the child fixture now copies
all declared assets. The full 193-test run passed after those repairs. A later
desktop-only resume re-arming refinement has its own focused report.

Native checks initially could not reopen restricted same-user objects inside the
execution sandbox. They passed outside that sandbox with the normal user token;
no ACL weakening or machine configuration workaround was introduced.

## Desktop observations and limits

The unpackaged release was launched on this host and its Focus window and desktop
Settings were observed. Dark appearance, navigation rail, numeric timing controls,
desktop behavior wording and accessible control exposure were visible. This uses
the separate development data directory, not an installed profile.

Computer Use screenshots and Flutter accessibility trees sometimes disagreed
immediately after an input; cached edit indexes failed, and duration typing could
not be confirmed reliably. **Do not call unconfirmed typing, keyboard, tray,
timer-expiry or notification interactions passed.** Automated widget checks support
those code paths but do not replace owner observations. A short visible-process
resource/module sample is in `artifacts/windows/runtime-visible-development.json`;
it included desktop probing and establishes no idle/performance threshold.

The **2008 signed MSIX** was extracted to `.tools/windows-package-smoke-rc6` and
launched there without installation. Its accessibility tree reached Focus / Ready
and SQLite opened. Loaded-module evidence shows the engine, SQLite, notification
dependency and required VC runtime DLLs resolving from that extracted folder,
including VC 14.29.30139. No build-directory DLL was loaded. This confirms removal
of the development native-assets manifest did not break runtime resolution on
this host. `artifacts/windows/runtime-extracted-package-rc6.json` records the paths.
Its 1.09-second zero-CPU sample is too short for a performance claim. Capture was
black on that final fixture despite the live accessibility tree; no visual pass
is claimed from that capture. The read-only startup fixture was then terminated
so it could not intercept an installed launch; it was not used to test crash recovery.

## Owner checklist — record observations for the signed package

Use the kit's `INSTALL.md`. You review/trust the public certificate and install
the local MSIX; no coding is required. Record package SHA-256, OS/build, display
scales, date, result and any anomaly. Use a fresh standard-user profile or a clean
Windows VM for the standalone check. Keep development tools closed and disconnect
the network only when you are ready; restore your normal connection afterward.

| ID | Procedure and required result | Status |
|---|---|---|
| W01 | Compare certificate fingerprint, trust only that certificate in Trusted People, install the local MSIX as the intended standard user. Launch from Start offline with development tools closed. All core screens open without downloads. | Pending owner |
| W02 | Add/select/rename a sample task, change duration/appearance, Quit and reopen. Values persist. Start a focus, rename the task, complete it: history retains its original title. | Pending owner |
| W03 | Set focus and short break to 1 minute. Choose the in-app alert preference. Start Focus, hide all Poma windows, wait 75 seconds and reopen: exactly one history row, Short break Ready, no unattended chain. Repeat once with completion alerts off. | Extracted 2009: one-minute focus expired while hidden with alerts off, exactly one completion and Ready five-minute break; installed cases pending |
| W04 | Start, Pause, wait, Quit and reopen: paused remaining time is unchanged. Resume: same run, correct remainder. Start strict mode: main/popup/tray restrictions match; Quit remains possible. | Extracted 2009: break pause/normal Quit/reopen and same-run Resume passed; installed and strict-mode comparisons pending |
| W05 | With a sufficiently long focus, enter S3 sleep and resume before deadline: sleep counts, the hidden deadline re-arms correctly. Repeat across expiry; one completion/Ready successor. Repeat using hibernation. Poma must not wake the computer. | Pending owner |
| W06 | After confirming ordinary saves, terminate the process using Task Manager. Reopen running/paused/overdue states. An overdue focus appears once at the saved deadline; no catch-up toast. Do not test on irreplaceable unsaved data. | Extracted 2009: forced process termination/reopen recovered a running break with the same run/deadline and elapsed time applied; installed and overdue-focus cases pending |
| W07 | Launch Poma several times rapidly, including while hidden: one sustained Poma owner, one tray icon and the existing window opens. Startup/notification relays are transient. | Extracted 2009: five extra launches exited successfully, same sole owner and existing window reopened; installed activation/tray-icon count pending |
| W08 | Left-click tray toggles one compact popup; right-click exposes valid phase actions, Open, Settings and Quit. Escape/outside activation dismisses it. Main/popup agree. Close explains tray residency once. Disable close-to-tray and verify Close quits. | Extracted 2009: Settings popup entry, matching Ready state, outside dismissal, first-close explanation and normal Quit passed; tray clicks/menus, popup keyboard and Close-to-Quit pending |
| W09 | Move the tray icon between visible area/overflow, test available displays at 100–200% DPI/text, negative monitor coordinates, auto-hide taskbar, display changes and Explorer restart. All windows remain reachable; the icon returns after Explorer restarts. Record unavailable hardware. | Pending owner |
| W10 | Allow notifications, hide Poma and complete a phase. Observe toast/sound and Open/Dismiss. Neither starts a phase. Try stale/repeated actions, Windows denial and DND. Preferences must survive launches. Quit/reset clears Poma alerts; no new alert after Quit/termination. | Pending owner |
| W11 | Startup defaults off. Enable explicitly, sign out/restart and observe tray startup; disable and repeat. If Windows disables it, Poma reports the actual blocked state. Full reset also disables startup. | Pending owner |
| W12 | Keyboard-only navigation, Ctrl+1–4, Ctrl+N, text editing, Escape, visible focus, Narrator, both appearances and high contrast remain usable. Long titles and enlarged text wrap; popup controls can be reached when scrolled. | Pending owner |
| W13 | After a closed-profile backup, install a higher-version package with identical identity/publisher/certificate: tasks, settings, history and timer identity remain. Uninstall only after acceptance/data-retention review. | Pending owner |
| W14 | Save failure/full-storage and unreadable-profile error show Retry without silent replacement or false success. Use isolated test data or automated fault tests; preserve any failed profile. Native cleanup can retry. | Automated storage cases passed; packaged fault scenario pending |
| W15 | On a clean profile, inspect loaded modules: app binaries/SQLite/CRT resolve from the package or Windows. Measure settled visible/hidden behavior, check no periodic hidden renders/writes and no app network activity. Document observation method and limits. | Extracted 2009: required runtime modules resolve locally; clean-profile/installed and rendering/write/network measurements pending |

Do not mark sleep, hibernation, installation, upgrade, DND, Narrator, real monitor
placement or offline standalone behavior passed from mocks, source review or old
phone campaigns. A fix changes the package hash; repeat only its affected checks
on the replacement candidate and preserve the earlier failure record.

## Candidate 2009 refinement

The final candidate is 1.0.0.2009. Native main-window focus forwarding now runs
only on activation, allowing the independent popup to retain keyboard focus.
Settings also offers Open compact timer, which does not create/start another
timer. The affected 27-case desktop suite, analysis and formatting pass. The
initial 2009 unpackaged application reached Focus / Ready in the accessibility tree;
black captures/input-targeting limitations prevented a real popup/keyboard pass.
Those initial limits are superseded only by the specific follow-up observations
below. The preceding extracted-runtime module evidence retains its 2008 scope.

## Final-candidate follow-up — 24–25 October 2026

All observations below use the files extracted from MSIX SHA-256
`2f6d11c245111446c14d663f3fb2950753c87ffc637c932c5a458df252424803`.
They use the separate development profile on this host, with Windows awake.
No installed package was found by a fresh current-user query. No certificate
trust, installation, notification permission or startup change was performed.
The closed development profile was backed up before the test.
The aggregate record is `artifacts/windows/continuation-2009-20261024.json`;
it records the rechecked host as Windows 11 25H2 build 26200.9711 x64 and
includes hashes for the individual JSON evidence files.

| Observation | Evidence and precise scope |
|---|---|
| Candidate integrity | MSIX and ZIP hashes match the release record; all 220 inventoried source inputs match; recursive kit checksums/public signer matching pass. The inherited tool module path required process-local imports of Windows PowerShell's own Utility/Security modules. The certificate chain remains untrusted. |
| Hidden completion | A one-minute focus started at `18:20:46.347543Z`. All Poma windows were hidden at `18:21:25.821Z`. Before any relaunch, a read-only database observation at `18:21:58.378430Z` found exactly one 60-second completion ending at `18:21:46.347543Z` and Short break Ready with 300 seconds. Alerts were off. `artifacts/windows/hidden-expiry-2009-20261024.json`. |
| Repeated launches | Five actual extra processes all exited successfully; the same original Poma owner remained the only running Poma process. The existing main window reopened and still showed one focus completion and the Ready break. `artifacts/windows/repeated-launches-2009-20261024.json`. This does not count tray icons or exercise package activation. |
| Main/popup presentation | Dark main window, numeric one-minute duration entry, first-close tray explanation, Settings → Open compact timer, matching native Ready-break display/action labels and outside-activation dismissal were observed. Popup focus initially rested on Start. No phase started merely by opening it. Real tray clicks, keyboard-only popup control and physical placement remain unobserved. |
| Paused restart | Normal Quit left no Poma process. Reopening showed Short break Paused; exact stored remainder `294314492` microseconds and the full paused snapshot were unchanged. Resume retained its run identity. `artifacts/windows/pause-before-restart-2009-20261024.json`, `pause-after-restart-2009-20261024.json` and `resume-after-restart-2009-20261024.json`. |
| Forced termination | Only the verified test process was intentionally terminated after its resume save. Reopening showed the running break with the same run and UTC deadline, less remaining time and still one focus history record. `artifacts/windows/terminated-fixture-2009-20261024.json` and `crash-recovery-2009-20261024.json`. This does not cover an overdue focus, power loss or installed activation. |
| Final runtime files | Flutter, SQLite and required app-local VC runtime modules loaded from the extracted 2009 directory; no module loaded from the development build directory. `artifacts/windows/runtime-extracted-package-2009-20261024.json`. The visible 10.06-second and hidden 10.09-second samples measured about 1.40% and 2.17% of one CPU core respectively. They are short, uncalibrated host samples, not performance thresholds; they do not measure rendered frames, database writes or network traffic. The hidden sample is `runtime-extracted-hidden-2009-20261024.json`. |

Computer Use's cached Flutter accessibility indexes, modifier-key shortcuts and
Unicode text injection were unreliable. Coordinate clicks, selecting numeric
text visually and ordinary number-key input worked. General typing, Ctrl+1–4,
Ctrl+N, keyboard-only use, Escape and Narrator still require direct owner checks;
this session does not classify those injection failures as application failures
or passes. Application sources/binaries were unchanged, so existing automated
results were not rerun without a new implementation change.

After recovery checks, the test break was paused and the application exited
through normal Quit. A final process query found no Poma process. The test
profile backup is `.tools/windows-acceptance-20261024/development-before`.
Do not reuse old fixture process IDs or silently substitute extracted-file
results for the W01–W15 installed acceptance gates.
