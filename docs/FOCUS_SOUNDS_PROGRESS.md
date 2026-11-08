# Poma focus sounds: implementation checklist and session tracker

Created: 8 November 2026. Last updated: 8 November 2026 (Asia/Kolkata).

This is the working specification, checklist, and handoff record for adding meditation sounds to Poma's focus timer. It supports one continuous implementation run or four separate sessions. Every prompt working on this feature must read this file first and update it before finishing, including partial or unsuccessful runs.

## Current position

| Item | Current record |
| --- | --- |
| Overall status | Session 1 technical work verified; final listening/recording selection pending; production integration not started |
| Repository | `D:\pomodoro` / `Jyotirmay-Singh/poma` |
| Planning baseline | `main` at `0a001d2b37e80c316449898de7419e50e18d1547` |
| Existing appearance | Still celestial background; Sora headings/countdown; Source Sans 3 body text |
| Platforms | Windows, Android, iOS |
| Feature branch | `codex/focus-soundscapes`; HEAD `0a001d2b37e80c316449898de7419e50e18d1547`; feature changes uncommitted |
| Audio delivery | Four bundled CC0 draft Ogg recordings, 3,194,230 bytes; exact hashes verified in Windows release and Android debug payloads |
| Playback library | `flutter_soloud` 4.1.7 qualified in the isolated Windows experiment; 5.2.3 resolver conflict recorded; mobile runtime pending |
| Final recordings | Eight original WAV comparisons acquired/prepared; four bundled drafts. Not auditioned or approved as final |
| Most recent baseline checks | Static analysis and 472 Flutter tests passed on 8 November 2026 during the branch merge; these are historical baseline results, not feature verification |
| Next action | Audition eight comparisons and approve/revise four drafts; Session 2 may implement the documented core against explicitly labelled drafts. Read FOCUS_SOUNDS_SESSION_1.md first |

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
- [ ] P03. Default to Off for both existing and new users. Remember selection, volume, and mute preference locally with backward-compatible defaults.
- [ ] P04. Choosing a sound during a running Focus session explicitly enables that sound. Choosing it while ready saves the choice without starting continuous playback.
- [ ] P05. Start the enabled, unmuted sound on an explicit Focus start or resume. Pause with the focus timer.
- [ ] P06. Stop sound on focus completion, reset, skip, full data reset, and Quit. Break phases remain silent.
- [ ] P07. Sound controls remain available in strict mode without bypassing strict timer restrictions.
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

- [ ] U01. Use Forest and comparable focus apps as quality references for calm hierarchy and restrained interaction. Create an original Poma interface and record the design rationale.
- [ ] U02. Preserve the celestial background, Sora/Source Sans 3 pairing, purple focus accent, teal break accent, and existing design tokens. The countdown and timer controls remain the main visual focus.
- [ ] U03. Add a compact "Focus sounds" control with clear selected sound, playback/mute state, and direct mute access. Keep selection and actual playback distinguishable.
- [ ] U04. Provide a mobile bottom sheet and a suitably sized desktop dialog/popover. Use coherent icons, an obvious Off option, selected states, preview, and volume. Use two columns only when readable; reflow at narrow widths and enlarged text.
- [ ] U05. Support light, dark, high contrast, reduced motion, keyboard operation, visible focus, screen readers, accessible slider values, and existing minimum 48-unit hit areas.
- [ ] U06. Verify narrow mobile, landscape where supported, desktop widths, and 100%/150%/200% text. Content must remain scrollable and controls reachable.
- [ ] U07. Implement real loading, playing, paused, muted, and failure/retry states. Sound actions cannot accidentally change timer state or history.
- [ ] U08. Capture and inspect representative rendered screens using bundled fonts. Refine alignment, spacing, contrast, and hierarchy after inspection; document actual visual evidence.

## Engineering and verification requirements

- [x] E01. Choose a maintained playback solution after a working compatibility spike on the pinned SDK. Document Windows/mobile support, gapless behaviour, native configuration, package size, and dependency trade-offs.
- [ ] E02. Keep the timer domain independent of audio packages. Use a dedicated coordinator, a playback port/adapter, and a fake adapter for meaningful state-transition tests.
- [ ] E03. Bind audio to the session identity/deadline and update background expiry on timer actions. Do not introduce a drifting second source of timer truth.
- [ ] E04. Verify rapid A -> B -> Off switching, stop during loading, reset/completion during callbacks, stale-session events, and disposal. Prevent duplicate players and tick-triggered restarts.
- [ ] E05. Complete Android media-playback service/audio-focus/notification integration and iOS audio-session/background configuration while preserving existing native timer and alert bridges.
- [ ] E06. Load only needed audio, bound buffer/resource use, and release resources when idle. Avoid audio loading, network requests, or preference writes on every timer tick.
- [ ] E07. Verify preference upgrade/defaults, reset behaviour, offline packaged assets, and absence of unrelated storage/history changes using isolated test data.
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
| Background deadline mechanism | Session-bound absolute elapsed lease plus renderer stop cap | Hidden Windows retirement observed +9,165 us; native stop survives blocked Dart. Mobile handler/guard is future work |
| Final recordings | Not approved; provisional #1110/#0219/#0265/#2715 | Exact rights/provenance retained; equal-perceived-loudness audition and final selection pending |
| Preview restoration / interruption policy | Defined in Session 1 record; production implementation/tests pending | Same run/segment/intent only; no mute/zero override; output loss requires explicit Play; competing audio pauses Poma |

## Session checklist

| Session | Scope | State | Completion evidence |
| --- | --- | --- | --- |
| 1 | Audit, audio selection, technical spike, design plan | Waiting for external input/access | Technical artifacts/Windows spike verified; human listening/final recording selection unavailable |
| 2 | Playback, preferences, timer integration | Not started | Pending |
| 3 | Professional UI and visual review | Not started | Pending |
| 4 | Mobile background behaviour and final verification | Not started | Pending |

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

- [ ] S2.1. Implement the coordinator/adapter boundary and backward-compatible local preferences.
- [ ] S2.2. Wire real focus transitions and session deadlines; handle fades, preview cleanup, errors, reset, disposal, and stale asynchronous work.
- [ ] S2.3. Complete Windows playback, navigation/minimise/tray continuity, sleep reconciliation, and Quit behaviour. Identify remaining mobile work explicitly.
- [ ] S2.4. Add and run meaningful fake-adapter/state/persistence tests, including rapid switching and callbacks after mute/completion.
- [ ] S2.5. Update requirement states, decisions, platform evidence, and this tracker; hand off the functioning core to Session 3.

### Session 3: professional UI

- [ ] S3.1. Implement the compact Focus control and adaptive chooser using production playback/preferences.
- [ ] S3.2. Complete actual selection, preview, mute, volume, loading, error/retry, and keyboard/screen-reader behaviour.
- [ ] S3.3. Capture mobile/desktop, light/dark, enlarged-text, and selected/playing/muted/error layouts; inspect and refine them.
- [ ] S3.4. Run relevant interaction/layout/accessibility regressions. Confirm timer controls and strict-mode boundaries remain correct.
- [ ] S3.5. Update this tracker with actual visual evidence and unfinished platform gates; hand off to Session 4.

### Session 4: background audio and acceptance

- [ ] S4.1. Finish native Android/iOS background playback, audio focus, media controls, headset handling, and session-bound expiry without breaking native timer/alert bridges.
- [ ] S4.2. Verify the platform acceptance matrix below, including real audible loops and locked/background deadline behaviour where hardware is available.
- [ ] S4.3. Run relevant formatting, analysis, regression/native checks, and available builds; verify packaged audio/notices, offline first use, preference upgrade/reset, and resource impact.
- [ ] S4.4. Record any unavailable device/signing access and the exact pending procedure. Do not present unavailable checks as passed or the platform as fully accepted.
- [ ] S4.5. Reconcile every requirement, retain unresolved items, update this tracker, and deliver reviewable changes with validation and limitations. Do not install/publish implicitly.

## Platform acceptance matrix

Use `Pending`, `Pass`, `Fail`, or `Unavailable` in each cell, with an evidence reference and source/build identity. Baseline tests do not count as feature evidence. For mobile sleep, test screen lock/backgrounding; for Windows sleep, verify safe reconciliation after wake rather than claiming audio plays during sleep.

| Check | Windows | Android | iOS |
| --- | --- | --- | --- |
| Actual packaged app loads all four sounds offline | Pending | Pending | Pending |
| Listening: loop joins, loudness, natural decays, no distracting peaks | Pending | Pending | Pending |
| Focus start/pause/resume/reset/skip/completion and strict controls | Pending | Pending | Pending |
| Navigation/minimisation or screen lock/background playback | Pending | Pending | Pending |
| Audio stops at the focus deadline while UI is hidden/locked | Pending | Pending | Pending |
| Sleep/wake or lock/unlock reconciles expiry without stale replay | Pending | Pending | Pending |
| Device/headphone/Bluetooth changes and applicable interruptions | Pending | Pending | Pending |
| No audio after explicit mute, expired session, Quit, or cold relaunch | Pending | Pending | Pending |
| Preferences survive restart/upgrade; full reset clears them | Pending | Pending | Pending |
| Responsive UI, text scaling, contrast, keyboard/assistive technology | Pending | Pending | Pending |
| Relevant build/native checks and package-size/resource observations | Pending | Pending | Pending |

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
