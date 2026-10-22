# Poma mobile

Flutter source for the Android and iOS Pomodoro app. See [the project README](../README.md) for setup, capabilities, architecture, and release requirements.

Run from this directory with `rtk proxy flutter run`, or use `../scripts/flutter.ps1` on Windows. SQLite stores settings, tasks, and history on the phone.

## Focus screen

The Focus tab displays the current phase inside a single timer dial. It has no Focus/Short break/Long break selector or large-text mode picker. The countdown uses larger tabular digits; when enlarged text would crowd the ring, it flows below the dial. Focus uses purple and both breaks use teal in light and dark appearances.

1. A fresh cycle opens in Focus. Choose a task if desired and press **Start focus**.
2. Completing a focus round displays a ready Short break. Press **Start short break**; completing it returns to a ready Focus.
3. The configured final focus round displays Long break directly. Press **Start long break**; completing it clears cycle progress and returns to a ready Focus.

Pause, Resume, Reset, Skip, and app-level strict mode retain their existing behavior. A skipped/reset focus adds no completion. Returning to the tab or reopening the app restores the saved phase and progress rather than starting a new cycle.

Set durations and the focus-round target in Settings:

| Setting | Default |
| --- | --- |
| Focus | 25 minutes |
| Short break | 5 minutes |
| Long break | 15 minutes |
| Focus rounds before Long break | 4; configurable from 1 to 8 |

See the [changelog](../CHANGELOG.md), [UI verification](../docs/UI_VERIFICATION.md), and [accessibility checks](../docs/ACCESSIBILITY.md). The 22 October 2026 update passed 163 Flutter tests, static analysis, and formatting, with 38 host-rendered captures. Follow the build-specific release record before using earlier packaged artifacts to assess this source update.
