# Isolated focus sound spike

Developer experiment for Poma Session 1; not a product entry point. This runner
has no Poma singleton, database, tray identity, notifications, accounts or profile
restoration. Its only file output is an explicitly supplied evidence report.

Use the pinned Flutter 3.44.2 / Dart 3.12.2 SDK. Build outputs and captures are
ignored. Source, exact dependency lockfile and measurements remain reviewable.
Audible quality and mobile background acceptance are separate from automation.

## Reproduce on the existing host

1. Copy the four exact `mobile/assets/audio/*.ogg` files into this package's
   ignored `assets/` directory; verify hashes against ASSET_PROVENANCE.json.
2. From the repository root, use the local RTK executable to run
   `powershell -File experiments/focus_sound_spike/run_flutter.ps1 pub get --offline --enforce-lockfile`.
   The helper creates generated plugin junctions without changing Developer Mode.
3. Run that helper with `analyze --no-pub`, `test --no-pub`, and
   `build windows --release --no-pub`.
4. Run `rtk proxy python experiments/focus_sound_spike/record_bundle.py assets`,
   then `rtk proxy python experiments/focus_sound_spike/measure_run.py assets`.
   Use `D:/pomodoro/.tools/rtk/rtk.exe` if RTK is not on PATH.

Only the explicit `--self-test --report=<path>` entry point starts automated
playback; ordinary launch is silent and offers a developer qualification action.
The utility hides only its own verified window. It uses a real sleep-inclusive
clock, native renderer stop, and an experimental lease guard. It never imports
Poma's data/controller or requests completion alerts. Do not run on a user's
installed Poma profile, and do not confuse this utility with the planned UI.

`measure_footprint.py` temporarily omits asset declarations, builds/records the
library variant, restores the manifest in a finally block, and builds/records the
assets variant from identical source/lockfile. `fixtures/baseline/` retains the
exact no-audio inputs used with this same Flutter-generated Windows runner.
Outputs live under ignored `artifacts/focus-sounds/session-1/`.

SoLoud 5.2.3 fails this SDK's meta constraint; the actual qualified version is
**4.1.7**, not a dependency override. The current result is 88 backend checks and
three guard tests. Output-device changes, phone background behavior, actual
listening and production coordinator races remain separate acceptance work.
