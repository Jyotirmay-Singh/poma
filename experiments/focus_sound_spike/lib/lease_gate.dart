/// Experiment-only authorization gate, not another countdown or timer owner.
class LeaseGate {
  LeaseGate(this.nowMicros);
  final int Function() nowMicros;
  int _generation = 0;
  String? _run;
  int? _segment;
  int? _deadline;

  int bind(String run, int segment, int deadlineMicros) {
    _run = run;
    _segment = segment;
    _deadline = deadlineMicros;
    return ++_generation;
  }

  void revoke() {
    _generation++;
    _run = null;
  }

  bool allows(int generation, String run, int segment) =>
      generation == _generation &&
      run == _run &&
      segment == _segment &&
      _deadline != null &&
      nowMicros() < _deadline!;
}
