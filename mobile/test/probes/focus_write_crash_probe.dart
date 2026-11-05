import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:poma/application/focus_block_controller.dart';
import 'package:poma/application/focus_block_ports.dart';
import 'package:poma/domain/focus_blocks.dart';
import '../focus_blocks_test.dart' as f;

const stage = String.fromEnvironment('POMA_FOCUS_CRASH_STAGE');
const directory = String.fromEnvironment('POMA_FOCUS_CRASH_DIRECTORY');
Never crash() {
  File('$directory/crash-stage').writeAsStringSync(stage, flush: true);
  exit(73);
}

class CrashStore extends f.JournalStore {
  CrashStore(super.directory);
  @override
  Future<FocusStoreLease> save(FocusStoreLease lease, String document) async {
    final result = await super.save(lease, document);
    final operations = (jsonDecode(document) as Map)['operations'] as List;
    if (operations.isNotEmpty) {
      final status = (operations.last as Map)['status'];
      if (stage == 'pending' && status == 'pending' ||
          stage == 'sending' && status == 'sending' ||
          stage == 'acknowledged' && status == 'saved') {
        crash();
      }
    }
    return result;
  }
}

class CrashGoogle extends f.GoogleStore {
  @override
  Future<FocusRemoteBlock> create(
    FocusCalendarBinding binding,
    FocusBlockOperation operation,
  ) async {
    final result = await super.create(binding, operation);
    File('$directory/server.json').writeAsStringSync(
      jsonEncode(events.values.map((e) => e.value).toList()),
      flush: true,
    );
    if (stage == 'serverCommitted') crash();
    return result;
  }
}

void main() {
  test('focus operation process crash', () async {
    final controller = FocusBlockController(
      session: f.WriteSession(),
      store: CrashStore(Directory(directory)),
      writer: CrashGoogle(),
      time: f.Times(),
      now: () => f.instant,
    );
    await controller.initialize();
    await controller.bind(f.binding());
    await controller.confirm(await controller.preview(f.draft()));
    fail('Requested crash boundary was not reached.');
  }, skip: stage.isEmpty || directory.isEmpty);
}
