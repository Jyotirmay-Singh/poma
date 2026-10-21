# Accessibility issue ledger

Updated 21 October 2026. Scope: the standalone offline Flutter app. **Resolved below means implemented and checked on the host, not certified with TalkBack or VoiceOver.** Physical-device acceptance remains open by agreement. No screenshot substitutes for an interaction assertion.

## Host method

`mobile/test/refinement_test.dart` checks populated screens in light/dark appearances at 100%/200% text on Compact phone 320×700, Tall phone 390×844, and Landscape phone 700×320 logical pixels. Tests simulate top/bottom safe insets, reduced motion, long task/history content, keyboard insets, and device locale/time preferences. The app's English copy remains English when device calendar formatting changes.

Android's 48-logical-pixel semantic tap-target guideline is stricter than the iOS 44-point minimum; both platforms still need physical navigation checks. Semantic labels, selected/disabled states, chart alternatives, keyboard submission and focus are asserted. Contrast checks calculate palette ratios and sample fully painted text: clipped text behind a scroll viewport is excluded from raster sampling, because its coordinates can coincide with navigation paint. This exclusion is not a text-size or contrast relaxation. Normal text targets 4.5:1; large text and essential non-text controls target 3:1. Native system-font rendering remains a device check.

## Resolved in host checks

| ID | Priority | Reproduction | Resolution and evidence |
| --- | --- | --- | --- |
| A01 | High | Focus, 120-minute setting, 320×700, 200% text | Measure timer text before placing it inside the dial. Oversized text flows below the ring without clamping the user's scale. Matrix scrolls the full page and rejects overflows. |
| A02 | High | Four destinations, 320×700, 200% text | Navigation text scales and destinations wrap into two rows when needed; selected semantics and minimum target sizes are tested. |
| A03 | High | Focus phase choices at 200% | A labeled native phase picker replaces three stacked chips, preserving readable names and the timer's emphasis. Normal-size chips remain. |
| A04 | High | Settings, 120 min / 8 rounds, narrow screen, 200% | Duration values sit above their decrease/increase controls; labels and control groups wrap. The matrix includes full-page scrolling. |
| A05 | High | Populated Insights with a 160-character history title | History title, local completion date/time, duration and deletion action reflow. Pagination/deletion interaction tests remain in place. |
| A06 | High | Understand the weekly chart without color or sight | Exact dated daily counts and focus minutes accompany the supplementary chart. Today is named in text; each day has one complete semantic description. Narrow/large-text layouts use the text alternative. |
| A07 | Medium | Complete and reopen a task | Checkbox labels distinguish “Mark … complete” from “Mark … incomplete”; row selection has text and selected semantics. An all-completed state explains how to continue. |
| A08 | High | Add/rename a long task with keyboard visible at 200% | Scrollable dialog, input label, blank-name validation, 160-character limit and keyboard Done action. Real input submission and reopening are asserted. |
| A09 | High | Save failure plus clock failure at 200% | Notices and page content share one scroll region. Controls remain reachable; unsaved-data warnings and retry remain visible in the document. |
| A10 | High | Enable strict mode during a phase | Copy states the app-only restrictions and explicitly says other apps and the phone remain available. Timing/timer controls are disabled while task edits remain usable; full reset still explains that it stops a strict phase. |
| A11 | High | Alerts denied, disabled, delayed, unavailable, or failed | Actual adapter state determines copy/actions. Denial opens phone settings; failure retries; Android delayed mode offers precise access. Tests count settings/retry calls and verify no automatic permission prompt. |
| A12 | Medium | Completion followed by repeated reconcile or tab navigation | A completion notice comes only from a real transition, includes overdue recovery, and is keyed to the completed run. Returning to the notice does not create another live announcement. The countdown is not a live region. |
| A13 | Medium | Device locale differs from English UI; 24-hour preference | Calendar formatting resolves the device's supported locale independently of English product copy. Locale/time assertions cover formatting and semantic totals. |
| A14 | Medium | Light/dark and reduced-motion preferences | Text/primary/teal contrast ratios are checked. System typography remains offline; reduced motion disables theme transitions and no decorative motion was added. |

## Open release gates

| ID | Priority | Required observation | Status |
| --- | --- | --- | --- |
| D01 | High | TalkBack swipe order, exploration, selected/disabled state, timer reading, dialogs, task entry, chart alternative, notification recovery and one completion announcement on a named Android phone | Open — hardware not supplied for this milestone. Flutter semantics are supporting evidence only. |
| D02 | High | The same flow with VoiceOver on a named iPhone, including rotor headings and notification/settings return | Open — Mac/Xcode and iPhone unavailable. |
| D03 | High | Real system font sizes up to 200%, Android font/display-size combinations, iOS accessibility sizes, keyboard/IME and cutout/home-indicator safe areas | Open — simulated host viewports do not establish device behavior. |
| D04 | High | Completion while locked and while another app is in front, with permitted/denied/revoked alerts and OS sound/Focus/DND settings | Open — follow the disconnected procedure in UI_VERIFICATION.md and NOTIFICATIONS.md. |
| D05 | High | Compile changed Swift resources/integration and run all ten RunnerTests on macOS | Open — Windows cannot establish iOS compilation or execution. |
| D06 | Medium | Real-device dark-mode changes, reduced motion, keyboard focus visibility and completion speech without interrupted screen-reader navigation | Open — requires device observation. |

Record model, OS/build, app artifact hash/signing, screen reader/version, text/display scaling, orientation, theme, locale, notification settings, steps and observed outcome when closing an item. Retain failures as open items; do not mark them passed from a capture or compilation alone.
