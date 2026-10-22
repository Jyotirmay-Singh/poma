# Poma 1.0.0 build 2007 release candidate

This report tracks the new owner-ID candidate separately from development build
2006. The release is not store-ready while the gates below remain open.

## Source and evidence boundary

Application/bundle ID: `com.jyotirmaysingh.poma`; store registration remains
unverified. Version: `1.0.0+2007`. The final build receipt records the source
commit, exact APK/AAB hashes, signing certificate, lockfile and tools.

Reused baseline: source `2613cbcb552095c5a37573729d2086def3ed81a8`, successful
CI 39729543402; 165 Flutter + eight Android JVM + ten Swift simulator tests.
Lockfile SHA-256: `64ce0ae60072093a53fb57e305e7f8f944383e54e55852f6d8b0063ffb9d84ef`.
The source guard verifies unchanged timer/controller/storage/native logic and
lockfile before allowing that evidence to be reused. The only entry-point
addition registers bundled native licenses. About/legal/version/build/assets
receive focused new checks. Existing 120 launch samples, CPU/RSS probes and
build-2006 operator passes remain valid only for their recorded artifact.

New test setup failures are retained: an offscreen lazy-list target required
scrolling; a pushed document route needed its first pump before real asset I/O.
Those were test-harness fixes, not timer/database regressions. The focused retry
passes; raw attempts remain under `artifacts/release-2007/checks/`.


## Built candidate and actual results

Frozen application source: `d0a6a4204258ec0ab4d44ff26ea79fd065b71f25` on `codex/poma-offline-release`.
[CI 39820922409](https://github.com/Jyotirmay-Singh/poma/actions/runs/39820922409)
passed Android and macOS release-only jobs. Full baseline suites were deliberately
reused, not reported as new passes. Later report/verification-tool changes do not
change the compiled application.

All artifacts are under ignored `artifacts/release-2007/final/`:

| Artifact | Bytes | SHA-256 |
| --- | ---: | --- |
| `poma-1.0.0-2007-android-arm64-release-test.apk` | 18,330,655 | `b0a12f845bde38a9e6a6be8eb15b99cb025fa8da83299764f6c8fb729df0080b` |
| `poma-1.0.0-2007-upload.aab` | 51,603,344 | `b6a7034d0105a7e5391bef5ba6216b47aefe752b3e25d257f26c982cd4206904` |
| `poma-1.0.0-2007-ios-UNSIGNED.xcarchive.zip` | 46,753,575 | `bffcabe53bad89d8687a11a03a88958aba5236808e7c7db33ec931a3b1019183` |

The APK is installable and the AAB is an owner upload-key signed Play candidate.
The iOS ZIP is an **unsigned macOS-built inspection archive**, never an installable
IPA, TestFlight build or phone result. The Android certificate SHA-256 is
`3037138217eca1e603bde6cd0134659c100191bf64fc2fdd15499c1dcdf54d87`; it is the owner's new RSA-3072 upload certificate,
not Android Debug or a future Play-managed signing certificate.

| New check | Actual result |
| --- | --- |
| Changed-file format/static analysis | Passed locally and in CI for five changed Dart inputs |
| Focused About/policy/200%-text tests | Three passed in CI; corrected local About retry passed. These add three distinct tests, not another 183-test run |
| Missing signing credentials | Explicit assembleRelease and aggregate build dry runs correctly rejected release signing |
| Android signatures/metadata/alignment | APK/AAB verified, matching owner signer, expected ID/version, non-debuggable, 16 KiB alignment |
| APK/AAB payload parity | Shared ARM64 native libraries and Flutter assets identical |
| Android package privacy | No INTERNET/wake-lock/foreground-service permission; allowBackup=false; nine domains excluded in each legacy/cloud/transfer section; three private app receivers retained; no signing-key file packaged |
| Offline legal assets | Current policy/native/Pomatez texts match source; complete generated Flutter notices retained (1,377,731 decoded bytes) |
| ARM64 size | **17.48 MiB**, passes provisional 20 MiB artifact budget |
| Modeled G54 download | **8,468,423 bytes** using bundletool 1.18.3 and the previously recorded G54/API 35 spec; owner-key signed generated splits. Not store size or a new device observation |
| iOS compilation/archive | Passed on **macOS 26.6.2 / Xcode 26.6 (17F113)**, Flutter 3.44.2/Dart 3.12.2; never built on Windows |
| iOS static inspection | Expected ID/version; unsigned root; matching legal assets; four privacy manifests with app API reasons retained; no root ATS override/background modes; three Mach-O load inventories with no XCTest dylib reference. Bounded evidence only |

Portable summary: `docs/release-2007-evidence.json`. Raw receipts, member inventories,
signature/alignment/backup XML logs, CI logs/environment and size model are retained
under `artifacts/release-2007/`. macOS artifact ID 12444517812 has downloaded ZIP
SHA-256 `b7874e1744e76f7fa759b4b1aea9a367be1c4304422574a45076cfa12198a2d7`.
These files and developer tools are not runtime dependencies. No app/store release
or public download was published.

## Candidate-specific standalone phone run â€” not yet observed

No phone was attached at the initial installation check. No installation,
launch, alert, screenshot, startup, energy or transfer result for build 2007
is inferred from build 2006 or from compilation.

1. Record the exact candidate APK hash/signing, model and OS. Install without
   launching. Stop developer services; physically unplug; enable airplane mode
   and explicitly disable Wi-Fi/mobile data before the first launcher opening.
2. Confirm ready Focus with no account/network gate. Create/select a synthetic
   task; set one-minute phases, two rounds and an appearance preference.
   Exercise initial notification denial: timer controls still work, the status
   is honest and prompts do not loop. Pause/resume/reset must not add history.
3. Grant alerts deliberately through settings. Start focus, lock across expiry,
   record actual generic alert appearance/sound/latency or suppression. Reopen
   twice: one history record with the original task title, Short break ready.
   Manually start Short break with another app in front; return to ready Focus
   without another focus-history record. Verify tasks/settings persisted.
4. Combine remaining controls/strict/full-cycle/deletion and permission-action
   cells from OFFLINE_PHONE_RUN.md with this walkthrough. Record each cell's
   actual observation, including not tried. Do not reset real personal data.
5. Reconnect only after disconnected observations finish. Verify installed
   package identity separately and collect candidate screenshots. Ordinary PID
   death, force-stop, reboot, clock/timezone changes, Doze/DND and exact-access
   revocation need their separately documented methods and actual outcomes.

Force-stop can suppress Android alarms until reopening; powered-off phones
cannot show an alert while off. UTC recovery after reboot/iOS process restoration
can be affected by manual clock changes. Accepted OS local requests do not imply
continuous app execution. Every next phase still requires a manual Start.

## Open gates

- Android phone connection: native integration entry point, exact candidate
  installation, first offline opening, matrix, TalkBack and real screenshots.
- Candidate ARM64 artifact budget â‰¤20 MiB, bundletool download estimate and
  five cold/five warm usable-startup samples (<1.5 s cold median); first-install
  startup is a separate measurement. Store-reported download size is unavailable
  before authorized store processing.
- Attributable frame p95 (60 Hz provisional â‰¤16.67 ms), matched three-by-20-minute
  unplugged energy windows, and actual backup/transfer including sidecars.
  No device/instrumentation means open, not passed. Do not repeat the old
  120-launch cohort, seeding or empty frame/rail captures.
- iOS signed archive/IPA, installation, VoiceOver, backup/transfer and physical
  iPhone acceptance: paid Apple membership, owner team/certificates/profiles and
  Mac/device installation access are missing. Unsigned macOS CI is separate.
- Owner review of final store materials, full embedded notice/legal scope,
  public policy URL, store ID availability and authorization/access for any
  TestFlight upload, store submission or public publication.

Build/install instructions are in BUILD_AND_INSTALL.md; policy and questionnaire
drafts are in PRIVACY_POLICY.md and STORE_MATERIALS.md. Raw evidence and private
keys are excluded from source. No public download or store release is created.
