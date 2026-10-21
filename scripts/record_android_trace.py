"""Record a bounded OS trace, not an app timer or disconnected acceptance run."""

import argparse
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import subprocess


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--adb', required=True)
    parser.add_argument('--rtk', default='rtk')
    parser.add_argument('--serial', required=True)
    parser.add_argument('--package', default='dev.poma.poma')
    parser.add_argument('--state', required=True)
    parser.add_argument('--artifact', type=Path, help='Exact installed release APK for hash binding')
    parser.add_argument('--seconds', type=int, default=40)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    if args.seconds < 1:
        parser.error('seconds must be positive')
    if args.output.exists():
        parser.error('choose a fresh evidence directory')
    args.output.mkdir(parents=True)

    def adb(*parts, check=True, timeout=120, input_text=None):
        result = subprocess.run([args.rtk, 'proxy', args.adb, '-s', args.serial, *parts], input=input_text, capture_output=True, text=True, encoding='utf-8', errors='replace', timeout=timeout)
        if check and result.returncode:
            raise RuntimeError(result.stdout + result.stderr)
        return result.stdout + result.stderr

    def snapshot(label):
        pid = adb('shell', 'pidof', args.package, check=False).strip()
        return {
            'pid': pid,
            'meminfo': adb('shell', 'dumpsys', 'meminfo', args.package, check=False),
            'battery': adb('shell', 'dumpsys', 'battery'),
            'thermal': adb('shell', 'dumpsys', 'thermalservice'),
            'label': label,
        }

    config = '''buffers { size_kb: 32768 fill_policy: RING_BUFFER }
duration_ms: DURATION
data_sources { config { name: "linux.ftrace" ftrace_config {
  ftrace_events: "sched/sched_switch"
  ftrace_events: "sched/sched_waking"
  ftrace_events: "power/suspend_resume"
  ftrace_events: "power/wakeup_source_activate"
  ftrace_events: "power/wakeup_source_deactivate"
  atrace_categories: "am"
  atrace_categories: "wm"
  atrace_categories: "gfx"
  atrace_categories: "view"
  atrace_apps: "PACKAGE"
} } }
data_sources { config { name: "linux.process_stats" process_stats_config {
  scan_all_processes_on_start: true
  record_thread_names: true
  proc_stats_poll_ms: 1000
} } }
data_sources { config { name: "android.surfaceflinger.frametimeline" } }
data_sources { config { name: "android.power" android_power_config {
  battery_poll_ms: 1000
  battery_counters: BATTERY_COUNTER_CHARGE
  battery_counters: BATTERY_COUNTER_CURRENT
  battery_counters: BATTERY_COUNTER_CAPACITY_PERCENT
  collect_power_rails: true
} } }
'''.replace('DURATION', str(args.seconds * 1000)).replace('PACKAGE', args.package)
    config_path = args.output / 'config.pbtxt'
    config_path.write_text(config, encoding='utf-8')
    token = args.output.name
    if not token.replace('-', '').replace('_', '').isalnum():
        parser.error('output directory name must contain only letters, digits, hyphens or underscores')
    remote_trace = f'/data/misc/perfetto-traces/poma-{token}.pftrace'
    record = {'recordedUtc': datetime.now(timezone.utc).isoformat(), 'collector': 'record_android_trace.py/1', 'package': args.package, 'serial': args.serial, 'declaredState': args.state, 'requestedSeconds': args.seconds, 'devicePerfettoVersion': adb('shell', 'perfetto', '--version'), 'before': snapshot('before'), 'limitations': ['State is declared by the operator and must be corroborated with UI/lifecycle evidence.', 'This is a connected OS-instrumented run, not disconnected acceptance.', 'The OS collector samples process/battery counters once per second; that is measurement overhead, not app-managed polling.', 'Raw local traces may contain system and other-process scheduling metadata; shared summaries must select Poma only.', 'USB-powered counters cannot establish unplugged app energy or battery savings.']}
    metadata = args.output / 'metadata.json'
    if args.artifact:
        data = args.artifact.read_bytes()
        record['artifact'] = {'path': str(args.artifact.resolve()), 'bytes': len(data), 'sha256': hashlib.sha256(data).hexdigest()}
    metadata.write_text(json.dumps(record, indent=2) + '\n', encoding='utf-8')
    # The traced service cannot read shell-owned /data/local/tmp on all devices.
    capture = adb('shell', 'perfetto', '--txt', '-c', '-', '-o', remote_trace, input_text=config, timeout=args.seconds + 120)
    (args.output / 'capture.log').write_text(capture, encoding='utf-8')
    trace = args.output / 'trace.pftrace'
    adb('pull', remote_trace, str(trace.resolve()))
    record['after'] = snapshot('after')
    record['trace'] = {'bytes': trace.stat().st_size, 'sha256': hashlib.sha256(trace.read_bytes()).hexdigest()}
    metadata.write_text(json.dumps(record, indent=2) + '\n', encoding='utf-8')
    print(json.dumps({'state': args.state, 'output': str(args.output), 'trace': record['trace']}), flush=True)


if __name__ == '__main__':
    main()
