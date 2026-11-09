"""Reproducible Session 3 checks; never use the installed Poma profile."""
import json
import hashlib
import os
from pathlib import Path
import subprocess
import sys
import time

sys.stdout.reconfigure(encoding='utf-8')

ROOT = Path(__file__).resolve().parents[1]
RTK = str(ROOT / '.tools/rtk/rtk.exe')
OUT = ROOT / 'artifacts/focus-sounds/session-3/checks'
FLUTTER = [RTK, 'proxy', 'powershell', '-NoProfile', '-ExecutionPolicy', 'Bypass',
           '-File', str(ROOT / 'scripts/flutter.ps1')]
COMMANDS = {
    'analyze': FLUTTER + ['analyze', '--no-pub'],
    'ui': FLUTTER + ['test', '--no-pub', 'test/focus_sounds_ui_test.dart',
                    '--dart-define=POMA_SOUND_CAPTURES=../artifacts/focus-sounds/session-3/ui'],
    'focused': FLUTTER + ['test', '--no-pub', 'test/focus_audio_test.dart',
                         'test/focus_audio_preferences_test.dart', 'test/focus_audio_desktop_test.dart'],
    'tests': FLUTTER + ['test', '--no-pub'],
    'windows-native': [RTK, 'proxy', 'powershell', '-NoProfile', '-ExecutionPolicy', 'Bypass',
                       '-File', str(ROOT / 'scripts/test_windows_native.ps1')],
    'windows-build': FLUTTER + ['build', 'windows', '--release', '--no-pub'],
    'review-build': FLUTTER + ['build', 'windows', '--release', '--no-pub',
                             '-t', 'tool/focus_audio_session3_review.dart'],
    'android-build': FLUTTER + ['build', 'apk', '--debug', '--target-platform', 'android-arm64', '--no-pub'],
    'format': [RTK, 'proxy', 'D:/SDKs/flutter/bin/cache/dart-sdk/bin/dart.exe', 'format',
               '--output=none', '--set-exit-if-changed', str(ROOT / 'mobile/lib'),
               str(ROOT / 'mobile/test/focus_sounds_ui_test.dart'),
               str(ROOT / 'mobile/test/focus_audio_test.dart'),
               str(ROOT / 'mobile/test/focus_audio_support.dart'),
               str(ROOT / 'mobile/tool/focus_audio_session3_review.dart')],
}

def main():
    OUT.mkdir(parents=True, exist_ok=True)
    env = dict(os.environ, JAVA_HOME='D:/Android/jdk/jdk-17.0.19+10',
               ANDROID_HOME='D:/Android/sdk', ANDROID_SDK_ROOT='D:/Android/sdk',
               FLUTTER_ROOT='D:/SDKs/flutter', TEMP=str(ROOT / '.tools/tmp'), TMP=str(ROOT / '.tools/tmp'))
    env['PATH'] = env['JAVA_HOME'] + '/bin;' + env['PATH']
    failed = False
    for name in sys.argv[1:]:
        command = COMMANDS[name]
        stamp = time.time_ns()
        log = OUT / f'{name}-{stamp}.log'
        print(f'Starting {name}', flush=True)
        sources = {p.relative_to(ROOT).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest()
                   for folder in ['mobile/lib', 'mobile/test', 'mobile/tool']
                   for p in (ROOT/folder).rglob('*.dart')}
        start = time.monotonic()
        with log.open('w', encoding='utf-8') as output:
            result = subprocess.run(command, cwd=ROOT, env=env, stdout=output,
                                    stderr=subprocess.STDOUT, timeout=1200)
        record = dict(check=name, command=command, exit_code=result.returncode,
                      elapsed_seconds=time.monotonic()-start, log=log.relative_to(ROOT).as_posix(),
                      source_sha256=sources)
        (OUT / f'{name}-{stamp}.json').write_text(json.dumps(record, indent=2)+'\n')
        print(json.dumps({k: v for k, v in record.items() if k != 'source_sha256'}), flush=True)
        if result.returncode:
            failed = True
            print(log.read_text(encoding='utf-8', errors='replace')[-16000:], flush=True)
    raise SystemExit(1 if failed else 0)

if __name__ == '__main__':
    main()
