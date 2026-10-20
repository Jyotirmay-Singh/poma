import 'dart:convert';

import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

import '../application/local_repository.dart';
import '../domain/models.dart';
import 'local_storage_policy.dart';

class SqliteRepository implements LocalRepository {
  SqliteRepository({
    DatabaseFactory? factory,
    this.databasePath,
    LocalStoragePolicy? storagePolicy,
  }) : factory = factory ?? databaseFactory,
       storagePolicy = storagePolicy ?? LocalStoragePolicy();

  final DatabaseFactory factory;
  final String? databasePath;
  final LocalStoragePolicy storagePolicy;
  Database? _database;

  Future<Database> _open() async {
    if (_database != null) return _database!;
    final location =
        databasePath ?? path.join(await factory.getDatabasesPath(), 'poma.db');
    // The directory exclusion also covers SQLite journal/WAL/SHM files.
    await storagePolicy.prepareDirectory(path.dirname(location));
    _database = await factory.openDatabase(
      location,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, _) async {
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
        },
      ),
    );
    return _database!;
  }

  @override
  Future<SavedState> load() async {
    final db = await _open();
    final state = {
      for (final row in await db.query('app_state'))
        row['key'] as String: row['value'] as String,
    };
    return SavedState(
      settings: state['settings'] == null
          ? const TimerSettings()
          : TimerSettings.fromJson(
              jsonDecode(state['settings']!) as Map<String, dynamic>,
            ),
      timer: state['timer'] == null
          ? null
          : TimerSnapshot.fromJson(
              jsonDecode(state['timer']!) as Map<String, dynamic>,
            ),
      selectedTaskId: state['selectedTaskId'],
      tasks: (await db.query(
        'tasks',
        orderBy: 'position ASC',
      )).map(FocusTask.fromRow).toList(),
      sessions: (await db.query(
        'sessions',
        orderBy: 'ended_at DESC',
      )).map(FocusSession.fromRow).toList(),
    );
  }

  @override
  Future<void> save(SavedState state) async {
    final db = await _open();
    // History and the advanced timer commit together. A recovered completion
    // cannot be counted twice, even if the process exits during this write.
    await db.transaction((txn) async {
      final batch = txn.batch();
      final values = {
        'settings': jsonEncode(state.settings.toJson()),
        if (state.timer != null) 'timer': jsonEncode(state.timer!.toJson()),
        if (state.selectedTaskId != null)
          'selectedTaskId': state.selectedTaskId!,
      };
      for (final entry in values.entries) {
        batch.insert('app_state', {
          'key': entry.key,
          'value': entry.value,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      if (state.selectedTaskId == null) {
        batch.delete(
          'app_state',
          where: 'key = ?',
          whereArgs: ['selectedTaskId'],
        );
      }
      batch.delete('tasks');
      for (var i = 0; i < state.tasks.length; i++) {
        batch.insert('tasks', state.tasks[i].toRow(i));
      }
      for (final session in state.sessions) {
        batch.insert(
          'sessions',
          session.toRow(),
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
      await batch.commit(noResult: true);
    });
  }

  @override
  Future<void> close() async {
    await _database?.close();
    _database = null;
  }
}
