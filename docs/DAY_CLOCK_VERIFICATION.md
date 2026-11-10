# Day Clock — Session 3 verification

9–10 November 2026, Asia/Calcutta. The owner approved deterministic fictional
providers only. This report distinguishes production-code tests and host Flutter
renders from actual Google, installed-app and assistive-technology acceptance.

**Status: complete in source, deterministically verified and compiled.** The final
complete Flutter suite passed **709 tests** in 3m 15s. The final feature/capture
run passed **168 tests** and produced **284 actual Flutter PNGs**. Analysis and
formatting are clean; native Windows checks passed **4/4 executables, 331
assertions**, and Windows Release compilation passed in **77.7s**. Live Google,
installed-app and physical assistive acceptance remain pending.

## Finished interface and fixes

- Filled sectors retain their real half-day positions, opaque small hub and four
  visible overlap lanes. Measured Sora numeral boxes reserve clear space between
  sectors, overflow highlights and ticks at 100/150/200% text. Pointer selection
  uses the same measured radii. Labels appear only when their complete boxes fit.
- The healthy schedule state uses a compact wrapping status/action area. Stale,
  incomplete, unloaded and error explanations retain their full reading surface.
  Agenda dividers replace repeated card outlines; selected/focused rows have
  explicit outlines and retain full titles, source labels and exact details.
- The form groups endpoint dates, explicit AM/PM times and elapsed duration.
  Saved has one read-only summary from the persisted intent: title, both endpoint
  dates/times/offsets, timezone, duration, account, destination, colour and Busy/Free.
  Open event, Show calendar and refresh/coverage notices remain available.
- Disabled Refresh text now retains readable contrast. Reduced motion removes
  the dialog transition. Closed-loop traversal and Escape return focus to the
  opener; when a narrow scrolled dial has removed its opener from the sliver
  tree, the page rebuilds a visible Add task button before restoring focus.
- Enlarged-text validation captions wrap completely. Saved refresh/hidden-calendar
  notices are derived from current reader state and clear after recovery instead
  of retaining a warning from the original save.
- Outcome checking cannot apply a late result to another draft/account or a
  changed lifecycle context. Unbound/disconnected drafts receive an actionable
  connection instruction rather than being told they require an original account.
- Ordinary minute ticks update only the hand/centre overlay. Tests retain the
  actual static dial and sky picture layers and count zero additional provider
  requests, reader-cache writes or creation-journal writes during that tick.

The separate reader, consent owner, focus writer/ownership checks and creation
journal remain in use. No new permission, runtime dependency or persistence
format was introduced in Session 3.

## Central acceptance: observed with fictional transport

Actual widget field entry and pointer Save actions use the production form,
controller, Google HTTP adapter and shared reader. The remote endpoint is a
fictional in-memory Google transport; no Google account is accessed.

| Check | Observed result |
| --- | --- |
| Selected date/half | 10 November 2026, PM; future relative to the controlled 9 November clock |
| Title/account/destination | Fictional evening planning; synthetic-primary; Personal (primary), actual destination ID synthetic-primary |
| Reviewed local interval | 2026-11-10 10:00 PM–11:00 PM; India Standard Time / Asia/Kolkata, UTC+05:30 at both endpoints |
| Provider endpoints/duration | 16:30Z–17:30Z; exactly 60 elapsed minutes; ordinary default event |
| Double Save plus lost response after commit | One POST, one provider event and one verifying GET; original client-generated event ID retained |
| Shared result | One PM sector at minutes 600–660, sweep pi/6; one chronological agenda entry with the same identity as the shared Calendar reader |
| Explicit event colour | Google ID 2, actual retained swatch #33B679 |
| Calendar colour default | No event colour ID; source-calendar fallback #123456 |
| Saved result | Immutable date/time/destination details; one Saved heading and validated Open event action |

Representative actual Flutter evidence:

![Reviewed creation form with fictional data](../artifacts/day-clock/session3/screenshots/creation/gesture-reviewed-colour.png)

![Immutable Saved summary](../artifacts/day-clock/session3/screenshots/creation/gesture-saved-colour.png)

![One 10–11 PM sector and one matching agenda entry](../artifacts/day-clock/session3/screenshots/creation/gesture-clock-colour.png)

## Acceptance matrix

These results are automated and deterministic. They do not imply an observed
live Google pass. The final complete-suite log records the exact named tests.

| Scenario | Evidence and expected boundary |
| --- | --- |
| Double-click Save | Actual pointer tests plus controller duplicate checks produce one operation/event. |
| Timeout after accepted insert | Production writer readback verifies original identity, markers and payload; no second insert. Foreign/changed events are not adopted. |
| Restart and checking/retry | Four child processes exit at kept draft, Sending, server commit and Saved acknowledgement. Durable journal/server files reopen; startup never inserts. Verified absence permits explicit same-ID retry. |
| Consent declined or partial | Candidate-scope, wrong-account and protected-commit tests preserve prior reading/focus receipts. The declined-consent form retains fields and visible explanation. |
| Account/disconnect during pending work | Post-transmission disconnect retains the possible provider event without compensating deletion. Pending checking cannot populate a replacement account draft; native replacement barriers reject old leases. |
| Read-only or inaccessible destination | Shared/read-only and lost-owner checks reject insertion. A missing calendar cannot establish event absence or authorize retry. |
| Offline draft then online | Actual Keep draft survives offline access failure. Reconnection performs no POST; renewed review and explicit Save create the event. |
| Saved with failed reader refresh | Saved receipt and event link remain authoritative. Reader failure cannot become a failed creation or fabricate a sector. |
| Hidden destination | Explicit Show calendar preserves other selections. Hidden/refresh-failed Saved UI retains one result; showing and refreshing yields one agenda entry. |
| Outside retained window | Save can be Saved with an event link and honest coverage notice; no invented clock sector. |
| Colours and old cache | Explicit palette IDs remain authoritative; calendar fallback applies only without an override. Optional/damaged palette data cannot discard old cached events; unknown label/colour IDs are visibly unavailable. |
| AM/PM, manual browsing and Now | Refresh/navigation retain manual selection; expired coverage stays explicit. Now resumes following actual date/half and shows a hand only in the real current half. |
| Noon/midnight and overnight | Exclusive-end clipping preserves full event identity/details; creation requires an explicit overnight end date and positive future interval. |
| Recurrence, cancelled/declined | A moved exception replaces its old position while retaining instance identity; cancelled/declined instances stay off the dial and agenda. |
| Dense overlaps | Stable/compacting lanes, four visible lanes, selectable overflow and merged elapsed totals; complete chronological agenda remains accessible. |
| Timezone/DST | UTC instants, offset-qualified creation, fingerprint changes, spring gaps and repeated fall hours retain exact elapsed durations. Ambiguous/nonexistent creation times are rejected. |
| Sleep/resume | Simulated native suspend/resume retains manual PM browsing across midnight; Now returns to the correct next AM hand. Native Windows timezone fixtures do not alter system settings. |
| Hand performance | Actual retained picture layers plus integrated HTTP/cache/journal counters prove presentation-only work. The established five-minute reader cadence remains independent. |
| Keyboard/accessibility | Labelled fields/AM-PM choices, modal traversal, Escape, visible focus restoration, agenda tap semantics and 48-unit row targets are exercised. Host checks do not establish Narrator acceptance. |

## Visual review and reproducibility

The final gallery contains **284 PNGs**: 129 creation and 155 viewing captures.
All PNG chunk checksums were checked successfully. The creation matrix covers
**24 configurations**: 640/1440 logical width ×
100/150/200% text × light/dark × standard/high contrast. Each captures draft,
review, Saved top/bottom and the resulting clock. Ordinary viewing also covers
1080 width; the finished-state matrix reviews dense, selected agenda, retained
stale, empty, disconnected and invalid-form states across all four appearances
and all three text scales, with scrolled captures as needed.

The production-font renders use fictional events and actual Flutter widgets;
the generated concept is only the design reference. Painted text checks retain
the 4.5:1 requirement. Geometry checks measure numeral/tick/sector clearances;
screen-reader semantics and practical selection alternatives complement them.

Review selections:

- [Ordinary wide dark](../artifacts/day-clock/session3/screenshots/viewing/ordinary-1440-100-dark.png)
- [Dense high contrast at 200%](../artifacts/day-clock/session3/screenshots/viewing/finished-dense-640-200-dark-contrast.png)
- [Light form at 150%](../artifacts/day-clock/session3/screenshots/creation/review-1440-150-light-bottom.png)
- [Narrow Saved at 200%](../artifacts/day-clock/session3/screenshots/creation/saved-640-200-dark-bottom.png)
- [Declined consent](../artifacts/day-clock/session3/screenshots/creation/consent-declined-fields-retained.png)
- [Hidden destination with refresh failure](../artifacts/day-clock/session3/screenshots/creation/saved-hidden-refresh-failed.png)

Run commands through the local RTK executable and `scripts/flutter.ps1`. The
recorder `scripts/record_day_clock_verification.py` saves exact argument arrays,
start/finish times and exit codes. Use `--dart-define-from-file` with the local
[capture settings](../artifacts/day-clock/session3/capture-defines.json) to rerender
the fictional UI. This avoids Windows argument splitting of multi-equals defines.
Keep screenshots under the ignored Session 3 directory; no fixture enters lib/.
Viewing and creation captures use separate subdirectories to prevent shared
form filenames overwriting each other. Intermediate captures are preserved
outside the final gallery.

## Final checks and identity

| Check | Final result |
| --- | --- |
| Final feature/capture suite | **168 passed**, 1m 35s; includes final recovery/wrapping assertions and four process exits; [log](../artifacts/day-clock/session3/captures-final.log) |
| Full Flutter regressions | **709 passed**, 3m 15s; includes all expanded feature cases; [log](../artifacts/day-clock/session3/flutter-final.log) |
| Static analysis | **No issues**, 17.1s; [log](../artifacts/day-clock/session3/analysis-verified.log) |
| Formatting | **134 files, 0 changes**, 0.98s; [log](../artifacts/day-clock/session3/format-final.log) |
| Windows native | 4/4 executables; 248 desktop + 43 fonts + 15 audio guard + 25 mobile safety = 331 assertions; [log](../artifacts/day-clock/session3/native-tests.log) |
| Windows Release compilation | **Passed**, 77.7s; [log](../artifacts/day-clock/session3/windows-final.log) |
| Evidence integrity | Final [manifest](../artifacts/day-clock/session3/verification-manifest.json) and [audit](../artifacts/day-clock/session3/final-audit.json); hashes, local links and final capture-run provenance checked |

Base commit: `c3625a68774f0478146f4abb84e5b039d52465f9`. Sessions 1–3 remain
uncommitted for review. Flutter **3.44.2**, Dart **3.12.2**, framework
`c9a6c484230f8b5e408ec57be1ef71dee1e77020`; release entrypoint lib/main.dart.

The manifest hashes **205 source/test/native/asset/workflow inputs**, **44 runtime
files**, all **284 final captures**, the verification records and documentation.
Source-input set SHA-256:
`c4c5704e3072585ae137b07557338b9ebeb32ab4cc4e2686b64445016dfb83ce`.

- Executable: mobile/build/windows/x64/runner/Release/poma.exe; actual file version
  **1.0.0.2007**; SHA-256
  `bf3d74c7a2928d5e8b9f49d15a9b4bb910404257ada3ed4669d8e23c59ce8e93`.
- Compiled Dart image: data/app.so; SHA-256
  `21aad6f36b54fdad1f1d02065efd2f5bd23f22402073449f967b8789d9a7254d`.
- The native runner is unchanged from Session 2; the Dart image identifies this
  new interface/controller build. No private Google defines were supplied.
  This is an unconfigured compilation, with the unchanged 1.0.0+2007 source
  version, and does not replace the installed 1.0.0.2027 application/profile.

Intermediate runs exposed a geometry initializer error, disabled-text contrast,
an enlarged-form fixture scroll race, CalendarDate identity assertions, a
scrolled-opener focus failure, persistent recovery notices and clipped validation
captions. Those were corrected. Final successful runs
supersede intermediate/failed logs; overlapping run counts are not additive.

## Remaining acceptance and limits

| Evidence category | Status |
| --- | --- |
| Production-code deterministic tests / host Flutter renders / native checks | Recorded above |
| Live Google OAuth, decline/partial grants, creation and Google UI readback | **Pending — owner selected deterministic-only testing** |
| Installed configured Windows package, real notifications/tray, DPI and actual sleep/resume | **Pending — no installation performed** |
| Narrator/other assistive technology and physical keyboard/touch operation | **Pending — host semantics are supporting evidence only** |
| Publishing / signing / installer preparation | **Separate action; not performed** |

Live acceptance requires an explicitly authorized disposable owned calendar and
named test events using Poma's configured Desktop OAuth flow. Compare exact
title, date, device-zone offsets, destination and one-hour duration in Google,
then confirm one PM sector and agenda identity. Exercise consent, recovery,
hidden selection, actual restart/resume and independent Focus behavior in that
identified installed build. Do not use a personal schedule implicitly.

Existing limits remain: Windows-owned-calendar creation only; seven retained
viewing dates; explicit review after offline drafting; Keep draft requires a
verified account (otherwise fields remain in memory); calendar data is locally
unencrypted while credentials/receipts retain DPAPI protection. Custom label-only
colours remain unavailable. Invitations, recurrence authoring and arbitrary
remote editing/deletion are outside the feature.
