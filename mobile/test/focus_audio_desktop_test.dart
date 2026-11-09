import 'package:flutter_test/flutter_test.dart';
import 'package:poma/application/desktop_controller.dart';
import 'package:poma/domain/models.dart';
import 'desktop_test.dart' show FakeShell;
import 'focus_audio_support.dart';

void main() {
  test(
    'desktop navigation, visibility and native actions share audio session owner',
    () async {
      final f = AudioFixture();
      await f.initialize();
      final shell = FakeShell();
      final desktop = DesktopController(
        f.app,
        shell,
        const DesktopEnvironment(
          dataDirectory: 'isolated-test',
          version: 'test',
          packaged: false,
        ),
      );
      addTearDown(() async {
        desktop.dispose();
        await f.close();
      });
      await desktop.initialize();
      await f.start();
      final starts = f.player.starts.length;
      desktop.navigate(1);
      desktop.navigate(0);
      await shell.send('visibility', {'visible': false});
      await f.settle();
      expect(f.player.active, isNotNull);
      expect(f.player.starts.length, starts);
      await desktop.requestTimerAction(
        action: 'pause',
        revision: f.app.timer.revision,
        runId: f.app.timer.runId,
      );
      await f.settle();
      expect(f.player.active, isNull);
      expect(f.app.timer.status, RunStatus.paused);
      await desktop.requestTimerAction(
        action: 'resume',
        revision: f.app.timer.revision,
        runId: f.app.timer.runId,
      );
      await f.settle();
      expect(f.player.active, isNotNull);
    },
  );
  test(
    'desktop Quit silences before saves and cancellation never autoplays',
    () async {
      final f = AudioFixture();
      await f.initialize();
      final shell = FakeShell();
      final desktop = DesktopController(
        f.app,
        shell,
        const DesktopEnvironment(
          dataDirectory: 'isolated-test',
          version: 'test',
          packaged: false,
        ),
      );
      addTearDown(() async {
        desktop.dispose();
        await f.close();
      });
      await desktop.initialize();
      await f.start();
      f.repository.failWrites = true;
      f.audio.setVolume(.21);
      desktop.confirmDiscard = () async => false;
      final cancelled = desktop.quit();
      expect(f.player.active, isNull);
      await cancelled;
      await f.settle();
      expect(shell.exits, 0);
      expect(f.player.active, isNull);
      await f.audio.playSounds();
      await f.settle();
      expect(f.player.active, isNotNull);
      desktop.confirmDiscard = () async => true;
      await desktop.quit();
      expect(f.player.closed, isTrue);
      expect(shell.exits, 1);
    },
  );
}
