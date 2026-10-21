// Dedicated-device lab entry point. Never imported by the production app.
// Build with --target=tool/seed_profile.dart, then overinstall the regular
// release APK using the same application ID and certificate before profiling.
import 'package:flutter/material.dart';
import 'package:poma/application/local_repository.dart';
import 'package:poma/data/local_repository.dart';
import 'package:poma/domain/models.dart';

const profileSessionCount = 100000;
const _batchSize = 1000;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProfileSeeder());
}

class ProfileSeeder extends StatefulWidget {
  const ProfileSeeder({super.key});

  @override
  State<ProfileSeeder> createState() => _ProfileSeederState();
}

class _ProfileSeederState extends State<ProfileSeeder> {
  int _written = 0;
  int? _verified;
  bool _running = false;
  String? _error;

  Future<void> _seed() async {
    setState(() {
      _running = true;
      _written = 0;
      _verified = null;
      _error = null;
    });
    final repository = SqliteRepository();
    try {
      final initial = await repository.loadInitial();
      if (initial.cleanupPending ||
          initial.timer != null && initial.timer!.status != RunStatus.ready ||
          initial.alerts.current != null) {
        if (mounted) {
          setState(() {
            _error =
                'Stop the timer and finish pending deletion before seeding.';
          });
        }
        return;
      }
      final existing = await repository.readHistoryPage();
      if (existing.sessions.isNotEmpty) {
        if (mounted) {
          setState(() {
            _error = 'History must be empty. Existing history was not changed.';
          });
        }
        return;
      }
      final state = SavedState(
        settings: initial.settings,
        timer: initial.timer,
        selectedTaskId: initial.selectedTaskId,
        alerts: initial.alerts,
      );
      var revision = await repository.commit(
        LocalCommit(
          id: newLocalId(),
          expectedRevision: initial.revision,
          changes: [LocalChange(state: state)],
        ),
      );
      // A fixed, equal-timestamp fixture stresses ID-boundary pagination. Its
      // records are synthetic, not a model of a person's actual focus history.
      final endedAt = DateTime.utc(2026, 1, 1, 12);
      for (var first = 0; first < profileSessionCount; first += _batchSize) {
        final sessions = List.generate(_batchSize, (offset) {
          final index = first + offset;
          return FocusSession(
            id: 'profile-100k-${index.toString().padLeft(6, '0')}',
            startedAt: endedAt.subtract(const Duration(minutes: 25)),
            endedAt: endedAt,
            focusSeconds: 1500,
          );
        });
        revision = await repository.commit(
          LocalCommit(
            id: newLocalId(),
            expectedRevision: revision,
            changes: [LocalChange(state: state, completions: sessions)],
          ),
        );
        if (mounted) setState(() => _written = first + sessions.length);
      }
      final summaries = await repository.readDaySummaries([
        DayRange(
          DateTime.utc(2026, 1, 1),
          DateTime.utc(2026, 1, 1),
          DateTime.utc(2026, 1, 2),
        ),
      ]);
      final page = await repository.readHistoryPage();
      if (summaries.single.count != profileSessionCount ||
          summaries.single.focusSeconds != profileSessionCount * 1500 ||
          page.sessions.length != 50 ||
          !page.hasOlder ||
          page.hasNewer ||
          page.sessions.first.id != 'profile-100k-099999') {
        throw const StorageFailure(StorageFailureKind.unreadable);
      }
      if (mounted) setState(() => _verified = summaries.single.count);
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Fixture preparation failed. Check free storage and retry.';
        });
      }
    } finally {
      await repository.close();
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Poma profile fixture',
    home: Scaffold(
      appBar: AppBar(title: const Text('Poma profile fixture')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Text('Dedicated test installation only.'),
            const SizedBox(height: 16),
            const Text(
              'Requires empty history. Create exactly 100,000 synthetic focus '
              'sessions. Tasks and settings are retained. No timer, alert, '
              'network request, or performance measurement is started.',
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _running ? null : _seed,
              child: const Text('Create 100,000 test sessions'),
            ),
            const SizedBox(height: 16),
            Text('Written: $_written / $profileSessionCount'),
            if (_verified != null) ...[
              Text('Verified: $_verified sessions'),
              const SizedBox(height: 16),
              const Text(
                'Complete. Close this lab app and overinstall the regular '
                'release with the same signing certificate before profiling. '
                'Do not measure this seeder.',
              ),
            ],
            if (_error != null) Text(_error!),
          ],
        ),
      ),
    ),
  );
}
