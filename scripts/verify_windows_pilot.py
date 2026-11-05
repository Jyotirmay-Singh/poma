"""Audit a private pilot's exact MSIX payload without running it or reading user data."""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import re
import xml.etree.ElementTree as ET
import zipfile

from windows_release import ROOT, sha256


def read_json(path: Path):
    return json.loads(path.read_text(encoding="utf-8-sig"))


def audit(candidate: Path, version: str, kit: Path | None, focus_scheduling: bool = False) -> dict:
    packages = list(candidate.glob("*.msix"))
    if len(packages) != 1:
        raise ValueError("Expected one MSIX")
    package = packages[0]
    inventory = read_json(candidate / "build-inventory.json")
    if inventory["version"] != version:
        raise ValueError("Inventory version mismatch")
    findings = []
    patterns = {
        "access-token-shaped value": rb"ya29\.[A-Za-z0-9_-]{20,}",
        "refresh-token-shaped value": rb"1//[A-Za-z0-9_-]{25,}",
        "private-key PEM": rb"-----BEGIN (?:RSA |EC |ENCRYPTED )?PRIVATE KEY-----",
        "literal user credential": rb'"(?:access_token|refresh_token)"\s*:\s*"[^"\s]{16,}"',
        "authorization-return query": rb"[?&](?:code|access_token|refresh_token)=[A-Za-z0-9._~-]{20,}",
    }
    markers = (
        "session9-synthetic-access", "session9-synthetic-refresh",
        "Fictional review event", "Synthetic private occurrence",
        "synthetic-private-body", "synthetic-private-storage-detail",
        "reviewVisibility", "reviewTextScale", "fictional-review-profile",
    )
    files_scanned = 0
    bytes_scanned = 0

    def inspect(name: str, data: bytes):
        nonlocal files_scanned, bytes_scanned
        files_scanned += 1
        bytes_scanned += len(data)
        path = Path(name)
        if (path.suffix.lower() in {".pfx", ".p12", ".key", ".db", ".sqlite", ".jks", ".pdb", ".log", ".dpapi"}
                or path.name.startswith(".env")
                or re.search(r"google-oauth-desktop|poma-calendar-defines|client_secret.*[.]json|^(credentials|tokens?)[.]json$", path.name, re.I)):
            findings.append({"file": name, "kind": "private/development filename"})
        for label, pattern in patterns.items():
            if re.search(pattern, data):
                findings.append({"file": name, "kind": label})
        for marker in markers:
            if marker.encode() in data or marker.encode("utf-16-le") in data:
                findings.append({"file": name, "kind": "review-only marker"})

    with zipfile.ZipFile(package) as archive:
        names = set(archive.namelist())
        if "AppxSignature.p7x" not in names:
            raise ValueError("Pilot MSIX must be signed")
        if archive.read("build-inventory.json") != (candidate / "build-inventory.json").read_bytes():
            raise ValueError("Loose and embedded inventories differ")
        for entry in inventory["files"]:
            data = archive.read(entry["path"])
            if len(data) != entry["bytes"] or hashlib.sha256(data).hexdigest() != entry["sha256"]:
                raise ValueError(f"Inventoried payload mismatch: {entry['path']}")
        for name in sorted(names):
            if not name.endswith("/"):
                inspect(name, archive.read(name))
        manifest = ET.fromstring(archive.read("AppxManifest.xml"))
        identity = next(e.attrib for e in manifest.iter() if e.tag.endswith("}Identity"))
        expected = {"Name": "JyotirmaySingh.Poma.Desktop", "Publisher": "CN=Jyotirmay Singh",
                    "Version": version, "ProcessorArchitecture": "x64"}
        if identity != expected:
            raise ValueError("Package identity mismatch")
        startup = [e.attrib for e in manifest.iter() if e.tag.endswith("}StartupTask")]
        if len(startup) != 1 or startup[0].get("TaskId") != "PomaStartup" or startup[0].get("Enabled") != "false":
            raise ValueError("Startup must retain its identity and default off")
        activators = [e.attrib.get("ToastActivatorCLSID") for e in manifest.iter()
                      if e.tag.endswith("}ToastNotificationActivation")]
        if activators != ["970A3EE4-5721-4FC9-8AB1-FA8994C723D7"]:
            raise ValueError("Notification identity mismatch")
        public = json.loads(archive.read("public-calendar-client.json").decode("utf-8-sig"))
        if not public["configured"] or public["clientType"] != "desktop-public" or public["audience"] != "external_testing":
            raise ValueError("Expected the configured External Testing Desktop pilot")
        if public["scopes"] != [
            "https://www.googleapis.com/auth/calendar.calendarlist.readonly",
            "https://www.googleapis.com/auth/calendar.events.readonly",
        ]:
            raise ValueError("Unexpected Calendar scope")
        expected_focus = [
            "https://www.googleapis.com/auth/calendar.calendarlist.readonly",
            "https://www.googleapis.com/auth/calendar.events.readonly",
            "https://www.googleapis.com/auth/calendar.app.created",
        ]
        if focus_scheduling:
            if public.get("schemaVersion") != 2 or public.get("focusSchedulingScopes") != expected_focus:
                raise ValueError("Unexpected optional focus-scheduling scopes")
        elif public.get("focusSchedulingScopes"):
            raise ValueError("Focus scheduling requires the explicit audit mode")
        if archive.read("public-calendar-client.json") != (candidate / "public-calendar-client.json").read_bytes():
            raise ValueError("Public client summaries differ")
        if not re.fullmatch(r"\d+-[A-Za-z0-9_-]+\.apps\.googleusercontent\.com", public["clientId"]):
            raise ValueError("Invalid public client ID")
        for name in ("poma.exe", "flutter_windows.dll", "sqlite3.dll", "flutter_local_notifications_windows.dll",
                     "msvcp140.dll", "vcruntime140.dll", "vcruntime140_1.dll", "data/app.so", "data/icudtl.dat",
                     "Assets/Square44x44Logo.png", "Assets/Square150x150Logo.png",
                     "Licenses/Flutter-and-packages.txt", "Licenses/Microsoft-Visual-C-Runtime.rtf"):
            if name not in names:
                raise ValueError(f"Missing required payload: {name}")
        license_text = archive.read("Licenses/Flutter-and-packages.txt").decode("utf-8").lower()
        for dependency in ("oauth2", "http", "crypto", "timezone", "sqlite3"):
            if dependency not in license_text:
                raise ValueError(f"Missing dependency notice: {dependency}")
        assets = json.loads(archive.read("data/flutter_assets/NativeAssetsManifest.json"))
        if assets["native-assets"]["windows_x64"]["package:sqlite3/src/ffi/libsqlite3.g.dart"] != ["absolute", "sqlite3.dll"]:
            raise ValueError("SQLite requires a package-local runtime basename")
        for name, imports in inventory["peImports"].items():
            for dependency in imports:
                if dependency["source"] == "package" and dependency["name"] not in {Path(n).name.lower() for n in names}:
                    raise ValueError("Missing application-local import")
        uncompressed_bytes = sum(i.file_size for i in archive.infolist())
        member_count = len(names)

    for path in sorted(candidate.rglob("*")):
        if path.is_file() and path != package:
            inspect(path.relative_to(candidate).as_posix(), path.read_bytes())
    if findings:
        # Never include matching bytes in evidence or stdout.
        raise ValueError(f"Privacy scan findings (values suppressed): {findings}")
    mobile_changes = [entry["path"] for entry in inventory["source"]["files"]
                      if entry["path"].startswith("mobile/") and sha256(ROOT / entry["path"]) != entry["sha256"]]
    if mobile_changes:
        raise ValueError(f"Application inputs changed since assembly: {mobile_changes}")
    kit_result = None
    if kit:
        with zipfile.ZipFile(kit) as archive:
            loose = {p.relative_to(candidate).as_posix(): p for p in candidate.rglob("*") if p.is_file()}
            archived = {name.replace("\\", "/"): name for name in archive.namelist() if not name.endswith("/")}
            if set(loose) != set(archived):
                raise ValueError("Kit archive is incomplete or contains extra files")
            for name, path in loose.items():
                if hashlib.sha256(archive.read(archived[name])).hexdigest() != sha256(path):
                    raise ValueError(f"Kit differs from loose file: {name}")
        kit_result = {"filename": kit.name, "sha256": sha256(kit), "bytes": kit.stat().st_size, "files": len(loose)}
    return {
        "observedUtc": datetime.now(timezone.utc).isoformat(), "version": version,
        "package": {"filename": package.name, "sha256": sha256(package), "bytes": package.stat().st_size,
                    "members": member_count, "uncompressedBytes": uncompressed_bytes},
        "source": inventory["source"], "identity": identity, "startup": startup,
        "notificationActivator": activators[0], "publicClientConfigured": True,
        "optionalFocusScheduling": focus_scheduling,
        "publicClientIdSha256": hashlib.sha256(public["clientId"].encode()).hexdigest(),
        "payloadHashesVerified": len(inventory["files"]), "peImportInventories": len(inventory["peImports"]),
        "privacyScan": {"files": files_scanned, "bytes": bytes_scanned, "findings": []}, "kit": kit_result,
        "limitations": [
            "Static package/import checks do not establish installed runtime or clean-machine acceptance.",
            "The bounded privacy scan checks selected patterns and markers; compiled public Desktop client settings are expected.",
            "No user profile, user token, event cache or private setup file is read by this audit.",
        ],
    }


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("candidate", type=Path)
    parser.add_argument("--version", required=True)
    parser.add_argument("--kit", type=Path)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--focus-scheduling", action="store_true")
    args = parser.parse_args()
    result = audit(args.candidate.resolve(), args.version, args.kit.resolve() if args.kit else None, args.focus_scheduling)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(f"Verified signed {args.version}: {result['payloadHashesVerified']} payload hashes; privacy scan has no selected findings.")
