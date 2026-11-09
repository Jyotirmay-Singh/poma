"""Session 2 checks; preserve earlier evidence and never open installed data."""
import json
import os
from pathlib import Path
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[1]
RTK = str(ROOT / '.tools/rtk/rtk.exe')
EVIDENCE = ROOT / 'artifacts/focus-sounds/session-2/checks'
FLUTTER = [RTK, 'proxy', 'powershell', '-NoProfile', '-ExecutionPolicy', 'Bypass',
           '-File', str(ROOT / 'scripts/flutter.ps1')]
COMMANDS = {
    'format': [RTK, 'proxy', 'D:/SDKs/flutter/bin/dart.bat', 'format', '--output=none', '--set-exit-if-changed',
               str(ROOT / 'mobile/lib'), str(ROOT / 'mobile/test'), str(ROOT / 'mobile/tool/focus_audio_session2_review.dart')],
    'analyze': FLUTTER + ['analyze', '--no-pub'],
    'interruption-regression': FLUTTER + ['test', '--no-pub', 'test/focus_audio_test.dart', '--plain-name',
                                        'older resume awaiting reconciliation cannot end a newer interruption'],
    'focused': FLUTTER + ['test', '--no-pub', 'test/focus_audio_test.dart', 'test/focus_audio_preferences_test.dart', 'test/focus_audio_desktop_test.dart'],
    'tests': FLUTTER + ['test', '--no-pub'],
    'windows-build': FLUTTER + ['build', 'windows', '--release', '--no-pub'],
    'review-build': FLUTTER + ['build', 'windows', '--release', '--no-pub', '-t', 'tool/focus_audio_session2_review.dart'],
    'android-build': FLUTTER + ['build', 'apk', '--debug', '--target-platform', 'android-arm64', '--no-pub'],
    'windows-native': [RTK, 'proxy', 'powershell', '-NoProfile', '-ExecutionPolicy', 'Bypass',
                       '-File', str(ROOT / 'scripts/test_windows_native.ps1')],
}

def main():
    EVIDENCE.mkdir(parents=True, exist_ok=True)
    environment = dict(os.environ, JAVA_HOME='D:/Android/jdk/jdk-17.0.19+10',
                       ANDROID_HOME='D:/Android/sdk', ANDROID_SDK_ROOT='D:/Android/sdk',
                       FLUTTER_ROOT='D:/SDKs/flutter', TEMP=str(ROOT / '.tools/tmp'), TMP=str(ROOT / '.tools/tmp'))
    environment['PATH'] = environment['JAVA_HOME'] + '/bin;' + environment['PATH']
    failed = False
    for name in sys.argv[1:]:
        command = COMMANDS[name]
        stamp = time.time_ns()
        log = EVIDENCE / f'{name}-{stamp}.log'
        print(f'Starting {name}', flush=True)
        start = time.monotonic()
        with log.open('w', encoding='utf-8') as output:
            result = subprocess.run(command, cwd=ROOT, env=environment,
                stdout=output, stderr=subprocess.STDOUT, timeout=1200)
        record = dict(check=name, command=command, exit_code=result.returncode,
                      elapsed_seconds=time.monotonic() - start, log=log.relative_to(ROOT).as_posix())
        (EVIDENCE / f'{name}-{stamp}.json').write_text(json.dumps(record, indent=2) + '\n')
        print(json.dumps(record), flush=True)
        if result.returncode:
            failed = True
            print(log.read_text(encoding='utf-8', errors='replace')[-8000:], flush=True)
    raise SystemExit(1 if failed else 0)

if __name__ == '__main__':
    main()
