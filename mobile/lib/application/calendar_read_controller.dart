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
  int _selectionRevision = 0;
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
  int get selectionRevision => _selectionRevision;
  DateTime get now => clock.nowUtc();
  final Map<String, CalendarWindow> _requestedRanges = {};
  final Map<String, String> _watchTokens = {};
  final Map<String, Set<CalendarDate>> _failedCoverage = {};
  final Map<String, DateTime> _rangeAccess = {};
  Iterable<CalendarWindow> get activeRanges => [
    _window,
    ..._requestedRanges.values,
  ];
  int dataRevision = 0;
  final Map<String, Future<void>> _rangeRequests = {};
  Future<void> _rangeWork = Future.value();
  int _rangePending = 0, _mutationRevision = 0;
  bool get rangeLoading => _rangePending > 0;
  final Map<String, CalendarReadFailure> rangeFailures = {};

  void watchRange(String consumer, CalendarWindow range) {
    final token =
        '$_generation/${range.key}/${(selected.toList()..sort()).join(',')}';
    if (_watchTokens[consumer] == token) return;
    _watchTokens[consumer] = token;
    _requestedRanges[consumer] = range;
    unawaited(ensureRange(range, consumer: consumer));
  }

  void releaseRange(String consumer) {
    _requestedRanges.remove(consumer);
    _watchTokens.remove(consumer);
  }

  Iterable<CalendarSnapshot> _sourceRanges(String id) sync* {
    if (snapshots[id] case final snapshot?) yield snapshot;
    yield* _data?.ranges[id]?.values ?? const <CalendarSnapshot>[];
  }

  List<CalendarEvent> eventsFor(CalendarWindow range) {
    final result = <String, CalendarEvent>{};
    final ordered = [
      for (final id in selected)
        for (final snapshot in _sourceRanges(id)) (id, snapshot),
    ]..sort((a, b) => a.$2.succeededAt.compareTo(b.$2.succeededAt));
    for (final (sourceId, snapshot) in ordered) {
      if (snapshot.coverage.startUtc.isBefore(range.endUtc) &&
          snapshot.coverage.endUtc.isAfter(range.startUtc)) {
        _rangeAccess['$sourceId/${snapshot.coverage.key}'] = now;
      }
      result.removeWhere(
        (_, event) =>
            event.calendarId == sourceId && event.overlaps(snapshot.coverage),
      );
      for (final event in snapshot.events.where(
        (e) => e.eligible && e.overlaps(range),
      )) {
        result.removeWhere(
          (_, old) => old.calendarId == event.calendarId && old.id == event.id,
        );
        result[calendarEventIdentity(event)] = event;
      }
    }
    return result.values.toList();
  }

  bool rangeVerified(CalendarWindow range, {bool availability = false}) {
    if (!connection.mayRead ||
        !_catalogVerified ||
        _catalogBlocked ||
        accountKey != connection.verifiedAccountKey ||
        selected.isEmpty ||
        failure != null ||
        saving ||
        loading) {
      return false;
    }
    for (
      var day = range.first;
      day.compareTo(range.until) < 0;
      day = day.plusDays(1)
    ) {
      final part = clock.dayWindow(day);
      for (final id in selected) {
        if (!sourceRangeVerified(id, part, availability: availability)) {
          return false;
        }
      }
    }
    return true;
  }

  bool sourceRangeVerified(
    String id,
    CalendarWindow range, {
    bool availability = false,
  }) {
    if (!connection.mayRead ||
        !_catalogVerified ||
        _catalogBlocked ||
        accountKey != connection.verifiedAccountKey ||
        !selected.contains(id) ||
        !sources.any((source) => source.id == id && source.readable) ||
        failure != null) {
      return false;
    }
    for (
      var day = range.first;
      day.compareTo(range.until) < 0;
      day = day.plusDays(1)
    ) {
      if (_failedCoverage[id]?.contains(day) == true) return false;
      final part = clock.dayWindow(day);
      if (!_sourceRanges(id).any(
        (snapshot) =>
            snapshot.fresh(now, part) &&
            (!availability || snapshot.availabilityKnown),
      )) {
        return false;
      }
    }
    return true;
  }

  void _recordCoverage(
    String source,
    CalendarWindow range, {
    required bool failed,
  }) {
    final dates = _failedCoverage.putIfAbsent(source, () => {});
    for (
      var day = range.first;
      day.compareTo(range.until) < 0;
      day = day.plusDays(1)
    ) {
      if (failed) {
        dates.add(day);
      } else {
        dates.remove(day);
      }
    }
  }

  Future<void> ensureRange(
    CalendarWindow range, {
    bool force = false,
    String? consumer,
  }) {
    if (_disposed || !_started) return Future.value();
    if (DateTime.utc(range.until.year, range.until.month, range.until.day)
            .difference(
              DateTime.utc(
                range.first.year,
                range.first.month,
                range.first.day,
              ),
            )
            .inDays >
        42) {
      return Future.error(
        ArgumentError('A visible range may contain at most 42 dates.'),
      );
    }
    final key = '$_generation/${range.key}';
    if (_rangeRequests[key] case final running?) return running;
    final generation = _generation, mutation = _mutationRevision;
    bool wanted() =>
        _current(generation) &&
        mutation == _mutationRevision &&
        (consumer == null ||
            _requestedRanges.values.any(
              (requested) => requested.key == range.key,
            ));
    final resident = _refreshing;
    _rangePending++;
    final work = _rangeWork.catchError((Object _) {}).then((_) async {
      if (resident != null) await resident;
      await _transition;
      if (!_current(generation) ||
          !connection.mayRead ||
          _lease == null ||
          consumer != null && _requestedRanges[consumer]?.key != range.key) {
        return;
      }
      if (!force && rangeVerified(range)) return;
      for (
        var first = range.first;
        first.compareTo(range.until) < 0;
        first = first.plusDays(7)
      ) {
        final until = first.plusDays(7).compareTo(range.until) > 0
            ? range.until
            : first.plusDays(7);
        final chunk = CalendarWindow(
          first: first,
          until: until,
          startUtc: clock.dayWindow(first).startUtc,
          endUtc: clock.dayWindow(until).startUtc,
        );
        final targets = sources.where((s) => selected.contains(s.id)).toList();
        for (var i = 0; i < targets.length; i += 2) {
          if (!wanted()) return;
          final batch = targets.skip(i).take(2);
          final results = await Future.wait(
            batch.map((source) async {
              try {
                final items = await provider.events(source, chunk);
                return (
                  source.id,
                  CalendarSnapshot(
                    coverage: chunk,
                    succeededAt: now,
                    events: List.unmodifiable(
                      items.where(
                        (event) =>
                            event.calendarId == source.id &&
                            event.eligible &&
                            event.overlaps(chunk),
                      ),
                    ),
                    availabilityKnown: items.every(
                      (event) => event.transparency != null,
                    ),
                  ),
                  null,
                );
              } catch (error) {
                return (source.id, null, _safe(error));
              }
            }),
          );
          if (!wanted()) return;
          final ranges = {
            for (final e in _data!.ranges.entries)
              e.key: Map<String, CalendarSnapshot>.of(e.value),
          };
          for (final result in results) {
            final failureKey = '${result.$1}/${chunk.key}';
            if (result.$2 case final snapshot?) {
              final sourceRanges = ranges.putIfAbsent(result.$1, () => {});
              sourceRanges.removeWhere(
                (key, old) =>
                    key.startsWith('ack/') && chunk.covers(old.coverage),
              );
              sourceRanges[chunk.key] = snapshot;
              _rangeAccess['${result.$1}/${chunk.key}'] = now;
              rangeFailures.remove(failureKey);
              _recordCoverage(result.$1, chunk, failed: false);
            } else {
              rangeFailures[failureKey] = result.$3!;
              _recordCoverage(result.$1, chunk, failed: true);
            }
          }
          _evictRanges(ranges);
          await _save(_data!.copyWith(ranges: ranges), generation);
          _notify();
        }
      }
    });
    final completed = work
        .catchError((Object error) {
          if (_current(generation)) {
            rangeFailures[range.key] = _safe(error);
            for (final source in selected) {
              _recordCoverage(source, range, failed: true);
            }
          }
        })
        .whenComplete(() {
          _rangeRequests.remove(key);
          _rangePending--;
          _notify();
        });
    _rangeRequests[key] = completed;
    _rangeWork = completed;
    return completed;
  }

  void _evictRanges(Map<String, Map<String, CalendarSnapshot>> ranges) {
    for (final (source, values) in ranges.entries.map(
      (entry) => (entry.key, entry.value),
    )) {
      final ordered = values.entries.toList()
        ..sort(
          (a, b) =>
              (_rangeAccess['$source/${b.value.coverage.key}'] ??
                      b.value.succeededAt)
                  .compareTo(
                    _rangeAccess['$source/${a.value.coverage.key}'] ??
                        a.value.succeededAt,
                  ),
        );
      final retainedDays = <CalendarDate>{};
      for (final entry in ordered) {
        final pinned = activeRanges.any(
          (r) =>
              entry.value.coverage.startUtc.isBefore(r.endUtc) &&
              entry.value.coverage.endUtc.isAfter(r.startUtc),
        );
        final dates = <CalendarDate>{};
        for (
          var day = entry.value.coverage.first;
          day.compareTo(entry.value.coverage.until) < 0;
          day = day.plusDays(1)
        ) {
          dates.add(day);
        }
        if (retainedDays.union(dates).length > 84 && !pinned) {
          values.remove(entry.key);
        } else {
          retainedDays.addAll(dates);
        }
      }
    }
  }

  /// A real mutation response can update visible events without proving that
  /// every other event in that interval has been loaded.
  Future<void> acceptMutation(
    String calendarId,
    String eventId, {
    CalendarEvent? event,
    bool series = false,
  }) async {
    _mutationRevision++;
    final generation = _generation;
    await _rangeWork;
    final running = _refreshing;
    if (running != null) await running;
    if (!_current(generation) || _data == null) return;
    CalendarSnapshot update(CalendarSnapshot s) => CalendarSnapshot(
      coverage: s.coverage,
      succeededAt: DateTime.utc(1970),
      availabilityKnown: s.availabilityKnown,
      events: [
        for (final e in s.events)
          if (e.id != eventId && (!series || e.recurringEventId != eventId)) e,
        if (event != null && event.overlaps(s.coverage)) event,
      ],
    );
    final retained = {
      for (final e in snapshots.entries)
        e.key: e.key == calendarId ? update(e.value) : e.value,
    };
    if (event != null &&
        retained[calendarId] == null &&
        event.overlaps(_window)) {
      retained[calendarId] = CalendarSnapshot(
        coverage: _window,
        succeededAt: DateTime.utc(1970),
        events: [event],
      );
    }
    final ranges = {
      for (final e in _data!.ranges.entries)
        e.key: {
          for (final r in e.value.entries)
            r.key: e.key == calendarId ? update(r.value) : r.value,
        },
    };
    if (event != null) {
      final date = event.allDay
          ? event.startDate!
          : CalendarDate(
              event.startUtc!.toLocal().year,
              event.startUtc!.toLocal().month,
              event.startUtc!.toLocal().day,
            );
      final day = clock.dayWindow(date);
      ranges.putIfAbsent(
        calendarId,
        () => {},
      )['ack/$eventId'] = CalendarSnapshot(
        coverage: day,
        succeededAt: DateTime.utc(1970),
        events: [event],
      );
    }
    await _save(
      _data!.copyWith(snapshots: retained, ranges: ranges),
      generation,
    );
    _notify();
  }

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
      for (final range in _requestedRanges.values.toSet()) {
        unawaited(ensureRange(range, force: true));
      }
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
    rangeFailures.clear();
    _failedCoverage.clear();
    _watchTokens.clear();
    _rangeAccess.clear();
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
      dataRevision++;
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
      dataRevision++;
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
    ++_selectionRevision;
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
    if (_rangePending > 0) {
      return _rangeWork.then(
        (_) => _disposed ? Future<void>.value() : refresh(manual: manual),
      );
    }
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

  /// An explicit view action, sharing the existing cache/refresh owner. A later
  /// user selection or account/lifecycle transition supersedes this request.
  /// The predicate also lets the view cancel after manual browsing or lock.
  Future<bool> includeForReveal(
    String expectedAccount,
    String calendarId, {
    required bool Function() current,
  }) async {
    final session = _session;
    var generation = _generation, selection = _selectionRevision;
    bool valid() =>
        current() &&
        !_disposed &&
        session == _session &&
        generation == _generation &&
        selection == _selectionRevision &&
        expectedAccount == accountKey &&
        expectedAccount == connection.verifiedAccountKey &&
        connection.mayRead;
    await _transition;
    if (!valid()) return false;
    final running = _refreshing;
    if (running != null) await running;
    if (!valid()) return false;
    // This fresh pass cannot be absorbed by a pre-action request. It also
    // verifies that the destination is still present before changing selection.
    await refresh(manual: true);
    if (!valid() ||
        failure != null ||
        !canSelect ||
        !sources.any((s) => s.id == calendarId && s.readable)) {
      return false;
    }
    if (!selected.contains(calendarId)) {
      final pending = select({...selected, calendarId});
      generation = _generation;
      selection = _selectionRevision;
      await pending;
    }
    return valid() && selected.contains(calendarId);
  }

  Future<void> _refresh(int generation) async {
    final mutation = _mutationRevision;
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
        if (!_current(generation) || mutation != _mutationRevision) return;
        final snapshot = CalendarSnapshot(
          coverage: _window,
          availabilityKnown: true,
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
          _recordCoverage(source.id, _window, failed: false);
        }
      } catch (error) {
        if (!_current(generation)) return;
        final problem = _safe(error);
        sourceFailures[source.id] = problem;
        _recordCoverage(source.id, _window, failed: true);
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
