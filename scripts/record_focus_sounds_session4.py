"""Reconcile Session 4 evidence without promoting unavailable acceptance gates."""
import hashlib
import json
from pathlib import Path
import re
import subprocess
from datetime import datetime, timezone
import xml.etree.ElementTree as ET
import zipfile

from check_focus_sounds_session4 import source_files

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'artifacts/focus-sounds/session-4'
DOC = ROOT / 'docs/focus-sounds'
RTK = str(ROOT / '.tools/rtk/rtk.exe')


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def save(path, value):
    path.write_text(json.dumps(value, indent=2) + '\n', encoding='utf-8')


def main():
    current = source_files()
    records = [(p, json.loads(p.read_text(encoding='utf-8')))
               for p in sorted((OUT / 'checks').glob('*.json'))]
    names = ['format', 'analyze', 'tests', 'focused', 'windows-native',
             'mobile-runtime-probe', 'windows-build', 'interactive-build',
             'android-build', 'android-native', 'android-release', 'android-review']
    checks = {}
    for name in names:
        path, record = next((p, r) for p, r in reversed(records) if r['check'] == name)
        assert record['exit_code'] == 0, (name, path)
        if name in {'format', 'analyze', 'tests', 'focused'}:
            scope = ('mobile/lib/', 'mobile/test/', 'mobile/pubspec.')
        elif name.startswith('android-'):
            scope = ('mobile/lib/', 'mobile/native/', 'mobile/android/', 'mobile/pubspec.')
        elif name in {'windows-native', 'mobile-runtime-probe'}:
            scope = ('mobile/native/', 'mobile/windows/')
        else:
            scope = ('mobile/lib/', 'mobile/windows/runner/', 'mobile/pubspec.')
        changes = [p for p, sha in record['source_sha256'].items() if current.get(p) != sha]
        assert not [p for p in changes if p.startswith(scope)], (name, changes)
        log = ROOT / record['log']
        checks[name] = dict(record=path.relative_to(ROOT).as_posix(), log=record['log'],
            log_sha256=digest(log), exit_code=0, source_matches_executed_scope=True,
            source_scope=list(scope), later_changes_outside_scope=changes,
            elapsed_seconds=record['elapsed_seconds'])
        for field in ['artifact', 'runtime']:
            if field in record:
                checks[name][field] = record[field]

    def count(name, expression):
        log = (ROOT / checks[name]['log']).read_text(encoding='utf-8', errors='replace')
        return int(re.findall(expression, log)[-1])

    junit = []
    for p in sorted((ROOT / 'mobile/build/app/test-results/testDebugUnitTest').glob('TEST-*.xml')):
        attrs = ET.parse(p).getroot().attrib
        assert all(int(attrs[k]) == 0 for k in ['failures', 'errors', 'skipped'])
        junit.append(dict(suite=attrs['name'], tests=int(attrs['tests']),
                          source=p.relative_to(ROOT).as_posix(), sha256=digest(p)))
    assert junit
    counts = dict(flutter_regression=count('tests', r'\+(\d+): All tests passed!'),
        focused_including_ui=count('focused', r'\+(\d+): All tests passed!'),
        desktop_native=count('windows-native', r'(\d+) native checks passed'),
        native_fonts=count('windows-native', r'(\d+) native font checks passed'),
        windows_audio_guard=count('windows-native', r'(\d+) native audio guard checks passed'),
        mobile_native_synthetic=count('windows-native', r'(\d+) mobile native safety checks passed'),
        mobile_runtime_real_windows_backend=count('mobile-runtime-probe', r'(\d+) mobile native safety checks passed'),
        android_jvm=sum(s['tests'] for s in junit))

    payload_path = OUT / 'PAYLOAD_INSPECTION.json'
    payload = json.loads(payload_path.read_text())
    runtime_folder = ROOT / json.loads((OUT / 'windows-runtime-location.json').read_text())['path']
    runtime = json.loads((runtime_folder / 'evidence.json').read_text())
    assert runtime['exit_code'] == 0 and runtime['report']['passed']
    assert all(digest(ROOT / p) == sha for p, sha in runtime['source_files'].items())
    review_package = json.loads((OUT / 'WINDOWS_REVIEW_PACKAGE.json').read_text())
    interactive_smoke = json.loads((OUT / 'WINDOWS_INTERACTIVE_SMOKE.json').read_text())
    assert interactive_smoke['exit_code'] == 0
    assert interactive_smoke['runtime'] == review_package['runtime']
    assert interactive_smoke['aot_sha256'] == review_package['aot_sha256']
    assert digest(ROOT / review_package['archive']) == review_package['archive_sha256']
    resources_path = OUT / 'run-1794164384001161900/evidence.json'
    resources = json.loads(resources_path.read_text())
    assert resources['exit_code'] == 0 and resources['runtime']['passed'] and resources['cold']['passed']
    _, resource_build = next((p, r) for p, r in reversed(records) if r['check'] == 'resource-build')
    assert resources['executable_sha256'] == resource_build['runtime']['executable_sha256']
    resource_runtime = resources_path.parent / 'runtime'
    assert digest(resource_runtime / 'data/app.so') == resource_build['runtime']['aot_sha256']
    for p, sha in resource_build['source_sha256'].items():
        if p.startswith(('mobile/lib/', 'mobile/windows/runner/', 'mobile/pubspec.')):
            assert digest(ROOT / p) == sha, p

    package = OUT / 'windows-package/production-2007-audited/Poma-1.0.0.2007-x64.msix'
    with zipfile.ZipFile(package) as archive:
        inventory = json.loads(archive.read('build-inventory.json'))
        assert 'AppxSignature.p7x' not in archive.namelist(), 'Expected unsigned inspection package'
        assert 'dartjni.dll' not in archive.namelist()
        for file in inventory['files']:
            assert hashlib.sha256(archive.read(file['path'])).hexdigest() == file['sha256'], file['path']
        for p in (ROOT / 'mobile/assets/audio').glob('*.ogg'):
            assert archive.read('data/flutter_assets/assets/audio/' + p.name) == p.read_bytes()
        for name in ['focus-sounds.txt', 'focus-audio-native.txt']:
            assert archive.read('data/flutter_assets/assets/licenses/' + name) == (ROOT / 'mobile/assets/licenses' / name).read_bytes()

    tracker = (ROOT / 'docs/FOCUS_SOUNDS_PROGRESS.md').read_text(encoding='utf-8')
    requirements = [dict(id=m[1], checked=m[0] == 'x', text=m[2]) for m in re.findall(
        r'^- \[([ x])\] ((?:P|A|U|E)\d{2}|S[1-4]\.\d)\. (.+)$', tracker, re.MULTILINE)]
    assert len(requirements) == 59 and len({r['id'] for r in requirements}) == 59
    for r in requirements:
        prefix = r['id'][0]
        r['acceptance_scope'] = {
            'P': 'Shared controller/UI and Windows host evidence; unchecked global requirements retain mobile/physical gates',
            'A': 'Exact bundled draft rights/provenance verified; final listening/loop/loudness approval remains pending',
            'U': 'Session 3 host viewports/fonts/semantics/keyboard and real Windows captures; physical assistive checks remain pending',
            'E': 'Source/native/payload/host evidence with unavailable iOS/device scopes explicitly retained',
            'S': 'Session tracker and corresponding session handoff; no device/listening acceptance inferred'}[prefix]
        r['evidence'] = 'docs/FOCUS_SOUNDS_SESSION_4.md#requirement-reconciliation'
    head = subprocess.check_output([RTK, 'proxy', 'git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip()
    branch = subprocess.check_output([RTK, 'proxy', 'git', 'branch', '--show-current'], cwd=ROOT, text=True).strip()
    platform_matrix = [line for line in tracker.splitlines()
                       if line.startswith('| ') and any(s in line for s in ['Pending —', 'Pass —', 'Unavailable —'])]
    assert len(platform_matrix) == 11, platform_matrix
    verification = dict(date='2026-11-09', timezone='Asia/Kolkata', recorded_utc=datetime.now(timezone.utc).isoformat(),
        branch=branch, HEAD=head, state='Local uncommitted Sessions 2/3/4; no installation, signing, push or release publication',
        checks=checks, counts=counts, android_jvm=junit,
        runtime=dict(evidence=(runtime_folder / 'evidence.json').relative_to(ROOT).as_posix(),
            executable_sha256=runtime['executable_sha256'], aot_sha256=runtime['aot_sha256'],
            source_files_match=True, report=runtime['report']),
        personally_inspected_runtime_captures=[(runtime_folder / 'runtime/fictional-review-profile' / name).relative_to(ROOT).as_posix()
            for name in ['windows-playing.png', 'windows-chooser.png']],
        resources=dict(evidence=resources_path.relative_to(ROOT).as_posix(), sha256=digest(resources_path),
            summary=resources['summary'], native_guard_retirement_attempt_offset_micros=resources['runtime']['nativeGuardRetirementAttemptOffsetMicros'],
            playback_checks=len(resources['runtime']['checks']), cold_reset_checks=len(resources['cold']['checks']),
            conditions='Hidden isolated Windows release; approximately 60/120/60-second off/playing/post-stop windows. CPU is percent of one core; startup/cache/GC are included. Not a battery estimate.'),
        payload=dict(evidence=payload_path.relative_to(ROOT).as_posix(), sha256=digest(payload_path),
            audio_bytes=payload['audio_bytes'], android_debug_comparison={k:v for k,v in payload['android_debug_comparison'].items() if k != 'entries'},
            mobile_native_binaries={name:[f for f in data['native'] if 'poma_focus_audio' in f['path']] for name,data in payload['android'].items()},
            windows_runtime_comparison={k:v for k,v in payload['windows'].items() if k not in ['inventory', 'baseline_inventory']}),
        windows_package=dict(path=package.relative_to(ROOT).as_posix(), bytes=package.stat().st_size, sha256=digest(package),
            signed=False, installed=False, all_inventory_hashes_match=True,
            excluded_platform_artifacts=inventory['excludedPlatformArtifacts'], pe_files=len(inventory['peImports'])-1,
            resolved_package_files=len(inventory['files']), comparison_msix_baseline='Unavailable; no comparable prior MSIX retained'),
        windows_review_package=review_package, interactive_windows_startup_quit=interactive_smoke,
        packaging_failure_and_resolution=dict(initial_failure='Unresolved dependency: dartjni.dll -> jvm.dll',
            cause='Both baseline and current developer outputs include an optional desktop JNI shim because a JDK is installed',
            resolution='Exclude Android-only JNI from distribution; fail closed on Windows native-asset/PE Java references; preserve codecs/CRT/notices. Audited unsigned MSIX and isolated review ZIP now pass; real isolated UI playback rerun passed.'),
        requirements=requirements, platform_matrix_markdown_rows=platform_matrix,
        historical_checks=[dict(path=p.relative_to(ROOT).as_posix(), check=r['check'], exit_code=r['exit_code']) for p,r in records],
        retained_logs=[dict(path=p.relative_to(ROOT).as_posix(), sha256=digest(p),
            has_completed_record=p.with_suffix('.json').exists()) for p in sorted((OUT / 'checks').glob('*.log'))],
        limitations=['Four bundled recordings remain drafts: no human listening/final selection approval',
            'Physical Windows sleep/hibernate/route/tray/Narrator and clean-account offline first use remain pending',
            'Android APK/JVM/payload inspection passed; no connected-phone playback/lock/deadline/call/route/TalkBack/resource result',
            'iOS source integrated; compilation, XCTest, signing, device/backend/lock/VoiceOver/resources unavailable without Mac/iPhone',
            'A real Windows backend test of the shared mobile runtime does not verify an Android/iOS backend',
            'Unsigned production packages are inspection artifacts; review APK/ZIP use separate test identities; no installed Poma data touched'])
    save(DOC / 'SESSION_4_VERIFICATION.json', verification)

    tracked = subprocess.check_output([RTK, 'proxy', 'git', 'ls-files', '--cached', '--others', '--exclude-standard', '-z'], cwd=ROOT).decode('utf-8').split('\0')
    files = sorted({p for p in tracked if p.startswith(('mobile/', 'scripts/', 'docs/FOCUS_SOUNDS', 'docs/focus-sounds/SESSION_4'))
                    and (ROOT / p).is_file() and not p.endswith('SESSION_4_SOURCE_MANIFEST.json')})
    save(DOC / 'SESSION_4_SOURCE_MANIFEST.json', dict(branch=branch, HEAD=head,
        state='Local uncommitted feature; accumulated source snapshot includes preserved Sessions 2/3', excludes_self=True,
        files=[dict(path=p, bytes=(ROOT / p).stat().st_size, sha256=digest(ROOT / p)) for p in files]))
    print(json.dumps(dict(counts=counts, reconciled_requirements=len(requirements), source_files=len(files),
        windows_review=verification['windows_review_package']['archive'], android_review=checks['android-review']['artifact']['path'])))


if __name__ == '__main__':
    main()
