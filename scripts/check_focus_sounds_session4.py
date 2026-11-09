"""Session 4 checks with source identities; never opens an installed profile."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import time
import shutil

ROOT = Path(__file__).resolve().parents[1]
RTK = str(ROOT / '.tools/rtk/rtk.exe')
OUT = ROOT / 'artifacts/focus-sounds/session-4/checks'
FLUTTER = [RTK, 'proxy', 'powershell', '-NoProfile', '-ExecutionPolicy', 'Bypass',
           '-File', str(ROOT / 'scripts/flutter.ps1')]
COMMANDS = {
    'analyze': FLUTTER + ['analyze', '--no-pub'],
    'focused': FLUTTER + ['test', '--no-pub', 'test/focus_audio_test.dart',
        'test/focus_audio_mobile_test.dart', 'test/focus_audio_preferences_test.dart',
        'test/focus_audio_desktop_test.dart', 'test/focus_sounds_ui_test.dart'],
    'tests': FLUTTER + ['test', '--no-pub', '--concurrency=1'],
    'process-regressions': FLUTTER + ['test', '--no-pub', '--concurrency=1',
        'test/process_crash_test.dart', 'test/focus_process_crash_test.dart'],
    'windows-native': [RTK, 'proxy', 'powershell', '-NoProfile', '-ExecutionPolicy',
        'Bypass', '-File', str(ROOT / 'scripts/test_windows_native.ps1')],
    'windows-build': FLUTTER + ['build', 'windows', '--release', '--no-pub'],
    'review-build': FLUTTER + ['build', 'windows', '--release', '--no-pub', '-t', 'tool/focus_audio_session3_review.dart'],
    'resource-build': FLUTTER + ['build', 'windows', '--release', '--no-pub', '-t', 'tool/focus_audio_session2_review.dart'],
    'interactive-build': FLUTTER + ['build', 'windows', '--release', '--no-pub', '-t', 'tool/focus_audio_session4_review.dart'],
    'android-build': FLUTTER + ['build', 'apk', '--debug', '--target-platform', 'android-arm64', '--no-pub'],
    'android-native': [RTK, 'proxy', str(ROOT / 'mobile/android/gradlew.bat'), ':app:testDebugUnitTest', '--console=plain'],
    'android-release': FLUTTER + ['build', 'apk', '--release', '--target-platform', 'android-arm64'],
    'android-review': FLUTTER + ['build', 'apk', '--release', '--target-platform', 'android-arm64',
        '--dart-define=POMA_FOCUS_AUDIO_REVIEW=true'],
    'mobile-runtime-probe': [RTK, 'proxy', str(ROOT / '.tools/windows-native-tests/Release/poma_mobile_audio_test.exe'),
        str(ROOT / 'artifacts/focus-sounds/session-4/baseline/windows-runtime'), str(ROOT / 'mobile/assets/audio')],
    'format': [RTK, 'proxy', 'D:/SDKs/flutter/bin/cache/dart-sdk/bin/dart.exe', 'format',
        '--output=none', '--set-exit-if-changed', str(ROOT / 'mobile/lib'), str(ROOT / 'mobile/test'), str(ROOT / 'mobile/tool')],
}

def source_files():
    paths = []
    for folder in ['mobile/lib', 'mobile/native', 'mobile/android/app/src', 'mobile/ios/Runner', 'mobile/windows/runner', 'mobile/test']:
        paths.extend(p for p in (ROOT / folder).rglob('*') if p.is_file() and p.suffix in {'.dart', '.cpp', '.h', '.swift', '.kt', '.xml', '.plist'})
    paths.extend(ROOT / p for p in ['mobile/pubspec.lock', 'mobile/pubspec.yaml', 'mobile/android/app/build.gradle.kts',
        'mobile/android/app/proguard-rules.pro', 'mobile/ios/Runner.xcodeproj/project.pbxproj',
        'mobile/android/app/src/main/cpp/CMakeLists.txt', 'mobile/windows/tests/CMakeLists.txt'])
    paths.extend(p for p in (ROOT / 'mobile/windows/tests').glob('*.cpp'))
    paths.extend(p for p in (ROOT / 'mobile/android/app/src/test').rglob('*.kt'))
    return {p.relative_to(ROOT).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest() for p in paths}

def main():
    OUT.mkdir(parents=True, exist_ok=True)
    env = dict(os.environ, JAVA_HOME='D:/Android/jdk/jdk-17.0.19+10',
        ANDROID_HOME='D:/Android/sdk', ANDROID_SDK_ROOT='D:/Android/sdk', FLUTTER_ROOT='D:/SDKs/flutter',
        TEMP=str(ROOT / '.tools/tmp'), TMP=str(ROOT / '.tools/tmp'), POMA_ALLOW_UNSIGNED_RELEASE='1')
    env['PATH'] = env['JAVA_HOME'] + '/bin;' + env['PATH']
    env['JAVA_TOOL_OPTIONS'] = '-Djdk.net.unixdomain.tmpdir=' + str(ROOT / '.tools/tmp')
    failed = False
    for name in sys.argv[1:]:
        command = COMMANDS[name]
        run_env = dict(env)
        stamp = time.time_ns()
        log = OUT / f'{name}-{stamp}.log'
        sources = source_files()
        start = time.monotonic()
        print('Starting ' + name, flush=True)
        with log.open('w', encoding='utf-8') as output:
            run = subprocess.run(command, cwd=ROOT / 'mobile/android' if name == 'android-native' else ROOT,
                env=run_env, stdout=output, stderr=subprocess.STDOUT, timeout=1800)
        record = dict(check=name, command=command, exit_code=run.returncode,
            elapsed_seconds=time.monotonic()-start, source_sha256=sources, log=log.relative_to(ROOT).as_posix())
        if run.returncode == 0 and name in ['android-build', 'android-release', 'android-review']:
            filename = 'app-debug.apk' if name == 'android-build' else 'app-release.apk'
            source = ROOT / 'mobile/build/app/outputs/flutter-apk' / filename
            target = OUT.parent / 'builds' / f'{name}-{stamp}' / filename
            target.parent.mkdir(parents=True, exist_ok=False)
            shutil.copy2(source, target)
            record['artifact'] = dict(path=target.relative_to(ROOT).as_posix(), bytes=target.stat().st_size,
                sha256=hashlib.sha256(target.read_bytes()).hexdigest())
            aapt = sorted(Path(env['ANDROID_HOME']).glob('build-tools/*/aapt.exe'))[-1]
            metadata = subprocess.run([RTK, 'proxy', str(aapt), 'dump', 'badging', str(target)],
                capture_output=True, text=True, env=run_env, timeout=60)
            expected = 'com.jyotirmaysingh.poma' + ('.focussoundsreview' if name == 'android-review' else '')
            package_line = next((line for line in metadata.stdout.splitlines() if line.startswith('package:')), '')
            record['artifact']['package_metadata'] = package_line
            record['artifact']['expected_package'] = expected
            if metadata.returncode != 0 or f"name='{expected}'" not in package_line:
                record['exit_code'] = 2
                record['inspection_failure'] = 'Package identity does not match the requested build; artifact is not approved for use.'
                run.returncode = 2
        if run.returncode == 0 and name in ['windows-build', 'review-build', 'resource-build', 'interactive-build']:
            source = ROOT / 'mobile/build/windows/x64/runner/Release'
            target = OUT.parent / 'builds' / f'{name}-{stamp}'
            shutil.copytree(source, target, ignore=shutil.ignore_patterns('*.pdb', '*.lib', '*.exp', 'fictional-review-profile'))
            record['runtime'] = dict(path=target.relative_to(ROOT).as_posix(),
                executable_sha256=hashlib.sha256((target/'poma.exe').read_bytes()).hexdigest(),
                aot_sha256=hashlib.sha256((target/'data/app.so').read_bytes()).hexdigest())
        (OUT / f'{name}-{stamp}.json').write_text(json.dumps(record, indent=2)+'\n', encoding='utf-8')
        print(json.dumps({k: v for k, v in record.items() if k != 'source_sha256'}), flush=True)
        if run.returncode:
            failed = True
            print(log.read_text(encoding='utf-8', errors='replace')[-14000:], flush=True)
    raise SystemExit(1 if failed else 0)

if __name__ == '__main__':
    main()
