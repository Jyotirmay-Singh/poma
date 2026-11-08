# Session 2 prompt: playback, preferences, and focus-timer integration

Copy this prompt into a separate chat in Plan mode after Session 1 has been executed. A plan alone is not evidence that Session 1's assets or spike exist.

---

You are the senior Flutter application engineer implementing Poma's meditation-sound feature in `D:\pomodoro`. Prepare a detailed, decision-ready Session 2 plan for reliable playback, local preferences, timer integration, and Windows lifecycle behaviour. The choices are Off, Tibetan bells, calming waterfall, calming ocean waves, and forest birds chirping.

## Mode and session continuity

Begin in Plan mode with read-only inspection and research. Do not edit code, dependencies, Git state, or documentation, run tests/builds that generate files, or start implementation while the host disallows mutations. Plan those steps for subsequent execution. Do not silently change modes or describe planned behaviour as working.

Read `D:\pomodoro\docs\FOCUS_SOUNDS_PROGRESS.md` completely and follow its start/end protocol. Read `D:\pomodoro\RTK.md` and repository instructions; prefix shell commands with RTK, using `D:\pomodoro\.tools\rtk\rtk.exe` when needed. Inspect the actual branch, source, pending changes, last session log, architecture decision, audio manifest/license evidence, and working spike. Resume the real feature work; do not recreate or reset unrelated changes.

Distinguish completed Session 1 execution from proposed work. If routine prerequisites are incomplete, include their completion first. If a consequential dependency cannot be established, state precisely which dependent tasks cannot proceed and continue planning independent work. Do not assume the historical 472-test result validates this feature.

During Plan mode, include the proposed tracker update in your final plan. When the plan is executed, update the actual tracker before finishing, including partial results, failed checks, evidence, and the Session 3 handoff. Keep implementation boxes pending until verified.

## Inspect the actual integration boundaries

Trace timer start/pause/resume/reset/skip/completion, phase transitions, strict controls, persisted state recovery, full local-data reset, and desktop tray/Quit behaviour through current source. Locate existing clock/deadline semantics and serialized asynchronous operations. Identify how to observe accepted transitions without duplicating timer logic or playing sound from widget builds.

Use the architecture chosen in Session 1 unless inspection or spike results provide a concrete reason to change it. Document a justified change and its effects rather than replacing the stack casually. Keep the domain independent of Flutter audio packages and preserve the existing repository/platform boundaries.

Plan the minimum production units: immutable audio preferences, an application coordinator, a playback adapter/port, and an injectable fake for tests. Select actual names and paths consistent with the repository. Explain construction, ownership, notification flow, cleanup, and where platform failures are contained.

## Specify playback as a state and intent contract

Represent saved preference, transient user intent, active session identity, interruption state, and actual player state separately enough to avoid accidental resumption. Define the effective play condition and all ways it becomes false. Use the real timer as the authority for whether a Focus session is running and unexpired.

Provide a transition table covering these cases:

- Fresh installation and upgrade from old preferences: sound defaults to Off.
- Ready timer: choosing a track saves it without continuous playback; preview is explicit and temporary.
- Running Focus: choosing an enabled sound starts/switches it; Off stops it; zero volume stays zero.
- Paused Focus: selection changes do not resume the timer or ongoing sound; timer resume uses the current saved selection and mute state.
- Focus start/resume: play only when enabled, unmuted, and valid for that specific run.
- Reset, skip, completion, or data reset: cancel pending loads/previews and stop playback; neither break phase starts ambient audio.
- Strict mode: music controls work while strict timer restrictions remain intact.
- Page navigation/minimisation/tray: do not dispose an active application's audio merely because a screen disappears.
- Cold launch with a recovered running timer: reconcile time and restore preferences silently until an explicit playback/timer action.
- Quit/disposal: cancel pending work and stop/release the player.
- Device/call interruption: pause or duck according to the recorded policy without changing earned focus time or implicitly pausing the timer.

Define explicit semantics for volume zero, mute, Off, track selection while muted, and restoring the previous audible level. Do not introduce a surprise volume increase. Explain what is persisted and what is transient.

Previews last at most ten seconds and never affect focus accounting. Specify the single-stream policy, how active playback is suspended for a preview if applicable, and whether restoration is allowed. Restoration must recheck the same session, current intent, mute state, and deadline; it cannot revive a completed/reset/muted session. Dismissal or starting a session cancels preview appropriately.

## Prevent asynchronous races

Define a serialization/cancellation-generation approach for play, load, stop, switching, preview timeout, interruption callbacks, and disposal. Cover A -> B -> Off before either load completes; a reset or completion during loading; a late completion from an earlier track; and rapid repeated notifications.

Late work must be harmless, resources belonging to stale requests must be released, and stopping sound must take precedence over queued play. Do not start duplicate players, restart a loop every tick, or allow a preference-save callback to resume audio. Avoid two audible categories during switching; use the agreed fade/replace approach.

Keep errors observable and recoverable without breaking the timer. Define loading/error states, bounded retries, and an explicit recovery action. Avoid retry loops and uncaught asynchronous errors after disposal.

## Preferences, reset, and clock integration

Inspect existing storage/versioning before selecting a persistence change. Specify missing-key defaults, validation, upgrade behaviour, atomicity with relevant settings, and full-reset cleanup. Never delete/recreate the main database because new audio preferences cannot be read.

Persist committed preference changes, not every timer tick or slider frame. Plan a bounded save policy that preserves the final slider value and handles an outstanding save on shutdown without blocking UI unnecessarily. Test the actual storage contract.

Bind audio lifetime to the current focus run and its existing authoritative deadline/remaining-time semantics. The mobile UI ticker is suspended in the background; a new foreground-only timer does not solve expiry. Plan the shared deadline contract and Windows implementation now, and define the native/mobile implementation boundary for Session 4.

On Windows sleep/wake, reconcile against the real session before resuming sound. Do not claim playback during system sleep. Ensure native tray timer commands use the same state owner and stop/update audio through accepted transitions. Keep existing notification actions and completion alerts independent.

## Performance and tests to plan

Load the chosen asset on demand, cache only what is justified, release idle buffers, and avoid per-tick decoding, I/O, writes, polling, and network requests. Use graceful fade durations without delaying an explicit stop excessively. Plan measurement of idle versus playing behaviour and dependency/asset-size impact.

Design meaningful fake-adapter/fake-clock and persistence tests for the transition table and race cases. Include restored preferences, cold-start silence, full reset, strict-mode music controls, failed asset loads, preview expiry/restoration, deadline completion, stale callbacks, repeated state notifications, and disposal. Assert user-visible outcomes and playback effects rather than mirroring private implementation details.

Plan actual Windows playback checks separately: each track loads and loops, volume/mute work, no duplicate sound follows navigation or tray actions, and Quit stops playback. Fake tests do not prove audible seam quality. Use isolated app data and preserve the user's installed profile.

## Required planning deliverable

Produce:

1. Actual prerequisite status and source extension points.
2. Ownership/API design, preference schema/defaults, and playback transition table.
3. Race/cancellation/error-handling strategy and deadline contract.
4. Ordered, file-specific implementation steps for shared code and Windows integration.
5. Behavioural/persistence test matrix and real playback verification procedure.
6. Performance/resource expectations, failure risks, and fallback decisions.
7. Session 2 completion gates mapped to S2.1-S2.5 and affected P/A/E requirements.
8. Proposed tracker update and a specific handoff identifying what Session 3 can consume and what remains for Session 4.

When executing, finish the planned core rather than stopping after interfaces or a proposal. Run relevant checks once changes warrant them, fix introduced regressions, and update the tracker with actual results and unverified gates. Do not add a full UI redesign, alter timer/history semantics, broadly upgrade dependencies, merge into main, or install/publish a release.
