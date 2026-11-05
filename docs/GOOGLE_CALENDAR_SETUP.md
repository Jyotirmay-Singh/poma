# Poma Windows Calendar: owner setup plan

## Optional Session 12 setup

The separate Windows Calendar page now contains connection, calendar selection,
focus scheduling, operation status, reminders and tray privacy. The historical
read-only setup below still applies to ordinary connection and pilot 2020.
For explicit scheduling, confirm Calendar API is enabled for the same existing
Desktop client's project. Keep the current Testing audience and tester restrictions.
In Google Auth Platform Data Access declare exactly these scheduling scopes:

- `https://www.googleapis.com/auth/calendar.calendarlist.readonly`
- `https://www.googleapis.com/auth/calendar.events.readonly`
- `https://www.googleapis.com/auth/calendar.app.created`

Ordinary Connect still requests only the first two. Enable focus scheduling uses
a fresh full-set Desktop flow; installed apps do not use incremental authorization.
The owner handles browser login/MFA/consent. A complete exact grant, replacement
refresh token, same account and verified candidate refresh are required. Decline
keeps the saved reader. Do not revoke rejected tokens or add broader scopes.
Then separately approve Create Poma Focus calendar, or review recovery of a verified
existing Poma calendar. Neither action schedules a block. Every event needs a final
preview and explicit confirmation. Calendar names are not permission boundaries.
Google's app-created scope can authorize calendar resource operations and unrelated
events on eligible calendars; Poma exposes only checked focus-block management.
Before release use the disposable personal-account L01-L05 checks in
[the write specification](WINDOWS_CALENDAR_WRITES_SPEC.md). No Codex connector tokens
may be borrowed. Missing readiness leaves live rows pending, not inferred passes.

Checked against official Google guidance on **25 October 2026** (Asia/Calcutta).
This records Windows Calendar **Session 4** setup and its configuration contract.
**Sessions 5–6 implementation update:** Windows authorization, protected refresh
storage, explicit calendar selection and bounded read-only snapshots now implement
the application contract. Google configuration
and owner-operated live sign-in remain unverified; this is not a live-flow pass.
Read the
[specification](WINDOWS_CALENDAR_SPEC.md),
[session sequence](GOOGLE_CALENDAR_WINDOWS_SESSION_PROMPTS.md), and latest
[handoff](WINDOWS_CALENDAR_PROGRESS.md) together with this document.

**Session 7 update:** the regular agenda popup now consumes the real selected-calendar
read model. Fictional previews remain an explicit separate Settings action.
**Owner setup status:** real authorization and selected-calendar controls are in Settings.
No Google Cloud project, API setting, OAuth client, test-user entry, downloaded
configuration, or real Poma authorization has been verified in this session.
No cloud resources or calendars were changed. The available browser inventory
exposed no Google Cloud Console tab; account access and project permissions were
not established. The plan below is for the owner to follow in their browser.

## 1. Prepare your account and app details

Use a Google account you control. Complete Google password, passkey, MFA and any
account recovery yourself, directly on Google's site. Never send a password,
authorization code, access token, refresh token or browser callback URL to a
chat, issue or handoff.

Prepare these inputs before opening the console:

| Input | What to use |
| --- | --- |
| App owner | Jyotirmay Singh, matching the existing Poma material. |
| Display name | Suggested private-test name: **Poma Windows Calendar (Private Test)**. |
| Project | An owner-selected project dedicated to the private test, or an existing appropriate test project whose other clients will not be disrupted. Record its project ID locally. |
| User support email | A real address you monitor and can select in Google's dropdown. This may be your signed-in Google account or an eligible Google Group you manage. No address has been supplied or invented here. |
| Developer contact email | Your monitored address for Google notices. This is separate from the user support field. |
| Audience | Usually **External + Testing** for a personal Gmail account or testers from different organizations. Use Internal only for a qualifying organization-only deployment; see step 4. |
| Homepage/privacy/terms | Real owner-controlled pages if required by the console or your distribution choice. No Windows Calendar policy URL or domain has been confirmed. Do not enter an example URL. |

The existing [mobile privacy policy](PRIVACY_POLICY.md) applies to Android/iOS.
The bundled [Windows notice](../mobile/assets/legal/privacy-windows.txt)
describes implemented optional Google Calendar access and its unencrypted cache.
The existing
[GitHub support page](https://github.com/Jyotirmay-Singh/poma/issues) is a support
route, not the email required by Google or a verified Calendar privacy page.

Before real consent, supply accurate Windows Calendar disclosures: optional
direct requests to Google; calendar selection and read-only event access; the
seven-local-date cache; an **unencrypted event cache** separate from Pomodoro
records; current-user DPAPI-protected refresh credentials; disconnect/deletion
and offline revocation limits; support contact; and no app-operated backend,
advertising or analytics under this design. Describe implemented behavior when
it becomes available, rather than presenting the design as already tested.

Google documents the support-address choices in
[Manage OAuth App Branding](https://support.google.com/cloud/answer/15549049).

## 2. Select a Cloud project and enable Calendar API

1. Open [Google Cloud Console](https://console.cloud.google.com/) in your browser
   and check the signed-in account.
2. Use the top project selector. Select the project you intend to use. If you
   need a new private-test project, choose **New project**, review its name,
   project ID and organization/location, then create it yourself. Do not alter
   an unrelated production project's consent settings. Google's
   [project instructions](https://docs.cloud.google.com/resource-manager/docs/creating-managing-projects)
   explain the creation permissions.
3. Confirm the same project remains selected. Open **APIs & Services → Library**,
   search for **Google Calendar API**, and open Google's API entry.
4. Click **Enable** if needed. Confirm it appears in **Enabled APIs & services**
   (the API's service name is `calendar-json.googleapis.com`). This enables an
   API for the project; it does not grant Poma access to your calendars.

If you lack project or API-enabling permission, have the project administrator
perform the step. Google documents the relevant Service Usage permissions in
[Enable and disable services](https://docs.cloud.google.com/service-usage/docs/enable-disable).
This plan needs no hosted app backend, service account, API key, VM, database or
paid-service subscription. Do not activate a trial or attach billing as a
workaround for a permissions problem; record any unexpected requirement.

## 3. Configure Google Auth Platform branding

Open **Google Auth Platform → Branding** in the selected project. If prompted,
choose **Get started**. Enter the app name, user support email, audience and
developer contact information from step 1. Review the Google API Services User
Data Policy yourself before accepting it and saving the configuration.

For an already configured project, inspect Branding, Audience and Data Access
instead of restarting the setup. These settings affect the project's OAuth
clients, not just a single Windows executable. Save private-test details without
publishing the app or starting public verification in this session.

Use truthful homepage/privacy/terms links if you enter them. For private Testing,
leave optional URL/logo fields empty until appropriate material is ready. If the
console or your account policy requires a URL, stop that step and supply a real
Windows Calendar policy; do not substitute the mobile-only policy. A local
Markdown file is not a hosted privacy URL. Adding a logo does not verify the app.

See Google's current
[consent setup instructions](https://developers.google.com/workspace/guides/configure-oauth-consent).

## 4. Choose the audience and add testers

| Who will use the private build? | Audience decision |
| --- | --- |
| Your personal Gmail account, or any tester outside one Cloud organization | Choose **External** and retain publishing status **Testing**. |
| Only members of the project's Google Workspace/Cloud Identity organization | **Internal** is available only for an organization-associated project. Confirm eligibility and administrator approval; it will not admit outside Gmail accounts. |

For **External + Testing**, open **Audience → Test users → Add users**. Add the
exact Google account you will later use inside Poma, save, and check that it is
listed. Add other named private testers only when intended. Being the Cloud
project owner does **not** replace the test-user entry. Keep **Testing**; do not
click **Publish app** to resolve a failed test login.

Testing currently allows up to 100 listed test users. Internal eligibility is
different from an external testing allowlist. Follow the applicable branch even
if a quickstart example happens to choose Internal. Google's
[audience guide](https://support.google.com/cloud/answer/15549945) describes these
restrictions and account exceptions.

## 5. Declare exactly the two read-only scopes

Open **Google Auth Platform → Data Access → Add or remove scopes**. Select or
manually enter the following full URLs, then **Update** and **Save**:

| Scope | Poma's reason |
| --- | --- |
| `https://www.googleapis.com/auth/calendar.calendarlist.readonly` | List subscribed calendars so you can choose which calendars to display. |
| `https://www.googleapis.com/auth/calendar.events.readonly` | Read events for the selected calendars to show the agenda and meeting context. |

Check the final saved scope list, including any prefilled entries. Do not add
the broad `calendar` or `calendar.readonly` scope, write scopes, Gmail, Drive,
Tasks or profile scopes for this pilot. Additional identity scopes require a
separate justification in Session 5. Declaring scopes here does not authorize
Poma: its future browser request must ask for the same approved pair and verify
what was actually granted.

The event scope permits reading events across calendars the account can access.
Poma's explicit selection limits what the app fetches; it is not an OAuth
restriction to a single selected calendar. Calendar owner/writer access does
not give this read-only Poma client permission to write.

Review the scope categories shown by Google. Read-only calendar data is still
personal data and can require sensitive-scope verification for public use.
Sources: [Calendar scopes](https://developers.google.com/workspace/calendar/api/auth)
and [Data Access controls](https://support.google.com/cloud/answer/15549135).

## 6. Create the Windows Desktop OAuth client

1. Open **Google Auth Platform → Clients → Create client**.
2. Set **Application type → Desktop app**. Suggested console-only name:
   **Poma Windows Desktop - Private Test**.
3. If **Use this client for an AI-powered agent** is offered, leave it unchecked.
   Poma is an interactive desktop calendar integration; using Codex to build it
   does not make its OAuth client an MCP/AI-agent client.
4. Review the selected project and type, then create the client yourself.
5. Download the client JSON immediately if offered and keep the original
   outside the repository as described in step 7. Google's current console
   guidance says full client secrets are viewable/downloadable at creation;
   do not assume the full value can be retrieved later.
6. Check locally that the client's type is **Desktop** and its downloaded JSON
   has an `installed` object with `client_id`. A `web` object is the wrong type.
   Record the public client ID and project ID locally without posting the file.

A Desktop client does not require a web application's Authorized JavaScript
origins or a list of fixed web callback URLs. Do not create a Web application,
Android, UWP, service-account, device-code or embedded-browser substitute.

Google's [Calendar desktop setup](https://developers.google.com/workspace/calendar/api/quickstart/python)
documents the client type; use its console steps, not its sample scope or
plaintext `token.json` storage. See also
[Manage OAuth Clients](https://support.google.com/cloud/answer/15549257) for the
current download and AI-client options.

## 7. Keep downloaded configuration outside source control

Suggested owner-local directory (expand `%LOCALAPPDATA%` for your Windows user):

```text
%LOCALAPPDATA%\Poma\Setup\GoogleCalendar\PrivateTest\
    google-oauth-desktop.json       original downloaded installed-client JSON
    poma-calendar-defines.json      curated build settings from step 8
```

This directory is outside `D:\pomodoro` and outside the app's timer/database
profile. Create it yourself in File Explorer and move the download there. Do
not leave extra copies in a shared/synced folder. Keep a protected owner backup
if needed. No directory or configuration file at this location was created or
read by this session. Avoid checking the download into source, adding it to
Flutter assets, or copying it into review evidence or a release ZIP.

| Value | Meaning and handling |
| --- | --- |
| OAuth client ID (`…apps.googleusercontent.com`), project ID/number, app name and scope URLs | Public application identifiers/settings, not authorization to anyone's calendar. The curated client ID may be compiled into a desktop build. |
| Downloaded Desktop `client_secret`, if supplied | Extractable desktop compatibility material, not a confidential server-secret boundary. Keep the original download out of Git/chat. A future adapter may need this value, but it never replaces PKCE, state checks or user consent. |
| Passwords, MFA codes, authorization codes, access/refresh tokens | User credentials. Never enter them into build settings, SQLite, source, logs, screenshots or handoffs. Refresh credentials must later use current-user Windows protection. |

The public nature of a Desktop client does not make a Web client secret,
service-account private key or user token public. None of those belongs in this
configuration. Google's
[desktop OAuth guide](https://developers.google.com/identity/protocols/oauth2/native-app)
explains the installed-client boundary.

## 8. Configuration injection contract for Session 5 and packaging

**Defined by Session 4; implemented in Session 5.** Windows composition reads
these settings; absent or invalid settings leave Connect disabled. The fictional
preview never invokes real sign-in.

Use the same **compile-time Dart settings** for development and Windows release
builds. Session 5 reads them with `const String.fromEnvironment` at Windows
composition and inject a validated immutable configuration into the calendar
adapter. Google endpoints and the two approved scopes stay fixed in code, not
editable from this file. This avoids relying on a terminal's environment or a
repository `.env` after someone installs an MSIX.

Create `poma-calendar-defines.json` locally with this shape; the empty client ID
is deliberately **unconfigured**, not a working sample credential:

```json
{
  "POMA_GOOGLE_CLIENT_ID": "",
  "POMA_GOOGLE_DESKTOP_CLIENT_SECRET": "",
  "POMA_GOOGLE_OAUTH_AUDIENCE": "external_testing"
}
```

- Copy your downloaded `installed.client_id` into `POMA_GOOGLE_CLIENT_ID`.
- If the download supplies `installed.client_secret`, copy it into the desktop
  compatibility field for the future adapter. Otherwise leave it empty; Session
  5 must verify the selected library/Google token-exchange requirements. No
  secret is an authentication guarantee for an installed app.
- Audience metadata accepts `external_testing`, `internal`, or
  `external_production`. It documents the owner-confirmed console choice and
  informs explanations; changing the string cannot change Google's settings or
  grant verification. Use only `external_testing` for the recommended pilot.
- Never pass Google's original `installed` JSON directly to Flutter's define
  flag. It is a different schema. Never put a user token into either file.

Development example, from the project
root using the existing Flutter helper:

```powershell
& 'D:/pomodoro/.tools/rtk/rtk.exe' proxy powershell -NoProfile -File 'D:/pomodoro/scripts/flutter.ps1' run -d windows "--dart-define-from-file=$env:LOCALAPPDATA/Poma/Setup/GoogleCalendar/PrivateTest/poma-calendar-defines.json"
```

For a future private Windows package, the release builder now accepts
`-CalendarDefinesPath <absolute owner-local curated JSON path>` and forwards
`--dart-define-from-file` to **Flutter's release compilation**, before packaging.
It validates the curated keys/values without printing them and rejects
`-SkipBuild` together with configuration, preventing reuse of a differently
configured executable. No configured private package is claimed by Session 5.
The resulting executable carries the curated application settings and runs
without that file, Flutter, Codex or developer environment variables. It must
contain no user tokens or original downloaded JSON. Keep the existing package
identity/publisher/signing material and choose a version above 1.0.0.2011.

Missing client ID, a placeholder/malformed ID, an unsupported audience value or
adapter-required missing compatibility material must produce an explicit
configuration state. Suggested UI: **“Google Calendar is not configured in this
build. Timers, tasks and history still work offline.”** Disable Connect and make
no authorization/listener/API attempt. A valid configuration with no user grant
is **Disconnected**, not Connected. Do not fall back to some other app's client.
Changing compiled settings requires a rebuild; changing client/account identity
must not reuse incompatible credentials.

Session 5 tests cover absent/invalid settings and mocked configured settings.
Later packaging must verify an installed launch without the setup directory or
development tooling. Installed configured-launch and live authorization checks
remain unrun; see the latest progress handoff for independent test evidence.
See Dart's
[compilation environment guidance](https://dart.dev/libraries/core/environment-declarations).

## 9. Desktop browser return: loopback, not a hosted callback

The Connect action opens the **external default browser** for Google's
authorization-code flow, with PKCE S256 and a fresh unpredictable state. Poma
temporarily listens on `127.0.0.1` at an OS-assigned free port, for example
`http://127.0.0.1:<port>/oauth2/callback`. Use the identical redirect URI in the
authorization and code-exchange requests; bind only loopback, never all network
interfaces. Validate callback path/state, handle denial/cancellation/timeout and
close the listener when the attempt ends. Do not log callback URLs.

Only the local return uses HTTP; Google authorization/API/token connections use
HTTPS. The owner completes consent and MFA in their browser and returns to Poma.
There is no public callback server, manual code pasting or embedded webview.
No listener is opened during setup or unconfigured startup. This is the
[planned desktop flow](https://developers.google.com/identity/protocols/oauth2/native-app).
Google's loopback deprecation for mobile client types
[does not remove Desktop client support](https://developers.google.com/identity/protocols/oauth2/resources/loopback-migration).
Never disable a firewall or other security control to force a callback through;
record a policy/listener failure for diagnosis.

## 10. Testing expiry and account restrictions

For **External + Testing**, Google documents refresh-token expiry after **seven
days** for these Calendar scopes. The exception for identity-only scopes does
not apply. Google also describes test-user authorizations expiring seven days
from consent. Regular refresh does not make this a rolling seven-day extension.
Access tokens have a separate short lifetime; use Google's returned expiry,
not seven days, for access-token refresh. Sources:
[OAuth overview: refresh-token expiration](https://developers.google.com/identity/protocols/oauth2/#expiration)
and [Testing audience limits](https://support.google.com/cloud/answer/15549945).

Poma explains this setup limitation before connecting. When refresh
fails, stop authenticated retries, preserve offline timer use, label any later
calendar cache stale and offer an explicit Reconnect. Explain that Testing
expiry may be the reason; do not claim every `invalid_grant` proves expiry or
repeatedly launch consent. Revocation, account policy and token limits can also
invalidate access. Offer a single user-initiated recovery with the reason visible.
Moving to production later does not repair a previously expired token or promise
permanent access; check the new authorization after that separate owner decision.

| Restriction or symptom | Owner action |
| --- | --- |
| Cloud access denied | Ask the project/organization administrator for the specific project/API/OAuth management permission; no Poma sign-in can fix Cloud IAM. |
| External Testing login denied | Check the account selected in the browser matches a saved test user and that the API/scopes belong to the same project/client. |
| `org_internal` | Use an eligible organization account or reconsider the audience with its owner; Internal does not support arbitrary outside testers. |
| Workspace policy / `admin_policy_enforced` / app blocked | Ask the Workspace administrator to review this Desktop client ID and the exact two scopes. Cloud project ownership is not Workspace approval. |
| Calendar unavailable, supervised account or Advanced Protection restriction | Check whether the account/service permits this integration. Being a test user does not bypass account protections. |
| Browser return fails | Check Desktop client type, exact redirect matching and loopback availability. Record a safe error category; do not paste codes/URLs or switch to a Web client. |

Google's [native-flow error guidance](https://developers.google.com/identity/protocols/oauth2/native-app#errors)
and audience guide cover provider-side restrictions. These account conditions
were not checked for the owner here.

## 11. Private testing versus a public release

The private pilot stays in Testing with named testers and explained expiry.
Google provides personal-use and development/testing verification exceptions;
they are not a verified-public-app claim. Read-only calendar access can still be
sensitive. See
[sensitive-scope verification and exceptions](https://developers.google.com/identity/protocols/oauth2/production-readiness/sensitive-scope-verification).

Public distribution is a separate owner decision. Prepare accurate public
homepage/privacy/support material, verified owner-controlled domains, any
required brand review, scope justification and a real feature/consent demo for
Google's Verification Center. Public homepage and privacy material must meet
Google's hosting/content requirements; adding GitHub's domain to the console
does not establish ownership of that domain. Review Google's
[brand-verification requirements](https://developers.google.com/identity/protocols/oauth2/production-readiness/brand-verification).
Changing **Publish app** is not the same as scope approval or publishing a
Windows package. No public verification, site publication or distribution is
part of Session 4. Existing mobile/offline privacy claims must not be reused
unchanged for a calendar-enabled Windows release.

## 12. Owner readiness checklist and current handoff

| Item | Status after this documentation session |
| --- | --- |
| Official guidance checked; setup plan and configuration contract written | Complete as documentation. |
| Google account/project selection and management permissions | Owner action pending; not verified. |
| Calendar API enabled in that project | Owner action pending; not verified. |
| Support/contact email and accurate Calendar privacy material | Owner inputs pending; no email/domain/Calendar policy URL confirmed. |
| Branding, audience and exact two scopes saved | Owner action pending; not verified. |
| Test account added, or Internal eligibility/admin approval confirmed | Owner action pending; not verified. |
| Desktop client created and original JSON stored outside source | Owner action pending; no client ID/download supplied. |
| Curated development/package configuration reader | Implemented in Session 5; owner configuration remains unverified. |
| Browser sign-in, actual scope grants, refresh, restart, disconnect | **Unrun**; Session 5 live prerequisite and evidence. |

After following steps 1–7, report only the project ID if needed, chosen audience,
confirmation that the two scopes/API/tester/client are ready, and the local file
path. Keep addresses/test-user details in your private console record when they
are not needed for support; never paste the download or user credentials.

Sessions 5–6 now implement authorization, protected credential lifecycle, explicit
selection and bounded read-only snapshots with independent synthetic tests.
Live sign-in and event comparison require the owner, a configured Desktop client,
accurate disclosures and harmless prepared events; those checks remain unrun.
Session 7 now connects the regular native agenda and explicit validated meeting
actions to the read model. Live setup/sign-in/event comparison remain owner
prerequisites. Session 8 adds optional resident reminders and focus-overlap
confirmation without changing Google permissions or requiring additional setup.
The next application stage is Session 9 only when requested;
preserve all earlier Windows acceptance gaps recorded in the handoff.

**Connecting Google Calendar inside Codex does not configure Poma.** The connector
uses its own OAuth client and credentials. Do not export or reuse them. Poma's
eventual Windows build must authorize independently and work without this chat
or its connector.
