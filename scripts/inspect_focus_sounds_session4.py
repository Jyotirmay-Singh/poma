"""Inspect actual build payloads, identities, native alignment and size deltas."""
import hashlib
import json
import os
from pathlib import Path
import struct
import subprocess
import zipfile

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'artifacts/focus-sounds/session-4'
RTK = str(ROOT / '.tools/rtk/rtk.exe')
ENV = dict(os.environ, JAVA_HOME='D:/Android/jdk/jdk-17.0.19+10')
ENV['PATH'] = ENV['JAVA_HOME']+'/bin;'+ENV['PATH']

def digest(data):
    return hashlib.sha256(data).hexdigest()

def latest(name):
    paths = sorted((OUT/'checks').glob(name+'-*.json'))
    record = json.loads(paths[-1].read_text())
    assert record['exit_code'] == 0, record
    return record

def load_alignment(data):
    assert data[:4] == b'\x7fELF'
    if data[4] == 2:
        offset, size, count = struct.unpack_from('<Q', data, 32)[0], struct.unpack_from('<H', data, 54)[0], struct.unpack_from('<H', data, 56)[0]
        align = [struct.unpack_from('<Q', data, offset+i*size+48)[0] for i in range(count) if struct.unpack_from('<I', data, offset+i*size)[0] == 1]
    else:
        offset, size, count = struct.unpack_from('<I', data, 28)[0], struct.unpack_from('<H', data, 42)[0], struct.unpack_from('<H', data, 44)[0]
        align = [struct.unpack_from('<I', data, offset+i*size+28)[0] for i in range(count) if struct.unpack_from('<I', data, offset+i*size)[0] == 1]
    assert align and min(align) >= 16384, align
    return align

def apk(path, expected, signed):
    build_tools = sorted(Path('D:/Android/sdk/build-tools').iterdir())[-1]
    run = subprocess.run([RTK, 'proxy', str(build_tools/'aapt.exe'), 'dump', 'badging', str(path)], capture_output=True, text=True, check=True)
    package = next(x for x in run.stdout.splitlines() if x.startswith('package:'))
    assert f"name='{expected}'" in package, package
    xml = subprocess.run([RTK, 'proxy', str(build_tools/'aapt.exe'), 'dump', 'xmltree', str(path), 'AndroidManifest.xml'], capture_output=True, text=True, check=True).stdout
    for permission in ['FOREGROUND_SERVICE', 'FOREGROUND_SERVICE_MEDIA_PLAYBACK', 'WAKE_LOCK']:
        assert 'android.permission.'+permission in xml
    assert 'android.permission.RECORD_AUDIO' not in xml
    for component in ['PomaApplication', 'MainActivity', 'PomaAudioService', 'PomaAudioControlReceiver',
                      'PomaAlarmReceiver', 'PomaDismissReceiver', 'PomaRestoreReceiver']:
        assert component in xml, component
    signature = subprocess.run([RTK, 'proxy', str(build_tools/'apksigner.bat'), 'verify', '--verbose', str(path)], capture_output=True, text=True, env=ENV)
    assert (signature.returncode == 0) == signed, signature.stdout + signature.stderr
    if not signed:
        assert 'DOES NOT VERIFY' in signature.stdout + signature.stderr, signature.stdout + signature.stderr
    with zipfile.ZipFile(path) as archive:
        payload = []
        for source in sorted((ROOT/'mobile/assets/audio').glob('*.ogg')):
            name = 'assets/flutter_assets/assets/audio/'+source.name
            assert digest(archive.read(name)) == digest(source.read_bytes()), name
            payload.append(dict(path=name, bytes=source.stat().st_size, sha256=digest(source.read_bytes())))
        for name in ['focus-sounds.txt', 'focus-audio-native.txt']:
            assert digest(archive.read('assets/flutter_assets/assets/licenses/'+name)) == digest((ROOT/'mobile/assets/licenses'/name).read_bytes())
        native = [dict(path=i.filename, bytes=i.file_size, sha256=digest(archive.read(i)), load_alignment=load_alignment(archive.read(i)))
                  for i in archive.infolist() if i.filename.startswith('lib/') and i.filename.endswith('.so')]
        dex = b''.join(archive.read(i) for i in archive.namelist() if i.endswith('.dex'))
        assert b'PomaAudioNative;' in dex, 'Optimized JNI callback class missing'
        entries = {i.filename: dict(bytes=i.file_size, compressed_bytes=i.compress_size) for i in archive.infolist()}
    label = next((x for x in run.stdout.splitlines() if x.startswith('application-label:')), '')
    if signed and expected.endswith('.focussoundsreview'):
        assert 'Poma Sounds Review' in label
    return dict(path=path.relative_to(ROOT).as_posix(), sha256=digest(path.read_bytes()), bytes=path.stat().st_size,
        package=package, label=label, signed=signed, assets=payload, native=native, entries=entries,
        manifest=xml, signature_output=signature.stdout+signature.stderr)

def main():
    OUT.mkdir(parents=True, exist_ok=True)
    android = {}
    for name, package, signed in [('android-build', 'com.jyotirmaysingh.poma', True),
        ('android-release', 'com.jyotirmaysingh.poma', False),
        ('android-review', 'com.jyotirmaysingh.poma.focussoundsreview', True)]:
        record = latest(name)
        android[name] = apk(ROOT/record['artifact']['path'], package, signed)
    baseline_path = OUT/'baseline/app-debug.apk'
    with zipfile.ZipFile(baseline_path) as archive:
        baseline_entries = {i.filename: dict(bytes=i.file_size, compressed_bytes=i.compress_size) for i in archive.infolist()}
    current = android['android-build']
    all_names = set(baseline_entries) | set(current['entries'])
    deltas = [dict(path=name, compressed_delta=current['entries'].get(name, {}).get('compressed_bytes', 0)-baseline_entries.get(name, {}).get('compressed_bytes', 0),
        uncompressed_delta=current['entries'].get(name, {}).get('bytes', 0)-baseline_entries.get(name, {}).get('bytes', 0)) for name in sorted(all_names)]
    production_record = latest('windows-build')
    production = ROOT/production_record['runtime']['path']
    marker = 'Poma.FocusAudioReview.Session2'.encode('utf-16le')
    assert marker not in (production/'poma.exe').read_bytes(), 'Production contains review identity'
    for source in (ROOT/'mobile/assets/audio').glob('*.ogg'):
        assert digest((production/'data/flutter_assets/assets/audio'/source.name).read_bytes()) == digest(source.read_bytes())
    for name in ['focus-sounds.txt', 'focus-audio-native.txt']:
        assert digest((production/'data/flutter_assets/assets/licenses'/name).read_bytes()) == digest((ROOT/'mobile/assets/licenses'/name).read_bytes())
    baseline = OUT/'baseline/windows-runtime'
    def inventory(folder):
        return [dict(path=p.relative_to(folder).as_posix(), bytes=p.stat().st_size, sha256=digest(p.read_bytes()))
                for p in sorted(folder.rglob('*')) if p.is_file() and p.suffix not in {'.pdb', '.lib', '.exp'}]
    old, new = inventory(baseline), inventory(production)
    report = dict(audio_bytes=sum(p.stat().st_size for p in (ROOT/'mobile/assets/audio').glob('*.ogg')),
        android=android, android_debug_comparison=dict(baseline_bytes=baseline_path.stat().st_size,
            current_bytes=current['bytes'], actual_apk_delta=current['bytes']-baseline_path.stat().st_size,
            compressed_entry_delta=sum(x['compressed_delta'] for x in deltas), entries=deltas,
            conditions='Same Flutter/Dart/dependencies, ARM64 debug target with packaged dependency ABIs. APK alignment/incremental ZIP layout is separate from entry size.'),
        windows=dict(runtime=production.relative_to(ROOT).as_posix(), baseline_bytes=sum(x['bytes'] for x in old),
            current_bytes=sum(x['bytes'] for x in new), delta_bytes=sum(x['bytes'] for x in new)-sum(x['bytes'] for x in old),
            inventory=new, baseline_inventory=old, package_mode='Windows x64 release runtime; PDB/export linker artifacts excluded'),
        limitations=['Artifact inventories/deltas are not installed footprint or store download sizes',
            'APK signing and source presence do not establish physical media controls/lock/deadline behavior',
            'iOS build/payload/resource inspection unavailable without Mac/Xcode'])
    (OUT/'PAYLOAD_INSPECTION.json').write_text(json.dumps(report, indent=2)+'\n', encoding='utf-8')
    print(json.dumps(dict(audio_bytes=report['audio_bytes'], android_apk_delta=report['android_debug_comparison']['actual_apk_delta'],
        windows_runtime_delta=report['windows']['delta_bytes'], android_review=android['android-review']['package'])))

if __name__ == '__main__':
    main()
