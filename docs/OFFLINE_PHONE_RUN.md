# Motorola standalone acceptance record and remaining matrix

Completed operator observations are recorded below for build 2006 on Motorola
moto g54 5G / Android 15. Read [the test ledger](TEST_LEDGER.md) first: do not
repeat completed flows. This release-mode package is development-signed;
production distribution remains separate. Unverified rows are evidence gaps,
not instructions to repeat passed cases. Use synthetic task names only.

## Completed operator reports — 22 October 2026

| ID | Requested conditions and result | Evidence / limits |
| --- | --- | --- |
| OFF-01 | USB unplugged, airplane mode on, Wi-Fi/data off: normal reopen without a reported gate. | Operator: “yes it opens normally”; `artifacts/session-8/offline-operator/offline-reopen.json` |
| OFF-02a | Set Focus and Short break to one minute. Start Focus, lock 90 seconds, reopen: Short break Ready, one added focus-history record. | Operator confirmed requested steps passed; `artifacts/session-8/offline-operator/offline-focus-break-confirmation.json` |
| OFF-02b | Manually start Short break, another app in front for 90 seconds, return: Focus Ready, no additional focus-history record. | Same operator confirmation; successor does not start automatically |

The exact concluding reply was “They have passed, am I now ready to go to the
next session? tell me briefly”. These are operator-reported passes under the
instructed disconnected conditions, not independently connected inspections.
Do not repeat these timer flows merely to collect omitted details. Alert
appearance/sound, exact latency, delayed-alert wording and actual permission
choice were not reported. Ask for recollection before proposing a new observation.
The first fresh-install opening was reported with internet ON; offline initial
initialization remains unverified. No PID death or repeated offline restart was
proved by the reports.

## Remaining scope by case

Before starting, finish the attached profiling and package checks. The tester
will confirm when the release is ready. Stop development servers, disconnect
the USB cable physically, enable airplane mode, and turn Wi-Fi and mobile data
off explicitly. Keep these conditions throughout the run. Record the phone
model/OS, build, approximate start time and any deviation. Do not count attached
observations or removal from Recents as disconnected ordinary process death.

| Case | Action and expected result | Observed result |
| --- | --- | --- |
| Fresh first launch | After a fresh installation, first open Poma while physically disconnected and offline. Focus is ready, with no login, loading/network gate or missing assets. | Unverified |
| Local settings | Set durations/rounds and appearance; switch tabs. Values remain local. | Partial operator pass: Focus/Short break one minute. Long break, rounds, appearance and restart persistence unverified offline |
| Tasks | Add `Offline test`, select it, rename it, complete/reopen it, then delete it. Start another synthetic task's focus and rename that task while running; the current/history title retains its original snapshot. | Unverified |
| Focus controls | Start, pause, wait, resume and reset. Paused time stays fixed. Skip prepares the next phase ready, without history. | Unverified |
| Break controls | Exercise start/pause/resume/reset/skip on both break types. Skipping/finishing a break adds no focus record. | Unverified |
| Strict mode | Enable strict mode and start a phase. Pause/reset/skip and timing changes are locked, while tasks/appearance remain usable. Full reset remains available with confirmation. | Unverified |
| First permission denial | When asked, choose Enable alerts and deny the Android notification permission. The timer still works and Poma explains alert unavailability. Choosing Not now in Poma is a different case. | Unverified |
| Grant/revocation | Grant through Phone notification settings, return with Back, then revoke during a started phase. The phase remains usable; denied delivery is not promised. Restore permission afterward. | Unverified |
| Another app in front | Started phase completes; successor stays ready. | Short-break case passed by operator (OFF-02b), no extra focus history. Disconnected focus variant unverified; attached focus case passed (DEV-02). Alert presentation/sound unreported |
| Locked screen | Started phase completes; successor stays ready. | Focus case passed by operator (OFF-02a), one added focus record. Disconnected break variant unverified; attached lock cases retain their scope. Alert presentation/sound unreported |
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
