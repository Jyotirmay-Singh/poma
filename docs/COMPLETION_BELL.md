# Completion bell

Poma includes one original two-second bell for natural Focus, Short break and
Long break completion on Android, iOS and Windows. Settings → Alerts contains
Completion bell (initially on) and Preview bell. Completion alerts remains the
delivery master switch. Existing disabled alerts are never enabled by this
upgrade. Skip, including credited early Skip, Pause and Reset do not ring.
The next phase still waits for Start.

Sound uses normal system notifications. Permission, channel settings, volume,
Silent/Focus/Do Not Disturb and system delivery policy can silence or delay it.
Windows requires a resident process and installed MSIX identity; sleeping or
exited delivery is not added. There is no media-volume fallback, critical alert,
new permission, additional playback dependency, periodic timer or background
service. Ambient focus sounds retain their independent preferences and native
deadline shutdown.

## State and delivery

`bellEnabled` is stored in existing notification-state JSON and copied into each
request. Missing fields in older records mean true; existing alert enablement
and database schema version are preserved. Sound edits use the existing command
and persistence queue, replace the current generation/OS request and preserve
its original elapsed deadline. Timer completion never waits for a sound file to
decode or an audio engine to initialize.

A single `pendingCompletion` request preserves an **already accepted** mobile OS
request across a live natural timer transition. Foreground reconciliation may
otherwise clear the current request before Android's receiver or iOS's foreground
delegate gets its turn. The marker is committed with timer/history changes;
receivers accept current or naturally completed identities, never just an
arbitrary previous/cancelled request. Synchronization retains an existing
request but never schedules an absent/expired completion marker. Cancellation,
reset, disabling alerts and cold startup retire it. Android's existing unique
delivery receipt and iOS's stable one-shot request identifier prevent repeated
reconciliation from repeating presentation. Windows retains post-commit receipt
handling; switching the bell off also silences a completion awaiting save retry.
The additional live state stays bounded; no history scan or per-tick native
query is added. Arbitrary crashes and OS interventions cannot guarantee audible
exactly-once delivery.

Android uses versioned audible and silent timer channels. Migration copies
legacy importance, silence and custom sound choices; a legacy default sound
becomes the new bell unless Android records an explicit sound choice. Existing
channels are not deleted or rewritten, and DND bypass is never requested.
Silent completions also suppress grouped-child audio, so a later OS override of
the silent channel cannot make Bell Off ring. iOS uses a bundled named sound or
nil. Windows uses the packaged WAV in toast audio or an explicit silent tag.

Preview uses a reserved notification ID/group, not any session or Calendar
identity. It can test sound while the app's bell or completion-alert switch is
off, subject to OS permission/quiet-mode rules. Requests are serialized with
reset and throttled natively for two seconds. Preview does not start a timer,
earn history, change settings, or request permission. The UI says requested,
blocked, or unavailable; it never claims audibility.

## Asset and verification

The canonical WAV is `mobile/native/resources/raw/completion_bell.wav`:
176,444 bytes, two seconds, 44.1 kHz mono 16-bit PCM. Android includes that shared
native resource directory, iOS copies the same source into its app bundle, and
Flutter bundles it for Windows's `ms-appx` URI. Reproduce it with
`rtk proxy python scripts/generate_completion_bell.py`; no external samples are
used.

Automated coverage includes legacy JSON, all phase endings, cancellation,
generation/deadline preservation, strict-mode controls, save failure/retry,
SQLite close/reopen, cold recovery, preview concurrency/isolation, native channel
contracts and the actual Settings screen at 100%/200% text. Swift tests cover
named/silent sound, bundled WAV and natural-completion identity retention.
Windows checks cover packaged audio URI, explicit silence and preview isolation.

Physical listening remains a separate acceptance step: install each exact build,
test focus and both breaks foreground/background/locked, mute and quiet modes,
permission/channel changes, rapid controls, and ambient audio at expiry. Record
device/OS/build, notification settings, observed sound/count/latency and resulting
timer/history. iOS requires a Mac/Xcode and an appropriately signed device build.
Host tests and resource inspection do not establish that a device played sound.

### Local verification — 19 November 2026

| Check | Observed result |
| --- | --- |
| Complete Flutter suite | 1,088 passed, including the new bell and SQLite-reopen cases, crash probes, enlarged text and contrast checks |
| Static checks | Analysis clean; changed Dart files formatted; whitespace check passed |
| Android native JVM suite | 10 tests passed, no failures/errors |
| Windows native suites | All four CTest targets passed: 251 desktop, 43 font, 15 audio-guard and 25 mobile-audio safety checks |
| Android arm64 debug build | Built; native raw resource and Flutter asset both match the canonical WAV byte for byte |
| Windows release and unsigned MSIX | Built; packaged toast WAV matches the canonical source byte for byte |
| iOS | Shared resource path/Copy Bundle Resources inspected; Xcode compilation and Swift tests not run on this Windows host |
| Installed listening | Not observed; foreground/background/lock/quiet-mode listening remains required on the exact device builds |

Run Flutter tests and the Windows app build **sequentially**: Flutter replaces a
shared SQLite native asset during builds, and Windows cannot replace that DLL
while tests have it loaded. Isolated crash probes now also copy the shared
notification resource directory declared in the manifest.

Local verification packages retain the repository's version-2007 baseline;
they are not a separately versioned, signed upgrade candidate. The Windows
package is unsigned. Artifact locations and SHA-256:

- Android: `mobile/build/app/outputs/flutter-apk/app-debug.apk` —
  `d9c11c1a1feb57727236a7d3285c35bf84b047d9579caeceadc8d9df26b64172`
- Windows: `artifacts/completion-bell/windows-unsigned-20261119/Poma-1.0.0.2007-x64.msix` —
  `8264d7984a902a880fa6106b19e403f139f55f8e67409ccd1ef1a174a96874c1`
- Canonical bell: `d0271ccb9390ad2be58ae2735c623873da77937e6687927561bea641a21e8441`
