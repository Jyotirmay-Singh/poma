import 'package:flutter/services.dart';
import '../application/calendar_connection_controller.dart';
import '../application/calendar_event_creation_ports.dart';

class WindowsCalendarCreationStore implements CalendarCreationStore {
  WindowsCalendarCreationStore(this.channel, this.connection);
  final MethodChannel channel;
  final CalendarConnectionController connection;
  int _credentialRevision = 0;
  @override
  Future<StoredCreationJournal> open(String accountKey) async {
    _credentialRevision = connection.storageRevision;
    final m = (await channel.invokeMapMethod<String, Object?>(
      'creationJournalOpen',
      {'revision': _credentialRevision, 'accountKey': accountKey},
    ))!;
    return StoredCreationJournal(
      CreationStoreLease(
        accountKey,
        m['generation'] as int,
        m['revision'] as int,
      ),
      m['document'] as String?,
      disabled: m['disabled'] == true,
    );
  }

  @override
  Future<CreationStoreLease> save(
    CreationStoreLease lease,
    String document,
  ) async {
    final revision = (await channel.invokeMethod<int>('creationJournalSave', {
      'credentialRevision': _credentialRevision,
      'accountKey': lease.accountKey,
      'generation': lease.generation,
      'revision': lease.revision,
      'document': document,
    }))!;
    return CreationStoreLease(lease.accountKey, lease.generation, revision);
  }

  @override
  Future<void> stop({bool purge = false}) =>
      channel.invokeMethod<void>('creationJournalStop', {'purge': purge});
  @override
  Future<void> setDisabled(bool disabled) => channel.invokeMethod<void>(
    'creationJournalDisable',
    {'disabled': disabled},
  );
}
