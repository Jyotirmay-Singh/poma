# Poma

An offline Pomodoro app for **Android and iOS**, built with Flutter and SQLite.

**Release candidate 1.0.0+2007:** owner IDs, private Android upload signing,
original native icon/splash and offline legal/support screens are prepared.
See [candidate status and open gates](docs/RELEASE_CANDIDATE.md),
[build/install instructions](docs/BUILD_AND_INSTALL.md), and
[store-material drafts](docs/STORE_MATERIALS.md). Build-2006 phone results do
not certify the new candidate. Physical Android connection and Apple signing
access remain required for their respective acceptance gates.

Focus sessions, tasks, settings, and history work entirely offline after installation. Data stays in local app storage. Android declares automatic-backup and device-transfer exclusions; iOS marks the SQLite directory as excluded before opening it. Build-specific validation and remaining phone checks are tracked in [release evidence](docs/RELEASE_EVIDENCE.md). No signup or server is required. After installation, the app needs no computer, development server, REA/MCP connection, or AI model.

There is no automatic data recovery after uninstalling Poma or losing the phone. These exclusions do not remove copies that an older version may already have placed in an OS backup.

## What works now

- A Focus tab showing only the current phase, with a centered countdown and round progress.
- Configurable focus, short-break, and long-break durations and 1–8 focus rounds per cycle; defaults are 25/5/15 minutes and 4 rounds.
- Start, pause, resume, reset, skip, and app-level strict mode.
- Sleep-inclusive native elapsed clocks, exact pause/resume, saved deadlines, and recovery after a process restart.
- Tasks: add, rename, complete, select for focus, and delete.
- Indexed focus history with 50-session Newer/Older pages, daily totals, and a seven-day view.
- Incremental transactional SQLite persistence, v1/v2 migrations, duplicate completion protection, visible save failures, and retry.
- Confirmed session/history deletion and full local data reset, with interrupted alert cleanup recovery.
- Native OS-scheduled completion alerts, permission/settings controls, cancellation, and Open timer / Dismiss actions. Android offers an inexact fallback when precise alarms are unavailable.
- System, light, and dark appearances; screen-reader labels and layouts that accommodate large text.
- Phase-specific start actions and inline completion feedback; current and next task labels, accessible daily totals, and permission-specific alert recovery.
- English localization resources and offline calendar formatting using the device locale and time preference.

A fresh cycle starts in Focus. Completing a focus round displays Short break; completing that break returns to Focus. The configured final focus round displays Long break directly. Finishing Long break resets cycle progress and returns to Focus. Each next phase appears ready and starts when you press its Start button. The Focus tab has no mode selector; durations and rounds are configured in Settings. Returning to the tab or reopening Poma restores the saved phase and progress.

Leaving the app can complete **one existing session**; it never manufactures a chain of unattended focus sessions. A skipped or reset session does not count. A task is attached when a focus session starts, and its original title stays in history after a rename or deletion.

History stays on the phone until explicitly deleted. Settings provides clear-history and full-reset controls; full reset abandons even a strict running phase. After a write failure, further edits can remain in memory with an unsaved warning: they may be lost if the app closes. An unreadable database is never silently deleted or replaced. Export/import is deferred and does not block the core offline release. See [local data, retention and recovery](docs/LOCAL_DATA.md).

## Run

Install Flutter **3.44.2** (Dart 3.12.2), an Android SDK with Java 17, and an Android emulator or connected phone. Run from `mobile/` (the examples use RTK to keep development output concise):

```powershell
rtk proxy flutter pub get
rtk proxy flutter run
rtk proxy flutter analyze
rtk proxy flutter test
rtk proxy flutter build apk --debug
```

On Windows, the optional helper also supports SDK discovery and a short temporary directory for Java build tools:

```powershell
# From the repository root. Uses installed RTK or the local .tools/rtk copy.
rtk proxy pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/flutter.ps1 test
rtk proxy pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/flutter.ps1 run -d <device-id>
rtk proxy pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/flutter.ps1 build apk --debug
```

Set `POMA_FLUTTER_SDK` to your SDK directory if Flutter is not on PATH. Install RTK before using the helper. RTK is a development helper and adds no dependency to the mobile app.

For iOS, use a **Mac with Xcode** and the Flutter iOS prerequisites. From `mobile/`, run `rtk proxy flutter run -d <ios-device-id>`. Device distribution and store submission require Apple signing.

## Verification

Start with the [test completion ledger](docs/TEST_LEDGER.md) and [all 183 named automated results](docs/AUTOMATED_TEST_RESULTS.md). Reuse completed checks for their recorded source/build; a new session or documentation edit does not require rerunning them. Current build 2006 has fresh package, launch, CPU/RSS and attached phone evidence plus operator-reported disconnected focus/break passes. Unverified scopes remain separate release gates.

The 22 October 2026 Focus-screen update passed **163 Flutter tests**, including **29 refinement tests**, plus static analysis and formatting. **38 host-rendered captures** include all three current phases in light/dark appearances at normal and 200% text. See the [changelog](CHANGELOG.md) and [UI verification](docs/UI_VERIFICATION.md) for the behavior, checks, reproduction, and evidence locations.

Earlier release APKs/AAB, package inspection, Motorola G54/Android 15 launch samples, native CI results, and remaining gates are recorded against their source/build identities in [release evidence](docs/RELEASE_EVIDENCE.md). Session 8 build 2006 includes this UI and worker repair; Session 6 packages predate it. Remaining disconnected acceptance, physical iOS behavior, backup/transfer behavior, unplugged energy, production signing, and store sizes require their own observed evidence.

The screen refinement includes a real-SQLite UI close/reopen flow and populated light/dark viewport tests at 100%/200% text. See [screen verification and disconnected phone procedure](docs/UI_VERIFICATION.md) and the [accessibility issue ledger](docs/ACCESSIBILITY.md). Host semantic/layout/contrast checks support the separate TalkBack, VoiceOver, and physical-device acceptance procedure.

The Flutter suite covers scheduling/cancellation, interrupted database/OS updates, permission-flow UI, fixed v1/v2-to-v3 migrations, real SQLite storage exhaustion, process exits before/after commit, rollback/retry, delayed saves, 100,000-row pagination, deletion, timer recovery, strict controls and large-text layouts. Eight Android JVM tests cover elapsed/reboot, receiver identity and native serial-worker ordering/responsiveness. Rendering writes and ticker lifecycle are checked explicitly. CI enforces the lockfile, formatting, analysis, Flutter/native tests, an Android build, and iOS simulator compilation/XCTest. Native build results apply to their identified source snapshots; physical-device notification/clock/backup/offline-restart checks require recorded phone observations. See the [local durability checks](docs/LOCAL_DATA.md), [alert protocol and device evidence matrix](docs/NOTIFICATIONS.md), and [architecture](docs/ARCHITECTURE.md).

Build outputs, signing keys, SDK configuration, and local development notes are excluded from source control.

## Architecture

`mobile/lib/domain/` owns the timer and immutable records. `application/` owns the persistence contract and coordinates actions, lifecycle, and serialized saves. `data/` implements SQLite and the local storage policy. `ui/` contains the four screens. The domain has no Flutter imports; the application does not import the data implementation. The entry point wires the layers together.

The app has no backend or network dependency. [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) describes the clock, persistence, resource policy, and data decisions. Accounts, cloud storage, and syncing are outside the product scope.

## Starter boundaries

This is a working foundation. Native local alerts/actions use `flutter_local_notifications` 22.3.2 for permission/settings APIs and app-owned one-shot Android elapsed alarms / iOS interval requests. They require no running Dart countdown, internet, or developer tools after registration. Delivery observations and native build results are recorded per build in [release evidence](docs/RELEASE_EVIDENCE.md). Permission, Focus/DND, exact-access revocation, force-stop, reboot and OEM policies can prevent or delay alerts. Android same-boot restoration uses persisted elapsed identity; reboot and iOS process-restoration fallback rely on UTC and can be affected by manual clock changes. Each next phase still starts manually.

Widgets, special-break schedules, and export/import remain unimplemented. Strict mode restricts controls inside Poma; it does not lock the phone or stop other apps. Delivery and force-quit limitations, source references and blocked device cases are recorded in [docs/NOTIFICATIONS.md](docs/NOTIFICATIONS.md).

Android release signing now requires owner credentials supplied outside source control;
debug signing is never a release fallback. The owner-ID candidate has original native
icon/splash assets. iOS production signing remains unavailable. Finish the open
device, accessibility, performance, backup/privacy and distribution gates in
[docs/RELEASE_CHECKLIST.md](docs/RELEASE_CHECKLIST.md) before distribution.

## Reference and attribution

The mobile implementation was written for Poma, with [Pomatez](https://github.com/zidoro/pomatez) as a feature reference. See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md), the app's license view, and [docs/POMATEZ_REFERENCE.md](docs/POMATEZ_REFERENCE.md) for reference and license details.
