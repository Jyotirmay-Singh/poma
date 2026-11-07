# Poma space appearance — Windows 1.0.0.2027

7 November 2026, Asia/Calcutta. The private Windows update is installed and
running with the still celestial backdrop and offline Sora/Source Sans 3 pairing.
The [design system](UI_DESIGN_SYSTEM.md) records the palette, font sizes, asset
provenance, scaling and high-contrast behavior.

## Build identity

- Installed package: `JyotirmaySingh.Poma.Desktop_1.0.0.2027_x64__kz516h6tttq8c`.
- Installer source: `24f1701b7a4732b6bd0c57bd83d9948332cafbd3`.
- Candidate directory: `artifacts/windows/Poma-1.0.0.2027-space-appearance`.
- MSIX: `Poma-1.0.0.2027-x64.msix`, **17,583,511 bytes**.
- SHA-256: `497b6443ef6e8f71657781b59b0c72e6b69bb602ae4c81c2e0511a7d7b21d152`.
- Private kit: `artifacts/windows/Poma-1.0.0.2027-space-appearance-private-kit.zip`.
- Kit SHA-256: `715a1069dc9c921787061c3de2d9a3d8e715dc28562cd615a65426cf9dfcd2e2`.
- Existing certificate SHA-256:
  `1CDE2CB78DFABF389C59475EB3684E4837D81AEFADB3723992B02402D328E955`.
- Windows signature status: **Valid**. Identity, publisher, certificate and
  existing owner-local Calendar build configuration were preserved.

Subsequent commits improve verification and documentation; production Dart,
Windows, assets, locked dependencies and release inputs remain identical to the
installer source. The original signed candidate and earlier packages are retained.

## Verification

| Check | Observed result |
| --- | --- |
| Complete Windows-host Flutter suite | 466 passed |
| Corrected contrast/support/appearance checks | 47 passed |
| Static analysis | Clean |
| Formatting | All project Dart files checked |
| Native coordination/privacy checks | 233 passed |
| Native production font checks | 43 passed |
| Windows release compilation | Passed |
| Installed runtime modules | Flutter, SQLite, notifications and all loaded VC runtimes resolved inside the installed package |
| Signed package audit | 63 payload hashes matched; no selected privacy findings |
| Bundled Sora fonts and OFL | Exact recorded hashes matched in Windows and Android packages |
| Android ARM64 debug compilation | Passed; 102,905,836-byte APK |
| Linux Flutter regression suite | 472 passed, including six contrast-check rejection/acceptance cases |
| Android CI build/test job | Passed, including native tests, debug APK, all release ABIs and app bundle |
| iOS simulator/release compilation and native tests | Passed for the installer's exact production source |
| Host review captures | 46 mobile, 72 desktop, 17 Calendar images |

The [iOS job for the installed production source](https://github.com/Jyotirmay-Singh/poma/actions/runs/42397366122/job/128477527577)
compiled the simulator and unsigned release apps and passed native tests.
Linux raster contrast
diagnostics identified antialiasing colors being mistaken for text colors;
the corrected checker retains 4.5:1 and includes rejection cases for genuinely
low-contrast and faded text. The final [Android CI job](https://github.com/Jyotirmay-Singh/poma/actions/runs/42400050811/job/128485665411)
passed all 472 Flutter tests, native Android tests and its complete build matrix
at `1cdd4284c2926d0206f6dc6cadc55de84449ef3e`. Its duplicate iOS job was stopped:
production inputs are unchanged from the completed iOS run above. These separate
job results are the recorded evidence; the later workflow's overall cancelled
status is not presented as a green complete run.

Logs and synthetic review captures are under ignored
`artifacts/space-appearance/`. The original upstream OFL text is retained byte for
byte, including its trailing space; source whitespace checks exclude that vendored
license. No private keys, build-setting secrets, profile backups or generated
packages are committed.

## Installed upgrade and preservation

Poma 2026 was closed using Settings → Quit Poma. A private copy of its complete,
closed LocalState was created in the owner's local Poma Backups directory. All
**five profile files** matched SHA-256 before the update and again after the
in-place installation, before the new app's first launch. Poma was never uninstalled.

After launching the registered 2027 executable, private logical fingerprints
confirmed preserved tasks, history, settings, selected task, timer state and
Calendar files. The app restored Focus / Ready at 25 minutes with the original
25/5/15 durations and four-round setting. The previously unselected Calendar
state was retained; no consent or Calendar write was initiated.

The installed Focus, Tasks, Calendar and Settings pages were visually observed.
The native compact timer displayed Sora's `25:00`, retained its complete accessible
label and showed matching timer/calendar controls. Returning to the main window
dismissed the popup. Poma is left running on Focus without starting a session.

These observations certify this appearance upgrade's recorded checks. Earlier
sleep/hibernate, physical screen-reader, multi-monitor, notification-policy and
clean-machine release gates retain their existing separate acceptance status.
