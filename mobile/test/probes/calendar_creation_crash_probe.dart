import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import '../calendar_creation_support.dart';

const stage = String.fromEnvironment('POMA_CREATION_CRASH_STAGE');
const directory = String.fromEnvironment('POMA_CREATION_CRASH_DIRECTORY');
Never crash() {
  File('$directory/crash-stage').writeAsStringSync(stage, flush: true);
  exit(73);
}

void main() {
  test('creation operation process crash', () async {
    final folder = Directory(directory);
    final store = CreationMemory(directory: folder);
    final server = CreationGoogle(directory: folder);
    final r = await creationRig(store: store, google: server);
    final d = r.draft();
    File('$directory/draft-id').writeAsStringSync(d.id, flush: true);
    store.onSaved = (document) {
      final m = jsonDecode(document) as Map;
      final ops = m['operations'] as Map;
      if (stage == 'draft' && (m['drafts'] as Map).isNotEmpty && ops.isEmpty) {
        crash();
      }
      if (ops.isNotEmpty) {
        final status = (ops.values.last as Map)['state'];
        if (stage == 'sending' && status == 'sending' ||
            stage == 'acknowledged' && status == 'saved') {
          crash();
        }
      }
    };
    server.afterCommit = () {
      if (stage == 'serverCommitted') crash();
    };
    if (stage == 'draft') await r.controller.keepDraft(d);
    await r.controller.submit(d, r.intent(d));
    fail('The requested crash boundary was not reached.');
  }, skip: stage.isEmpty || directory.isEmpty);
}
