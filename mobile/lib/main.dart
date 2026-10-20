import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'application/app_controller.dart';
import 'application/local_repository.dart';
import 'data/local_repository.dart';
import 'data/local_storage_policy.dart';
import 'data/timer_clock.dart';
import 'data/local_alerts.dart';
import 'application/local_alerts.dart';
import 'domain/timer_engine.dart';
import 'ui/app_shell.dart';
import 'ui/theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks([
      'Pomatez',
    ], await rootBundle.loadString('assets/licenses/pomatez.txt'));
  });
  runApp(const PomaLoader());
}

class PomaLoader extends StatefulWidget {
  const PomaLoader({
    super.key,
    this.repositoryFactory,
    this.clockFactory,
    this.alertsFactory,
  });

  final LocalRepository Function()? repositoryFactory;
  final TimerClock Function()? clockFactory;
  final LocalAlerts Function()? alertsFactory;
  @override
  State<PomaLoader> createState() => _PomaLoaderState();
}

class _PomaLoaderState extends State<PomaLoader> {
  late Future<AppController> _loading;
  LocalRepository? _repository;
  AppController? _controller;
  @override
  void initState() {
    super.initState();
    _loading = _load();
  }

  Future<AppController> _load() async {
    await _repository?.close();
    final repository = widget.repositoryFactory?.call() ?? SqliteRepository();
    _repository = repository;
    return _controller = await AppController.create(
      repository,
      clock: widget.clockFactory?.call() ?? NativeTimerClock(),
      alerts:
          widget.alertsFactory?.call() ??
          (widget.repositoryFactory == null ? NativeLocalAlerts() : null),
    );
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<AppController>(
    future: _loading,
    builder: (context, snapshot) {
      if (snapshot.hasData) return PomaApp(controller: snapshot.data!);
      return MaterialApp(
        title: 'Poma',
        debugShowCheckedModeBanner: false,
        theme: pomaTheme(Brightness.light),
        home: Scaffold(
          body: SafeArea(
            child: Center(
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
                                ? 'Timer time could not be read. Try again. Your data is kept.'
                                : snapshot.error
                                      is LocalStoragePreparationException
                                ? 'Local storage privacy settings could not be applied.'
                                : 'Your saved data could not be opened.',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Try again. Your existing data will be kept.',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 20),
                          FilledButton(
                            onPressed: () => setState(() {
                              _loading = _load();
                            }),
                            child: const Text('Try again'),
                          ),
                        ],
                      )
                    : const CircularProgressIndicator(
                        semanticsLabel: 'Opening Poma',
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
  const PomaApp({required this.controller, super.key});
  final AppController controller;
  @override
  State<PomaApp> createState() => _PomaAppState();
}

class _PomaAppState extends State<PomaApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.controller.setForeground(
      WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) =>
      widget.controller.setForeground(state == AppLifecycleState.resumed);
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    builder: (context, _) => MaterialApp(
      title: 'Poma',
      debugShowCheckedModeBanner: false,
      theme: pomaTheme(Brightness.light),
      darkTheme: pomaTheme(Brightness.dark),
      themeMode: switch (widget.controller.settings.appearance) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      },
      home: AppShell(controller: widget.controller),
    ),
  );
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.controller.setForeground(false);
    super.dispose();
  }
}
