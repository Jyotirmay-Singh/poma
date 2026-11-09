# Focus sounds: Android device follow-up

9 November 2026, Asia/Kolkata. Device evidence was captured on branch
`codex/focus-soundscapes`, HEAD
`6bd18d3e10f348a5b9d5e4958203fc934b3e24fd`, with uncommitted feature work then.
The implementation was subsequently committed as
`c59291323fc5b0b61880d378316dca666649af5f`, fast-forwarded/pushed to `main`,
and the feature branch deleted locally/remotely after verified synchronization.
Recorded source/build evidence keeps its original capture scope.
The user connected a phone and authorized device checks. Only the separately
identified **Poma Sounds Review** application is used. Production `dev.poma.poma`
and its profile remain untouched.

Device: **moto g54 5G**, Android **15 / API 35**, ARM64. The app targets API 36.
The initial release-mode, debug-signed review APK is the S4 artifact with SHA-256
`2b811bcce49747ae064bec0307b90d873f9758b47a17976df749149f89074484`.
The follow-up verification JSON distinguishes this initial build from the
corrected build and records exact artifact/source/check identities.

Machine-readable record:
[Android device verification](focus-sounds/SESSION_4_ANDROID_DEVICE_VERIFICATION.json).
[Follow-up source identity](focus-sounds/SESSION_4_ANDROID_SOURCE_MANIFEST.json)
records current application/native/assets/test/build/helper hashes. Exactly three
mobile source/test inputs changed after the original snapshot; unrelated native,
assets and dependency inputs retain their previous evidence scope. Fifty
assertions over the captured states pass; these are scoped assertions across the
pre-fix and corrected builds, not fifty independent physical trials.
Raw app-only UI XML, screenshots, actions, native service/session/track observations,
logs and resource samples are retained in ignored
`artifacts/focus-sounds/session-4/android-device-20261109/`.
The evidence index records file hashes. No lock-screen or unrelated-app screenshots
are retained. ADB is used without root, security bypass or microphone access.

## Observed behavior before the alert correction

- Fresh app: Off, 35%, unmuted, ready timer and empty completion history.
- All four bundled previews reach native Android playback. Three timed previews
  end and release media/focus residency; dismissing Forest birds stops its preview.
  Choosing a sound while ready remains silent and previews earn no focus time.
- Focus start, pause, explicit resume, reset and skip control playback correctly.
  Breaks stay silent, including after media Play. Media Pause affects sound while
  the timer continues; media Play cannot resume a paused timer or override mute,
  zero volume or an expired session.
- Actual slider endpoints/midpoint reach 0% and 50%. Waterfall/50%/mute survive a
  force-stop and cold relaunch. Cold launch does not authorize sound.
- A rapid Tibetan bells -> Waterfall -> Off sequence finishes in about 175 ms
  and remains stopped. Selecting Waterfall during a running Focus explicitly plays.
  Preview/dismissal during Focus is checked after the native loading window;
  the preview and restored source have the correct generic media metadata and
  their own active AudioFlinger track.
- Strict mode disables timer controls while mute/unmute and sound selection stay
  available. Reset/skip/media/preview actions do not add completions. Three
  completed one-minute trials are observed as exactly three sessions/three minutes;
  later alert comparisons add their own legitimate completions.
- With the screen locked/Dozing, native playback, media service, audio focus and
  the bounded partial wake lock remain active. In the 60-second run they are
  active at 59.400 seconds and stopped by 61.392 seconds without reopening the app.
  The own-process audio track and wake lock are absent after expiry. These are
  polling bounds, not speaker latency.
- Navigation and Home preserve a settled Ocean waves source. Another 60-second
  background run remains playing at 55 seconds and stops by 61 seconds. Unlock/
  return shows a Ready break; expired media Play and cold relaunch stay silent.

The phone's speaker media stream was muted at zero. A temporary low-volume request
still reported zero; the original zero setting was explicitly restored. The user
chose **"Continue the device checks; I'll listen later"**. These observations prove
native backend/state behavior, not audible quality, balanced loudness, loop joins
or actual speaker silence. No listening approval is inferred.

Initial short-delay snapshots captured PAUSED during asynchronous source loading.
Later native-track snapshots confirm correct playback/restoration. The helper now
waits for both PLAYING and the expected sound metadata; an old source's PLAYING
state cannot satisfy a replacement check. Initial snapshots and the onboarding
fixture failure are retained rather than discarded.

## Completion-alert regression and correction

The first-use completion-alert prompt was declined. Timer/audio operation works
without notification permission. Notifications were then enabled for this review
app through the Android permission prompt. Precise-alert access was initially off;
the review app's specific Android setting was temporarily enabled for a controlled
comparison, without changing production Poma's permissions.

The comparison exposed a feature regression:

1. With Ocean waves playing and precise access allowed, the media notification
   uses ID **-1124**, channel `poma_focus_sounds_v1`. The audio retires at its
   deadline, but no completion notification remains at 61/66 seconds.
2. With sounds Off and the same permissions, completion notification ID **3** on
   `poma_timer_completion_v1` is present at 61 and 66 seconds before app reentry.
3. Native audio expiry immediately called the shared timer reconciliation path.
   That advanced the timer/outbox and cancelled the independently registered
   completion request before its Android receiver could leave a visible alert.

The new regression test fails before the fix because the pending OS request has
been removed. Its retained log is
`artifacts/focus-sounds/session-4/checks/focused-1794205317670938700.log`.

The correction is confined to
`mobile/lib/application/focus_audio_coordinator.dart`: mobile continuous-audio
expiry disarms and releases audio without initiating a timer reconciliation.
The existing foreground ticker, resume and explicit timer actions remain the
timer/history owners, matching the pre-feature silent-background behavior.
Desktop expiry retains immediate reconciliation for resident completion alerts.
No native alert receiver, IDs, database work queue, alarm registration or accounting
rule is replaced. Resume still records one completion and leaves the next phase Ready.

The test uses the real shared controller/coordinator plus an independent fake OS
alert port to assert that audio stops while the already registered completion
request survives until normal reconciliation. It also verifies exactly one history
completion after return. The existing mobile expiry fixture now explicitly returns
to the foreground before asserting reconciled timer/history state.

Formatting, analysis, all **541 Flutter regressions** and **69 focused audio/UI
checks** pass after the correction. Fresh Windows release and Android review
builds pass. The corrected APK is 36,117,169 bytes, SHA-256
`2523f4f46e1f42a20b08e40b2dc99fd1c1bf272fcaf5930d939a8d7df1ba9a5c`.
It was installed only over the separate review package; its test preferences and
five completed minutes survived the update.

The corrected phone run (`300`-`313` evidence) uses Ocean waves, one minute,
notifications allowed and precise access allowed. Native playback remains active
after navigation/Home at 55 seconds, and retires by the 61-second observation.
At the 66-second observation, **completion notification ID 4** on the existing
`poma_timer_completion_v1` channel remains visible, with media ID -1124 gone.
The native track and partial wake lock are absent. This is captured before app
reentry. Return leaves a Ready break and advances history from exactly five to
six one-minute sessions. The original failure, silent comparison and successful
corrected-build retest remain separately identified in the verification record.

## Restart, reset and final phone state

Active Ocean waves playback was force-stopped in the review package; its service,
MediaSession and audio focus retire. The resource helper originally treated
Android's expected `pidof` exit 1/no process as a fixture failure. The helper was
corrected to allow that specific empty result; no process/wake lock was confirmed.
That first cold reopen occurred after the one-minute deadline, so the timer
legitimately recorded the seventh completed minute and stayed silent. The saved
`334-force-no-new-completion` filename predates that observation; its actual UI
shows seven. It is not used to claim that completion was suppressed.

A fresh three-minute trial (`337`-`350`) repeats active force-stop and immediately
cold-reopens before expiry: the timer restores Running with 2:57 remaining,
**Sound paused**, and no active audio service/focus. Reset stops the timer without
changing seven sessions/seven minutes. Explicit termination does not promise
background service or alert survival.

The app's own **Delete all local data** confirmation was exercised only in the
review sandbox. It stops audio and restores **Off / 35% / unmuted / strict off**,
**25-minute Ready / zero rounds**, and empty tasks/history. Temporary review-only
notification permission and precise access were then restored to their initial
**denied / off** states. The final precise UI and appop report off/deny, and the
review package dump reports notification permission denied. No stale review
notifications remain. Cold reopen stays silent with default preferences.

The installed APK's bytes were read back through ADB and match the corrected
SHA-256 above (`383-installed-apk.json`). Production `dev.poma.poma` remains
installed; no operation targeted its data or permissions. Global media volume is
the original **0/15**. Captured final own-process logs have no matched fatal,
security, service-start or native-load error. Default Focus and lower-chooser
screenshots (`377`, `370`) were inspected: controls are readable/reachable at the
current phone settings. This does not establish TalkBack or enlarged system text.

## Resource scope and remaining acceptance

The locked Waterfall run has PSS samples of 104,236 / 102,376 kB at 10/30 seconds
and 94,829 kB after stop at 64 seconds. Own-process CPU totals, RSS, memory details,
threads and audio-track/wake-lock state are retained. CPU totals have one-second
resolution; no precise rate, energy, battery-life or unplugged measurement is claimed.
The USB/ADB connection and phone networking were retained during automated checks.

Still required from a human/device tester:

1. User/listener: open **Poma Sounds Review**, raise media volume manually from
   its current zero when ready, preview each draft and listen on speakers/headphones
   for ten minutes/five natural joins per candidate. Record loudness, peaks and bell
   decays; approve/replace drafts and repeat backend verification after replacements.
2. Android tester: use a fresh review test-user sandbox with Wi-Fi/mobile data off
   before first launch, confirm all assets/notices, then unplug USB/debug tools.
   Explicitly start Focus and repeat playback and locked deadline checks offline.
3. Android tester: while Focus plays, trigger real calls/other media and remove
   wired/Bluetooth output. Interruption end/reconnection must remain stopped until
   an eligible explicit Play; mute/zero/expiry must still win. Repeat near expiry.
4. Android tester: test task removal, TalkBack labels/focus/slider operation and
   actual 100/150/200% system text sizes. Preserve the
   documented OS/OEM/force-stop limitations; no reboot/sticky playback is promised.
5. Complete the remaining Windows physical/listening/clean-account checks and
   unavailable Mac/Xcode/iPhone compilation/signing/device acceptance.

The feature is not globally accepted or published by this phone run. The tracker
retains all 59 requirements and their platform scopes.
