import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../domain/focus_blocks.dart';
import 'focus_block_ports.dart';

/// Calendar commands have their own persistence lane; never the timer's queue.
class FocusBlockController extends ChangeNotifier {
  FocusBlockController({
    required this.session,
    required this.store,
    required this.writer,
    required this.time,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now {
    session.addListener(_sessionChanged);
    _signature = _sessionSignature;
  }
  final FocusWriteSession session;
  final FocusBlockOperationStore store;
  final FocusBlockWriter writer;
  final FocusTimeResolver time;
  final DateTime Function() _now;
  FocusJournal? journal;
  FocusStoreLease? _lease;
  Future<void> _saves = Future.value();
  Future<void>? _initializing;
  Future<void>? _stopping;
  final Map<String, FocusBlockPreview> _previews = {};
  final Set<String> _busy = {};
  int _epoch = 0;
  bool _disposed = false,
      _unlocked = true,
      _setupBusy = false,
      _disabled = false;
  bool get disabled => _disabled;
  String? message;
  String _signature = '';
  DateTime get now => _now().toUtc();
  bool get unlocked => _unlocked;
  set unlocked(bool value) {
    if (_unlocked == value) return;
    _unlocked = value;
    _previews.clear();
    if (!value) writer.cancel();
    _notify();
  }

  CalendarWriteCapability get capability => _disabled
      ? CalendarWriteCapability.disabled
      : session.writeCapability == CalendarWriteCapability.setupRequired &&
            journal?.binding != null
      ? CalendarWriteCapability.ready
      : session.writeCapability;
  bool get online => session.focusOnline;
  bool get ready =>
      !_disabled &&
      session.focusWriteEnabled &&
      online &&
      journal?.binding != null &&
      _lease != null &&
      !_disposed &&
      unlocked;
  String get _sessionSignature =>
      '${session.verifiedAccountKey}/${session.credentialGeneration}/${session.focusWriteEnabled}';
  bool _current(int epoch) => !_disposed && epoch == _epoch;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _guard(int epoch, {bool mutation = false}) {
    if (!_current(epoch) ||
        journal?.accountKey != session.verifiedAccountKey ||
        _lease == null ||
        mutation &&
            (_disabled || !session.focusWriteEnabled || !online || !unlocked)) {
      throw const FocusFailure(FocusFailureKind.cancelled);
    }
  }

  void _sessionChanged() {
    if (_signature == _sessionSignature) {
      _notify();
      return;
    }
    _signature = _sessionSignature;
    final purge = journal?.accountKey != session.verifiedAccountKey;
    unawaited(
      stop(purge: purge).then((_) {
        if (!_disposed && session.verifiedAccountKey != null) {
          _initializing = null;
          unawaited(initialize());
        }
      }),
    );
  }

  void _error(Object error) {
    final kind = error is FocusFailure ? error.kind : FocusFailureKind.storage;
    message = switch (kind) {
      FocusFailureKind.storage =>
        'Focus scheduling could not save its local record. Repair storage and review the outcome before retrying.',
      FocusFailureKind.permission =>
        'Focus scheduling access was refused. Calendar viewing may still be available. Review scheduling setup.',
      FocusFailureKind.invalidTime =>
        'Choose a future, unambiguous time in the current device timezone and review it again.',
      FocusFailureKind.conflict || FocusFailureKind.precondition =>
        'The Google block differs from this preview. Review the current block; no unrelated data was changed.',
      FocusFailureKind.missing =>
        'The calendar or block is unavailable. Review access in Google Calendar.',
      FocusFailureKind.cancelled =>
        'This preview is no longer current. Review again before scheduling.',
      FocusFailureKind.throttled =>
        'Google requested a pause. Check the outcome again after the retry delay.',
      _ =>
        'The outcome could not be confirmed. Check the saved operation before retrying.',
    };
    _notify();
  }

  Future<void> initialize() => _initializing ??= () async {
    await _stopping;
    await _restore();
  }();
  Future<void> _restore() async {
    final epoch = _epoch, key = session.verifiedAccountKey;
    if (key == null) return;
    try {
      final saved = await store.open(key);
      if (!_current(epoch) || session.verifiedAccountKey != key) return;
      final data = saved.document == null
          ? FocusJournal(key)
          : FocusJournal.decode(saved.document!, key);
      _lease = saved.lease;
      journal = data;
      _disabled = saved.disabled;
      await _commit((j) {
        for (final entry in j.operations.entries.toList()) {
          final op = entry.value;
          if (op.status == FocusOperationStatus.sending) {
            j.operations[entry.key] = op.state(
              FocusOperationStatus.checking,
              now,
            );
          }
          if (op.status == FocusOperationStatus.pending) {
            j.operations[entry.key] = op.state(
              op.payload.start.isAfter(now)
                  ? FocusOperationStatus.cancelled
                  : FocusOperationStatus.expired,
              now,
            );
          }
          final later =
              op.transitionAt != null &&
                  op.transitionAt!.isAfter(op.payload.end)
              ? op.transitionAt!
              : op.payload.end;
          if (!op.unresolved &&
              now.difference(later) > const Duration(days: 30)) {
            j.operations.remove(entry.key);
          }
        }
        j.drafts.removeWhere(
          (_, d) => now.difference(d.payload.end) > const Duration(days: 30),
        );
        j.blocks.removeWhere((_, b) {
          try {
            return now.difference(b.end) > const Duration(days: 30) &&
                !j.operations.values.any(
                  (o) => o.eventId == b.id && o.unresolved,
                );
          } catch (_) {
            return false;
          }
        });
        if (j.provisioningState == 'sending') j.provisioningState = 'checking';
      }, epoch: epoch);
    } catch (error) {
      if (_current(epoch)) {
        journal = null;
        _lease = null;
        _error(error);
      }
    }
    _notify();
  }

  Future<void> _commit(void Function(FocusJournal) change, {int? epoch}) {
    final expected = epoch ?? _epoch;
    final result = _saves.then((_) async {
      _guard(expected);
      final next = journal!.copy();
      change(next);
      final encoded = jsonEncode(next.toJson());
      if (utf8.encode(encoded).length > 16 * 1024 * 1024) {
        throw const FocusFailure(FocusFailureKind.storage);
      }
      try {
        final lease = await store.save(_lease!, encoded);
        _guard(expected);
        _lease = lease;
        journal = next;
      } catch (error) {
        _guard(expected);
        final saved = await store.open(journal!.accountKey);
        _guard(expected);
        _lease = saved.lease;
        if (saved.document != null) {
          journal = FocusJournal.decode(saved.document!, journal!.accountKey);
        }
        if (saved.document != encoded) rethrow;
      }
      _notify();
    });
    _saves = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<FocusCalendarBinding> _binding(
    int epoch, {
    bool mutation = false,
  }) async {
    _guard(epoch, mutation: mutation);
    final b = journal!.binding;
    if (b == null ||
        b.accountKey != session.verifiedAccountKey ||
        b.clientId != session.focusClientId) {
      throw const FocusFailure(FocusFailureKind.permission);
    }
    final current = await writer.validate(b);
    _guard(epoch, mutation: mutation);
    if (current.id != b.id ||
        current.calendarKey != b.calendarKey ||
        current.provisioningId != b.provisioningId) {
      throw const FocusFailure(FocusFailureKind.conflict);
    }
    return current;
  }

  Future<List<FocusCalendarBinding>> discoverCalendars() async {
    final epoch = _epoch;
    _guard(epoch, mutation: true);
    final found = await writer.discover(
      journal!.accountKey,
      session.focusClientId,
    );
    _guard(epoch, mutation: true);
    return found;
  }

  Future<void> bind(FocusCalendarBinding binding) async {
    final epoch = _epoch;
    _guard(epoch, mutation: true);
    final canonical = journal!.binding;
    if (canonical != null &&
        (canonical.id != binding.id ||
            canonical.calendarKey != binding.calendarKey ||
            canonical.provisioningId != binding.provisioningId)) {
      throw const FocusFailure(FocusFailureKind.conflict);
    }
    if (binding.accountKey != session.verifiedAccountKey ||
        binding.clientId != session.focusClientId) {
      throw const FocusFailure(FocusFailureKind.permission);
    }
    final current = await writer.validate(binding);
    _guard(epoch, mutation: true);
    await _commit((j) {
      j.binding = current;
      j.provisioningState = 'bound';
    }, epoch: epoch);
  }

  Future<void> createCalendar() async {
    if (_setupBusy) return;
    _setupBusy = true;
    final epoch = _epoch;
    try {
      _guard(epoch, mutation: true);
      if (journal!.binding != null) return;
      if (journal!.provisioning != null) {
        final intent = journal!.provisioning!;
        final all = await discoverCalendars();
        final matches = all
            .where(
              (b) =>
                  b.calendarKey == intent.calendarKey &&
                  b.provisioningId == intent.provisioningId,
            )
            .toList();
        if (matches.length == 1) {
          await bind(matches.single);
          return;
        }
        await _commit((j) {
          j.provisioningState = 'needsReview';
        }, epoch: epoch);
        message =
            'Calendar setup needs review. No additional calendar was created.';
        return;
      }
      final existing = await discoverCalendars();
      if (existing.isNotEmpty) {
        message =
            'Existing Poma calendars were found. Review and recover a calendar before creating another.';
        return;
      }
      final intent = FocusCalendarBinding(
        accountKey: journal!.accountKey,
        clientId: session.focusClientId,
        id: 'provisioning',
        calendarKey: focusUuid(),
        provisioningId: focusUuid(),
        name: 'Poma Focus',
      );
      await _commit((j) {
        j.provisioning = intent;
        j.provisioningState = 'prepared';
      }, epoch: epoch);
      await _commit((j) {
        j.provisioningState = 'sending';
      }, epoch: epoch);
      _guard(epoch, mutation: true);
      final created = await writer.provision(intent);
      _guard(epoch, mutation: true);
      if (created.calendarKey != intent.calendarKey ||
          created.provisioningId != intent.provisioningId) {
        throw const FocusFailure(FocusFailureKind.conflict);
      }
      await bind(created);
    } catch (error) {
      if (_current(epoch)) {
        if (journal?.provisioning != null) {
          try {
            await _commit((j) {
              j.provisioningState = 'checking';
            }, epoch: epoch);
          } catch (_) {}
        }
        _error(error);
      }
    } finally {
      _setupBusy = false;
      _notify();
    }
  }

  Future<void> saveDraft(FocusBlockDraft draft) async {
    try {
      if (!validFocusUuid(draft.id)) {
        throw const FocusFailure(FocusFailureKind.response);
      }
      await _commit((j) {
        j.drafts[draft.id] = draft;
      });
      message = 'Draft saved. Not scheduled.';
      _notify();
    } catch (error) {
      _error(error);
    }
  }

  Future<FocusBlockPreview> preview(
    FocusBlockDraft draft, {
    FocusOperationKind kind = FocusOperationKind.create,
    FocusRemoteBlock? before,
  }) async {
    final epoch = _epoch;
    final binding = await _binding(epoch, mutation: true);
    if (kind != FocusOperationKind.delete) await verifyTime(draft.payload);
    _guard(epoch, mutation: true);
    if (kind != FocusOperationKind.create) {
      if (before == null) throw const FocusFailure(FocusFailureKind.conflict);
      final current = await writer.get(binding, before.id);
      _guard(epoch, mutation: true);
      if (current == null ||
          !current.owned(binding) ||
          current.etag != before.etag ||
          current.actualHash != before.actualHash) {
        throw const FocusFailure(FocusFailureKind.precondition);
      }
      before = current;
    }
    final block = kind == FocusOperationKind.create
        ? draft.id
        : before!.blockId;
    if (journal!.operations.values.any(
          (o) => o.blockId == block && o.unresolved,
        ) ||
        journal!.operations.containsKey(draft.id)) {
      throw const FocusFailure(FocusFailureKind.conflict);
    }
    final preview = FocusBlockPreview(
      focusUuid(),
      draft,
      kind,
      binding,
      session.credentialGeneration!,
      before: before,
    );
    _previews[preview.token] = preview;
    return preview;
  }

  Future<void> confirm(FocusBlockPreview preview) async {
    if (!identical(_previews.remove(preview.token), preview)) return;
    final block = preview.kind == FocusOperationKind.create
        ? preview.draft.id
        : preview.before!.blockId;
    if (!_busy.add(block)) return;
    final epoch = _epoch;
    FocusBlockOperation? operation;
    bool sent = false;
    try {
      _guard(epoch, mutation: true);
      if (preview.credentialGeneration != session.credentialGeneration) {
        throw const FocusFailure(FocusFailureKind.cancelled);
      }
      final binding = await _binding(epoch, mutation: true);
      if (binding.id != preview.binding.id ||
          binding.calendarKey != preview.binding.calendarKey) {
        throw const FocusFailure(FocusFailureKind.conflict);
      }
      final p = preview.draft.payload;
      if (preview.kind != FocusOperationKind.delete) await verifyTime(p);
      _guard(epoch, mutation: true);
      FocusRemoteBlock? current;
      if (preview.kind != FocusOperationKind.create) {
        current = await writer.get(binding, preview.before!.id);
        _guard(epoch, mutation: true);
        if (current == null ||
            !current.owned(binding) ||
            current.etag != preview.before!.etag ||
            current.actualHash != preview.before!.actualHash) {
          throw const FocusFailure(FocusFailureKind.precondition);
        }
      }
      operation =
          preview.operation ??
          FocusBlockOperation(
            id: preview.draft.id,
            blockId: block,
            kind: preview.kind,
            payload: p,
            confirmedAt: now,
            credentialGeneration: preview.credentialGeneration,
            etag: current?.etag,
            before: current,
            taskId: preview.draft.taskId,
            target: binding,
          );
      if (preview.operation == null &&
          journal!.operations.containsKey(operation.id)) {
        return;
      }
      final op = operation;
      await _commit((j) {
        j.operations[op.id] = op.state(FocusOperationStatus.pending, now);
        j.drafts.remove(preview.draft.id);
      }, epoch: epoch);
      await _record(op, FocusOperationStatus.sending, epoch);
      _guard(epoch, mutation: true);
      if (op.kind != FocusOperationKind.delete &&
          !op.payload.start.isAfter(now)) {
        await _record(op, FocusOperationStatus.expired, epoch);
        return;
      }
      sent = true;
      FocusRemoteBlock? result;
      switch (op.kind) {
        case FocusOperationKind.create:
          result = await writer.create(binding, op);
        case FocusOperationKind.edit:
          result = await writer.edit(binding, op, current!);
        case FocusOperationKind.delete:
          await writer.delete(binding, op);
      }
      _guard(epoch);
      if (result != null && (!result.owned(binding) || !result.matches(op))) {
        throw const FocusFailure(FocusFailureKind.conflict);
      }
      await _record(op, FocusOperationStatus.saved, epoch, remote: result);
      message = op.kind == FocusOperationKind.delete
          ? 'Focus block deleted.'
          : 'Focus block saved.';
      _notify();
    } catch (error) {
      if (_current(epoch)) {
        if (operation != null) {
          final uncertain =
              sent &&
              (error is! FocusFailure ||
                  !const {
                    FocusFailureKind.permission,
                    FocusFailureKind.precondition,
                    FocusFailureKind.invalidTime,
                  }.contains(error.kind));
          try {
            await _record(
              operation,
              uncertain
                  ? FocusOperationStatus.checking
                  : error is FocusFailure &&
                        error.kind == FocusFailureKind.invalidTime &&
                        !operation.payload.start.isAfter(now)
                  ? FocusOperationStatus.expired
                  : FocusOperationStatus.failed,
              epoch,
              error: error is FocusFailure ? error.kind.name : 'storage',
            );
          } catch (_) {}
          if (uncertain) {
            await reconcile(operation.id);
          } else {
            _error(error);
          }
        } else {
          _error(error);
        }
      }
    } finally {
      _busy.remove(block);
      _notify();
    }
  }

  Future<void> _record(
    FocusBlockOperation op,
    FocusOperationStatus status,
    int epoch, {
    FocusRemoteBlock? remote,
    String? error,
  }) => _commit((j) {
    j.operations[op.id] = op.state(status, now, error: error);
    if (remote != null) j.blocks[remote.id] = remote;
    if (error == 'deleted') j.blocks.remove(op.eventId);
    if (status == FocusOperationStatus.saved &&
        op.kind == FocusOperationKind.delete) {
      j.blocks.remove(op.eventId);
    }
  }, epoch: epoch);
  Future<void> reconcile(String id) async {
    final epoch = _epoch;
    final op = journal?.operations[id];
    if (op == null) return;
    try {
      final binding = await _binding(epoch);
      if (!_targetMatches(op, binding)) {
        throw const FocusFailure(FocusFailureKind.conflict);
      }
      final remote = await writer.get(binding, op.eventId);
      _guard(epoch);
      if (remote == null || remote.deleted) {
        final knownDeleted =
            remote?.deleted == true ||
            op.error == 'deleted' ||
            op.status == FocusOperationStatus.saved ||
            op.before != null ||
            journal!.blocks.containsKey(op.eventId);
        await _record(
          op,
          op.kind == FocusOperationKind.delete
              ? FocusOperationStatus.saved
              : FocusOperationStatus.needsReview,
          epoch,
          error: knownDeleted ? 'deleted' : 'notFound',
        );
      } else if (!remote.owned(binding)) {
        await _record(
          op,
          FocusOperationStatus.needsReview,
          epoch,
          error: 'foreign',
        );
      } else if (op.kind != FocusOperationKind.delete && remote.matches(op)) {
        await _record(op, FocusOperationStatus.saved, epoch, remote: remote);
      } else {
        await _record(
          op,
          FocusOperationStatus.needsReview,
          epoch,
          remote: remote,
          error: 'remoteChanged',
        );
      }
    } catch (error) {
      if (_current(epoch)) _error(error);
    }
  }

  Future<FocusBlockPreview> retry(String id) async {
    await reconcile(id);
    final epoch = _epoch;
    final op = journal!.operations[id]!;
    final binding = await _binding(epoch, mutation: true);
    if (!_targetMatches(op, binding)) {
      throw const FocusFailure(FocusFailureKind.conflict);
    }
    if (op.credentialGeneration != session.credentialGeneration ||
        !op.payload.start.isAfter(now) ||
        await time.fingerprint() != op.payload.zoneFingerprint) {
      throw const FocusFailure(FocusFailureKind.invalidTime);
    }
    if (op.kind != FocusOperationKind.create || op.error != 'notFound') {
      throw const FocusFailure(FocusFailureKind.conflict);
    }
    final p = FocusBlockPreview(
      focusUuid(),
      FocusBlockDraft(id: op.id, payload: op.payload, taskId: op.taskId),
      op.kind,
      binding,
      op.credentialGeneration,
      operation: op,
    );
    _previews[p.token] = p;
    return p;
  }

  Future<void> verifyTime(FocusPayload payload) async {
    if (!payload.start.isAfter(now) ||
        await time.fingerprint() != payload.zoneFingerprint) {
      throw const FocusFailure(FocusFailureKind.invalidTime);
    }
    for (final endpoint in [
      (payload.start, payload.startOffsetMinutes),
      (payload.end, payload.endOffsetMinutes),
    ]) {
      final wall = endpoint.$1.add(Duration(minutes: endpoint.$2));
      final resolved = await time.resolve(wall);
      if (resolved.utc != endpoint.$1 ||
          resolved.offsetMinutes != endpoint.$2 ||
          resolved.fingerprint != payload.zoneFingerprint) {
        throw const FocusFailure(FocusFailureKind.invalidTime);
      }
    }
  }

  bool _targetMatches(FocusBlockOperation op, FocusCalendarBinding b) =>
      op.target?.id == b.id &&
      op.target?.calendarKey == b.calendarKey &&
      op.target?.provisioningId == b.provisioningId &&
      op.target?.accountKey == b.accountKey &&
      op.target?.clientId == b.clientId;

  Future<List<FocusRemoteBlock>> recover(DateTime start, DateTime end) async {
    final epoch = _epoch;
    final b = await _binding(epoch);
    final blocks = await writer.recover(b, start, end);
    _guard(epoch);
    return blocks.where((r) => r.owned(b)).toList();
  }

  Future<FocusRemoteBlock> freshBlock(String id) async {
    final epoch = _epoch;
    final b = await _binding(epoch);
    final block = await writer.get(b, id);
    _guard(epoch);
    if (block == null || !block.owned(b)) {
      throw const FocusFailure(FocusFailureKind.conflict);
    }
    return block;
  }

  Future<void> adopt(List<FocusRemoteBlock> blocks) async {
    final epoch = _epoch;
    final b = await _binding(epoch);
    final current = <FocusRemoteBlock>[];
    for (final block in blocks) {
      final fresh = await writer.get(b, block.id);
      _guard(epoch);
      if (fresh == null ||
          !fresh.owned(b) ||
          fresh.etag != block.etag ||
          fresh.actualHash != block.actualHash) {
        throw const FocusFailure(FocusFailureKind.precondition);
      }
      current.add(fresh);
    }
    await _commit((j) {
      for (final block in current) {
        j.blocks[block.id] = block;
        for (final entry in j.operations.entries.toList()) {
          if (entry.value.eventId == block.id &&
              entry.value.status == FocusOperationStatus.needsReview) {
            j.operations[entry.key] = entry.value.state(
              FocusOperationStatus.failed,
              now,
              error: 'reviewedCurrent',
            );
          }
        }
      }
    }, epoch: epoch);
  }

  Future<void> stop({bool purge = false}) async {
    ++_epoch;
    _previews.clear();
    writer.cancel();
    _lease = null;
    _initializing = null;
    if (purge) journal = null;
    try {
      await (_stopping = store.stop(purge: purge));
    } catch (error) {
      _error(error);
    }
    _notify();
  }

  Future<void> disable() async {
    _disabled = true;
    final stopping = stop();
    if (store is FocusSchedulingGateStore) {
      try {
        await (store as FocusSchedulingGateStore).setDisabled(true);
      } catch (error) {
        _error(error);
      }
    }
    await stopping;
    _notify();
  }

  Future<void> enable() async {
    if (!session.focusWriteEnabled) {
      throw const FocusFailure(FocusFailureKind.permission);
    }
    await _stopping;
    if (store is FocusSchedulingGateStore) {
      await (store as FocusSchedulingGateStore).setDisabled(false);
    }
    await initialize();
    _disabled = false;
    _notify();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    ++_epoch;
    _previews.clear();
    session.removeListener(_sessionChanged);
    writer.cancel();
    super.dispose();
  }
}
