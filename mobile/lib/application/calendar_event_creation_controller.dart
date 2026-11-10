import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../domain/calendar_data.dart';
import '../domain/calendar_event_creation.dart';
import '../domain/focus_blocks.dart' show CalendarWriteCapability;
import 'calendar_connection_controller.dart';
import 'calendar_event_creation_ports.dart';
import 'calendar_read_controller.dart';
import 'focus_block_ports.dart';

/// A separate command lane. Neither timer commands nor focus ownership enter it.
class CalendarCreationController extends ChangeNotifier {
  CalendarCreationController({
    required this.connection,
    required this.reader,
    required this.store,
    required this.writer,
    required this.time,
  }) {
    connection.addListener(_sessionChanged);
  }
  final CalendarConnectionController connection;
  final CalendarReadController reader;
  final CalendarCreationStore store;
  final CalendarEventCreationWriter writer;
  final FocusTimeResolver time;
  CalendarCreationJournal? journal;
  CreationStoreLease? _lease;
  Future<void> _transition = Future.value(), _saves = Future.value();
  int _epoch = 0;
  String _signature = '';
  bool _disposed = false, _unlocked = false, _disabled = false, busy = false;
  String? message;
  String? activeId;
  CalendarCreateOperation? get active => journal?.operations[activeId];
  bool get unlocked => _unlocked;
  bool get ready =>
      !_disposed &&
      unlocked &&
      !_disabled &&
      _lease != null &&
      connection.creationEnabled &&
      !connection.creationUpgradeActive &&
      connection.operationsEnabled &&
      journal?.accountKey == connection.verifiedAccountKey;
  bool get disabled => _disabled;
  DateTime get now => reader.now.toUtc();
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  String get _session =>
      '${connection.verifiedAccountKey}/${connection.sessionGeneration}/'
      '${connection.storageRevision}/${connection.creationGeneration}/${connection.creationEnabled}/'
      '${connection.creationUpgradeActive}';
  bool _current(int e) => !_disposed && e == _epoch;
  void _guard(int e, {bool mutation = false}) {
    if (!_current(e) ||
        !unlocked ||
        _lease == null ||
        journal?.accountKey != connection.verifiedAccountKey ||
        mutation && !ready) {
      throw StateError('Creation authority changed.');
    }
  }

  void setUnlocked(bool value) {
    if (_unlocked == value) return;
    _unlocked = value;
    if (!value &&
        const {
          CalendarWriteCapability.granting,
          CalendarWriteCapability.verifying,
        }.contains(connection.creationCapability)) {
      unawaited(connection.cancelCreationConsent());
    }
    _restart();
  }

  void _sessionChanged() {
    if (_signature == _session) {
      _notify();
      return;
    }
    _restart();
  }

  Future<void> initialize() {
    _restart();
    return _transition;
  }

  void _restart() {
    _signature = _session;
    final e = ++_epoch, key = connection.verifiedAccountKey;
    final purge = journal != null && journal!.accountKey != key;
    writer.cancel();
    busy = false;
    _lease = null;
    if (purge) {
      journal = null;
      activeId = null;
    }
    Object? stopFailure;
    final stop = store.stop(purge: purge).catchError((Object error) {
      stopFailure = error;
    });
    _transition = _transition.catchError((Object _) {}).then((_) async {
      try {
        await stop;
        if (stopFailure != null) {
          throw StateError('Creation invalidation failed.');
        }
        await _saves;
        if (!_current(e) ||
            key == null ||
            !unlocked ||
            connection.cleanupPending) {
          return;
        }
        final saved = await store.open(key);
        if (!_current(e)) return;
        final j = saved.document == null
            ? CalendarCreationJournal(key)
            : CalendarCreationJournal.decode(saved.document!, key);
        _lease = saved.lease;
        _disabled = saved.disabled;
        journal = j;
        await _commit((next) {
          for (final entry in next.operations.entries.toList()) {
            final op = entry.value;
            if (op.state == CalendarCreationState.sending) {
              next.operations[entry.key] = op.result(
                const CalendarCreateResult(
                  CalendarCreationState.checking,
                  message:
                      'Poma restarted. Check the original event before retrying.',
                ),
                now,
              );
            }
            final later =
                op.transitionAt != null &&
                    op.transitionAt!.isAfter(op.intent.endUtc)
                ? op.transitionAt!
                : op.intent.endUtc;
            if ((op.state == CalendarCreationState.saved ||
                    op.state == CalendarCreationState.failed) &&
                now.difference(later) > const Duration(days: 30)) {
              next.operations.remove(entry.key);
              next.drafts.remove(entry.key);
            }
          }
          next.drafts.removeWhere((id, d) {
            if (next.operations.containsKey(id)) return false;
            final end = DateTime.tryParse(d.endDate)?.toUtc();
            final later =
                end != null && (d.savedAt == null || end.isAfter(d.savedAt!))
                ? end
                : d.savedAt;
            return later != null &&
                now.difference(later) > const Duration(days: 30);
          });
        }, e);
        if (_current(e)) message = null;
      } catch (_) {
        if (_current(e)) {
          _lease = null;
          message =
              'Task-save storage needs attention. No event will be sent. Retry storage or repair it before continuing.';
        }
      }
      _notify();
    });
    _notify();
  }

  Future<void> stop() async {
    ++_epoch;
    writer.cancel();
    busy = false;
    _lease = null;
    final stopped = store.stop();
    await stopped;
    await _saves;
    _notify();
  }

  Future<void> _commit(void Function(CalendarCreationJournal) change, int e) {
    final result = _saves.then((_) async {
      _guard(e);
      final next = CalendarCreationJournal.decode(
        journal!.encode(),
        journal!.accountKey,
      );
      change(next);
      final encoded = next.encode();
      if (utf8.encode(encoded).length > 16 * 1024 * 1024) {
        throw StateError('Journal too large.');
      }
      try {
        final lease = await store.save(_lease!, encoded);
        _guard(e);
        _lease = lease;
        journal = next;
      } catch (_) {
        _guard(e);
        final saved = await store.open(journal!.accountKey);
        _guard(e);
        _lease = saved.lease;
        if (saved.document != encoded) rethrow;
        journal = CalendarCreationJournal.decode(
          encoded,
          saved.lease.accountKey,
        );
      }
      _notify();
    });
    _saves = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<bool> keepDraft(CalendarEventDraft draft) async {
    if (draft.accountKey == null || connection.verifiedAccountKey == null) {
      message =
          'Connect Google and choose the account for this draft before saving it on this device. The form stays in memory while Poma runs.';
      _notify();
      return false;
    }
    await _transition;
    final e = _epoch;
    try {
      _guard(e);
      if (draft.accountKey != journal!.accountKey) {
        throw StateError('Account changed.');
      }
      final frozen = CalendarEventDraft.fromJson(draft.toJson())..savedAt = now;
      await _commit((j) {
        j.drafts[draft.id] = frozen;
        j.destination = draft.calendarId;
      }, e);
      message = 'Draft saved on this device. Not scheduled.';
      _notify();
      return true;
    } catch (_) {
      if (_current(e)) {
        message =
            'The draft could not be saved. Its fields remain in this form; no event was sent.';
        _notify();
      }
      return false;
    }
  }

  Future<void> discard(String id) async {
    await _transition;
    final e = _epoch;
    if (journal?.operations.containsKey(id) == true) return;
    try {
      await _commit((j) => j.drafts.remove(id), e);
    } catch (_) {
      message = 'The stored draft could not be removed. Retry storage.';
      _notify();
      rethrow;
    }
  }

  Future<void> enable({CalendarEventDraft? draft}) async {
    if (draft != null && !await keepDraft(draft)) return;
    if (!unlocked) return;
    await connection.enableCreation();
    await _transition;
    if (connection.creationEnabled && unlocked) {
      try {
        await store.setDisabled(false);
        await initialize();
      } catch (_) {
        message =
            'Access is granted, but local task creation could not be enabled.';
        _notify();
      }
    }
  }

  Future<void> disable() async {
    ++_epoch;
    _disabled = true;
    _lease = null;
    writer.cancel();
    busy = false;
    _notify();
    var localSaved = false;
    try {
      await store.setDisabled(true);
      localSaved = true;
    } catch (_) {
      /* Also attempt protected receipt disablement. */
    }
    await connection.disableCreation();
    if (localSaved) {
      await initialize();
    } else {
      message =
          'Creation stopped, but saving disablement needs attention. Retry before closing Poma.';
      _notify();
    }
  }

  Future<void> _verifyTime(CalendarCreateIntent i) async {
    if (!i.startUtc.isAfter(now) ||
        !i.endUtc.isAfter(i.startUtc) ||
        await time.fingerprint() != i.zoneFingerprint) {
      throw StateError('Review the current future times.');
    }
    final r = await Future.wait([
      time.resolve(i.startUtc.add(Duration(minutes: i.startOffset))),
      time.resolve(i.endUtc.add(Duration(minutes: i.endOffset))),
    ]);
    if (r[0].utc != i.startUtc ||
        r[1].utc != i.endUtc ||
        r[0].fingerprint != i.zoneFingerprint ||
        r[1].fingerprint != i.zoneFingerprint ||
        r[0].offsetMinutes != i.startOffset ||
        r[1].offsetMinutes != i.endOffset) {
      throw StateError('Timezone rules changed.');
    }
  }

  Future<void> verifyTime(CalendarCreateIntent intent) => _verifyTime(intent);

  Future<CalendarCreateResult> submit(
    CalendarEventDraft draft,
    CalendarCreateIntent intent, {
    bool retry = false,
  }) async {
    if (busy) return _result(active);
    final e = _epoch;
    busy = true;
    _notify();
    await _transition;
    activeId = draft.id;
    try {
      _guard(e, mutation: true);
      final previous = journal!.operations[draft.id];
      if (previous != null && !retry) return await _check(previous, e);
      if (intent.accountKey != journal!.accountKey ||
          intent.title.trim().isEmpty ||
          intent.colorId != null &&
              reader.palette?.colors.containsKey(intent.colorId) != true) {
        throw StateError('Review the current draft.');
      }
      if (previous != null) {
        if (previous.state == CalendarCreationState.saved) {
          return _result(previous);
        }
        if (previous.intent.hash != intent.hash ||
            previous.intent.calendarId != intent.calendarId) {
          return const CalendarCreateResult(
            CalendarCreationState.failed,
            message:
                'Resolve the original save before editing its reviewed payload.',
          );
        }
        final checked = await _check(previous, e);
        if (!checked.retryAllowed) return checked;
      }
      await _verifyTime(intent);
      _guard(e, mutation: true);
      if (!await writer.validateDestination(
        intent.accountKey,
        intent.calendarId,
      )) {
        throw StateError('The original owned calendar is unavailable.');
      }
      _guard(e, mutation: true);
      final op =
          previous ??
          CalendarCreateOperation(
            draft.id,
            creationEventId(draft.id),
            intent,
            clientId: connection.configuration.clientId,
            generation: connection.creationGeneration!,
            state: CalendarCreationState.sending,
            confirmedAt: now,
            transitionAt: now,
          );
      await _commit((j) {
        j.drafts[draft.id] = CalendarEventDraft.fromJson(draft.toJson());
        j.destination = intent.calendarId;
        j.operations[draft.id] = op.result(
          const CalendarCreateResult(
            CalendarCreationState.sending,
            message: 'Sending to Google Calendar…',
          ),
          now,
        );
      }, e);
      _guard(e, mutation: true);
      var result = await writer.create(op);
      _guard(e);
      if (result.state == CalendarCreationState.checking) {
        await _record(op, result, e);
        result = await writer.readBack(op);
        _guard(e);
      }
      await _record(op, result, e);
      if (result.state == CalendarCreationState.saved) {
        result = await _afterSaved(op, result, e);
      }
      return result;
    } catch (_) {
      final existing = journal?.operations[draft.id];
      final result = CalendarCreateResult(
        existing == null
            ? CalendarCreationState.failed
            : CalendarCreationState.checking,
        message: existing == null
            ? 'The task was not sent. Check storage, access and future times; your fields are kept.'
            : 'The outcome needs checking. The original event ID is retained; do not create a replacement.',
      );
      if (_current(e)) {
        message = result.message;
        _notify();
      }
      return result;
    } finally {
      if (_current(e)) {
        busy = false;
        _notify();
      }
    }
  }

  CalendarCreateResult _result(CalendarCreateOperation? op) => op == null
      ? const CalendarCreateResult(CalendarCreationState.draft)
      : CalendarCreateResult(
          op.state,
          event: op.event,
          message: op.message,
          retryAllowed: op.retryAllowed,
        );
  Future<void> _record(
    CalendarCreateOperation op,
    CalendarCreateResult result,
    int e,
  ) => _commit((j) => j.operations[op.operationId] = op.result(result, now), e);
  Future<CalendarCreateResult> check(CalendarCreateOperation op) async {
    if (busy) return _result(active);
    final e = _epoch;
    busy = true;
    activeId = op.operationId;
    _notify();
    await _transition;
    try {
      return await _check(op, e);
    } catch (_) {
      return const CalendarCreateResult(
        CalendarCreationState.checking,
        message:
            'The outcome could not be checked. Restore the original account and try again.',
      );
    } finally {
      if (_current(e)) {
        busy = false;
        _notify();
      }
    }
  }

  Future<CalendarCreateResult> _check(CalendarCreateOperation op, int e) async {
    _guard(e);
    if (op.intent.accountKey != journal!.accountKey ||
        op.clientId != connection.configuration.clientId ||
        !connection.operationsEnabled) {
      throw StateError('Original account unavailable.');
    }
    if (op.state == CalendarCreationState.saved) return _result(op);
    var result = await writer.readBack(op);
    if (result.retryAllowed && !op.intent.startUtc.isAfter(now)) {
      result = const CalendarCreateResult(
        CalendarCreationState.failed,
        message:
            'No event was found on the verified original calendar, and the reviewed start has expired. Use Add task for a new future intent.',
      );
    }
    _guard(e);
    await _record(op, result, e);
    if (result.state == CalendarCreationState.saved) {
      result = await _afterSaved(op, result, e);
    }
    return result;
  }

  Future<CalendarCreateResult> _afterSaved(
    CalendarCreateOperation op,
    CalendarCreateResult result,
    int e,
  ) async {
    var refreshFailed = false;
    try {
      await reader.refreshAfterCreation();
    } catch (_) {
      refreshFailed = true;
    }
    if (!_current(e)) {
      return CalendarCreateResult(
        CalendarCreationState.saved,
        event: result.event,
        message:
            'Saved to Google Calendar. The schedule refresh could not be confirmed.',
      );
    }
    final event = result.event!;
    final hidden = !reader.selected.contains(event.calendarId);
    final outside = !event.overlaps(reader.window);
    final found = reader.events.any(
      (v) => calendarEventIdentity(v) == calendarEventIdentity(event),
    );
    final notice = hidden
        ? ' Its calendar is hidden. Choose Show calendar to display it.'
        : outside
        ? ' This date is outside the retained clock coverage.'
        : refreshFailed ||
              !found ||
              reader.failure != null ||
              reader.sourceFailures.containsKey(event.calendarId)
        ? ' The schedule could not yet be refreshed. The Google event is saved.'
        : '';
    result = CalendarCreateResult(
      CalendarCreationState.saved,
      event: event,
      message: 'Saved to Google Calendar.$notice',
    );
    try {
      await _record(op, result, e);
    } catch (_) {
      /* The prior Saved receipt remains authoritative. */
    }
    message = result.message;
    _notify();
    return result;
  }

  String describe(CalendarCreateOperation op) {
    if (op.state != CalendarCreationState.saved || op.event == null) {
      return op.message ?? op.state.name;
    }
    if (!reader.selected.contains(op.intent.calendarId)) {
      return 'Saved. Its calendar is hidden; choose Show calendar to display it.';
    }
    if (!op.event!.overlaps(reader.window)) {
      return 'Saved. This date is outside retained clock coverage. Open the Google event for details.';
    }
    if (reader.failure != null ||
        reader.sourceFailures.containsKey(op.intent.calendarId) ||
        !reader.events.any(
          (e) => calendarEventIdentity(e) == calendarEventIdentity(op.event!),
        )) {
      return 'Saved. The schedule has not refreshed to confirm it; use Open event in Google Calendar.';
    }
    // Persisted notices describe the original refresh, which may have recovered.
    // Current selection/coverage above determines what still needs attention.
    return 'Saved to Google Calendar.';
  }

  Future<void> showCalendar(CalendarCreateOperation op) async {
    if (op.intent.accountKey != connection.verifiedAccountKey ||
        !unlocked ||
        busy) {
      return;
    }
    await reader.select({...reader.selected, op.intent.calendarId});
  }

  @override
  void dispose() {
    _disposed = true;
    ++_epoch;
    writer.cancel();
    connection.removeListener(_sessionChanged);
    unawaited(store.stop().catchError((Object _) {}));
    super.dispose();
  }
}
