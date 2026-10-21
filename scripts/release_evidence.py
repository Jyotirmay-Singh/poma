"""Standard-library evidence collection; no package execution or extraction."""

import argparse
import hashlib
import json
from datetime import datetime, timezone
from pathlib import Path
import subprocess
import zipfile


def digest(data):
    return hashlib.sha256(data).hexdigest()


def source(root, rtk):
    def git(*args):
        return subprocess.check_output([rtk, "proxy", "git", *args], cwd=root)

    names = sorted(set(git("ls-files", "-z", "--cached", "--others", "--exclude-standard").decode().split("\0")) - {""})
    files = []
    for name in names:
        path = root / name
        if path.is_file():
            data = path.read_bytes()
            files.append({"path": name.replace("\\", "/"), "bytes": len(data), "sha256": digest(data)})
    canonical = json.dumps(files, sort_keys=True, separators=(",", ":")).encode()
    return {
        "head": git("rev-parse", "HEAD").decode().strip(),
        "sourceFingerprintSha256": digest(canonical),
        "method": "Canonical path/byte-length/SHA-256 records of tracked and nonignored untracked files; ignored files excluded",
        "status": git("status", "--porcelain=v1").decode(),
        "files": files,
    }


def archive(path):
    data = path.read_bytes()
    entries = []
    with zipfile.ZipFile(path) as package:
        for ordinal, entry in enumerate(package.infolist()):
            if entry.flag_bits & 1:
                entries.append({"ordinal": ordinal, "path": entry.filename, "encrypted": True, "sha256": None})
                continue
            member = package.read(entry)
            entries.append({
                "ordinal": ordinal, "path": entry.filename,
                "bytes": entry.file_size, "compressedBytes": entry.compress_size,
                "compressionMethod": entry.compress_type, "crc32": f"{entry.CRC:08x}",
                "sha256": digest(member), "encrypted": False,
            })
    return {
        "path": str(path.resolve()), "bytes": len(data), "MiB": len(data) / 1048576,
        "sha256": digest(data), "memberCount": len(entries), "members": entries,
        "limitations": [
            "ZIP member inventory and decoded member hashes only; not code execution or signature verification.",
            "APK signing blocks and other non-entry bytes are included in the root digest, not the member inventory.",
            "Artifact bytes are not installed size or store-estimated download size.",
        ],
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("operation", choices=("source", "archive"))
    parser.add_argument("paths", nargs="*")
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--rtk", default="rtk")
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    result = {"recordedUtc": datetime.now(timezone.utc).isoformat(), "collector": "release_evidence.py/1"}
    if args.operation == "source":
        result.update(source(args.root, args.rtk))
    else:
        if not args.paths:
            parser.error("archive requires at least one path")
        result["artifacts"] = [archive(Path(path)) for path in args.paths]
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"output": str(args.output), "operation": args.operation, "artifacts": len(result.get("artifacts", [])), "sourceFingerprintSha256": result.get("sourceFingerprintSha256")}))


if __name__ == "__main__":
    main()
