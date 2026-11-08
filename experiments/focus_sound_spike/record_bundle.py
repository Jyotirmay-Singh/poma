"""Retain an isolated release bundle and its exact byte inventory."""
import hashlib
import json
import shutil
import sys
from pathlib import Path

spike = Path(__file__).resolve().parent
root = spike.parents[1]
variant = sys.argv[1]
assert variant in ("baseline", "library", "assets")
source = spike / "build/windows/x64/runner/Release"
destination = root / "artifacts/focus-sounds/session-1/bundles" / variant
destination.parent.mkdir(parents=True, exist_ok=True)
shutil.copytree(source, destination, dirs_exist_ok=True)
files = [{"path": p.relative_to(source).as_posix(), "bytes": p.stat().st_size,
          "sha256": hashlib.file_digest(p.open("rb"), "sha256").hexdigest()}
         for p in sorted(source.rglob("*")) if p.is_file()]
record = {"variant": variant, "kind": "Unpackaged Windows x64 release experiment; not Poma/MSIX",
          "runtime_bytes_excluding_pdb": sum(p["bytes"] for p in files if not p["path"].endswith(".pdb")),
          "all_bytes": sum(p["bytes"] for p in files), "files": files}
for name in ("pubspec.yaml", "pubspec.lock", "lib/main.dart"):
    shutil.copyfile(spike / name, destination.parent / (variant + "-" + Path(name).name + ".txt"))
output = destination.parent / (variant + "-inventory.json")
output.write_text(json.dumps(record, indent=2) + "\n")
print(json.dumps({k: v for k, v in record.items() if k != "files"}))
