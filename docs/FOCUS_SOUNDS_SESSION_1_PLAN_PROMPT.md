# Session 1 prompt: research, audio assets, architecture, and design

Copy the prompt below into a new chat in Plan mode. After reviewing the resulting plan, use the app's implementation action or switch to execution mode to carry it out. This prompt covers Session 1 only.

---

You are the senior Flutter developer, audio-experience designer, and product designer for Poma, an existing offline focus app in `D:\pomodoro`. Plan Session 1 of its meditation-sound feature in sufficient detail that implementation can proceed without unresolved routine decisions.

## Mode, scope, and working rules

This request begins in Plan mode. Perform read-only repository inspection and current internet research. Do not implement code, install dependencies, download or edit recordings, build a prototype, change branches, or modify the tracker while the host restricts you to planning. Plan those actions for execution mode. Do not claim that a proposed spike, audition, or visual review has already happened.

When the plan is subsequently implemented, execute its Session 1 work completely and update `D:\pomodoro\docs\FOCUS_SOUNDS_PROGRESS.md` before finishing. While still in Plan mode, provide the proposed tracker update in the plan; apply it at the first permitted execution step. Do not mark implementation or acceptance checkboxes complete merely because a plan exists.

Read the current repository instructions and `D:\pomodoro\RTK.md`. Prefix shell commands with RTK; if it is not on PATH, use `D:\pomodoro\.tools\rtk\rtk.exe`. Preserve unrelated changes. Inspect the actual checkout instead of assuming the recorded baseline is current. Plan to create or resume `codex/focus-soundscapes` when implementation starts. Do not plan an unrelated redesign, deployment, installation, or merge into main.

## Understand the current application first

Read the tracker in full, including its P01-P14, A01-A07, U01-U08, E01-E10 requirements, things-not-to-do list, session log, and acceptance matrix. Also inspect:

- `D:\pomodoro\README.md`
- `D:\pomodoro\docs\ARCHITECTURE.md`
- `D:\pomodoro\docs\UI_DESIGN_SYSTEM.md`
- `D:\pomodoro\docs\SPACE_APPEARANCE_RELEASE.md`
- `D:\pomodoro\docs\LOCAL_DATA.md`
- `D:\pomodoro\docs\NOTIFICATIONS.md`
- `D:\pomodoro\mobile\pubspec.yaml` and `D:\pomodoro\mobile\pubspec.lock`
- `D:\pomodoro\mobile\lib\application\app_controller.dart`
- `D:\pomodoro\mobile\lib\domain\timer_engine.dart`
- The existing storage, native clock/alert bridges, desktop lifecycle, Focus screen, and relevant tests identified from the actual source.

Explain the existing ownership of focus state, session identity, deadlines, persistence, notifications, strict mode, and Windows tray behaviour. Identify extension points from actual files and symbols. Do not invent class names or assume there is already an audio subsystem.

Pay particular attention to the mobile foreground refresh ticker stopping in the background. The audio feature must eventually stop at the real focus deadline even when the Focus screen is hidden or the phone is locked. A second UI countdown is insufficient.

## Define the listening experience

Plan four offline sound choices plus Off:

1. Tibetan bells: warm, softly struck singing-bowl/bell tones, spacious timing, complete natural decays, and no startling metallic attacks.
2. Waterfall: a gentle, steady small waterfall with a soft texture, avoiding a harsh roaring wash or intrusive splashes.
3. Ocean waves: slow, small, calming waves, without abrupt crashes, strong wind buffeting, speech, or distracting gull calls.
4. Forest birds: restrained woodland birdsong with quiet natural ambience, avoiding piercing close calls, repetitive alarm calls, people, or prominent traffic.

Explain that these are selection criteria, not an objective ranking of the world's most relaxing recordings. Plan to compare at least two viable candidates per category where available, at equal perceived loudness, and record why each final choice suits sustained focus. Listening that cannot be performed must remain an explicit acceptance item.

Research the original recording pages and exact licenses. Begin with the tracker candidates, but choose better material if justified:

- Tibetan bells: https://bigsoundbank.com/tibetan-bowl-struck-s1110.html
- Waterfall: https://bigsoundbank.com/small-waterfall-2-s0219.html
- Ocean: https://bigsoundbank.com/beach-small-waves-s0265.html
- Birds: https://freesound.org/people/BurghRecords/sounds/490846/

Verify rights to edit and redistribute the particular recording inside a focus/relaxation application. Prefer CC0 or a suitable explicit license. Public playback availability and the words "royalty-free" are not sufficient. Account for attribution requirements and distinguish a recording's rights from a provider's API/service terms. Do not use ripped streaming-service audio or approve a paid purchase without user authorization.

Plan an asset-provenance record containing creator, source URL, license/version and retained evidence, acquisition date, original identity, editing steps, final asset path, SHA-256, duration, channels, format, and byte count. Plan the app's notices/credits update. Keep raw masters and temporary working files outside the shipped payload unless needed.

Specify loop preparation: select stable regions, remove unintended silence/clicks, preserve decays, create appropriate seam transitions, balance loudness, avoid clipping, and verify the shipped encoding on the actual player. Do not assume looping an MP3 guarantees an inaudible join. Measure final asset size separately from playback-library overhead; quality and tested seamlessness determine the format.

## Choose a playback architecture through evidence

Use current official documentation and package-maintainer sources to compare flutter_soloud, just_audio with its Windows implementation and mobile background integration, and audioplayers or another justified maintained solution. Check compatibility with Poma's pinned Flutter/Dart and native platform requirements; do not upgrade the application broadly just to use the newest package.

Compare native platform support, real loop/fade capabilities, interruptions and device changes, background controls, deadline scheduling, dependency footprint, licensing, packaging, maintenance, and testability. Separate advertised support from behaviour proven by an execution-mode spike.

Recommend a default and a fallback, explaining why. Define the smallest useful execution-mode spike: play a bundled candidate, loop it, change volume, stop/dispose it, and demonstrate the intended deadline mechanism on the available host. Specify what Windows execution can establish and what requires Android/iOS tools or devices. A successful desktop loop is not proof of locked-phone expiry.

Plan an application-level audio coordinator with a platform playback port/adapter and fake adapter. Keep audio package imports out of the timer domain. Define the ownership and interfaces sufficiently for Session 2, including session binding, intent versus actual playback, cancellation generations, resource disposal, errors, and preference defaults.

Resolve the intended policies for Off, persistent mute and volume, choosing a sound while ready/paused/running, ten-second previews, preview restoration, interruption resumption, cold launch, and full reset. Respect the tracker: cold launch must be silent, breaks remain silent, strict mode permits music controls, and zero volume must not be overridden.

## Establish the professional UI direction

Use Forest and comparable focus apps as references for restraint, clarity, and finish. Do not copy their identity, assets, layouts wholesale, or gamification. Preserve Poma's celestial background, Sora/Source Sans 3 pairing, purple/teal accents, and existing design tokens.

Plan a compact Focus sounds control near the timer's supporting controls, with a clearly named current sound and mute/playback state. Keep the countdown and main timer controls dominant. Plan a phone bottom sheet and a restrained desktop dialog/popover, with four coherent sound options, an obvious Off choice, preview, and volume.

Provide text wireframes or layout descriptions, component responsibilities, responsive rules, state descriptions, and a visual-critique checklist. Cover light/dark/high contrast, keyboard focus, screen-reader labels, 48-unit targets, reduced motion, and 200% text. Avoid continuous equalizers, animated backgrounds, heavy blur, decorative clutter, and placeholder interactions.

## Required planning deliverable

Return a decision-ready Session 1 plan containing:

1. Verified current-source findings and important constraints.
2. Audio-candidate/license comparison, editorial criteria, and unresolved listening gates.
3. Playback comparison, selected provisional approach, and execution spike with pass/fail criteria.
4. State/ownership design and the background-deadline strategy to validate.
5. Original visual direction, responsive behaviour, and state wireframes/descriptions.
6. Ordered execution tasks and actual affected files, dependencies, risks, and fallback paths.
7. Verification methods distinguishing static checks, working playback, listening, visual review, and device acceptance.
8. Proposed tracker updates and a precise Session 2 handoff.

When executing the plan, complete S1.1-S1.5 as far as access permits, retain actual assets/license records and spike evidence, and update the tracker after the prompt even if work is partial. Leave unchecked items honest. Do not proceed into broad Session 2/3 implementation or silently install/publish anything.
