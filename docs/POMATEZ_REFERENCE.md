# Pomatez reference audit

Source: [zidoro/pomatez](https://github.com/zidoro/pomatez), pinned to `c2727800c6272573590911e9ee81637b89e55d5f` (version 1.11.0). The README lists Windows, macOS, and Linux. The root manifest exposes Electron and Tauri build paths. The mobile starter does not bundle those desktop shells, Node.js, or their dependencies.

Reviewed sources:

- [README](https://github.com/zidoro/pomatez/blob/c2727800c6272573590911e9ee81637b89e55d5f/README.md): supported features and desktop platform scope.
- [package.json](https://github.com/zidoro/pomatez/blob/c2727800c6272573590911e9ee81637b89e55d5f/package.json): workspace and desktop build entry points.
- [defaultTimer.ts](https://github.com/zidoro/pomatez/blob/c2727800c6272573590911e9ee81637b89e55d5f/app/renderer/src/store/timer/defaultTimer.ts) and [types.ts](https://github.com/zidoro/pomatez/blob/c2727800c6272573590911e9ee81637b89e55d5f/app/renderer/src/store/timer/types.ts): initial focus state, round identity, and focus/short/long/special phase taxonomy.
- [LICENSE](https://github.com/zidoro/pomatez/blob/c2727800c6272573590911e9ee81637b89e55d5f/LICENSE): MIT, copyright 2024 Roldan Montilla Jr.

| Reference behavior | Mobile treatment | Starter status |
| --- | --- | --- |
| Custom Pomodoro rules | Configurable focus/short/long durations and cycle length | Implemented |
| Built-in task list | SQLite-backed tasks attached to a focus session | Implemented |
| Dark theme | System, light, dark | Implemented |
| Strict mode | Disable app timer controls during an active phase | Implemented, app-only |
| Desktop notifications | Native scheduled local notifications and permission UX | Required session 3 milestone |
| Full-screen breaks | Current short/long break replaces focus in the same in-app dial, with an explicit Start action | Implemented current-phase screen; no forced overlay |
| Special breaks | Timezone-aware scheduled breaks with explicit conflict rules | Deferred |
| Auto-start work | Each focus/break phase starts through a user action | Outside the confirmed mobile scope |
| Tray, always-on-top, native titlebar | Mobile navigation / future notification controls or widgets | Desktop-only features omitted |
| Desktop updater | Play Store / App Store release process | Session 7 |
| Voice assistance and extra cues | Optional native alerts after accessibility review | Deferred |

History and weekly summaries are new mobile design choices. The familiar 25/5/15, four-round default is the starter's selected Pomodoro policy; the small inspected upstream timer files do not establish those duration values. No claim of full source review or exact desktop feature parity is made.

On 22 October 2026, Poma adopted a current-mode Focus screen: the three phase choices and the large-text picker were removed, while the existing cycle and manual Start behavior were retained. This mobile design decision and its verification are recorded in the [changelog](../CHANGELOG.md) and [UI verification](UI_VERIFICATION.md).

REA is useful for packaged APK/IPA/Electron evidence and can inspect our build artifacts later. Ordinary available source is inspected directly; decompilation is not needed to understand these reference files.

Session 1 rechecked the five pinned source files above on 20 October 2026. The packaged `assets/licenses/pomatez.txt` matches the upstream MIT license after line-ending normalization. The complete notice remains in `THIRD_PARTY_NOTICES.md` and the app's license registry. ZIP/Android SDK tools suffice for package/manifest verification; no REA connection, desktop shell, unrelated MCP server, or native analysis engine is needed for this source review.
