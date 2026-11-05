# Poma Windows Calendar: explicit focus-block writes

Status: **Session 12 code implemented; private-pilot verification is recorded in
[the Session 12 ledger](WINDOWS_CALENDAR_SESSION12.md). Live consent/resource gates
remain pending until observed. Session 11 design history is retained below.**
Owner decisions recorded: **1 November 2026, Asia/Calcutta**.

This is the contract for optional Session 12. The existing
[read-only specification](WINDOWS_CALENDAR_SPEC.md), [Google setup](GOOGLE_CALENDAR_SETUP.md)
and [progress/handoff](WINDOWS_CALENDAR_PROGRESS.md) remain applicable. The latest
recorded complete private pilot is **1.0.0.2020**. Its installed/live-Google
acceptance remains pending as recorded in progress section 16; browser consent
alone has not established a saved, verified Poma connection. Earlier automated
results belong to their recorded source/build, not to this proposed feature.

Session 11 changes documentation only. It does not change application code,
compiled scopes, dependencies, Google configuration, credentials, Windows
settings or pilot artifacts. It does not request permission or perform live
calendar operations. The Windows offline timer, tasks, history, selected-calendar
reader, cache, reminders and existing package identity must remain usable.

## 1. Owner decisions and release boundary

The owner explicitly chose the following during planning and approved this plan
for documentation:

| Choice | Agreed behavior |
| --- | --- |
| Calendar | A dedicated secondary calendar created by Poma, initially named **Poma Focus**; no primary or existing planning calendar destination. |
| Availability | **Busy by default**, with Free selectable in every preview. |
| Management | Explicit title edits, rescheduling, Busy/Free changes and deletion of verified Poma-owned one-off blocks. |
| Offline | Save a local draft, then require a fresh online preview and confirmation. |
| Recovery | Offer explicit, reviewed recovery of existing Poma blocks after disconnect or local reset. |

Supported remote mutations are initial Poma Focus calendar creation and explicit
creation, limited editing and deletion of eligible blocks on that bound calendar.
An explicit Delete action is the supported reversal of creation; there is no
automatic compensating delete after a timeout, disconnect or failure.

Out of scope: editing invitations, responses or attendees; attendee notifications;
recurring-series or occurrence edits; calendar moves, sharing or calendar deletion;
automatic completion uploads; Google Tasks integration; full two-way task
synchronization; automatic session-history uploads; silent focus-session logging;
Workspace focus-time/status automation; multi-device command synchronization;
OAuth client/project migration; public publication.

Poma-owned describes checked provenance and supported app behavior. The user
remains the data owner of a calendar created under their authorization; this is
not a service-account calendar. See [calendars.insert](https://developers.google.com/workspace/calendar/api/v3/reference/calendars/insert).

## 2. Explicit scheduling and management flow

### Entry and preparation

Offer **Schedule focus block** in a task's actions and the selected task's Focus
view on Windows. Scheduling never starts, stops or completes a timer. Require a
verified Poma read-only account before enabling the optional write setup; an
unconfigured/disconnected build can explain the existing connection prerequisite.
Declining connection or write setup returns to the usable offline application.

Copy the selected task title into an editable event title. Keep the task ID and
association local. The uploaded title is a snapshot: later task renaming,
completion or deletion never updates or deletes an event. Do not upload task
notes, task IDs, focus receipts, completion counts or history.

Default to today's next strictly future five-minute boundary and the configured
focus duration, normally 25 minutes. Derive the default end by elapsed duration,
not by assuming every local date is 24 hours. Allow explicit start/end changes.
The first release uses the current device timezone, with no arbitrary timezone
picker. This is a design default, not a newly requested owner choice.

### Review and confirmation

Use a full application dialog that can show all details, rather than submitting
from a compact tray gesture. An illustrative fictional final preview is:

~~~text
Schedule focus block
Task:       Outline proposal (local association)
Title:      Outline proposal (this text will be sent to Google)
Account:    Connected Google account
Calendar:   Poma Focus
Starts:     1 November 2026, 10:00
Ends:       1 November 2026, 10:25
Timezone:   Device timezone name; UTC+05:30 at both endpoints
Duration:   25 minutes
Show as:    Busy [Free available]

[Back] [Save draft] [Schedule focus block]
~~~

The account label and actual calendar display name must come from the verified
binding, never a form-supplied destination. Always show both endpoint dates;
display each endpoint's offset if they differ. Show the exact complete title
before submission, including Unicode; do not submit text the preview truncated.
Hide details while Windows is locked or lock state is unknown, following the
existing privacy policy. Unlock requires a current preview before sending.

The final action must revalidate: nonblank title, valid device-local date/time
resolution, positive duration, start strictly after the current instant, unchanged
timezone interpretation, valid account/calendar binding and ready write
capability. Reject nonexistent and ambiguous local times around DST; ask for an
unambiguous time instead of silently normalizing or choosing an offset. A device
timezone change invalidates the preview. Persist exact UTC instants and endpoint
offsets when confirmed; never reinterpret them on retry.

Show known overlaps with selected calendars as an advisory warning that the
user must acknowledge in the preview. An incomplete/stale snapshot is labeled
availability unknown; it cannot establish that the user is free. This is not a
global conflict check and requires no new availability scope. Deselecting Poma
Focus in the agenda does not disable scheduling or silently reselect it.

Keep these actions separate:

1. **Enable focus scheduling** explains the extra access and starts consent.
2. **Create Poma Focus calendar** explicitly approves calendar provisioning, or
   a reviewed recovery selects an already verified Poma-created calendar.
3. **Schedule focus block** confirms the final event payload after setup.

Successful consent or calendar setup returns to review. Neither sends an event.
Display Pending, Sending, Checking outcome, Saved, Failed, Expired or Needs
review as appropriate; a toast alone is not the operation record.

### Event behavior and management

Create an ordinary timed `eventType=default` event. Busy sends
`transparency=opaque`; Free sends `transparency=transparent`. Busy marks time
busy on Poma Focus. Whether an appointment service or another person sees that
as unavailable depends on the calendars and sharing they consult. It does not
auto-decline invitations, set Google Chat status or imply Workspace focus-time
features. Google documents status events as limited to eligible accounts and
primary calendars: [event fields](https://developers.google.com/workspace/calendar/api/v3/reference/events/insert)
and [status-event guidance](https://developers.google.com/workspace/calendar/api/guides/calendar-status).

New blocks have private event visibility, no attendees, recurrence, conferencing,
attachments or event reminders. Set `reminders.useDefault=false` and an empty
override list; do not activate Poma's separate resident reminders. Use
`sendUpdates=none`, without promising that this parameter prevents every possible
Google-generated email. A zero-attendee supported shape is the guard against
invitation operations.

Manage a block through its operation result or the Poma Focus block list.
Fetch a fresh remote snapshot for the edit/delete preview. Edits show before and
after title, start/end, timezone and Busy/Free; deletion shows the exact block
and a separate **Delete focus block** confirmation. Preserve unrelated remote
fields. If the remote shape now contains attendees, recurrence, a different event
type or lost provenance, disable all mutations, including deletion, and offer
explicit Open in Google Calendar. Do not remove unsupported fields to make a
block manageable.

## 3. Permission evaluation: Google boundary and Poma boundary

The future write authorization requests exactly these approved URLs:

| Scope | Purpose |
| --- | --- |
| `https://www.googleapis.com/auth/calendar.calendarlist.readonly` | Existing account identity, calendar selection and calendar-list recovery. |
| `https://www.googleapis.com/auth/calendar.events.readonly` | Existing selected-calendar event reading. |
| `https://www.googleapis.com/auth/calendar.app.created` | Create app-created secondary calendars and manage events on those calendars. |

The current pilot continues requesting only the first two. Do not add broad
`calendar`, `calendar.events`, `calendar.events.owned`, calendar-list write,
calendar metadata write, ACL, Google Tasks or identity scopes for convenience.

Google's [scope documentation](https://developers.google.com/workspace/calendar/api/auth)
defines `calendar.app.created` at the app-created secondary-calendar boundary.
It is not restricted to a calendar literally named Poma Focus, one selected
calendar, a local installation, a task, or an ownership marker. It can cover
events a user manually adds to an eligible app-created calendar. The existing
read scopes still permit reads outside that boundary; Poma's explicit agenda
selection is an application restriction, not a narrower OAuth grant.

Method authorization lists also accept `calendar.app.created` for
[calendar retrieval](https://developers.google.com/workspace/calendar/api/v3/reference/calendars/get),
[metadata changes](https://developers.google.com/workspace/calendar/api/v3/reference/calendars/update)
and [secondary-calendar deletion](https://developers.google.com/workspace/calendar/api/v3/reference/calendars/delete).
Do not describe this as an event-only permission or promise that Google itself
can restrict it to Poma's marked events. Poma exposes calendar creation and
checked event management only; no calendar delete/clear, metadata editing,
calendar-list mutation, sharing, ACL or general event editor is exposed.

Before **every** event mutation, freshly verify the active credential generation,
bound account/client, stored calendar ID, non-primary status, owner role and
calendar provenance marker. With the exact three-scope grant, `calendars.get`
provides an app-created-eligibility check; the two existing read scopes alone
do not authorize that method. An access role or matching title by itself is
insufficient. Failure stops the write without choosing another destination or
requesting a broader scope.

Treat Google's association of a resource with an app as provider-controlled.
Do not assume a new OAuth client, another project or a reinstalled profile
inherits eligibility merely because the display name matches. Pin the current
client/account identity and verify resource access. Cross-client/project
migration is outside this release.

Suggested pre-consent disclosure:

> Focus scheduling is optional. Google grants access to events on calendars this
> app creates. Poma will use its dedicated Poma Focus calendar and change only
> focus blocks it can verify. You review the title and timing before anything is
> scheduled. Skipping this keeps your existing calendar viewing and offline Poma.

These are documented API boundaries and Poma design requirements. **No live
`calendar.app.created` grant or resource-boundary experiment has been performed
in Session 11.** The disposable-account checks in section 10 are release gates,
not recorded passes.

## 4. Additional desktop consent and safe credential replacement

Google's current [Desktop OAuth guide](https://developers.google.com/identity/protocols/oauth2/native-app)
states that installed apps do not support incremental authorization. Desktop
clients are public clients. Use the system browser and the supported desktop
loopback return with PKCE; do not substitute a web application or embedded login.
Google also documents that [token revocation](https://developers.google.com/identity/protocols/oauth2/native-app#tokenrevoke)
can invalidate the project's grants across its clients, including read access.

The following is Poma's replacement protocol, not a claim that the web
incremental-authorization pattern applies to installed apps:

Before live Session 12 consent, the owner confirms Calendar API readiness for
the existing Desktop client's project, keeps the current audience/test-user
restrictions, and declares only the additional app-created scope alongside the
two read scopes in Google Auth Platform Data Access. Review the displayed scope
categories and updated feature/privacy disclosure without publishing the app or
requesting production verification as a workaround. Console declarations do not
grant access. None of these console steps is performed in Session 11.

1. Leave the canonical read credential, selected calendars, cached data and read
   capability active. Start an independent write-upgrade attempt/generation.
   Do not reuse the current controller's `connect`/failure path unchanged:
   incomplete permissions in that path can retire the existing credential.
2. Explicitly request the complete three-scope set in a fresh Desktop
   authorization-code flow. Reuse hardened IPv4-loopback binding, exact callback
   checks, fresh unpredictable state and PKCE S256. Use offline access and an
   explicit consent/account-selection prompt. Do not depend on
   `include_granted_scopes` or on a request for only the new scope.
3. Stage the result separately from the canonical connection. Check the raw token
   response before the OAuth library can default missing scopes to the requested
   set. Require a usable access token, positive expiry, explicit evidence of all
   three approved scopes and a nonempty replacement refresh token. An unexpected
   extra scope is a failed upgrade requiring review, not silent acceptance.
4. Verify account identity through the existing primary-calendar metadata
   identity check. Pin the same configured Desktop client and same account key;
   `login_hint` is not identity proof. A different account must use a separate,
   explicit account-replacement flow and cannot adopt the old account's drafts.
5. Refresh the candidate once before promotion; verify the returned token,
   identity and scopes. A refresh response omitting `scope` may retain only the
   previously verified scope set of that same candidate token lineage. Explicit
   partial/malformed scopes fail. Never infer a write grant by taking the union
   of requested scopes and the old read-only credential.
6. A missing replacement refresh token fails this upgrade. Do not assume the old
   read-only refresh token acquired new rights. Ordinary refresh of an already
   verified credential may retain its own refresh token when rotation is omitted.
7. Serialize promotion against refresh and credential mutations. Atomically
   replace the DPAPI credential together with a versioned capability receipt
   bound to its identity, generation and verified scopes. Use expected-revision
   checks; reject obsolete refresh/save completions. Preserve selection and
   account data for the same account. Access tokens stay in memory.
8. Publish write readiness only after the committed protected record is verified.
   Atomic-save failure preserves the last valid record. If acknowledgement is
   uncertain, reread protected storage and accept only a fully verified committed
   candidate or the previous valid record; do not blindly roll back or enable
   writes. A crash before promotion restores the original connection.

No replacement is saved on denial, cancellation, missing/partial grants, wrong
account, candidate refresh failure or failed pre-commit storage. Keep the reader
usable and report only that scheduling was not enabled. Do not clear or retire
the read credential through a write-upgrade error. Provider revocation, account
policy or token-limit invalidation can independently break old credentials; use
the existing explicit read reconnect behavior if that actually occurs.

Never revoke an old, rejected or superseded candidate token as upgrade cleanup.
Discard staged secrets locally; Google-side grants may remain. Do not log tokens,
scope-response bodies, callback URLs, codes or downloaded client material.

Model read capability and optional `CalendarWriteCapability` separately.
Write capability has disabled, granting, verifying, setup-required, ready and
blocked states, with a separately visible connectivity condition. Old protected
records load as read-only with writes disabled unless the new receipt and local
enablement are present and validated. A write-only 403 blocks scheduling without
retiring an otherwise usable reader. A true invalid grant may affect both.

**Disable focus scheduling** synchronously closes the mutation gate, stops pending
commands and persists local disablement while retaining reading and Google
authorization. It does not claim to remove only the extra Google scope.
**Disconnect Google** retains the existing full local cleanup/best-effort
revocation contract and explains that Google authorization removal affects reading
as well. Test-mode expiry, administrator policies and public verification remain
the existing setup/release constraints; consent is never repeatedly opened.

## 5. Dedicated calendar provisioning and binding

Use a `FocusCalendarBinding` with schema version, client/account key, returned
calendar ID, a random calendar key, provisioning UUID and verified provenance.
Never accept an arbitrary calendar ID from a UI or task as a write target.

For a new calendar, the user confirms **Create Poma Focus calendar**. Before the
request, durably save a provisioning UUID and calendar key, plus the current
account and credential generation. Put a versioned, nonsecret marker in the
calendar description, for example:

~~~text
Created by Poma for explicitly scheduled focus blocks.
Poma-Focus-v1 calendarKey=<UUID> provisioningId=<UUID>
~~~

Create the secondary calendar with summary Poma Focus. Preserve the timezone
returned by Google; do not add a settings permission to obtain one. Every event
uses its explicitly resolved timed endpoints. Calendar ownership stays with the
authorized user. Save the returned ID/binding before allowing an event request.

Unlike events, the documented calendar-insert contract supplies no client-chosen
idempotent calendar ID. Record sending intent before the request and distinguish
preparation, sending, checking, bound and needs-review states. After an uncertain
send, lost result or failed binding save:

- Query the existing calendar list with `showHidden=true` and all page tokens.
  Use the already approved read scope; `calendar.app.created` alone is not a
  calendar-list permission. Verify candidate metadata and app-created eligibility.
  See [calendarList.list](https://developers.google.com/workspace/calendar/api/v3/reference/calendarList/list).
- Recover a unique exact provisioning-marker match and its returned ID. Never
  identify a calendar solely by Poma Focus, or repeat insert because a list is
  empty, delayed or only partly fetched.
- Keep zero/ambiguous matches, marker loss, access refusal and incomplete pages
  in **Calendar setup needs review**. Retry performs discovery only. Provide an
  explicit Google Calendar link for owner inspection; unresolved provisioning
  does not authorize another calendar-creation request.

A valid stored ID remains canonical even if the user renames the calendar;
show its current name in every subsequent preview. Marker loss blocks writes.
Do not automatically restore names, descriptions or other metadata. If the
calendar is deleted/inaccessible, stop; no replacement or fallback is created.

After disconnect/reset, explicitly discover supported Poma calendar markers and
review a target. If several eligible Poma calendars exist, require a visible
choice and pin the selected ID; never silently create another or delete extras.
Cross-install concurrent provisioning cannot be promised globally exactly once;
this release prevents blind retries from one local setup intent and fails closed
when discovery cannot establish a unique result.

## 6. Operation identity, ownership and internal interfaces

Keep these internal contracts separate from the timer engine:

| Contract | Required responsibility |
| --- | --- |
| `CalendarWriteCapability` | Verified scopes, explicit local enablement and account/credential generation; reader status is independent. |
| `FocusCalendarBinding` | Canonical calendar identity/provenance and fresh eligibility validation. |
| `FocusBlockDraft` / `FocusBlockOperation` | Editable local draft, immutable confirmed payload and stable mutation identity. |
| `FocusBlockWriter` | Checked create, patch, delete and get/reconcile methods; no general calendar editor or arbitrary destination. |
| `FocusBlockOperationStore` | Serialized account-scoped atomic journal, ownership records, revision checks and durable invalidation. |

The Google adapter uses `calendars.insert/get`, read-only calendar-list methods
and `events.insert/get/list/patch/delete` only as described here. Patch the
allowed fields rather than replacing an entire event resource.

Generate UUID v4 identities using a secure random source. Allocate a stable draft
ID when the form opens; repeated confirmation of the same draft resolves to its
one operation. For creation, the block UUID is also its create-operation UUID:

~~~text
eventId = "poma" + blockUuid.toLowerCase().replaceAll("-", "")
~~~

Use the UUID's 32 hexadecimal digits directly, without hex-encoding their text
a second time. This is 36 characters, using only lowercase a-v and digits 0-9,
within Google's 5-1024-character ID format. Each later edit/delete has a new
operation UUID and keeps the original event ID. Retries retain operation ID, event ID and immutable
payload. IDs are not derived from task titles or times: separately confirmed
blocks may legitimately share those values. Google documents client IDs for
duplicate recovery, but distributed collision detection is not an absolute
exactly-once guarantee. See [events.insert](https://developers.google.com/workspace/calendar/api/v3/reference/events/insert).

Use `extendedProperties.private` with these string keys:

| Key | Meaning |
| --- | --- |
| `pomaOwner` | Fixed `poma.windows` application identifier. |
| `pomaSchema` | Ownership format `1`. |
| `pomaCalendarKey` | The bound calendar's random key. |
| `pomaBlockId` | Stable block UUID. |
| `pomaCreateOp` | Immutable creation operation UUID. |
| `pomaLastOp` | Most recently applied create/edit operation UUID. |
| `pomaPayloadHash` | SHA-256 of the confirmed allowed event fields. |

Define canonical payload-hash input as the UTF-8 JSON encoding of the fixed-order
array `[summary,startUtc,endUtc,transparency]`, using UTC RFC3339 timestamps at
whole-second precision (`YYYY-MM-DDTHH:mm:ssZ`). Use compact JSON, the exact
submitted title without Unicode normalization, and only required JSON string
escaping. It excludes the hash itself, local task association,
ETag, reminders and unrelated remote fields. Persist the actual submitted
endpoints/offsets alongside it; never reserialize a changed payload under an old
operation. A delete uses the prior snapshot/hash as its target, without writing
new event properties.

Private properties belong to a calendar/event copy; they are not encrypted,
immutable or security proof. Recovery must recompute the ID from the block UUID,
match create/block identity and calendar key, verify the actual calendar binding,
validate the complete event shape and obtain user review. A copied marker on a
different ID/calendar does not pass. Preserve other private properties when
patching. See [extended properties](https://developers.google.com/workspace/calendar/api/guides/extended-properties).

Local operation records contain version, account/client/calendar identity,
generation, block/operation IDs, kind, confirmed payload/hash, confirmation
instant, expected ETag for edit/delete, state, attempt/reconciliation metadata
and a safe error category. Retain the optional local task association separately
from uploaded properties. No credential or raw provider response belongs here.

## 7. Durable send, reconciliation, retries and conflicts

Persist the confirmed immutable operation before any mutation. A failed local
save produces a storage failure and **zero remote mutation requests**. Serialize
per-block commands: an unresolved create/edit/delete prevents another mutation
of that block. Reject duplicate submissions through both the controller and the
durable journal; disabling a button is insufficient.

The durable state progression is:

~~~text
draft -> confirmed/pending -> sending -> saved
                               |
                               +-> checking -> saved / needs review / failed
draft or unsent pending -> expired / cancelled
~~~

Saving `sending` precedes the request. A restart finding sending/checking treats
it as uncertain even if the process died just before transmission. Read-only
reconciliation may run after account/binding validation; no startup, timer tick,
refresh, notification action or connectivity callback automatically sends a
mutation.

| Result | Required recovery |
| --- | --- |
| Create succeeds | Verify returned ID, markers and allowed fields; atomically save acknowledgement and ETag before showing Saved. |
| Timeout, network loss, 5xx or lost local acknowledgement | GET the same event ID. Never insert with a newly generated ID. |
| Matching operation and payload found | Record Saved without another mutation. |
| Correct block found but fields changed remotely | Report present/changed and Needs review; do not restore the old payload. |
| `409` duplicate ID | GET and verify; a foreign/mismatched record is a conflict, never an update target or reason for a new ID. |
| Event absent after uncertain create | Keep outcome uncertain until the calendar is independently accessible; offer a fresh future-time preview and explicit same-ID Retry only. |
| Event tombstone/deleted | Do not resurrect or replace it automatically. Revised scheduling is a distinct explicit intent after resolving the old result. |
| Edit/delete precondition `412` | Reread; show the remote difference; require a new confirmed operation with its current ETag. No silent merge or unconditional retry. |
| Edit timeout | Match `pomaLastOp` and current fields on GET; changed/missing markers or a different version require review. |
| Delete succeeds or acknowledgement is lost | Record absence only after verified calendar access and a matching known target; do not recreate it. |
| `404`/`410` on delete/reconcile | Distinguish a missing/deleted event from inaccessible calendar/account; missing permission is not proof of deletion. |
| `401` | Allow one serialized token refresh; reconcile any uncertain send before a user retries. |
| Permission `403` | Block writes and explain recovery; no broader scope request and no repeated consent. |
| Rate-limit `403`/`429` or transient read failure | Back off GET/discovery using retry guidance; show retry availability. |

Use the preview's ETag as `If-Match` for both edits and deletes. Verify supported
ownership before transmission as well as account/calendar eligibility. If a
fresh preflight sees a changed ETag, return to review before any request.
ETags, not titles or local timestamps, protect against concurrent remote edits.
See [conditional modification](https://developers.google.com/workspace/calendar/api/guides/version-resources)
and [API errors](https://developers.google.com/workspace/calendar/api/guides/errors).

Use cancellable exponential backoff for recovery reads, initially one second,
doubling to a 60-second cap with jitter; honor a longer Retry-After and coalesce
requests. Mutating retries require an explicit Retry/reconfirmation action,
retain the original identity/payload, and recheck the future start and binding.
Do not change payload to repair validation under an existing operation. An
edited proposal becomes a new operation only after the old outcome is resolved.

Never label an uncertain result as definitely failed, deleted or cancelled.
Reconciliation of an expired but possibly sent operation is still useful; expiry
forbids a new delayed insertion, not the GET that establishes what happened.

## 8. Offline behavior, retention and lifecycle

Store account-bound drafts and the write journal separately from the seven-date
agenda cache and the authoritative Pomodoro database. A known verified/retired
account can keep a draft offline; without an account identity, the unsubmitted
form remains in memory until connection establishes its destination.

The journal is unencrypted local calendar data and can contain titles/times.
Use the existing private profile/account storage policy, atomic replacement,
bounded validated document sizes and generation leases. Do not claim DPAPI
credential protection encrypts this journal. Corrupt, oversized or unwritable
records block scheduling; never delete them and resend an inferred command.
Retain unresolved operations and records for active/future blocks; remove
terminal payloads/expired drafts 30 days after the later of their end time or
terminal transition. Keep minimal non-content receipts until the same cleanup
point. Disconnect/reset purges all account write records.

Offline Schedule becomes **Save draft**, visibly labeled **Not scheduled**.
Returning online requires a fresh preview, current time, capability, calendar
and ownership validation, plus a user confirmation. No queued focus block sends
just because internet returns. If a previous send may have succeeded, reconcile
it before offering revised scheduling. Quit/suspend stop outgoing work; resume
does not replay writes. Lock/unknown lock state prevents a new confirmation/send;
an already transmitted request may finish.

For **Disable focus scheduling**, disconnect, account replacement, reset or Quit,
invalidate write generations synchronously before cancellation or awaited work.
Persist a replay-prevention tombstone before cleanup can be reported complete.
Generation checks must protect HTTP results and queued local saves, so a late
response cannot re-enable access, recreate purged records or overwrite a new
account. Failed cleanup remains visible, blocks writes and retries cleanup on
reopen; an old journal must not become executable because its deletion failed.

Full disconnect keeps its existing best-effort Google revocation and local
credential/cache cleanup. Reset also keeps existing local task/history deletion
semantics; disconnect alone preserves those records. Neither action deletes a
remote event or calendar. Do not compensate for an in-flight request with a
remote delete. Explain that a request already sent may still appear in Google
and can be inspected there or recovered explicitly after reconnection.

## 9. Explicit recovery of existing blocks

After a verified same-account connection and write setup, offer **Recover Poma
blocks**. This action performs reads and local adoption only, not remote writes.
Discover/review the calendar as in section 5; consent, reconnection and restart
alone never import commands or silently select a new calendar.

Preview supported marked events from the bound calendar in seven-local-date
pages, initially the upcoming seven dates, with explicit date navigation. Finish
all Google result pages for each displayed range before describing it as
complete. Filter by private ownership properties server-side where supported,
then verify the entire marker set and supported shape locally; search results
are not ownership proof. Do not fetch arbitrary calendars for recovery.

The user selects blocks to recover. Recheck identity, current fields and ETag
before persisting their new local ownership records. Show current Google titles,
times and Busy/Free. A changed payload hash is labeled remotely changed and
requires explicit adoption of the current snapshot; it does not authorize
restoring old content. Unsupported/copy/foreign/ambiguous markers stay read-only.

Recovered blocks have no recreated local task association. Do not interpret
`pomaLastOp` as a command to execute, restore deleted tasks, rebuild focus history
or replay old pending operations. Later changes use ordinary fresh previews,
new operation UUIDs and concurrency checks. This is limited owned-block
management, not two-way task synchronization.

## 10. Required tests before production write code

The following rows are the Session 11 acceptance requirements. Actual Session 12
results and open live gates are recorded in the linked implementation ledger;
this table alone is not evidence of a pass. Session 12 adds meaningful
failing tests against fake transport and durable-store seams, then implements
the handlers. The fake Google store must commit independently of the response
so timeout-after-success cannot be simulated merely as a never-sent request.
Process-restart probes must reopen durable state rather than reuse in-memory
controllers. Assert remote calendar/event counts and contents, mutation/GET
counts, stable IDs, protected records, journal states and visible outcomes.

| ID | Fault/scenario | Required assertion |
| --- | --- | --- |
| W01 | Double click, repeated keyboard confirm, concurrent dialog callbacks, delayed journal save | One operation/event ID; zero mutation before durable save; one eventual remote block. Distinct explicitly confirmed intents remain distinct. |
| W02 | Initial journal/provisioning-save failure | Zero insert/patch/delete requests; visible storage error; reader/timer usable. |
| W03 | Event committed, response lost; response received, local acknowledgement fails | GET finds same ID and markers; one event; restart/retry never generates another ID. |
| W04 | Kill before send, after saving sending, after server commit, before/after acknowledgement | Reopen actual journal; distinguish unknown from saved; no mutation at startup; explicit future Retry retains IDs. |
| W05 | Calendar committed with lost response/binding save; match on later list page or delayed discovery | One calendar insert per setup intent; unique marker recovery; partial/empty/ambiguous discovery stays needs review without another insert. |
| W06 | Same-name user calendar, primary ID/alias, wrong owner/client/account, renamed/deleted target | Reject unsafe destinations before mutation; renamed valid binding is displayed accurately; no fallback/recreation. |
| W07 | `409` for foreign marker, mismatched UUID/hash or copied event | No overwrite, new ID or success acknowledgement; conflict visible. |
| W08 | Remote edit between preview and send; `412`; edit success then timeout and another remote edit | No lost update; compare GET/last-operation markers; fresh reviewed operation required. |
| W09 | External event deletion, minimal tombstone, delete timeout, inaccessible calendar returning `404` | Verify calendar separately; no resurrection; no false deletion success on access loss. |
| W10 | Offline draft, restart, restored connectivity, expired start, suspend/resume/Quit | No automatic mutations; Not scheduled/Expired visible; fresh preview and confirmation required; uncertain prior sends can still be read. |
| W11 | DST gap/fold, different endpoint offsets, midnight crossing, device timezone/clock change, Unicode/blank title | Exact preview/UTC payload; reject invalid/ambiguous times; stale preview cannot submit; no hidden title truncation. |
| W12 | Denial/cancel, partial/missing/extra scopes, library default scopes, missing replacement refresh token, wrong account | No canonical replacement/retirement/revocation; old reader, selections and offline app remain usable; writes disabled. |
| W13 | Candidate refresh fails/rotates/omits token or scopes; storage failure/uncertain acknowledgement; competing read refresh | Same-lineage verification only; atomic valid credential survives restart; stale refresh cannot overwrite upgrade; no tokens logged. |
| W14 | Permission denial, rate limits, backend/network failures | Safe error classes, bounded/cancellable GET backoff; explicit mutation Retry only; no broadened permission request or browser loop. |
| W15 | Disconnect/reset/account switch/disable during save, preflight, send or response; failed cleanup | Durable invalidation stops replay across restart; stale results cannot restore data/access; no compensating remote delete. |
| W16 | Explicit recovery after local reset; pagination failure; copied markers, guests, recurrence, changed type/hash | Adopt selected verified current snapshots only; unsupported blocks read-only; no task/history restoration or command replay. |
| W17 | Old pilot credentials, missing capability receipt, corrupt/oversized journal, expired-record cleanup | Read-only default retained; no inferred writes or silent data recreation; retention and disablement survive restart. |
| W18 | Scope declined, scheduling disabled, no network, hidden timer expiry and ordinary agenda/reminders | Existing read-only requests contain only their intended operations; timer/task/history and shared/mobile behavior remain independent. |

Live tests require owner participation, an eligible disposable **personal Google
account**, verified read-only setup and an actually inspected exact grant. Never
use Codex connector credentials or real invitations. Record these separately:

| ID | Owner-assisted release gate |
| --- | --- |
| L01 | Verify complete desktop consent, actual three-scope grant, protected credential restart/refresh and unchanged read-only use after a separately exercised decline. |
| L02 | On disposable primary/pre-existing secondary resources, establish denied writes outside the app-created boundary; on a disposable app-created calendar, establish allowed supported operations. Inspect scopes first; no broad-grant boundary claims. |
| L03 | Demonstrate that a manually added disposable event on the app-created calendar is within Google's resource boundary, while Poma's guards refuse its management. Any direct boundary probe belongs to the disposable API test harness, not a general editor in Poma. |
| L04 | Confirm creation, edit/reschedule, Busy/Free and deletion in Google Calendar; verify default event type, no guests/recurrence/reminders and one block after retries/restart. |
| L05 | Disconnect/reset with a disposable existing block; verify remote preservation, explicit reviewed recovery and absence of replay/task creation. Verify a separate private installed build and read-only/offline regressions. |

Boundary checks are not permission to mutate the owner's existing calendars.
If readiness or owner input is missing, complete synthetic work and keep live
rows unrun. Do not infer a personal-account pass from a Workspace-only test.

## 11. Session 12 implementation and release handoff

Proceed with Session 12 only when requested. Keep Session 10's read-only
installation/API/sign-in and desktop acceptance gates open until actually
observed. Optional writing does not resolve them. Existing architecture,
privacy, retention, setup, bundled Windows notice and private release documents
must describe implemented behavior before a write-enabled private build is
offered; no such disclosure/build change is made by Session 11.

~~~text
Implement optional Windows Calendar Session 12 in D:\pomodoro only within
docs/WINDOWS_CALENDAR_WRITES_SPEC.md and the latest progress handoff.
Read RTK.md and preserve all existing tracked/untracked work, the current
read-only pilot, package/client identity, offline timer and sole data owner.

First add W01-W18 fault-injection coverage, including independent fake-server
commits and restart of durable state. Then implement the separate write
capability, staged desktop credential replacement, verified Poma Focus binding,
durable operation identities and explicit create/edit/reschedule/delete flow.
Implement no general event, attendee, recurring or task-sync operations.

Keep read-only connection and selected-calendar use functional when the extra
grant is declined. Consent/setup never schedules a block. Every mutation needs
the current preview, ownership/binding checks, durable save and concurrency
protection; uncertain results reconcile before any explicit same-ID retry.
Offline/restart/expiry/disconnect must not silently send or replay operations.
Offer reviewed recovery of eligible blocks without recovering commands/tasks.

Complete affected automated, native-storage and shared/mobile regression checks.
Perform L01-L05 only with owner participation, disposable personal-account data
and verified exact grants. The owner handles browser authentication/MFA/consent.
Record actual outcomes in Google Calendar and keep unobserved gates unrun.

Update implemented privacy/scope/setup/retention/release documentation and bundle
notices. Produce a separate, higher-version private Windows build with the same
package identity; preserve the 2020 pilot and its artifact hashes. Record new
source/build hashes and owner-installed evidence. Do not publish automatically,
change broad Google access, or mark historical acceptance gaps passed.
~~~

Session 11 verification is limited to documentation coverage, local links,
whitespace and preservation of pre-existing source/pilot inputs. No application
campaign is rerun for this documentation-only change, and W01-W18/L01-L05 remain
future tests rather than claimed results.
