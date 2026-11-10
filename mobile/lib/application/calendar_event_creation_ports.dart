import 'package:flutter/foundation.dart';

import '../domain/calendar_event_creation.dart';

class CreationStoreLease {
  const CreationStoreLease(this.accountKey, this.generation, this.revision);
  final String accountKey;
  final int generation, revision;
}

class StoredCreationJournal {
  const StoredCreationJournal(
    this.lease,
    this.document, {
    this.disabled = false,
  });
  final CreationStoreLease lease;
  final String? document;
  final bool disabled;
}

abstract interface class CalendarCreationStore {
  Future<StoredCreationJournal> open(String accountKey);
  Future<CreationStoreLease> save(CreationStoreLease lease, String document);
  Future<void> stop({bool purge = false});
  Future<void> setDisabled(bool disabled);
}

/// UI contract for Session 2. The foundation implements the unavailable side;
/// the future transport/journal owner must supply truthful asynchronous results.
abstract interface class CalendarEventCreationController implements Listenable {
  bool get creationConnected;
  CalendarCreationState get creationState;
  CalendarEventDraft? get draft;
  CalendarCreateIntent? get review;
  Future<void> validateDraft();
  Future<CalendarCreateResult> submitReviewed();
  Future<CalendarCreateResult> reconcile(CalendarCreateOperation operation);
}
