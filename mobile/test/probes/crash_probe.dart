// Launched only by process_crash_test.dart; not discovered by the normal suite.
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:poma/application/app_controller.dart';
import 'package:poma/data/local_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../support.dart';
import '../alert_support.dart';

void main() {
  test('terminate repository owner at transaction boundary', () async {
    const location = String.fromEnvironment('POMA_CRASH_PATH');
    const stage = String.fromEnvironment('POMA_CRASH_STAGE');
    if (location.isEmpty || !['beforeCommit', 'afterCommit'].contains(stage)) {
      throw StateError('Probe requires explicit fixture path and stage.');
    }
    sqfliteFfiInit();
    final repository = SqliteRepository(
      factory: databaseFactoryFfi,
      databasePath: location,
      commitObserver: (observed) async {
        if (observed == stage) {
          File(
            '$location.crash-stage',
          ).writeAsStringSync(observed, flush: true);
          exit(73);
        }
      },
    );
    final clock = FakeClock()..advance(const Duration(days: 2));
    await AppController.create(repository, clock: clock, alerts: FakeAlerts());
    fail('Crash hook was not reached.');
  });
}
