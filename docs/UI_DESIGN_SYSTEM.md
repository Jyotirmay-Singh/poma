# Poma UI refinement

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
