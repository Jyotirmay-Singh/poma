import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:poma/application/local_repository.dart';
import 'package:poma/data/local_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  test(
    'production read transactions allow a second connection to read alerts',
    () async {
      final directory = Directory.systemTemp.createTempSync(
        'poma-native-reader-',
      );
      final path = '${directory.path}/poma.db';
      // Separate factories/handles model the native adapter, not sqflite's shared
      // singleton connection. Open the probe before holding a transaction.
      final factory = createDatabaseFactoryFfi();
      final setup = SqliteRepository(factory: factory, databasePath: path);
      await setup.loadInitial();
      await setup.close();
      final probe = await createDatabaseFactoryFfi().openDatabase(
        path,
        options: OpenDatabaseOptions(singleInstance: false),
      );
      await probe.execute('PRAGMA busy_timeout = 0');
      final exclusiveReader = await factory.openDatabase(path);
      // Reproduce the lock from the former read policy using the same probe.
      await exclusiveReader.transaction((txn) async {
        await txn.rawQuery('SELECT value FROM notification_state WHERE id=1');
        await expectLater(
          probe.rawQuery('PRAGMA journal_mode'),
          throwsA(isA<DatabaseException>()),
        );
      }, exclusive: true);
      await exclusiveReader.close();
      final observed = <String>[];
      final repository = SqliteRepository(
        factory: _ProbeFactory(factory, () async {
          // Android opens run PRAGMA journal_mode before reading the outbox.
          await probe.rawQuery('PRAGMA journal_mode');
          await probe.rawQuery(
            'SELECT value FROM notification_state WHERE id=1',
          );
          observed.add('native reader succeeded');
        }),
        databasePath: path,
      );
      try {
        await repository.loadInitial();
        await repository.readHistoryPage();
        await repository.readDaySummaries([
          DayRange.local(DateTime(2026, 10, 22)),
        ]);
        expect(observed, hasLength(3));
      } finally {
        await repository.close();
        await probe.close();
        directory.deleteSync(recursive: true);
      }
    },
  );
}

class _ProbeFactory implements DatabaseFactory {
  _ProbeFactory(this.delegate, this.probe);
  final DatabaseFactory delegate;
  final Future<void> Function() probe;
  @override
  Future<Database> openDatabase(
    String path, {
    OpenDatabaseOptions? options,
  }) async => _ProbeDatabase(
    await delegate.openDatabase(path, options: options),
    probe,
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ProbeDatabase implements Database {
  _ProbeDatabase(this.delegate, this.probe);
  final Database delegate;
  final Future<void> Function() probe;
  @override
  Future<T> transaction<T>(
    Future<T> Function(Transaction txn) action, {
    bool? exclusive,
  }) => delegate.transaction((txn) async {
    await probe();
    return action(txn);
  }, exclusive: exclusive);
  @override
  Future<void> close() => delegate.close();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
