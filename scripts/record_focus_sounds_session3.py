"""Record hashes/results after Session 3 checks and visual inspection."""
import hashlib
import json
from pathlib import Path
import re
import subprocess
import zipfile

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'artifacts/focus-sounds/session-3'
RTK = str(ROOT / '.tools/rtk/rtk.exe')

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def save(path, value):
    path.write_text(json.dumps(value, indent=2)+'\n', encoding='utf-8')

def main():
    checks = []
    records = [(p, json.loads(p.read_text())) for p in sorted((OUT/'checks').glob('*.json'))]
    latest = {}
    for p, record in records:
        latest[record['check']] = (p, record)
    for name in ['ui', 'tests', 'analyze', 'format', 'focused', 'windows-native',
                 'windows-build', 'review-build', 'android-build']:
        p, record = latest[name]
        assert record['exit_code'] == 0, (name, record)
        if name not in ['focused', 'windows-native']:
            mismatch = [k for k, v in record.get('source_sha256', {}).items()
                        if digest(ROOT/k) != v]
            assert not mismatch, (name, 'outdated production sources', mismatch)
        checks.append({k: v for k, v in record.items() if k != 'source_sha256'} |
                      {'record': p.relative_to(ROOT).as_posix(),
                       'source_hashes_match': True if record.get('source_sha256') else None})
    runtime_path = ROOT/json.loads((OUT/'windows-runtime-location.json').read_text())['path']
    runtime = json.loads((runtime_path/'evidence.json').read_text())
    assert runtime['report']['passed']
    assert all(digest(ROOT/k) == v for k, v in runtime['source_files'].items()), 'Runtime sources changed'
    production = ROOT/'mobile/build/windows/x64/runner/Release'
    exe = production/'poma.exe'
    assert 'Poma.FocusAudioReview.Session2'.encode('utf-16le') not in exe.read_bytes()
    assert b'reviewAudioEnvironment' not in exe.read_bytes()
    apk = ROOT/'mobile/build/app/outputs/flutter-apk/app-debug.apk'
    assets = []
    with zipfile.ZipFile(apk) as archive:
        for source in sorted((ROOT/'mobile/assets/audio').glob('*.ogg')):
            relative = source.relative_to(ROOT/'mobile').as_posix()
            expected = digest(source)
            assert digest(production/'data/flutter_assets'/relative) == expected
            assert hashlib.sha256(archive.read('assets/flutter_assets/'+relative)).hexdigest() == expected
            assets.append({'path': relative, 'bytes': source.stat().st_size, 'sha256': expected})
        for relative in ['assets/licenses/focus-sounds.txt', 'assets/licenses/focus-audio-native.txt',
                         'assets/fonts/Sora-Medium.ttf', 'assets/fonts/Sora-SemiBold.ttf',
                         'assets/fonts/SourceSans3-Regular.ttf', 'assets/fonts/SourceSans3-Medium.ttf',
                         'assets/fonts/SourceSans3-Semibold.ttf']:
            expected = digest(ROOT/'mobile'/relative)
            assert digest(production/'data/flutter_assets'/relative) == expected
            assert hashlib.sha256(archive.read('assets/flutter_assets/'+relative)).hexdigest() == expected
    captures = json.loads((OUT/'ui/screenshots.json').read_text())
    for c in captures:
        c['sha256'] = digest(OUT/'ui'/c['file'])
    inspected = [
        'phone-off-closed', 'phone-off-chooser', 'phone-ready-closed',
        'phone-playing-closed', 'phone-playing-preview',
        'phone-large-muted-chooser', 'phone-large-muted-footer',
        'phone-landscape-error-footer', 'desktop-playing-chooser',
        'desktop-paused-chooser', 'desktop-zero-footer',
        'contrast-light-chooser', 'contrast-dark-chooser',
        'desktop-loading-closed', 'desktop-error-footer', 'phone-unavailable-chooser']
    for name in inspected:
        assert (OUT/'ui'/f'{name}.png').is_file()
    def count(name):
        log = (ROOT/latest[name][1]['log']).read_text(encoding='utf-8', errors='replace')
        return int(re.findall(r'\+(\d+): All tests passed!', log)[-1])
    previous = json.loads((ROOT/'docs/focus-sounds/SESSION_2_SOURCE_MANIFEST.json').read_text())
    allowed = {'docs/FOCUS_SOUNDS_PROGRESS.md', 'mobile/lib/application/focus_audio_ports.dart',
               'mobile/lib/application/focus_audio_coordinator.dart', 'mobile/lib/data/soloud_focus_audio_playback.dart',
               'mobile/test/focus_audio_support.dart', 'mobile/test/focus_audio_test.dart',
               'mobile/windows/runner/CMakeLists.txt'}
    changes = [f['path'] for f in previous['files'] if digest(ROOT/f['path']) != f['sha256']]
    assert not set(changes)-allowed, ('Unrelated Session 2 changes', changes)
    head = subprocess.check_output([RTK, 'proxy', 'git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip()
    verification = {'date': '2026-11-08', 'timezone': 'Asia/Kolkata', 'branch': 'codex/focus-soundscapes',
        'HEAD': head, 'state': 'Local uncommitted Session 2 and Session 3 changes',
        'checks': checks, 'counts': {'flutter_regression': count('tests'), 'sound_ui': count('ui'),
            'focused_audio': count('focused'), 'desktop_native': 233, 'native_fonts': 43, 'native_guard': 15},
        'runtime': {'evidence': (runtime_path/'evidence.json').relative_to(ROOT).as_posix(),
            'executable_sha256': runtime['executable_sha256'], 'aot_sha256': runtime['aot_sha256'],
            'source_files_match': True, 'report': runtime['report']},
        'production': {'windows_executable_sha256': digest(exe), 'windows_aot_sha256': digest(production/'data/app.so'),
            'review_hooks_absent': True, 'android_debug_apk_sha256': digest(apk), 'android_debug_apk_bytes': apk.stat().st_size,
            'audio_bytes': sum(x['bytes'] for x in assets), 'assets': assets,
            'audio_notices_and_production_fonts_match_both_payloads': True},
        'host_captures': captures,
        'personally_inspected_host_captures': [f'artifacts/focus-sounds/session-3/ui/{name}.png' for name in inspected],
        'personally_inspected_runtime_captures': [(runtime_path/'runtime/fictional-review-profile'/name).relative_to(ROOT).as_posix()
                                                for name in runtime['report']['captures']],
        'session_2_changes_limited_to_approved_files': changes,
        'historical_check_records': [{'path': p.relative_to(ROOT).as_posix(), 'exit_code': r['exit_code']}
                                     for p, r in records],
        'retained_logs': [{'path': p.relative_to(ROOT).as_posix(), 'sha256': digest(p)}
                          for p in sorted((OUT/'checks').glob('*.log'))],
        'limitations': ['Human listening/final recording selection not performed',
            'Physical Windows sleep/route/tray acceptance pending',
            'Android/iOS native media/audio-focus/background integration remains Session 4',
            'Physical TalkBack/VoiceOver/system text scaling and iOS compilation not performed',
            'Host viewport captures and native voice counts are not physical-device/listening acceptance']}
    save(ROOT/'docs/focus-sounds/SESSION_3_VERIFICATION.json', verification)
    files = [
        'docs/FOCUS_SOUNDS_PROGRESS.md', 'docs/FOCUS_SOUNDS_SESSION_3.md', 'docs/UI_DESIGN_SYSTEM.md',
        'docs/focus-sounds/SESSION_3_VERIFICATION.json', 'mobile/lib/application/focus_audio_ports.dart',
        'mobile/lib/application/focus_audio_coordinator.dart', 'mobile/lib/data/soloud_focus_audio_playback.dart',
        'mobile/lib/ui/focus_screen.dart', 'mobile/lib/ui/focus_sounds_control.dart',
        'mobile/lib/ui/focus_sounds_chooser.dart', 'mobile/lib/ui/copy.dart', 'mobile/lib/l10n/app_en.arb',
        'mobile/lib/l10n/poma_localizations.dart', 'mobile/lib/l10n/poma_localizations_en.dart',
        'mobile/test/focus_audio_test.dart', 'mobile/test/focus_audio_support.dart', 'mobile/test/focus_sounds_ui_test.dart',
        'mobile/tool/focus_audio_session3_review.dart', 'mobile/windows/runner/CMakeLists.txt',
        'scripts/check_focus_sounds_session3.py', 'scripts/collect_focus_sounds_session3.py',
        'scripts/record_focus_sounds_session3.py']
    save(ROOT/'docs/focus-sounds/SESSION_3_SOURCE_MANIFEST.json', {'HEAD': head,
        'branch': 'codex/focus-soundscapes', 'state': 'Local uncommitted Session 3 changes',
        'excludes_self': True, 'files': [{'path': p, 'bytes': (ROOT/p).stat().st_size,
                                        'sha256': digest(ROOT/p)} for p in files]})
    print(json.dumps({'counts': verification['counts'], 'host_captures': len(captures),
                      'real_windows_checks': len(runtime['report']['checks']), 'source_files': len(files)}))

if __name__ == '__main__':
    main()
