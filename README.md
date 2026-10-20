# Poma

An offline Pomodoro app for **Android and iOS**, built with Flutter and SQLite.

Focus sessions, tasks, settings, and history work entirely offline after installation. Data stays in local app storage. Android declares automatic-backup and device-transfer exclusions; iOS marks the SQLite directory as excluded before opening it. Real-device validation remains pending on both platforms, and the changed iOS integration still needs macOS compilation/tests. No signup or server is required. After installation, the app needs no computer, development server, REA/MCP connection, or AI model.

There is no automatic data recovery after uninstalling Poma or losing the phone. These exclusions do not remove copies that an older version may already have placed in an OS backup.

## What works now

- Focus, short-break, and long-break timers with configurable durations and cycle length.
- Start, pause, resume, reset, skip, and app-level strict mode.
- Sleep-inclusive native elapsed clocks, exact pause/resume, saved deadlines, and recovery after a process restart.
- Tasks: add, rename, complete, select for focus, and delete.
- Completed focus history, daily totals, and a seven-day view.
- Transactional SQLite persistence, duplicate completion protection, visible save failures, and retry.
- Native OS-scheduled completion alerts, permission/settings controls, cancellation, and Open timer / Dismiss actions. Android offers an inexact fallback when precise alarms are unavailable.
- System, light, and dark appearances; screen-reader labels and layouts that accommodate large text.

Each phase starts manually. Leaving the app can complete **one existing session**; it never manufactures a chain of unattended focus sessions. A skipped or reset session does not count. A task is attached when a focus session starts, and its original title stays in history after a rename or deletion.

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
./scripts/flutter.ps1 test
./scripts/flutter.ps1 run -d <device-id>
./scripts/flutter.ps1 build apk --debug
```

Set `POMA_FLUTTER_SDK` to your SDK directory if Flutter is not on PATH. Install RTK before using the helper. RTK is a development helper and adds no dependency to the mobile app.

For iOS, use a **Mac with Xcode** and the Flutter iOS prerequisites. From `mobile/`, run `rtk proxy flutter run -d <ios-device-id>`. Device distribution and store submission require Apple signing.

## Verification

The suite has 96 passing Flutter tests, including scheduling/cancellation, interrupted database/OS updates, permission-flow UI, v1-to-v2 migration, rollback/retry, timer recovery, strict controls and large-text layouts. Six Android JVM tests cover elapsed/reboot and receiver-identity policy. Rendering writes and ticker lifecycle are checked explicitly. CI enforces the lockfile, formatting, analysis, Flutter/native tests, an Android build, and iOS simulator compilation/XCTest. Changed Swift integration and all physical-device notification/clock/backup checks remain unverified until run on macOS and phones. See the [alert protocol and device evidence matrix](docs/NOTIFICATIONS.md) and [architecture](docs/ARCHITECTURE.md).

Build outputs, signing keys, SDK configuration, and local development notes are excluded from source control.

## Architecture

`mobile/lib/domain/` owns the timer and immutable records. `application/` owns the persistence contract and coordinates actions, lifecycle, and serialized saves. `data/` implements SQLite and the local storage policy. `ui/` contains the four screens. The domain has no Flutter imports; the application does not import the data implementation. The entry point wires the layers together.

The app has no backend or network dependency. [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) describes the clock, persistence, resource policy, and data decisions. Accounts, cloud storage, and syncing are outside the product scope.

## Starter boundaries

This is a working foundation. Native local alerts/actions use `flutter_local_notifications` 22.3.2 for permission/settings APIs and app-owned one-shot Android elapsed alarms / iOS interval requests. They require no running Dart countdown, internet, or developer tools after registration. **Actual delivery remains unobserved on both platforms; iOS integration still needs macOS compilation/tests.** Permission, Focus/DND, exact-access revocation, force-stop, reboot and OEM policies can prevent or delay alerts. Android same-boot restoration uses persisted elapsed identity; reboot and iOS process-restoration fallback rely on UTC and can be affected by manual clock changes. Each next phase still starts manually.

Widgets, special-break schedules, and export/import remain unimplemented. Strict mode restricts controls inside Poma; it does not lock the phone or stop other apps. Delivery and force-quit limitations, source references and blocked device cases are recorded in [docs/NOTIFICATIONS.md](docs/NOTIFICATIONS.md).

Production signing is unconfigured. The launcher icon and application identifiers still need release branding. Finish the device, accessibility, performance, backup/privacy, and signing checks in [docs/RELEASE_CHECKLIST.md](docs/RELEASE_CHECKLIST.md) before distribution.

## Reference and attribution

The mobile implementation was written for Poma, with [Pomatez](https://github.com/zidoro/pomatez) as a feature reference. See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md), the app's license view, and [docs/POMATEZ_REFERENCE.md](docs/POMATEZ_REFERENCE.md) for reference and license details.
