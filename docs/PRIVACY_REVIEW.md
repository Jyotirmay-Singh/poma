# Privacy, local data and dependency review

## Owner-ID candidate — 22 October 2026

Build 2007 adds offline privacy/support pages, native dependency notices and
owner signing/branding without changing storage, scheduling, dependencies or
network behavior. PRIVACY_POLICY.md and STORE_MATERIALS.md contain the reviewable
policy and store-answer drafts. RELEASE_CANDIDATE.md binds new artifact evidence
separately from build 2006. The native notice collector inspected cached JAR/AAR
license/NOTICE entries for the 52 declared coordinates and preserved their Apache
terms; four metadata/variant coordinates have no separate cached runtime archive.
Flutter's complete generated engine/Dart notices remain separate and included.
This is bounded notice preparation, not universal legal clearance.

The later Session 8 evidence below supersedes older tables: iOS unsigned release
compilation did succeed, ten Swift simulator tests passed, Android coarse UID
traffic/selective backup and named phone recovery checks were observed. Those
results do not certify a signed iOS IPA, universal backups, exhaustive traffic,
or the new candidate. Older unreconciled rows remain historical scope only.

## Session 8 update — 22 October 2026

The current ARM64 validation package is SHA-256
`6edb098ce0389a6f5c970189e4708a18f703d3678e9dfada78e7d143984baa88`.
Fresh SDK decoding retains `allowBackup=false`, legacy exclusions and cloud/
device-transfer exclusions for all nine domains at `.`; database-domain rules
include SQLite sidecars by scope. The manifest has notification, exact-alarm,
boot, vibration and protected dynamic-receiver permissions, with no INTERNET,
network-state, wake-lock or foreground-service permission. These are packaged
facts, not actual transfer/backup-content observations.

The refreshed bounded pattern review covers 31 production Dart/Kotlin/Swift
files with zero network-API/URL, logging-call or secret-marker hits. Packaged
notices are present. The worker repair adds no dependency, profile collection,
backend, polling timer or wake lock. Dependency declarations are unchanged;
network-capable transitive packages and final notice compliance remain review
boundaries below, rather than being called harmless from count alone. The
current offline release graph has 52 selected Maven coordinates. The 23 missing
cached POMs were fetched from official Google Maven/Maven Central, with hashes;
22 declare Apache 2.0 directly and listenablefuture inherits its declaration
from guava-parent 26.0-android. This closes missing-POM declaration evidence,
not a complete post-R8/native-engine inventory or legal/notice clearance. Current iOS unsigned-package review retains four privacy manifests and
no root ATS override or UIBackgroundModes. Ten Swift tests passed in current
CI, including simulator backup-policy tests; physical iPhone attributes,
UserDefaults backup metadata and real backup/transfer behavior remain gated.

Current attached observations show generic focus/break alerts and exactly-once
focus recovery; strict full reset and durable defaults passed after repair.
No encryption, forensic deletion, erasure of older backups, universal backup
prevention or comprehensive traffic-capture claim follows. Fresh raw records
are under ignored `artifacts/session-8/worker-review/` and `final/`.

Review date: 21 October 2026. This continues the Session 5 implementation; it does not replace its UI, durability or notification evidence.

## Evidence boundary and release status

The reviewed source implements an offline Android/iOS app with no account, backend, app-managed synchronization, analytics, remote configuration or personal-profile form. Tasks, settings, timer state and focus history are stored locally. This is a source finding. A fresh release package inspection and observations on named phones establish different facts and must be recorded separately.

| Evidence | What this review establishes | Remaining limit |
| --- | --- | --- |
| App-owned source/configuration | Permissions, storage preparation, data deletion and notification payload design; bounded network/log/secret-pattern review | Does not establish actual OS delivery, network traffic, backup behavior or every dependency's behavior |
| Installed package metadata/licenses | Exact declared production dependency closure and local primary-license texts | Includes platform-specific packages; not a list of all code shipped after tree shaking/R8 |
| Previous release output | Historical baseline only | Its manifest lacks the current notification receivers/permissions and its license asset lacks current notifications/intl entries; do not use it for this release |
| Fresh Android release packages | Package-verified; [exact hashes and REA IDs](RELEASE_EVIDENCE.md) | Does not establish every device/OS behavior |
| iOS simulator/native tests | CI-verified: simulator compilation and ten Swift tests passed | Simulator results are not physical iPhone behavior |
| iOS device release / signed IPA | Initial unsigned release compilation failed; diagnostic rerun pending | No valid release archive, signed IPA, installed package or merged release privacy-manifest result yet |
| Physical phones, backup/transfer and traffic | Unverified | Parent inventory reports a connected G54 on Android 15; no installed-app backup/transfer, disconnected acceptance or attributable traffic outcome has been supplied to this review |

No result below claims database encryption, universally disabled OS backups, erasure of older backups, forensic erasure, or measured battery/latency improvements.

## Data and permissions

| Local information | Purpose and location | Deletion/retention |
| --- | --- | --- |
| Task IDs, titles, completion and ordering | Private SQLite `tasks` | Until task deletion or confirmed full reset |
| Timer preferences, appearance, selected task and saved running/paused phase | SQLite state | Until changed or confirmed full reset |
| Completed focus sessions and original task-title snapshots | SQLite `sessions`, indexed history | Retained until individual deletion, clear-history or full reset; task rename/deletion does not rewrite snapshots |
| Desired alert and action receipts | SQLite notification tables | Reconciled with the current/previous phase; full reset clears old records |
| Native scheduling/response metadata | Android private SharedPreferences; iOS standard UserDefaults | Opaque run IDs, generations, notification/action identifiers and database location; full reset clears pending/delivered alerts and response/scheduling journals |
| System notification permission, channel settings and delivered notifications | OS-managed | Controlled partly by the OS; an app data reset does not revoke notification permission |

There is no user-profile, contact, location, advertising-ID or account field in the reviewed application flow. Task titles and history can still contain sensitive information chosen by the person. The database is not encrypted by Poma. Ordinary OS sandboxing and any device-level protection are distinct from application encryption; their exact device configuration was not observed.

Android source declares `POST_NOTIFICATIONS`, `SCHEDULE_EXACT_ALARM` and `RECEIVE_BOOT_COMPLETED`. The alarm, dismiss and restore receivers are private. `SCHEDULE_EXACT_ALARM` supports the user-selected precise alert path, with an inexact fallback; store eligibility/approval is not established here. `RECEIVE_BOOT_COMPLETED` supports event-driven restoration. No main-source `INTERNET`, app wake-lock, foreground-service, restricted `USE_EXACT_ALARM`, contacts, location or DND-bypass permission is declared. Android's merged signature-protected dynamic-receiver permission, when supplied by AndroidX, is different from an extra user data permission. Inspect the fresh release manifest rather than assuming dependency manifests add nothing.

The current ARM64 release manifest was decoded with Android build tools 36.0.0
and bound to SHA-256
`c162a616d26800f3b165670191e1d3f19f4adb610fc1b42cb88d1f1494a13632`.
It retains the three app permissions, the notification library's normal
`VIBRATE` permission and the signature-protected dynamic-receiver permission.
Vibration is an OS notification-channel capability; the app adds no vibration
loop or custom vibration request. Existing channel preferences are preserved.
No `INTERNET`, `ACCESS_NETWORK_STATE`, wake-lock or foreground-service permission
appears. The package is not debuggable. Resource decoding resolves the obfuscated
backup XML paths and confirms all nine domains at `.` in legacy/cloud/transfer
sections. This establishes packaged rules, not universal backup prevention.

iOS source adds no remote-push entitlement or continuous background-execution mode. Its app privacy manifest declares no tracking/collected-data categories and required API reasons `35F9.1` for boot-time interval measurement and `CA92.1` for app-private UserDefaults. The installed notification plugin also declares `CA92.1` with no tracking or collected-data categories; sqflite_darwin's local privacy manifest declares no accessed API or collected-data categories. These are reviewed declarations, not a signed-IPA or App Store approval result. Preserve all merged framework/plugin manifests when the IPA is available.

Notification permission is explained at the first Start rather than launch. Denial leaves timer controls usable; settings expose alert enablement, OS settings and retry. Permission denial/revocation and exact-access revocation still require phone observation.

## Storage, backup and transfer policy

Android's main manifest sets `allowBackup=false` and references both `backup_rules.xml` and `data_extraction_rules.xml`. Legacy backup rules and both modern cloud-backup/device-transfer sections exclude `root`, `file`, `database`, `sharedpref`, `external` and device-protected root/file/database/sharedpref domains at `.`. Database-domain exclusion covers `poma.db` and companion WAL/SHM/journal files rather than excluding only the main filename. This is configuration evidence. Actual Android version, transport and OEM transfer behavior remain unverified; the manifest flag alone is insufficient to claim every transfer path is prevented.

On iOS, `LocalRepository._openOnce` awaits privacy preparation on the database's parent directory before `openDatabase`. `LocalBackupPolicy.exclude` resolves/canonicalizes the directory, rejects paths outside the app container and the container root, creates the directory if required, sets `isExcludedFromBackup=true` and reads the attribute back. A missing bridge or failed preparation produces a retryable startup error, preserving existing data. Excluding the directory is intended to include `poma.db`, `poma.db-wal`, `poma.db-shm`, `poma.db-journal` and subsequently created sidecars.

Three Swift backup-policy tests cover existing database/sidecar preservation, creating an excluded directory before the database exists and rejecting an outside-container path. They passed within the ten-test macOS simulator run recorded in [release evidence](RELEASE_EVIDENCE.md). These tests establish the simulator attribute policy, not the contents of every iCloud/Finder backup or Quick Start/device-transfer path. Physical directory attributes and backup/transfer observations remain gated.

The SQLite-directory attribute does not cover standard iOS UserDefaults. `poma.alert.database` stores a local database path and `poma.alert.responses` stores opaque run/generation/action metadata. No task title or full focus history is written there by the reviewed code. This metadata remains in the backup inventory; do not describe every app-private byte as excluded. Android's broad shared-preference exclusions also cover its native alert metadata. Full reset may retain non-content configuration such as the native database location.

The product requests backup exclusions. Device/OS behavior must be checked and qualified in user-facing claims. The English privacy explanation now says that Poma requests exclusion, that system backup/phone-transfer behavior can vary and that older backups may retain data. The resources were regenerated with the existing Flutter SDK; no package was added or upgraded. There is no app export/import or automatic lost-phone/uninstall recovery. These exclusions cannot erase copies an older version may already have placed in an OS backup. Do not promise that older backups or forensic flash remnants have been removed.

Required observations use synthetic tasks/history and record database/sidecar locations, attribute/configuration evidence, OS/transport/OEM and the actual backup/restore or transfer result. Keep iOS backup exclusion, iOS transfer behavior, Android legacy/cloud backup and Android device transfer as separate cases; unsupported or unavailable operations stay unverified.

## Notification privacy, logs and deletion

Android notification content is a generic focus/break-complete title plus “Open Poma when you’re ready.” It uses `VISIBILITY_PRIVATE`, immutable PendingIntents and opaque session identity. iOS uses the same generic wording and only run/generation identity in notification `userInfo`. Neither platform includes a task title in the scheduled content. Sound, previews, Focus/DND and lock-screen policy remain OS-controlled. A generic completion still reveals that Poma was used. Actual lock-screen previews, notification actions and denial/revocation must be observed on each phone.

The application does not add a privacy screen over the OS app-switcher snapshot, nor claim that user-entered content is hidden from device screenshots or OS diagnostics. Do not infer this protection from generic notification wording.

The bounded source scan found no direct `print`, `debugPrint`, `NSLog`, `os_log` or Android Log calls in the reviewed app-owned source. UI errors expose safe failure categories rather than task contents/raw SQL/raw platform exception strings. This does not establish that Flutter, SQLite, plugins, the OS or crash diagnostics never emit information. Inspect attributable device logs with synthetic task content and review packaged debug endpoints independently.

Clear-history and individual-session deletion require confirmation and remove completed history without resetting the active phase or earned rounds. An overdue phase is reconciled before clear-history; a still-active phase may legitimately add a later completion. Task deletion preserves snapshots already attached to an active/completed phase.

Confirmed full reset abandons even a strict active phase, resets local tasks/history/preferences and clears old receipt data. The empty desired schedule and cleanup marker are committed before native pending/delivered notifications and journals are cleared. A retry/reopen completes interrupted cleanup; a new phase cannot start before unfinished cleanup. System notification permission remains an OS setting. Real-device interrupted reset/deletion/reopen behavior is unverified even though host durability cases exist.

Deletion uses transactional SQLite row removal. It is not secure erasure from freed pages, SQLite sidecars, flash storage or older OS backups. No automatic vacuum, retention pruning, data upload or remote deletion service is introduced. An unreadable database is not silently deleted/recreated.

## Dependency and license inventory

The local `package_graph.json` production closure was traversed from only `poma.dependencies`, excluding the development roots `flutter_lints`, `flutter_test`, `integration_test` and `sqflite_common_ffi`. This resolves **39 declared packages**, including SDK/framework and platform-specific transitives. Each package had a readable primary license file; the full local texts, exact graph edges, package roots, byte counts and SHA-256 values are retained in the evidence below. SDK package versions `0.0.0` are graph placeholders; the actual selected SDK is Flutter 3.44.2 / Dart 3.12.2.

This graph classification does not establish native test-harness exclusion. The parent inspected the pinned Flutter tooling: the normal pub/build path regenerates Android's production plugin selection, whereas `--no-pub` can leave stale native-tooling metadata. The pinned iOS/macOS plugin filtering implementation explicitly retains development plugins (Flutter issue 163874). Therefore `integration_test` may still be linked into an iOS release even though it is a development root in the Dart graph. Fresh iOS package inspection must resolve that question; do not promise a test-harness-free IPA or redesign the harness without packaged evidence. The parent release build is using the normal regeneration path for Android.

The updated iOS evidence workflow preserves the SDK-generated `.flutter-plugins-dependencies` after normal release registration refresh. This is registration metadata, not proof of which code is linked into the `.app` or IPA. Until the workflow runs and its packaged output is inspected, iOS development-plugin inclusion remains unresolved.

| Package | Resolved version | Declared role | Primary license reviewed |
| --- | --- | --- | --- |
| args | 2.7.0 | transitive | BSD-3-Clause |
| async | 2.13.1 | transitive | BSD-3-Clause |
| characters | 1.4.1 | transitive | BSD-3-Clause |
| clock | 1.1.2 | transitive | Apache-2.0 |
| collection | 1.19.1 | transitive | BSD-3-Clause |
| dbus | 0.8.0 | transitive | MPL-2.0 |
| ffi | 2.2.0 | transitive | BSD-3-Clause |
| flutter | 0.0.0 | direct | BSD-3-Clause |
| flutter_local_notifications | 22.3.2 | direct | BSD-3-Clause |
| flutter_local_notifications_linux | 8.0.2 | transitive | BSD-3-Clause |
| flutter_local_notifications_platform_interface | 12.2.0 | transitive | BSD-3-Clause |
| flutter_local_notifications_web | 1.0.0 | transitive | BSD-3-Clause |
| flutter_local_notifications_windows | 3.1.1 | transitive | BSD-3-Clause |
| flutter_localizations | 0.0.0 | direct | BSD-3-Clause |
| http | 1.6.0 | transitive | BSD-3-Clause |
| http_parser | 4.1.2 | transitive | BSD-3-Clause |
| intl | 0.20.2 | direct | BSD-3-Clause |
| material_color_utilities | 0.13.0 | transitive | Apache-2.0 |
| meta | 1.18.0 | transitive | BSD-3-Clause |
| path | 1.9.1 | direct | BSD-3-Clause |
| petitparser | 7.0.2 | transitive | MIT |
| platform | 3.2.0 | transitive | BSD-3-Clause |
| plugin_platform_interface | 2.1.8 | transitive | BSD-3-Clause |
| sky_engine | 0.0.0 | transitive | Mixed engine third-party notices; preserve complete text |
| source_span | 1.10.2 | transitive | BSD-3-Clause |
| sqflite | 2.4.4+2 | direct | BSD-2-Clause |
| sqflite_android | 2.4.4+1 | transitive | BSD-2-Clause |
| sqflite_common | 2.5.14 | transitive | BSD-2-Clause |
| sqflite_darwin | 2.4.4+1 | transitive | BSD-2-Clause |
| sqflite_platform_interface | 2.4.2 | transitive | BSD-2-Clause |
| string_scanner | 1.4.1 | transitive | BSD-3-Clause |
| synchronized | 3.5.0 | transitive | MIT |
| term_glyph | 1.2.2 | transitive | BSD-3-Clause |
| timezone | 0.11.2 | transitive | BSD-2-Clause |
| typed_data | 1.4.0 | transitive | BSD-3-Clause |
| vector_math | 2.2.0 | transitive | BSD-3-Clause |
| web | 1.1.1 | transitive | BSD-3-Clause |
| xdg_directories | 1.1.0 | transitive | BSD-3-Clause |
| xml | 7.0.1 | transitive | MIT |

The direct packages support SQLite, path handling, bundled locale formatting and notification initialization/permission/settings. They have current source call sites. No package was removed solely to reduce a dependency count. In particular, the app-owned one-shot schedulers do not remove the need for notification permission/settings integration. Removing or replacing that wrapper requires a measured size/runtime benefit and equivalent behavior tests.

`http` is a **declared production transitive**, through `flutter_local_notifications → timezone → http`; it is not accurate to call every network-related lockfile entry development-only. The inspected notification sources import `timezone/timezone.dart`, not its browser/standalone initialization helpers. Those optional helpers can fetch timezone data, but Poma imports none of them and adds no timezone lookup. Declared dependency, reachable AOT code, bundled bytes and observed traffic are different evidence. Tree shaking/platform selection must be checked in the fresh release before claiming that this code is absent. Also distinguish Linux dbus/MPL-2.0 and Windows/web-only declarations from libraries actually packaged for Android/iOS.

The Dart graph is not the complete native license inventory. The installed Android notification plugin declares AndroidX core/media, Gson 2.12.0 and desugar_jdk_libs 2.1.4; resolution may select newer conflict-resolved AndroidX versions. Both inspected iOS Swift packages depend on the local FlutterFramework and carry privacy resources. Preserve the final Android resolved runtime graph, native Maven licenses/notices, Flutter engine notices and final Swift/framework resources with each release. No macOS resolution or native complete-license approval is claimed here.

The fresh Android `releaseRuntimeClasspath` graph is now retained. Its 52 unique
selected Maven coordinates have 29 locally available POM records declaring
Apache 2.0 variants; 23 have no cached POM in this bounded review. Those missing
records are unresolved coverage, not proof of unlicensed dependencies. The
graph includes resolved AndroidX core 1.13.1, Kotlin stdlib 2.3.20 and Flutter
embedding revision `77e2e94772b6eb43759e34ed1ad7da4674e19cab`.
`android-release-runtime-graph.log` and
`native-maven-license-declarations.json` retain exact declarations and limits.
Complete native/embedded notice clearance remains a distribution gate.

The APK contains `NOTICES.Z` (110,357 bytes), decoding offline to 1,377,731 bytes,
SHA-256 `b886055b4ba708a086ee1b89084b2a21b85e1a151046d79f928299902c7aebae`,
and the separate Pomatez license asset. Notices include the notification,
SQLite, intl and http package names. A license-name occurrence does not establish
reachable AOT code or observed network activity. The full text is retained;
engine notices are not reduced to Flutter's top-level license.

The notification package also contributes a 3,407-byte browser service-worker
asset to the Android archive. Its inspected script handles browser notification
clicks locally and contains no external asset URL. Poma's native mobile startup
does not load that browser script. It is retained library packaging overhead;
its presence neither creates an Android service worker nor establishes network
traffic. No dependency replacement is justified solely by that small payload.

Pomatez's MIT text is already bundled and registered with the About → View licenses flow. Flutter's generated `NOTICES.Z` and the explicit Pomatez asset must be present in the fresh package and readable offline. Preserve original copyright/license texts and required notices for included BSD/MIT/Apache material. Do not reduce the mixed engine inventory to the SDK's top-level BSD license. The declared Linux MPL package requires separate inclusion/source-license assessment if a future target actually ships it. A primary-file classification is not a complete legal clearance for every native or embedded subcomponent.

## Bounded secrets and network review

The final retained source audit scans 42 app-owned Dart/Kotlin/Swift/XML/plist/ARB/privacy-manifest files (41 in the immutable initial snapshot). It found zero matches for the recorded direct-network primitive patterns, zero direct application log-call matches and zero common private-key/AWS/GitHub/OpenAI/Google-key pattern matches. Match output is limited to counts and file/line references, never credential values. A separate tracked filename check found no keystore/JKS/P12/PEM/mobileprovision, `.env`, google-services or secret/credential-named file. Ignore rules cover development tools, caches, signing material and environment files.

This is a bounded review, not a proof that all possible secrets, obfuscated endpoints or third-party diagnostic behavior are absent. Signing keys must stay outside source/packages. Inspect the fresh release for debug service/configuration, remote URLs/assets, analytics identifiers, credentials and unexpected permissions without printing any found secret. URL strings from licenses, XML doctypes or source comments do not establish network activity.

Observed attributable outbound traffic is **unmeasured**. A connected capture must correlate the app process/UID and exercised actions, with capture completeness and device OS traffic limitations recorded. The disconnected standalone matrix then establishes operation without network/development tools. Airplane mode alone cannot prove that the app never attempted outbound traffic; a static absence of `INTERNET` on Android cannot establish iOS behavior.

## Evidence retention and remaining observations

Local raw audit files are ignored development evidence, not assets required by the app:

The local review used Python 3.14.2 and RTK 1.0.1. Later snapshots retain the executing script's hash and tool versions, and the script refuses to overwrite an existing evidence file; use a new `--snapshot name` for another review.

- `artifacts/session-6/privacy_inventory.py`: repeatable local metadata/source review; performs no network query or dependency update.
- `artifacts/session-6/dependency-license-inventory.json`, evidence ID `POMA-DEPENDENCIES-20261021`: complete local package/license inventory, 1,442,134 bytes, SHA-256 `356362838ce24a950585e9810fb73196d914a6e69ef8ceaedd57d471bd45b017` at the initial review snapshot.
- `artifacts/session-6/privacy-source-audit.json`, evidence ID `POMA-PRIVACY-SOURCE-20261021`: source identities and bounded scan patterns/results, 9,356 bytes, SHA-256 `34229daf12a71b5dc2e062fd943a505589b2868b595b6d59b84cf3826008c5a1` at the initial review snapshot.
- `artifacts/session-6/dependency-license-inventory-final.json`, evidence ID `POMA-DEPENDENCIES-20261021-final`: final source graph/license snapshot with tool/script identity, 1,442,587 bytes, SHA-256 `ca06b515fa0c63d855093f6d4be205a3b86136927f91f88549fbbe0c8e611dfb`.
- `artifacts/session-6/privacy-source-audit-final.json`, evidence ID `POMA-PRIVACY-SOURCE-20261021-final`: final source identities after controller/measurement additions and regenerated privacy copy, 9,930 bytes, SHA-256 `29fa0eefa51ba17f3b69802ad14b3580b93b47e298d7b4341b250c56c4b5a729`.
- Reviewed lockfile SHA-256: `64ce0ae60072093a53fb57e305e7f8f944383e54e55852f6d8b0063ffb9d84ef`; graph SHA-256: `614d858aa7ff26d43d96813e445902b260c3c303cd06d83e2fa1485858088d10`. Re-run and retain a new identity if those inputs change.
- Later source audit including the corrected launch marker: `privacy-source-audit-release-validated.json`, 9,928 bytes, SHA-256 `ec8ebc1ae1f5c1509d6ad29832d3b27256ed5b578ca967c61b67cf7d0187ac2a`; 42 files, zero matches for the bounded network/log/secret patterns. Its dependency/license companion is 1,442,585 bytes, SHA-256 `6b93890d93b1029987c81ca81a6591c44b887da032cbb46e2544b85a85b38763`.

| Release observation | Status in this review | Required evidence |
| --- | --- | --- |
| Fresh Android merged permissions, backup resources, native receivers and Dart/license assets | Package-verified | Exact hashes, REA IDs and decoded resources in the release report; full native license clearance remains open |
| Signed iOS entitlements, merged privacy manifests and license resources | Unverified | IPA hash, Xcode/SDK, signing/install identity and focused packaged evidence |
| Android cloud/legacy backup and device transfer | Unverified | Named model, OS/OEM, transport, synthetic DB/sidecars/preferences, restore/transfer result and limitations |
| iOS backup and device transfer | Unverified | Directory/sidecar attributes plus observed supported backup/restore and transfer result; attribute tests alone do not pass this row |
| Lock-screen content, notification denial/revocation and precise-access fallback | Unverified | Named phone/settings/build and observed alert/preview/action result |
| Clear-history/full reset and interruption recovery | Host coverage exists; phone result unverified | Standalone device flow, durable rows/state, native cleanup and repeated reopen outcome |
| Device logs and attributable outbound traffic | Unmeasured | Synthetic-content log inspection, process/UID attribution, capture method/duration/coverage and observed requests |
| Self-contained disconnected launch and all core features | Unverified | Installed release package; computer disconnected and development server stopped; per-case observed/unverified matrix |

Keep failed, observed and unavailable cases explicit in the release handoff. No backend, hosting, authentication, remote push, cloud synchronization or new production dependency is needed to close these checks.
