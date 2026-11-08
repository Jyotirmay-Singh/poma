import 'package:flutter_test/flutter_test.dart';
import 'package:focus_sound_spike/lease_gate.dart';

void main() {
  test('an interruption crossing the real deadline cannot resume', () {
    var elapsed = 100;
    final gate = LeaseGate(() => elapsed);
    final ticket = gate.bind('focus-a', 1, 200);
    expect(gate.allows(ticket, 'focus-a', 1), isTrue);
    elapsed = 200;
    expect(gate.allows(ticket, 'focus-a', 1), isFalse);
  });
  test('same run after resume rejects the previous segment and ticket', () {
    final gate = LeaseGate(() => 100);
    final old = gate.bind('focus-a', 1, 200);
    final current = gate.bind('focus-a', 2, 300);
    expect(gate.allows(old, 'focus-a', 1), isFalse);
    expect(gate.allows(current, 'focus-a', 2), isTrue);
  });
  test('Off/mute/reset/disposal revocation defeats a late callback', () {
    final gate = LeaseGate(() => 100);
    final old = gate.bind('focus-a', 1, 200);
    gate.revoke();
    expect(gate.allows(old, 'focus-a', 1), isFalse);
    final next = gate.bind('focus-b', 1, 400);
    expect(gate.allows(old, 'focus-a', 1), isFalse);
    expect(gate.allows(next, 'focus-b', 1), isTrue);
  });
}
