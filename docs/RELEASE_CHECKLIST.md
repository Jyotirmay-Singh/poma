# Release gates

The current deliverable is a starter. Complete these before a production release.

## Correctness and platform behavior

- Pass timer, controller, database, widget, and migration tests on the pinned SDK.
- Test on real Android and iOS phones: lock screen, background, process kill, force-stop, reboot, timezone and manual clock changes, low-power modes, and permission denial/revocation.
- Native local notifications, cancellation/rescheduling, action deduplication and an explicit Android inexact fallback are implemented. Finish physical-device acceptance in [NOTIFICATIONS.md](NOTIFICATIONS.md); no device delivery has passed, and changed iOS integration still needs macOS compilation/XCTest. Retain SCHEDULE_EXACT_ALARM eligibility review; USE_EXACT_ALARM/store approval is not claimed. iOS does not allow arbitrary continuous background countdown execution.
- Preserve manually started phases. Auto-start chains are outside the confirmed scope; define special-break overlap semantics only if that deferred feature is approved.
- Verify first launch, timer and break controls, local tasks/history/settings, restart recovery, and local alerts in airplane mode. No app feature may require signup or a network connection.
- Test VoiceOver, TalkBack, 200% text, narrow screens, dark mode, landscape, contrast, hit targets, and reduced motion.
- Screen refinements have host widget/SQLite flow and named viewport coverage; retain the open physical checks in [ACCESSIBILITY.md](ACCESSIBILITY.md) and execute [UI_VERIFICATION.md](UI_VERIFICATION.md) on disconnected standalone installations. The native integration entry point is not proof of those checks and remains unrun without devices.

## Data and privacy

- Explicit v1/v2→v3 migrations, incremental transactions, indexed pagination, failure fixtures and local retention/deletion are implemented. Keep [LOCAL_DATA.md](LOCAL_DATA.md) current and run the durability suite, including process-exit probes, before release.
- Export/import is deferred and must not delay the core offline release. If later promised, require a versioned validated format, size limits, duplicate rules and a destructive-conflict preview.
- Verify the implemented backup exclusions on devices: Android legacy/cloud-backup/device-transfer rules and iOS database-directory exclusion (including SQLite sidecars). Native iOS compilation/tests and actual OS backup/transfer behavior remain unverified. Keep the no-automatic-recovery disclosure accurate; an older OS backup is not retroactively removed.
- Review sensitive task content, lock-screen notification privacy, and logs. Do not claim database encryption; none is implemented.
- Keep accounts, backend services, cloud synchronization, remote configuration, and personal-profile collection outside the product scope. Retain settings, tasks, and history locally as requested.
- Verify no secrets, signing keys, debug endpoints, analytics, or unnecessary permissions ship.

## Performance evidence

- Measure an arm64 **release** artifact and store-estimated download size; retain ABI and signing details. Debug/universal sizes are separate.
- Profile launch, frames, RSS, CPU and energy on named physical devices. Record OS, sample count, commands, and baseline.
- Check idle/background work: no polling, no unnecessary wake locks, and no busy foreground service.
- Use REA/archive inspection to verify packaged assets and dependencies where appropriate; static inventory is not a runtime benchmark.

## Distribution

- Replace the development bundle/application identifier with one the owner controls.
- Create a real upload keystore outside source control and configure Android release signing. Release builds must not inherit debug signing.
- On macOS, verify iOS compilation, deployment target compatibility, SQLite integration, entitlements, signing, and TestFlight installation.
- Prepare name/icon/splash assets, version numbers, privacy policy, accurate App Privacy/Data Safety responses, screenshots, support details, and notices.
- Run CI on Android and an iOS simulator, then perform real-device smoke tests.
- Submit or publish only after the owner authorizes the concrete release and supplies required store access.
