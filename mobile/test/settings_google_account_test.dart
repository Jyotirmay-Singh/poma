import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poma/application/app_controller.dart';
import 'package:poma/application/calendar_connection_controller.dart';
import 'package:poma/application/calendar_controller.dart';
import 'package:poma/application/desktop_controller.dart';
import 'package:poma/domain/models.dart';
import 'package:poma/main.dart';

import 'calendar_connection_test.dart' as calendar;
import 'contrast_support.dart';
import 'desktop_test.dart' show FakeShell;
import 'support.dart';

const accountEmail = 'jules@example.com';

void main() {
  Future<
    ({
      AppController app,
      DesktopController desktop,
      CalendarConnectionController connection,
      calendar.FakeAuthorization authorization,
      calendar.MemoryCredentials store,
      FakeShell shell,
    })
  >
  mount(
    WidgetTester tester, {
    bool signedIn = false,
    String email = accountEmail,
    String appearance = 'light',
    String sessionState = 'unlocked',
    Size size = const Size(1080, 1000),
    double scale = 1,
    bool highContrast = false,
    GoogleCalendarConfiguration configuration = calendar.configured,
    CalendarConnectionStatus? status,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        FakeAccessibilityFeatures(highContrast: highContrast);
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    final app = await AppController.create(
      MemoryRepository(
        SavedState(settings: TimerSettings(appearance: appearance)),
      ),
      clock: FakeClock(),
    );
    final store = calendar.MemoryCredentials();
    final authorization = calendar.FakeAuthorization();
    authorization.onAuthorize = () async => calendar.grant(account: email);
    authorization.onRefresh = () async =>
        calendar.grant(account: email, refresh: null);
    final connection = CalendarConnectionController(
      configuration: configuration,
      authorization: authorization,
      store: store,
    );
    await connection.initialize();
    if (signedIn) await connection.connect();
    final shell = FakeShell();
    final desktop = DesktopController(
      app,
      shell,
      DesktopEnvironment(
        dataDirectory: 'synthetic-account-profile',
        version: 'test',
        packaged: false,
        sessionState: sessionState,
      ),
      calendar: CalendarController(scheduleUpdates: false),
      connection: connection,
    );
    await desktop.initialize();
    if (status != null) connection.status = status;
    addTearDown(() {
      desktop.dispose();
      app.dispose();
    });
    await tester.pumpWidget(
      RepaintBoundary(
        key: const ValueKey('account-preview'),
        child: PomaApp(controller: app, desktop: desktop),
      ),
    );
    desktop.navigate(3);
    await tester.pumpAndSettle();
    return (
      app: app,
      desktop: desktop,
      connection: connection,
      authorization: authorization,
      store: store,
      shell: shell,
    );
  }

  Future<void> capture(WidgetTester tester, String name) async {
    const directory = String.fromEnvironment('POMA_ACCOUNT_SCREENSHOTS');
    if (directory.isEmpty) return;
    await tester.runAsync(
      () => precacheImage(
        const AssetImage('assets/branding/google-g.png'),
        tester.element(find.byKey(const ValueKey('settings-google-account'))),
      ),
    );
    await tester.pumpAndSettle();
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('account-preview')),
    );
    await tester.runAsync(() async {
      final picture = await boundary.toImage();
      final bytes = await picture.toByteData(format: ui.ImageByteFormat.png);
      final file = File('$directory/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      picture.dispose();
    });
  }

  testWidgets('Settings signs in through the shared Google connection', (
    tester,
  ) async {
    final fixture = await mount(tester);
    expect(find.text('Google account'), findsOneWidget);
    expect(find.text('Signed out'), findsOneWidget);
    expect(find.text(accountEmail), findsNothing);
    await capture(tester, 'signed-out-light');

    await tester.tap(find.byKey(const ValueKey('settings-google-sign-in')));
    await tester.pumpAndSettle();
    expect(fixture.authorization.authorizations, 1);
    expect(fixture.connection.status, CalendarConnectionStatus.connected);
    expect(fixture.desktop.connection, same(fixture.connection));
    expect(fixture.store.value?.accountId, accountEmail);
    expect(find.text(accountEmail), findsOneWidget);
    expect(find.text('Connected'), findsOneWidget);
    expect(find.text('Used by Calendar and Day Clock.'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('settings-google-manage-calendars')),
    );
    await tester.pumpAndSettle();
    expect(fixture.desktop.destination, 4);
    expect(fixture.desktop.calendarSection, CalendarPageSection.settings);
    expect(
      find.byKey(const ValueKey('google-calendar-status')),
      findsOneWidget,
    );
  });

  testWidgets('account menu switches and signs out using the same controller', (
    tester,
  ) async {
    final fixture = await mount(tester, signedIn: true, appearance: 'dark');
    await capture(tester, 'connected-dark');
    await tester.tap(
      find.byKey(const ValueKey('settings-google-account-menu')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Switch account'), findsOneWidget);
    expect(find.text('Sign out'), findsOneWidget);
    await capture(tester, 'account-menu-dark');
    fixture.authorization.onAuthorize = () async =>
        calendar.grant(account: 'alex@example.com');
    await tester.tap(find.text('Switch account'));
    await tester.pumpAndSettle();
    expect(fixture.authorization.authorizations, 2);
    expect(fixture.connection.verifiedAccountLabel, 'alex@example.com');
    expect(fixture.store.purges.last, isTrue);
    expect(find.text(accountEmail), findsNothing);
    expect(find.text('alex@example.com'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('settings-google-account-menu')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    expect(fixture.connection.status, CalendarConnectionStatus.disconnected);
    expect(fixture.authorization.revocations, 1);
    expect(fixture.store.value, isNull);
    expect(find.text('alex@example.com'), findsNothing);
    expect(find.text('Signed out'), findsOneWidget);
    expect(
      find.textContaining('Google revocation could not be confirmed'),
      findsOneWidget,
    );
  });

  testWidgets('pending sign-in can be cancelled and late results are ignored', (
    tester,
  ) async {
    final fixture = await mount(tester);
    final authorization = Completer<CalendarAuthorization>();
    fixture.authorization.onAuthorize = () => authorization.future;
    await tester.tap(find.byKey(const ValueKey('settings-google-sign-in')));
    await tester.pump();
    expect(find.text('Signing in…'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('settings-google-cancel')));
    await tester.pumpAndSettle();
    authorization.complete(calendar.grant(account: accountEmail));
    await tester.pumpAndSettle();
    expect(fixture.authorization.cancellations, greaterThan(0));
    expect(fixture.store.value, isNull);
    expect(find.text(accountEmail), findsNothing);
    expect(find.text('Signed out'), findsOneWidget);
  });

  testWidgets('sign-out hides identity while Google revocation is pending', (
    tester,
  ) async {
    final fixture = await mount(tester, signedIn: true);
    final revocation = Completer<bool>();
    fixture.authorization.onRevoke = () => revocation.future;
    await tester.tap(
      find.byKey(const ValueKey('settings-google-account-menu')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign out'));
    await tester.pump();
    expect(find.text(accountEmail), findsNothing);
    expect(find.text('Signing out…'), findsOneWidget);
    expect(find.byKey(const ValueKey('settings-google-sign-in')), findsNothing);

    revocation.complete(true);
    await tester.pumpAndSettle();
    expect(find.text('Signed out'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('settings-google-sign-in')),
      findsOneWidget,
    );
    expect(fixture.store.value, isNull);
  });

  testWidgets('failed local sign-out offers a working cleanup retry', (
    tester,
  ) async {
    final fixture = await mount(tester, signedIn: true);
    fixture.store.failClear = true;
    await tester.tap(
      find.byKey(const ValueKey('settings-google-account-menu')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    expect(find.text(accountEmail), findsNothing);
    expect(find.text('Needs attention'), findsOneWidget);
    expect(find.text(fixture.connection.message!), findsOneWidget);
    expect(find.byKey(const ValueKey('settings-google-sign-in')), findsNothing);

    fixture.store.failClear = false;
    await tester.tap(
      find.byKey(const ValueKey('settings-google-retry-sign-out')),
    );
    await tester.pumpAndSettle();
    expect(fixture.connection.cleanupPending, isFalse);
    expect(fixture.store.value, isNull);
    expect(find.text('Signed out'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('settings-google-sign-in')),
      findsOneWidget,
    );
  });

  testWidgets('Windows lock immediately hides a previously visible account', (
    tester,
  ) async {
    final fixture = await mount(tester, signedIn: true);
    expect(find.text(accountEmail), findsOneWidget);
    await fixture.shell.onEvent!('sessionState', {'state': 'locked'});
    await tester.pumpAndSettle();
    expect(find.text(accountEmail), findsNothing);
    expect(find.text('Account hidden'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('settings-google-account-menu')),
      findsNothing,
    );

    await fixture.shell.onEvent!('sessionState', {'state': 'unlocked'});
    await tester.pumpAndSettle();
    expect(find.text(accountEmail), findsOneWidget);
    expect(fixture.authorization.authorizations, 1);
  });

  testWidgets('sign-in errors stay visible beside the Google action', (
    tester,
  ) async {
    final fixture = await mount(tester);
    fixture.authorization.onAuthorize = () async =>
        throw const CalendarConnectionFailure(CalendarFailureKind.denied);
    await tester.tap(find.byKey(const ValueKey('settings-google-sign-in')));
    await tester.pumpAndSettle();
    expect(fixture.connection.message, isNotNull);
    expect(find.text(fixture.connection.message!), findsOneWidget);
    expect(
      find.byKey(const ValueKey('settings-google-sign-in')),
      findsOneWidget,
    );
    expect(find.text(accountEmail), findsNothing);
  });

  testWidgets('unconfigured builds offer the existing Calendar setup page', (
    tester,
  ) async {
    final fixture = await mount(
      tester,
      configuration: const GoogleCalendarConfiguration(),
    );
    expect(find.text('Setup required'), findsOneWidget);
    expect(
      find.text('Google sign-in needs setup in this build.'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('settings-google-sign-in')), findsNothing);
    await tester.tap(
      find.byKey(const ValueKey('settings-google-manage-calendars')),
    );
    await tester.pumpAndSettle();
    expect(fixture.authorization.authorizations, 0);
    expect(fixture.desktop.calendarSection, CalendarPageSection.settings);
  });

  for (final sessionState in ['locked', 'unknown']) {
    testWidgets(
      'account identity and actions are hidden when Windows is $sessionState',
      (tester) async {
        final fixture = await mount(
          tester,
          signedIn: true,
          sessionState: sessionState,
        );
        expect(find.text(accountEmail), findsNothing);
        expect(find.text('Account hidden'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('settings-google-account-menu')),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey('settings-google-manage-calendars')),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey('settings-google-sign-in')),
          findsNothing,
        );
        expect(fixture.authorization.authorizations, 1);
      },
    );
  }

  for (final status in <CalendarConnectionStatus, String>{
    CalendarConnectionStatus.offline: 'Offline',
    CalendarConnectionStatus.reconnectRequired: 'Sign-in required',
    CalendarConnectionStatus.incompletePermissions: 'Permission needed',
    CalendarConnectionStatus.storageError: 'Needs attention',
    CalendarConnectionStatus.unavailable: 'Needs attention',
  }.entries) {
    testWidgets('Settings shows the saved account during ${status.key.name}', (
      tester,
    ) async {
      await mount(tester, signedIn: true, status: status.key);
      expect(find.text(accountEmail), findsOneWidget);
      expect(find.text(status.value), findsOneWidget);
      expect(find.text('Connected'), findsNothing);
      expect(
        find.byKey(const ValueKey('settings-google-sign-in')),
        findsOneWidget,
      );
    });
  }

  for (final appearance in ['light', 'dark']) {
    for (final highContrast in [false, true]) {
      for (final size in [const Size(640, 1000), const Size(1080, 1000)]) {
        for (final scale in [1.0, 2.0]) {
          testWidgets(
            'Google account $appearance highContrast=$highContrast width=${size.width} text=$scale',
            (tester) async {
              final semantics = tester.ensureSemantics();
              const email =
                  'very.long.google.account.name.for.accessibility@example.com';
              await mount(
                tester,
                signedIn: true,
                email: email,
                appearance: appearance,
                size: size,
                scale: scale,
                highContrast: highContrast,
              );
              expect(find.text(email), findsOneWidget);
              expect(tester.takeException(), isNull);
              await expectLater(
                tester,
                meetsGuideline(androidTapTargetGuideline),
              );
              await expectLater(
                tester,
                meetsGuideline(labeledTapTargetGuideline),
              );
              await expectLater(
                tester,
                meetsGuideline(
                  RenderedTextContrastGuideline(
                    finder: find.descendant(
                      of: find.byKey(const ValueKey('settings-google-account')),
                      matching: find.byType(Text),
                    ),
                  ),
                ),
              );
              if (!highContrast) {
                await capture(
                  tester,
                  'connected-$appearance-${size.width.toInt()}-${scale.toInt()}x',
                );
              }
              semantics.dispose();
            },
          );
        }
      }
    }
  }
}
