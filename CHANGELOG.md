# Changelog

## Unreleased — 22 October 2026

### Current-mode Focus screen

- Removed the Focus, Short break, and Long break mode selector, including its large-text dropdown. The dial displays only the current phase.
- Enlarged the countdown and tightened the spacing below the page heading. Focus keeps its purple accent; both break phases use teal in light and dark appearances.
- Measured the text block against the dial's circular inner bounds. Enlarged countdowns move below the ring before they crowd its tick marks, preserving the user's text scale.
- Retained phase-specific Start actions, Pause, Resume, Reset, Skip, round progress, completion feedback, task selection, and strict-mode controls.

A fresh cycle begins in Focus. Completed focus rounds lead to Short break until the configured final round, which leads directly to Long break. Short break returns to Focus; Long break resets cycle progress and returns to Focus. Each successor is ready until the person presses Start. Returning to the tab or reopening Poma restores the saved phase and progress.

Durations and round targets remain configurable in Settings. Defaults are 25 minutes of focus, 5 minutes of short break, 15 minutes of long break, and 4 focus rounds; the round target supports 1–8. The existing timer/controller interfaces, SQLite schema, stored settings, and native alert protocol are retained.

Verification: **163 Flutter tests passed**, including **29 refinement tests**; static analysis and formatting passed. **38 host-rendered captures** include twelve views of the three phases in both themes at normal and 200% text. Checks cover one-, three-, and four-round cycles, configured durations, manual successor starts, stale controls, semantics, contrast, tap targets, scrolling, and saved-state recovery.

See [UI verification](docs/UI_VERIFICATION.md) for reproduction and evidence, [accessibility](docs/ACCESSIBILITY.md) for host checks and phone acceptance, and [architecture](docs/ARCHITECTURE.md#design-intent) for the current layout. Earlier packaged builds and device measurements in [release evidence](docs/RELEASE_EVIDENCE.md) apply to their recorded source snapshots; this UI update has local source/test/render verification.
