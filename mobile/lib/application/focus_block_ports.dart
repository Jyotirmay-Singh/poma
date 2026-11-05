import 'package:flutter/foundation.dart';
import '../domain/focus_blocks.dart';

abstract interface class FocusWriteSession implements Listenable {
  String? get verifiedAccountKey;
  String get focusClientId;
  String? get credentialGeneration;
  bool get focusWriteEnabled;
  bool get focusOnline;
  CalendarWriteCapability get writeCapability;
}

class FocusBlockPreview {
  const FocusBlockPreview(
    this.token,
    this.draft,
    this.kind,
    this.binding,
    this.credentialGeneration, {
    this.before,
    this.operation,
  });
  final String token, credentialGeneration;
  final FocusBlockDraft draft;
  final FocusOperationKind kind;
  final FocusCalendarBinding binding;
  final FocusRemoteBlock? before;
  final FocusBlockOperation? operation;
}

enum FocusFailureKind {
  cancelled,
  network,
  permission,
  conflict,
  precondition,
  missing,
  throttled,
  response,
  storage,
  invalidTime,
}

class FocusFailure implements Exception {
  const FocusFailure(this.kind, {this.retryAfter});
  final FocusFailureKind kind;
  final Duration? retryAfter;
  @override
  String toString() => 'Focus scheduling failed (${kind.name}).';
}

class FocusStoreLease {
  const FocusStoreLease(this.accountKey, this.generation, this.revision);
  final String accountKey;
  final int generation, revision;
}

class FocusStoredJournal {
  const FocusStoredJournal(
    this.lease,
    this.document, {
    this.stopped = false,
    this.disabled = false,
  });
  final FocusStoreLease lease;
  final String? document;
  final bool stopped;
  final bool disabled;
}

abstract interface class FocusBlockOperationStore {
  Future<FocusStoredJournal> open(String accountKey);
  Future<FocusStoreLease> save(FocusStoreLease lease, String document);
  Future<void> stop({bool purge = false});
}

abstract interface class FocusSchedulingGateStore {
  Future<void> setDisabled(bool disabled);
}

abstract interface class FocusBlockWriter {
  Future<List<FocusCalendarBinding>> discover(
    String accountKey,
    String clientId,
  );
  Future<FocusCalendarBinding> provision(FocusCalendarBinding intent);
  Future<FocusCalendarBinding> validate(FocusCalendarBinding binding);
  Future<FocusRemoteBlock?> get(FocusCalendarBinding binding, String eventId);
  Future<FocusRemoteBlock> create(
    FocusCalendarBinding binding,
    FocusBlockOperation operation,
  );
  Future<FocusRemoteBlock> edit(
    FocusCalendarBinding binding,
    FocusBlockOperation operation,
    FocusRemoteBlock current,
  );
  Future<void> delete(
    FocusCalendarBinding binding,
    FocusBlockOperation operation,
  );
  Future<List<FocusRemoteBlock>> recover(
    FocusCalendarBinding binding,
    DateTime start,
    DateTime end,
  );
  void cancel();
}

class FocusTimeResolution {
  const FocusTimeResolution({
    required this.utc,
    required this.offsetMinutes,
    required this.zone,
    required this.fingerprint,
  });
  final DateTime utc;
  final int offsetMinutes;
  final String zone, fingerprint;
}

abstract interface class FocusTimeResolver {
  Future<FocusTimeResolution> resolve(DateTime wallTime);
  Future<String> fingerprint();
}
