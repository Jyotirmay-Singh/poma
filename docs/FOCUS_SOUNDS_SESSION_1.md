# Focus sounds — Session 1 record and implementation contract

8 November 2026, Asia/Kolkata. Baseline: `0a001d2b37e80c316449898de7419e50e18d1547`.
Feature branch: `codex/focus-soundscapes`. This is Session 1 only: acquisition,
preparation, an isolated compatibility experiment, architecture and design.
Production playback, preferences, UI and mobile services are not implemented.

## Observed source ownership

`TimerEngine.apply` / `reconcile` are synchronous over one supplied `ClockReading`.
The engine owns focus/break × ready/running/paused, unique completion, strict-mode
restrictions and ready successors. `TimerSnapshot.runId` identifies the session;
`segment` changes on resume. `elapsedDeadlineMicros` is the live sleep-inclusive
deadline; the fixed UTC deadline preserves history/recovery semantics. Do not use
the display's rounded seconds or notification identity as audio authority.

`AppController._enqueue` samples the clock and applies transitions in command
order. Insert the future audio event after snapshot capture and before `_persist`;
audio cancellation must not await a database write or native alert synchronization.
The new audio work lane must not hold up `_commands`. `setForeground(false)`
cancels `_ticker`; the foreground ticker cannot implement background expiry.

`SavedState`, `LocalChange` and `SqliteRepository.commit` own schema-v3 scalar
state and serialized incremental saves. Add an optional `focusSounds` app_state
entry through this same writer, following the existing `windowsDesktop` pattern.
No extra database owner, SQL schema version or history field is needed. Preserve
v1/v2 upgrades, native notification tables/receipts and reset cleanup barriers.

`AlertCoordinator`, `NativeLocalAlerts`, `PomaAlerts.kt` and `PomaLocalAlerts.swift`
retain completion-alert ownership. Sound must stop even with alerts disabled.
Android samples `elapsedRealtimeNanos`; iOS samples `CLOCK_MONOTONIC_RAW`.
Existing alarm/response receivers do not provide continuous background playback.

Windows `DesktopController` publishes the real controller snapshot and routes
revision/run-checked tray commands. `NativeWindowsHost.armDeadline` sends run ID
and elapsed deadline to `DesktopHost`; `QueryInterruptTimePrecise` includes sleep.
Hidden awake expiry reconciles independently of display refresh. Suspend/resume
requires re-arming from the real clock. No playback during Windows sleep is promised.
`DesktopController.quit` drains saves, handles discard consent, cancels deadlines,
closes storage and exits. Audio must revoke immediately and await cleanup there.

`PomaLoader` composes platform services. `FocusScreen` is a projection, not an
audio owner. Its desktop split threshold is 900 logical units with text scale
at most 1.4. Existing Sora/Source Sans 3, celestial sky and minimum 48-unit targets
remain authoritative. Historical baseline captures were reviewed; no production
sound UI has been rendered.

## Dependency evidence and decision

Retain Flutter 3.44.2 / Dart 3.12.2, Android minimum 24 / target 36 / Java 17,
iOS 13 and SwiftPM. The installed Flutter metadata matches this baseline.

The proposed **flutter_soloud 5.2.3 fails actual dependency resolution**:
its native_toolchain_c ^0.19.4 requires meta ^1.19.0, but this Flutter SDK pins
meta 1.18.0. Headline SDK compatibility was insufficient. No override or SDK
upgrade is permitted to conceal this conflict. Pub recommends SoLoud 4.1.7.
Version 4.1.7 resolves on the pinned SDK and passed the real Windows experiment;
retain it, with just_audio as the documented fallback. This is a deliberate deviation
from the provisional 5.2.3 version, preserving the approved engine capabilities
without changing unrelated application dependencies.

| Candidate | Native support / controls | Cost and qualification |
| --- | --- | --- |
| SoLoud 4.1.7 | Windows/Android/iOS; native loop, per-voice volume/fade, scheduleStop; MIT wrapper / zlib engine plus bundled codec licenses | One renderer API; OS focus/background handling remains explicit. Its scheduled stop follows voice/render time, not Poma's continuous clock. Old CMake packaging must be checked. |
| just_audio 0.10.6 + just_audio_windows 0.2.3 | Mobile native players; separate WinRT Windows backend advertises loop/gapless | Fallback if the SoLoud experiment fails. Qualify PCM WAV first; Windows codec support cannot depend on a Store codec download. Native fade/deadline integration remains required. |
| audioplayers 6.8.1 | All targets; asset play/loop/volume | SDK constraints fit, but backend parity, seamless joins and background policy still need qualification; not selected merely for a smaller API. |

Use audio_session 0.2.4 and a custom audio_service 0.18.19 handler for future
mobile integration. The custom handler controls session-bound media actions and
preview restoration; just_audio_background's simpler automatic wrapper is not
the selected ownership model. No mobile service is started by Session 1.

Primary references checked during planning and acquisition:

- https://pub.dev/packages/flutter_soloud and the exact published package API
- https://pub.dev/packages/just_audio and https://pub.dev/packages/just_audio_windows
- https://pub.dev/packages/audioplayers
- https://pub.dev/packages/audio_session and https://pub.dev/packages/audio_service
- https://pub.dev/packages/just_audio_background
- https://docs.page/alnitak/flutter_soloud_docs/get_started/audio_context
- https://developer.android.com/media/optimize/audio-focus
- https://developer.android.com/develop/background-work/services/fgs/service-types

The experiment's lockfile and installed published sources, rather than latest
documentation alone, define the APIs used in the result. Actual results below
supersede provisional recommendations.

## Audio assets, rights and editing

[ASSET_PROVENANCE.json](focus-sounds/ASSET_PROVENANCE.json) records eight original
WAV acquisitions, their exact measured media identity, creator/source/license,
retained evidence hashes, edits, encoder, draft file hashes and byte counts.
Catalog durations differ slightly from decoded originals; measured durations are
authoritative for edits. Original WAV metadata also identifies the provider and
CC0/WTFPL/public-domain rights. No preview MP3 was used as a master.

BigSoundBank's exact recording pages explicitly permit processing, editing and
redistribution in apps, including commercial use. The provider identifies CC0
1.0 Universal; voluntary credits will remain. Original page bodies stay in ignored
artifacts, with extracted page text and CC0 legal code retained under
[license-evidence](focus-sounds/license-evidence/). Full-response and retained-text
checksums distinguish these representations. No provider API or account is used.

The Freesound BurghRecords seed is CC0 but original acquisition requires login.
No account was created, login bypassed or preview substituted. Forest #3 and #4
provide two accessible CC0 original comparisons instead. Freesound recording
rights and API terms remain distinct; Poma adds no runtime Freesound integration.

| Category | Prepared comparisons | Provisional bundled candidate; not a listening winner |
| --- | --- | --- |
| Tibetan bells | Joseph Sardin #1110 / #2553 | #1110; full decays, three strikes at 3/43/83 seconds in 120 seconds |
| Waterfall | gamin #0219 / #0213 | #0219; stable middle region with two-second wrap transition |
| Ocean waves | DenisChardonnet #0265 / Joseph Sardin #1447 | #0265; middle region with three-second wrap transition |
| Forest birds | Pierre Sibanarco #2715 / Joseph Sardin #2749 | #2715; accessible original, two-second wrap transition |

`scripts/acquire_focus_sounds.py` follows the public WAV download form and its
required five-second wait. `scripts/prepare_focus_sounds.py` records all encoder
commands and prepares deterministic 48-kHz, 24-bit PCM working masters plus
Vorbis quality-4 drafts. Ambient regions are rotated and crossfaded tail-to-head;
bell decays are not overlapped. Ambient two-pass normalization targets -23 LUFS-I with
-3 dBTP headroom; encoded true peaks must remain <= -2 dBTP. Bells use constant gain only, preserving their complete dynamics; gated bell loudness
is recorded, not artificially equated with a constant noise bed. Raw/working
files and the portable preparation tools are not app payload.

These measurements do not certify a natural join or equal perceived loudness.
The chosen format is provisional until the actual backend and listening pass.
No universal "most relaxing" or therapeutic claim is made.

### Outstanding listening gate

The agent has not auditioned recordings. Use the eight matched files under
`artifacts/focus-sounds/session-1/comparison` in fixed-output-level A/B trials.
For each category, listen to both candidates for texture and distracting events,
then listen to the proposed winner for ten minutes and at least five natural
joins on headphones and speakers. Bells require a separate active-passage loudness
comparison. Record listener, date, exact hashes, playback backend/output, reasons
for choosing/rejecting, join observations and fatigue/peak observations.
Reject speech, traffic, wind buffeting, harsh splashes/crashes, piercing close
calls or repetitive alarm calls. If neither passes, retain both as rejected and
acquire another suitable licensed recording. Do not green A01/A04/A05/A07 from DSP.

## Session 2 interfaces and policies

The following are proposed production types, not implemented Session 1 symbols:
`FocusSoundId`, `FocusSoundPreferences`, `FocusAudioSessionEvent`, `FocusAudioLease`,
`FocusAudioCoordinator`, `FocusAudioPlaybackPort`, real adapter and controllable fake.

Preferences default to Off / volume 0.35 / muted false. Invalid audio preferences
disable sound without invalidating core data. The existing writer persists changes;
volume persistence happens at interaction completion, never per timer tick.
An ephemeral armed-run intent is never restored from disk. Cold launch is silent.

The composition root owns the coordinator. It consumes events carrying the real
snapshot, explicit action/cause and clock-validity status. Deduplicate by run,
segment, phase/status, elapsed deadline and invalidation epoch, ignoring display
ticks and rounding. Emit immediate reset invalidation before queued reset IO.
The coordinator's prepare/play/fade/stop/dispose work runs outside the timer lane.
The port reports loading/playing/stopped/interrupted/route-loss/expired/error with
generation and resource identity. Late loads dispose only their obsolete resource.
Stop invalidates immediately and cannot queue behind a slow load. Keep at most
one audible voice, bound prepared sources and release them when idle.

| Action/state | Contract |
| --- | --- |
| Select Off | Stop preview/continuous audio; persist Off, retain volume/mute. |
| Choose during running Focus | Arm the current run/segment; respect persistent mute and zero volume. |
| Choose ready/paused | Save only; continuous audio waits for explicit Focus start/resume. |
| Focus start/resume | Arm current valid session; play only selected, unmuted and nonzero. |
| Pause/reset/skip/completion/reset-all/Quit | Pause/release or stop immediately; invalidate restoration before async cleanup. |
| Breaks | Silent, including previews; selection/volume/mute may be edited for next Focus. |
| Cold running restoration | Reconcile silently; labelled Play sounds or another explicit permitted action is required. |
| Media Pause/Stop | Affect sound only, not timer state/history or persistent selection. |
| Media Play | Only a reconciled unexpired running Focus; cannot start a timer or successor and cannot override mute/zero. |
| Other audio | Pause Poma on platform focus loss, including duck requests; Windows lacks a universal equivalent, so document observed coverage. |
| Temporary interruption ends | Resume only when OS permits and run/segment/generation/selection/route/deadline remain valid. |
| Output/headphone/Bluetooth loss | Stop; no automatic speaker fallback. Require explicit playback action. |
| Error | Stop safely, retain selection, show contextual Retry; leave timer/tasks/history/alerts working. |

Previews never select or earn focus. A preview has at most ten audible seconds,
or the remaining Focus lease if shorter. A new preview, dismissal, timer action,
mute, Off, expiry or reset ends it. Restore previous continuous audio only with
the unchanged run/segment/intent token and current eligible preferences. Volume
changes apply to restoration; old mute/gain is never restored. Muted/zero preview
controls explain the required adjustment rather than silently overriding it.
Use a 600-ms start fade and sequential 200-ms switches. Completion fade finishes
at the deadline. Urgent stops take priority over the natural bell decay.

## Background expiry and platform qualification

Use the real absolute elapsed deadline, regardless of completion-alert settings.
Windows retains its existing native trigger and adds a native-renderer stop cap.
The mobile audio handler owns a one-shot expiry derived from the same deadline,
stops output before requesting controller reconciliation, and never writes history.
The renderer's scheduled stop is a second stop mechanism: its voice clock is not
the OS continuous clock. Every resume/re-route must reconcile before output.
Reject a backend configuration that automatically resumes an expired voice before
validation; add the necessary native guard before mobile acceptance.

Android needs an audio_service foreground mediaPlayback service, appropriate
permissions and active-playback-only wake lock. API-35+ focus requests require
foreground eligibility. Retain MainActivity clock/alert hooks when changing its
superclass; reuse the one engine/controller/database owner. No idle polling,
boot autoplay, battery-exemption request or microphone permission is allowed.
iOS needs audio background mode and explicit audio-session/interruption setup,
preserving implicit-engine registration, backup exclusions and notification delegate.
Existing completion alerts and consent are unchanged.

Session 4 must observe on real devices: offline first playback, locked expiry,
interruption across expiry, user mute/reset during interruption, wired and Bluetooth
removal, media Play on ready/break/expired state, ordinary termination versus
force-stop/force-quit, significant time change and cold recovery. Record exact
device/OS/build/asset hashes, notification/focus settings and output route. Windows
sleep/wake is a separate observed gate. A desktop loop or build proves none of these.

## Original UI specification for Session 3

References: Forest (https://www.forestapp.cc/), Pomofocus (https://pomofocus.io/),
Tide (https://tide.fm/en_US/). Borrow restraint and discoverability, not identity,
art, trees, rewards, layouts or gamification. Poma's instrument-like countdown
remains the only visual emphasis. Keep the still sky and Sora/Source Sans 3.

Place a compact, opaque Focus sounds control below timer controls and phase hint,
before task details; keep it in the timer column on a split desktop layout.

```text
             25:00
           Start focus
           Reset   Skip
        Existing phase hint

  Focus sounds                         [Mute]
  Ocean waves · Playing                    >
```

The text target opens the chooser; direct mute has its own 48-unit target. Show
Play sounds when a restored running session is intentionally silent. Status copy:
Off; Selected; Playing; Paused; Muted; Volume 0%; Silent during break; Loading
Ocean waves…; Sound couldn't play / Retry. Selection and actual output are separate.

```text
Focus sounds                            Close
Only during Focus
○ Off
○ Tibetan bells     Soft bowl tones       Preview 10 s
○ Waterfall         Gentle flowing water  Preview 10 s
● Ocean waves       Slow, small waves     Preview 10 s
○ Forest birds      Quiet woodland        Preview 10 s
Volume                                    35%
[────────●──────────────────────────────────]
[Muted / Unmuted]                         Done
```

Below 700 units, use a safe-area scrollable bottom sheet capped at 90% viewport
height. On desktop use an opaque centered dialog up to 560 units, bounded by
viewport height. Four options may form two columns only with at least 480 units
of content width and text scale <=125%; otherwise use wrapping single-column rows.
At 150%/200% scale stack controls as needed; do not clamp text scaling. Keep Off
obvious and full width. Use coherent built-in outline icons, not new decorative
imagery. PomaSpace 4/8/12/16/24/32/48; control radius 8; panel radius 12.

Responsibilities: compact control projects state; adaptive chooser owns only its
preview-dismissal token; option row separates selection from preview; coordinator
owns players and restoration. Widgets perform no IO on build. Strict mode leaves
music controls operable without calling restricted timer actions.

Critique before implementation: adding nature picture cards or a large player
would compete with the dial and imitate reference apps, so neither is included.
The compact row uses explicit text instead of a continuous equalizer. Check light,
dark and plain high-contrast surfaces; >=4.5:1 readable text and >=3:1 essential
controls; non-color selection; visible focus; Tab/Shift-Tab/Enter/Space; slider
arrow/Home/End input and percentage semantics; Escape/Back cleanup and focus
restoration. Test 320/390-unit phones, landscape, 700/1024/1440 desktop widths,
100/150/200% text, reduced motion, loading/muted/paused/error states and long labels.
Real rendered captures with bundled fonts and screen-reader/device observations
remain Session 3/4 work, not completed design evidence.

## Failures, checks and handoff

Actual results and exact artifact inventory are appended after the experiment.
The tracker distinguishes source, working playback, listening, visual and device
acceptance. No failed attempt is replaced by an inferred pass.

Preparation failure: the initial FFmpeg 9.0.2 bell graph with unbounded apad and
time-based atrim emitted an unexpectedly large temporary WAV and exhausted the
available workspace volume. That one task-created intermediate was removed after
verifying its resolved workspace path; originals and profiles were not altered.
The corrected graph uses finite sample counts plus output duration/size caps and
a subprocess timeout. This failure is retained instead of hidden by the rerun.

Session 2 starts with the qualified exact backend/lockfile and the draft asset
hashes, then implements the production coordinator/adapter/fake, preferences,
transition feed and Windows lifecycle. Required tests: A→B→Off; stop during load;
reset/completion after callbacks; same run/new segment; preview restoration and
invalidations; muted/zero cold recovery; strict mode; independent alerts; failure,
reset and disposal; no tick-triggered audio work or writes. Resolve a failed
backend first. Draft assets may support core implementation, but cannot be called
final or release-ready while listening and device gates remain pending.

### Verified Session 1 checkpoint

- Selected **flutter_soloud 4.1.7** on the unchanged SDK. All **75** previously
  locked packages are preserved; 12 new packages are recorded in VERIFICATION.json.
- Real Windows MiniAudio backend opened one available output device. **88 checks
  passed**: four asset loads, volume/fades, pause, 20 forced loop-wrap observations,
  stop/dispose, own-window hiding, native expiry, blocked-Dart expiry, rejected
  paused-session restoration and 20 start/stop repetitions. Hidden native voice
  retirement was observed at **+9,165 microseconds** in this one run. This is a
  transport observation, not measured physical speaker latency or listening.
- Three experiment lease tests passed; experiment and application analysis are
  clean. **472 Flutter tests passed**. Windows native suites, Windows release
  compilation, Android arm64 debug compilation and Android JVM task passed.
  Upstream C++/Gradle warnings remain recorded in the logs, not patched broadly.
- Four exact draft recording hashes, both notices and audio runtime components
  were verified inside the Windows release bundle and fresh Android debug APK.
  The APK is **105,093,089 bytes**, SHA-256
  `c326b6a162a5849426c4d52a57fa88bd40b7975ccebbbd826335bd470d58b816`.
  This is a debug artifact, not a release/store size. Its permission inventory has
  no microphone or media-service/wake-lock permission; debug INTERNET is retained.
- Draft audio totals **3,194,230 bytes**. Matched Windows experiment runtime totals
  are 27,195,300 bytes baseline, 31,206,150 library/probe, and 34,400,618 with assets.
  Native library/probe overhead is **4,010,850 bytes**; adding recordings and asset
  metadata is **3,194,468 bytes**. Library/assets builds use identical final probe
  code and lockfile. This is unpackaged x64 release evidence, not MSIX compression.
- One 81-sample experiment run peaked at 70,471,680 working-set bytes and
  72,192,000 private bytes. Pre-initialization idle median working set was
  63,787,008 bytes; active qualification with forced seeks was 68,497,408 bytes.
  CPU observations were about 2.88% / 2.40% of one core over their stated short
  windows. Startup and seek work are included; no battery/steady-state claim follows.

Compact results: [VERIFICATION.json](focus-sounds/VERIFICATION.json). Source identity:
[SOURCE_MANIFEST.json](focus-sounds/SOURCE_MANIFEST.json). Full logs, original WAVs,
masters, comparison files, three bundle inventories and resource samples remain
under ignored `artifacts/focus-sounds/session-1/`. The spike's baseline input
fixtures are also retained in source so the no-audio comparison can be reproduced.

Additional corrected failures: the first clock FFI lookup used kernel32 instead
of kernelbase and produced an uncaught setup exception. The owned child was
bounded/killed by the experiment timeout; the failure log is retained. Setup now
reports failure safely and uses the correct DLL. The initial pub-get link failure
left an empty native registrant; this was detected before qualification and fixed
with junction preparation and successful locked resolution. A premature APK check
rejected a stale pre-feature artifact; the fresh post-build payload passed.

No Poma app was installed, launched against a real profile, merged or published.
Changes are uncommitted on the feature branch. Listening/final recording selection
remains the only unfinished Session 1 acceptance dependency; Session 2 may use
these explicitly labelled drafts. New production UI and phone acceptance are
still separate future work.

### GitHub handoff update - 8 November 2026

The user has authorized a feature-branch commit and push. The technical work and
verification above are complete for the stated scope; S1.3 listening/final selection
is pending. Sessions 2-4 remain unimplemented. The earlier uncommitted statement
is historical; the progress tracker records the subsequent pushed source identity.

Implementation checkpoint c20ccb7bd5f93e00b0b7d4e7c5e6acfae02c2104 was successfully pushed to
origin/codex/focus-soundscapes. This documentation follow-up records publication;
all listening and future-session gates above remain unchanged.
