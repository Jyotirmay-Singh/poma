import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:poma/application/app_controller.dart';
import 'package:poma/data/local_repository.dart';
import 'package:poma/domain/focus_sound_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'support.dart';

void main() {
  setUpAll(sqfliteFfiInit);
  test(
    'audio preferences validate finite values and retain mute and exact zero',
    () {
      const preferences = FocusSoundPreferences(
        sound: FocusSoundId.forestBirds,
        volume: 0,
        muted: true,
      );
      expect(FocusSoundPreferences.fromJson(preferences.toJson()), preferences);
      expect(FocusSoundPreferences.fromJson({}), const FocusSoundPreferences());
      for (final bad in [
        {'volume': double.nan},
        {'volume': -1},
        {'volume': 2},
        {'sound': 'unknown'},
        {'muted': 0},
        {'version': 2},
        {'volume': null},
        {'muted': null},
        {'sound': null},
      ]) {
        expect(
          () => FocusSoundPreferences.fromJson(bad),
          throwsFormatException,
        );
      }
    },
  );
  for (final legacy in [null, 'v1', 'v2']) {
    test(
      'real SQLite $legacy defaults Off, survives reopen, reset removes only intended data',
      () async {
        final dir = Directory.systemTemp.createTempSync('poma-sounds-');
        final file = '${dir.path}/poma.db';
        addTearDown(() => dir.deleteSync(recursive: true));
        if (legacy != null) {
          final db = await databaseFactoryFfi.openDatabase(file);
          final sql =
              File('test/fixtures/v1.sql').readAsStringSync() +
              (legacy == 'v2'
                  ? File('test/fixtures/v2.sql').readAsStringSync()
                  : '');
          for (final statement in sql.split(';')) {
            if (statement.trim().isNotEmpty) await db.execute(statement);
          }
          await db.close();
        }
        var repository = SqliteRepository(
          factory: databaseFactoryFfi,
          databasePath: file,
        );
        var app = await AppController.create(repository, clock: FakeClock());
        expect(app.focusSoundPreferences, const FocusSoundPreferences());
        app.addTask('Keep this local task');
        await app.flush();
        final taskCount = app.tasks.length;
        const saved = FocusSoundPreferences(
          sound: FocusSoundId.tibetanBells,
          volume: .19,
          muted: true,
        );
        await app.updateFocusSoundPreferences(saved);
        app.dispose();
        await repository.close();
        repository = SqliteRepository(
          factory: databaseFactoryFfi,
          databasePath: file,
        );
        app = await AppController.create(repository, clock: FakeClock());
        try {
          expect(app.focusSoundPreferences, saved);
          expect(app.tasks.length, taskCount);
          final db = await databaseFactoryFfi.openDatabase(file);
          expect(await db.getVersion(), 3);
          await app.deleteAllLocalData();
          expect(app.focusSoundPreferences, const FocusSoundPreferences());
          expect(
            await db.query(
              'app_state',
              where: 'key = ?',
              whereArgs: ['focusSounds'],
            ),
            isEmpty,
          );
          await db.close();
        } finally {
          app.dispose();
          await repository.close();
        }
      },
    );
  }
  for (final value in [
    'broken json',
    jsonEncode({'sound': 'waterfall', 'volume': -1}),
    jsonEncode({'version': 99}),
  ]) {
    test(
      'corrupt optional namespace fails closed without deleting core data: $value',
      () async {
        final dir = Directory.systemTemp.createTempSync('poma-sounds-corrupt-');
        final file = '${dir.path}/poma.db';
        final repo = SqliteRepository(
          factory: databaseFactoryFfi,
          databasePath: file,
        );
        var app = await AppController.create(repo, clock: FakeClock());
        app.addTask('Preserved');
        await app.flush();
        app.dispose();
        await repo.close();
        final db = await databaseFactoryFfi.openDatabase(file);
        await db.insert('app_state', {'key': 'focusSounds', 'value': value});
        await db.close();
        app = await AppController.create(repo, clock: FakeClock());
        try {
          expect(app.focusSoundPreferences.sound, FocusSoundId.off);
          expect(app.tasks.single.title, 'Preserved');
        } finally {
          app.dispose();
          await repo.close();
          dir.deleteSync(recursive: true);
        }
      },
    );
  }
}
