# Focus sounds — Session 2 implementation and handoff

8 November 2026, Asia/Kolkata. Starting branch `codex/focus-soundscapes`, HEAD
`6bd18d3e10f348a5b9d5e4958203fc934b3e24fd`, clean. Session 2 changes are local
and uncommitted. No installation, merge, release, or publication is included.

## Implemented ownership and storage

The composition root owns one `FocusAudioCoordinator` and one
`SoLoudFocusAudioPlayback`. `AppController.focusAudio` exposes that application
service for Session 3; screens never construct or dispose players.

`AppController` publishes accepted timer snapshots synchronously before starting
the associated persistence/alert synchronization. Events carry the real sampled
clock, timer outcome, run ID, segment and absolute elapsed deadline. Initial
reconciliation is labelled restoration. Clock failure immediately revokes audio.
Display ticks update the cached reading without restarting audio or writing prefs.

`FocusSoundPreferences` is immutable pure Dart. Optional `app_state.focusSounds`
contains version 1, sound ID, volume and muted. Defaults are Off / .35 / false.
Missing fields default; malformed present values or unsupported versions fail
closed to Off without invalidating the main database. SQLite remains schema 3,
using the existing incremental writer and atomic scalar snapshots. Core timer,
history, receipts and migration rules are unchanged.

Selection/mute save immediately; slider changes affect live gain but save at
interaction completion. Keyboard input coalesces after 300 ms. Dismissal,
backgrounding and Quit flush staged volume. Save failures retain the existing
AppController warning and retry/discard policy. A save callback never starts audio.

Full reset synchronously invalidates audio, queued preview restoration and staged
volume. Composite cleanup preserves the existing Calendar participant. The reset
transaction clears the optional namespace; late loads cannot restore old settings.

## Playback and cancellation contract

Authorization, preferences, actual transport, previews and interruption gates are
separate. Only a clock-valid, unexpired running Focus with matching armed run and
segment may play continuously. Cold recovery is silent, even with enabled saved
preferences. Explicit selection during running Focus, accepted start/resume or
Play sounds can authorize output; none can override mute, zero, Off or a blocked
platform gate. Breaks remain silent, including previews.

Mute preserves gain; unmute restores that exact gain including zero. Music APIs
do not call timer controls or earn focus. Strict timer restrictions remain intact.

There is one coalescing playback lane and at most one native preparation in
flight. Revocation silences the known voice synchronously without waiting for
loads or writes. Generations invalidate stale loads/events; resource references
protect a newer consumer of the same backend source. Loads time out after ten
seconds; their eventual result remains observed and released. No automatic retry
loop exists. Retry is a new explicit action. Native-deadline rejection is normal
cancellation and reconciliation, rather than a spurious playback failure.

Normal replacement is sequential: 200 ms fade out, old voice retirement, then
600 ms fade in. Urgent mute/Off/reset/expiry/route/Quit stops win immediately.
Native scheduled fades finish at the lease deadline. Sources unload on stop;
the idle engine deinitializes after five seconds. Extracted bundled assets are
the backend's bounded temporary cache, not user data or a network cache.

Previews do not change selection. They use one voice for at most ten seconds,
shortened by a running Focus deadline. Replacement previews retain the original
restoration token. Timeout/dismissal restores only unchanged run/segment/intent
and current eligible preferences after fresh reconciliation. Start, pause, reset,
completion, mute, Off, interruption or Quit cancels preview restoration.

## Windows implementation and evidence scope

The runner exports a private guard ABI for the exactly pinned SoLoud 4.1.7
renderer exports. Native wire authorization uses the unique operation generation
representing the application lease; the application retains run/segment identity.
The guard validates its platform epoch and `QueryInterruptTimePrecise` deadline
before unpausing a zero-gain voice. A one-shot worker and native renderer cap stop
output independently of Dart, foreground ticking, alert permission or DB writes.

`PowerRegisterSuspendResumeNotification` pauses output natively. Resume never
unpauses it: the controller must reconcile before a new voice is bound.
`IMMNotificationClient` callbacks are nonblocking, invalidate the route epoch and
signal native handling. Playback binds a concrete enumerated output device;
automatic default-device fallback is not requested. Route change requires explicit
Play sounds. The guard unregisters callbacks and joins native work before renderer
deinitialization. No audio during system sleep is claimed.

The desktop visibility policy is explicitly injected, independent of completion
alerts: hidden/tray Windows playback continues; the mobile interim policy stops
on background entry. Quit revokes before Calendar/storage waits, handles existing
save/discard consent, and releases audio before repository closure and native exit.
Cancelling Quit stays silent until an explicit playback action.

The review target has a separate profile, mutex/pipe, tray GUID and notification
CLSID. Its native hooks are compiled only for that target. The collector checks
the executable's isolated identity before launching a copied runtime, controls
only its owned processes, and never renames or opens an installed profile.

See `focus-sounds/SESSION_2_VERIFICATION.json` for actual checks and resource
results, and `focus-sounds/SESSION_2_SOURCE_MANIFEST.json` for source identity.
Full successful and failed logs remain under ignored
`artifacts/focus-sounds/session-2/`. Results distinguish a synthetic renderer,
real unpackaged production-adapter playback, builds and physical observations.

Physical sleep/wake, output removal, Bluetooth and subjective listening are
pending. Windows has no universal competing-application/call focus callback;
the implementation does not claim to detect every such interruption.

Primary native references:
[suspend/resume registration](https://learn.microsoft.com/en-us/windows/win32/api/powerbase/nf-powerbase-powerregistersuspendresumenotification),
[endpoint callbacks](https://learn.microsoft.com/en-us/windows/win32/api/mmdeviceapi/nn-mmdeviceapi-immnotificationclient),
and [continuous Windows clock](https://learn.microsoft.com/en-us/windows/win32/api/realtimeapiset/nf-realtimeapiset-queryinterrupttimeprecise).

## Verified Session 2 checkpoint

- Formatting and analysis are clean. **507 regression tests** and **35 focused
  audio tests** pass. The latter include load timeout, late disposal, final slider
  persistence, real v1/v2 SQLite upgrades, strict timer controls and a reproduced
  older-resume/newer-interruption race. That race failed before the fix and passed
  after interruption tokens were revalidated and consumed after reconciliation.
- **233 desktop**, **43 font** and **15 synthetic audio-guard checks** pass.
  Production Windows release, isolated Windows review and Android arm64 debug
  builds pass. No dependency/SDK upgrade or new mobile service permission was made.
- The final copied Windows release review passes **32 real playback checks** and
  **four cold-relaunch/reset checks**. Four assets load, native loops wrap, gain
  and persistent zero/mute work, native tray pause/resume and hidden/navigation
  continuity work, and previews restore only eligible continuous playback.
- Simulated power/route notifications exercised the real native renderer. The
  final guard retirement attempt was observed **602 microseconds after its
  deadline** while Dart was blocked; output was stopped when Dart returned.
  This is not measured physical speaker latency or a physical sleep observation.
- Exact draft hashes and both notices match source in fresh production Windows
  and Android payloads. Audio assets total **3,194,230 bytes**; the seven bundled
  audio DLLs total **3,665,408 bytes**. These are file inventories, distinct from
  Session 1's matched no-audio delta. Production Windows runtime files excluding
  PDB/linker artifacts total **45,489,921 bytes**. The fresh Android debug APK is
  **105,489,164 bytes**; this is not a release/store size.
- `poma.lib` (2,680 bytes) and `poma.exp` (1,362 bytes) are build-only export
  artifacts, excluded from the runtime-size figure; final release staging should
  omit them along with debug artifacts. No release staging or publication occurred.

Matched resource observations use one isolated release process on Windows 11
10.0.26200, hidden throughout via the existing startup visibility flag. No OS
startup setting was changed. Default output endpoints were recorded as hashes
without personal device names. The three windows were 60 / 120 / 60 seconds;
actual sampled spans were 59.67 / 119.66 / 59.46 seconds at approximately 0.5 s.

| Window | CPU, percent of one core | Median working set | Handles | Threads |
| --- | --- | --- | --- | --- |
| Off idle | 1.31% | 105.0 MiB | 479-487 | 34-40 |
| Playing | 1.66% | 91.4 MiB | 550-562 | 35-41 |
| Post-stop idle | 0.79% | 74.6 MiB | 508-534 | 31-33 |

Engine/source release is separately asserted after the idle grace period.
Startup/cache/GC effects are included; working-set differences are not isolated
audio overhead, steady-state/battery guarantees or phone results. Earlier failed
and intermediate runs remain in the verification record with distinct executable
and Dart AOT identities. Only the final hidden matched run represents this source.

## Session 3 consumption

- Obtain `controller.focusAudio`; subscribe to the coordinator's ChangeNotifier
  and render immutable `state` alongside the real timer phase/status.
- Use `selectSound`, `playSounds`, `pauseSounds`, `setMuted`, and `retry`.
- Use `setVolume(value)` during drag, `setVolume(value, commit: true)` at drag
  end, and `keyboard: true` for keyboard coalescing. Call `flushPreferences`
  when closing the chooser, even if no preview was started.
- `preview(sound)` returns a nullable token. Close only that preview with
  `dismissPreview(token)`; an older chooser cannot stop a newer preview.
- Distinguish saved selection from loading/playing/error, persistent mute/zero,
  route block/interruption, paused timer, breaks and intentionally silent recovery.
- Build the planned compact control and adaptive chooser. Preserve the celestial
  theme, fonts, strict-mode boundaries and accessibility requirements. No product
  sound UI or visual acceptance is claimed by Session 2.

## Session 4 boundary and remaining acceptance

Mobile playback currently fails safely before opening a renderer; it is not a
foreground-only approximation of background support. Session 4 must supply the
custom audio_service handler, audio_session policy and native expiry guard before
enabling Android/iOS playback. Use the same lease and existing native continuous
clocks, one engine/controller/database owner and independent completion alerts.
Do not add background polling or a second countdown/history writer.

On physical Windows hardware, run the isolated developer target, select a track
and start Focus. Test sleep/wake both before and across expiry; mute/reset during
interruption; wired/Bluetooth removal; route changes; repeated tray commands; and
Quit. Record hardware/OS/build, route, timing, exact hashes and observed output.
An expired/muted/reset run must stay silent after wake or late callbacks.

For listening acceptance, use the retained eight comparisons, then audition each
proposed winner for ten minutes and at least five natural joins on headphones and
speakers. Record listener and exact hashes separately. Forced seeks, numerical
seam diagnostics and successful builds do not establish natural joins or equal
perceived loudness. Final assets remain drafts and Session 1 S1.3 stays pending.
