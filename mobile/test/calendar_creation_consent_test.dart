import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:poma/application/calendar_connection_controller.dart';
import 'package:poma/data/google_calendar_authorization.dart';
import 'package:poma/domain/focus_blocks.dart';
import 'calendar_connection_test.dart' as f;
import 'calendar_write_consent_test.dart' show AtomicMemory;

class CapabilityAuth extends f.FakeAuthorization
    implements GoogleCapabilityAuthorization {
  Set<String>? requested;
  Future<CalendarAuthorization> Function(Set<String>)? candidate;
  Future<CalendarAuthorization> Function(CalendarCredential)? verification;
  @override
  Future<CalendarAuthorization> authorizeScopes(
    GoogleCalendarConfiguration config,
    Set<String> scopes,
  ) async {
    requested = scopes;
    return candidate == null ? f.grant(scopes: scopes) : candidate!(scopes);
  }

  @override
  Future<CalendarAuthorization> refreshVerified(
    GoogleCalendarConfiguration config,
    CalendarCredential credential,
  ) async => verification == null
      ? f.grant(scopes: credential.scopes, refresh: null)
      : verification!(credential);
}

const generation = '12345678-1234-4234-8234-123456789abc';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  Future<
    (
      CalendarConnectionController,
      AtomicMemory,
      CapabilityAuth,
      f.FakeAuthorization,
    )
  >
  rig({
    bool focus = false,
    bool creation = false,
    bool creationEnabled = true,
  }) async {
    final disk = AtomicMemory()
      ..value = CalendarCredential(
        clientId: f.configured.clientId,
        accountId: 'synthetic-primary',
        refreshToken: 'synthetic-old',
        scopes: {
          ...calendarReadScopes,
          if (focus) focusWriteScope,
          if (creation) calendarCreationScope,
        },
        focusReceipt: focus
            ? const CalendarWriteReceipt(generation: generation, enabled: true)
            : null,
        creationReceipt: creation
            ? CalendarWriteReceipt(
                generation: generation,
                enabled: creationEnabled,
              )
            : null,
      );
    final read = f.FakeAuthorization()
      ..onRefresh = () async => f.grant(scopes: disk.value!.scopes);
    final write = CapabilityAuth();
    final c = CalendarConnectionController(
      configuration: f.configured,
      authorization: read,
      writeAuthorization: write,
      store: disk,
    );
    await c.initialize();
    addTearDown(c.dispose);
    return (c, disk, write, read);
  }

  test(
    'creation from read requests only three applicable scopes and survives protected reload',
    () async {
      final (c, disk, write, _) = await rig();
      await c.enableCreation();
      expect(write.requested, calendarCreationScopes);
      expect(c.creationEnabled, true);
      expect(c.focusWriteEnabled, false);
      expect(c.operationsEnabled, true);
      final restored = CalendarCredential.fromJson(
        jsonDecode(jsonEncode(disk.value!.toJson())),
      );
      expect(restored.creationReceipt!.enabled, true);
      expect(restored.focusReceipt, isNull);
    },
  );
  test(
    'cancellation during credential commit durably disables only the new capability',
    () async {
      final (c, disk, _, _) = await rig(focus: true);
      final before = disk.writes, gate = Completer<void>();
      disk.writeGate = gate;
      final enabling = c.enableCreation();
      for (var i = 0; i < 30 && disk.writes == before; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(disk.writes, greaterThan(before));
      final cancelling = c.cancelCreationConsent();
      gate.complete();
      await enabling;
      await cancelling;
      expect(c.creationEnabled, false);
      expect(c.focusWriteEnabled, true);
      expect(
        CalendarCredential.fromJson(
          disk.value!.toJson(),
        ).creationReceipt!.enabled,
        false,
      );
      expect(c.operationsEnabled, true);
    },
  );
  test(
    'creation upgrade preserves enabled focus receipt, scope, generation and reader',
    () async {
      final (c, disk, write, _) = await rig(focus: true);
      final pending = Completer<CalendarAuthorization>();
      write.candidate = (_) => pending.future;
      final enabled = c.enableCreation();
      expect(c.focusWriteEnabled, true);
      expect(c.operationsEnabled, true);
      pending.complete(
        f.grant(scopes: {...calendarFocusScopes, calendarCreationScope}),
      );
      await enabled;
      expect(write.requested, {...calendarFocusScopes, calendarCreationScope});
      expect(c.focusWriteEnabled, true);
      expect(c.credentialGeneration, generation);
      expect(c.creationEnabled, true);
      final loaded = CalendarCredential.fromJson(disk.value!.toJson());
      expect(loaded.focusReceipt!.generation, generation);
      expect(loaded.creationReceipt!.enabled, true);
    },
  );
  for (final localEnabled in [true, false]) {
    test(
      'focus upgrade preserves independently ${localEnabled ? 'enabled' : 'disabled'} creation receipt',
      () async {
        final (c, disk, write, _) = await rig(
          creation: true,
          creationEnabled: localEnabled,
        );
        await c.enableFocusScheduling();
        expect(write.requested, {...calendarCreationScopes, focusWriteScope});
        expect(c.focusWriteEnabled, true);
        expect(c.creationEnabled, localEnabled);
        expect(disk.value!.creationReceipt!.generation, generation);
        await c.disableFocusScheduling();
        expect(c.creationEnabled, localEnabled);
        expect(c.focusWriteEnabled, false);
        expect(
          CalendarCredential.fromJson(
            disk.value!.toJson(),
          ).creationReceipt!.enabled,
          localEnabled,
        );
      },
    );
  }
  for (final fault in [
    'denied',
    'cancelled',
    'partial',
    'extra',
    'wrong account',
    'missing refresh',
    'candidate refresh',
    'storage',
  ]) {
    test(
      '$fault creation upgrade retains canonical focus/read grant without revocation',
      () async {
        final (c, disk, write, read) = await rig(focus: true);
        final before = disk.value;
        write.candidate = (scopes) async {
          if (fault == 'denied') {
            throw const CalendarConnectionFailure(CalendarFailureKind.denied);
          }
          if (fault == 'cancelled') {
            throw const CalendarConnectionFailure(
              CalendarFailureKind.cancelled,
            );
          }
          return f.grant(
            scopes: fault == 'partial'
                ? calendarFocusScopes
                : fault == 'extra'
                ? {...scopes, 'unexpected'}
                : scopes,
            account: fault == 'wrong account'
                ? 'different'
                : 'synthetic-primary',
            refresh: fault == 'missing refresh' ? null : 'synthetic-candidate',
          );
        };
        if (fault == 'candidate refresh') {
          write.verification = (_) async =>
              throw const CalendarConnectionFailure(
                CalendarFailureKind.network,
              );
        }
        if (fault == 'storage') {
          disk.failWrite = true;
        }
        await c.enableCreation();
        expect(disk.value, same(before));
        expect(c.focusWriteEnabled, true);
        expect(c.operationsEnabled, true);
        expect(c.creationEnabled, false);
        expect(read.revocations, 0);
        expect(write.revocations, 0);
      },
    );
  }
  test(
    'ordinary refresh preserves both receipts and scope loss disables only the affected capability',
    () async {
      final (c, disk, _, read) = await rig(focus: true, creation: true);
      await c.refreshRejectedAccess('synthetic-access');
      expect(c.creationEnabled, true);
      expect(c.focusWriteEnabled, true);
      read.onRefresh = () async => f.grant(scopes: calendarFocusScopes);
      await c.refreshRejectedAccess('synthetic-access');
      expect(c.creationEnabled, false);
      expect(c.focusWriteEnabled, true);
      expect(c.operationsEnabled, true);
      expect(disk.value!.creationReceipt, isNull);
    },
  );
  test(
    'legacy scope-only grant cannot infer creation; old focus v3 remains valid',
    () async {
      final base = f.credential().toJson();
      base['scopes'] = {...calendarFocusScopes, calendarCreationScope}.toList();
      final old = CalendarCredential.fromJson(base);
      expect(old.focusReceipt, isNull);
      expect(old.creationReceipt, isNull);
      final focus = CalendarCredential(
        clientId: f.configured.clientId,
        accountId: 'synthetic-primary',
        refreshToken: 'synthetic',
        scopes: calendarFocusScopes,
        focusReceipt: const CalendarWriteReceipt(
          generation: generation,
          enabled: true,
        ),
      );
      expect(focus.toJson()['version'], 3);
      expect(
        CalendarCredential.fromJson(focus.toJson()).focusReceipt!.enabled,
        true,
      );
    },
  );
  test(
    'combined upgrade rejects late old refresh overwriting either receipt',
    () async {
      final (c, disk, write, read) = await rig(focus: true);
      final candidate = Completer<CalendarAuthorization>(),
          refreshing = Completer<CalendarAuthorization>();
      write.candidate = (_) => candidate.future;
      final enabling = c.enableCreation();
      read.onRefresh = () => refreshing.future;
      final oldRefresh = c.refreshRejectedAccess('synthetic-access');
      candidate.complete(
        f.grant(scopes: {...calendarFocusScopes, calendarCreationScope}),
      );
      await enabling;
      refreshing.complete(f.grant(scopes: calendarFocusScopes));
      await oldRefresh;
      expect(disk.value!.scopes, {
        ...calendarFocusScopes,
        calendarCreationScope,
      });
      expect(c.creationEnabled, true);
      expect(c.focusWriteEnabled, true);
    },
  );
  test(
    'cancel and disconnect invalidate pending creation consent without replacing focus credentials',
    () async {
      final (c, disk, write, _) = await rig(focus: true);
      final before = disk.value;
      final pending = Completer<CalendarAuthorization>();
      write.candidate = (_) => pending.future;
      final enabling = c.enableCreation();
      await c.cancelCreationConsent();
      pending.complete(
        f.grant(scopes: {...calendarFocusScopes, calendarCreationScope}),
      );
      await enabling;
      expect(disk.value, same(before));
      expect(c.focusWriteEnabled, true);
      expect(c.creationEnabled, false);
      final next = Completer<CalendarAuthorization>();
      write.candidate = (_) => next.future;
      final reconnecting = c.enableCreation();
      await c.disconnect();
      next.complete(
        f.grant(scopes: {...calendarFocusScopes, calendarCreationScope}),
      );
      await reconnecting;
      expect(disk.value, isNull);
      expect(c.creationEnabled, false);
      expect(c.focusWriteEnabled, false);
    },
  );
  for (final scopes in [
    calendarCreationScopes,
    {...calendarFocusScopes, calendarCreationScope},
  ]) {
    test(
      'Desktop full-set ${scopes.length}-scope flow validates raw evidence and same-lineage refresh omission',
      () async {
        final browser = f.CapturingBrowser();
        var refreshing = false;
        final provider = DesktopGoogleAuthorization(
          browser: browser,
          clientFactory: () => MockClient((request) async {
            if (request.url.host == 'oauth2.googleapis.com') {
              return f.tokenResponse(
                scope: refreshing ? null : scopes.join(' '),
                refresh: refreshing ? null : 'synthetic-candidate',
              );
            }
            return http.Response(
              jsonEncode({'id': 'synthetic-primary', 'primary': true}),
              200,
            );
          }),
        );
        addTearDown(provider.dispose);
        final authorizing = provider.authorizeScopes(f.configured, scopes);
        final url = await browser.opened.future;
        expect(url.queryParameters['scope']!.split(' ').toSet(), scopes);
        expect(
          url.queryParameters.containsKey('include_granted_scopes'),
          false,
        );
        await f.callback(url);
        final candidate = await authorizing;
        refreshing = true;
        final result = await provider.refreshVerified(
          f.configured,
          CalendarCredential(
            clientId: f.configured.clientId,
            accountId: candidate.accountId,
            refreshToken: candidate.refreshToken!,
            scopes: candidate.scopes,
          ),
        );
        expect(result.scopes, scopes);
        expect(result.refreshToken, 'synthetic-candidate');
      },
    );
  }
  for (final evidence in <String?>[
    null,
    'unexpected',
    calendarReadScopes.join(' '),
  ]) {
    test(
      'raw creation token evidence $evidence cannot default to the requested grant',
      () async {
        final browser = f.CapturingBrowser();
        final provider = DesktopGoogleAuthorization(
          browser: browser,
          clientFactory: () =>
              MockClient((_) async => f.tokenResponse(scope: evidence)),
        );
        addTearDown(provider.dispose);
        final future = provider.authorizeScopes(
          f.configured,
          calendarCreationScopes,
        );
        final asserted = expectLater(
          future,
          throwsA(isA<CalendarConnectionFailure>()),
        );
        final url = await browser.opened.future;
        await f.callback(url);
        await asserted;
      },
    );
  }
}
