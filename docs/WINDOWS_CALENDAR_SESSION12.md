# Windows Calendar Session 12 — explicit focus scheduling

Implementation and verification record, 3 November 2026 (Asia/Calcutta).

The approved write specification is implemented as an optional Windows workflow:
separate consent/capability, dedicated-calendar provisioning and recovery,
confirmed durable operations, deterministic event IDs, GET reconciliation,
checked ownership and ETag-protected edits/deletion. The Calendar page separates
focus blocks from calendar settings. Mobile remains an offline timer.

## Verification ledger

- Initial controller fault-test baseline: 1 model test passed, 23 workflow tests
  failed against placeholder handlers, before the production handlers were added.
- Scheduling/consent fault checks: 45 passed in the recorded intermediate run.
- Google transport/boundary checks: 17 passed in the recorded intermediate run.
- Expanded native Windows suite: 230 passed, including actual DPAPI/CAS and
  independent journal leases, persistent disablement and Windows DST rules.
- Final complete Flutter suite: **414 passed**, including four actual process exits
  at pending/sending/server-committed/acknowledged boundaries and new identity,
  retention, scope-upgrade, ETag, storage and UI cases. Static analysis is clean.
- Windows production integration: **1 passed**, 67 seconds after compilation.
  Actual native services/SQLite, tasks/settings, exact pause/reopen, one completion,
  manual successor and strict mode were checked using a marked fictional profile.
- Build-configuration checks: **11 passed**. Both development-profile isolation
  runs were restored with original hashes; all 22 historical 2020 kit files remain
  byte-for-byte unchanged.
- Readable fictional previews/status at 100% and 200% text were rendered and
  inspected. The automated font fixture lacks OS emoji fallback; exact Unicode
  text/HTTP payload assertions pass. Native font/OS accessibility gates remain.
- Evidence: [automated summary](../artifacts/windows/calendar-session12/automated-summary.json),
  [Flutter](../artifacts/windows/calendar-session12/flutter-full.log),
  [native](../artifacts/windows/calendar-session12/native.log),
  [Windows integration](../artifacts/windows/calendar-session12/windows-e2e.log),
  [analysis](../artifacts/windows/calendar-session12/analysis.log).
- Live L01-L05 and installed candidate acceptance: pending owner participation,
  a verified reader and exact grant on disposable personal-account resources.

The first native run timed out in COM activation after the storage checks. The
test previously reused the installed application's CLSID. It now uses a fresh
test-only CLSID, retaining the production default identity; the final native run
completed in under one second. The first integration run timed out waiting for
a frame. The harness now explicitly shows its marked test window before pumping;
the failed fixture was archived and the test rerun from a clean isolated profile.
The final full UI run also corrected platform-override cleanup using the test
framework's Windows variant. These harness failures are not recorded passes.
Transport checks exposed and fixed a coalesced
GET future awaiting itself. Calendar-control tests are being updated for the
new navigation destination, with lock redaction retained.

## Privacy and scope

Ordinary Connect requests only calendar-list read and event read. Enable focus
scheduling separately requests those scopes plus `calendar.app.created` through
the same Desktop client. Candidates need exact raw grant evidence, replacement
refresh material, same-account verification and candidate refresh before atomic
promotion. Failure preserves the reader. App-created scope is a Google resource
boundary, not a promise of marker-only access. Poma enforces its narrower guards.

The separate unencrypted focus journal contains titles, times, operation IDs,
ETags and ownership snapshots. Task associations remain local. No notes/history,
attendees, recurring writes or notification operations are uploaded. Offline,
restart and connectivity callbacks never send mutations. Local disablement,
disconnect/reset and Quit invalidate pending work without deleting remote events.

## Private pilot

Signed candidate: **1.0.0.2022**, same package/client/publisher/certificate.
[Installer](../artifacts/windows/Poma-1.0.0.2022-session12-pilot/Poma-1.0.0.2022-x64.msix),
SHA-256 `f4ee904a095a120fe0c26b2e6dd737149c958e2f39fc43a57e86e68dcfb8de90`; 15,958,595 bytes.
Build source SHA-256: `92c0c6a63b0412098c49c018f016393cd6bb8fb25f4a66364c496a3217b34266`.

Final native suite: **233 passed**, including an additional native barrier that
invalidates old-account focus leases during credential replacement, before Dart
publishes the new account. A queued worker cannot recreate purged old-account
records in the acknowledgement/crash window. The 2021 intermediate kit is
preserved and superseded by 2022. No Dart production code changed after the clean
414-test run; the final native barrier has its own direct regression checks.

Installed 2021 launched with package-local SQLite/Flutter/CRT and restored its
saved reader with scheduling disabled. This does not establish 2022 installed
or live write acceptance. The owner confirmed API/test-user readiness; account
confirmation and the first declined-upgrade check are pending owner response.

Both development-profile test runs were restored with original hashes. The
installed closed-data backup was completed after the 2021 package upgrade,
before its first launch, following a hashing-module failure. It is not recorded
as a pre-upgrade backup. No certificate trust or Windows privacy setting changed.
No publication or live Google mutation has been performed by the agent.

## Final artifact checks

- [Complete private kit](../artifacts/windows/Poma-1.0.0.2022-session12-pilot-private-pilot-kit.zip):
  16,078,530 bytes, SHA-256 `00da592fec82561f99dd309f2adfee4abdb84bb442725d8811ab6fc5ae1820ec`.
- Installer SHA-256: `f4ee904a095a120fe0c26b2e6dd737149c958e2f39fc43a57e86e68dcfb8de90`; source digest `92c0c6a63b0412098c49c018f016393cd6bb8fb25f4a66364c496a3217b34266`.
- [Final audit](../artifacts/windows/calendar-session12/kit-final-audit.json):
  all 56 payload hashes verified, exact optional scope metadata, valid identities,
  complete local runtimes/licenses and no selected privacy-scan findings.
- [Installed runtime observation](../artifacts/windows/calendar-session12/installed-runtime.json)
  is **2021 only**: executable, SQLite, Flutter and three CRTs resolved to its
  installed package. Poma displayed the restored saved reader as Connected with
  scheduling Disabled. No private account labels/event content are copied here.
- The final 2022 installer is ready; its live/installed acceptance remains open.
  Consent, creation/edit/delete, personal-account provider boundary checks and
  reviewed recovery must be observed before their rows are marked passed.
