# Motorola standalone acceptance procedure

This is a pending operator procedure, not a record of passed tests. Use the
identified build 2006 release-mode validation APK. It is development-signed;
production distribution remains separate. Use synthetic task names only.

Before starting, finish the attached profiling and package checks. The tester
will confirm when the release is ready. Stop development servers, disconnect
the USB cable physically, enable airplane mode, and turn Wi-Fi and mobile data
off explicitly. Keep these conditions throughout the run. Record the phone
model/OS, build, approximate start time and any deviation. Do not count attached
observations or removal from Recents as disconnected ordinary process death.

| Case | Action and expected result | Observed result |
| --- | --- | --- |
| Fresh first launch | After a fresh installation, first open Poma while physically disconnected and offline. Focus is ready, with no login, loading/network gate or missing assets. | Unverified |
| Local settings | Set Focus, Short break and Long break to one minute and rounds to two. Select an appearance; switch tabs. Values remain local. | Unverified |
| Tasks | Add `Offline test`, select it, rename it, complete/reopen it, then delete it. Start another synthetic task's focus and rename that task while running; the current/history title retains its original snapshot. | Unverified |
| Focus controls | Start, pause, wait, resume and reset. Paused time stays fixed. Skip prepares the next phase ready, without history. | Unverified |
| Break controls | Exercise start/pause/resume/reset/skip on both break types. Skipping/finishing a break adds no focus record. | Unverified |
| Strict mode | Enable strict mode and start a phase. Pause/reset/skip and timing changes are locked, while tasks/appearance remain usable. Full reset remains available with confirmation. | Unverified |
| First permission denial | When asked, choose Enable alerts and deny the Android notification permission. The timer still works and Poma explains alert unavailability. Choosing Not now in Poma is a different case. | Unverified |
| Grant/revocation | Grant through Phone notification settings, return with Back, then revoke during a started phase. The phase remains usable; denied delivery is not promised. Restore permission afterward. | Unverified |
| Another app in front | Manually start a focus, switch to another app and wait beyond expiry. Return: one completion, ready successor. Record whether a generic local alert appeared/sounded, without a task title. | Unverified |
| Locked screen | Manually start a break, lock the phone and wait beyond expiry. Record alert presentation/sound. Unlock: the correct successor remains ready, with unchanged focus history. | Unverified |
| Manual full cycle | From a fresh cycle complete Focus → Short break → Focus → Long break. Press the matching Start each time. Long break returns to ready Focus with zero progress. Wait on a ready successor: it must not start or add history. | Unverified |
| Restart/durability | Close/reopen Poma with paused and ready state. Reopen twice after a completed focus: history must not duplicate. Tasks/settings/history remain local and usable. | Unverified |
| Ordinary process termination | Requires a separately identified OS/test method proving the original PID died before expiry without force-stop. Recents removal and activity recreation do not establish this. Attached build-2006 evidence has passed; disconnected case remains separate. | Unverified |
| History/deletion | Browse history; delete one record, clear history and confirm tasks/settings persist. Full reset during a strict phase restores defaults and empty tasks/history; reopen to verify durability. Deletion is not a forensic-erasure claim. | Unverified |

Report each case as passed, failed or not tried, with the actual result and any
alert sound/presentation observation. Reconnect only after the offline checks
are finished so the build identity and final state can be checked separately.
Human observations establish their stated scope, not sampled launch latency or
packet-capture completeness.

Force-stop, reboot, manual clock/timezone changes, exact-alarm revocation,
low-power/Doze/OEM suppression, backup/phone transfer and matched unplugged
energy windows require separate methods/results. None is a pass from this
checklist. Force-stop can suppress Android alarms until reopening; UTC-based
reboot recovery can be affected by clock changes. Actual store sizes, physical
iPhone 16 acceptance and production signing remain separate release gates.
