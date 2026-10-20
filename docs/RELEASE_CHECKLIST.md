# Release gates

The current deliverable is a starter. Complete these before a production release.

## Correctness and platform behavior

- Pass timer, controller, database, widget, and migration tests on the pinned SDK.
- Test on real Android and iOS phones: lock screen, background, process kill, force-stop, reboot, timezone and manual clock changes, low-power modes, and permission denial/revocation.
- Implement native local notifications, cancellation/rescheduling, and action deduplication. Test Android's exact-alarm restrictions and Play eligibility; provide an honest inexact fallback. iOS does not allow arbitrary continuous background countdown execution.
- Decide auto-start and special-break overlap semantics before adding those features.
- Verify first launch, timer and break controls, local tasks/history/settings, restart recovery, and local alerts in airplane mode. No app feature may require signup or a network connection.
- Test VoiceOver, TalkBack, 200% text, narrow screens, dark mode, landscape, contrast, hit targets, and reduced motion.

## Data and privacy

- Add explicit migrations and failure-injection fixtures. Avoid full-history rewrites and unbounded in-memory loading.
- Implement export/import and validation if promised, plus data retention and deletion.
- Decide Android Auto Backup/iCloud backup behavior and disclose it accurately. Current data is local app storage, with OS backup behavior inherited from platform defaults.
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
