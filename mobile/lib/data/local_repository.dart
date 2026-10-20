import 'dart:convert';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';
import '../application/local_repository.dart';
import '../domain/models.dart';
import '../domain/alert_state.dart';
import 'local_storage_policy.dart';
import 'schema_migrations.dart';

class SqliteRepository implements LocalRepository {
  SqliteRepository({
    DatabaseFactory? factory,
    this.databasePath,
    LocalStoragePolicy? storagePolicy,
    this.commitObserver,
  }) : factory = factory ?? databaseFactory,
       storagePolicy = storagePolicy ?? LocalStoragePolicy();
  final DatabaseFactory factory;
  final String? databasePath;
  final LocalStoragePolicy storagePolicy;

  /// Optional fault-injection seam; production never supplies a callback.
  final Future<void> Function(String stage)? commitObserver;
  Database? _database;
  Future<Database>? _opening;
  Future<void>? _closing;

  Future<Database> _open() {
    if (_closing != null) return _closing!.then((_) => _open());
    if (_database != null) return Future.value(_database!);
    return _opening ??= _openOnce().whenComplete(() {
      _opening = null;
    });
  }

  Future<Database> _openOnce() async {
    final location =
        databasePath ?? path.join(await factory.getDatabasesPath(), 'poma.db');
    await storagePolicy.prepareDirectory(path.dirname(location));
    final database = await _guard(
      () => factory.openDatabase(
        location,
        options: OpenDatabaseOptions(
          version: 3,
          onConfigure: (db) async {
            await _guard(
              () => db.execute('PRAGMA synchronous = FULL'),
              StorageFailureKind.unreadable,
            );
          },
          onCreate: (db, version) => migrateSchema(db, 0, version),
          onUpgrade: migrateSchema,
          onDowngrade: (db, oldVersion, newVersion) async {
            throw const StorageFailure(StorageFailureKind.migration);
          },
        ),
      ),
      StorageFailureKind.unreadable,
    );
    _database = database;
    return database;
  }

  Future<T> _guard<T>(
    Future<T> Function() action,
    StorageFailureKind fallback,
  ) async {
    try {
      return await action();
    } on StorageFailure {
      rethrow;
    } on LocalStoragePreparationException {
      rethrow;
    } catch (error) {
      // Never retain or print DatabaseException: it can contain SQL arguments.
      final full =
          error is DatabaseException &&
          ((error.getResultCode() ?? 0) & 255) == 13;
      throw StorageFailure(full ? StorageFailureKind.full : fallback);
    }
  }

  @override
  Future<String?> notificationDatabasePath() async => (await _open()).path;

  @override
  Future<bool> recordAlertReceipt(String key) => _guard(() async {
    final db = await _open();
    return db.transaction((txn) async {
      await txn.insert('notification_receipts', {
        'key': key,
        'created_at': DateTime.now().toUtc().millisecondsSinceEpoch,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
      return (await txn.rawQuery('SELECT changes() AS n')).single['n'] == 1;
    });
  }, StorageFailureKind.write);

  @override
  Future<SavedState> loadInitial() => _guard(() async {
    final db = await _open();
    return db.transaction((txn) async {
      final state = {
        for (final row in await txn.query('app_state'))
          row['key'] as String: row['value'] as String,
      };
      final alerts = await txn.query('notification_state', where: 'id = 1');
      final meta = (await txn.query('storage_meta')).single;
      if (meta['revision'] is! int ||
          (meta['revision'] as int) < 0 ||
          ![0, 1].contains(meta['cleanup_pending'])) {
        throw const StorageFailure(StorageFailureKind.unreadable);
      }
      return SavedState(
        settings: state['settings'] == null
            ? const TimerSettings()
            : TimerSettings.fromJson(storedObject(state['settings']!)),
        timer: state['timer'] == null
            ? null
            : TimerSnapshot.fromJson(storedObject(state['timer']!)),
        selectedTaskId: state['selectedTaskId'],
        tasks: (await txn.query(
          'tasks',
          orderBy: 'position ASC, id ASC',
        )).map(FocusTask.fromRow).toList(),
        alerts: alerts.isEmpty
            ? const AlertState()
            : AlertState.fromJson(
                storedObject(alerts.single['value'] as String),
              ),
        revision: meta['revision'] as int,
        lastCommitId: meta['commit_id'] as String?,
        cleanupPending: meta['cleanup_pending'] == 1,
      );
    });
  }, StorageFailureKind.unreadable);

  @override
  Future<int> commit(LocalCommit request) => _guard(() async {
    final db = await _open();
    final result = await db.transaction((txn) async {
      final meta = (await txn.query('storage_meta')).single;
      final revision = meta['revision'] as int;
      if (meta['commit_id'] == request.id &&
          (revision == request.expectedRevision + 1 ||
              (request.supersedesId != null &&
                  revision == request.expectedRevision + 2))) {
        return revision;
      }
      final superseded =
          request.supersedesId != null &&
          meta['commit_id'] == request.supersedesId &&
          revision == request.expectedRevision + 1;
      if ((!superseded && revision != request.expectedRevision) ||
          request.id.isEmpty ||
          request.changes.isEmpty) {
        throw const StorageFailure(StorageFailureKind.conflict);
      }
      for (final change in request.changes) {
        if (change.reset) {
          await txn.delete('tasks');
          await txn.delete('sessions');
          await txn.delete('app_state');
          await txn.delete('notification_receipts');
        } else if (change.clearHistory) {
          await txn.delete('sessions');
        }
        for (final id in change.deletedSessions) {
          await txn.delete('sessions', where: 'id = ?', whereArgs: [id]);
        }
        for (final id in change.deletedTasks) {
          await txn.delete('tasks', where: 'id = ?', whereArgs: [id]);
        }
        for (final task in change.tasks) {
          final existing = await txn.query(
            'tasks',
            columns: ['position'],
            where: 'id = ?',
            whereArgs: [task.id],
          );
          if (existing.isEmpty) {
            final position =
                ((await txn.rawQuery(
                          'SELECT MAX(position) AS p FROM tasks',
                        )).single['p']
                        as int? ??
                    -1) +
                1;
            FocusTask.fromRow(task.toRow(position));
            await txn.insert('tasks', task.toRow(position));
          } else {
            FocusTask.fromRow(task.toRow(existing.single['position'] as int));
            await txn.update(
              'tasks',
              {'title': task.title, 'done': task.done ? 1 : 0},
              where: 'id = ?',
              whereArgs: [task.id],
            );
          }
        }
        for (final session in change.completions) {
          final values = session.toRow();
          FocusSession.fromRow(values);
          final existing = await txn.query(
            'sessions',
            where: 'id = ?',
            whereArgs: [session.id],
          );
          if (existing.isNotEmpty) {
            final original = FocusSession.fromRow(existing.single).toRow();
            if (values.keys.any((key) => values[key] != original[key])) {
              throw const StorageFailure(StorageFailureKind.conflict);
            }
          } else {
            await txn.insert('sessions', {
              ...values,
              'ended_at_utc_micros': session.endedAt.microsecondsSinceEpoch,
            });
          }
        }
        final state = change.state;
        TimerSettings.fromJson(state.settings.toJson());
        state.timer?.validate();
        final values = {
          'settings': jsonEncode(state.settings.toJson()),
          'timer': state.timer == null
              ? null
              : jsonEncode(state.timer!.toJson()),
          'selectedTaskId': state.selectedTaskId,
        };
        for (final entry in values.entries) {
          if (entry.value == null) {
            await txn.delete(
              'app_state',
              where: 'key = ?',
              whereArgs: [entry.key],
            );
          } else {
            final previous = await txn.query(
              'app_state',
              where: 'key = ?',
              whereArgs: [entry.key],
            );
            if (previous.isEmpty || previous.single['value'] != entry.value) {
              await txn.insert('app_state', {
                'key': entry.key,
                'value': entry.value,
              }, conflictAlgorithm: ConflictAlgorithm.replace);
            }
          }
        }
        final alertValue = jsonEncode(state.alerts.toJson());
        final oldAlerts = await txn.query(
          'notification_state',
          where: 'id = 1',
        );
        if (oldAlerts.isEmpty || oldAlerts.single['value'] != alertValue) {
          await txn.insert('notification_state', {
            'id': 1,
            'value': alertValue,
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
        await txn.update('storage_meta', {
          'cleanup_pending': state.cleanupPending ? 1 : 0,
        }, where: 'id = 1');
      }
      await txn.update('storage_meta', {
        'revision': revision + 1,
        'commit_id': request.id,
      }, where: 'id = 1');
      await commitObserver?.call('beforeCommit');
      return revision + 1;
    });
    await commitObserver?.call('afterCommit');
    return result;
  }, StorageFailureKind.write);

  @override
  Future<HistoryPage> readHistoryPage({
    HistoryCursor? before,
    HistoryCursor? after,
  }) => _guard(() async {
    if (before != null && after != null) {
      throw ArgumentError('One cursor required.');
    }
    final cursor = before ?? after;
    final newer = after != null;
    final db = await _open();
    return db.transaction((txn) async {
      Future<List<Map<String, Object?>>> seek(
        HistoryCursor key,
        bool forward,
        int limit,
      ) {
        final comparison = forward ? '>' : '<';
        final direction = forward ? 'ASC' : 'DESC';
        // Two index seeks bound work even with identical timestamps, without
        // requiring newer SQLite tuple-comparison syntax on Android API 24.
        return txn.rawQuery(
          'SELECT * FROM sessions WHERE ended_at_utc_micros = ? AND id $comparison ? UNION ALL SELECT * FROM sessions WHERE ended_at_utc_micros $comparison ? ORDER BY ended_at_utc_micros $direction,id $direction LIMIT $limit',
          [key.endedMicros, key.id, key.endedMicros],
        );
      }

      final rows = cursor == null
          ? await txn.query(
              'sessions',
              orderBy: 'ended_at_utc_micros DESC,id DESC',
              limit: 51,
            )
          : await seek(cursor, newer, 51);
      var sessions = rows.take(50).map((row) {
        final session = FocusSession.fromRow(row);
        if (session.endedAt.microsecondsSinceEpoch !=
            row['ended_at_utc_micros']) {
          throw const StorageFailure(StorageFailureKind.unreadable);
        }
        return session;
      }).toList();
      if (newer) sessions = sessions.reversed.toList();
      Future<bool> exists(FocusSession session, String operator) async =>
          (await seek(
            HistoryCursor.forSession(session),
            operator == '>',
            1,
          )).isNotEmpty;
      return HistoryPage(
        List.unmodifiable(sessions),
        hasOlder: sessions.isNotEmpty && await exists(sessions.last, '<'),
        hasNewer: sessions.isNotEmpty && await exists(sessions.first, '>'),
      );
    });
  }, StorageFailureKind.unreadable);

  @override
  Future<List<DaySummary>> readDaySummaries(
    List<DayRange> days,
  ) => _guard(() async {
    if (days.length > 7) throw ArgumentError('At most seven days.');
    final db = await _open();
    return db.transaction((txn) async {
      final result = <DaySummary>[];
      for (final day in days) {
        if (!day.endUtc.isAfter(day.startUtc)) {
          throw ArgumentError('Invalid day range.');
        }
        final row = (await txn.rawQuery(
          'SELECT COUNT(*) AS n, COALESCE(SUM(focus_seconds),0) AS seconds FROM sessions WHERE ended_at_utc_micros >= ? AND ended_at_utc_micros < ?',
          [
            day.startUtc.microsecondsSinceEpoch,
            day.endUtc.microsecondsSinceEpoch,
          ],
        )).single;
        result.add(
          DaySummary(day.date, row['n'] as int, row['seconds'] as int),
        );
      }
      return result;
    });
  }, StorageFailureKind.unreadable);

  @override
  Future<void> close() async {
    if (_closing != null) return _closing;
    final operation = () async {
      try {
        await _opening;
      } catch (_) {
        /* Already sanitized at the caller. */
      }
      await _database?.close();
      _database = null;
    }();
    _closing = operation;
    try {
      await operation;
    } finally {
      _closing = null;
    }
  }
}
