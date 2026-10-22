"""Preserve selected Android dependency declarations and embedded license/NOTICE texts."""

import argparse
import hashlib
import io
import json
from pathlib import Path
import re
from urllib.parse import unquote, urlparse
import zipfile

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--inventory", type=Path, required=True)
    parser.add_argument("--report", type=Path, required=True)
    args = parser.parse_args()
    coordinates = [x["coordinate"] for x in json.loads(args.inventory.read_text())["coordinates"]]
    cache = Path.home() / ".gradle/caches/modules-2/files-2.1"
    texts = {}
    records = []

    def inspect(archive, label):
        for name in archive.namelist():
            if re.search(r"(^|/)(NOTICE|LICENSE|COPYING)([._-]|$)", name, re.I):
                data = archive.read(name)
                digest = hashlib.sha256(data).hexdigest()
                entry = texts.setdefault(digest, {"text": data.decode("utf-8", errors="replace"), "sources": []})
                entry["sources"].append(label + ":" + name)
            elif name == "classes.jar":
                with zipfile.ZipFile(io.BytesIO(archive.read(name))) as nested:
                    inspect(nested, label + ":classes.jar")

    for coordinate in coordinates:
        group, name, version = coordinate.split(":")
        archives = sorted((cache / group / name / version).glob("*/*"))
        archives = [p for p in archives if p.suffix in (".jar", ".aar")]
        for path in archives:
            with zipfile.ZipFile(path) as archive:
                inspect(archive, coordinate)
        records.append({"coordinate": coordinate, "archivesInspected": len(archives)})
    config = ROOT / "mobile/.dart_tool/package_config.json"
    packages = json.loads(config.read_text())["packages"]
    clock = next(x for x in packages if x["name"] == "clock")
    uri = clock["rootUri"]
    package_path = Path(unquote(urlparse(uri).path.lstrip("/"))) if uri.startswith("file:") else config.parent / uri
    apache = (package_path / "LICENSE").read_text(encoding="utf-8")
    if "TERMS AND CONDITIONS FOR USE" not in apache:
        raise SystemExit("Expected the complete locally installed clock Apache 2.0 license")
    intro = (
        "Poma Android runtime dependency notices\n\n"
        "The following resolved Android coordinates are retained for attribution. "
        "The package's generated View licenses also preserves Flutter engine and Dart/plugin notices.\n\n"
        + "\n".join(coordinates) + "\n\n"
        "AndroidX, Android desugaring, Gson, Guava and Kotlin components retain their upstream "
        "Apache 2.0 terms and embedded notices below. Flutter embedding/engine notices remain "
        "in Flutter's complete generated license inventory. Declared coordinates can include "
        "build/runtime pieces removed by optimization; this inventory does not assert every class is shipped.\n\n"
        + apache + "\n\n"
    )
    body = intro + "\n\n".join(
        "Sources: " + ", ".join(sorted(set(entry["sources"]))) + "\n\n" + entry["text"]
        for _, entry in sorted(texts.items())
    )
    asset = ROOT / "mobile/assets/licenses/android-native.txt"
    asset.write_text(body, encoding="utf-8", newline="\n")
    report = {"selectedCoordinates": len(coordinates), "records": records,
              "uniqueEmbeddedTexts": len(texts), "assetSha256": hashlib.sha256(asset.read_bytes()).hexdigest(),
              "limitations": ["Declared coordinate/archive inventory; no universal legal-clearance claim.",
                              "Generated Flutter engine/Dart licenses are preserved separately in the package."]}
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps(report, indent=2)+"\n", encoding="utf-8")
    print(json.dumps({"coordinates": len(records), "archivesMissing": [r["coordinate"] for r in records if not r["archivesInspected"]],
                      "uniqueEmbeddedTexts": len(texts), "assetBytes": asset.stat().st_size}))


if __name__ == "__main__":
    main()
