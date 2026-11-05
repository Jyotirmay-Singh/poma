"""Local Windows release inventory and PE import audit. No network or OS changes."""
from __future__ import annotations

import argparse
import gzip
import hashlib
import json
import os
from pathlib import Path
import struct
import subprocess
from datetime import datetime, timezone

ROOT = Path(__file__).resolve().parents[1]


def sha256(path: Path) -> str:
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def pe_imports(path: Path) -> list[str]:
    """Read normal and delay imports without loading executable code."""
    data = path.read_bytes()
    pe = struct.unpack_from("<I", data, 0x3C)[0]
    if data[pe:pe + 4] != b"PE\0\0":
        raise ValueError(f"Not PE: {path.name}")
    machine, count = struct.unpack_from("<HH", data, pe + 4)
    if machine != 0x8664:
        raise ValueError(f"Non-x64 binary: {path.name}")
    opt_size = struct.unpack_from("<H", data, pe + 20)[0]
    opt = pe + 24
    if struct.unpack_from("<H", data, opt)[0] != 0x20B:
        raise ValueError(f"Non-PE32+ binary: {path.name}")
    sections = []
    for i in range(count):
        section = opt + opt_size + i * 40
        virtual_size, rva, size, offset = struct.unpack_from("<IIII", data, section + 8)
        sections.append((rva, max(virtual_size, size), offset))

    def locate(rva: int) -> int:
        for start, size, offset in sections:
            if start <= rva < start + size:
                return offset + rva - start
        raise ValueError(f"Invalid import RVA in {path.name}")

    def string(rva: int) -> str:
        start = locate(rva)
        return data[start:data.index(b"\0", start)].decode("ascii").lower()

    names = set()
    for index, width, name_index in [(1, 20, 3), (13, 32, 1)]:
        rva, size = struct.unpack_from("<II", data, opt + 112 + index * 8)
        if not rva:
            continue
        start = locate(rva)
        for offset in range(start, start + size, width):
            row = struct.unpack_from("<" + "I" * (width // 4), data, offset)
            if not any(row):
                break
            name_rva = row[name_index]
            if index == 13 and not row[0] & 1:
                raise ValueError("Unsupported VA delay-import table")
            names.add(string(name_rva))
    return sorted(names)


def source_identity() -> dict:
    rtk = ROOT / ".tools/rtk/rtk.exe"
    prefix = [str(rtk), "proxy"] if rtk.exists() else ["rtk", "proxy"]
    def git(*args: str) -> str:
        return subprocess.check_output([*prefix, "git", *args], cwd=ROOT).decode("utf-8").strip()
    files = git("ls-files", "--cached", "--others", "--exclude-standard", "-z").split("\0")
    # The owner's unrelated Calendar planning document is preserved, not part of
    # the implementation identity or installation kit.
    files = [name for name in files if name.startswith(("mobile/", "scripts/", "release/windows/"))]
    entries = [{"path": name, "sha256": sha256(ROOT / name)} for name in sorted(files) if (ROOT / name).is_file()]
    digest = hashlib.sha256(json.dumps(entries, sort_keys=True).encode()).hexdigest()
    return {"baseCommit": git("rev-parse", "HEAD"), "branch": git("branch", "--show-current"),
            "uncommitted": bool(git("status", "--porcelain")), "sourceTreeSha256": digest,
            "files": entries, "lockfileSha256": sha256(ROOT / "mobile/pubspec.lock")}


def stage_inventory(stage: Path, version: str) -> None:
    required = ["poma.exe", "flutter_windows.dll", "sqlite3.dll", "flutter_local_notifications_windows.dll",
                "data/app.so", "data/icudtl.dat", "data/flutter_assets/NOTICES.Z", "AppxManifest.xml",
                "msvcp140.dll", "vcruntime140.dll", "vcruntime140_1.dll"]
    for name in required:
        if not (stage / name).is_file():
            raise ValueError(f"Missing runtime file: {name}")
    assets = json.loads((stage / 'data/flutter_assets/NativeAssetsManifest.json').read_text())
    sqlite_asset = assets['native-assets']['windows_x64']['package:sqlite3/src/ffi/libsqlite3.g.dart']
    if sqlite_asset != ['absolute', 'sqlite3.dll']:
        raise ValueError('Review SQLite runtime resolution; expected the package-local basename')
    if (stage / 'native_assets.json').exists():
        raise ValueError('Do not distribute the development native-assets manifest containing build paths')
    prohibited = {".pfx", ".p12", ".key", ".db", ".sqlite", ".jks", ".pdb"}
    for file in stage.rglob("*"):
        if file.suffix.lower() in prohibited or file.name.startswith(".env"):
            raise ValueError(f"Unexpected private/development file: {file.name}")
    licenses = stage / "Licenses"
    licenses.mkdir(exist_ok=True)
    (licenses / "Flutter-and-packages.txt").write_bytes(gzip.decompress((stage / "data/flutter_assets/NOTICES.Z").read_bytes()))
    binaries = [p for p in stage.rglob("*") if p.suffix.lower() in {".exe", ".dll", ".so"}]
    local = {p.name.lower() for p in binaries}
    system = Path(os.environ["SystemRoot"]) / "System32"
    imports = {}
    for binary in binaries:
        if binary.relative_to(stage).as_posix() == 'data/app.so':
            header = binary.read_bytes()[:64]
            if header[:6] != b'\x7fELF\x02\x01' or struct.unpack_from('<H', header, 18)[0] != 62:
                raise ValueError('Expected the Flutter ELF64 x86-64 AOT snapshot')
            imports['data/app.so'] = [{"source": "Dart AOT snapshot loaded by the bundled Flutter engine", "architecture": "x86-64 ELF64"}]
            continue
        imports[binary.relative_to(stage).as_posix()] = []
        for dependency in pe_imports(binary):
            if dependency in local:
                location = "package"
            elif dependency.startswith(("api-ms-win-", "ext-ms-win-")):
                location = "Windows API set"
            elif dependency.startswith(("msvcp", "vcruntime", "concrt")):
                raise ValueError(f"VC runtime is not application-local: {dependency}")
            elif (system / dependency).is_file():
                location = "Windows System32 (static import checked on build host)"
            else:
                raise ValueError(f"Unresolved dependency: {binary.name} -> {dependency}")
            imports[binary.relative_to(stage).as_posix()].append({"name": dependency, "source": location})
    records = [{"path": p.relative_to(stage).as_posix(), "bytes": p.stat().st_size, "sha256": sha256(p)}
               for p in sorted(stage.rglob("*")) if p.is_file() and p.name != "build-inventory.json"]
    inventory = {"version": version, "architecture": "x64", "supportTarget": "Windows 11 25H2 build 26200",
                 "builtUtc": datetime.now(timezone.utc).isoformat(), "source": source_identity(),
                 "peImports": imports, "files": records,
                 "limitations": ["Static imports are not loaded-module or clean-profile evidence.",
                                 "Packaged installation, sleep, notification presentation, and offline acceptance require recorded observations."]}
    (stage / "build-inventory.json").write_text(json.dumps(inventory, indent=2) + "\n", encoding="utf-8")
    print(f"Audited {len(binaries) - 1} x64 PE files, the x64 AOT snapshot, and {len(records)} package files.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("stage", type=Path)
    parser.add_argument("--version", required=True)
    args = parser.parse_args()
    stage_inventory(args.stage.resolve(), args.version)
