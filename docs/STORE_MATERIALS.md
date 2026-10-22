# Poma 1.0.0 store-material draft

Owner: Jyotirmay Singh. Support/privacy contact:
https://github.com/Jyotirmay-Singh/poma/issues . Public issues must not contain
private task text or unredacted logs. Bundle/application ID:
`com.jyotirmaysingh.poma` (store reservation not yet verified).

These materials are prepared for owner review; no store submission, TestFlight
upload, public release or policy hosting is authorized by their preparation.
The full policy is in PRIVACY_POLICY.md and bundled offline in the app.
A functioning public policy URL must be approved/published before submission;
the local document path is not a substitute for that URL.

## Listing copy

Name: **Poma**

Short description: **Offline focus timer, tasks and history. Start each break yourself.**

Full description:

Poma keeps your focus timer, tasks, settings and history on your phone. After
installation it works without internet, an account or a computer.

- Set focus, short-break and long-break durations and rounds per cycle.
- Start, pause, resume, reset or skip a phase. Each next phase waits for you.
- Choose a task and review your daily and seven-day focus history.
- Use optional completion alerts scheduled by your phone while locked or in
  another app. Permission and OS settings control delivery and sound.
- Choose system, light or dark appearance. Strict mode limits controls inside
  Poma; it does not lock the phone or block other apps.

Poma includes no ads, tracking, analytics, app-operated cloud sync or account.
You can delete history or all local data in Settings. There is no export/import
or automatic recovery after uninstalling or losing the phone. Poma requests
backup exclusions, but OS/OEM backup and transfer behavior can vary and older
backups can retain data. Poma does not encrypt its database itself.

Poma does not run continuously in the background. Force-stop, powered-off time,
Focus/DND, permissions, exact-alarm access and battery/device policies can delay
or suppress alerts. It never starts an unattended chain of phases.

## Google Play Data Safety draft

Based on current app-owned behavior and packaged permissions; final candidate
package review and remaining device observations must stay linked to the answers.

| Question | Prepared answer / basis |
| --- | --- |
| Collects or shares covered user data off device? | No app-operated collection or sharing. Tasks/settings/history are processed locally; no account, ads, analytics or upload path. Local storage is not itself off-device collection. |
| Tracking / advertising ID / ads? | None implemented. No advertising ID permission. |
| Encryption in transit? | Not applicable to app-collected/transmitted data. Do not translate this into a claim of database encryption. |
| Account creation/deletion? | No accounts; account-deletion URL not applicable to this design. Local deletion controls remain available. |
| Backup/OS behavior? | Disclose exclusions and their limits in the policy; OS-controlled backup/transfer and optional GitHub support are separate from developer-operated collection. |
| Notification/exact-alarm purpose? | Optional local phase-completion alerts. SCHEDULE_EXACT_ALARM with user-granted access and inexact fallback; no USE_EXACT_ALARM, full-screen intent or DND bypass. Store eligibility/approval is not claimed. |

Do not claim network-capable transitive packages are all development-only or
that zero coarse UID bytes prove zero socket attempts. Confirm questionnaires
against the current console wording at submission, without changing code behavior.

## Apple App Privacy draft

Prepared answer: **Data Not Collected** by the app owner; **no tracking** and no
advertising identifiers. Task/history content remains local. System diagnostics,
store services, backup/transfer and voluntary GitHub support follow the relevant
provider/user choices. No app-operated diagnostics collection is implemented.

Preserve app/framework privacy manifests and required API reasons: boot-time
interval measurement `35F9.1`, app-private UserDefaults `CA92.1`. The iOS SQLite
directory exclusion does not cover standard UserDefaults scheduling/response
metadata. Final signed entitlements/privacy-manifest review remains blocked by
missing Apple signing. Do not infer that review from a simulator build.

## Screenshot capture sheet

Capture the exact installed candidate with synthetic task names only: ready Focus,
running Focus, ready Short/Long break, Tasks, populated Insights and Settings/About.
Include light/dark and an accessible large-text example. Remove personal OS
notifications from captures. Keep original resolution, artifact/version identity
and device/OS metadata. Use descriptive captions without delivery/sound guarantees.

Existing 38 host-rendered captures are historical supporting layout evidence,
not current physical candidate screenshots. Android physical captures remain
pending phone connection; iPhone captures remain pending signing/installation.
Simulator captures, if produced, must be labelled as simulator captures. Do not
invent screenshots or advertise a platform as device-verified before observing it.
