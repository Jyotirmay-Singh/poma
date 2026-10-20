import 'package:poma/application/local_repository.dart';
import 'package:poma/domain/models.dart';
import 'package:poma/domain/timer_engine.dart';

class FakeClock implements TimerClock {
  FakeClock([DateTime? now]) : utcNow = now ?? DateTime.utc(2026, 10, 20, 9);
  DateTime utcNow;
  Duration elapsed = Duration.zero;
  ClockReading get reading => ClockReading(utcNow: utcNow, elapsed: elapsed);
  bool failReads = false;
  @override
  Future<ClockReading> sample() async {
    if (failReads) throw const TimerClockException();
    return reading;
  }

  void advance(Duration duration) {
    utcNow = utcNow.add(duration);
    elapsed += duration;
  }
}

class MemoryRepository implements LocalRepository {
  MemoryRepository([SavedState? initial]) : state = initial ?? SavedState();
  SavedState state;
  bool failWrites = false;
  int writes = 0;
  @override
  Future<SavedState> load() async => state;
  @override
  Future<void> save(SavedState next) async {
    writes++;
    if (failWrites) throw StateError('Disk full');
    state = next;
  }

  @override
  Future<void> close() async {}
}
