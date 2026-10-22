# Completed automated test inventory

## Build 2007 additions — separate from the 183 baseline results

At app source `d0a6a4204258ec0ab4d44ff26ea79fd065b71f25`, CI39820922409
passed these three new tests in `mobile/test/release_ui_test.dart`:

| Stable ID | Passed test |
| --- | --- |
| RC-LEGAL-01 | bundled policy explains backup metadata and logical deletion offline |
| RC-ABOUT-01 | About shows release version and public support from Settings |
| RC-A11Y-01 | offline legal text remains scrollable at 200 percent text |

Raw CI log: artifacts/release-2007/ci-android-job.json. Two initial local
test-harness setup issues and the corrected About retry remain documented in
RELEASE_CANDIDATE.md. The 183 results below are reused baseline evidence,
not a newly executed combined suite. Native physical integration is still open.

This indexes **existing passed results**; generating this document did not run tests.
Read [the test ledger](TEST_LEDGER.md) before scheduling any checks. These tests are closed for the recorded source; a new session or documentation edit is not a reason to run them again.

Tested app source: `2613cbcb552095c5a37573729d2086def3ed81a8`. CI: [39729543402](https://github.com/Jyotirmay-Singh/poma/actions/runs/39729543402).
Full working-tree fingerprint before the canonical release build: `6ef5bd65b064aa3b58ff9988af2d34aedbd94f7092a0c48e8e312b63d377a011`.

| Suite | Passed | Failed / skipped | Existing evidence |
| --- | ---: | --- | --- |
| Flutter | 165 | 0 / 0 | `artifacts/session-8/checks/flutter-tests.log` |
| Android JVM | 8 | 0 / 0 | XML copies in `artifacts/session-8/documentation/` |
| Swift simulator | 10 | 0 / 0 | `artifacts/session-8/ci/ios-current/native-tests.log` and summary JSON |

**183 distinct tests.** Earlier 150/157/163-test snapshots and repeated CI executions overlap this coverage; do not add them to the total. Swift ran on an iPhone 17 Pro simulator, iOS 26.4.1, not the physical iPhone 16.

Stable IDs derive from the source-file/test name (Flutter) or native qualified test name. The ignored `artifacts/session-8/documentation/automated-test-index.json` retains every result, input path/hash and suite check command. Original raw logs are preserved.

## Other completed local checks

| Check | Existing result | Log |
| --- | --- | --- |
| offline-lockfile | Passed, exit 0 | `artifacts/session-8/checks/offline-lockfile.log` |
| format | Passed, exit 0 | `artifacts/session-8/checks/format.log` |
| analyze | Passed, exit 0 | `artifacts/session-8/checks/analyze.log` |

Lockfile and dependency declarations were unchanged. These result records, rather than repeating their commands, establish completion.

## Flutter tests

### mobile/test/alerts_test.dart

| Stable ID | Passed test |
| --- | --- |
| `FL-420489e7fb` | Android same-boot restoration ignores a changed wall clock; reboot falls back to UTC |
| `FL-47cef1d944` | FocusPhase.focus schedules only while running and resume replaces its segment |
| `FL-7d56f629ba` | FocusPhase.longBreak schedules only while running and resume replaces its segment |
| `FL-f414a95c31` | FocusPhase.shortBreak schedules only while running and resume replaces its segment |
| `FL-8b7f0afebc` | clock failure leaves the last durable scheduled request intact |
| `FL-cc6a17b1a4` | crash after OS update repairs from durable desired state |
| `FL-f0e1527c51` | crash before OS update repairs from durable desired state |
| `FL-6ef2624c23` | crash between cancelled database state and OS cancellation removes stale request |
| `FL-e40551cf07` | denial, revocation and inexact fallback retain the running phase |
| `FL-60fa220d45` | duplicate open/dismiss taps, stale payloads and action-ack crash do not advance phases |
| `FL-927bf59c3a` | failed acknowledgement repairs without dropping timer or multiplying requests |
| `FL-35c85e7400` | failed timer save never registers an uncommitted session; retry repairs it |
| `FL-45762e57fd` | first Start explains alerts; choice false still starts one phase |
| `FL-a01731db21` | first Start explains alerts; choice true still starts one phase |
| `FL-bce3208188` | long absence completes one focus and never schedules the ready break |
| `FL-1e4219c57b` | skip and phase selection retire their requests; duration edits preserve active timing |
| `FL-c0ed82bdb4` | strict mode blocks controls without replacing an active request |

### mobile/test/controller_test.dart

| Stable ID | Passed test |
| --- | --- |
| `FL-e2509f2d58` | a control at the deadline cannot act on two phases |
| `FL-0ebf49c94a` | a delayed clock response cannot restart an inactive or disposed ticker |
| `FL-51340b22b9` | a failed completion save reports failure and retry keeps the same identity |
| `FL-ac1d610a11` | backward-clock recovery checkpoints its capped deadline once |
| `FL-41c75a9c83` | clock failure preserves state, stops ticker and can be reconciled on retry |
| `FL-a66e8daa7e` | failed saves are visible and retry writes the newest state |
| `FL-609871d755` | midnight completion and timezone regrouping use completion instant, not reopening |
| `FL-20802d517c` | overdue recovery saves one completion and an advanced timer atomically |
| `FL-e0ddea7805` | rapid queued toggles cannot start then immediately pause a new session |
| `FL-0012b8b774` | refresh queued before a control consumes the old phase revision |
| `FL-b71fd93976` | rendering has no saves and ticker is cancelled while idle or inactive |
| `FL-373e9175c6` | session-targeted actions are explicit, repeatable and reject stale IDs |
| `FL-c723946315` | strict controls also apply to direct application and notification actions |
| `FL-8e128b68db` | task actions and selected focus task persist across startup |
| `FL-c3e6d8c698` | task changes during delayed start and paused recovery retain captured task |
| `FL-c6ee6e9242` | unchanged reconciliation reports an outstanding failed save honestly |

### mobile/test/durability_test.dart

| Stable ID | Passed test |
| --- | --- |
| `FL-607dc3c956` | 100000-row history has indexed bounded pages, ties and reversible cursors |
| `FL-c6949c3e8a` | SQLite FULL rolls back all rows and same commit retries after space is available |
| `FL-f8ea716f19` | UTC range summaries honor midnight, timezone regrouping and 23/25 hour days |
| `FL-03224b6272` | close/reopen retains settings, task order and history without any remote service |
| `FL-d0f098c12b` | commit succeeded but acknowledgement failed retries the exact identity once |
| `FL-07af4ba6e0` | confirmed reset supersedes an earlier failed task insert |
| `FL-680b5a961a` | delayed save cannot overtake a later task edit or reset |
| `FL-1d5a7d4199` | failed completion followed by task edits retries every delta, then deletion cannot resurrect it |
| `FL-6ce7e42524` | fixed v1 fixture migrates, preserves identities/order/snapshots and reopens |
| `FL-d6d1e749dc` | fixed v2 fixture migrates, preserves identities/order/snapshots and reopens |
| `FL-c85f76e0fb` | fresh schema is identical to v1 migration |
| `FL-a62264ad51` | full reset abandons strict timer and unfinished native cleanup resumes on reopen |
| `FL-adfc252a57` | future version and unreadable database are retained without reset |
| `FL-e638239cd8` | malformed migration JSON never reaches diagnostic logs |
| `FL-8fbabeb25e` | malformed settings/task/history produce safe errors and preserve data |
| `FL-1bc96e8120` | migration fails after partial backfill and rolls back schema/data/version |
| `FL-6f3405e255` | ordinary edits touch only dirty task rows and never reinsert known history |
| `FL-4e2e99dfff` | reset resolves uncertain commit without resurrecting old task contents |
| `FL-5b0decfb88` | rollback, duplicate completion identity and conflicting content never advance partially |
| `FL-ac279e4246` | task edits dispatched after a reset survive the reset boundary |

### mobile/test/durability_ui_test.dart

| Stable ID | Passed test |
| --- | --- |
| `FL-001f3f9767` | failed history is an error, retry shows a real empty state |
| `FL-456959b8e6` | foreground date and timezone reconciliation refresh local-day aggregates |
| `FL-26bcf01d04` | full reset confirmation and native cleanup failure have retry feedback |
| `FL-d75f354710` | history pages, confirmation cancel, delete and clear history work |
| `FL-118a8abf1b` | stale async pages cannot overwrite newer results or reappear after deletion |

### mobile/test/launch_reporter_test.dart

| Stable ID | Passed test |
| --- | --- |
| `FL-7ad3379070` | missing or failed launch reporting cannot fail startup |
| `FL-4139e88a5f` | one Android call reports usability without awaiting any timer work |
| `FL-6ca953cf67` | other platforms perform no Android launch call |
| `FL-66f9d01105` | usability waits for restored UI and is not reported on rebuild |

### mobile/test/local_storage_policy_test.dart

| Stable ID | Passed test |
| --- | --- |
| `FL-92cb952552` | Android policy uses manifest rules without a native channel call |
| `FL-12f7f76282` | an unavailable iOS bridge cannot silently enable backups |
| `FL-c67bfe30ba` | iOS excludes the actual database directory through the native bridge |
| `FL-b85de9ff9f` | native exclusion failures remain visible to startup |

### mobile/test/native_reader_concurrency_test.dart

| Stable ID | Passed test |
| --- | --- |
| `FL-4ddc876b92` | production read transactions allow a second connection to read alerts |

### mobile/test/notification_repository_test.dart

| Stable ID | Passed test |
| --- | --- |
| `FL-7127df3e13` | completion, successor and alert cancellation roll back and retry together |
| `FL-8718b7125d` | invalid v1 snapshot rejects migration without rewriting database bytes |
| `FL-0a6d740975` | v1 migration retains running identity/tasks and durable action receipts survive reopen |

### mobile/test/offline_flow_test.dart

| Stable ID | Passed test |
| --- | --- |
| `FL-e667d3ac52` | UI focus, manual break, history and settings survive SQLite reopen |

### mobile/test/process_crash_test.dart

| Stable ID | Passed test |
| --- | --- |
| `FL-d2ac2005c5` | owner process exit afterCommit preserves atomic completion and alert cancellation |
| `FL-1b246dec8a` | owner process exit beforeCommit preserves atomic completion and alert cancellation |

### mobile/test/refinement_test.dart

| Stable ID | Passed test |
| --- | --- |
| `FL-3bf7915319` | alert state AlertAvailability.delayed offers honest recovery without auto permission prompts |
| `FL-bc80418f3f` | alert state AlertAvailability.denied offers honest recovery without auto permission prompts |
| `FL-0f9f8c8005` | alert state AlertAvailability.disabled offers honest recovery without auto permission prompts |
| `FL-e54b04788e` | alert state AlertAvailability.failed offers honest recovery without auto permission prompts |
| `FL-7886f88112` | alert state AlertAvailability.ready offers honest recovery without auto permission prompts |
| `FL-7425d5eb39` | alert state AlertAvailability.unavailable offers honest recovery without auto permission prompts |
| `FL-9e72a4a6bb` | chart data has dated semantic totals and uses device date/time preferences |
| `FL-3a9c98dcce` | compact dark 1.0x populated screens remain usable |
| `FL-815a00834c` | compact dark 2.0x populated screens remain usable |
| `FL-9fb2c30eeb` | compact light 1.0x populated screens remain usable |
| `FL-f4aa2b904f` | compact light 2.0x populated screens remain usable |
| `FL-57dc9dc4c6` | completion region stops announcing after the first presentation |
| `FL-4282c7734c` | current modes remain accessible in dark at 1.0x text |
| `FL-8d7c28859a` | current modes remain accessible in dark at 2.0x text |
| `FL-a7c8dd1b42` | current modes remain accessible in light at 1.0x text |
| `FL-e9a42fb554` | current modes remain accessible in light at 2.0x text |
| `FL-ef31d16fb3` | current task snapshot, completion notice and manual break action agree |
| `FL-6adf723988` | landscape dark 1.0x populated screens remain usable |
| `FL-68e17539bb` | landscape dark 2.0x populated screens remain usable |
| `FL-101f4490a7` | landscape light 1.0x populated screens remain usable |
| `FL-4cca77ec3b` | landscape light 2.0x populated screens remain usable |
| `FL-0bfdcb572f` | overdue recovery has a real completion notice; manual phase changes do not |
| `FL-52fe6d3a86` | palette text and essential accents meet contrast ratios |
| `FL-eef5e2fbdd` | strict mode locks timer controls while stacked errors remain scrollable |
| `FL-63c3242f77` | tall dark 1.0x populated screens remain usable |
| `FL-97062c3bfc` | tall dark 2.0x populated screens remain usable |
| `FL-82a0ec1df8` | tall light 1.0x populated screens remain usable |
| `FL-4cbd6dcc20` | tall light 2.0x populated screens remain usable |
| `FL-036498d064` | task input validates, submits with keyboard, and reopens a completed task |

### mobile/test/repository_test.dart

| Stable ID | Passed test |
| --- | --- |
| `FL-f5b58a3951` | SQLite survives close and reopen with tasks, preferences and a running timer |
| `FL-91126d760d` | a database is not created until privacy preparation succeeds |
| `FL-fa0aa6c6f9` | backup preparation failure preserves an existing database and retry reopens it |
| `FL-79c2a4bb21` | completion identity prevents duplicate history and clearing a selection persists |
| `FL-7c4c75d9cf` | failed SQLite completion rolls back timer and history; retry survives reopen |
| `FL-1f87a3be1e` | malformed persisted timer fails startup without rewriting SQLite bytes |

### mobile/test/startup_work_test.dart

| Stable ID | Passed test |
| --- | --- |
| `FL-3208efb0fd` | countdown ticks do no writes or alerts; background reads stop |
| `FL-0b4987d994` | start refresh waits for native synchronization without blocking paint |
| `FL-1e0dece384` | startup and foreground summary reads are counted independently |
| `FL-206eaa629f` | summary reads do not weaken the startup native alert barrier |

### mobile/test/timer_clock_test.dart

| Stable ID | Passed test |
| --- | --- |
| `FL-63a3638a15` | malformed and regressing native readings are rejected |
| `FL-676ed69be4` | missing bridge and native failures never fall back to wall time |
| `FL-5e9f808aaf` | native sleep-inclusive samples, not Dart execution, drive elapsed time |

### mobile/test/timer_engine_test.dart

| Stable ID | Passed test |
| --- | --- |
| `FL-4dd4f6cca5` | TimerAction.pause at expiry of FocusPhase.focus consumes only the original phase |
| `FL-f1ea553089` | TimerAction.pause at expiry of FocusPhase.longBreak consumes only the original phase |
| `FL-6201951101` | TimerAction.pause at expiry of FocusPhase.shortBreak consumes only the original phase |
| `FL-da3e2a6349` | TimerAction.reset at expiry of FocusPhase.focus consumes only the original phase |
| `FL-09587ae0d1` | TimerAction.reset at expiry of FocusPhase.longBreak consumes only the original phase |
| `FL-e5390cf6ef` | TimerAction.reset at expiry of FocusPhase.shortBreak consumes only the original phase |
| `FL-ce933c61ac` | TimerAction.resume at expiry of FocusPhase.focus consumes only the original phase |
| `FL-6930f792ac` | TimerAction.resume at expiry of FocusPhase.longBreak consumes only the original phase |
| `FL-5205046cf8` | TimerAction.resume at expiry of FocusPhase.shortBreak consumes only the original phase |
| `FL-9c64fa42e9` | TimerAction.selectPhase at expiry of FocusPhase.focus consumes only the original phase |
| `FL-a6e078e954` | TimerAction.selectPhase at expiry of FocusPhase.longBreak consumes only the original phase |
| `FL-f513adde8f` | TimerAction.selectPhase at expiry of FocusPhase.shortBreak consumes only the original phase |
| `FL-55750a7802` | TimerAction.skip at expiry of FocusPhase.focus consumes only the original phase |
| `FL-15ffc2b029` | TimerAction.skip at expiry of FocusPhase.longBreak consumes only the original phase |
| `FL-928dd719bf` | TimerAction.skip at expiry of FocusPhase.shortBreak consumes only the original phase |
| `FL-114b2f5ea2` | TimerAction.start at expiry of FocusPhase.focus consumes only the original phase |
| `FL-ce9d97c2d0` | TimerAction.start at expiry of FocusPhase.longBreak consumes only the original phase |
| `FL-1bf1f36078` | TimerAction.start at expiry of FocusPhase.shortBreak consumes only the original phase |
| `FL-2a9adfc798` | a regressing live elapsed clock fails before changing state |
| `FL-736631dc44` | continuous elapsed time completes a sleeping live process without callbacks |
| `FL-ce26fb5a6d` | cycle target changes preserve earned progress and current phase |
| `FL-1ec2cc1a88` | delayed callbacks and repeated refresh never count callback frequency |
| `FL-987c12d8a8` | duration edits preserve running and paused duration until reset |
| `FL-2a51382272` | four completed focus rounds and long break finish the default cycle |
| `FL-e5ac0a97db` | fractional expiry rounds display upward and completes at zero only |
| `FL-2513e56924` | live countdown and completion deadline ignore wall jump -3:00:00.000000 |
| `FL-92311e8a9c` | live countdown and completion deadline ignore wall jump 3:00:00.000000 |
| `FL-30b1eef987` | pause, reset and skip one microsecond before expiry never count a completion |
| `FL-ccb6b46056` | paused FocusPhase.focus recovery excludes days closed and preserves metadata |
| `FL-eb3fa7769b` | paused FocusPhase.longBreak recovery excludes days closed and preserves metadata |
| `FL-5e07f59f46` | paused FocusPhase.shortBreak recovery excludes days closed and preserves metadata |
| `FL-385d054e52` | repeated fractional pauses preserve identity, task and exact remaining |
| `FL-9edc977712` | reset, skip and same-phase selection abandon without counting |
| `FL-b1a898f700` | restart with a backward wall clock caps remaining to original duration |
| `FL-460e461e92` | running FocusPhase.focus restores deadline and completes only its started phase |
| `FL-45536d86c2` | running FocusPhase.longBreak restores deadline and completes only its started phase |
| `FL-54461a9d73` | running FocusPhase.shortBreak restores deadline and completes only its started phase |
| `FL-5f191b7d9d` | settings at expiry apply after completion without selecting another phase |
| `FL-be27798fbd` | snapshot parser rejects corruption instead of clamping or erasing it |
| `FL-db5588bac2` | strict FocusPhase.focus locks controls and timing settings but permits appearance |
| `FL-dcb301b52e` | strict FocusPhase.longBreak locks controls and timing settings but permits appearance |
| `FL-1a2b652643` | strict FocusPhase.shortBreak locks controls and timing settings but permits appearance |

### mobile/test/ui_test.dart

| Stable ID | Passed test |
| --- | --- |
| `FL-f09011bce1` | all four screens fit a small phone with 200 percent text |
| `FL-3f905de499` | callbacks from the previous frame cannot start, reset or skip the successor |
| `FL-8e3c2a0561` | current mode follows a 1-round cycle and waits for Start |
| `FL-6042e3f794` | current mode follows a 3-round cycle and waits for Start |
| `FL-8b214c0c54` | current mode follows a 4-round cycle and waits for Start |
| `FL-981c9c16cf` | focus controls and the real task form work |
| `FL-4cd09abc9e` | light and dark focus previews |
| `FL-ba3017b428` | startup privacy failure offers retry and retains saved tasks |

## Android JVM tests

| Stable ID | Passed test | Runner seconds |
| --- | --- | ---: |
| `AN-26fbc8dc31` | dev.poma.poma.AlertPolicyTest.elapsedDeadlineCanBeOverdueAfterSleep | 0.003 |
| `AN-b0dcf7f056` | dev.poma.poma.AlertPolicyTest.oldRunAndOldResumeGenerationAreRejected | 0.0 |
| `AN-415b7fec70` | dev.poma.poma.AlertPolicyTest.overdueRebootDoesNotRescheduleFutureWork | 0.0 |
| `AN-2273bafead` | dev.poma.poma.AlertPolicyTest.rebootNeverComparesDifferentBootRelativeClocks | 0.0 |
| `AN-4b33ee0ca4` | dev.poma.poma.AlertPolicyTest.sameBootIgnoresForwardAndBackwardWallChanges | 0.03 |
| `AN-8d192f31a3` | dev.poma.poma.AlertPolicyTest.unavailableBootIdentityUsesBoundedUtc | 0.0 |
| `AN-482e99eb95` | dev.poma.poma.AlertWorkQueueTest.blockedNativeReadLeavesCallerFreeToCompleteDatabaseReply | 0.001 |
| `AN-e9e773a679` | dev.poma.poma.AlertWorkQueueTest.bridgeAndReceiverWorkStayOrderedWhileCallerRemainsResponsive | 0.005 |

## Swift simulator tests

| Stable ID | Passed test | Runner seconds |
| --- | --- | ---: |
| `SW-850e948915` | RunnerTests.testAlertUsesOneShotElapsedIntervalAndPersistedIdentity() | 0.004 |
| `SW-62b5b2aa0b` | RunnerTests.testBreakWordingAndActionsDoNotStartAPhase() | 0.001 |
| `SW-8cc2aa3e6a` | RunnerTests.testCannotExcludeTheContainerRootOrAnOutsideDirectory() | 0.004 |
| `SW-6a80512024` | RunnerTests.testConcurrentNativeResponsesDoNotOverwriteEachOther() | 0.028 |
| `SW-ef9237a6b9` | RunnerTests.testCreatesExcludedDirectoryBeforeTheDatabaseExists() | 0.01 |
| `SW-4937788904` | RunnerTests.testExclusionPreservesDatabaseAndSidecars() | 0.004 |
| `SW-9a3e427819` | RunnerTests.testExpiredAlertIsNotReplayed() | 0.002 |
| `SW-3b4d4df7f3` | RunnerTests.testResetClearsResponseJournalIdempotently() | 0.005 |
| `SW-66d80582d0` | RunnerTests.testResponseJournalSurvivesRecreationAndDeduplicatesTaps() | 0.006 |
| `SW-a123e19316` | RunnerTests.testStaleRunOrSegmentDoesNotMatch() | 0.001 |

