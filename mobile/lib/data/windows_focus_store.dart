import 'package:flutter/services.dart';
import '../application/calendar_connection_controller.dart';
import '../application/focus_block_ports.dart';

class WindowsFocusStore
    implements FocusBlockOperationStore, FocusSchedulingGateStore {
  WindowsFocusStore(this.channel, this.connection);
  final MethodChannel channel;
  final CalendarConnectionController connection;
  int _credentialRevision = 0;
  @override
  Future<FocusStoredJournal> open(String accountKey) async {
    try {
      _credentialRevision = connection.storageRevision;
      final m = (await channel.invokeMapMethod<String, Object?>(
        'focusJournalOpen',
        {'revision': _credentialRevision, 'accountKey': accountKey},
      ))!;
      return FocusStoredJournal(
        FocusStoreLease(
          accountKey,
          m['generation'] as int,
          m['revision'] as int,
        ),
        m['document'] as String?,
        stopped: m['stopped'] == true,
        disabled: m['disabled'] == true,
      );
    } catch (_) {
      throw const FocusFailure(FocusFailureKind.storage);
    }
  }

  @override
  Future<FocusStoreLease> save(FocusStoreLease lease, String document) async {
    try {
      final revision = (await channel.invokeMethod<int>('focusJournalSave', {
        'credentialRevision': _credentialRevision,
        'accountKey': lease.accountKey,
        'generation': lease.generation,
        'revision': lease.revision,
        'document': document,
      }))!;
      return FocusStoreLease(lease.accountKey, lease.generation, revision);
    } catch (_) {
      throw const FocusFailure(FocusFailureKind.storage);
    }
  }

  @override
  Future<void> stop({bool purge = false}) async {
    try {
      await channel.invokeMethod<void>('focusJournalStop', {'purge': purge});
    } catch (_) {
      throw const FocusFailure(FocusFailureKind.storage);
    }
  }

  @override
  Future<void> setDisabled(bool disabled) async {
    try {
      await channel.invokeMethod<void>('focusJournalDisable', {
        'disabled': disabled,
      });
    } catch (_) {
      throw const FocusFailure(FocusFailureKind.storage);
    }
  }
}
