# Poma 1.0.0 build 2007 candidate preparation

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

## Candidate-specific standalone phone run — not yet observed

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
- Candidate ARM64 artifact budget ≤20 MiB, bundletool download estimate and
  five cold/five warm usable-startup samples (<1.5 s cold median); first-install
  startup is a separate measurement. Store-reported download size is unavailable
  before authorized store processing.
- Attributable frame p95 (60 Hz provisional ≤16.67 ms), matched three-by-20-minute
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
