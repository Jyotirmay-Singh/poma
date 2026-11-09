"""Retain source, check and payload evidence without installing or opening Poma."""
import hashlib
import ctypes as c
from ctypes import wintypes as w
import json
from pathlib import Path
import shutil
import platform
import re
import subprocess
import sys
import time
import zipfile
import uuid

ROOT = Path(__file__).resolve().parents[1]
EVIDENCE = ROOT / 'artifacts/focus-sounds/session-2'
RTK = ROOT / '.tools/rtk/rtk.exe'

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def environment():
    class Guid(c.Structure):
        _fields_ = [('a', w.DWORD), ('b', w.WORD), ('d', w.WORD), ('tail', c.c_ubyte * 8)]
    def guid(value): return Guid.from_buffer_copy(uuid.UUID(value).bytes_le)
    def method(pointer, index, result, *arguments):
        address = c.cast(pointer, c.POINTER(c.POINTER(c.c_void_p))).contents[index]
        return c.WINFUNCTYPE(result, c.c_void_p, *arguments)(address)
    record = dict(os=platform.platform(), kernel_version=platform.version(),
        route_scope='Current default render endpoint identities observed during isolated review; hashes omit personal device names',
        route_observed_utc=time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime()), endpoint_sha256_by_role={})
    ole = c.OleDLL('ole32')
    initialized = ole.CoInitializeEx(None, 2)
    enumerator = c.c_void_p()
    try:
        clsid = guid('BCDE0395-E52F-467C-8E3D-C4579291692E')
        iid = guid('A95664D2-9614-4F35-A746-DE8DB63617E6')
        result = ole.CoCreateInstance(c.byref(clsid), None, 1, c.byref(iid), c.byref(enumerator))
        if result < 0: raise OSError('Audio endpoint inventory unavailable')
        for role, name in enumerate(['console', 'multimedia', 'communications']):
            device = c.c_void_p()
            result = method(enumerator, 4, w.LONG, c.c_int, c.c_int, c.POINTER(c.c_void_p))(enumerator, 0, role, c.byref(device))
            if result < 0: continue
            identifier = c.c_void_p()
            try:
                result = method(device, 5, w.LONG, c.POINTER(c.c_void_p))(device, c.byref(identifier))
                if result >= 0:
                    record['endpoint_sha256_by_role'][name] = hashlib.sha256(c.wstring_at(identifier).encode()).hexdigest()
            finally:
                if identifier.value: ole.CoTaskMemFree(identifier)
                method(device, 2, w.ULONG)(device)
    finally:
        if enumerator.value: method(enumerator, 2, w.ULONG)(enumerator)
        if initialized >= 0: ole.CoUninitialize()
    target = EVIDENCE / 'environment.json'
    target.write_text(json.dumps(record, indent=2) + '\n')
    print(json.dumps(record))

def sources():
    paths = set((ROOT / 'mobile/lib').rglob('*.dart'))
    paths.update((ROOT / 'mobile/windows/runner').rglob('*.cpp'))
    paths.update((ROOT / 'mobile/windows/runner').rglob('*.h'))
    paths.update([ROOT / p for p in ['mobile/pubspec.yaml', 'mobile/pubspec.lock',
        'mobile/windows/runner/CMakeLists.txt', 'mobile/tool/focus_audio_session2_review.dart']])
    return [dict(path=p.relative_to(ROOT).as_posix(), bytes=p.stat().st_size, sha256=digest(p)) for p in sorted(paths)]

def snapshot_review():
    source = ROOT / 'mobile/build/windows/x64/runner/Release'
    assert 'Poma.FocusAudioReview.Session2'.encode('utf-16le') in (source / 'poma.exe').read_bytes()
    target = EVIDENCE / ('review-bundle-' + str(time.time_ns()))
    shutil.copytree(source, target, ignore=shutil.ignore_patterns('fictional-review-profile'))
    metadata = dict(path=target.relative_to(ROOT).as_posix(), executable_sha256=digest(target / 'poma.exe'), sources=sources())
    (EVIDENCE / 'review-bundle-location.json').write_text(json.dumps(metadata, indent=2) + '\n')
    print(json.dumps(dict(review_bundle=metadata['path'], source_files=len(metadata['sources']))))

def record():
    provenance = json.loads((ROOT / 'docs/focus-sounds/ASSET_PROVENANCE.json').read_text())
    assets = [x for x in provenance['prepared_assets'] if 'final_asset_path' in x]
    bundle = ROOT / 'mobile/build/windows/x64/runner/Release'
    assert 'Poma.FocusAudioReview.Session2'.encode('utf-16le') not in (bundle / 'poma.exe').read_bytes(), 'Build production main first'
    assert b'pomaAudioTestPower' not in (bundle / 'poma.exe').read_bytes(), 'Review hooks leaked into production'
    apk = ROOT / 'mobile/build/app/outputs/flutter-apk/app-debug.apk'
    payloads = []
    with zipfile.ZipFile(apk) as archive:
        for asset in assets:
            path = ROOT / asset['final_asset_path']
            relative = asset['final_asset_path'].removeprefix('mobile/')
            assert digest(path) == asset['sha256']
            assert digest(bundle / 'data/flutter_assets' / relative) == asset['sha256']
            assert hashlib.sha256(archive.read('assets/flutter_assets/' + relative)).hexdigest() == asset['sha256']
            payloads.append(dict(path=relative, bytes=asset['bytes'], sha256=asset['sha256']))
        for name in ['focus-sounds.txt', 'focus-audio-native.txt']:
            relative = 'assets/licenses/' + name
            source_hash = digest(ROOT / 'mobile' / relative)
            assert digest(bundle / 'data/flutter_assets' / relative) == source_hash
            assert hashlib.sha256(archive.read('assets/flutter_assets/' + relative)).hexdigest() == source_hash
    assert len(list((bundle / 'data/flutter_assets/assets/audio').iterdir())) == 4
    libraries = [bundle / (name + '.dll') for name in ['flutter_soloud_plugin', 'ogg', 'opus', 'vorbis', 'vorbisenc', 'vorbisfile', 'FLAC']]
    assert all(p.is_file() for p in libraries)
    snapshot = json.loads((EVIDENCE / 'review-bundle-location.json').read_text())
    review_aot_sha256 = digest(ROOT / snapshot['path'] / 'data/app.so')
    mismatches = [x['path'] for x in snapshot['sources'] if digest(ROOT / x['path']) != x['sha256']]
    assert not mismatches, ('Source changed after review build', mismatches)
    checks = [json.loads(p.read_text()) for p in sorted((EVIDENCE / 'checks').glob('*.json'))]
    latest = {item['check']: item for item in checks}
    required = ['format', 'analyze', 'focused', 'tests', 'windows-native', 'windows-build', 'android-build', 'review-build', 'interruption-regression']
    assert all(latest[name]['exit_code'] == 0 for name in required)
    test_counts = {}
    for name in ['tests', 'focused']:
        log = (ROOT / latest[name]['log']).read_text(encoding='utf-8', errors='replace')
        test_counts[name] = int(re.search(r'\+(\d+): All tests passed!', log).group(1))
    runs = []
    for p in sorted(EVIDENCE.glob('run-*/evidence.json')):
        data = json.loads(p.read_text())
        runs.append(dict(path=p.relative_to(ROOT).as_posix(), measured=data['measured'],
            executable_sha256=data['executable_sha256'], launch_hidden=data.get('launch_hidden', False),
            aot_sha256=digest(p.parent / 'runtime/data/app.so'),
            passed=data['runtime'].get('passed'), failure=data['runtime'].get('failure'),
            checks=len(data['runtime'].get('checks', [])), cold=data.get('cold'),
            deadline_offset_micros=data['runtime'].get('nativeGuardRetirementAttemptOffsetMicros'), summary=data['summary']))
    assert any(x['measured'] and x['passed'] and x['cold']['passed'] and x['launch_hidden']
               and x['executable_sha256'] == snapshot['executable_sha256']
               and x['aot_sha256'] == review_aot_sha256 for x in runs)
    final_run = next(x for x in reversed(runs) if x['measured'] and x['passed'] and x['launch_hidden']
                     and x['executable_sha256'] == snapshot['executable_sha256']
                     and x['aot_sha256'] == review_aot_sha256)
    assert all(final_run['summary'][phase]['duration_seconds'] >= seconds - 2
               for phase, seconds in [('off-idle', 60), ('playing', 120), ('post-stop-idle', 60)])
    head = subprocess.run([str(RTK), 'proxy', 'git', 'rev-parse', 'HEAD'], cwd=ROOT,
                          text=True, capture_output=True, check=True).stdout.strip()
    result = dict(date='2026-11-08', timezone='Asia/Kolkata', branch='codex/focus-soundscapes', starting_HEAD=head,
        environment=json.loads((EVIDENCE / 'environment.json').read_text()),
        source_state='Session 2 local uncommitted implementation; no install/merge/publication',
        sdk=dict(flutter='3.44.2', dart='3.12.2', playback='flutter_soloud 4.1.7'),
        checks=checks, latest_successful_checks=latest, test_counts=test_counts,
        native_checks=dict(desktop=233, fonts=43, audio_guard=15),
        runtime_runs=runs, final_runtime=final_run, review_sources_verified=True,
        review_bundle=dict(path=snapshot['path'], executable_sha256=snapshot['executable_sha256'], aot_sha256=review_aot_sha256),
        payload=dict(assets=payloads, asset_bytes=sum(x['bytes'] for x in payloads),
            native_audio_files=[dict(name=p.name, bytes=p.stat().st_size, sha256=digest(p)) for p in libraries],
            native_audio_file_bytes=sum(p.stat().st_size for p in libraries),
            windows_runtime_bytes=sum(p.stat().st_size for p in bundle.rglob('*') if p.is_file() and p.suffix not in ['.pdb', '.lib', '.exp']),
            windows_executable_sha256=digest(bundle / 'poma.exe'), windows_aot_sha256=digest(bundle / 'data/app.so'),
            excluded_linker_artifacts=[dict(name=p.name, bytes=p.stat().st_size) for p in bundle.iterdir() if p.suffix in ['.lib', '.exp']],
            android_debug_bytes=apk.stat().st_size, android_debug_sha256=digest(apk),
            review_hooks_absent_from_production=True, exact_assets_and_notices_in_both_builds=True,
            size_scope='File inventory, not net no-audio delta, MSIX compression, release APK, store size or battery guarantee'),
        pending=['Human listening and final draft selection', 'Physical Windows sleep/wake and wired/Bluetooth route removal',
            'Production sound controls and rendered/assistive acceptance (Session 3)',
            'Android/iOS native media/background/audio-focus integration and physical acceptance (Session 4)',
            'macOS/iOS compilation and signing access'],
        early_failures=['Initial restricted SDK lockfile access; resolved by approved check execution with SDK cache access',
            'Initial analysis/style/FFI callback declaration; corrected',
            'Initial test helper import and combined v2 fixture setup; corrected',
            'Initial native link lacked mincore; corrected',
            'Rapid-control resource retirement race caught by strict-mode test; corrected',
            'Immediate mixed-voice-count assertion during suspend was invalid; corrected to paused plus zero native gain',
            'Older resume crossed a newer interruption; reproduced by a failing regression, fixed by revalidating and consuming the interruption token after reconciliation',
            'Initial new regression fixture omitted dart:async import; corrected'])
    target = ROOT / 'docs/focus-sounds/SESSION_2_VERIFICATION.json'
    target.write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps(dict(verification=str(target), asset_bytes=result['payload']['asset_bytes'], native_audio_file_bytes=result['payload']['native_audio_file_bytes'],
        windows_runtime_bytes=result['payload']['windows_runtime_bytes'], android_debug_bytes=result['payload']['android_debug_bytes'], runtime_runs=runs)))

if __name__ == '__main__':
    if sys.argv[1:] == ['snapshot-review']: snapshot_review()
    elif sys.argv[1:] == ['record']: record()
    elif sys.argv[1:] == ['environment']: environment()
    else: raise SystemExit('Use snapshot-review, environment or record')
