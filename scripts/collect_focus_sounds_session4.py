"""Verify an isolated Windows review distribution without an installed profile."""
import argparse
import ctypes
from ctypes import wintypes
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import time
import zipfile

import collect_focus_sounds_session3 as review
from windows_release import pe_imports


def distribution(source, package, interactive=False):
    marker = 'Poma.FocusAudioReview.Session2'.encode('utf-16le')
    assert marker in (source / 'poma.exe').read_bytes(), 'Refusing a production runner'
    folder = review.OUT / 'windows-package' / f'review-{time.time_ns()}'
    runtime = folder / 'Poma Sounds Review'
    shutil.copytree(source, runtime, ignore=shutil.ignore_patterns(
        'fictional-review-profile', '*.pdb', '*.lib', '*.exp', 'native_assets.json', 'dartjni.dll'))
    with zipfile.ZipFile(package) as archive:
        crt = json.loads(archive.read('runtime-source.json').decode('utf-8-sig'))
        for entry in crt:
            data = archive.read(entry['name'])
            assert hashlib.sha256(data).hexdigest().lower() == entry['sha256'].lower()
            (runtime / entry['name']).write_bytes(data)
        for name in archive.namelist():
            if name.startswith('Licenses/') and not name.endswith('/'):
                target = runtime / name
                assert target.resolve().is_relative_to(runtime.resolve())
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(archive.read(name))
        for source_asset in (review.ROOT / 'mobile/assets/audio').glob('*.ogg'):
            target = runtime / 'data/flutter_assets/assets/audio' / source_asset.name
            assert review.digest(target) == review.digest(source_asset)
            assert archive.read('data/flutter_assets/assets/audio/' + source_asset.name) == target.read_bytes()
    native_assets = (runtime / 'data/flutter_assets/NativeAssetsManifest.json').read_text()
    assert 'jni' not in native_assets.lower()
    binaries = [p for p in runtime.rglob('*') if p.suffix.lower() in {'.exe', '.dll'}]
    local = {p.name.lower() for p in binaries}
    system = Path(os.environ['SystemRoot']) / 'System32'
    imports = {}
    for binary in binaries:
        imports[binary.relative_to(runtime).as_posix()] = pe_imports(binary)
        for name in imports[binary.relative_to(runtime).as_posix()]:
            assert name not in {'dartjni.dll', 'jvm.dll'}
            assert name in local or (not name.startswith(('msvcp', 'vcruntime', 'concrt')) and
                (name.startswith(('api-ms-win-', 'ext-ms-win-')) or (system / name).is_file())), (binary.name, name)
    (runtime / 'README.txt').write_text(
        'Poma Sounds Review - isolated local review\n\n'
        'Extract the entire folder, then run poma.exe. No installation is needed.\n'
        'This review uses its own fictional-review-profile folder and separate tray identity.\n'
        'Its data is separate from installed Poma. Keep all bundled files together.\n'
        'The four recordings remain drafts awaiting listening approval.\n'
        'Physical sleep, headphones, Bluetooth and accessibility checks remain pending.\n', encoding='utf-8')
    archive_path = folder / 'Poma-Sounds-Review-Windows-x64.zip'
    with zipfile.ZipFile(archive_path, 'w', compression=zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
        for path in sorted(runtime.rglob('*')):
            if path.is_file():
                assert path.suffix.lower() not in {'.pdb', '.lib', '.exp', '.db', '.sqlite', '.jks', '.pfx'}
                archive.write(path, path.relative_to(folder).as_posix())
    record = dict(kind='Interactive product review' if interactive else 'Automated production UI review',
        package=package.relative_to(review.ROOT).as_posix(), package_sha256=review.digest(package),
        review_source=source.relative_to(review.ROOT).as_posix(),
        runtime=runtime.relative_to(review.ROOT).as_posix(),
        executable_sha256=review.digest(runtime / 'poma.exe'), aot_sha256=review.digest(runtime / 'data/app.so'),
        archive=archive_path.relative_to(review.ROOT).as_posix(), archive_bytes=archive_path.stat().st_size,
        archive_sha256=review.digest(archive_path), pe_imports=imports,
        crt_source='Same application-local CRT files and license as the audited unsigned MSIX',
        excluded=['dartjni.dll', 'native_assets.json', '*.pdb', '*.lib', '*.exp', 'fictional-review-profile'],
        first_use_clean_machine='Pending; host run and static audit do not establish clean-VM acceptance')
    (review.OUT / 'WINDOWS_REVIEW_PACKAGE.json').write_text(json.dumps(record, indent=2) + '\n', encoding='utf-8')
    return runtime


def smoke_interactive(runtime):
    """Open only the isolated interactive runner, then ask that owned app to quit."""
    marker = 'Poma.FocusAudioReview.Session2'.encode('utf-16le')
    assert marker in (runtime / 'poma.exe').read_bytes()
    profile = runtime / 'fictional-review-profile'
    assert not profile.exists(), 'Use a fresh review distribution'
    user = ctypes.WinDLL('user32', use_last_error=True)
    callback_type = ctypes.WINFUNCTYPE(wintypes.BOOL, wintypes.HWND, wintypes.LPARAM)
    user.EnumWindows.argtypes = [callback_type, wintypes.LPARAM]
    user.GetWindowThreadProcessId.argtypes = [wintypes.HWND, ctypes.POINTER(wintypes.DWORD)]
    user.GetClassNameW.argtypes = [wintypes.HWND, wintypes.LPWSTR, ctypes.c_int]
    user.PostMessageW.argtypes = [wintypes.HWND, wintypes.UINT, wintypes.WPARAM, wintypes.LPARAM]
    windows = []
    with (runtime.parent / 'interactive-startup.log').open('w', encoding='utf-8') as log:
        child = subprocess.Popen([str(runtime / 'poma.exe'), '--startup'], cwd=runtime,
            stdout=log, stderr=subprocess.STDOUT, creationflags=subprocess.CREATE_NO_WINDOW)
        try:
            deadline = time.monotonic() + 45
            while child.poll() is None and time.monotonic() < deadline and not list(profile.rglob('*.db')):
                time.sleep(.25)
            assert child.poll() is None and list(profile.rglob('*.db')), 'Interactive app did not open its isolated database'
            time.sleep(2)
            def visit(hwnd, _):
                pid = wintypes.DWORD()
                user.GetWindowThreadProcessId(hwnd, ctypes.byref(pid))
                name = ctypes.create_unicode_buffer(128)
                user.GetClassNameW(hwnd, name, len(name))
                if pid.value == child.pid and name.value == 'FLUTTER_RUNNER_WIN32_WINDOW':
                    windows.append(int(hwnd))
                    # Synthetic request reaches the app's ordinary Quit handler;
                    # it does not log off Windows or contact another process.
                    user.PostMessageW(hwnd, 0x0011, 0, 0)
                return True
            user.EnumWindows(callback_type(visit), 0)
            assert windows, 'Owned review window was not found'
            child.wait(timeout=15)
            assert child.returncode == 0, child.returncode
        finally:
            if child.poll() is None:
                child.terminate()
                child.wait(timeout=10)
    record = dict(kind='Fresh isolated interactive Windows package startup/ordinary Quit smoke',
        runtime=runtime.relative_to(review.ROOT).as_posix(), executable_sha256=review.digest(runtime / 'poma.exe'),
        aot_sha256=review.digest(runtime / 'data/app.so'), exit_code=child.returncode,
        fresh_profile_created=True, bundled_jni=False, bundled_crt=True,
        physical_acceptance=False, listening='Not performed')
    (review.OUT / 'WINDOWS_INTERACTIVE_SMOKE.json').write_text(json.dumps(record, indent=2) + '\n', encoding='utf-8')
    print(json.dumps(record))

if __name__ == '__main__':
    review.OUT = review.ROOT / 'artifacts/focus-sounds/session-4'
    review.OUT.mkdir(parents=True, exist_ok=True)
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--review-runtime', type=Path)
    parser.add_argument('--package', type=Path)
    parser.add_argument('--package-only', action='store_true',
                        help='Prepare the interactive Session 4 entry point; launch only with --smoke-interactive')
    parser.add_argument('--smoke-interactive', action='store_true',
                        help='Verify fresh isolated interactive startup and ordinary Quit after packaging')
    args = parser.parse_args()
    assert (args.review_runtime is None) == (args.package is None), 'Both distribution paths are required'
    assert not args.package_only or args.package, 'Interactive packaging requires both input paths'
    assert not args.smoke_interactive or args.package_only
    source = distribution(args.review_runtime.resolve(), args.package.resolve(), args.package_only) if args.package else None
    if args.package_only:
        print(json.dumps({'interactive_runtime': source.relative_to(review.ROOT).as_posix(), 'installed': False}))
        if args.smoke_interactive:
            smoke_interactive(source)
    else:
        review.main(source)
