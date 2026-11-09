"""Reuse the isolated measurement procedure without replacing historical data."""
import measure_focus_sounds_session2 as measurement

if __name__ == '__main__':
    measurement.OUT = measurement.ROOT / 'artifacts/focus-sounds/session-4'
    measurement.OUT.mkdir(parents=True, exist_ok=True)
    raise SystemExit(measurement.main())
