# Release gates

## Main-window calendar schedule

- Confirm the calendar grid and view controls are visible before calendar
  selection at normal text sizes. Unloaded cells must remain explicitly unknown.

- Verify the seven retained dates, Day navigation bounds, overlapping events,
  date-only events, refresh replacement and the read-only interaction flags.
- Check initial setup, no selected calendars, stale/partial/offline data and
  storage failures; an unloaded or unverified date must not imply availability.
- Check details, tooltips and accessible labels disappear on lock, account/scope
  invalidation and deselection. Verify Settings/tray links and Ctrl+1 through
  Ctrl+5 reach their intended destinations.
- Review 640, 1080 and 1440 logical pixels at 100% and 200% text, both themes,
  high contrast and keyboard operation. Keep live Google acceptance separate
  from fictional-data checks. See [Schedule behavior](CALENDAR_SCHEDULE.md).
- Keep upstream repository links, owner names and promotional branding out of
  ordinary UI, README and release descriptions. Preserve package identifiers and
  required copyright/license notices in their technical and legal locations.

## Session 12 private Windows candidate

- Preserve pilot 1.0.0.2020 and its hashes; create a higher-version separate kit.
- Keep initial connection at two read scopes; audit the separate exact three-scope
  scheduling request with `verify_windows_pilot.py --focus-scheduling`.
- Verify DPAPI receipt migration, native commit/journal leases, W01-W18 recovery,
  read-only/offline/mobile regressions, lock redaction and the Calendar page.
- Record L01-L05 separately with owner-operated disposable personal-account consent.
- Include current bundled privacy, scope/setup/retention instructions, complete
  x64 runtime/licenses, signer comparison, source/package/ZIP SHA-256 and evidence.
- Do not publish, import certificate trust, or mark historical owner gates passed.

## Windows Calendar private pilot

Use [Session 9 acceptance](WINDOWS_CALENDAR_ACCEPTANCE.md) and the latest
[calendar handoff](WINDOWS_CALENDAR_PROGRESS.md). Source/fixture, isolated runtime,
package inspection and owner-installed observations remain distinct. Packaging
Session 10 must bind a fresh higher-version artifact to its exact source inputs,
preserve identity/certificate, and retain live Google, clean-profile, upgrade,
physical display/accessibility/startup/sleep and installed-toast gates. No event
writes or public distribution are part of this pilot.

## Owner-ID candidate 1.0.0+2007

Use RELEASE_CANDIDATE.md for current build/check receipts and remaining gates.
Permanent ID configuration, original icon/splash, private Android upload signing,
offline policy/support and store-material drafts are implemented. Store ID
reservation, physical candidate acceptance, startup/device observations,
signed iOS distribution and authorized publication remain evidence gates.
The new release-only CI path verifies unchanged core/lockfile inputs and checks
About/legal/build changes without replaying the 183 baseline tests. No previous
phone, launch, CPU/RSS or migration result is relabelled as a new artifact pass.

Build 2007 now has passed signed APK/AAB verification, the 17.48 MiB ARM64 size
gate, an 8,468,423-byte modeled G54 download, three new focused tests and CI
39820922409 on Android/macOS. The macOS iOS archive is unsigned/non-installable.
See the candidate report for exact hashes and evidence; physical gates remain open.

Complete these gates before a production release. **Read [the test ledger](TEST_LEDGER.md) first.** It closes completed checks for their recorded source/build and supersedes historical pending instructions. Do not rerun tests/builds/measurements for session changes or documentation-only edits. General checklist verbs below describe release requirements, not an instruction to repeat completed evidence; act only on a specifically unverified scope or a justified affected regression.

## Current Android phone continuation — 22 October 2026

See [the current Android acceptance record](ANDROID_ACCEPTANCE_2026_10_22.md).
Build 2006 is installed on Motorola G54 / Android 15. All 165 Flutter and eight
Android native tests passed; current Android/macOS CI passed, including ten
Swift tests and unsigned iOS release compilation. The native UI-thread
contention repair passed immediate strict reset, confirmation across expiry,
durable defaults and native process-death delivery / exactly-once recovery.
Earlier failing builds remain historical evidence. See the current report for
hashes, fresh ABI/AAB inventories, bundletool estimate and measurement scopes.

Empty-history 30 cold / 30 warm launches are measured: usable cold median 504 ms,
within the provisional 1.5-second budget. Large-history 30 cold / 30 warm samples are complete
(usable cold median 481 ms), and eight 40-second state traces are captured.
Frame p95 and matched unplugged energy remain unmeasured.
Locked recovery and large-history full reset passed. The fresh install was opened
online, then the operator reported offline reopen and the disconnected locked-focus/
manual-short-break flow passed, with ready successors and one focus record only.
Do not repeat those flows. Remaining disconnected cases, backup/transfer behavior, licenses, physical iPhone,
production signing and store distribution remain explicit gates.

## Historical initial current-mode Focus verification — 22 October 2026

The latest UI source passed **163 Flutter tests**, including **29 refinement tests**, static analysis, and formatting. The **38 host-rendered captures** include all three phases in light/dark appearances at normal and 200% text. See the [changelog](../CHANGELOG.md) and [UI verification](UI_VERIFICATION.md) for the current flow and exact reproduction.

This initial UI snapshot is superseded by build 2006 and its current ledger entries. Do not rebuild or repeat acceptance from this historical instruction. The earlier Session 6 package hashes, CI results, device measurements, and 157-test snapshot below apply to their identified source/builds rather than this later UI change.

## Recorded Session 6 evidence status

See [release evidence](RELEASE_EVIDENCE.md) for exact artifacts, methods, raw local
evidence locations and limitations. Statuses are deliberately distinct:

| Evidence class | Recorded state |
| --- | --- |
| Source-verified | Manual successors; bounded startup/history; transition-only writes; inactive ticker cancellation; counted summary reads reduced from two to one |
| Host/CI-verified | 157 Flutter tests, six Android native tests, formatting/analysis/locked offline resolution; Android CI builds; iOS simulator compilation and ten Swift tests |
| Package-verified | Fresh three-ABI APKs/AAB, development-signature validation copies, REA member hashes, offline assets/notices, Android permissions and backup/transfer XML |
| Device-observed | Named G54/Android 15 release cold/warm launches; empty-history usable cold median 597 ms; bounded idle CPU/RSS trace |
| Historical failure, subsequently resolved | Initial workflow context and unsigned iOS optimizer failure were repaired; current unsigned compilation and ten Swift tests passed |
| Unmeasured / unverified | Complete disconnected matrix, matched unplugged energy, store sizes, full backup/phone-transfer behavior and physical iPhone 16 validation |

The ARM64 validation APK is 18,361,384 bytes (17.51 MiB), within the provisional
20 MiB artifact budget. The G54 bundletool compressed download estimate is
8,440,294 bytes. Neither value is a store-reported size or proof of low memory,
CPU or energy use. Production signing and store distribution remain gates.

## Correctness and platform behavior

- Pass timer, controller, database, widget, and migration tests on the pinned SDK.
- Test on real Android and iOS phones: lock screen, background, process kill, force-stop, reboot, timezone and manual clock changes, low-power modes, and permission denial/revocation.
- Native local notifications, cancellation/rescheduling, action deduplication and an explicit Android inexact fallback are implemented. Finish physical-device acceptance in [NOTIFICATIONS.md](NOTIFICATIONS.md); disconnected functional expiry/recovery is operator-reported passed, while alert presentation/sound is unreported. iOS simulator compilation/XCTest and unsigned device release compilation passed; physical iPhone delivery remains gated. Retain SCHEDULE_EXACT_ALARM eligibility review; USE_EXACT_ALARM/store approval is not claimed. iOS does not allow arbitrary continuous background countdown execution.
- Preserve manually started phases. Auto-start chains are outside the confirmed scope; define special-break overlap semantics only if that deferred feature is approved.
- Verify the current-mode UI without chips or a phase dropdown at every text size. Exercise Focus → Short break → Focus, direct Long break after the configured final focus, and return to zero-round Focus after Long break; every successor waits for its matching Start action.
- Reopen a saved focus or break and revisit the Focus tab; preserve its phase/progress. Check purple focus/teal break accents in both themes, the single timer semantic readout, large-text spacing, reachable controls, and the existing strict-mode restrictions.
- Verify first launch, timer and break controls, local tasks/history/settings, restart recovery, and local alerts in airplane mode. Core offline operation requires no signup/network. Optional Windows Calendar requires Google access without blocking the core app.
- Test VoiceOver, TalkBack, 200% text, narrow screens, dark mode, landscape, contrast, hit targets, and reduced motion.
- Screen refinements have host widget/SQLite flow and named viewport coverage; retain the open physical checks in [ACCESSIBILITY.md](ACCESSIBILITY.md) and execute [UI_VERIFICATION.md](UI_VERIFICATION.md) on disconnected standalone installations. The native integration entry point is not proof of those checks and remains unrun without devices.

## Data and privacy

- Explicit v1/v2→v3 migrations, incremental transactions, indexed pagination, failure fixtures and local retention/deletion are implemented. Keep [LOCAL_DATA.md](LOCAL_DATA.md) current and reuse the passed durability suite, including process-exit probes (AUTO-01); rerun only if a concrete affected change justifies it.
- Export/import is deferred and must not delay the core offline release. If later promised, require a versioned validated format, size limits, duplicate rules and a destructive-conflict preview.
- Verify the implemented backup exclusions on devices: Android legacy/cloud-backup/device-transfer rules and iOS database-directory exclusion (including SQLite sidecars). Android packaged rules and the iOS simulator attribute tests are verified; actual phone backup/transfer behavior remains unverified. Keep the no-automatic-recovery disclosure accurate; an older OS backup is not retroactively removed.
- Review sensitive task content, lock-screen notification privacy, and logs. Do not claim database encryption; none is implemented.
- Keep accounts, backend services, cloud synchronization, remote configuration, and personal-profile collection outside the mobile core. Windows adds only its explicitly chosen read-only Google connection; tasks and history remain local.
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
