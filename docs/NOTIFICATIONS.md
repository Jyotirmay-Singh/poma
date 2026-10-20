# Native local alerts and device evidence

Updated 20 October 2026. Android native integration builds and host tests exercise the protocol. **No physical notification delivery has been observed on Android or iOS. iOS compilation and XCTest execution are blocked by the absence of macOS/Xcode.** This is not a production delivery certification.

## Phone capability

Start one focus or break in Poma. The phone registers a one-shot system request; no internet, account, computer, developer server, push provider, backend, foreground service, or continuously executing Dart countdown is needed for its later delivery. Every successor is ready until the person starts it. Notification permission and OS policy still apply.

The first Start explains alerts before asking for OS permission. Not now, denial, and revocation leave the timer usable. Settings offers a completion-alert switch, phone notification settings, retry, and Android precise-alert access when applicable. Native and system settings are rechecked on return. Permission prompts are not issued by launch, rendering, receivers, or ordinary resume.

Content is only **Focus complete** / **Break complete**, **Open Poma when you’re ready.** No task titles enter notification content, payloads, channels, or native journals. **Open timer** opens the timer; **Dismiss** clears the alert. Neither starts or skips a phase. Sound uses the platform notification default and follows the person's channel, notification, Focus and Do Not Disturb settings. There are no critical alerts, alarm-volume audio, full-screen intents, DND bypasses or battery-optimization exemption requests.

## Dependency and native configuration

`flutter_local_notifications` is exactly **22.3.2** in the manifest and resolved lockfile. Its installed README, Dart API, Android source, iOS source, Swift package and privacy manifest were inspected before integration. It supports this Flutter 3.44.2 / Dart 3.12.2, Android API 24 / compile 36 / Java 17 and iOS 13 / SwiftPM baseline. Existing locked dependencies were retained; new transitive packages come from the notification package. Its date scheduler uses Android RTC alarms and iOS calendar triggers; its interval API repeats. Poma therefore uses its public initialization/permission/status/settings API with small app-owned native one-shot schedulers, without accessing package internals or importing it in domain/application code.

Android enables core library desugaring (`desugar_jdk_libs` 2.1.4), provides a monochrome notification icon, and declares POST_NOTIFICATIONS, SCHEDULE_EXACT_ALARM and RECEIVE_BOOT_COMPLETED with private native alarm/action/restore receivers. It does not declare USE_EXACT_ALARM. A timer is a policy-listed exact-alarm use case, but that does not establish Play approval; the starter deliberately uses optional user-granted special access. The scheduler checks `canScheduleExactAlarms`, catches an access race, and falls back from `setExactAndAllowWhileIdle` to `setAndAllowWhileIdle`, both with ELAPSED_REALTIME_WAKEUP. Inexact delivery is visibly described as potentially delayed.

iOS retains UIScene and SwiftPM, supplies non-repeating UNTimeIntervalNotificationTrigger requests, registers a completion category, and routes system responses through the existing app delegate. No remote-push entitlement or background-execution mode is added. The app privacy manifest declares system-boot-time timer use (35F9.1) and app-private UserDefaults use (CA92.1).

## Persistence and crash protocol

SQLite v2 introduced `notification_state` and `notification_receipts`; current v3 preserves that native contract and adds incremental commit metadata/indexed history. The existing database location, tasks, history, selections, backup policy and valid v1 timers are retained. Corrupt legacy state rejects migration transactionally. The desired record carries a persisted session ID, scheduling generation, integer notification ID, running segment, UTC projection, elapsed deadline, boot count where available, and bounded remaining interval. A resume retains the session/notification ID but gets a new generation. Confirmed full data reset commits an empty desired request plus an opaque cleanup marker before clearing pending/delivered notifications and native response/scheduling journals; retry/reopen repairs an interrupted cleanup. See [local data policy](LOCAL_DATA.md).

1. Reconcile timer expiry with the injected native clock. Commit timer, history and desired notification changes in the same SQLite transaction.
2. Apply native cancellation/replacement using the persisted identity. Acknowledge success separately with a unique receipt. The coordinator runs inside the controller's command queue; rendering does not schedule, save, or query notification status every second.
3. On launch, resume, explicit retry and native events, repeat reconciliation. Android cancels its journaled alarm tokens and re-arms only the committed current intent; iOS enumerates actual pending requests and removes obsolete owned requests. Neither infers successful delivery solely from a missing request.
4. Android journals registration before the OS call and validates the committed run/generation under a SQLite transaction before posting. A delivery receipt suppresses duplicate receiver delivery. iOS uses a stable request identifier to replace pending requests. Reconciliation never synthesizes an overdue alert to make up for a missing OS request.
5. Native response journals persist Open/Dismiss tokens until the application records a unique action receipt. A crash before native acknowledgement can repeat ingestion, not the action. Dismiss can finish natively; no second/headless Dart timer owner is created. When the normal engine is present, the event triggers its serialized reconciliation; otherwise history is reconciled on next app entry.

Pause, reset, skip, selection, alert disabling and completion remove desired requests; ready/paused phases have none. Duration edits retain the current phase's original duration. Save/scheduling/acknowledgement errors keep the timer and expose retry. A failed save never registers a new uncommitted phase; safety cancellation is still attempted. A failed clock sample preserves the last durable schedule instead of treating absent scheduling data as completion. Focus history remains unique by session ID and is committed with its ready successor.

SQLite and notification services cannot share one atomic transaction. A crash can interrupt registration or cancellation before acknowledgement; next-entry reconciliation repairs it. In particular, an already accepted iOS request can still appear in a cancellation crash window while no app code runs. A native crash between showing an Android notification and committing its delivery receipt also cannot provide a universal exactly-once sound guarantee. These are not claims of uninterrupted or second-perfect delivery under arbitrary crashes or OS interventions.

## Clock, termination and permission limits

- Android persists BOOT_COUNT and elapsed deadlines. Same-boot process restoration uses elapsed time, including sleep, and ignores wall-clock jumps. Boot, package replacement, clock/timezone changes and exact-access grants invoke native reconciliation. After reboot, boot-relative values are discarded; bounded UTC recovery applies. Time spent powered off, and manual time changes around reboot, cannot be reconstructed with certainty. Overdue boot recovery does not post a late alert or start another phase; history reconciles when Dart next runs.
- Android ordinary process death or removal from recents differs from **Force stop**. Force stop can remove alarms and stop receiver delivery until the app is opened. Exact-access revocation can kill the process and cancel exact alarms; there is no guaranteed revocation callback that can install a fallback while the app remains closed. Return to Poma rechecks access and uses the fallback for a still-active phase. OEM restrictions and Doze quotas can delay or suppress delivery, including exact alarms.
- iOS owns accepted local requests while the app is suspended or terminated. Swiping the app away does not require its Dart countdown for an existing local request, but supplies no general right to run background Dart, reconcile history at expiry, repair requests, or receive boot events. iOS has no app boot receiver here. Reboot and force-quit combinations require device observation; no guarantee of new background execution is made.
- The iOS continuous clock is retained within the live engine. Across process death, Poma uses bounded UTC recovery because there is no reliable documented boot identity used here. It does not treat wall time minus uptime as a reboot-proof identifier. Manual clock changes across a dead process can therefore change timer recovery even though an accepted interval notification is system-owned. Significant-time/timezone changes notify the app while it is running; launch/resume always repairs pending requests.
- Timezones do not alter elapsed Android timers or native interval scheduling. Notification authorization, blocked channels, sound settings, Focus, Scheduled Summary, low power, device policy and future OS behavior can affect presentation. The UI does not claim delivery occurred merely because scheduling succeeded.

## Device evidence matrix

Available checks observed on the final implementation:

| Check | Observed result |
| --- | --- |
| Flutter suite | 96 passed, including 20 added alert/migration/UI scenarios |
| Android JVM policy suite | 6 passed, 0 skipped/failures/errors |
| Static analysis / formatting / whitespace | Passed |
| Offline enforced lockfile resolution | Passed; existing locked packages unchanged |
| Android arm64 debug build | Passed; 93,215,948 bytes |
| Android artifact SHA-256 | `95e6572e3dc68d5a92b332e27a966d7a96457dedfc377b50f0de39d0669011e1` |
| iOS compilation / native XCTest | Not run; macOS/Xcode unavailable |
| Physical Android/iOS alert delivery | Not observed |

The debug APK includes Flutter's development-only INTERNET permission; the merged manifest has the intended native receivers and no foreground-service, app wake-lock, restricted exact-alarm or DND-bypass permission. This inspection is packaging evidence, not a runtime/offline/privacy benchmark. No new hosted CI result is claimed.

Inventory observed on this Windows host: `adb devices -l` returned **no attached devices**. There is no local macOS/Xcode/iOS device environment. Every cell below is **BLOCKED — NOT OBSERVED**, not a pass inferred from host tests or compilation. Android Force stop is Settings/`am force-stop`; iOS force-quit is a multitasking swipe, a distinct condition.

| Physical-device scenario | Android | iOS | Required observation |
| --- | --- | --- | --- |
| Airplane mode, computer disconnected, all developer tools stopped | Blocked | Blocked | Start focus, disconnect, one completion alert; successor ready |
| Open another app / background | Blocked | Blocked | One alert and working Open/Dismiss |
| Locked screen across deadline | Blocked | Blocked | Generic wording, permitted sound, no task disclosure |
| Ordinary killed process | Blocked | Blocked | Previously registered request delivers without Dart |
| Force stop / force-quit | Blocked | Blocked | Record OS-specific delivery/suppression and recovery after open |
| Reboot before deadline, including first unlock | Blocked | Blocked | Record actual rescheduling/delivery; no fabricated chain |
| Reboot after deadline | Blocked | Blocked | No late synthesized alert; one recovered completion |
| Doze / Low Power Mode | Blocked | Blocked | Record actual latency/suppression and permission mode |
| Timezone change while backgrounded/dead | Blocked | Blocked | Record delivery and recovered timer/history |
| Manual clock forward and backward, live and dead process | Blocked | Blocked | Separate same-boot elapsed behavior from UTC fallback |
| Permission denied initially | Blocked | Blocked | Timer works, honest status, no repeated prompt |
| Permission/channel revoked after scheduling | Blocked | Blocked | Record OS cancellation and recovery on return |
| Exact access granted/denied/revoked | Blocked | N/A | Exact vs inexact result and revocation limitations |
| Focus / DND / sound disabled | Blocked | Blocked | Respect OS presentation/sound choices |
| Duplicate taps, old notification after pause/resume | Blocked | Blocked | No duplicate count or unintended phase start |
| Pause/reset/skip/selection/settings changes | Blocked | Blocked | Obsolete request suppressed/cancelled |
| Short/long break completion | Blocked | Blocked | One generic break alert, no focus history, ready successor |

For each actual run record date, model, OS/build, artifact hash, app build mode/signing, notification/channel/exact settings, starting phase and duration, exact steps, observed delivery latency, pending requests before/after, resulting history/cycle, and screenshot/video or log evidence. Keep task text and personal notifications out of shared evidence. Simulator/JVM/fake-clock results must remain separately labeled.

## Reproduce and finish validation

From the repository root, `scripts/flutter.ps1` provides the existing RTK/SDK/short-temp wrapper. Run formatting, `pub get --offline --enforce-lockfile`, analysis, all Flutter tests, and `build apk --debug --target-platform android-arm64 --no-pub`. From `mobile/android`, run `rtk proxy ./gradlew :app:testDebugUnitTest --console=plain` with the host's existing Java/short-temp setup when needed. CI now runs Android policy tests and uploads their JUnit report; its macOS job compiles the simulator app and runs all RunnerTests, including notification tests.

On a connected Android phone install the fresh debug APK, launch it normally, enable notifications, choose exact access or intentionally leave it unavailable, and start a one-minute phase. Close developer tools and disconnect before testing background/lock behavior in airplane mode. Test standalone launch again after reboot; debug labels and debug tooling permissions are not release privacy/performance evidence. On a Mac use a legitimately development-signed **profile/release** iOS build for standalone phone checks; a debugger-attached JIT build is not sufficient. Store publication and production signing remain separate release gates.

## Primary sources checked

- [Notification package 22.3.2](https://pub.dev/packages/flutter_local_notifications/versions/22.3.2) and its installed sources.
- [Android elapsed vs RTC alarms](https://developer.android.com/develop/background-work/services/alarms), [exact-access rules](https://developer.android.com/about/versions/14/changes/schedule-exact-alarms), [notification runtime permission](https://developer.android.com/develop/ui/views/notifications/notification-permission), [BOOT_COUNT](https://developer.android.com/reference/android/provider/Settings.Global#BOOT_COUNT).
- [Play exact-alarm policy](https://support.google.com/googleplay/android-developer/answer/16558241?hl=en).
- [Apple local notification responsibility and cancellation](https://developer.apple.com/library/archive/documentation/NetworkingInternet/Conceptual/RemoteNotificationsPG/SchedulingandHandlingLocalNotifications.html), [authorization](https://developer.apple.com/documentation/usernotifications/asking-permission-to-use-notifications), [interval trigger](https://developer.apple.com/documentation/usernotifications/untimeintervalnotificationtrigger), [required API reasons](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitypereasons).
