import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import '../domain/calendar_data.dart';
import '../domain/calendar_reminders.dart';
import 'calendar_read_controller.dart';
import 'calendar_read_ports.dart';
import 'calendar_reminder_ports.dart';

class _Reminder {
  const _Reminder(this.key, this.event, this.deadline);
  final String key;
  final CalendarEvent event;
  final DateTime deadline;
}

/// Independent, serialized calendar effects. Never owns or commands a timer.
class CalendarReminderController extends ChangeNotifier {
  CalendarReminderController({
    required this.reader,
    required this.store,
    required this.platform,
    required this.openAgenda,
  }) {
    reader.addListener(_changed);
    reader.connection.addListener(_changed);
    _changed();
  }
  final CalendarReadController reader;
  final CalendarReminderStore store;
  final CalendarReminderPlatform platform;
  final Future<void> Function() openAgenda;
  final String _nonce = List.generate(
    24,
    (_) => Random.secure().nextInt(256),
  ).join('-');
  CalendarReminderPreferences preferences = const CalendarReminderPreferences();
  String availability = 'disabled';
  String? error;
  bool saving = false, _disposed = false, _suspended = false;
  bool _pendingSave = false;
  bool unlocked = false;
  int _generation = 0;
  String? _account, _loadedLease, _signature;
  CalendarCacheLease? _lease;
  final Map<String, int> _attempts = {};
  final Set<String> _actions = {};
  final Map<String, _Reminder> _tokens = {};
  DateTime? _armed;
  Future<void> _work = Future.value();
  Future<void> get settled => _work;

  String _digest(Object value) =>
      sha256.convert(utf8.encode(jsonEncode(value))).toString();
  String? get _leaseKey {
    final lease = reader.activeLease;
    return lease == null
        ? null
        : '${lease.accountKey}/${lease.revision}/${lease.scope}';
  }

  List<_Reminder> get _eligible {
    if (_disposed ||
        _suspended ||
        !preferences.enabled ||
        saving ||
        error != null ||
        reader.saving ||
        reader.loading ||
        !reader.connection.mayRead ||
        reader.accountKey != reader.connection.verifiedAccountKey ||
        reader.failure != null) {
      return [];
    }
    final now = reader.now;
    return reader.events
        .where(
          (e) =>
              !e.allDay &&
              e.eligible &&
              reader.selected.contains(e.calendarId) &&
              preferences.calendars.contains(e.calendarId) &&
              e.startUtc!.isAfter(now) &&
              reader.sourceFailures[e.calendarId] == null &&
              reader.snapshots[e.calendarId]?.fresh(now, reader.window) == true,
        )
        .map(
          (e) => _Reminder(
            _digest([
              reader.accountKey,
              e.calendarId,
              e.id,
              e.recurringEventId,
              e.originalStart,
              e.startUtc!.microsecondsSinceEpoch,
            ]),
            e,
            e.startUtc!.subtract(Duration(minutes: preferences.leadMinutes)),
          ),
        )
        .toList()
      ..sort((a, b) {
        final d = a.deadline.compareTo(b.deadline);
        return d == 0 ? a.key.compareTo(b.key) : d;
      });
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> _enqueue(Future<void> Function() action) {
    final generation = _generation;
    final next = _work.then((_) async {
      if (!_disposed) await action();
    });
    _work = next.catchError((Object _) {
      if (_disposed || generation != _generation) return;
      error =
          'Calendar reminders could not be saved or updated. Retry; your timer is kept.';
      availability = 'failed';
      saving = false;
      _armed = null;
      _tokens.clear();
      unawaited(platform.replace(++_generation, {}).catchError((Object _) {}));
      _notify();
    });
    return _work;
  }

  void _changed() {
    if (_disposed) return;
    if (_account != null && reader.accountKey != _account) {
      preferences = const CalendarReminderPreferences();
      _attempts.clear();
      _actions.clear();
      _account = null;
      _loadedLease = null;
      _lease = null;
      _pendingSave = false;
      saving = false;
      error = null;
    }
    final candidates = _eligible;
    final signature = jsonEncode([
      _leaseKey,
      reader.accountKey,
      reader.connection.sessionGeneration,
      reader.scopeGeneration,
      reader.saving,
      reader.loading,
      preferences.toJson(),
      saving,
      error,
      _suspended,
      candidates
          .map((e) => [e.key, e.deadline.microsecondsSinceEpoch])
          .toList(),
    ]);
    if (_signature == signature) return;
    _signature = signature;
    if (!preferences.enabled) availability = 'disabled';
    final generation = ++_generation;
    _actions.clear(); // Prior resident-generation tokens are already invalid.
    _armed = null;
    _tokens.clear();
    // Revoke immediately, before queued disk work, including selection/disconnect.
    final revoked = platform
        .replace(generation, {})
        .then<Object?>((_) => null, onError: (Object failure) => failure);
    unawaited(
      _enqueue(() async {
        final revokeFailure = await revoked;
        if (revokeFailure != null) throw revokeFailure;
        if (generation != _generation) return;
        final lease = reader.activeLease;
        if (lease == null || reader.saving || reader.loading) {
          _notify();
          return;
        }
        if (_loadedLease != _leaseKey) {
          final document = await store.read(lease);
          if (generation != _generation) return;
          if (_account != lease.accountKey) {
            preferences = const CalendarReminderPreferences();
            _attempts.clear();
            _actions.clear();
          }
          _account = lease.accountKey;
          if (document != null) {
            if (document['version'] != 1 ||
                document['accountKey'] != _account) {
              throw const FormatException('Invalid reminder document.');
            }
            preferences = CalendarReminderPreferences.fromJson(
              document['preferences'] as Map,
            );
            _attempts
              ..clear()
              ..addAll(Map<String, int>.from(document['attempts'] as Map));
            _actions
              ..clear()
              ..addAll(Set<String>.from(document['actions'] as List));
            if (_attempts.length > 4096 || _actions.length > 8192) {
              throw const FormatException('Reminder limit.');
            }
          }
          _lease = lease;
          _loadedLease = _leaseKey;
          _signature = null;
          _changed();
          return;
        }
        _lease = lease;
        final included = preferences.calendars.intersection(reader.selected);
        if (!setEquals(included, preferences.calendars)) {
          preferences = preferences.copyWith(calendars: included);
          await _save(lease);
          if (generation != _generation) return;
        }
        availability = error != null
            ? 'failed'
            : preferences.enabled
            ? await platform.availability()
            : 'disabled';
        if (generation != _generation) return;
        await _schedule(generation);
        _notify();
      }),
    );
  }

  Future<void> _save(CalendarCacheLease lease) async {
    _attempts.removeWhere(
      (_, start) => start < reader.window.startUtc.microsecondsSinceEpoch,
    );
    if (_attempts.length > 4096 || _actions.length > 8192) {
      throw const FormatException('Reminder limit.');
    }
    final savedPreferences = jsonEncode(preferences.toJson());
    _pendingSave = true;
    await store.write(lease, {
      'version': 1,
      'accountKey': lease.accountKey,
      'preferences': preferences.toJson(),
      'attempts': Map.of(_attempts),
      'actions': _actions.toList(),
    });
    if (_account == lease.accountKey &&
        savedPreferences == jsonEncode(preferences.toJson())) {
      _pendingSave = false;
    }
  }

  Future<void> update(CalendarReminderPreferences next) async {
    if (_disposed ||
        _lease == null ||
        reader.saving ||
        !CalendarReminderPreferences.leads.contains(next.leadMinutes)) {
      return;
    }
    preferences = next.copyWith(
      calendars: next.calendars.intersection(reader.selected),
    );
    final account = _account;
    _pendingSave = true;
    saving = true;
    error = null;
    _signature = null;
    _changed();
    _notify();
    await _enqueue(() async {
      final lease = reader.activeLease;
      if (lease == null || lease.accountKey != account || _account != account) {
        return;
      }
      await _save(lease);
      saving = false;
      _signature = null;
      _changed();
      _notify();
    });
  }

  Future<void> retry() async {
    if (_pendingSave &&
        _lease != null &&
        reader.activeLease?.accountKey == _account) {
      await update(preferences);
      return;
    }
    error = null;
    saving = false;
    _loadedLease = null;
    _signature = null;
    _changed();
    await settled;
  }

  void lifecycle({bool suspended = false}) {
    _suspended = suspended;
    _signature = null;
    _changed(); // Future deadlines only; never catch up.
  }

  Future<void> _schedule(int generation) async {
    if (generation != _generation || _disposed) return;
    _tokens.clear();
    if (availability == 'ready') {
      for (final item in _eligible) {
        _tokens[_digest([_nonce, generation, item.key])] = item;
      }
    }
    await platform.replace(generation, _tokens.keys.toSet());
    if (generation != _generation || _disposed) return;
    final now = reader.now;
    final future = _tokens.values.where(
      (e) => !_attempts.containsKey(e.key) && e.deadline.isAfter(now),
    );
    _armed = future.firstOrNull?.deadline;
    await platform.arm(generation, _armed);
  }

  Future<void> deadline(int generation) => _enqueue(() async {
    final armed = _armed;
    _armed = null;
    if (generation != _generation || armed == null || _suspended) return;
    final now = reader.now;
    if (now.isBefore(armed)) {
      await _schedule(generation);
      return;
    }
    // Ordinary message-loop jitter is tolerated; lifecycle catch-up never is.
    final due = now.difference(armed) > const Duration(seconds: 30)
        ? <_Reminder>[]
        : _eligible
              .where(
                (e) => e.deadline == armed && !_attempts.containsKey(e.key),
              )
              .toList();
    for (final item in due) {
      final lease = _lease;
      if (generation != _generation || lease == null) return;
      final token = _digest([_nonce, generation, item.key]);
      _attempts[item.key] = item.event.startUtc!.microsecondsSinceEpoch;
      await _save(lease); // An interrupted attempt may be lost, never replayed.
      if (generation != _generation ||
          !_eligible.any((e) => e.key == item.key)) {
        return;
      }
      await platform.show(generation, token, item.event.startUtc!);
    }
    await _schedule(generation);
    _notify();
  });
  Future<void> handleResponses() => _enqueue(() async {
    for (final response in await platform.responses()) {
      final token = response['token'], action = response['action'];
      if (token is! String || action is! String) continue;
      final item = _tokens[token];
      final generation = _generation;
      final receipt = '$token:$action';
      final valid =
          response['generation'] == generation &&
          item != null &&
          _attempts.containsKey(item.key) &&
          _eligible.any((e) => e.key == item.key) &&
          unlocked &&
          const ['open', 'dismiss'].contains(action) &&
          !_actions.contains(receipt);
      if (valid && _lease != null) {
        _actions.add(receipt);
        await _save(_lease!);
        if (generation == _generation && unlocked && action == 'open') {
          await openAgenda();
        }
      }
      await platform.acknowledge(token, action);
    }
  });
  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    ++_generation;
    reader.removeListener(_changed);
    reader.connection.removeListener(_changed);
    _tokens.clear();
    unawaited(platform.replace(_generation, {}).catchError((Object _) {}));
    super.dispose();
  }
}
