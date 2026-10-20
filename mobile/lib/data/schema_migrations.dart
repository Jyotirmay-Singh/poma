import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../application/local_repository.dart';
import '../domain/models.dart';
import '../domain/alert_state.dart';

Map<String, dynamic> storedObject(String value) =>
    jsonDecode(value) as Map<String, dynamic>;

Future<void> validateLegacyState(DatabaseExecutor db) async {
  for (final row in await db.query('app_state')) {
    switch (row['key']) {
      case 'timer':
        TimerSnapshot.fromJson(storedObject(row['value'] as String));
      case 'settings':
        TimerSettings.fromJson(storedObject(row['value'] as String));
      case 'selectedTaskId':
        if (row['value'] is! String ||
            (row['value'] as String).trim().isEmpty) {
          throw const FormatException('Invalid selection.');
        }
    }
  }
  String? cursor;
  while (true) {
    final rows = await db.query(
      'tasks',
      where: cursor == null ? null : 'id > ?',
      whereArgs: cursor == null ? null : [cursor],
      orderBy: 'id',
      limit: 250,
    );
    for (final row in rows) {
      FocusTask.fromRow(row);
    }
    if (rows.length < 250) break;
    cursor = rows.last['id'] as String;
  }
}

/// sqflite wraps onCreate/onUpgrade in a transaction, including user_version.
/// Sanitize inside this callback: sqflite may print an open failure itself.
Future<void> migrateSchema(Database db, int from, int to) async {
  try {
    if (from > 0) await validateLegacyState(db);
    for (var version = from + 1; version <= to; version++) {
      switch (version) {
        case 1:
          await db.execute(
            'CREATE TABLE app_state (key TEXT PRIMARY KEY, value TEXT NOT NULL)',
          );
          await db.execute(
            'CREATE TABLE tasks (id TEXT PRIMARY KEY, title TEXT NOT NULL, done INTEGER NOT NULL, position INTEGER NOT NULL)',
          );
          await db.execute(
            'CREATE TABLE sessions (id TEXT PRIMARY KEY, started_at TEXT NOT NULL, ended_at TEXT NOT NULL, focus_seconds INTEGER NOT NULL, task_id TEXT, task_title TEXT)',
          );
          await db.execute(
            'CREATE INDEX sessions_ended_at ON sessions(ended_at)',
          );
        case 2:
          await db.execute(
            'CREATE TABLE notification_state (id INTEGER PRIMARY KEY CHECK(id = 1), value TEXT NOT NULL)',
          );
          await db.execute(
            'CREATE TABLE notification_receipts (key TEXT PRIMARY KEY, created_at INTEGER NOT NULL)',
          );
        case 3:
          for (final row in await db.query('notification_state')) {
            AlertState.fromJson(storedObject(row['value'] as String));
          }
          await db.execute(
            'ALTER TABLE sessions ADD COLUMN ended_at_utc_micros INTEGER NOT NULL DEFAULT 0',
          );
          String? cursor;
          while (true) {
            final rows = await db.query(
              'sessions',
              where: cursor == null ? null : 'id > ?',
              whereArgs: cursor == null ? null : [cursor],
              orderBy: 'id',
              limit: 250,
            );
            final batch = db.batch();
            for (final row in rows) {
              final session = FocusSession.fromRow(row);
              batch.update(
                'sessions',
                {'ended_at_utc_micros': session.endedAt.microsecondsSinceEpoch},
                where: 'id = ?',
                whereArgs: [session.id],
              );
            }
            await batch.commit(noResult: true);
            if (rows.length < 250) break;
            cursor = rows.last['id'] as String;
          }
          await db.execute(
            'CREATE INDEX sessions_end_id ON sessions(ended_at_utc_micros DESC, id DESC)',
          );
          await db.execute(
            'CREATE INDEX tasks_position_id ON tasks(position, id)',
          );
          await db.execute(
            'CREATE TABLE storage_meta (id INTEGER PRIMARY KEY CHECK(id=1), revision INTEGER NOT NULL, commit_id TEXT, cleanup_pending INTEGER NOT NULL CHECK(cleanup_pending IN (0,1)))',
          );
          await db.insert('storage_meta', {
            'id': 1,
            'revision': 0,
            'commit_id': null,
            'cleanup_pending': 0,
          });
        default:
          throw const StorageFailure(StorageFailureKind.migration);
      }
    }
  } catch (error) {
    if (error is DatabaseException &&
        ((error.getResultCode() ?? 0) & 255) == 13) {
      throw const StorageFailure(StorageFailureKind.full);
    }
    // No raw JSON/SQL exception escapes into sqflite's open diagnostics.
    throw const StorageFailure(StorageFailureKind.migration);
  }
}
