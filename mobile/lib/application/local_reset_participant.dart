/// Optional platform data cleanup; never a timer-domain or network dependency.
abstract interface class LocalResetParticipant {
  void invalidateForReset();
  Future<void> clearForReset();
}

class CompositeLocalResetParticipant implements LocalResetParticipant {
  CompositeLocalResetParticipant(Iterable<LocalResetParticipant> participants)
    : participants = List.unmodifiable(participants);
  final List<LocalResetParticipant> participants;
  @override
  void invalidateForReset() {
    for (final participant in participants) {
      participant.invalidateForReset();
    }
  }

  @override
  Future<void> clearForReset() async {
    // Attempt every cleanup even if one platform fails. Preserve retry barrier.
    Object? failure;
    for (final participant in participants) {
      try {
        await participant.clearForReset();
      } catch (error) {
        failure ??= error;
      }
    }
    if (failure != null) throw failure;
  }
}
