import '../domain/models.dart';

/// Persistence required by the application, independent of the storage engine.
abstract interface class LocalRepository {
  Future<SavedState> load();
  Future<void> save(SavedState state);
  Future<void> close();
  Future<String?> notificationDatabasePath();
  Future<bool> recordAlertReceipt(String key);
}
