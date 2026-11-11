// Launched only by planner_repository_test.dart at explicit transaction boundaries.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:poma/application/app_controller.dart';
import 'package:poma/data/local_repository.dart';
import 'package:poma/domain/models.dart';
import 'package:poma/domain/planner.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../support.dart';

void main() {
  test('terminate planner owner at a transaction boundary', () async {
    const path = String.fromEnvironment('POMA_CRASH_PATH');
    const stage = String.fromEnvironment('POMA_CRASH_STAGE');
    if (path.isEmpty || !['beforeCommit', 'afterCommit'].contains(stage)) {
      throw StateError('Explicit fixture required.');
    }
    sqfliteFfiInit();
    var armed = false;
    final repository = SqliteRepository(
      factory: databaseFactoryFfi,
      databasePath: path,
      commitObserver: (observed) async {
        if (armed && observed == stage) {
          File('$path.planner-stage').writeAsStringSync(stage, flush: true);
          exit(73);
        }
      },
    );
    final app = await AppController.create(repository, clock: FakeClock());
    final task = FocusTask(
      id: newLocalId(),
      title: 'Fictional atomic planner task',
    );
    final schedule = PlannerSchedule(
      id: newPlannerId(),
      taskId: task.id,
      accountKey: 'fictional-account',
      calendarId: 'fictional-owned',
      eventId: 'fictional-stable-event',
      policy: PlannerSyncPolicy.google,
      fields: {
        'summary': task.title,
        'start': {
          'dateTime': '2026-11-10T16:30:00Z',
          'timeZone': 'Asia/Kolkata',
        },
        'end': {'dateTime': '2026-11-10T17:30:00Z', 'timeZone': 'Asia/Kolkata'},
      },
    );
    final operation = PlannerOperation(
      id: newPlannerId(),
      scheduleId: schedule.id,
      accountKey: schedule.accountKey!,
      calendarId: schedule.calendarId!,
      eventId: schedule.eventId!,
      kind: PlannerOperationKind.create,
      fields: schedule.fields,
    );
    armed = true;
    await app.commitPlanner(
      PlannerData(
        schedules: {schedule.id: schedule},
        operations: {operation.id: operation},
      ),
      changedTasks: [task],
    );
    fail('The requested crash boundary was not reached.');
  });
}
