# Focus sounds — Session 4 implementation and acceptance handoff

Execution began 8 November 2026; handoff date 9 November 2026, Asia/Kolkata.
Branch `codex/focus-soundscapes`, HEAD
`6bd18d3e10f348a5b9d5e4958203fc934b3e24fd`. Session 2/3 work was preserved.
All changes remain local and uncommitted. Production Poma and its profile remain
untouched; no Git publication, merge, tag, or release publication is included.

**Android follow-up, 9 November:** the connected moto g54 5G now has only the
separate **Poma Sounds Review** update. Physical checks found and corrected an
audio-expiry/completion-alert cancellation race. Fresh analysis/format, **541
regressions**, **69 focused checks**, Android review and Windows release builds
pass. The corrected phone run preserves the completion notification after native
audio expiry and records one completion on return. Active force-stop/cold silence,
review-only full reset and permission restoration pass. See the
[device record](FOCUS_SOUNDS_ANDROID_DEVICE.md),
[verification](focus-sounds/SESSION_4_ANDROID_DEVICE_VERIFICATION.json) and
[current source manifest](focus-sounds/SESSION_4_ANDROID_SOURCE_MANIFEST.json).
Earlier host artifacts/results below retain their original source scope.

**Local outcome:** Android/iOS native source integration is in place. Windows and
Android builds, host regressions/native safety and payload checks pass. The
separate Android review APK and isolated Windows review ZIP are prepared. iOS
compilation and remaining physical/listening gates remain open. S4.4/S4.5
are complete; S4.1-S4.3 stay unchecked for their remaining external gates.

## Ownership and native boundary

The existing `AppController`/`TimerEngine` remains the only owner of timer state,
accounting, SQLite writes, phase starts and completion-alert registration.
Accepted snapshots reach `FocusAudioCoordinator` before persistence/alert work.
The UI ticker is still disabled in the background.

Windows keeps the qualified SoLoud adapter and native guard. Android/iOS now use
`MobileFocusAudioPlayback`, an adapter over one app-owned native runtime and OS
bridge. The mobile runtime uses the bundled **flutter_soloud 4.1.7** native ABI;
it does not initialize Dart's SoLoud singleton or a second player/database owner.
Flutter 3.44.2, Dart 3.12.2, the package lockfile and audio recordings are retained.

The user chose app-owned media integration instead of the earlier proposed
audio_service/audio_session handler. Upstream audio_service's fixed positive
notification ID 1124 can overlap Poma's existing completion-alert IDs. The new
media ID is -1124, and the channel is `poma_focus_sounds_v1`. Existing positive
timer IDs, channels, receivers, response journals and work queues are preserved.

The coordinator's generation represents its full run/segment/intent lease;
prepared resources additionally carry the same run, segment and intent for the
final Dart-side comparison. Native authorization uses a random per-process
residency capability, monotonic operation generation, platform epoch and unique
prepared-source identity. An older process, interrupted route, queued control,
late load or old release cannot authorize or close a newer source.

The native guard validates the absolute deadline immediately before unpausing a
zero-gain voice. A native one-shot worker and renderer-scheduled fade/stop enforce
expiry without any Dart/UI callback. Android uses CLOCK_BOOTTIME, matching
elapsedRealtime; iOS uses CLOCK_MONOTONIC_RAW, matching the existing clock bridge.
The guard stops output before notifying the application. Ordinary controller
reconciliation then accounts for the completion and leaves the next phase Ready.
The native runtime never creates another countdown or completion notification.

| Platform | Implemented capability/configuration | Deadline and interruptions | Verified environment / remaining access |
| --- | --- | --- | --- |
| Windows | Existing SoLoud, native runner/tray/guard; same profile and application/notification/Calendar identities | Sleep-inclusive elapsed lease, native worker and renderer cap; native suspend/output loss revokes audio; wake reconciles; no universal competing-app focus detection | Windows 11 x64 release/native/real isolated playback and packaged-runtime checks pass. Physical sleep/hibernate, wired/Bluetooth/default-device changes, manual tray, Narrator and clean-account offline acceptance pending |
| Android | Application-owned single Flutter engine; non-exported mediaPlayback FGS; generic MediaSession, silent media channel; FGS/media-playback/wake permissions; existing alert work unchanged | CLOCK_BOOTTIME absolute deadline, native worker/renderer; focus loss/noisy/route/media pause revokes. No auto-resume or sticky/reboot start. Audio expiry does not reconcile/cancel the independent completion request | SDK 36 builds/JVM/payload checks and Android 15 moto g54 native previews, controls, strict/mute/zero, lock/background deadline, completion coexistence, restart/reset/accounting and resource observations pass their recorded scope. Listening, offline/unplugged, calls/routes and TalkBack remain |
| iOS | Existing implicit engine/scenes; playback/default AVAudioSession, no mixing, audio background mode, remote commands | CLOCK_MONOTONIC_RAW absolute deadline, native worker/renderer; interruption/route/reset revokes; explicit eligible Play only | Source reviewed on Windows. Mac/Xcode compilation, XCTest/linking, signing, simulator and iPhone backend/lock/VoiceOver/energy checks unavailable |

Revocation is synchronous for audible output and does not wait for silent asset
loading. Slow device teardown runs natively, independently of Dart. Loading is
limited to one bundled asset, at most 4 MiB encoded, with ten-second startup
authorization. The pinned stream-memory API takes ownership of its input;
the mobile wrapper therefore uses copying decode mode. Only one recording is
decoded (largest current draft approximately 34 MB PCM), and it is retired on
stop. This memory/loop tradeoff needs Android device resource observations.

## Product and interruption policy

- Off / 35% / unmuted defaults and version-1 optional preferences remain. No
  schema migration or persisted playback authorization was added.
- Selection while ready saves a preference. Continuous playback requires a
  valid, explicitly armed Focus. Breaks and cold restoration remain silent.
- Mobile backgrounding preserves valid continuous audio; previews end and may
  restore only the same eligible Focus after fresh reconciliation.
- Previews retain their cancellation token and ten-second native cap, shortened
  by the Focus deadline. One stream is audible; switching retires the old stream
  before the next source starts.
- Calls/navigation/competing audio and media pause stop mobile output. Interruption
  end never restarts it. Play sounds/media Play or an explicit Focus Start/Resume
  must revalidate the clock and acquire OS authorization. Mute, zero and Off win.
- Output loss requires explicit Play. Reconnection cannot restart audio.
- Media actions never call a timer start/resume/skip API or earn history.
- Reset, full reset, completion, Quit, disposal and failed authorization revoke
  pending playback before slower work. Errors keep existing timer/data/alert
  behavior and expose Retry where appropriate.
- Lock-screen metadata contains only a sound title and Poma; no task, Calendar,
  account or personal device names are included.

## Android integration

Target/compile SDK 36, minimum SDK 24, AGP 9.0.1, Gradle 9.1.0, Kotlin 2.3.20,
Java 17 and NDK 28.2.13676358 are retained. An application-owned Flutter engine
keeps the one controller alive across Activity recreation and supported playback.
MainActivity still inherits FlutterActivity. Clock and alert bridges are attached
once at engine scope; launch metrics, alert-open capture and onNewIntent remain.

The non-exported mediaPlayback service starts only from the current explicit
request, enters foreground promptly, then acquires media/music AUDIOFOCUS_GAIN.
Transient/duck/permanent loss pauses instead of mixing or automatically resuming.
API-appropriate focus calls support SDK 24 onward. FOREGROUND_SERVICE,
FOREGROUND_SERVICE_MEDIA_PLAYBACK and a deadline-bounded WAKE_LOCK are declared.
No microphone, Bluetooth scanning, battery-optimization exemption or new exact
alarm permission is requested. Existing POST_NOTIFICATIONS/exact-alert handling
remains independent.

The media notification is silent/low importance with a real framework MediaSession
and Play/Pause/Stop policy. Native noisy/device callbacks stop output. Backend
AAudio/CoreAudio feedback also invalidates reroutes with an unchanged device
inventory; its real-time callback only signals the native guard worker. The service
returns START_NOT_STICKY. No boot/time/package receiver starts music. Service
loss/task removal stays silent and updates application playback state. Native
deadline cleanup removes foreground residency and releases focus/wake state even
when Dart is blocked. Paused system media history is OS-owned; every Play checks
the current resident Focus/deadline again.

The optional review build has application ID
`com.jyotirmaysingh.poma.focussoundsreview` and launcher label **Poma Sounds Review**.
It uses explicit review-only debug signing in release mode; production keeps its
own ID and signing requirements. The review app has a separate Android sandbox.
JNI callback names are retained for optimized builds.

## iOS source integration — verification unavailable

The scene/implicit-engine lifecycle, clock/storage channels, local notification
delegate, backup exclusion, Swift Package Manager setup and iOS 13 target remain.
The new bridge is registered beside existing channels. UIBackgroundModes adds
only audio. AVAudioSession uses playback/default mode without mixing/ducking;
explicitly started playback ignores the silent switch. The app's mute/volume
remain authoritative. Activation is deferred to an explicit eligible request;
idle cleanup notifies other audio sessions on deactivation.

Control Center/headset Play/Pause/Stop commands use generic metadata. Unsupported
seek/queue commands are disabled. Native interruptions, route loss and media
services reset retire output; returning to the foreground checks expiry before
any request may resume. Natural bell gaps are content, never an added silent
keepalive. Arbitrary suspended Dart timers are not an expiry mechanism.

This is implemented source, **not an iOS compilation or device claim**. The user
selected Unavailable for Mac verification; no CI dispatch/push was performed.
Mac/Xcode compilation, native XCTest, Swift/native linking, signed installation,
actual playback/session policy, lock behavior and VoiceOver remain unverified.

## Verification and evidence

`docs/focus-sounds/SESSION_4_VERIFICATION.json` and
`SESSION_4_SOURCE_MANIFEST.json` record final outcomes/source identities.
Successful and failed logs remain in `artifacts/focus-sounds/session-4/checks/`.
The source baseline and copied existing production artifacts were retained before
implementation; baseline Windows EXE and Android debug APK matched Session 3's
recorded hashes. A fixture/library inventory is not a store-size measurement.

Host checks cover coordinator/media controls, persistence/reset, strict controls,
stale callbacks, preview restoration, native absolute expiry, resource retirement,
loading cancellation, process replacement and corrupt-asset recovery. The native
mobile runtime is additionally qualified against the real packaged Windows
renderer/four encodings; that does not establish an Android/iOS playback backend.
Forced loop seeks do not establish audible natural joins or perceived loudness.

Fresh Windows production UI captures were collected from an identity-checked,
copied review process with fictional storage. Playing and chooser captures were
visually inspected. Existing responsive/light/dark/high-contrast/font/semantics
evidence retains its original scope; no physical assistive result is inferred.

Failures retained during this run include SDK-cache/Windows-process access,
native warning/link settings, an initial test-fixture revision lookup, the real
stream-memory ownership failure, and two Windows temporary-file sharing failures
in the first parallel full regression run. The ownership defect was corrected
and real-backend probes rerun. The unchanged process-cleanup regressions are
rerun separately/sequentially; final results are recorded rather than erasing the
initial failures or modifying unrelated application behavior.

Original host snapshot: **540 Flutter regressions**, **68 focused tests including
UI**, **233 desktop + 43 fonts + 15 Windows guard + 25 mobile synthetic native
checks**, **108 shared-mobile-runtime checks using the real Windows backend**,
and **10 Android JVM policy/alert/work-queue tests**. Analysis and Dart formatting
pass. Later native-only changes were verified by fresh native/Android builds;
the verification record confirms unchanged Dart/Windows sources for reused
checks instead of claiming that earlier tests exercised later mobile code.
The Android alert correction has fresh format/analysis, **541 regressions**,
**69 focused checks**, Windows release and Android review builds. Native C++/
Kotlin, dependencies and assets did not change in that correction; prior native
and payload evidence keeps that scope. Its source hashes/builds are linked above.

The final real Windows run from the sanitized review distribution passes five
production UI/playback checks. Playing and chooser captures at
`artifacts/focus-sounds/session-4/windows-runtime-1794201269113911000/` were
inspected on 9 November. The same hidden renderer/resource procedure passes 32
core playback checks plus four cold/reset checks; the native stop attempt was
observed +1,061 microseconds from its deadline, not a speaker-latency measurement.

### Review artifacts and packaging correction

- Current Android: `artifacts/focus-sounds/session-4/builds/android-review-1794205856909895100/app-release.apk`.
  Package `com.jyotirmaysingh.poma.focussoundsreview`, label **Poma Sounds Review**,
  debug-signed release-mode review, 36,117,169 bytes; SHA-256
  `2523f4f46e1f42a20b08e40b2dc99fd1c1bf272fcaf5930d939a8d7df1ba9a5c`.
  Installed review APK bytes were read back and match this hash. Production is
  untouched. The original pre-fix APK (`android-review-1794200768379284800`, hash
  `2b811bcce49747ae064bec0307b90d873f9758b47a17976df749149f89074484`)
  and its failures remain retained separately.
- Windows: `artifacts/focus-sounds/session-4/windows-package/review-1794201884719164000/Poma-Sounds-Review-Windows-x64.zip`.
  Extract the entire folder and run `poma.exe`. The compiled review runner uses
  its own fictional profile/mutex/tray/notification identities. This is the
  interactive Session 4 production entry point from before the mobile alert
  correction; no refreshed ZIP is claimed. 22,225,036 bytes; SHA-256
  `46f9c71226d77167500a67d96ca6e5e1bcb65b274a164829e55510efb32793ab`.
  Its fresh isolated startup/database and synthetic request through the ordinary
  Quit handler pass without JNI. The five playback/UI checks use the separately
  retained automated Session 3 review entry point with the same sanitized DLL/CRT
  inventory, not a claim of manually operating this interactive build.
- Production Windows inspection package:
  `artifacts/focus-sounds/session-4/windows-package/production-2007-audited/Poma-1.0.0.2007-x64.msix`.
  Unsigned and not installed, 22,429,438 bytes; SHA-256
  `3ca326ee98a8daaf4d3891a8996eae4ff3b25b8b55b7f3ad6bd0a14709192613`.
  Source version/identity was preserved; this is not a published upgrade.

The first packaging attempt failed on `dartjni.dll -> jvm.dll`. Both the saved
Session 3 baseline and current developer output contained that optional JNI
desktop shim because this host has a JDK. Windows uses `WindowsLocalAlerts` and
does not initialize the Android notification/JNI adapter; its native-asset map
also has no JNI reference. Packaging now omits that Android-only artifact and
fails if any Windows native-asset or PE import references JNI/JVM. All audio
codecs, app-local CRT and their licenses remain. The successful MSIX audits 20
x64 PE files, one AOT snapshot and 76 payload files. The isolated review ZIP was
then launched without the shim and passed its real playback/UI checks. This
does not replace clean-VM/installed offline-first-use acceptance.

### Measured size and resources

All four unchanged draft recordings total **3,194,230 bytes**. The matched raw
Windows release-runtime inventory is unchanged from the saved Session 3 build;
the packaging correction separately removes the 68,096-byte unused JNI shim.
Audio/codec DLLs retain the earlier 3,665,408-byte inventory. No comparable prior
MSIX is retained, so no MSIX-to-MSIX delta is claimed.

The fresh Android debug APK is 104,012,748 bytes, **1,507,344 bytes smaller** than
the retained same-target Session 3 APK. Compressed ZIP-entry bytes instead grew
by **1,156,375 bytes**; alignment/layout differences mean the raw APK delta is
not a claim of reduced audio/native cost. The new release native guard totals
1,014,572 uncompressed bytes across packaged ARM64, ARMv7 and x86-64 libraries.
All packaged native ELF load segments meet the inspected 16-KiB alignment.

The isolated hidden Windows release used approximately 60/120/60-second
off/playing/post-stop windows. CPU percent of one core was **0.82 / 1.55 / 0.42**;
median working set was **102.5 / 52.6 / 47.7 MiB**. Startup/cache/GC are included.
Raw samples, threads/handles and exact binary identity are retained under
`artifacts/focus-sounds/session-4/run-1794164384001161900/evidence.json`.
These are practical host observations, not mobile memory/energy or battery claims.

The first interactive startup-smoke fixture looked for the database in the
profile root instead of its `databases` subdirectory; it timed out after Poma had
correctly created the isolated database. Its owned child was cleaned up. The
failure record is retained in the checks directory. Correcting the fixture's
lookup and repeating against a fresh copy passes startup and normal Quit; no
application/storage behavior was changed to satisfy the fixture.

### Primary documentation checked

Reviewed 9 November 2026 against the pinned Flutter 3.44.2 / Dart 3.12.2,
flutter_soloud 4.1.7, SDK 36 and iOS 13 source configuration:

- [Android audio focus](https://developer.android.com/media/optimize/audio-focus):
  focus must be acquired before output; target 35+ requires a top app or FGS.
- [Android mediaPlayback foreground service](https://developer.android.com/develop/background-work/services/fgs/service-types#media)
  and [background-start restrictions](https://developer.android.com/develop/background-work/services/fgs/restrictions-bg-start):
  the declared media type/permissions and explicit-action start boundary are retained;
  no boot-started playback or promised force-stop survival.
- [Apple playback category](https://developer.apple.com/documentation/avfaudio/avaudiosession/category-swift.struct/playback?language=objc)
  and [audio-session configuration](https://developer.apple.com/library/archive/documentation/AudioVideo/Conceptual/MediaPlaybackGuide/Contents/Resources/en.lproj/ConfiguringAudioSettings/ConfiguringAudioSettings.html):
  playback category plus the audio background mode are configured; explicit
  playback ignores silent mode. Device policy is still unverified.
- [Flutter UIScene lifecycle](https://docs.flutter.dev/release/breaking-changes/uiscenedelegate):
  retain `FlutterImplicitEngineDelegate` registration and scene callbacks.
- [SoLoud OS audio-context boundary](https://docs.page/alnitak/flutter_soloud_docs/get_started/audio_context):
  playback alone does not supply OS audio-session policy. The locally installed
  4.1.7 headers/implementation were checked for the exact ABI, copying load mode,
  callbacks and app-owned iOS audio-session configuration.

## Exact remaining physical acceptance procedures

Owner: **the user** for Windows/Android; **a future Mac/iPhone tester** for iOS.
Record date, device/model/OS, source/build/hash, signing, route/volume, power and
notification settings, steps, expected/observed behavior and private-safe evidence.

1. **Final recordings:** compare the eight retained candidates, then listen to
   each proposed winner for ten minutes and five natural loop joins on headphones
   and speakers. Record exact hashes, selection reason, peaks, decays, speech and
   loudness observations. Repeat backend checks after any asset replacement.
2. **Windows:** use the isolated review runtime. Test navigation, minimise,
   close-to-tray, native tray start/pause/resume/reset/skip and Quit/cancel-Quit.
   Test real sleep/hibernate before and across expiry; no audio during sleep is
   promised. Remove wired/Bluetooth outputs, change the default output, and
   confirm explicit recovery. Observe Narrator, keyboard and real system text size.
   Other apps follow Windows audio policy; universal competing-app focus detection
   is unsupported and must not be claimed.
3. **Packaged Windows first use:** use a clean test VM/account and appropriately
   trusted/signed review package, never installed Poma's identity/profile. Disable
   network before first launch, play all four recordings, inspect notices and
   verify bundled codecs/CRT. File inspection alone leaves this gate pending.
4. **Android remaining:** the corrected review APK is installed and reset to
   defaults. The user deferred listening. Listen to all four previews/loops and
   repeat Focus with USB/debug tools and network disconnected. Use a fresh review
   test-user sandbox for first-launch offline acceptance, with networking disabled
   before launch; preserve production data. Repeat lock/background expiry unplugged.
   Test calls/navigation/other media, wired removal and Bluetooth disconnect;
   interruption end/reconnection stays silent until explicit eligible Play.
5. **Android remaining policy/accessibility:** exact-permitted alert/media
   coexistence, denial-compatible audio, force-stop/cold silence, exact history and
   manual next-phase state have scoped phone evidence. Temporary review notification/
   precise permissions were restored to denied/off. Test task removal, TalkBack,
   physical system text sizes and additional OEM/power conditions; do not promise
   survival or alarm delivery after explicit OS termination. Denied precise access
   retains Android's documented scheduling limitations.
6. **iOS access:** provide a Mac with Xcode and the pinned Flutter SDK. Run the
   existing simulator/native-test and unsigned release workflows against the exact
   feature source. Then supply a development-signed standalone profile/release
   review app on iPhone. Repeat offline/loops/lock/deadline/calls/routes/mute/reset,
   silent-switch policy, natural bell gaps, force-quit/reopen and VoiceOver tests.
   Simulator/unsigned compilation cannot close the physical gates.
7. **Resources:** Windows observations describe their named isolated process and
   conditions only. Android PSS/RSS, coarse cumulative CPU and native track/wake-lock
   observations are recorded in the device follow-up; no energy measurement is
   inferred. iOS Instruments/energy still needs the unavailable Mac/iPhone.
   No universal battery or store-download claim follows from host measurements.

## Requirement reconciliation

All 59 tracker requirements retain their meanings. P03/P07, A02/A03/A07,
U01-U08 and the previously completed engineering/session items keep their scoped
evidence. P01/P04-P06/P08-P14 have shared/Windows and native-policy evidence but
remain globally open for the platform matrix. P02 and A01/A04-A06 still require
final recording/listening and relevant packaged/backend acceptance. E03/E05 and
S4.1/S4.2 remain open while mandatory mobile/iOS verification is missing.
S1.3 and S2.3 retain their listening/physical gates. Build/test/source completion
never substitutes for those observations. The tracker and final verification
record provide the current Pass/Fail/Pending/Unavailable matrix and next action.

S4.3 remains partial because clean-account packaged offline first use and iOS
resource observations require the recorded external environments. The available
formatting, analysis, 541 regressions, native/JVM checks, builds, payload hashes,
isolated playback, Windows package audits and host resource work are finished.

| Requirements | Evidence and remaining acceptance |
| --- | --- |
| P01 | Four drafts/Off and one-stream policy: UI/native/real Windows plus Android previews, rapid switch and correct-source restoration observed. Listening/iOS remain |
| P02 | Windows MSIX/ZIP and Android APK contain exact assets/notices. Final recordings and clean-account/phone offline-first-use pending |
| P03 | Defaults, optional legacy preferences, SQLite restart/reset and real isolated cold/reset pass |
| P04-P05 | Explicit ready/running selection, start/pause/resume pass shared/UI and Android native-state checks. Audible/iOS acceptance remains |
| P06 | Shared/Windows checks plus Android reset/skip/deadline/full reset/force-stop retirement pass; iOS remains |
| P07 | Existing strict-mode boundary/UI tests pass; sound controls do not invoke timer restrictions |
| P08 | Windows hidden/navigation and Android Home/locked native playback pass; manual Windows tray, unplugged/audible and iOS remain |
| P09 | Android lock/unlock, expired and active cold-launch silence pass; real Windows sleep and iOS remain |
| P10 | Android native timed previews/dismissal/correct-source restoration join shared/Windows token checks; listening/iOS remain |
| P11 | Focus/noisy/route/media-loss policy implemented and native guards checked. Physical calls/headphone/Bluetooth/default-device tests pending |
| P12 | Shared/native stale-event checks plus phone audio-only media controls cannot resume paused timer or override mute/zero/expiry. Physical interruptions/iOS remain |
| P13 | Shared failed/corrupt recovery checks and phone mute/zero policy pass; introduced alert race reproduced, corrected and phone-retested. Physical corrupt-asset/iOS recovery remains |
| P14 | Existing IDs/work queues/receivers preserved. Phone comparison reproduces cancellation; corrected build retains completion ID 4 after media -1124 retires with precise access allowed. iOS/other OS policy conditions remain |
| A01 | Eight candidates retained; no human comparative audition or final choice claimed |
| A02-A03 | Exact unchanged draft hashes retain Session 1 source/license/provenance evidence |
| A04-A05 | Numerical diagnostics/forced wraps do not establish natural audible joins, decays or balanced loudness; listener/backend procedure pending |
| A06 | Exact assets/DLL/guard/raw package deltas and scoped Android resources measured; final recordings and iOS resources remain |
| A07 | Listening is explicitly separate from machine/host evidence; no universal relaxation ranking |
| U01-U04 | Session 3 original celestial design, hierarchy, truthful control state and adaptive chooser retained; unchanged UI regressions pass |
| U05-U06 | Host semantics/keyboard/contrast/fonts/text-size/viewports retain their checked scope. Native Narrator/TalkBack/VoiceOver and physical scaling pending |
| U07-U08 | Real state/retry/interaction and inspected Windows playing/chooser captures pass; previous Session 3 capture evidence retained |
| E01 | Exact 4.1.7 ABI/dependencies retained; current Windows/Android builds and shared native real-backend probes pass |
| E02 | Domain/timer stays package-independent; coordinator/ports/fakes/native renderer boundary preserved |
| E03 | Native deadline/session host checks plus Android locked/background retirement pass; iOS compilation/backend remains open |
| E04 | Loading cancellation, stale callbacks/media, expiry/reset, rapid switching and disposal pass shared/native probes |
| E05 | Android FGS/focus/media/lock/expiry observed; physical calls/routes remain. iOS source integrated, compilation/device unavailable |
| E06 | Lazy one-source/no tick IO and cleanup checks plus Android own-track/memory/wake-lock observations pass their stated scope |
| E07 | Backward-compatible preferences and composite reset checked; no new SQLite migration or timer accounting changes |
| E08 | Available format/analysis/regression/native/JVM/build/payload/package checks recorded with scoped source identities; unavailable iOS tests explicit |
| E09 | Measured size deltas and named Windows/Android resource samples; no energy/battery claim |
| E10 | Source, host tests, actual Windows renderer, visuals, listening, device acceptance and release readiness recorded separately |
| S1.1-S1.5 | Prior evidence retained; S1.3 stays open for final listening/selection |
| S2.1-S2.5 | Prior core checks retained; S2.3 stays open for physical sleep/routes/manual tray |
| S3.1-S3.5 | Completed shared/Windows UI scope retained; no device acceptance inferred |
| S4.1 | Native source complete; Android scoped checks and introduced alert correction verified. iOS compile/link/test and physical interruption/routes remain |
| S4.2 | Scoped Windows and Android matrix passes recorded; listening and remaining physical acceptance stay open |
| S4.3 | Fresh supported host checks/builds complete; clean-account offline-first-use and iOS resource gates remain open |
| S4.4-S4.5 | External access, exact owner procedures, all 59 requirement states, build/source identities, retained failures and final tracker reconciled |
