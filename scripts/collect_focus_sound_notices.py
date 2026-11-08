"""Retain runtime audio notices from the qualified package and primary upstreams."""
import hashlib
import json
from pathlib import Path
from urllib.parse import unquote, urlparse
from urllib.request import urlopen

ROOT = Path(__file__).resolve().parents[1]


def main():
    config = json.loads((ROOT / "experiments/focus_sound_spike/.dart_tool/package_config.json").read_text())
    uri = next(p["rootUri"] for p in config["packages"] if p["name"] == "flutter_soloud")
    package = Path(unquote(urlparse(uri).path).lstrip("/"))
    assert "4.1.7" in package.name
    destination = ROOT / "mobile/assets/licenses/focus-audio-native.txt"
    parts = ["Poma focus audio native components — flutter_soloud 4.1.7\n"
             "Package integrity is pinned in pubspec.lock. Notices below are retained from\n"
             "the published package and primary codec upstreams. FFmpeg is preparation\n"
             "tooling only and is not linked into or distributed with Poma.\n"]
    records = []
    paths = ["LICENSE", "src/soloud/LICENSE", "src/filters/signalsmith-stretch/LICENSE.txt",
             "src/filters/signalsmith-linear/LICENSE.txt", "src/pffft/pffft.h",
             "src/soloud/src/backend/miniaudio/miniaudio.h",
             "src/soloud/src/audiosource/wav/dr_wav.h",
             "src/soloud/src/audiosource/wav/dr_mp3.h",
             "src/soloud/src/audiosource/wav/dr_flac.h"]
    for relative in paths:
        raw = (package / relative).read_bytes()
        text = raw.decode("utf-8", errors="strict")
        if relative.endswith("pffft.h"):
            notice = text[:text.index("*/") + 2]
        elif relative.endswith(".h"):
            index = text.rfind("This software is available as a choice")
            assert index >= 0, relative
            start = text.rfind("/*", 0, index)
            notice = text[start:text.index("*/", index) + 2]
        else:
            notice = text
        parts.append(f"\n=== Published flutter_soloud 4.1.7: {relative} ===\n\n{notice}\n")
        records.append({"source": "flutter_soloud 4.1.7/" + relative,
                        "source_sha256": hashlib.sha256(raw).hexdigest(),
                        "notice_sha256": hashlib.sha256(notice.encode()).hexdigest()})
    codecs = {
        "libogg": "https://raw.githubusercontent.com/xiph/ogg/master/COPYING",
        "libvorbis": "https://raw.githubusercontent.com/xiph/vorbis/master/COPYING",
        "libopus": "https://raw.githubusercontent.com/xiph/opus/main/COPYING",
        "libFLAC": "https://raw.githubusercontent.com/xiph/flac/master/COPYING.Xiph",
    }
    evidence = ROOT / "docs/focus-sounds/license-evidence"
    for name, url in codecs.items():
        with urlopen(url, timeout=60) as response:
            raw = response.read()
        text = raw.decode("utf-8")
        assert "Redistribution" in text
        (evidence / (name + "-COPYING.txt")).write_bytes(raw)
        parts.append(f"\n=== {name}; {url} ===\n\n{text}\n")
        records.append({"source": url, "sha256": hashlib.sha256(raw).hexdigest(),
                        "scope": "Notice for corresponding runtime codec DLL supplied with the pinned package; binary inventory retained separately"})
    destination.write_text("\n".join(parts), encoding="utf-8")
    (ROOT / "docs/focus-sounds/NATIVE_LICENSE_SOURCES.json").write_text(json.dumps(
        {"package": "flutter_soloud 4.1.7", "notice_sources": records,
         "bundled_notice_path": destination.relative_to(ROOT).as_posix(),
         "bundled_notice_sha256": hashlib.sha256(destination.read_bytes()).hexdigest()}, indent=2) + "\n")
    original = ROOT / "docs/focus-sounds/license-evidence/CC0-1.0-legalcode.txt"
    credits = ["Poma focus sounds — prepared draft recordings (listening approval pending).",
               "All recordings: CC0 1.0 Universal; https://creativecommons.org/publicdomain/zero/1.0/",
               "Edited for loop preparation and level; no endorsement is implied.", ""]
    provenance = json.loads((ROOT / "docs/focus-sounds/ASSET_PROVENANCE.json").read_text())
    selected = {a["candidate_id"] for a in provenance["prepared_assets"] if "final_asset_path" in a}
    for candidate in provenance["candidates"]:
        if candidate["candidate_id"] in selected:
            credits += [candidate["category"] + " — " + candidate["creator"], candidate["source_url"], ""]
    (ROOT / "mobile/assets/licenses/focus-sounds.txt").write_text("\n".join(credits) + "\n" + original.read_text(), encoding="utf-8")
    print(f"Retained {len(records)} audio runtime notice sources and four CC0 recording credits")


if __name__ == "__main__":
    main()
