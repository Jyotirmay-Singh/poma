# Screen refinement verification

Updated 21 October 2026. This milestone preserves Flutter 3.44.2, manual phase starts, SQLite v3, the database location/backup exclusions, and the existing native one-shot alert protocol. No account, backend, cloud option, remote asset, downloaded font, analytics or ad dependency was introduced.

## Current-mode Focus screen — 22 October 2026

The Focus screen displays only the current phase in the timer dial. Mode chips and the large-text phase picker are removed, the dial sits directly below the page heading, and the countdown has a larger type size. Purple identifies focus; teal identifies both break phases. The current-phase name remains visible and included in the timer's semantic readout. The text block is measured against the circular inner bounds; enlarged countdowns move below the ring before they crowd its tick marks.

The existing timer prepares a short break after each completed focus, returns to focus after a short break, and prepares a long break after the configured final focus round. Finishing the long break resets the round counter and prepares focus. Every successor waits for Start. Saved phases, durations, controls, strict mode, completion history and alert behavior continue through the existing controller and timer engine.

The updated UI checks exercise one-, three-, and four-round cycles with distinct configured durations, and reject stale Start/Reset/Skip callbacks after completion. The current-phase capture checks exercise a two-round cycle in both themes at 100%/200% text, including phase names, countdowns, Start labels, semantic readouts, contrast, tap targets, and scrolling. Capture output can be redirected with `--dart-define=POMA_SCREENSHOT_DIR=../artifacts/current-mode`; the default remains `artifacts/session-5/`.

Final host result for this update: **163 Flutter tests passed**, including all 29 refinement tests. **38 host-rendered captures** are saved in ignored `artifacts/current-mode/`, with metadata in `screenshots.json` and the complete suite result in `flutter-tests.log`. Twelve captures specifically show the three current phases in both themes at normal and 200% text. The captures were visually reviewed for spacing and legibility; they are supporting host evidence for the phone acceptance procedure below.

Reproduce the current-mode checks and captures from the repository root:

```powershell
rtk proxy pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/flutter.ps1 test --no-pub --dart-define=POMA_SCREENSHOTS=true --dart-define=POMA_SCREENSHOT_DIR=../artifacts/current-mode
```

## Automated functional evidence

Final host results: **150 Flutter tests passed**, **26 capture/refinement tests passed**, six Android JVM tests passed, static analysis found no issues, formatting reported 40 files unchanged, offline enforced lockfile resolution passed, and the fresh Android arm64 debug APK built successfully. There are **26 captures**. Local structured results, final APK size/hash and unobserved-device statuses are recorded in ignored `artifacts/session-5-verification.json`. No new hosted CI or physical-device result is claimed.

`mobile/test/offline_flow_test.dart` drives app widgets against a real temporary SQLite database. It creates and selects a task, starts a one-minute focus, advances an injected elapsed clock, checks one completion and a ready short break, manually starts the break, finds history, changes timing/appearance, and closes/reopens SQLite. It asserts original task/session identity, selection, history, preferences and the still-running manually started break. Native alerts and time are injected substitutes. The host-only no-isolate SQLite factory avoids mixing database fixture work with Flutter's simulated async clock; it does not replace production's native database adapter.

`mobile/test/refinement_test.dart` covers populated screen layouts, keyboard validation/submission, completion notices and task snapshots, strict controls with multiple errors, every alert availability, permission-settings recovery, dated chart semantics, locale/time preferences, hit targets, labels and contrast. Existing timer, durability, process-exit, migrations, pagination, alert protocol and UI deletion tests remain required.

The existing repository failure-injection fixture drains controller aggregate reads before changing schema through its second SQLite connection. Its trigger still forces the real completion transaction to fail and tests rollback/retry; an unrelated external-DDL lock is not the intended failure.

## Captures

Generated evidence belongs under ignored `artifacts/session-5/`; the source tests remain tracked. `screenshots.json` records each capture's viewport, logical dimensions, render scale, device pixel ratio, simulated safe insets, locale, text scale, appearance, reduced-motion state and data setup. These are **Flutter host-renderer captures, not screenshots of physical phones**. SDK-cached Roboto and Material Icons are preview substitutes; the installed app continues using system typography.

| Profile | Logical viewport | Text | Appearance | Insets |
| --- | --- | --- | --- | --- |
| Compact phone | 320×700 | 100%, 200% tested; 200% captured | Light and dark | Simulated 24 top / 24 bottom |
| Tall phone | 390×844 | 100%, 200% tested; 100% captured | Light and dark | Simulated 24 top / 24 bottom |
| Landscape phone | 700×320 | 100%, 200% tested; 200% captured | Light and dark | Simulated 24 top / 24 bottom |

All four screens are captured for the indicated combinations. Additional captures show an actual UI-started focus completion (injected elapsed time) and denied-alert settings with the settings-link action asserted. Standard populated fixtures intentionally include a maximum-duration timer, three tasks including a long title/completed task, and seven real domain session records. Chart values come from the repository/controller, not display-only sample numbers. Small viewports are scrollable; a capture shows only the current scroll position.

Reproduce from the repository root using RTK and the installed Flutter SDK:

```powershell
rtk proxy pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/flutter.ps1 pub get --offline --enforce-lockfile
rtk proxy pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/flutter.ps1 gen-l10n
rtk proxy pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/flutter.ps1 analyze --no-pub
rtk proxy pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/flutter.ps1 test --no-pub
rtk proxy pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/flutter.ps1 test --no-pub --dart-define=POMA_SCREENSHOTS=true test/refinement_test.dart
rtk proxy pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/flutter.ps1 build apk --debug --target-platform android-arm64 --no-pub
```

Use the local RTK path described in RTK.md when it is not on PATH. Native Android JVM tests use the existing process-scoped short TEMP/TMP/Java socket-directory setup; do not change machine execution policy or platform compatibility flags.

## Native integration entry point

`mobile/integration_test/native_offline_test.dart` uses native SQLite, the native elapsed clock and the native alert adapter on a fresh dedicated test installation. It waits for a real one-minute focus, verifies one completion and a manually started break, then reopens storage and checks the saved task/history/settings. Run with `rtk proxy flutter test integration_test/native_offline_test.dart -d <device-id>`. This developer-attached foreground smoke test intentionally disables completion alerts to avoid unattended OS permission dialogs. It is **not** a disconnected delivery or screen-reader test, and remains unrun without hardware.

## Disconnected phone acceptance — not observed

Run on each named Android/iOS phone; install a fresh standalone build first. Android debug APKs can run independently after installation, but their debug/network-tooling permissions are not release privacy/performance evidence. On iOS use a correctly signed profile/release installation; a debugger-dependent JIT session is insufficient. Production signing/publication is separate work.

1. Record artifact hash, build mode/signing, phone model/OS, locale, clock format, theme, text scaling and notification/channel/exact-access settings. Enable airplane mode and explicitly disable Wi-Fi/mobile data. Stop developer tools/servers and disconnect the computer before the following observations.
2. Open Poma from its launcher. Add and select a task. Set focus and short break to one minute. Start focus, choose alerts deliberately, and observe foreground completion. Verify one history entry with the original task and completion instant; the break must remain ready until “Start short break” is activated.
3. Manually start the break. Find the focus in Insights, change appearance/timing settings, close/reopen Poma, and verify task/selection, history, settings and correct timer recovery. A skipped/reset phase must not add history.
4. Repeat focus completion with the phone locked across the deadline. Repeat again with another app in front. Record actual local alert delivery or suppression, latency and wording. Return/open the timer, confirm exactly one completion for each explicitly started focus and a ready successor. Open/Dismiss must never start another phase. Do not infer delivery from a stored history record.
5. Deny/revoke notifications and repeat: timer and history still work, the UI describes the denial, phone settings is reachable, and granting permission is reflected after returning. On Android record precise access versus the delayed fallback. Respect Focus/DND/channel/sound policy; no universal exact delivery or sound guarantee is made.
6. With TalkBack/VoiceOver enabled, navigate all destinations and perform task creation/selection, timer reading/controls, manual next phase, history/dated totals and settings recovery. Confirm meaningful labels/order, selected/disabled states, no per-second announcement chatter and one completion announcement. Repeat narrow/landscape, 200% text, keyboard/IME, safe-area, dark-mode and reduced-motion checks. Record issues in ACCESSIBILITY.md.

Force-stop/force-quit, reboot, power saving, clock/timezone changes, backup/transfer behavior and performance remain the separate release matrix in NOTIFICATIONS.md and RELEASE_CHECKLIST.md. This milestone provides no observed physical delivery, TalkBack, VoiceOver, iOS compilation or store-readiness claim.
