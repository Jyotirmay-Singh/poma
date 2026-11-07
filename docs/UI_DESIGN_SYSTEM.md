# Poma UI refinement

## Calm space appearance — 7 November 2026

Windows and mobile share one still sky behind the route tree, including startup
and legal views. Sparse deterministic stars and soft purple/teal radial washes
give the empty space depth. There is no animation controller, runtime image/font
download, blur filter or extra runtime dependency. A separate repaint boundary
retains the painted sky across timer ticks and navigation.

| Role | Dark | Light |
| --- | --- | --- |
| Background | `#0D1528` | `#F2F5FD` |
| Reading surface | `#18233B` | `#FFFFFF` |
| Main text | `#EDF2FF` | `#202A43` |
| Secondary text | `#B8C5DC` | `#52627A` |
| Focus | `#C9BFFF` | `#6854C8` |
| Break | `#81D4CF` | `#147D80` |

System/Light/Dark retain their existing stored values. High contrast has a plain
solid background and the existing accessible system-oriented palette. The sky
cannot intercept pointer input or introduce accessibility announcements.

Dense page content uses contiguous opaque Material reading surfaces while
retaining separate scroll children and semantics. Navigation, dialogs, menus,
legal text and the calendar grid have opaque fills. The timer's center is also
opaque. Existing spacing, reading widths, control sizes and corner radii remain.

| Role | Family | Size / line height | Weight |
| --- | --- | --- | --- |
| Page title | Sora | 24/32 below 700 units; 28/36 above | 600 |
| Section heading | Sora | 20/28 | 600 |
| Countdown | Sora | Dial diameter / 5, capped at 64; height 1.15 | 500 |
| Body and tasks | Source Sans 3 | 16/24 | 400 |
| Emphasized body and chart days | Source Sans 3 | 16/24 | 600 |
| Secondary text | Source Sans 3 | 14/20 | 500 |
| Controls/navigation | Source Sans 3 | 14/20 | 600 |
| Nonessential captions | Source Sans 3 | 12/16 | 500 |

All roles have zero tracking. The countdown uses OpenType tabular figures and
keeps the existing move-below-the-ring fallback at enlarged text sizes. Shared
theme application preserves the distinct font families instead of overwriting
the display roles with the body font.

Sora Medium/SemiBold are static instances of the official variable font at
`7f9a9c5d0ccd1c099cfac420aa27133df1c5fdc4`, created with fontTools 4.60.1. Only
weight instancing and static Windows family/style naming were performed; glyph
outlines were not edited. Source and output hashes, weights and font names are
in `mobile/assets/fonts/SORA_SOURCE.json`. Both files together add 117,648 bytes
before compression. The OFL is registered in About and shipped offline.

The native popup privately embeds both families and uses Sora Medium at 24 units
for its countdown, Source Sans 3 at 16 for body text and 14 for controls. GDI does
not apply OpenType tabular substitutions, so its timer draws fixed digit cells
while retaining the complete accessible static-control text. Header allocation
measures the longest supported duration and stacks before it can crowd the title.
Font availability is tracked independently for the body and countdown families.

Verification and visual review artifacts are under ignored
`artifacts/space-appearance/`. Tests measure contrast over the actual painted sky,
check both production font families, verify stable countdown widths, exercise
controls through the decoration and assert that updates retain the sky's picture
layer. Existing populated mobile, desktop and calendar matrices cover light/dark,
100%/150%/200% text, long content, touch targets and keyboard behavior. Host captures
remain distinct from physical-device acceptance.

The final full Flutter run passed **466 tests**. Native checks passed **233**
coordination/privacy assertions and **43** production-font assertions. Review
output contains **46 mobile, 72 desktop and 17 Calendar images**. The first full
run exposed fresh crash-probe SQLite downloads timing out; probe fixtures now
copy the local immutable native cache into independent output directories, and
the package build hook rechecks each binary's content hash. All six real-process
crash checks pass, including a clean complete-suite rerun. No dependency or
production persistence behavior changed.

## Earlier typography and spacing refinement — 5 November 2026

Implemented 5 November 2026 on top of checkpoint `4ca8607`.

Poma keeps its purple focus accent, teal break accent and circular countdown.
Navigation and supporting content stay quiet so the active phase remains the
visual focus. Text and lists align to a shared left edge; only the timer and
its controls are centered. There are no new runtime services or UI packages.

## Shared foundations

`mobile/lib/ui/design_tokens.dart` owns logical spacing, typography, content
widths and component geometry. `mobile/lib/ui/theme.dart` applies these roles
to controls, lists, menus, dialogs, navigation, inputs and tables.

| Role | Size / line height | Weight |
| --- | --- | --- |
| Page title | 24 / 32 | 600 |
| Section title | 20 / 28 | 600 |
| Body and task title | 16 / 24 | 400 |
| Emphasized body and values | 16 / 24 | 600 |
| Secondary information | 14 / 20 | 500 |
| Controls and navigation | 14 / 20 | 600 |
| Nonessential captions | 12 / 16 | 500 |
| Countdown | Responsive to dial width / 1.15 | 500, tabular numerals |

Sizes are logical units at 100% text scaling, not physical screenshot pixels.
All ordinary text has zero tracking; the countdown uses -1 tracking. Secondary
text uses medium weight and a darker light-theme neutral for readable small text.
The semantic hierarchy is consistent; text is not flattened to one size.

The unmodified Adobe Source Sans 3 Regular, Medium and Semibold fonts ship with
the app. No runtime download or device-wide font installation is used. The
upstream revision, byte counts, Git blob identities and SHA-256 hashes are in
`mobile/assets/fonts/SOURCE.json`; the full SIL OFL notice is bundled and
registered in About → View licenses. Fonts add approximately 1.22 MiB before
package compression. Windows also embeds these assets for its native popup.
Font fallback applies only to missing characters. OS-owned menus, toasts and
system dialogs retain their system typography. The compact native popup uses
the same 16-unit body and 14-unit controls with a 24-unit countdown.

| Spacing token | Logical units | Typical use |
| --- | --- | --- |
| xxs | 4 | Related text and icon/label gaps |
| xs | 8 | Row separation and small gaps |
| sm | 12 | Control padding and compact groups |
| md | 16 | Panel padding and compact page margins |
| lg | 24 | Sections and normal page margins |
| xl | 32 | Wide layout columns and page endings |
| xxl | 48 | Empty-state breathing room |

Controls retain at least 48-unit hit areas. Control corners use radius 8;
panels and dialogs use radius 12. Fine calendar geometry retains explicit
optical measurements where a time slot is smaller than a normal component.
High-contrast appearances retain their explicit system-oriented colors.

## Layout and screen changes

- Tasks, Settings, calendar settings/focus blocks and legal text have an
  800-unit maximum reading width. Focus, Insights/History and Schedule can use
  1120 units. Narrow windows use 16-unit side margins and reflow naturally.
- Existing rail thresholds and the two-column Focus layout are retained and
  named centrally. At enlarged text sizes, content stacks and remains scrollable.
- Page headings share a title, subtitle and adaptive action area. The desktop
  Add task action fits its label; narrow layouts place it below the heading.
  The calendar agenda action has a visible label as well as its icon.
- Task rows keep full wrapping titles, aligned leading controls and consistent
  selected states. Completion and task-selection behavior are unchanged.
- Phone duration settings place decrement, value and increment on one row.
  Labels and controls stack when space or text scaling requires it. Windows
  retains its validated number entry and its existing range handling.
- Schedule status and recovery/settings actions share a row when there is
  enough content width. Date/view controls wrap below. Unloaded, stale and
  failed availability remain explicit, and event details still expose full text.
- History headings, chart labels, tables and record rows use the shared type
  roles. Existing pagination, deletion confirmation and accessible daily totals
  remain intact.
- The native popup privately loads the same font resources, uses matching
  control corners and 8-unit gaps, and places pairs of actions side by side only
  when both labels fit. Enlarged text keeps full-width wrapping actions and
  the existing scrolling and keyboard focus handling.

Timer state, manual phase starts, strict mode, storage, permissions, Google
consent and scheduling confirmations have not been changed by this refinement.

## Validation and review

All Flutter widget tests load the shipped font metrics through
`mobile/test/flutter_test_config.dart`, including tests that do not save images.
The populated-screen, desktop and Schedule matrices now include 150% text in
addition to 100% and 200%. Existing narrow, landscape, light/dark, high-contrast,
contrast, semantics and touch-target checks remain enabled.

`mobile/windows/tests/font_native_test.cpp` uses the actual runner resources to
check private font loading, resolved family, control text heights and stable
native digit advances at 100%, 150% and 200%. It supplements the existing native
desktop suite. It does not install a font or change Windows text settings.

Review artifacts are written to ignored `artifacts/ui-refinement/`. Phone and
desktop captures are host-rendered fixtures, not physical-device acceptance.
Existing physical TalkBack/VoiceOver and installed multi-monitor/DPI acceptance
procedures remain applicable; no new physical observations are claimed here.

Final results for this working-tree refinement:

| Check | Result |
| --- | --- |
| Offline dependency resolution with enforced lockfile | Passed; no package upgrades |
| Flutter regression suite | 460 tests passed |
| Static analysis | No issues |
| Dart formatting | 23 changed/related Dart files clean |
| Native desktop suite | 233 checks passed |
| Production native font resources | 36 checks passed |
| Windows release build | Passed for `lib/main.dart` |
| Font integrity | All three upstream SHA-256 checks matched |
| Review captures | 46 mobile, 72 desktop and 17 calendar images |

The final logs are `flutter-tests-final.log`, `analyze-final.log`,
`native-tests.log` and `windows-build-final.log` in that artifact directory.
The final desktop input check also asserts its screen-reader label after the
duplicate floating visual label was removed. Existing history/About test flows
wait for scrolling layout to settle before interacting with their targets.

## Design references

- [Pomatez](https://github.com/zidoro/pomatez): compact timer/task hierarchy.
- [Super Productivity styling guide](https://github.com/super-productivity/super-productivity/blob/master/docs/styling-guide.md): shared style tokens.
- [Time Cop](https://github.com/hamaluik/timecop): restrained Flutter time-tracking UI.
- [Fluent layout](https://fluent2.microsoft.design/layout) and [typography](https://fluent2.microsoft.design/typography): spacing, alignment and semantic hierarchy.
- [Material typography](https://m3.material.io/styles/typography/applying-type): semantic roles and tabular timer figures.
- [Linear refresh](https://linear.app/now/behind-the-latest-design-refresh): quieter supporting chrome and predictable action positions.
- [Source Sans 3](https://github.com/adobe-fonts/source-sans): one offline family for app-owned surfaces.
