# Poma focus sounds: implementation checklist and session tracker

Created: 8 November 2026. Last updated: 9 November 2026 (Asia/Kolkata).

This is the working specification, checklist, and handoff record for adding meditation sounds to Poma's focus timer. It supports one continuous implementation run or four separate sessions. Every prompt working on this feature must read this file first and update it before finishing, including partial or unsuccessful runs.

## Current position

| Item | Current record |
| --- | --- |
| Overall status | Corrected separate Android review app installed and device checks finished. Audio-expiry/completion-alert race reproduced, fixed and phone-retested; fresh 541 regressions, 69 focused checks and Windows/Android builds pass. Review data/defaults and temporary permissions restored. Listening/remaining physical acceptance and iOS stay open |
| Repository | `D:\pomodoro` / `Jyotirmay-Singh/poma` |
| Planning baseline | `main` at `0a001d2b37e80c316449898de7419e50e18d1547` |
| Existing appearance | Still celestial background; Sora headings/countdown; Source Sans 3 body text |
| Platforms | Windows, Android, iOS |
| Current branch | `main`; implementation checkpoint `c59291323fc5b0b61880d378316dca666649af5f`. Sessions 1-4 are committed; earlier verification records retain their historical branch/HEAD and uncommitted-at-capture scope |
| Git publication | Implementation pushed to `origin/main`, exact local/remote equality and clean tree verified, then `codex/focus-soundscapes` deleted locally and on origin. This documentation follow-up records that observed outcome; physical/listening acceptance remains unchanged |
| Audio delivery | Four bundled CC0 draft Ogg recordings, 3,194,230 bytes; exact hashes verified in Windows release and Android debug payloads |
| Playback library | `flutter_soloud` 4.1.7; Windows adapter/guard and app-owned mobile native renderer/OS bridges implemented; Android builds/host policy checks pass; iOS compilation and physical/mobile acceptance pending; 5.2.3 conflict retained |
| Final recordings | Eight original WAV comparisons acquired/prepared; four bundled drafts. Not auditioned or approved as final |
| Most recent baseline checks | Android follow-up: 541 Flutter regressions, 69 focused audio/UI checks, clean analysis/format and fresh Windows release/Android review builds; 50 assertions over scoped pre/post-fix physical evidence. Prior unchanged native/assets scope retains 233 desktop + 43 font + 15 Windows guard + 25 mobile synthetic checks, 108 real-Windows-backend mobile-runtime checks, 10 Android JVM tests and S4 payload/package audits. Exact source/build/failure scopes: SESSION_4_ANDROID_DEVICE_VERIFICATION.json and original SESSION_4_VERIFICATION.json |
| Next action | User listens later in Poma Sounds Review: phone media stream is still original zero, app is Off/35%/unmuted and 25-minute Ready. Complete recording approval, fresh-sandbox offline/unplugged, real calls/routes/task removal/TalkBack/text scaling; Windows physical/clean-account and Mac/iPhone gates remain. Exact owner steps: FOCUS_SOUNDS_ANDROID_DEVICE.md and FOCUS_SOUNDS_SESSION_4.md |

The baseline is a reference, not permission to discard later changes. Inspect the actual checkout and current instructions before starting. Preparing this document does not implement or verify the feature.

## Mandatory protocol for every feature prompt

At the start:

1. Read this whole file, repository instructions, and `RTK.md`.
2. Inspect the actual branch, commit, and working tree. Preserve unrelated work.
3. Read the latest session log and continue from the first unfinished dependency. Do not recreate completed work or repeat checks whose evidence still applies.
4. State the scope of the current prompt. Make routine implementation decisions autonomously.

Before the final response, even if the requested session is incomplete:

1. Update the date, current position, session status, and next action.
2. Update affected checkboxes. Mark an item complete only when its stated behaviour or artifact is verified. Partial work stays unchecked with an explanation.
3. Record decisions, changed files, actual checks and outcomes, evidence locations, limitations, and remaining work. Do not record secrets or personal data.
4. Append a session-log entry; preserve earlier entries and evidence. For a status-only prompt, make a short entry noting that implementation did not change.
5. Record the branch and HEAD observed at handoff. If changes are uncommitted, say so; do not invent a commit identifier.
6. Ensure this tracker accompanies any feature checkpoint commit. If a check fails, keep its failure and any later successful resolution in the record.
7. Tell the user what was completed, what was verified, and which session or action comes next, with a link to this file.

This document is updated by the agent executing the prompt. It is not a background watcher. Each copyable prompt below explicitly requires the update; use those prompts when starting a new chat.

Plan mode exception: if the host makes the repository read-only during planning, do not edit this tracker or perform implementation actions. Include the proposed tracker update in the returned plan, then apply it as the first permitted execution step. Update this file before the final response of each execution run. Planning alone never completes an implementation or acceptance checkbox.

### Checklist conventions

- `[ ]` means unfinished or not yet verified; it does not necessarily mean no code exists.
- `[x]` means completed with supporting evidence in the session log or linked verification record.
- Use session states `Not started`, `In progress`, `Complete`, or `Waiting for external input/access`. State the specific unmet requirement for the last state.
- Implementation, automated checks, actual listening, physical-device acceptance, and release publication are different results. Record them separately.
- Do not remove requirements or weaken acceptance criteria merely to make the checklist green. Record an explicit user-approved scope change if one occurs.

## Read before implementation

- [Project overview](../README.md)
- [Architecture](ARCHITECTURE.md)
- [UI design system](UI_DESIGN_SYSTEM.md)
- [Space appearance and recorded verification](SPACE_APPEARANCE_RELEASE.md)
- [Local data and recovery](LOCAL_DATA.md)
- [Notification behaviour](NOTIFICATIONS.md)
- [Application/timer coordination](../mobile/lib/application/app_controller.dart)
- [Focus UI](../mobile/lib/ui/focus_screen.dart)
- [Design tokens](../mobile/lib/ui/design_tokens.dart)
- [Current dependencies](../mobile/pubspec.yaml)

The mobile UI refresh ticker is stopped in the background. Continuous audio must use the real focus-session identity and deadline, with background-capable expiry handling; UI rebuilds and the foreground ticker are insufficient.

## Required product behaviour

- [ ] P01. Offer Off, Tibetan bells, Waterfall, Ocean waves, and Forest birds. Only one sound is audible at a time.
- [ ] P02. Bundle all four final recordings. First playback after installation works without internet, login, subscription, or a Poma server.
- [x] P03. Default to Off for both existing and new users. Remember selection, volume, and mute preference locally with backward-compatible defaults.
- [ ] P04. Choosing a sound during a running Focus session explicitly enables that sound. Choosing it while ready saves the choice without starting continuous playback.
- [ ] P05. Start the enabled, unmuted sound on an explicit Focus start or resume. Pause with the focus timer.
- [ ] P06. Stop sound on focus completion, reset, skip, full data reset, and Quit. Break phases remain silent.
- [x] P07. Sound controls remain available in strict mode without bypassing strict timer restrictions.
- [ ] P08. Sound follows an active session across page navigation, Windows minimisation/tray use, and supported mobile background/lock-screen operation.
- [ ] P09. After sleep/resume, reconcile the session deadline before continuing. Never replay expired-session audio. Cold launch restores preferences but requires an explicit timer or playback action before making sound.
- [ ] P10. Provide clearly labelled preview, volume, and mute controls. Limit previews to 10 seconds; stop on dismissal or session start. Define and verify preview restoration without overlapping streams or resurrecting a stopped session.
- [ ] P11. Calls, competing audio, Bluetooth/device changes, and headphone removal behave predictably. Headphone removal stops/pauses sound without unexpectedly continuing on speakers.
- [ ] P12. Late interruption callbacks cannot restart sound after mute, reset, completion, or a session change. Media controls affect sound without implicitly starting a timer or recording focus time.
- [ ] P13. Audio failure leaves timers, tasks, history, and completion alerts working; show a concise recovery action. A zero-volume or muted choice must not be silently overridden.
- [ ] P14. Existing completion alerts remain independently configurable and follow existing OS policy. Do not duplicate alert registration through the media service.

## Audio quality and licensing

- [ ] A01. Compare suitable candidates in every category, preferably at least two where available. Record the choice and its reason. Do not claim an audition if listening was unavailable.
- [x] A02. Recheck the exact selected recording's license and app-redistribution rights before incorporating it. Prefer CC0 or explicit suitable commercial rights; satisfy attribution where required.
- [x] A03. Record creator, original source URL, license/version, acquisition date, original file identity, edits, final filename, checksum, duration, channels, encoding, and file size. Link retained license evidence.
- [ ] A04. Prepare natural, seamless loops and check the shipped encoding on each actual playback backend. Remove unintended silence/clicks and abrupt joins; preserve natural bell decays.
- [ ] A05. Balance perceived loudness across tracks. Favour gentle bell attacks, steady soft waterfall texture, small ocean waves, and unobtrusive birdsong; reject speech, lyrics, clipping, and distracting peaks.
- [ ] A06. Ship necessary assets and notices only. Measure total audio size and playback-library overhead separately; justify the chosen quality/size balance.
- [x] A07. Record listening acceptance separately from automated checks. Describe sounds as selected for a relaxing experience, without claiming a universal "most relaxing" ranking.

### Research candidates, not final assets

These sources were checked during the earlier research on 8 November 2026 and were listed as CC0. Recheck the exact license before acquisition/use; final selection and listening remain pending.

| Category | Candidate | Original duration | Final choice / evidence |
| --- | --- | --- | --- |
| Tibetan bells | [Tibetan Bowl Struck #1, Joseph Sardin](https://bigsoundbank.com/tibetan-bowl-struck-s1110.html) | 00:31 | Pending |
| Waterfall | [Small Waterfall #2, gamin](https://bigsoundbank.com/small-waterfall-2-s0219.html) | 00:46 | Pending |
| Ocean waves | [Beach: Small Waves, Denis Chardonnet](https://bigsoundbank.com/beach-small-waves-s0265.html) | 00:58 | Pending |
| Forest birds | [Birds in Forest, Scotland, BurghRecords](https://freesound.org/people/BurghRecords/sounds/490846/) | 01:53 | Pending |

Other recordings or commissioned work are valid if they improve the result and have suitable rights. "Royalty-free" alone does not establish permission for distribution in a meditation app.

## Professional UI requirements

- [x] U01. Use Forest and comparable focus apps as quality references for calm hierarchy and restrained interaction. Create an original Poma interface and record the design rationale.
- [x] U02. Preserve the celestial background, Sora/Source Sans 3 pairing, purple focus accent, teal break accent, and existing design tokens. The countdown and timer controls remain the main visual focus.
- [x] U03. Add a compact "Focus sounds" control with clear selected sound, playback/mute state, and direct mute access. Keep selection and actual playback distinguishable.
- [x] U04. Provide a mobile bottom sheet and a suitably sized desktop dialog/popover. Use coherent icons, an obvious Off option, selected states, preview, and volume. Use two columns only when readable; reflow at narrow widths and enlarged text.
- [x] U05. Support light, dark, high contrast, reduced motion, keyboard operation, visible focus, screen readers, accessible slider values, and existing minimum 48-unit hit areas.
- [x] U06. Verify narrow mobile, landscape where supported, desktop widths, and 100%/150%/200% text. Content must remain scrollable and controls reachable.
- [x] U07. Implement real loading, playing, paused, muted, and failure/retry states. Sound actions cannot accidentally change timer state or history.
- [x] U08. Capture and inspect representative rendered screens using bundled fonts. Refine alignment, spacing, contrast, and hierarchy after inspection; document actual visual evidence.

## Engineering and verification requirements

- [x] E01. Choose a maintained playback solution after a working compatibility spike on the pinned SDK. Document Windows/mobile support, gapless behaviour, native configuration, package size, and dependency trade-offs.
- [x] E02. Keep the timer domain independent of audio packages. Use a dedicated coordinator, a playback port/adapter, and a fake adapter for meaningful state-transition tests.
- [ ] E03. Bind audio to the session identity/deadline and update background expiry on timer actions. Do not introduce a drifting second source of timer truth.
- [x] E04. Verify rapid A -> B -> Off switching, stop during loading, reset/completion during callbacks, stale-session events, and disposal. Prevent duplicate players and tick-triggered restarts.
- [ ] E05. Complete Android media-playback service/audio-focus/notification integration and iOS audio-session/background configuration while preserving existing native timer and alert bridges.
- [x] E06. Load only needed audio, bound buffer/resource use, and release resources when idle. Avoid audio loading, network requests, or preference writes on every timer tick.
- [x] E07. Verify preference upgrade/defaults, reset behaviour, offline packaged assets, and absence of unrelated storage/history changes using isolated test data.
- [x] E08. Run relevant formatting, static analysis, automated behavioural/UI tests, native checks, and available platform builds. Record commands, outcomes, commit/source identity, and evidence; diagnose introduced failures.
- [x] E09. Measure and record package-size impact and practical idle/playing resource observations. Distinguish measurements from estimates.
- [x] E10. Separate source completion, build verification, listening, real-device behaviour, and release readiness. For unavailable access, provide exact remaining acceptance steps and finish independent work.

## Things not to do

These boundaries apply throughout the feature:

- Do not redesign the whole app or replace the space theme with Forest branding, artwork, or a copied interface.
- Do not add streaming subscriptions, accounts, analytics, advertising, a backend, or runtime font downloads for this feature.
- Do not use recordings from YouTube, Spotify, or stock sites merely because they can be played publicly. Verify rights for the exact source and distribution use.
- Do not request microphone or recording access for playback alone.
- Do not change focus accounting, manual next-phase starts, strict timer rules, tasks/history, Calendar consent, or existing notification behaviour to accommodate music.
- Do not let previews or media actions earn focus time or implicitly start a session.
- Do not start audio automatically on cold launch, replay expired audio, or allow stale callbacks to undo the user's mute/stop action.
- Do not restart loops from widget builds or rely on the foreground UI ticker for background expiry.
- Do not add constant equalizer animation, moving backgrounds, heavy blur, clutter, or unnecessary UI dependencies.
- Do not broadly upgrade unrelated dependencies, refactor unrelated modules, or add placeholder controls that appear functional.
- Do not test destructively against the user's installed profile, uninstall Poma, overwrite real history, or commit credentials, personal data, caches, build binaries, and temporary evidence.
- Do not merge into main or install/publish a release as part of these implementation prompts unless the user separately requests it. Keep feature work reviewable.
- Do not claim audible quality, screen-lock behaviour, or physical-device acceptance from a successful build or fake-player test alone.
- Do not mark unchecked gates complete, hide failed checks, invent evidence, or silently remove unavailable platform coverage.

## Decisions to maintain

| Topic | Current decision | Rationale / evidence / later change |
| --- | --- | --- |
| Delivery | Bundle four sounds | Preserves offline-first use |
| Default | Off | No surprise playback for existing/new users |
| Break audio | Silent in this version | Focus-only scope |
| Appearance | Retain Poma's space design | User confirmed the existing appearance is part of the app |
| Preview | Maximum 10 seconds; one audible stream | Explicit audition without overlapping playback |
| Playback library/version | `flutter_soloud` 4.1.7; just_audio fallback retained | 5.2.3 failed actual resolution; 4.1.7 passed 88 Windows native probe checks without changing 75 existing locked versions |
| Codec and loop preparation | 48-kHz Vorbis quality 4; four prepared drafts | Numerical seam diagnostics and Windows wraps pass; subjective joins/loudness and mobile backends pending |
| Background deadline mechanism | Session-bound absolute elapsed lease; Windows guard and mobile app-owned native worker plus renderer cap | No UI/Dart ticker dependency. Android CLOCK_BOOTTIME and iOS CLOCK_MONOTONIC_RAW match existing bridges. Android locked/background native retirement observed; mobile audio expiry must not initiate timer reconciliation/cancel independent OS alerts. Existing foreground/resume/action paths account completion. iOS and real Windows sleep remain pending |
| Final recordings | Not approved; provisional #1110/#0219/#0265/#2715 | Exact rights/provenance retained; equal-perceived-loudness audition and final selection pending |
| Preview restoration / interruption policy | Shared/Windows verified; mobile native focus/media/route callbacks implemented and host-policy checked | Same run/segment/intent only; residency/generation/source/platform-epoch guards. Mobile interruption end/reconnection never resumes; explicit eligible Play required; mute/zero/Off win. Physical calls/routes pending |

## Session checklist

| Session | Scope | State | Completion evidence |
| --- | --- | --- | --- |
| 1 | Audit, audio selection, technical spike, design plan | Waiting for external input/access | Technical artifacts/Windows spike verified; human listening/final recording selection unavailable |
| 2 | Playback, preferences, timer integration | Waiting for external input/access | Core/checks/builds and isolated real Windows review pass; S2.3 physical sleep/route and manual minimise/close-to-tray observations pending. Session 3 can consume the core |
| 3 | Professional UI and visual review | Complete | S3.1-S3.5: production UI, 24 interaction/layout checks, 533 regressions, inspected host/real Windows captures; physical and mobile gates remain open |
| 4 | Mobile background behaviour and final verification | Waiting for external input/access | Android scoped backend/control/lock/expiry/alerts/accounting/restart/reset checks finished; introduced alert race corrected and physical retest passes. Fresh supported checks/builds pass. S4.1-S4.3 retain listening/unplugged/physical and Mac/iPhone gates; S4.4/S4.5 retain recorded scope |

### Session 1: research, assets, and design

- [x] S1.1. Inspect actual source, state/persistence boundaries, native integrations, current tests, and host capabilities.
- [x] S1.2. Evaluate maintained playback candidates using current primary documentation; prove the chosen solution in a small working spike without unrelated upgrades.
- [ ] S1.3. Select/prepare the four candidate recordings, record provenance/license evidence, and separate verified listening from outstanding listening acceptance.
- [x] S1.4. Record the compact control/chooser design, responsive behaviour, and state designs. Critique against Poma's identity before broad UI work.
- [x] S1.5. Document architecture, chosen library and encoding, background-expiry approach, size observations, and remaining platform questions. Update this tracker and give a Session 2 handoff.

Starting library references: [Flutter SoLoud guide](https://docs.flutter.dev/cookbook/audio/soloud), [flutter_soloud](https://pub.dev/packages/flutter_soloud), [just_audio](https://pub.dev/packages/just_audio), [just_audio_background](https://pub.dev/packages/just_audio_background), and [audioplayers](https://pub.dev/packages/audioplayers). These are candidates; read current documentation and test compatibility before selection. Just_audio requires an additional Windows implementation; SoLoud needs explicit OS audio-session/background integration.


S1.3 is partial: eight originals/comparisons and four bundled draft loops with
complete provenance exist, but final recording selection/listening is unavailable.
Checked A02/A03 refer to the exact bundled drafts; replacements must repeat rights
and provenance checks. Checked E01/E08/E09/E10 refer to this Session 1 snapshot,
not future production integration or mobile acceptance. A01/A04/A05/A06 and every
production UI/integration gate remain pending. See [Session 1 record](FOCUS_SOUNDS_SESSION_1.md),
[verification](focus-sounds/VERIFICATION.json) and [provenance](focus-sounds/ASSET_PROVENANCE.json).

### Session 2: playback and session integration

- [x] S2.1. Implement the coordinator/adapter boundary and backward-compatible local preferences.
- [x] S2.2. Wire real focus transitions and session deadlines; handle fades, preview cleanup, errors, reset, disposal, and stale asynchronous work.
- [ ] S2.3. Complete Windows playback, navigation/minimise/tray continuity, sleep reconciliation, and Quit behaviour. Identify remaining mobile work explicitly.
- [x] S2.4. Add and run meaningful fake-adapter/state/persistence tests, including rapid switching and callbacks after mute/completion.
- [x] S2.5. Update requirement states, decisions, platform evidence, and this tracker; hand off the functioning core to Session 3.

Session 2 evidence scope: P03/E02/E04/E06/E07 refer to the shared application,
real isolated Windows playback and host SQLite upgrade/reset tests, plus exact
Windows/Android payload hashes. E03/E05 and global background/device requirements
remain pending for mobile. P04-P14 core behaviours have scoped test evidence;
product controls, assistive review and physical acceptance are not implied.
S2.3 is deliberately unchecked: synthetic power/route callbacks and hidden-window
tests do not establish physical sleep/headphone/Bluetooth or manual close/minimise
acceptance. Production sound UI remains Session 3. See
[Session 2 handoff](FOCUS_SOUNDS_SESSION_2.md),
[verification](focus-sounds/SESSION_2_VERIFICATION.json), and
[source identity](focus-sounds/SESSION_2_SOURCE_MANIFEST.json).

### Session 3: professional UI

- [x] S3.1. Implement the compact Focus control and adaptive chooser using production playback/preferences.
- [x] S3.2. Complete actual selection, preview, mute, volume, loading, error/retry, and keyboard/screen-reader behaviour.
- [x] S3.3. Capture mobile/desktop, light/dark, enlarged-text, and selected/playing/muted/error layouts; inspect and refine them.
- [x] S3.4. Run relevant interaction/layout/accessibility regressions. Confirm timer controls and strict-mode boundaries remain correct.
- [x] S3.5. Update this tracker with actual visual evidence and unfinished platform gates; hand off to Session 4.


Session 3 evidence scope: checked U01-U08 and S3.1-S3.5 describe production shared/Windows UI, host viewports/fonts/semantics/keyboard/contrast and isolated Windows renderer observations. U05/U06 do not close physical TalkBack/VoiceOver, real system accessibility sizes or device acceptance. P07 is the shared strict-mode boundary verified through real controller/coordinator actions. P01/P04-P06/P10/P13 have scoped Windows/shared-UI evidence but remain globally unchecked until their mobile/physical requirements are met. E08 is refreshed with Session 3 checks; E03/E05, S1.3/S2.3, draft listening and the physical acceptance matrix remain pending. See [Session 3 record](FOCUS_SOUNDS_SESSION_3.md), [verification](focus-sounds/SESSION_3_VERIFICATION.json), and [source identity](focus-sounds/SESSION_3_SOURCE_MANIFEST.json).

### Session 4: background audio and acceptance

- [ ] S4.1. Finish native Android/iOS background playback, audio focus, media controls, headset handling, and session-bound expiry without breaking native timer/alert bridges.
- [ ] S4.2. Verify the platform acceptance matrix below, including real audible loops and locked/background deadline behaviour where hardware is available.
- [ ] S4.3. Run relevant formatting, analysis, regression/native checks, and available builds; verify packaged audio/notices, offline first use, preference upgrade/reset, and resource impact.
- [x] S4.4. Record any unavailable device/signing access and the exact pending procedure. Do not present unavailable checks as passed or the platform as fully accepted.
- [x] S4.5. Reconcile every requirement, retain unresolved items, update this tracker, and deliver reviewable changes with validation and limitations. Do not install/publish implicitly.

S4.3 is partial, with all **available Windows host/build checks complete**: packaged bytes,
real isolated playback, defaults/persistence/reset and Windows resource samples
are verified. Android native backend, controls and short resource observations
now have scoped physical evidence. Clean-account offline installation/first use
and iOS device resource/backend results remain open; no unavailable
observation is counted as passed. S4.1 remains unchecked until iOS compilation
and native/device integration verification; S4.2 retains physical/listening gates.

## Platform acceptance matrix

Use `Pending`, `Pass`, `Fail`, or `Unavailable` in each cell, with an evidence reference and source/build identity. Baseline tests do not count as feature evidence. For mobile sleep, test screen lock/backgrounding; for Windows sleep, verify safe reconciliation after wake rather than claiming audio plays during sleep.

| Check | Windows | Android | iOS |
| --- | --- | --- | --- |
| Actual packaged app loads all four sounds offline | Pending — S4 payload/host loads pass; clean-account offline first use remains | Pending — D1 four native previews load and S4 payload hashes pass; phone first use with network/USB disconnected remains | Unavailable — S4, Mac/iPhone needed |
| Listening: loop joins, loudness, natural decays, no distracting peaks | Pending — S4 forced wraps are not an audition | Pending — D1 speaker stream muted at zero; user explicitly deferred listening | Unavailable — S4, iPhone/listener needed |
| Focus start/pause/resume/reset/skip/completion and strict controls | Pending — S4 shared/host checks pass; full manual tray/strict procedure remains | Pass — D1 initial APK native/UI controls, strict mute/selection and silent breaks; corrected APK deadline/accounting/full reset. Backend observations, listening separate | Unavailable — S4, Mac/iPhone needed |
| Navigation/minimisation or screen lock/background playback | Pending — S4 hidden/navigation pass; manual minimise/close-to-tray remains | Pass — D1 Android 15 review: own native track/media service remain active while screen Dozing; USB attached and speaker muted; listening/unplugged acceptance separate | Unavailable — S4, Mac/iPhone needed |
| Audio stops at the focus deadline while UI is hidden/locked | Pass — S4 real hidden renderer with Dart blocked; guard attempt +1,061 us | Pass — D1 initial locked run active at 59.400 s/stopped by 61.392 s; corrected Home run active at 55 s/stopped at 61/66 s. Track/service/focus/wake lock retire before UI reentry. Muted, polling bounds | Unavailable — S4, Mac/iPhone needed |
| Independent completion alerts coexist with audio | Pending — S4 shared/desktop checks pass; physical notification/tray acceptance remains | Pass — D1 initial sound-on failure retained against Off control; corrected APK media -1124 retires and completion ID 4 remains on existing channel at 66 s before reentry, precise access allowed | Unavailable — S4, Mac/iPhone needed |
| Sleep/wake or lock/unlock reconciles expiry without stale replay | Pending — S4 synthetic power pass; real sleep/hibernate remains | Pass — D1 initial locked expiry then user unlock/cold return shows Ready and one completion; corrected cold reopen after expiry stays silent. Unplugged/OEM conditions remain separate | Unavailable — S4, Mac/iPhone needed |
| Device/headphone/Bluetooth changes and applicable interruptions | Pending — S4 synthetic route pass; physical routes remain | Pending — S4 focus/route policy built; physical calls/routes needed | Unavailable — S4, Mac/iPhone needed |
| No audio after explicit mute, expired session, Quit, or cold relaunch | Pass — S4 isolated real renderer mute/deadline/Quit/cold checks; fresh correction regressions/build pass | Pass — D1 initial mute/zero/media/expiry; corrected active force-stop and cold Running timer stay silent until explicit action. Reset leaves no new completion | Unavailable — S4, Mac/iPhone needed |
| Preferences survive restart/upgrade; full reset clears them | Pass — S4 SQLite/real isolated cold/reset scope; fresh correction regressions/build pass | Pass — D1 initial Waterfall/50%/mute survives cold restart; corrected update retains data, UI full reset restores Off/35%/unmuted/strict off/25-minute Ready and empty tasks/history | Unavailable — S4, Mac/iPhone needed |
| Responsive UI, text scaling, contrast, keyboard/assistive technology | Pending — S3 host/UI + S4 inspected captures pass; physical Narrator remains | Pending — S3 viewport checks pass; TalkBack/system text sizes needed | Unavailable — S4, Mac/iPhone/VoiceOver needed |
| Relevant build/native checks and package-size/resource observations | Pass — S4 release/native/MSIX/ZIP/import audits and measured host resources | Pass — S4 builds/JVM/payload/alignment/size plus D1 own-process PSS/RSS, coarse CPU and wake-lock observations. Short USB-attached samples; no energy/battery claim | Unavailable — S4, Mac/Xcode/resources needed |

**S4 evidence/source identity for every cell:**
[verification](focus-sounds/SESSION_4_VERIFICATION.json),
[source manifest](focus-sounds/SESSION_4_SOURCE_MANIFEST.json), and
[procedures/limitations](FOCUS_SOUNDS_SESSION_4.md).
Pass refers only to the stated procedure and build scope. Pending and Unavailable
retain the exact owner/device steps in that handoff; the feature is not fully accepted.

**D1 Android follow-up (9 November 2026):**
[device verification](focus-sounds/SESSION_4_ANDROID_DEVICE_VERIFICATION.json)
and [device handoff](FOCUS_SOUNDS_ANDROID_DEVICE.md), with
[follow-up source identity](focus-sounds/SESSION_4_ANDROID_SOURCE_MANIFEST.json).
Initial checks used the original S4 APK and verified 291 unchanged inputs then.
The introduced completion-alert race required three later mobile application/test
file changes. Corrected APK SHA-256
`2523f4f46e1f42a20b08e40b2dc99fd1c1bf272fcaf5930d939a8d7df1ba9a5c`
is verified against bytes read from the installed separate package. The record
distinguishes pre-fix observations, the reproduced failure/Off control, fresh
checks and post-fix phone evidence. Review-only fictional data was reset and its
temporary notification/precise permissions restored to denied/off. Other Android
Pending cells retain listening, unplugged/offline, calls/routes/task removal and
assistive acceptance; no iOS or release gate is closed by this run.

## Detailed Plan mode prompts

These four standalone prompts expand the session requirements into detailed planning, implementation, verification, and handoff instructions. Use them in order in separate Plan mode chats. Each asks for a decision-ready plan first; code changes and actual tracker updates happen when execution is permitted.

1. [Session 1: research, audio assets, architecture, and design](FOCUS_SOUNDS_SESSION_1_PLAN_PROMPT.md)
2. [Session 2: playback, preferences, and focus-timer integration](FOCUS_SOUNDS_SESSION_2_PLAN_PROMPT.md)
3. [Session 3: professional UI and visual verification](FOCUS_SOUNDS_SESSION_3_PLAN_PROMPT.md)
4. [Session 4: native background playback, acceptance, and final handoff](FOCUS_SOUNDS_SESSION_4_PLAN_PROMPT.md)

## Copyable execution prompts

Use one prompt per chat/session, or use the final prompt for a continuous run. They are instructions for future implementation; creating this tracker does not start those sessions.

### Session 1 prompt

```text
Read D:\pomodoro\docs\FOCUS_SOUNDS_PROGRESS.md in full and follow its mandatory start/end protocol. Execute Session 1 only: inspect the actual project, evaluate and spike playback options, research/prepare licensed audio, and establish a professional original design that preserves Poma's space theme. Follow all requirements and things-not-to-do boundaries. Make routine decisions autonomously. Before finishing, update that Markdown file with checklist states, decisions, evidence, actual results, remaining limitations, and a concrete Session 2 handoff. Do not start unrelated feature work.
```

### Session 2 prompt

```text
Read D:\pomodoro\docs\FOCUS_SOUNDS_PROGRESS.md in full and follow its mandatory start/end protocol. Resume the actual feature branch and execute Session 2: implement playback, local preferences, timer/session integration, Windows lifecycle handling, and meaningful behavioural tests. Check Session 1 dependencies first; resolve routine unfinished prerequisites and record them instead of assuming they passed. Preserve current Poma behaviour and all things-not-to-do boundaries. Before finishing, update the same Markdown file with checklist states, changed files, verification evidence, failures/limitations, and the Session 3 handoff.
```

### Session 3 prompt

```text
Read D:\pomodoro\docs\FOCUS_SOUNDS_PROGRESS.md in full and follow its mandatory start/end protocol. Resume the feature and execute Session 3: build and refine the professional adaptive Focus sounds UI using real playback/preferences, preserve the space theme, and verify interactions, accessibility, and actual rendered layouts. Check prior-session dependencies; do not substitute mock functionality for missing integration. Before finishing, update the same Markdown file with completed and pending items, screenshots/evidence, actual checks, and the Session 4 handoff.
```

### Session 4 prompt

```text
Read D:\pomodoro\docs\FOCUS_SOUNDS_PROGRESS.md in full and follow its mandatory start/end protocol. Resume the feature and execute Session 4: complete native mobile background playback and deadline handling, verify the platform acceptance matrix, run relevant checks/builds, and reconcile the requirements. Complete independent work when device/signing access is unavailable; record exact unverified acceptance steps without claiming success. Before finishing, update the same Markdown file with every affected checklist state, platform evidence, remaining limitations, reviewable commit/source identities, and any next action. Do not install, merge, or publish a release unless separately requested.
```

### Continuous implementation or continuation prompt

```text
Read D:\pomodoro\docs\FOCUS_SOUNDS_PROGRESS.md in full. Follow its requirements, things-not-to-do boundaries, and mandatory start/end protocol. Inspect the actual checkout and latest log, then execute the next unfinished session and continue through the remaining sessions as time and available access permit. Update that Markdown file after every session and before your final response, including partial runs, failures, evidence, and the next concrete step. Preserve valid completed work and do not invent device or listening results. Keep the final implementation reviewable; do not install, merge, or publish unless separately requested.
```

## Session log (append; do not replace earlier entries)

### 8 November 2026 - tracker preparation

- Prompt/scope: Create a Markdown checklist covering requirements, things to avoid, session execution, and updates after every feature prompt.
- State: Planning document prepared; Sessions 1-4 have not started.
- Starting branch/HEAD: `main`, `0a001d2b37e80c316449898de7419e50e18d1547`; working tree was clean before this document was created.
- Changed files: `docs/FOCUS_SOUNDS_PROGRESS.md` only. No application code, dependencies, audio assets, or installed app data changed.
- Evidence: Read the current project instructions, manifest, design tokens, and earlier design/release documentation. Captured current branch/HEAD and confirmed this document's path is not ignored by Git. Document structure, links, and whitespace checked after creation.
- Check result: Documentation checks passed. App tests were not rerun for this documentation-only change; the 472-test/static-analysis result above is the earlier baseline.
- Commit state: Tracker is a new, uncommitted document; no feature branch, push, or release created by this prompt.
- Next action: Run the Session 1 prompt above.

### 8 November 2026 - detailed Plan mode prompt pack

- Prompt/scope: Produce four separate, elaborative Plan mode prompts covering the meditation-sound implementation.
- State: Planning materials expanded; Sessions 1-4 remain Not started and all implementation/acceptance checkboxes remain pending.
- Starting branch/HEAD: `main`, `0a001d2b37e80c316449898de7419e50e18d1547`; the previously created tracker was uncommitted at the start.
- Changed files: This tracker plus `docs/FOCUS_SOUNDS_SESSION_1_PLAN_PROMPT.md`, `docs/FOCUS_SOUNDS_SESSION_2_PLAN_PROMPT.md`, `docs/FOCUS_SOUNDS_SESSION_3_PLAN_PROMPT.md`, and `docs/FOCUS_SOUNDS_SESSION_4_PLAN_PROMPT.md`. Application code and installed data are unchanged.
- Decisions: Keep one detailed prompt per session. Each begins with read-only planning, supplies decision/implementation/acceptance detail, and requires a tracker update when execution is allowed. Added an explicit Plan mode exception so planning cannot falsely mark implementation complete or demand forbidden file edits.
- Verification: Checked document links, whitespace, prompt coverage, and preservation of the 59 pending checklist items. No app tests rerun for documentation-only changes.
- Commit state: All five feature-planning documents are local and uncommitted. No feature branch, push, merge, or release created by this prompt.
- Next action: Open the detailed Session 1 prompt, paste its body into a new Plan mode chat, then implement the resulting plan when ready.

### 8 November 2026 - Session 1 execution started

- Scope: Execute the approved Session 1 plan only. Production coordinator, production UI and mobile background acceptance remain Sessions 2-4.
- Starting branch/HEAD: `main`, `0a001d2b37e80c316449898de7419e50e18d1547`; tracker and four session prompts are untracked and preserved.
- Provisional decisions: SoLoud 5.2.3; just_audio 0.10.6 / Windows 0.2.3 fallback; Vorbis quality-4 trial. Defaults Off / 35% / unmuted. Persistent mute and zero volume take precedence; competing audio pauses Poma.
- Playback, listening, new UI rendering and physical-device acceptance are not yet verified. All requirement and implementation checkboxes remain unchanged at this starting checkpoint.
- Next action: Create/resume `codex/focus-soundscapes`, retain acquisition/license evidence and execute the isolated spike.

### 8 November 2026 - Session 1 technical checkpoint and listening handoff

- Scope/result: Execute Session 1 only; technical work verified, final audio selection partial because agent listening is unavailable. Sessions 2-4 remain Not started. No production controls, preferences or media service were replaced with placeholders.
- Starting branch/HEAD: `main` / `0a001d2b37e80c316449898de7419e50e18d1547`, five planning files untracked. Created `codex/focus-soundscapes`; pre-existing prompts preserved.
- Work/rights: Eight original public CC0 WAVs acquired through the normal download form/wait; eight comparisons and four 48-kHz Vorbis-q4 drafts prepared. Forest #3/#4 provide accessible original comparisons because the Freesound seed needs login. No account, purchase, provider API or preview master used. Exact source/license/acquisition/edit/media/hash/size evidence retained.
- Decision: 5.2.3 failed resolution (native_toolchain_c requires meta ^1.19.0; Flutter pins 1.18.0). Qualified resolver-recommended 4.1.7 instead. All 75 prior locked versions preserved. App/root notices and offline license registry updated; draft audio totals 3,194,230 bytes.
- Changed files: This tracker, Session 1 architecture/design/handoff, provenance/license/verification/source records; isolated experiment/baseline fixtures; preparation/notice/check/evidence scripts; four Ogg files/two notice assets; main.dart license registration; pubspec/lockfile/generated Windows FFI list; app/root notices. Timer domain, AppController, schema, native alert configuration and installed profiles were not modified.
- Actual checks: 88 real Windows MiniAudio probe checks, 3 lease tests, 472 Flutter tests, clean app/experiment analysis and formatting, Windows native suites/release build, Android arm64 debug build/JVM task and exact payload hashes passed. Commands/outcomes/source identity: docs/focus-sounds/VERIFICATION.json and SOURCE_MANIFEST.json. Full logs/bundles/resources: ignored artifacts/focus-sounds/session-1/.
- Observations: Four native asset loads, volume/fades/pause, 20 forced loop wraps, own-window hiding, expiry and cleanup. Native voice retirement observed +9,165 us in one hidden trial; native stop worked while Dart blocked. Paused synthetic transport rejected expired restoration. This is not physical speaker latency, listening, real calls or locked-phone acceptance.
- Size/resources: Windows experiment runtime 27,195,300 / 31,206,150 / 34,400,618 bytes (baseline/library/assets); matched library/probe overhead 4,010,850 bytes, asset increment 3,194,468 bytes. One 81-sample run peaked at 70,471,680 working-set bytes; short idle/active CPU windows retained. No battery/store-size guarantee. Fresh Android debug APK: 105,093,089 bytes; SHA-256 c326b6a162a5849426c4d52a57fa88bd40b7975ccebbbd826335bd470d58b816.
- Failures/resolutions: Initial unbounded bell intermediate exhausted free workspace space; only that resolved task-created file was removed. Finite sample limits, duration/size caps and timeout passed. Incorrect clock DLL lookup timed out the owned child; failure log retained, lookup/error reporting corrected. Native link/empty registrant setup repaired using junctions and locked resolution without changing Developer Mode. One style finding corrected. Premature APK inspection rejected a stale artifact; fresh post-build inspection passed. Upstream warnings remain in logs. See Session 1 record for details; failures are not erased by later passes.
- Unavailable/remaining: Agent equal-perceived-loudness audition, ten-minute trials and headphone/speaker join review; production rendered/assistive review; physical Android/iOS; Windows sleep/wake; iOS compilation. Earlier ADB daemon inventory failed, so attached-device availability was not asserted. All production acceptance-matrix cells remain Pending.
- Requirement updates: S1.1/S1.2/S1.4/S1.5, A02/A03/A07 and E01/E08/E09/E10 verified for the stated snapshot/scope. S1.3/listening and production integration/UI/mobile gates remain unchecked.
- Handoff branch/HEAD: `codex/focus-soundscapes` / `0a001d2b37e80c316449898de7419e50e18d1547`, feature changes uncommitted. No Poma installation, push, merge or publication.
- Next concrete action: Audition eight comparisons and approve/replace four drafts. Session 2 may implement the documented coordinator/port/fake, preferences, transition feed and Windows lifecycle using clearly labelled drafts; resolve listening before claiming final assets/release readiness.

### Template for each later prompt

Copy and fill this template; retain the template for later use.

```text
Date/time and timezone:
Prompt/session and scope:
Starting branch/HEAD and working-tree condition:
Result: complete / partial / failed / waiting for specific external access
Completed work and requirement IDs:
Changed files:
Decisions and reasons:
Checks actually run, source/build identity, and outcomes:
Listening / visual / physical-device observations (state what was observed):
Evidence locations:
Failures, unresolved issues, and unavailable checks:
Requirement/session/matrix updates:
Handoff branch/HEAD and uncommitted changes:
Next concrete action:
```

### 8 November 2026 - commit and GitHub handoff requested

- User authorized committing and pushing the Session 1 work to origin on codex/focus-soundscapes.
- Completed: source audit, original CC0 acquisition/evidence, four draft loops, isolated Windows playback qualification, notices/asset registration, UI specification and Session 2 contracts/handoff.
- Verified: 88 real playback checks, 3 lease tests, 472 app tests, analysis, Windows native checks/release build, Android debug build/JVM checks and packaged hashes. Final source-manifest and whitespace checks passed.
- Still pending: listening/final recording selection (S1.3), production playback/preferences (Session 2), production UI (Session 3), mobile background/device acceptance (Session 4). Earlier log entries describe their historical commit state.
- Publication: preparing the source checkpoint; the follow-up entry records the actual pushed commit. No new app tests required for this documentation-only checkpoint.

### 8 November 2026 - GitHub source checkpoint published

- Session 1 implementation checkpoint: c20ccb7bd5f93e00b0b7d4e7c5e6acfae02c2104. Successfully pushed to origin/codex/focus-soundscapes; upstream tracking configured.
- Repository: https://github.com/Jyotirmay-Singh/poma/tree/codex/focus-soundscapes
- This follow-up documentation commit records that successful push and retains the same completed/pending checklist states. Its final commit identity is available from Git history.
- No merge, release publication, installation or additional implementation performed. Listening/final selection and Sessions 2-4 remain pending.

### 8 November 2026 - Session 2 execution started

- Scope: Execute the approved playback/preferences/timer/Windows plan. Production UI remains Session 3; mobile native media/background integration remains Session 4.
- Starting branch/HEAD: `codex/focus-soundscapes` / `6bd18d3e10f348a5b9d5e4958203fc934b3e24fd`, clean. The preceding planning pass performed no implementation or application checks; it verified draft/license/source-manifest hashes read-only.
- Work: Shared preferences/coordinator/ports/fake, optional schema-v3 metadata, accepted-transition feed, composite reset, application lifetime/Quit handling, pinned SoLoud adapter, native deadline/power/route guard, isolated developer review target, behavioural/SQLite/native tests and evidence scripts.
- Decisions: Keep 4.1.7 and draft recordings. Guard native output independently of Dart, keep old interruption-resume tokens invalid after newer interruptions, and reject regressing native platform epochs. Windows visibility policy is explicitly injected rather than inferred from completion-alert configuration. Mobile remains safely unavailable until Session 4.
- Verification in progress: Initial 504-test regression and 34 focused tests passed; 233 desktop, 43 font and 15 synthetic audio-guard checks passed; Windows release/Android debug builds passed. First real review passed 31 playback plus four cold/reset checks. Final source checks, builds and resource measurements are being refreshed after the interruption race fix; this entry is not a claim that final gates passed.
- Failures retained: SDK-cache permission boundary; initial style/FFI callback declaration; test-helper import/v2 fixture composition; missing mincore native link; rapid-control resource retirement; invalid immediate mixed-voice count assumption on suspend. A new test reproduced an older resume crossing a newer interruption, then passed after post-reconciliation token revalidation. Full successful/failed logs remain under `artifacts/focus-sounds/session-2/`.
- Safety/evidence scope: Only copied review builds with separate profile/mutex/pipe/tray/notification identities were launched. No installed profile was opened or renamed, no app was installed/published, and no Git commit/merge/push was made. Human listening and physical Windows/mobile acceptance remain pending.

### 8 November 2026 - Session 2 verified core and Session 3 handoff

- Result: Shared/Windows core implemented and verified. Session 2 remains Waiting for external input/access for S2.3 physical sleep/wake, wired/Bluetooth removal and manual minimise/close-to-tray observations. Session 3 can implement the product UI now; Session 4 still owns all mobile media/background enablement and physical acceptance.
- Branch/HEAD: `codex/focus-soundscapes` / `6bd18d3e10f348a5b9d5e4958203fc934b3e24fd`. All Session 2 source/docs/evidence changes are local and uncommitted. No merge, push, app installation or release publication occurred.
- Changed files: Domain preferences and SavedState; application ports/coordinator/transition feed/reset composition/Quit; SoLoud and Windows guard adapters; composition root; native guard and review isolation hooks; fake/SQLite/controller/desktop/native tests; developer review target and check/measurement/evidence scripts; tracker, Session 2 handoff and verification/source JSON. Exact inventory and hashes: `docs/focus-sounds/SESSION_2_SOURCE_MANIFEST.json`.
- Completed gates: S2.1, S2.2, S2.4 and S2.5; P03 and E02/E04/E06/E07 verified for the scoped shared/Windows and host/payload evidence. S2.3, E03/E05 mobile coverage, global device/UI requirements and final A01/A04/A05/A06 acceptance remain pending. Existing A02/A03 rights evidence applies to unchanged drafts; listening status is unchanged.
- Actual final checks: 507 full Flutter regression tests, 35 focused audio tests, clean analysis/format, 233 desktop + 43 font + 15 audio-guard native checks; Windows production release, isolated review release and Android arm64 debug builds all pass. Commands/outcomes, including earlier failures, are retained in `docs/focus-sounds/SESSION_2_VERIFICATION.json` and ignored `artifacts/focus-sounds/session-2/checks/` logs. The reproduced older-resume/newer-interruption test failed before the fix and passed afterward.
- Real playback: Final isolated release review passes 32 playback checks plus four cold/relaunch/reset checks. Four local assets load and loop; gain/mute/zero, native tray pause/resume, hidden/navigation continuity, bounded preview/restoration, idle cleanup, blocked-Dart deadline retirement and Quit cleanup pass. Synthetic power/route notifications use the real renderer; they are not physical sleep/headphone observations. Final native guard retirement attempt: +602 microseconds, not physical speaker latency.
- Package/source identity: Exact four draft hashes and both notices verified in fresh production Windows and Android payloads. Audio assets 3,194,230 bytes; audio DLL files 3,665,408 bytes; Windows runtime inventory excluding PDB/linker artifacts 45,489,921 bytes; fresh Android debug APK 105,489,164 bytes. Executable, Dart AOT, APK and source hashes are recorded. TimerEngine, schema migrations, lockfile/manifest and Android/iOS native source remain unchanged by Session 2.
- Resource observations: Final Windows 11 10.0.26200 release run stays hidden for matched 60/120/60-second idle/playing/post-stop windows. CPU percent of one core: 1.31 / 1.66 / 0.79; median working set: 105.0 / 91.4 / 74.6 MiB. Native engine/source release is separately asserted; handles/threads and raw samples are retained. Startup/cache/GC are included; no net library-overhead, battery or store-size guarantee follows. Final release staging should omit the 4,042 bytes of export linker artifacts.
- Unavailable/not performed: Human listening/final selection; physical Windows sleep/wake, wired/Bluetooth changes and manual minimise/close-to-tray review; production UI/assistive review; Android/iOS native audio focus/media/background/lock-screen behaviour and physical devices; macOS/iOS compilation. None is recorded as passed.
- Session 3 handoff: Use `AppController.focusAudio`, immutable state, real selection/mute/volume/preview/retry APIs and chooser-specific dismissal tokens. Preserve strict controls and keep widget builds free of playback IO. Detailed API, scope, results and pending physical procedure: `docs/FOCUS_SOUNDS_SESSION_2.md`. Mobile playback stays safely unavailable until Session 4 supplies its native guards/services; do not substitute mock playback.

### 8 November 2026 - Session 3 read-only planning and execution start

- Planning observed `codex/focus-soundscapes` at `6bd18d3e10f348a5b9d5e4958203fc934b3e24fd`, with preserved uncommitted Session 2 work. All 33 Session 2 manifest entries matched. Read tracker, production APIs, design/layout/localization sources and verification support. Inspected existing tall-dark phone, compact-light 200%, landscape-dark 200%, and 1440-unit light desktop Focus captures.
- Approved choices: small outline tiles with adaptive columns; current task context before sounds on stacked layouts; existing celestial identity and bundled fonts. Dependencies: explicit playback availability and preview-retry cancellation token.
- Planning changed no files and ran no builds, captures or app tests. All implementation/acceptance checkboxes remained unchanged.
- Execution now authorized: implement Session 3 only, preserve local Session 2 changes, verify real coordinator interactions and rendered layouts, retain mobile/background/listening/physical gates. No install, merge or release publication.
- Starting branch/HEAD unchanged; Session 3 In progress. Actual results and handoff will be appended before completion.

### 8 November 2026 - Session 3 verified UI and Session 4 handoff

- Result: S3.1-S3.5 complete for shared/Windows production UI and the stated host/isolated-runtime scope. U01-U08 and shared strict-mode P07 verified. Global mobile/physical product gates remain unchecked; listening is unchanged.
- Branch/HEAD: `codex/focus-soundscapes` / `6bd18d3e10f348a5b9d5e4958203fc934b3e24fd`. Session 2 changes preserved; Session 3 is local/uncommitted. No commit, push, merge, app installation or publication occurred.
- Implemented: compact Focus control, task-first stacked layout, adaptive sheet/dialog, parallel outline sound choices, real preview/mute/volume/playback/retry, truthful transport/platform states, localized copy, keyboard/focus/semantics and enlarged-text scrolling. Added availability gating and the preview-retry replacement token; no schema, timer accounting, audio assets or package upgrade.
- Actual checks: 533 full Flutter regression tests; 24 sound interaction/layout checks included in that count and rerun for capture; 37 focused audio tests; clean analysis/format; 233 desktop + 43 production-font + 15 synthetic audio-guard native checks. Windows production/review release and Android ARM64 debug compilation passed. Exact commands/source hashes/logs are in the Session 3 verification record.
- Visual evidence: 41 host fixture captures at `artifacts/focus-sounds/session-3/ui/`; 16 representative views personally inspected, spanning Off, ready, preview, loading, playing, paused, muted/zero, failure/Retry, unavailable, high contrast and enlarged/landscape layouts. The manifest distinguishes fixture playback from native phone acceptance. Four final Windows renderer captures under `artifacts/focus-sounds/session-3/windows-runtime-1794157691406233500/runtime/fictional-review-profile/` were personally inspected.
- Real isolated Windows observations: production UI starts exactly one native voice; preview retains the selected sound and one stream; dismissal restores eligible continuous Focus; direct mute revokes output immediately. Five runtime checks passed with exact executable/AOT/source identities. This is not human listening, physical sleep/headset acceptance or an installed-profile observation.
- Refinements: readable disabled preview ink; consistent tile row alignment; visible focus edges; selected-option scrolling preserves already visible header content; Home/End and 1% arrows; separate pointer and coalesced keyboard/accessibility volume; removed repeated Off copy. Contrast thresholds and production fonts were retained.
- Failures retained: initial SDK-cache/formatter-wrapper access, chooser syntax/style findings, lazy off-screen test setup, fake-clock/semantics/Calendar teardown ordering, slider key handling and disabled-preview contrast. Obscured background text was excluded from active-modal sampling without changing the contrast checker/threshold. Successful and failed logs remain in the Session 3 artifact directory.
- Remaining: final audio audition/selection; physical Windows sleep/wake, wired/Bluetooth/tray observations; TalkBack/VoiceOver and real system text scaling; Android/iOS media/background/lock/route integration and hardware acceptance; iOS compilation. No unavailable gate is marked passed.
- Next action: execute Session 4 against the existing coordinator/availability contract. Preserve preview-token ownership, one-stream/deadline rules, independent alerts, strict timer boundaries and these UI regressions. Full decisions, component files and exact acceptance concerns: `docs/FOCUS_SOUNDS_SESSION_3.md`.

### 8 November 2026 - Session 4 execution authorized

- Scope: Implement the approved native audio plan locally on Windows. Preserve existing Session 2/3 changes. User will connect Android later; no connected-phone result is assumed. Mac/Xcode, iOS signing and physical iPhone checks remain unavailable; existing Mac CI is not authorized for this run.
- Starting branch/HEAD: codex/focus-soundscapes / 6bd18d3e10f348a5b9d5e4958203fc934b3e24fd, with preserved uncommitted Session 2/3 work. Planning verified all 22 Session 3 manifest entries and the four draft hashes (3,194,230 bytes); no planning builds/tests or edits occurred.
- Decisions: Keep Flutter 3.44.2, Dart 3.12.2 and flutter_soloud 4.1.7. Use app-owned native media controls instead of audio_service/audio_session; reserve a negative media notification ID, preserving all positive completion-alert IDs. Interruption end never starts audio; explicit eligible action is required.
- Gates: All existing implementation/acceptance checkboxes retain their prior evidence scope. Listening/final assets, physical Windows/Android, assistive and iOS gates are not passed by authorization. No installed profile, merge, push or release publication is included.
- Next action: Add native session/expiry safety, preserve timer/alert bridges, and execute supported checks with source/build evidence.

### 9 November 2026 - Session 4 local implementation and available checks finished

- Scope/result: Completed the independent Windows-host implementation and checks authorized by the user. Android device execution is deferred until connection. iOS source is integrated, but Mac/Xcode/signing/iPhone verification is unavailable. Listening/final recordings and mandatory physical acceptance remain open; the feature is not fully accepted.
- Branch/HEAD: `codex/focus-soundscapes` / `6bd18d3e10f348a5b9d5e4958203fc934b3e24fd`. Preserved Sessions 2/3 and accumulated Session 4 changes; all remain local/uncommitted. No installation, real-profile access, production signing/certificate-trust change, Git publication, merge, tag or release publication.
- Implemented: Shared background/media port and coordinator lease propagation; one app-owned mobile native renderer/deadline worker; source/residency/generation/platform-epoch safety; Android application-scoped engine/clock/alert bridges, mediaPlayback FGS, focus/noisy/routes/wake state, generic media controls and separate negative notification ID; iOS audio-session/background/scene/remote-command/route/interruption source. Existing timer accounting, alert IDs/receivers/work queues, schema, assets, locked versions and Windows identity remain.
- Source files: Exact accumulated hashes/inventory in `docs/focus-sounds/SESSION_4_SOURCE_MANIFEST.json`. Principal S4 files are `mobile/native/focus_audio_runtime.*`, `mobile/lib/data/mobile_focus_audio_playback.dart`, background/media coordinator/port additions, Android `PomaApplication`/`PomaPlatformPlugin`/`PomaAudio*`/JNI/CMake/manifest/Gradle, iOS `PomaFocusAudio*`/AppDelegate/SceneDelegate/Info/project entries, tests/review entry point and Session 4 scripts/docs. Windows distribution correction is confined to build/inventory scripts; the existing Windows native playback implementation is preserved.
- Actual checks: 540 Flutter regressions; 68 focused audio/UI tests; 233 desktop, 43 font, 15 Windows guard and 25 synthetic mobile-native checks; 108 native mobile-runtime checks using the real Windows renderer; 10 Android JVM tests including existing alert/work-queue suites. Analysis/format, Windows production/review releases, Android debug/unsigned release/separate signed review builds pass. Scope-aware hashes confirm unchanged Dart/Windows inputs when earlier checks are reused; later mobile native changes have fresh native/Android checks. Commands, logs, build hashes and counts: `docs/focus-sounds/SESSION_4_VERIFICATION.json`.
- Real isolated Windows: 32 core playback plus four cold/reset checks pass with measured hidden 60/120/60-second resource windows. Native guard retirement attempt +1,061 microseconds; this is not speaker latency. A fresh sanitized review distribution passes five actual UI/playback/preview/dismissal/mute checks; its playing and chooser captures were inspected. No human audition, real sleep, headphones, Bluetooth, manual tray or native assistive result is inferred.
- Packaging failure/resolution: First actual MSIX audit rejected `dartjni.dll -> jvm.dll`. The optional desktop JNI shim was present in both the old and current developer outputs because a JDK is installed. Windows uses its app-owned alerts and has no JNI native-asset/import dependency. Distribution now omits that Android-only shim and rejects any future Windows JNI/JVM reference. Audio codecs/CRT/notices remain included. Audited unsigned MSIX (20 PE files, AOT, 76 payload files) and isolated ZIP pass; ZIP runtime playback was rerun without JNI. No developer Java installation is a Windows package requirement.
- Artifacts: Separate Android `Poma Sounds Review` release-mode/debug-signed APK, package `com.jyotirmaysingh.poma.focussoundsreview`, at `artifacts/focus-sounds/session-4/builds/android-review-1794200768379284800/app-release.apk` (36,117,169 bytes, SHA-256 `2b811bcce49747ae064bec0307b90d873f9758b47a17976df749149f89074484`). Windows isolated interactive portable ZIP at `artifacts/focus-sounds/session-4/windows-package/review-1794201884719164000/Poma-Sounds-Review-Windows-x64.zip` (22,225,036 bytes); fresh isolated startup/database and synthetic normal-Quit smoke pass. The five playback/UI checks use the separately retained automated review entry point with the same sanitized dependencies. Unsigned production-identity MSIX is inspection-only and not installed. Exact identities/procedures: `docs/FOCUS_SOUNDS_SESSION_4.md`.
- Size/resources: Four unchanged drafts total 3,194,230 bytes. Raw Windows runtime matches the saved baseline; distribution separately excludes 68,096 JNI bytes. New mobile release guard totals 1,014,572 uncompressed bytes across packaged ABIs. Fresh comparable debug APK is 104,012,748 bytes, raw delta -1,507,344 while compressed entries grow 1,156,375; ZIP alignment/layout means this is not an audio-overhead saving claim. Windows one-core CPU off/playing/post-stop 0.82/1.55/0.42%; median working set 102.5/52.6/47.7 MiB. No prior comparable MSIX or mobile battery/resource result is claimed.
- Retained failures: Earlier SDK-cache/process access, native compile/link settings, fixture lookup, stream-memory ownership, initial parallel temporary-file sharing/process regressions and interrupted build logs remain under `artifacts/focus-sounds/session-4/`. Corrected stream-memory copying and sequential regressions pass. On continuation, a restricted-cache build attempt failed; permitted retry built the verified review APK. The packaging failure and its successful resolution are explicit in the verification record. The first interactive-smoke fixture searched the root instead of the isolated `databases` subdirectory; its failure record is retained, its owned child cleaned up, and the corrected fixture passes on a fresh copy without application changes.
- Requirements/matrix: Reconciled all 59 P/A/U/E/session items without removing gates. S4.4/S4.5 checked; S4.1-S4.3 remain partial for iOS/native-device/listening/clean-account-first-use/resource access. Existing checked requirements keep their documented scope. Four Windows matrix rows pass their stated real/shared host procedures; other physical Windows/Android rows remain Pending and iOS rows Unavailable, with exact source/build references.
- Next action/owner: User connects the designated Android test phone, installs only the separate review APK, then follows the offline/all-sounds/media/lock/deadline/calls/routes/alerts/force-stop/accounting/TalkBack procedure in `docs/FOCUS_SOUNDS_SESSION_4.md`. User also completes Windows listening/sleep/routes/manual tray/Narrator/clean-account checks. A future Mac/iPhone tester compiles/tests/links the exact source before signed physical iOS acceptance. No independent local implementation work is waiting for the phone.

### 9 November 2026 - Connected Android verification and completion-alert correction

- Scope/result (Asia/Kolkata): User connected an Android phone, later unlocked it and instructed continued checks while deferring listening. Completed available scoped device checks in the separate **Poma Sounds Review** app. Remaining listening, unplugged/offline, real calls/routes/task removal/assistive and Windows/iOS external gates stay open; Session 4 returns to Waiting for external input/access.
- Branch/HEAD: `codex/focus-soundscapes` / `6bd18d3e10f348a5b9d5e4958203fc934b3e24fd`. Earlier uncommitted Sessions 2/3/4 preserved; this follow-up is also local/uncommitted. No commit, push, merge, tag, production installation or release publication.
- Device/identity: moto g54 5G, Android 15/API 35, ARM64, USB/ADB attached. Only `com.jyotirmaysingh.poma.focussoundsreview` was installed/updated and exercised. Initial S4 APK hash `2b811bcce49747ae064bec0307b90d873f9758b47a17976df749149f89074484` retains its pre-fix evidence. Corrected release-mode/debug-signed APK: `artifacts/focus-sounds/session-4/builds/android-review-1794205856909895100/app-release.apk`, 36,117,169 bytes, SHA-256 `2523f4f46e1f42a20b08e40b2dc99fd1c1bf272fcaf5930d939a8d7df1ba9a5c`; installed APK bytes were read back and match.
- Regression/fix: Physical background comparison with notifications/precise access allowed exposed missing completion notification with Ocean waves, while the Off control retained completion ID 3 at 61/66 seconds. Mobile native audio expiry called timer reconciliation and withdrew the independent OS request. A new real-controller/coordinator/fake-alert regression test failed before the fix. Mobile expiry now disarms/releases only audio, retaining existing foreground/resume/action reconciliation; desktop keeps immediate resident completion handling. No native alarm receiver/ID, queue, schema, asset or dependency change.
- Application/test files changed this phone run: `mobile/lib/application/focus_audio_coordinator.dart`, `mobile/test/focus_audio_mobile_test.dart`, `mobile/test/focus_audio_support.dart`. Added scoped Android inspection/recording helpers, device handoff and verification/source JSON; updated this tracker and S4 handoff/follow-up reference. Exact hashes and retained check failures are linked in the device record.
- Fresh checks: Format, analysis, **541 full Flutter regressions**, **69 focused audio/UI checks**, Android review APK and Windows release build pass against current hashed inputs. Focused tests are a selected subset, not an additional full-suite count. Prior unchanged C++/Kotlin/assets/config inputs retain their native/JVM/payload/package evidence scope; the earlier Windows review ZIP is not represented as rebuilt after the mobile correction.
- Physical observations: Four native previews; ready/running selection; start/pause/resume/reset/skip; media sound-only commands; mute/zero; volume 0/50%; strict sound controls; cold preference persistence; rapid bells -> Waterfall -> Off; settled correct-source preview restoration; silent breaks. Locked 60-second run remains active at 59.400 s and is retired by 61.392 s without reopening; own native track/service/focus/wake lock retire. User unlock/cold return reconciles to Ready and exact history. USB/network and system speaker mute conditions are explicit.
- Corrected-build retest: Ocean waves stays active after navigation/Home through 55 s, stops at 61/66 s observations, and completion **ID 4** remains on `poma_timer_completion_v1` at 66 s before app reentry while media **-1124** is gone. Return advances five to exactly six one-minute completions and leaves the break Ready. A separate active force-stop/cold reopen restores a Running timer with Sound paused; reset adds no completion. Full review-data reset restores Off/35%/unmuted/strict off/25-minute Ready, zero rounds and empty tasks/history.
- Fixtures/failures retained: Restricted ADB daemon access resolved through permitted execution; initial alert-onboarding label lookup; media volume command help/syntax; early PAUSED snapshots during source loading; read-only filename listing; `pidof` exit 1/no process resource handling. First active-stop cold reopen happened after the one-minute deadline and legitimately added completion seven; its misleading `334-force-no-new-completion` filename is explicitly explained. Fresh three-minute active-cold trial then remained at seven after reset. None of those fixtures substitutes for the separately reproduced and fixed app alert race.
- Final phone/safety: Temporary review-only notification/precise permissions restored to denied/off; no review notifications or active audio remain. Global media stream restored/confirmed at original 0/15. Review app left at default Ready. Production `dev.poma.poma` remains installed; its data/permissions were never targeted. No security bypass/root/microphone access. Final captured own-process logs contain no matched fatal/security/service-start/native-load error. Default Focus/lower-chooser screenshots inspected at current device settings.
- Evidence/requirements: [Device handoff](FOCUS_SOUNDS_ANDROID_DEVICE.md), [verification](focus-sounds/SESSION_4_ANDROID_DEVICE_VERIFICATION.json), [current source identity](focus-sounds/SESSION_4_ANDROID_SOURCE_MANIFEST.json); ignored raw app-only evidence under `artifacts/focus-sounds/session-4/android-device-20261109/`, with hashed index and 50 scoped assertions. Initial and corrected APK scopes remain separate. Android controls, lock/wake, cold silence, preferences/reset and independent-alert matrix rows updated; global P/A/U/E and S4.1-S4.3 gates retain remaining platform/listening conditions.
- Next owner/action: User listens later and approves/replaces drafts. Android tester completes fresh-sandbox offline/unplugged, calls/competing audio/routes/task removal/TalkBack/system text procedures in the device handoff. User/tester completes Windows sleep/routes/manual tray/Narrator/clean-account procedure. A Mac/iPhone tester compiles/tests/signs the exact source before physical iOS acceptance. No independent local implementation/check work remains from this connected-device run.

### 9 November 2026 - Main publication and feature-branch cleanup authorized and completed

- Scope (Asia/Kolkata): User explicitly requested committing and pushing all current changes to `main`, completing synchronization, then deleting the feature branch. This authorizes source publication and branch cleanup; the recorded physical/listening acceptance states remain unchanged.
- Starting branch/HEAD: `codex/focus-soundscapes` / `6bd18d3e10f348a5b9d5e4958203fc934b3e24fd`. All 91 pending paths were the accumulated Sessions 2/3/4 implementation, tests, scripts and documentation. No local tools, build binaries, application profiles or raw device captures were staged.
- Verification: Fetched origin; remote `main` remained `0a001d2b37e80c316449898de7419e50e18d1547`, an ancestor of the feature. All 332 recorded current source/helper inputs matched; 541 full regressions, 69 focused checks, format/analysis and Windows/Android build records retained their exact scope. Staged whitespace check passed. No application source changed or additional test run was needed during this Git-only handoff.
- Implementation commit: `c59291323fc5b0b61880d378316dca666649af5f` (**Add focus sound controls and native background playback**). Switched to `main`, fast-forwarded without conflicts, and pushed to `origin/main`. This also brings the previously published Session 1 commits into `main`.
- Observed synchronization before deletion: Local `main`, `origin/main` and the live GitHub main ref all equalled `c59291323fc5b0b61880d378316dca666649af5f`; working tree clean. Both the local feature tip and remote feature tip were verified ancestors of `main`. Remote branch deletion used the observed old tip as a lease, then safe local `git branch -d` succeeded. Only `codex/focus-soundscapes` was removed.
- Evidence: Ignored `artifacts/focus-sounds/session-4/git-publication-20261109/before-branch-cleanup.json` retains exact refs and timestamp. This documentation checkpoint records the completed source push and cleanup; its final commit is available from Git history and the user-facing handoff. Final synchronization is rechecked after pushing this record.
- Checkout normalization: A strict post-checkout byte check flagged six text inputs. Each is proven to differ only by CRLF -> LF: converting the current LF bytes back to CRLF exactly reproduces its captured SHA-256. The other 326 inputs, including all four Ogg recordings, remain byte-identical. No semantic application change or test rerun; original evidence is preserved. [Publication identity](focus-sounds/MAIN_SOURCE_PUBLICATION.json) records these exact hashes rather than presenting historical byte hashes as current ones.
- Handoff: Remain on `main`; implementation checkpoint above is the observed HEAD before this documentation-only commit. Earlier verification JSON/manifests are historical snapshots, not assertions that the current branch is still uncommitted. No app release/tag or production installation was performed. Remaining device/listening/iOS procedures stay in the current matrix and device handoff.
