import 'package:poma/application/local_repository.dart';
import 'package:poma/domain/models.dart';
import 'package:poma/domain/timer_engine.dart';

class FakeClock implements TimerClock {
  FakeClock([DateTime? now]) : utcNow = now ?? DateTime.utc(2026, 10, 20, 9);
  @override
  DateTime utcNow;
  @override
  Duration elapsed = Duration.zero;
  void advance(Duration duration) {
    utcNow = utcNow.add(duration);
    elapsed += duration;
  }
}

class MemoryRepository implements LocalRepository {
  MemoryRepository([SavedState? initial]) : state = initial ?? SavedState();
  SavedState state;
  bool failWrites = false;
  @override
  Future<SavedState> load() async => state;
  @override
  Future<void> save(SavedState next) async {
    if (failWrites) throw StateError('Disk full');
    state = next;
  }

  @override
  Future<void> close() async {}
}
