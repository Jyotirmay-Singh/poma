"""Run a copied review build with its own native identity and profile only."""
import ctypes as c
from datetime import datetime
from ctypes import wintypes as w
import hashlib
import json
from pathlib import Path
import shutil
import statistics
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'artifacts/focus-sounds/session-2'

class Memory(c.Structure):
    _fields_ = [('cb', w.DWORD), ('PageFaultCount', w.DWORD)] + [(name, c.c_size_t) for name in
        ('PeakWorkingSetSize', 'WorkingSetSize', 'QuotaPeakPagedPoolUsage', 'QuotaPagedPoolUsage',
         'QuotaPeakNonPagedPoolUsage', 'QuotaNonPagedPoolUsage', 'PagefileUsage', 'PeakPagefileUsage', 'PrivateUsage')]

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

class ThreadEntry(c.Structure):
    _fields_ = [('size', w.DWORD), ('usage', w.DWORD), ('id', w.DWORD), ('owner', w.DWORD),
               ('priority', w.LONG), ('delta', w.LONG), ('flags', w.DWORD)]

def thread_count(pid):
    create = c.windll.kernel32.CreateToolhelp32Snapshot
    create.restype = w.HANDLE
    snapshot = create(4, 0)
    if snapshot == c.c_void_p(-1).value: return None
    row = ThreadEntry(); row.size = c.sizeof(row)
    count = 0
    try:
        present = c.windll.kernel32.Thread32First(w.HANDLE(snapshot), c.byref(row))
        while present:
            if row.owner == pid: count += 1
            present = c.windll.kernel32.Thread32Next(w.HANDLE(snapshot), c.byref(row))
        return count
    finally:
        c.windll.kernel32.CloseHandle(w.HANDLE(snapshot))

def main():
    source_arg = next((x.split('=', 1)[1] for x in sys.argv if x.startswith('--source=')),
                      'mobile/build/windows/x64/runner/Release')
    source = (ROOT / source_arg).resolve()
    assert ROOT in source.parents, 'Review source must stay within this workspace'
    # Fail before launching if the special native build/isolation was not selected.
    binary = (source / 'poma.exe').read_bytes()
    assert 'Poma.FocusAudioReview.Session2'.encode('utf-16le') in binary, 'Build the isolated review target first'
    run = OUT / ('run-' + str(time.time_ns()))
    bundle = run / 'runtime'
    shutil.copytree(source, bundle, ignore=shutil.ignore_patterns('fictional-review-profile'))
    samples = []
    profile = bundle / 'fictional-review-profile'
    measured = '--measure' in sys.argv
    started = time.monotonic()
    with (run / 'runtime.log').open('w', encoding='utf-8') as output:
        child = subprocess.Popen([str(bundle / 'poma.exe'), '--startup', '--self-test'] + (['--measure'] if measured else []),
            cwd=bundle, stdout=output, stderr=subprocess.STDOUT)
        handle = w.HANDLE(int(child._handle))
        try:
            while child.poll() is None:
                elapsed = time.monotonic() - started
                if elapsed > 600:
                    raise TimeoutError('Owned review process exceeded ten minutes')
                phase = 'qualification'
                try:
                    state = json.loads((profile / 'session2-phase.json').read_text())
                    # A phase's label remains on disk while later qualification
                    # runs. Do not count that subsequent playback as idle time.
                    phase_started = datetime.fromisoformat(state['utc']).timestamp()
                    if 0 <= time.time() - phase_started <= state['seconds']:
                        phase = state['phase']
                except (OSError, ValueError): pass
                memory = Memory(); memory.cb = c.sizeof(memory)
                creation, end, kernel, user = (w.FILETIME() for _ in range(4))
                handles = w.DWORD()
                if c.windll.psapi.GetProcessMemoryInfo(handle, c.byref(memory), memory.cb) and c.windll.kernel32.GetProcessTimes(handle, c.byref(creation), c.byref(end), c.byref(kernel), c.byref(user)):
                    c.windll.kernel32.GetProcessHandleCount(handle, c.byref(handles))
                    cpu = ((kernel.dwHighDateTime << 32) + kernel.dwLowDateTime + (user.dwHighDateTime << 32) + user.dwLowDateTime) / 10000000
                    samples.append(dict(elapsed_seconds=elapsed, phase=phase, cpu_seconds=cpu,
                        working_set_bytes=memory.WorkingSetSize, private_bytes=memory.PrivateUsage, handles=handles.value,
                        threads=thread_count(child.pid)))
                time.sleep(.5)
        except Exception:
            child.kill()  # Only the process just created above.
            child.wait()
            raise
    report_path = profile / 'session2-runtime.json'
    report = json.loads(report_path.read_text()) if report_path.exists() else {'passed': False, 'failure': 'No runtime report'}
    cold = None
    if report.get('passed'):
        with (run / 'cold.log').open('w', encoding='utf-8') as output:
            second = subprocess.Popen([str(bundle / 'poma.exe'), '--startup', '--verify-cold'], cwd=bundle, stdout=output, stderr=subprocess.STDOUT)
            try: second.wait(timeout=30)
            except subprocess.TimeoutExpired:
                second.kill(); second.wait(); raise
        path = profile / 'session2-cold.json'
        cold = json.loads(path.read_text()) if path.exists() else {'passed': False, 'failure': 'No cold report'}
    summary = {}
    for name in ('off-idle', 'playing', 'post-stop-idle'):
        rows = [x for x in samples if x['phase'] == name]
        if len(rows) < 2: continue
        summary[name] = dict(samples=len(rows), duration_seconds=rows[-1]['elapsed_seconds'] - rows[0]['elapsed_seconds'],
            cpu_percent_one_core=(rows[-1]['cpu_seconds']-rows[0]['cpu_seconds']) / (rows[-1]['elapsed_seconds']-rows[0]['elapsed_seconds']) * 100,
            median_working_set_bytes=statistics.median(x['working_set_bytes'] for x in rows),
            peak_private_bytes=max(x['private_bytes'] for x in rows), min_handles=min(x['handles'] for x in rows), max_handles=max(x['handles'] for x in rows),
            min_threads=min(x['threads'] for x in rows if x['threads'] is not None),
            max_threads=max(x['threads'] for x in rows if x['threads'] is not None))
    record = dict(kind='Isolated unpackaged release review; synthetic power/route events, no physical listening',
        measured=measured, launch_hidden=True, exit_code=child.returncode, runtime=report, cold=cold,
        executable_sha256=digest(bundle / 'poma.exe'), summary=summary, samples=samples)
    (run / 'evidence.json').write_text(json.dumps(record, indent=2) + '\n')
    print(json.dumps(dict(evidence=str(run / 'evidence.json'), passed=report.get('passed'),
        failure=report.get('failure'), checks=len(report.get('checks', [])), cold=cold, summary=summary)))
    return 0 if report.get('passed') and cold and cold.get('passed') else 1

if __name__ == '__main__':
    raise SystemExit(main())
