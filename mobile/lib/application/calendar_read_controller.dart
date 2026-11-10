import 'dart:async';
import 'package:flutter/foundation.dart';
import '../domain/calendar_data.dart';
import 'calendar_connection_controller.dart';
import 'calendar_read_ports.dart';

/// Calendar-only state and persistence. Never enters the Pomodoro command queue.
class CalendarReadController extends ChangeNotifier {
  CalendarReadController({
    required this.connection,
    required this.provider,
    required this.cache,
    required this.clock,
    required this.scheduler,
  });
  final CalendarConnectionController connection;
  final CalendarReadProvider provider;
  final CalendarCacheStore cache;
  final CalendarClock clock;
  final CalendarScheduler scheduler;
  CalendarAccountData? _data;
  CalendarCacheLease? _lease;
  late CalendarWindow _window;
  CalendarScheduledJob? _cadence, _midnight, _ageUpdate;
  bool _disposed = false, _started = false, _catalogVerified = false;
  bool _catalogBlocked = false;
  int _generation = 0;
  String? _session;
  Future<void>? _refreshing;
  Future<void> _transition = Future.value();
  bool loading = false, saving = false;
  CalendarReadFailure? failure;
  CalendarReadFailure? paletteFailure;
  CalendarEventPalette? get palette => _data?.palette;
  final Map<String, CalendarReadFailure> sourceFailures = {};
  final Set<String> _blockedSources = {};
  List<CalendarSource> get sources => _data?.sources ?? const [];
  Set<String> get selected => _data?.selected ?? const {};
  Map<String, CalendarSnapshot> get snapshots => _data?.snapshots ?? const {};
  CalendarWindow get window => _window;
  String? get accountKey => _data?.accountKey;

  /// Shared capability; consumers must never bind a second cache scope.
  CalendarCacheLease? get activeLease => _lease;
  int get scopeGeneration => _generation;
  DateTime get now => clock.nowUtc();
  bool get refreshing => _refreshing != null;
  bool get canSelect =>
      _data != null &&
      _catalogVerified &&
      !loading &&
      !saving &&
      connection.mayRead;
  List<CalendarEvent> get events => List.unmodifiable(
    snapshots.values
        .expand((s) => s.events)
        .where((e) => e.eligible && e.overlaps(_window)),
  );
  bool _current(int generation) => !_disposed && generation == _generation;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  CalendarReadFailure _safe(Object error) => error is CalendarReadFailure
      ? error
      : const CalendarReadFailure(CalendarReadFailureKind.storage);

  void initialize() {
    if (_started || _disposed) return;
    _started = true;
    _window = clock.window();
    connection.addListener(_connectionChanged);
    _connectionChanged();
    _scheduleCadence();
    _scheduleMidnight();
    _scheduleAge();
  }

  void _scheduleCadence() {
    _cadence = scheduler.after(const Duration(minutes: 5), () {
      if (_disposed) return;
      unawaited(refresh());
      _scheduleCadence();
    });
  }

  void _scheduleAge() {
    _ageUpdate = scheduler.after(const Duration(minutes: 1), () {
      if (_disposed) return;
      _notify(); // Presentation only; never network or storage.
      _scheduleAge();
    });
  }

  void _scheduleMidnight() {
    _midnight?.cancel();
    final next = clock.nextMidnightUtc();
    _midnight = scheduler.after(next.difference(now), () {
      if (!_disposed) unawaited(lifecycleChanged());
    });
  }

  int _invalidate() {
    ++_generation;
    provider.cancel();
    _refreshing = null;
    _lease = null;
    return _generation;
  }

  void _connectionChanged() {
    if (!_started || _disposed) return;
    final key = connection.verifiedAccountKey;
    final signature =
        '$key/${connection.sessionGeneration}/${connection.storageRevision}/${connection.mayRead}';
    if (_session == signature) return;
    _session = signature;
    final generation = _invalidate();
    _catalogVerified = false;
    _catalogBlocked = false;
    _blockedSources.clear();
    sourceFailures.clear();
    paletteFailure = null;
    failure = null;
    saving = false;
    loading = key != null;
    if (_data?.accountKey != key) _data = null;
    // Scope invalidation is dispatched immediately, before waiting for disk work.
    final invalidation = cache.invalidate();
    _transition = _activate(generation, key, invalidation);
    _notify();
  }

  Future<void> _activate(
    int generation,
    String? key,
    Future<void> invalidation,
  ) async {
    try {
      await invalidation;
      if (!_current(generation) || key == null) return;
      final lease = await cache.open(connection.storageRevision, key);
      if (!_current(generation)) return;
      final existing =
          _data ??
          await cache.read(lease) ??
          CalendarAccountData(accountKey: key);
      if (!_current(generation)) return;
      final data = existing.trim(_window);
      _data = data;
      // Startup trimming also overwrites an abandoned atomic-write temporary.
      await cache.write(lease, data);
      if (!_current(generation)) return;
      _lease = lease;
      _data = data;
      failure = null;
    } catch (error) {
      if (_current(generation)) failure = _safe(error);
    } finally {
      if (_current(generation)) {
        loading = false;
        _notify();
      }
    }
    if (_current(generation) && connection.mayRead && _lease != null) {
      unawaited(refresh());
    }
  }

  Future<bool> _save(CalendarAccountData data, int generation) async {
    final lease = _lease;
    if (!_current(generation) || lease == null) return false;
    try {
      await cache.write(lease, data);
      if (!_current(generation)) return false;
      _data = data;
      return true;
    } catch (error) {
      if (_current(generation)) failure = _safe(error);
      return false;
    }
  }

  Future<void> select(Set<String> ids) async {
    if (!canSelect ||
        ids.any((id) => !sources.any((s) => s.id == id && s.readable))) {
      return;
    }
    final data = _data!.copyWith(
      selected: ids,
      snapshots: {
        for (final entry in snapshots.entries)
          if (ids.contains(entry.key)) entry.key: entry.value,
      },
    );
    final generation = _invalidate();
    saving = true;
    failure = null;
    sourceFailures.clear();
    _blockedSources.clear();
    _notify();
    _transition = () async {
      try {
        final lease = await cache.open(
          connection.storageRevision,
          data.accountKey,
        );
        if (!_current(generation)) return;
        _lease = lease;
        await _save(data.trim(_window), generation);
      } catch (error) {
        if (_current(generation)) failure = _safe(error);
      } finally {
        if (_current(generation)) {
          saving = false;
          _notify();
        }
      }
    }();
    await _transition;
    if (_current(generation) && failure == null) await refresh();
  }

  Future<void> opened() async {
    await lifecycleChanged(refreshAlways: false);
  }

  Future<void> retry() async {
    if (_lease == null) {
      _session = null;
      _connectionChanged();
      await _transition;
    } else {
      await refresh(manual: true);
    }
  }

  Future<void> lifecycleChanged({bool refreshAlways = true}) async {
    if (!_started || _disposed) return;
    final next = clock.window();
    if (next.key != _window.key) {
      _window = next;
      final generation = _invalidate();
      _data = _data?.trim(
        next,
      ); // Hide expired entries immediately, including offline.
      _catalogVerified = false;
      final invalidation = cache.invalidate();
      _transition = _activate(
        generation,
        connection.verifiedAccountKey,
        invalidation,
      );
    }
    _scheduleMidnight();
    await _transition;
    if (refreshAlways ||
        !_catalogVerified ||
        selected.any((id) => snapshots[id]?.fresh(now, _window) != true)) {
      await refresh();
    }
  }

  Future<void> refresh({bool manual = false}) {
    if (_disposed ||
        !_started ||
        saving ||
        loading ||
        !connection.mayRead ||
        _lease == null) {
      return Future.value();
    }
    if (_refreshing != null) return _refreshing!;
    if (manual) {
      _blockedSources.clear();
      _catalogBlocked = false;
    }
    if (_catalogBlocked) return Future.value();
    final generation = _generation;
    final result = _refresh(generation);
    _refreshing = result;
    _notify();
    unawaited(
      result.whenComplete(() {
        if (_current(generation) && identical(_refreshing, result)) {
          _refreshing = null;
          _notify();
        }
      }),
    );
    return result;
  }

  /// A pre-insert refresh must not absorb the refresh that confirms creation.
  Future<void> refreshAfterCreation() async {
    final running = _refreshing;
    if (running != null) await running;
    await refresh(manual: true);
  }

  Future<void> _refresh(int generation) async {
    failure = null;
    try {
      final catalog = await provider.calendars();
      if (!_current(generation)) return;
      final permitted = catalog
          .where((s) => s.readable)
          .map((s) => s.id)
          .toSet();
      final retained = selected.intersection(permitted);
      final data = _data!
          .copyWith(
            sources: catalog,
            selected: retained,
            snapshots: {
              for (final entry in snapshots.entries)
                if (retained.contains(entry.key)) entry.key: entry.value,
            },
          )
          .trim(_window);
      if (!await _save(data, generation)) return;
      _catalogVerified = true;
      sourceFailures.removeWhere((id, _) => !retained.contains(id));
      _blockedSources.removeWhere((id) => !retained.contains(id));
      _notify();
    } catch (error) {
      if (_current(generation)) {
        failure = _safe(error);
        _catalogBlocked =
            failure!.kind == CalendarReadFailureKind.forbidden ||
            failure!.kind == CalendarReadFailureKind.authorization;
        _notify();
      }
      // A failed catalog pass cannot remove sources or prove account access.
      if (_catalogBlocked || !_catalogVerified) return;
    }
    if (!_current(generation)) return;
    for (final source
        in sources.where((s) => selected.contains(s.id)).toList()) {
      if (!_current(generation)) return;
      if (_blockedSources.contains(source.id)) continue;
      try {
        final items = await provider.events(source, _window);
        if (!_current(generation)) return;
        final snapshot = CalendarSnapshot(
          coverage: _window,
          succeededAt: now,
          events: List.unmodifiable(
            items.where(
              (e) =>
                  e.calendarId == source.id &&
                  e.eligible &&
                  e.overlaps(_window),
            ),
          ),
        );
        if (!await _save(
          _data!.copyWith(snapshots: {...snapshots, source.id: snapshot}),
          generation,
        )) {
          if (_current(generation)) {
            sourceFailures[source.id] = const CalendarReadFailure(
              CalendarReadFailureKind.storage,
            );
          }
        } else {
          sourceFailures.remove(source.id);
        }
      } catch (error) {
        if (!_current(generation)) return;
        final problem = _safe(error);
        sourceFailures[source.id] = problem;
        if (problem.kind == CalendarReadFailureKind.forbidden) {
          _blockedSources.add(source.id);
        }
        if (problem.kind == CalendarReadFailureKind.authorization ||
            problem.kind == CalendarReadFailureKind.throttled) {
          break;
        }
      }
      _notify();
    }
    // Palette refresh shares the reader's cadence and cancellation/account scope.
    // Its failure never removes retained events or turns an event fetch into a
    // failed snapshot. There is no palette timer or presentation-tick I/O.
    final paletteProvider = provider;
    final fetched = palette?.fetchedAt;
    if (_current(generation) &&
        paletteProvider is CalendarPaletteProvider &&
        (fetched == null ||
            fetched.isAfter(now) ||
            now.difference(fetched) >= const Duration(days: 1) ||
            paletteFailure != null)) {
      try {
        final next = await (paletteProvider as CalendarPaletteProvider)
            .eventPalette();
        if (!_current(generation)) return;
        if (await _save(_data!.copyWith(palette: next), generation)) {
          paletteFailure = null;
        }
      } catch (error) {
        if (_current(generation)) paletteFailure = _safe(error);
      }
      if (_current(generation)) _notify();
    }
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    ++_generation;
    _cadence?.cancel();
    _midnight?.cancel();
    _ageUpdate?.cancel();
    connection.removeListener(_connectionChanged);
    provider.dispose();
    unawaited(cache.invalidate().catchError((Object _) {}));
    super.dispose();
  }
}
