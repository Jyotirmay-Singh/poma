# Focus sounds — Session 3 implementation and handoff

8 November 2026, Asia/Kolkata. Feature branch `codex/focus-soundscapes`, starting
HEAD `6bd18d3e10f348a5b9d5e4958203fc934b3e24fd`. Session 2 local work is preserved.
No installation, merge, push or release publication belongs to this session.

## Production ownership and interface

`AppController.focusAudio` remains the single application-lifetime owner. The UI
does not construct players, run independent audio timers, or persist playback
authorization. Existing sound IDs, schema, deadlines and focus accounting remain.

`FocusAudioPlaybackPort.availability` and immutable state now expose
`FocusAudioAvailability.available/unavailable` without starting the renderer.
The Windows adapter reports available; Android/iOS remain unavailable until
Session 4 supplies their native integrations. The coordinator gates preparation,
while selection/mute/volume still save. User copy explains unavailable playback;
there is no ineffective retry loop or simulated mobile playback in production.

`retry()` returns `Future<int?>`. A failed-preview retry returns its replacement
cancellation token. The chooser tracks that token and a pending-request identity;
late tokens after dismissal are cancelled, and stale owners cannot stop newer
previews. Close, Done, Escape, Back, barrier and drag dismissal flush preferences
and cancel only the owned preview. Restoration remains coordinator-owned.

Volume pointer changes affect gain immediately and commit on interaction end.
Keyboard/accessibility adjustments use existing coalescing. Arrow keys change 1%,
Home/End set zero/full, and dismissal flushes staged values. Mute never replaces
the chosen volume or selection. Sound actions do not enter timer commands.

## Design and adaptive behavior

The compact control uses the actual transport plus preferences and timer phase,
distinguishing Off, selected/ready, loading, playing, paused, zero, muted,
interrupted, route-blocked, errors and platform availability. Preview status is
separate from selection. Localization uses the existing English ARB/generation
mechanism, including percentages and specific accessible preview names.

On split desktop layouts sounds sit beneath timer actions at maximum width 360.
Stacked layouts retain full current task context before sounds; ready state keeps
the next-task card first. The timer dial, Start/Pause, strict restrictions and
existing task/scheduling/alert actions retain their authority.

The phone sheet and 560-unit desktop dialog share an opaque chooser. Off is a
full-width radio choice. The other four use small outline icons and independent
preview actions. Two columns require 480 units of content and <=125% text;
otherwise choices stack. All heights follow text and the whole modal scrolls.
Targets retain the existing 48-unit minimum. The selected radio has explicit
selection text; focused radios/buttons receive visible outlines. Modal focus is
trapped, initially enters selection, and returns to the opener or Focus heading.
Reduced motion removes transition animation. Production fonts and contrast
thresholds were retained.

Reference: https://www.forestapp.cc/ — one clear focal point and restrained
secondary controls. Poma's stationary celestial identity is preserved; no new
artwork, gamification, subscriptions, streaming or runtime dependencies were added.

## Verification and visual critique

Session 3 check commands/logs are retained beneath
`artifacts/focus-sounds/session-3/checks/`. The final verification/source manifests
record actual results and source/build hashes. Earlier failures remain in their
own logs; passing later runs do not erase them.

The capture matrix includes 390x844 and 320x700 phones, 700x320 landscape,
640x600/1080x800/1440x1000 desktops, light/dark/high contrast and 100/150/200% text.
States include Off, selected-ready, playing, paused, zero, muted, loading, error,
preview and unsupported playback, with long fictional task titles. Captures use
bundled Sora and Source Sans 3. Their manifest identifies fake-port host fixtures;
phone-shaped playback images do not establish native phone playback.

Refinements after review: disabled preview labels now use readable secondary ink;
tile selection-label space is reserved so grid rows align; explicit focus edges
distinguish focused radio choices; initial selection scroll preserves already
visible header content; enlarged-text action groups stack without shrinking text.
Duplicate Off summary text was removed. Keyboard Home/End were explicitly handled, and pointer/keyboard volume paths were
separated to preserve coalescing.

The contrast helper is scoped to painted text in the active chooser while it is
open: underlying route text is obscured by the modal and is not valid sampling
input. The 4.5:1 threshold and existing checker are unchanged. Initial fixture
failures also exposed lazy off-screen controls, teardown ordering for fake clocks,
semantics handles and the desktop Calendar timer; fixture lifecycle was corrected.
The first SDK-wrapper attempt lacked cache access; authorized checks used normal
SDK-cache access. A formatter wrapper was replaced with the direct Dart executable.

The isolated Windows target uses production PomaApp, coordinator and SoLoud, with
separate storage/mutex/pipe/tray/notification identities. Its copied runtime is
identity-checked before launch. Only its own hidden window is resized; installed
Poma and real tasks/Calendar data are untouched. Actual renderer captures and
checks distinguish this from fake-player tests and physical listening.

Final results: **533 Flutter regressions**, **24 sound UI checks** (included in
the full suite and rerun for captures), **37 focused audio checks**, clean
analysis/format, **233 desktop + 43 font + 15 guard native checks**, Windows
production/review release builds and Android ARM64 debug compilation passed.
The final isolated Windows runtime passed five production-UI/playback checks.

There are 41 host captures with explicit fixture metadata. Sixteen representative
views were personally inspected: phone Off closed/chooser, ready closed, playing
closed/preview, large muted chooser/footer, landscape-error footer; desktop
playing chooser, 150% paused chooser, 200% zero footer, both high-contrast
choosers, loading closed, focused error/Retry footer and unavailable phone chooser.
Exact paths/checksums are in `focus-sounds/SESSION_3_VERIFICATION.json`.

Four final real-Windows renderer captures were personally inspected under
`artifacts/focus-sounds/session-3/windows-runtime-1794157691406233500/runtime/fictional-review-profile/`:
`windows-playing.png`, `windows-chooser.png`, `windows-preview.png`, and
`windows-muted.png`. The timer remains dominant, task context is readable,
selected/preview states differ, and actual mute is silent by native voice checks.
Scrollable captures show their current viewport; clipped content at the viewport
edge is reachable by scrolling, with dismissal/keyboard behavior separately tested.

S3.1-S3.5 and U01-U08 are complete for this shared/Windows UI and host verification
scope. Physical assistive/device/background/listening requirements retain their
separate pending states. P07's shared strict-mode boundary is verified. Global
P01/P04-P06/P10/P13 remain unchecked despite scoped Windows/shared-UI evidence.
E08 is refreshed; E03/E05, S1.3 and S2.3 remain pending. No production release was
installed, committed, pushed, merged or published by Session 3.

## Session 4 boundary

- Enable Android/iOS only after media service/audio-session/focus, headset/route
  behavior, native session-bound expiry and background/lock handling exist.
- Implement the same availability contract; preserve the coordinator, lease,
  token-returning retry, one stream, independent completion alerts and one DB owner.
- Repeat selection/start/pause/resume, preview/dismissal, mute/zero, errors,
  strict mode, foreground/background/lock expiry, interruptions, route removal,
  cold launch, reset and Quit through production controls on named hardware.
- Perform TalkBack/VoiceOver, real accessibility text sizes/safe areas, Windows
  physical sleep/headphone/Bluetooth/tray checks, and final listening separately.
- Four recordings remain licensed drafts; no listening/final-source approval is
  inferred from these captures, native voice counts or build results.
- No new dependency, schema migration, native mobile permission or release upgrade
  is needed by Session 3. Physical/device/background/listening gates stay open.
