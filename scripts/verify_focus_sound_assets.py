"""Verify recording provenance and actual build payloads, without opening profiles."""
import hashlib
import json
import re
import subprocess
import sys
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
RTK = ROOT / ".tools/rtk/rtk.exe"


def digest(path):
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def verify_retained_text(path, expected):
    # Git uses LF here; acquisition on Windows may have hashed CRLF.
    content = path.read_bytes().replace(b"\r\n", b"\n")
    hashes = {
        hashlib.sha256(content).hexdigest(),
        hashlib.sha256(content.replace(b"\n", b"\r\n")).hexdigest(),
    }
    assert expected in hashes, path


def versions(text):
    return {match[0]: re.search(r'^    version: "(.*?)"', match[1], re.M).group(1)
            for match in re.findall(r'^  (\w+):\n(.*?)(?=^  \w+:|^sdks:|\Z)', text, re.M | re.S)}


def main():
    data = json.loads((ROOT / "docs/focus-sounds/ASSET_PROVENANCE.json").read_text(encoding="utf-8"))
    assert len(data["candidates"]) == 8
    categories = {}
    for candidate in data["candidates"]:
        categories[candidate["category"]] = categories.get(candidate["category"], 0) + 1
        assert candidate["license"] == "CC0-1.0"
        assert digest(ROOT / candidate["original_path"]) == candidate["original_sha256"]
        evidence = candidate["license_evidence"]
        verify_retained_text(ROOT / evidence["retained_text"], evidence["retained_text_sha256"])
        terms = candidate["provider_terms"]
        verify_retained_text(ROOT / terms["retained_text"], terms["retained_text_sha256"])
    assert all(count == 2 for count in categories.values()) and len(categories) == 4
    assets = [a for a in data["prepared_assets"] if "final_asset_path" in a]
    registered = {
        "mobile/" + path for path in re.findall(
            r"^\s*-\s+(assets/audio/\S+)", (ROOT / "mobile/pubspec.yaml").read_text(encoding="utf-8"), re.M)
    }
    assert {asset["final_asset_path"] for asset in assets} == registered
    assert len(assets) == len(registered)
    for asset in assets:
        if "source" in asset:
            source = asset["source"]
            assert digest(ROOT / source["original_path"]) == source["original_sha256"]
        path = ROOT / asset["final_asset_path"]
        assert digest(path) == asset["sha256"]
        assert path.stat().st_size == asset["bytes"]
        assert asset["channels"] in (1, 2) and asset["sample_rate_hz"] == 48000
        assert float(asset["measured_loudness"]["input_tp"]) <= -2
        assert asset["seam_diagnostic"]["boundary_below_p99"]
        assert asset["listening_acceptance"] == "Pending"
    original = subprocess.run([RTK, "proxy", "git", "show", "HEAD:mobile/pubspec.lock"],
                              cwd=ROOT, text=True, capture_output=True, check=True).stdout
    old, current = versions(original), versions((ROOT / "mobile/pubspec.lock").read_text())
    changed = {name: [version, current.get(name)] for name, version in old.items() if current.get(name) != version}
    assert not changed, changed
    result = {"original_candidates_verified": 8, "two_candidates_per_category": True,
              "draft_asset_count": len(assets), "draft_asset_bytes": sum(a["bytes"] for a in assets),
              "preserved_existing_locked_packages": len(old), "changed_existing_packages": changed,
              "new_packages": {name: version for name, version in current.items() if name not in old},
              "listening": "Pending; numerical diagnostics do not certify audible quality"}
    if "--packages" in sys.argv:
        bundle = ROOT / "mobile/build/windows/x64/runner/Release"
        for asset in assets:
            target = bundle / "data/flutter_assets" / asset["final_asset_path"].removeprefix("mobile/")
            assert digest(target) == asset["sha256"], target
        audio_payload = list((bundle / "data/flutter_assets/assets/audio").iterdir())
        assert len(audio_payload) == len(assets)
        for name in ("flutter_soloud_plugin", "ogg", "opus", "vorbis", "vorbisenc", "vorbisfile", "FLAC"):
            assert (bundle / (name + ".dll")).is_file(), name
        for name in ("focus-sounds.txt", "focus-audio-native.txt"):
            assert digest(bundle / "data/flutter_assets/assets/licenses" / name) == digest(ROOT / "mobile/assets/licenses" / name)
        result["windows_release_payload"] = f"{len(assets)} exact audio hashes, both notices and seven audio DLLs verified"
        apk = ROOT / "mobile/build/app/outputs/flutter-apk/app-debug.apk"
        if "--windows-only" not in sys.argv and apk.exists():
            assert apk.stat().st_mtime >= (ROOT / "mobile/pubspec.yaml").stat().st_mtime, "Build the current APK before claiming payload verification"
            with zipfile.ZipFile(apk) as archive:
                for asset in assets:
                    name = "assets/flutter_assets/" + asset["final_asset_path"].removeprefix("mobile/")
                    assert hashlib.sha256(archive.read(name)).hexdigest() == asset["sha256"]
                assert any("flutter_soloud" in name and name.endswith(".so") for name in archive.namelist())
                for name in ("focus-sounds.txt", "focus-audio-native.txt"):
                    assert hashlib.sha256(archive.read("assets/flutter_assets/assets/licenses/" + name)).hexdigest() == digest(ROOT / "mobile/assets/licenses" / name)
            result["android_debug_payload"] = {"result": f"{len(assets)} exact audio hashes, notices and audio native library verified", "bytes": apk.stat().st_size, "sha256": digest(apk)}
    output = ROOT / "artifacts/focus-sounds/session-1/asset-verification.json"
    output.write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
