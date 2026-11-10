import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'application/app_controller.dart';
import 'application/local_repository.dart';
import 'data/local_repository.dart';
import 'data/local_storage_policy.dart';
import 'data/timer_clock.dart';
import 'data/local_alerts.dart';
import 'data/launch_reporter.dart';
import 'application/local_alerts.dart';
import 'domain/timer_engine.dart';
import 'ui/app_shell.dart';
import 'ui/theme.dart';
import 'ui/space_backdrop.dart';
import 'ui/copy.dart';
import 'l10n/poma_localizations.dart';
import 'application/desktop_controller.dart';
import 'data/windows_platform.dart';
import 'ui/desktop_scope.dart';
import 'application/calendar_connection_controller.dart';
import 'data/google_calendar_authorization.dart';
import 'data/windows_calendar_credentials.dart';
import 'domain/calendar_preview.dart';
import 'application/calendar_read_controller.dart';
import 'data/calendar_time.dart';
import 'data/google_calendar_reader.dart';
import 'data/windows_calendar_cache.dart';
import 'application/calendar_reminder_controller.dart';
import 'data/windows_calendar_reminders.dart';
import 'application/focus_block_controller.dart';
import 'application/calendar_event_creation_controller.dart';
import 'data/google_calendar_event_writer.dart';
import 'data/windows_calendar_creation_store.dart';
import 'data/google_focus_writer.dart';
import 'data/windows_focus_store.dart';
import 'data/windows_focus_time.dart';
import 'application/focus_audio_coordinator.dart';
import 'application/focus_audio_ports.dart';
import 'application/local_reset_participant.dart';
import 'data/soloud_focus_audio_playback.dart';
import 'data/mobile_focus_audio_playback.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks([
      'Poma focus sound recordings',
    ], await rootBundle.loadString('assets/licenses/focus-sounds.txt'));
    yield LicenseEntryWithLineBreaks([
      'Focus audio native runtime',
    ], await rootBundle.loadString('assets/licenses/focus-audio-native.txt'));
    yield LicenseEntryWithLineBreaks([
      'Sora',
    ], await rootBundle.loadString('assets/licenses/sora.txt'));
    yield LicenseEntryWithLineBreaks([
      'Source Sans 3',
    ], await rootBundle.loadString('assets/licenses/source-sans-3.txt'));
    yield LicenseEntryWithLineBreaks([
      'Pomatez',
    ], await rootBundle.loadString('assets/licenses/pomatez.txt'));
    yield LicenseEntryWithLineBreaks(
      [
        Platform.isWindows
            ? 'Windows native runtime dependencies'
            : 'Android native runtime dependencies',
      ],
      await rootBundle.loadString(
        Platform.isWindows
            ? 'assets/licenses/windows-native.txt'
            : 'assets/licenses/android-native.txt',
      ),
    );
  });
  runApp(const PomaLoader());
}

class PomaLoader extends StatefulWidget {
  const PomaLoader({
    super.key,
    this.repositoryFactory,
    this.clockFactory,
    this.alertsFactory,
    this.focusAudioFactory,
  });

  final LocalRepository Function()? repositoryFactory;
  final TimerClock Function()? clockFactory;
  final LocalAlerts Function()? alertsFactory;
  final FocusAudioPlaybackPort Function()? focusAudioFactory;
  @override
  State<PomaLoader> createState() => _PomaLoaderState();
}

class _PomaLoaderState extends State<PomaLoader> {
  late Future<AppController> _loading;
  LocalRepository? _repository;
  AppController? _controller;
  NativeWindowsHost? _windowsHost;
  DesktopController? _desktop;
  CalendarConnectionController? _connection;
  FocusAudioCoordinator? _focusAudio;
  @override
  void initState() {
    super.initState();
    unawaited(DeviceFormats.initialize());
    _loading = _load();
  }

  Future<AppController> _load() async {
    await _focusAudio?.close();
    await _repository?.close();
    DesktopEnvironment? environment;
    if (widget.repositoryFactory == null && Platform.isWindows) {
      _windowsHost ??= NativeWindowsHost();
      environment = await _windowsHost!.initialize();
    }
    final repository =
        widget.repositoryFactory?.call() ??
        (environment == null
            ? SqliteRepository()
            : await _windowsHost!.repository(environment));
    _repository = repository;
    final alerts =
        widget.alertsFactory?.call() ??
        (widget.repositoryFactory != null
            ? null
            : environment == null
            ? NativeLocalAlerts()
            : WindowsLocalAlerts(_windowsHost!));
    if (environment != null) {
      final credentials = WindowsCalendarCredentials(_windowsHost!.channel);
      _connection ??= CalendarConnectionController(
        configuration: const GoogleCalendarConfiguration.environment(),
        authorization: DesktopGoogleAuthorization(browser: credentials),
        writeAuthorization: DesktopGoogleAuthorization(browser: credentials),
        store: credentials,
        onDisconnected: () =>
            _desktop?.calendar.select(CalendarFixture.disconnected),
      );
    }
    final audio = _focusAudio =
        widget.focusAudioFactory != null || widget.repositoryFactory == null
        ? FocusAudioCoordinator(
            widget.focusAudioFactory?.call() ??
                (Platform.isAndroid || Platform.isIOS
                    ? MobileFocusAudioPlayback()
                    : SoLoudFocusAudioPlayback()),
          )
        : null;
    final controller = _controller = await AppController.create(
      repository,
      clock: widget.clockFactory?.call() ?? NativeTimerClock(),
      alerts: alerts,
      resetParticipant: CompositeLocalResetParticipant([?audio, ?_connection]),
      onFocusAudioSession: audio?.onSession,
      focusAudio: audio,
      suspendAudioInBackground: !Platform.isWindows,
      completionPresenter: alerts is CompletionPresenter
          ? alerts as CompletionPresenter
          : null,
    );
    audio?.bind(
      preferences: controller.focusSoundPreferences,
      save: controller.updateFocusSoundPreferences,
      reconcile: () async {
        await controller.reconcile();
      },
    );
    if (environment != null) {
      const calendarClock = DeviceCalendarClock();
      const calendarScheduler = TimerCalendarScheduler();
      final calendarData = CalendarReadController(
        connection: _connection!,
        provider: GoogleCalendarReader(
          access: _connection!,
          clock: calendarClock,
          scheduler: calendarScheduler,
        ),
        cache: WindowsCalendarCache(_windowsHost!.channel),
        clock: calendarClock,
        scheduler: calendarScheduler,
      );
      _desktop = DesktopController(
        controller,
        _windowsHost!,
        environment,
        connection: _connection,
        calendarData: calendarData,
        calendarPlatform: _windowsHost,
      );
      await _desktop!.initialize();
      final focusWriter = GoogleFocusWriter(_connection!);
      final focusBlocks = FocusBlockController(
        session: _connection!,
        store: WindowsFocusStore(_windowsHost!.channel, _connection!),
        writer: focusWriter,
        time: WindowsFocusTime(_windowsHost!.channel),
      );
      focusWriter.verifyTime = focusBlocks.verifyTime;
      _desktop!.attachFocusBlocks(focusBlocks);
      final eventWriter = GoogleCalendarEventWriter(_connection!);
      final creation = CalendarCreationController(
        connection: _connection!,
        reader: calendarData,
        store: WindowsCalendarCreationStore(
          _windowsHost!.channel,
          _connection!,
        ),
        writer: eventWriter,
        time: focusBlocks.time,
      );
      eventWriter.mutationAllowed = () => creation.ready && creation.busy;
      eventWriter.verifyTime = creation.verifyTime;
      _desktop!.attachCreation(creation);
      final reminderAdapter = WindowsCalendarReminders(_windowsHost!.channel);
      _desktop!.attachReminders(
        CalendarReminderController(
          reader: calendarData,
          store: reminderAdapter,
          platform: reminderAdapter,
          openAgenda: () => _desktop!.showPopup(),
        ),
      );
    }
    return controller;
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<AppController>(
    future: _loading,
    builder: (context, snapshot) {
      if (snapshot.hasData) {
        return PomaApp(controller: snapshot.data!, desktop: _desktop);
      }
      return MaterialApp(
        title: 'Poma',
        localizationsDelegates: PomaLocalizations.localizationsDelegates,
        supportedLocales: PomaLocalizations.supportedLocales,
        debugShowCheckedModeBanner: false,
        theme: pomaTheme(Brightness.light),
        darkTheme: pomaTheme(Brightness.dark),
        highContrastTheme: pomaTheme(Brightness.light, highContrast: true),
        highContrastDarkTheme: pomaTheme(Brightness.dark, highContrast: true),
        builder: (context, child) => PomaBackdrop(child: child!),
        home: Builder(
          builder: (context) => Scaffold(
            body: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: snapshot.hasError
                        ? Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.storage_outlined, size: 40),
                              const SizedBox(height: 20),
                              Text(
                                snapshot.error is TimerClockException
                                    ? context.copy.clockError
                                    : snapshot.error
                                          is LocalStoragePreparationException
                                    ? context.copy.startupPrivacy
                                    : snapshot.error is StorageFailure
                                    ? storageMessage(
                                        context.copy,
                                        (snapshot.error as StorageFailure).kind,
                                      )
                                    : context.copy.startupRead,
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                context.copy.tryAgainHelp,
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 20),
                              FilledButton(
                                onPressed: () => setState(() {
                                  _loading = _load();
                                }),
                                child: Text(context.copy.tryAgain),
                              ),
                            ],
                          )
                        : CircularProgressIndicator(
                            semanticsLabel: context.copy.opening,
                          ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
  @override
  void dispose() {
    _focusAudio?.flushPreferences();
    _focusAudio?.dispose();
    _desktop?.dispose();
    if (_desktop == null) _connection?.dispose();
    _controller?.dispose();
    unawaited(
      (_controller?.flush() ?? Future.value()).then(
        (_) => _repository?.close(),
      ),
    );
    super.dispose();
  }
}

class PomaApp extends StatefulWidget {
  const PomaApp({required this.controller, this.desktop, super.key});
  final AppController controller;
  final DesktopController? desktop;
  @override
  State<PomaApp> createState() => _PomaAppState();
}

class _PomaAppState extends State<PomaApp> with WidgetsBindingObserver {
  final _navigator = GlobalKey<NavigatorState>();
  @override
  void initState() {
    super.initState();
    unawaited(DeviceFormats.initialize());
    WidgetsBinding.instance.addObserver(this);
    if (widget.desktop == null) {
      widget.controller.setForeground(
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed,
      );
    }
    widget.desktop?.confirmDiscard = () async =>
        await showDialog<bool>(
          context: _navigator.currentContext!,
          builder: (context) => AlertDialog(
            title: const Text('Quit with unsaved changes?'),
            content: const Text(
              'Changes could not be saved. Retry in Poma, or quit and lose unsaved changes.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Keep Poma open'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Quit anyway'),
              ),
            ],
          ),
        ) ??
        false;
    widget.desktop?.chooseAlerts = () => showDialog<bool>(
      context: _navigator.currentContext!,
      builder: (context) => AlertDialog(
        title: const Text('Completion alerts'),
        content: const Text(
          'Poma can notify you when a phase finishes while it is running, including in the tray. Windows notification settings still apply. Quit stops alerts.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Enable alerts'),
          ),
        ],
      ),
    );
    widget.desktop?.confirmFocusConflict = (conflict) async {
      final desktop = widget.desktop!;
      final navigator = _navigator.currentState!;
      final route = DialogRoute<bool>(
        context: _navigator.currentContext!,
        builder: (context) => AlertDialog(
          scrollable: true,
          title: const Text('Focus overlaps a meeting'),
          content: Text(
            '${conflict.event.title}\n'
            '${DeviceFormats.time(context, conflict.event.startUtc!.toLocal())}'
            '${conflict.additional == 0 ? '' : '\n${conflict.additional} additional overlapping meeting(s).'}'
            '${conflict.stale ? '\nSaved schedule; calendar data may have changed.' : ''}'
            '\nContinue with your full focus duration?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Continue'),
            ),
          ],
        ),
      );
      void changed() {
        if ((desktop.sessionState != 'unlocked' || desktop.isQuitting) &&
            route.isActive) {
          navigator.removeRoute(route, false);
        }
      }

      desktop.addListener(changed);
      try {
        return await navigator.push(route) ?? false;
      } finally {
        desktop.removeListener(changed);
      }
    };
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(reportFirstUsableFrame());
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (widget.desktop == null) {
      widget.controller.setForeground(state == AppLifecycleState.resumed);
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    builder: (context, _) => MaterialApp(
      navigatorKey: _navigator,
      title: 'Poma',
      localizationsDelegates: PomaLocalizations.localizationsDelegates,
      supportedLocales: PomaLocalizations.supportedLocales,
      themeAnimationDuration:
          WidgetsBinding
              .instance
              .platformDispatcher
              .accessibilityFeatures
              .disableAnimations
          ? Duration.zero
          : kThemeAnimationDuration,
      debugShowCheckedModeBanner: false,
      theme: pomaTheme(Brightness.light),
      darkTheme: pomaTheme(Brightness.dark),
      builder: (context, child) => PomaBackdrop(child: child!),
      highContrastTheme: pomaTheme(Brightness.light, highContrast: true),
      highContrastDarkTheme: pomaTheme(Brightness.dark, highContrast: true),
      themeMode: switch (widget.controller.settings.appearance) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      },
      home: widget.desktop == null
          ? AppShell(controller: widget.controller)
          : DesktopScope(
              controller: widget.desktop!,
              child: CallbackShortcuts(
                bindings: {
                  for (var i = 0; i < desktopDestinationOrder.length; i++)
                    SingleActivator(
                      [
                        LogicalKeyboardKey.digit1,
                        LogicalKeyboardKey.digit2,
                        LogicalKeyboardKey.digit3,
                        LogicalKeyboardKey.digit4,
                        LogicalKeyboardKey.digit5,
                        LogicalKeyboardKey.digit6,
                      ][i],
                      control: true,
                    ): () =>
                        widget.desktop!.navigate(desktopDestinationOrder[i]),
                  const SingleActivator(LogicalKeyboardKey.keyN, control: true):
                      widget.desktop!.requestNewTask,
                },
                child: Focus(
                  autofocus: true,
                  child: AppShell(controller: widget.controller),
                ),
              ),
            ),
    ),
  );
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.controller.setForeground(false);
    super.dispose();
  }
}
