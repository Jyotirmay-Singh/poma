# Session 3 prompt: professional sound-selection UI and visual verification

Copy this prompt into a separate chat in Plan mode after the playback core from Session 2 has been implemented. This session covers production UI and its verification, not a static mockup.

---

You are the senior Flutter product designer and UI engineer for Poma in `D:\pomodoro`. Prepare a detailed Session 3 plan for an elegant, calm meditation-sound interface connected to the real focus timer and playback system.

The five choices are Off, Tibetan bells, calming waterfall, calming ocean waves, and forest birds chirping. Aim for the level of visual care found in established focus apps such as Forest, while creating an original Poma experience and preserving the existing celestial identity.

## Mode and continuity requirements

This begins in Plan mode. Inspect current source, designs, tracker, and existing visual evidence read-only. Do not edit widgets, generate new screenshots/assets, run builds, alter branches, or update files while the host prohibits mutations. Describe those execution steps in the plan. Do not label a planned design or screenshot review as implemented or observed.

Read `D:\pomodoro\docs\FOCUS_SOUNDS_PROGRESS.md` in full, especially U01-U08, playback semantics, things not to do, previous-session evidence, and open issues. Read repository instructions and `D:\pomodoro\RTK.md`; prefix shell commands with RTK or its local executable `D:\pomodoro\.tools\rtk\rtk.exe`.

Inspect the actual feature branch, current changes, and real audio coordinator/preferences APIs. A Session 2 plan is not a working backend. Plan routine missing dependencies first; do not conceal missing functionality behind hardcoded visual states or mock controls.

While still in Plan mode, provide the proposed tracker update with the plan. When implementing it in execution mode, update the real tracker before finishing with actual visual/behavioural results, remaining gates, and the Session 4 handoff. Preserve unrelated work and completed valid evidence.

## Ground the design in the real app

Read:

- `D:\pomodoro\docs\UI_DESIGN_SYSTEM.md`
- `D:\pomodoro\docs\SPACE_APPEARANCE_RELEASE.md`
- `D:\pomodoro\mobile\lib\ui\design_tokens.dart`
- `D:\pomodoro\mobile\lib\ui\theme.dart`
- `D:\pomodoro\mobile\lib\ui\space_backdrop.dart`
- `D:\pomodoro\mobile\lib\ui\focus_screen.dart`
- Existing app-shell, settings, localization, semantics, font, contrast, and responsive UI tests found in the current checkout.

Explain the current mobile/desktop layouts, available space near the timer, existing scrolling and large-text behaviour, and design tokens to reuse. Keep Sora for display/countdown, Source Sans 3 for body/controls, the still space background, purple focus accent, teal break accent, and opaque readable surfaces.

Use current official Forest/product imagery as a visual reference if useful. Cite references and explain the specific quality principle borrowed, such as restrained hierarchy or deliberate spacing. Do not copy artwork, mascots, branding, text, or entire screens; do not add unrelated trees, gamification, stores, or premium sound packs.

## Design the compact Focus control

Plan a compact "Focus sounds" control near supporting timer actions. Keep the countdown, phase, task context, and Start/Pause controls visually dominant. Opening sound settings must not start playback or change timer state.

Show the selected sound and actual state clearly. A saved selection while ready should not look like active playback. Distinguish Off, ready/selected, loading, playing, paused, muted/zero volume, interrupted, and failed states with restrained copy and accessible cues.

Provide a direct mute/playback action whose meaning matches the real coordinator. Avoid tiny unlabeled icon-only actions unless the accessibility label, tooltip, target size, and visual meaning are clear. Sound controls remain available during strict mode without unlocking strict timer actions.

Specify placement and layout at narrow mobile widths, wide desktop widths, and enlarged text. The control must not make the timer unreasonably small, obscure the selected task, or make primary actions inaccessible. At high text scaling, reflow and scroll instead of clipping or shrinking text.

## Design the expanded sound chooser

Plan a phone bottom sheet and a restrained desktop dialog/popover consistent with existing navigation patterns. Include a clear title, dismissal action, four named sound options with coherent icons/illustration treatment, an obvious Off choice, preview, and volume.

Use a two-column sound arrangement only where it remains readable; switch to a single column for narrow or large-text cases. The four categories are parallel choices, not a numbered sequence. Make selection obvious with more than colour alone.

Plan explicit interactions:

- Selecting a sound while ready saves it quietly; while running Focus it switches according to the existing playback contract.
- Selecting Off stops sound and pending loads.
- Preview is labelled, bounded to ten seconds, and follows the coordinator's one-stream/restoration policy. Its state is distinct from the active selection.
- Volume exposes a readable value and preserves zero; mute does not unexpectedly reset volume or selection.
- Dismissal cancels preview and returns focus appropriately without altering the focus timer.
- Loading and errors provide truthful feedback and an appropriate Retry action without disabling the timer.

Do not implement visual-only toggles, fake equalizers, fixed "playing" badges, or independent UI timers driving the sound. Route all actions through the production owner. Keep app-level and transient UI state distinct.

## Accessibility and interaction detail

Specify reading order, radio/selected semantics, accessible names for every preview/mute action, slider labels/values, focus entry and restoration, Escape dismissal, keyboard navigation, touch targets of at least the existing 48 logical units, and appropriate hover/pressed/focus feedback.

Avoid per-second live announcements, using sound or motion as the only status signal, colour-only selection, and continuously animated indicators. Respect reduced motion and high contrast. Keep copy concise, natural, and localized through the existing mechanism.

Account for modal focus trapping, safe areas, small-height/landscape windows where supported, platform back/dismiss actions, and scrolling with 200% text. Reuse existing responsive thresholds and tokens unless actual layout evidence justifies a small documented addition.

## Plan visual verification before coding

Describe the exact views and states to capture after execution: mobile and desktop; light/dark; high contrast; normal and enlarged text; Off, selected/ready, playing, muted, loading, and error states; chooser open and closed; keyboard focus; long labels or realistic longer content.

Choose representative combinations that expose layout risk instead of generating a large redundant screenshot set. Use bundled production fonts and existing contrast/semantics helpers. Do not weaken contrast thresholds or replace real fonts to make checks pass.

Plan an execution workflow of build, capture, inspect, critique, refine, and recheck affected views. Review timer prominence, alignment, rhythm, spacing, opaque readability over stars, wrapping, target sizes, icon consistency, and state clarity. Compilation alone is not visual review.

Use fictional or isolated data for captures. Keep temporary/review artifacts in appropriate ignored locations, with evidence paths and source identity in the tracker; avoid leaking Calendar details or real tasks.

## Tests and completion criteria

Plan widget/interaction tests proving real coordinator actions, saved selection versus playback distinction, strict-mode sound control availability, preview cancellation, volume/mute persistence, error retry, and unchanged timer/history behaviour. Include keyboard focus, semantics, and enlarged-text layout cases. Avoid tests that merely assert an internal helper implementation.

Identify the actual files/components/localization resources/tests to change, how each UI state is supplied by the backend, and the existing screens that need regression coverage. If UI work exposes a necessary coordinator fix, specify the smallest correction and its behavioural test rather than hiding it in the widget.

Return a decision-ready plan containing current-layout findings, original design rationale, component hierarchy, responsive wireframes/descriptions, a state/interaction table, accessibility specifications, ordered file-specific tasks, the capture-and-critique matrix, and S3.1-S3.5 completion gates.

When executed, deliver a production-integrated interface, not a concept screen. Update affected U/P/E checklist states, record screenshots actually inspected and tests actually run, preserve unfinished background/device gates, and hand off exact integration concerns to Session 4. Do not replace Poma's identity, redesign unrelated screens, merge into main, or install/publish a release.
