"""Extract Poma-only scheduling, resident memory and frame evidence from Perfetto."""

import argparse
import csv
import hashlib
import io
import json
import math
from pathlib import Path
import subprocess


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--processor', required=True, type=Path)
    parser.add_argument('--rtk', default='rtk')
    parser.add_argument('--package', default='dev.poma.poma')
    parser.add_argument('--trace', required=True, type=Path)
    parser.add_argument('--output', required=True, type=Path)
    args = parser.parse_args()
    if args.output.exists():
        parser.error('Choose a fresh evidence directory')
    args.output.mkdir(parents=True)
    package = args.package.replace("'", "''")
    match = f"(p.name='{package}' OR p.name GLOB '{package}:*')"

    def query(name, sql):
        (args.output / f'{name}.sql').write_text(sql + '\n', encoding='utf-8')
        result = subprocess.run([args.rtk, 'proxy', str(args.processor), 'query', str(args.trace), sql], capture_output=True, text=True, encoding='utf-8', errors='replace', timeout=120)
        (args.output / f'{name}.csv').write_text(result.stdout, encoding='utf-8')
        (args.output / f'{name}.log').write_text(result.stderr, encoding='utf-8')
        if result.returncode:
            raise RuntimeError(result.stderr + result.stdout)
        return list(csv.DictReader(io.StringIO(result.stdout)))

    bounds = query('bounds', 'SELECT start_ts,end_ts,(end_ts-start_ts)/1e9 AS seconds FROM trace_bounds')
    timing = query('collection_window', "SELECT name,int_value FROM metadata WHERE name IN ('tracing_started_ns','tracing_disabled_ns')")
    timing = {row['name']: int(row['int_value']) for row in timing}
    start = timing.get('tracing_started_ns', int(bounds[0]['start_ts']))
    end = timing.get('tracing_disabled_ns', int(bounds[0]['end_ts']))
    overlap = f's.ts<{end} AND s.ts+s.dur>{start}'
    duration = f'MIN(s.ts+s.dur,{end})-MAX(s.ts,{start})'
    cpu = query('cpu', f'SELECT p.pid,p.name,SUM({duration})/1e6 AS cpu_ms,COUNT(*) AS scheduled_slices FROM process p JOIN thread t USING(upid) JOIN sched s USING(utid) WHERE {match} AND s.dur>0 AND {overlap} GROUP BY p.upid')
    threads = query('threads', f'SELECT p.pid,t.tid,t.name,SUM({duration})/1e6 AS cpu_ms,COUNT(*) AS scheduled_slices FROM process p JOIN thread t USING(upid) JOIN sched s USING(utid) WHERE {match} AND s.dur>0 AND {overlap} GROUP BY t.utid ORDER BY cpu_ms DESC')
    memory = query('memory', f'SELECT p.pid,t.name,c.ts,c.value FROM process_counter_track t JOIN process p USING(upid) JOIN counter c ON c.track_id=t.id WHERE {match} AND c.ts BETWEEN {start} AND {end} AND t.name IN (\'mem.rss\',\'mem.locked\',\'mem.swap\') ORDER BY c.ts')
    frames = query('frames', f'SELECT f.ts,f.dur/1e6 AS duration_ms,f.layer_name,f.surface_frame_token,f.jank_type,f.on_time_finish,f.present_type FROM actual_frame_timeline_slice f JOIN process p USING(upid) WHERE {match} AND f.ts>={start} AND f.ts+f.dur<={end} AND f.surface_frame_token>0 AND f.dur>0 ORDER BY f.ts')
    counters = query('counter_names', f'SELECT DISTINCT t.name FROM process_counter_track t JOIN process p USING(upid) WHERE {match}')
    health = query('health', "SELECT name,severity,value FROM stats WHERE value>0 AND severity IN ('error','data_loss')")
    seconds = (end-start)/1e9
    durations = sorted(float(row['duration_ms']) for row in frames)
    def percentile(p):
        return durations[max(0, math.ceil(len(durations) * p / 100) - 1)] if durations else None
    rss = [float(row['value']) for row in memory if row['name'] == 'mem.rss']
    cpu_ms = sum(float(row['cpu_ms']) for row in cpu)
    report = {
        'trace': {'path': str(args.trace.resolve()), 'sha256': hashlib.sha256(args.trace.read_bytes()).hexdigest()},
        'processor': {'path': str(args.processor.resolve()), 'sha256': hashlib.sha256(args.processor.read_bytes()).hexdigest()},
        'collectionWindow': {'startNs': start, 'endNs': end, 'serviceMetadataAvailable': len(timing)==2},
        'seconds': seconds, 'cpuMs': cpu_ms, 'oneCoreCpuPercent': cpu_ms / (seconds * 1000) * 100,
        'processes': cpu, 'threads': threads,
        'processRssBytes': {'samples': len(rss), 'minimum': min(rss) if rss else None, 'maximum': max(rss) if rss else None},
        'frames': {'samples': len(durations), 'p50Ms': percentile(50), 'p95Ms': percentile(95), 'p99Ms': percentile(99), 'above16_67Ms': sum(x>16.67 for x in durations), 'jankTypes': sorted({x['jank_type'] for x in frames})},
        'availableProcessCounters': counters, 'traceHealth': health,
        'limitations': [
            'Connected instrumented interval; state and exact APK hash require the companion metadata/UI observations.',
            'CPU percent is total scheduled Poma CPU time divided by wall time on one core; it is not whole-device CPU or energy.',
            'Collection uses tracing-service start/disable timestamps. Raw trace bounds can include historical process metadata outside this interval.',
            'Process RSS counters exclude some driver-accounted graphics allocations. Android dumpsys RSS/PSS/Graphics are separate observations.',
            'FrameTimeline durations include scheduling/presentation and are not Dart build or raster CPU times.',
            'No frames in an unchanged idle screen is not a frame-performance pass.',
            'Available process counters and trace health delimit I/O/wake evidence; absent counters do not prove zero writes.',
            'Power rails or battery counters on USB do not establish unplugged app energy.'
        ],
    }
    (args.output / 'summary.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
    print(json.dumps(report))


if __name__ == '__main__':
    main()
