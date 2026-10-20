# Poma

An offline Pomodoro app for **Android and iOS**, built with Flutter and SQLite.

Focus sessions, tasks, settings, and history work entirely offline after installation. Data stays in local app storage, subject to the phone's backup settings. No signup or server is required.

## What works now

- Focus, short-break, and long-break timers with configurable durations and cycle length.
- Start, pause, resume, reset, skip, and app-level strict mode.
- Elapsed-time countdown, saved deadlines, and recovery after a process restart.
- Tasks: add, rename, complete, select for focus, and delete.
- Completed focus history, daily totals, and a seven-day view.
- Transactional SQLite persistence, duplicate completion protection, visible save failures, and retry.
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

The starter's 22 automated tests and static analysis passed on the pinned SDK. Android arm64 debug and optimized packages were built locally. Physical-device testing and native iOS compilation remain outstanding. The GitHub workflow checks formatting, analysis, tests, an Android build, and an iOS simulator build.

Build outputs, signing keys, SDK configuration, and local development notes are excluded from source control.

## Architecture

`mobile/lib/domain/` owns the timer and immutable records. `application/` coordinates actions, lifecycle, and serialized saves. `data/` implements the SQLite repository. `ui/` contains the four screens. The domain has no Flutter imports.

The app has no backend or network dependency. [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) describes the clock, persistence, resource policy, and data decisions. Accounts, cloud storage, and syncing are outside the product scope.

## Starter boundaries

This is a working foundation. Native scheduled notifications, notification actions, widgets, special-break schedules, and export/import are not implemented. **There is no alert while the app is closed.** Strict mode restricts controls inside Poma; it does not lock the phone or stop other apps. Time recovery across a restart relies on the device's wall clock; manual clock changes while the process is closed can affect recovery.

Production signing is unconfigured. The launcher icon and application identifiers still need release branding. Finish the device, accessibility, performance, backup/privacy, and signing checks in [docs/RELEASE_CHECKLIST.md](docs/RELEASE_CHECKLIST.md) before distribution.

## Reference and attribution

The mobile implementation was written for Poma, with [Pomatez](https://github.com/zidoro/pomatez) as a feature reference. See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md), the app's license view, and [docs/POMATEZ_REFERENCE.md](docs/POMATEZ_REFERENCE.md) for reference and license details.
