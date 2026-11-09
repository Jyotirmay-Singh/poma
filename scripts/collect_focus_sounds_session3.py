"""Run only a copied, identity-checked developer build with isolated storage."""
import ctypes
from ctypes import wintypes
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import time

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'artifacts/focus-sounds/session-3'

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def main(source=None):
    source = Path(source) if source is not None else ROOT / 'mobile/build/windows/x64/runner/Release'
    executable = source / 'poma.exe'
    marker = 'Poma.FocusAudioReview.Session2'.encode('utf-16le')
    assert marker in executable.read_bytes(), 'Refusing non-isolated production executable'
    run = OUT / f'windows-runtime-{time.time_ns()}'
    runtime = run / 'runtime'
    shutil.copytree(source, runtime, ignore=shutil.ignore_patterns('fictional-review-profile'))
    identity = {'executable_sha256': digest(runtime/'poma.exe'),
                'aot_sha256': digest(runtime/'data/app.so'),
                'kind': 'Copied isolated Windows developer build; no installed data',
                'profile': 'runtime/fictional-review-profile',
                'source_files': {p.relative_to(ROOT).as_posix(): digest(p)
                                 for folder in ['mobile/lib', 'mobile/tool']
                                 for p in (ROOT/folder).rglob('*.dart')}}
    user = ctypes.WinDLL('user32', use_last_error=True)
    callback_type = ctypes.WINFUNCTYPE(wintypes.BOOL, wintypes.HWND, wintypes.LPARAM)
    user.EnumWindows.argtypes = [callback_type, wintypes.LPARAM]
    user.GetWindowThreadProcessId.argtypes = [wintypes.HWND, ctypes.POINTER(wintypes.DWORD)]
    user.SetWindowPos.argtypes = [wintypes.HWND, wintypes.HWND, ctypes.c_int, ctypes.c_int,
                                  ctypes.c_int, ctypes.c_int, wintypes.UINT]
    user.GetClassNameW.argtypes = [wintypes.HWND, wintypes.LPWSTR, ctypes.c_int]
    with (run/'runtime.log').open('w') as log:
        process = subprocess.Popen([str(runtime/'poma.exe'), '--startup'], cwd=runtime,
                                   stdout=log, stderr=subprocess.STDOUT,
                                   creationflags=subprocess.CREATE_NO_WINDOW)
        resized = False
        def visit(hwnd, _):
            nonlocal resized
            pid = wintypes.DWORD()
            user.GetWindowThreadProcessId(hwnd, ctypes.byref(pid))
            class_name = ctypes.create_unicode_buffer(128)
            user.GetClassNameW(hwnd, class_name, len(class_name))
            if pid.value == process.pid and class_name.value == 'FLUTTER_RUNNER_WIN32_WINDOW':
                # Resize only this owned hidden review window; never show/activate it.
                if user.SetWindowPos(hwnd, None, 80, 60, 1800, 1200, 0x14):
                    resized = True
            return True
        callback = callback_type(visit)
        deadline = time.monotonic()+90
        while process.poll() is None and time.monotonic() < deadline:
            if not resized:
                user.EnumWindows(callback, 0)
            time.sleep(.25)
        if process.poll() is None:
            process.terminate()
            process.wait(timeout=10)
            identity['timeout'] = True
        identity['exit_code'] = process.returncode
        identity['resized_owned_window'] = resized
    report_path = runtime/'fictional-review-profile/session3-runtime.json'
    if report_path.exists():
        identity['report'] = json.loads(report_path.read_text(encoding='utf-8'))
        identity['captures'] = {p.name: digest(p) for p in report_path.parent.glob('*.png')}
    else:
        identity['missing_report'] = True
    (run/'evidence.json').write_text(json.dumps(identity, indent=2)+'\n')
    (OUT/'windows-runtime-location.json').write_text(json.dumps({'path': run.relative_to(ROOT).as_posix()})+'\n')
    print(json.dumps({'evidence': (run/'evidence.json').relative_to(ROOT).as_posix(),
                      'passed': identity.get('report', {}).get('passed', False)}))
    assert identity.get('report', {}).get('passed'), identity.get('report', identity)

if __name__ == '__main__':
    main()
