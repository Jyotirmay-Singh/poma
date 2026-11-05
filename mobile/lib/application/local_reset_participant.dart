/// Optional platform data cleanup; never a timer-domain or network dependency.
abstract interface class LocalResetParticipant {
  void invalidateForReset();
  Future<void> clearForReset();
}
