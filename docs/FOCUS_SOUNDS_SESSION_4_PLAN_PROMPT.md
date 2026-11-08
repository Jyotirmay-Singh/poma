# Session 4 prompt: native background playback, acceptance, and final handoff

Copy this prompt into a separate chat in Plan mode after Sessions 1-3 have been executed. This session completes platform integration and verifies the feature; it does not authorize installation or publication.

---

You are the senior Flutter/native-platform engineer and release-quality reviewer for Poma in `D:\pomodoro`. Produce a detailed Session 4 plan to finish and verify meditation sounds on Windows, Android, and iOS: Tibetan bells, calming waterfall, calming ocean waves, and forest birds chirping, with Off, preview, mute, and volume.

## Planning mode, dependencies, and evidence

Start in Plan mode with read-only inspection and current primary-documentation research. Do not change native configuration, dependencies, code, Git state, installed applications, or the tracker; do not build/test/generate artifacts while the host prohibits mutations. Plan the permitted execution work and its checks. Do not describe intended results as observed.

Read `D:\pomodoro\docs\FOCUS_SOUNDS_PROGRESS.md` completely, including prior-session logs, audio provenance, decisions, outstanding failures, all requirement IDs, things not to do, and the platform acceptance matrix. Read the repository instructions and `D:\pomodoro\RTK.md`; prefix shell commands with RTK or `D:\pomodoro\.tools\rtk\rtk.exe`.

Inspect the actual feature branch and source before planning. Verify which assets, UI, coordinator, deadline mechanisms, tests, and native integrations truly exist. A completed earlier plan does not prove implementation. Include unfinished prerequisites in dependency order and identify external access that is actually required.

Provide proposed tracker changes in the Plan mode deliverable. Once execution is permitted, update the actual tracker before finishing every run, even if physical devices or signing access remain unavailable. Never mark the entire feature accepted by silently dropping those gates.

## Audit the platform boundary

Trace the active-session/playback contract and how timer actions invalidate pending audio. Explain the native/background owner and the source of truth for expiry. Inspect current Android activity/method channels, alert workers, manifest and target SDK; iOS app/scene/audio integrations and project configuration; and Windows runner, tray, lifecycle, notification and packaging code.

Read relevant current official Android, Apple, Flutter, and chosen-package documentation. Verify requirements against Poma's actual pinned versions and current build settings. Do not replace an existing native host or change its inheritance without accounting for its timer/clock/alert bridges and testing the result.

Provide a platform capability table: supported behaviour, required native configuration, background expiry approach, interruption/media controls, available verification environment, and pending access. Distinguish implementation claims from proven behaviour.

## Android completion plan

Plan the required legitimate media-playback foreground service, notification channel/metadata, audio focus/session configuration, relevant permissions, and headset/media controls for the selected stack and target SDK. Preserve existing timer completion channels, identifiers, receivers, database work queues, and permission handling.

Start playback from explicit user action in accordance with current platform rules. Do not auto-start music after reboot, resurrect it on a background broadcast, or request microphone access for playback. Use generic sound metadata such as "Ocean waves" rather than exposing personal task or Calendar details in the media notification.

Specify behaviour while the screen is locked or another app is foregrounded; while calls/navigation/other media interrupt; after wired/Bluetooth disconnection; and after pause, focus completion, reset, or Quit. Media play/pause controls affect audio and must not implicitly start focus or earn history.

Explain exactly how audio stops at the existing focus deadline with no foreground UI ticker. Propagate pause/resume/reset/skip/completion and session replacement safely to the background owner. Avoid duplicate owners and stale notifications. Include source-identity and cancellation guards for queued callbacks and process/lifecycle changes.

Document OS/OEM/force-stop limitations based on observed or official behaviour. Do not promise survival after explicit termination or unsupported background conditions, and do not use a false perpetual service to hide incomplete deadline handling.

## iOS completion plan

Plan the appropriate audio-session category/options, required background-audio mode, interruption and route-change handling, and media controls supported by the chosen architecture. Integrate with existing app/scene lifecycle and native timer/notification channels.

Define silent-mode and competing-audio behaviour deliberately and consistently with the documented policy. Ensure calls, headphones, Bluetooth changes, interruption end, screen lock, and app restoration cannot start expired or user-muted audio. Preserve cold-launch silence and manual phase starts.

Explain expiry while backgrounded using a mechanism supported by the actual playback architecture; do not assume arbitrary suspended Dart timers run. On interruption or wake, reconcile the real session deadline before resuming. Do not play inaudible filler to keep the process alive.

Identify Mac/Xcode, simulator, physical-device, and signing capabilities actually available. Specify which checks each can establish. Simulator compilation, an unsigned archive, and fake-player tests do not establish audible physical-device or screen-lock acceptance.

## Windows completion plan

Verify main-window, navigation, minimisation, native tray timer actions, restored preferences, and Quit all use the same state owner. Sound must continue while a valid active session remains resident and stop when the user quits.

Plan device switching/disconnection, default audio-device changes, sleep/hibernate/resume, expired deadlines on wake, rapid controls, and session reset. Do not claim audio continues while Windows sleeps. Preserve the current app identity, packaging/runtime dependencies, data paths, and existing notification/Calendar integration.

Check playback libraries and codecs are included in the actual review package and require no undeclared developer-machine installation. Do not modify the user's installed Poma or real profile as part of these tests; use isolated data and review artifacts.

## End-to-end acceptance and regression plan

Map each platform-matrix row to a concrete procedure, expected result, required environment, and retained evidence. Include:

1. First use offline from the actual packaged build; all four sounds and notices are present.
2. Listening to multiple loop joins, balanced loudness and bell decays on actual backends; track switching is free of unintended overlaps or peaks.
3. Focus start/pause/resume/reset/skip/completion, silent breaks, strict-mode sound controls, full reset, and error recovery.
4. Hidden/locked playback and stopping at the real deadline without reopening the UI.
5. Calls/competing audio, route changes, Bluetooth/headphone removal, and late callbacks after mute or expiry.
6. Rapid A -> B -> Off actions, reset during loading, preview timeout/dismissal, and disposal.
7. Cold-launch silence, saved preferences, migration from a pre-feature profile, and safe recovery after an unavailable/corrupt audio asset.
8. Windows sleep/wake and mobile lock/unlock without stale replay; explicit OS termination limitations.
9. Professional UI in representative light/dark/high-contrast and large-text layouts; keyboard/semantics and native assistive-technology observations where available.
10. No regression in focus accounting, tasks/history, Calendar consent/actions, native clock/alarm bridges, and independent completion alerts.

Plan relevant formatting, static analysis, full Flutter regressions where justified, targeted native tests, and supported platform builds using existing project workflows. Check current baseline and new failures rather than enforcing an obsolete test count. Use authorized existing CI for unavailable host platforms if possible; identify any access dependency without silently publishing a release.

Measure asset bytes, playback/native dependency overhead, actual package-size differences against a comparable baseline, and representative idle/playing resource observations. Record measurement conditions and source/build identities; do not invent universal battery claims or call an estimate a measurement.

## Completion, pending acceptance, and final deliverable

Return a decision-ready plan with actual prerequisite status; file-specific Android/iOS/Windows changes; the authoritative background-deadline mechanism; media/interruption/privacy policies; ordered tasks; a regression and platform acceptance matrix; access requirements; and explicit S4.1-S4.5 completion criteria.

When executed, complete independent implementation and checks even if some hardware/signing access is missing. Fix regressions caused by the feature and retain evidence of the failure and resolution. Do not broaden into unrelated repairs.

Before finishing execution:

- Reconcile every P/A/U/E and session requirement against actual evidence.
- Update the acceptance matrix with Pass, Fail, Pending, or Unavailable plus a specific source/build/evidence reference.
- Separate source completion, automated checks, host listening, rendered visual review, device acceptance, and release readiness.
- Leave unverified requirements unchecked and provide an exact owner/device procedure for each remaining gate.
- Update the tracker's current position, decisions, session states, log, branch/HEAD, pending changes, and next action. Preserve earlier entries.
- Deliver reviewable feature changes, concise implementation/validation notes, and a truthful list of remaining limitations.

Do not declare full acceptance while mandatory device/listening gates remain unverified. Do not merge into main, delete branches, change the installed app, or publish/tag a release unless the user separately requests those actions.
