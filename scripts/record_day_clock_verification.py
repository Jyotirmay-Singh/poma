"""Record local deterministic Day Clock checks and reproducible file identities."""

import argparse
import hashlib
import json
import re
from pathlib import Path
import subprocess
import sys
from datetime import datetime, timezone
from urllib.parse import unquote


ROOT = Path(__file__).resolve().parents[1]
EVIDENCE = ROOT / "artifacts/day-clock/session3"
RTK = ROOT / ".tools/rtk/rtk.exe"
FINAL_CHECKS = ["captures-final", "flutter-final", "analysis-verified",
                "format-final", "native-tests", "windows-final", "patch-whitespace"]


def stamp():
    return datetime.now(timezone.utc).isoformat()


def hashed(path):
    return {"path": path.relative_to(ROOT).as_posix(),
            "sha256": hashlib.sha256(path.read_bytes()).hexdigest()}


def compiled_version(path):
    import ctypes
    import struct
    api = ctypes.windll.version
    filename = ctypes.c_wchar_p(str(path))
    size = api.GetFileVersionInfoSizeW(filename, None)
    if not size:
        return None
    data = ctypes.create_string_buffer(size)
    if not api.GetFileVersionInfoW(filename, 0, size, data):
        return None
    pointer, length = ctypes.c_void_p(), ctypes.c_uint()
    if not api.VerQueryValueW(data, ctypes.c_wchar_p("\\"),
                             ctypes.byref(pointer), ctypes.byref(length)):
        return None
    fields = struct.unpack("<13I", ctypes.string_at(pointer, 52))
    return ".".join(str(n) for n in
                    [fields[2] >> 16, fields[2] & 65535, fields[3] >> 16, fields[3] & 65535])


def run(label, command):
    EVIDENCE.mkdir(parents=True, exist_ok=True)
    result_path = EVIDENCE / f"{label}.result.json"
    result_path.unlink(missing_ok=True)
    started = stamp()
    with (EVIDENCE / f"{label}.log").open("w", encoding="utf-8") as log:
        process = subprocess.Popen(command, cwd=ROOT, stdout=subprocess.PIPE,
                                   stderr=subprocess.STDOUT, text=True,
                                   encoding="utf-8", errors="replace")
        for line in process.stdout:
            log.write(line)
            log.flush()
            print(line, end="", flush=True)
        code = process.wait()
    result_path.write_text(json.dumps({
        "command": command, "startedUtc": started, "finishedUtc": stamp(),
        "exitCode": code,
    }, indent=2) + "\n", encoding="utf-8")
    return code


def manifest():
    listed = subprocess.check_output(
        [str(RTK), "proxy", "git", "ls-files", "--cached", "--others", "--exclude-standard"],
        cwd=ROOT, text=True, encoding="utf-8").splitlines()
    prefixes = ("mobile/lib/", "mobile/test/", "mobile/windows/",
                "mobile/integration_test/", "mobile/assets/")
    exact = {"mobile/pubspec.yaml", "mobile/pubspec.lock", "mobile/analysis_options.yaml",
             "mobile/windows/CMakeLists.txt", "scripts/flutter.ps1",
             "scripts/test_windows_native.ps1", "scripts/prepare_windows_links.ps1",
             "scripts/record_day_clock_verification.py"}
    sources = [hashed(ROOT / p) for p in sorted(set(listed))
               if (p.startswith(prefixes) or p in exact) and (ROOT / p).is_file()]
    source_hash = hashlib.sha256("\n".join(
        f"{e['path']}\t{e['sha256']}" for e in sources).encode()).hexdigest()
    runtime = ROOT / "mobile/build/windows/x64/runner/Release"
    results = {p.stem.removesuffix(".result"): json.loads(p.read_text(encoding="utf-8"))
               for p in sorted(EVIDENCE.glob("*.result.json"))}
    data = {
        "schemaVersion": 1, "recordedUtc": stamp(),
        "baseCommit": subprocess.check_output([str(RTK), "proxy", "git", "rev-parse", "HEAD"],
                                             cwd=ROOT, text=True).strip(),
        "sourceState": "Uncommitted Session 1/2/3 source ready for review",
        "sourceSetSha256": source_hash,
        "flutter": "3.44.2", "dart": "3.12.2",
        "frameworkRevision": "c9a6c484230f8b5e408ec57be1ef71dee1e77020",
        "entrypoint": "lib/main.dart", "buildProfile": "Release",
        "compiledFileVersion": compiled_version(runtime / "poma.exe"),
        "calendarConfiguration": "Unconfigured compilation; no private Google defines supplied",
        "liveGoogleAcceptance": "Pending; owner selected fictional deterministic verification",
        "installedAppAcceptance": "Pending", "assistiveTechnologyAcceptance": "Pending",
        "installed": False, "published": False,
        "sourceFiles": sources,
        "runtimeFiles": [hashed(p) for p in sorted(runtime.rglob("*")) if p.is_file()],
        "screenshots": [hashed(p) for p in sorted((EVIDENCE / "screenshots").rglob("*.png"))],
        "verificationLogs": [hashed(p) for p in sorted(EVIDENCE.glob("*.log"))],
        "verificationInputs": [hashed(EVIDENCE / "capture-defines.json")],
        "commands": results,
        "finalCheckLabels": FINAL_CHECKS,
        "documentationFiles": [hashed(ROOT / "docs" / name) for name in
                               ["DAY_CLOCK_PLAN.md", "DAY_CLOCK_PROGRESS.md", "DAY_CLOCK_VERIFICATION.md"]
                               if (ROOT / "docs" / name).is_file()],
    }
    target = EVIDENCE / "verification-manifest.json"
    target.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"sourceSetSha256": source_hash,
                      **{k: len(data[k]) for k in ["sourceFiles", "runtimeFiles", "screenshots", "verificationLogs"]}}, indent=2))


def audit():
    data = json.loads((EVIDENCE / "verification-manifest.json").read_text(encoding="utf-8"))
    mismatches = []
    for category in ["sourceFiles", "runtimeFiles", "screenshots", "verificationLogs", "verificationInputs", "documentationFiles"]:
        for entry in data[category]:
            path = ROOT / entry["path"]
            if not path.is_file() or hashed(path)["sha256"] != entry["sha256"]:
                mismatches.append(entry["path"])
    failed = [name for name in FINAL_CHECKS if data["commands"].get(name, {}).get("exitCode") != 0]
    missing, links = [], 0
    for name in ["DAY_CLOCK_PLAN.md", "DAY_CLOCK_PROGRESS.md", "DAY_CLOCK_VERIFICATION.md"]:
        doc = ROOT / "docs" / name
        for target in re.findall(r"\]\(([^)]+)\)", doc.read_text(encoding="utf-8")):
            if re.match(r"[a-z]+://|#", target, re.I):
                continue
            links += 1
            if not (doc.parent / unquote(target.split("#", 1)[0])).resolve().exists():
                missing.append({"document": name, "target": target})
    final_run = data["commands"]["captures-final"]
    start = datetime.fromisoformat(final_run["startedUtc"]).timestamp()
    end = datetime.fromisoformat(final_run["finishedUtc"]).timestamp()
    old_captures = [e["path"] for e in data["screenshots"]
                    if not start <= (ROOT / e["path"]).stat().st_mtime <= end]
    result = {"manifestHashMismatches": mismatches, "failedFinalChecks": failed,
              "checkedLocalLinks": links, "missingLocalLinks": missing,
              "capturesOutsideFinalRun": old_captures,
              "installed": False, "published": False,
              "liveGoogleAcceptance": "Pending", "assistiveTechnologyAcceptance": "Pending"}
    (EVIDENCE / "final-audit.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(result, indent=2))
    return int(bool(mismatches or failed or missing or old_captures))


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("action", choices=["run", "manifest", "audit"])
    parser.add_argument("label", nargs="?")
    parser.add_argument("command", nargs=argparse.REMAINDER)
    args = parser.parse_args()
    if args.action == "manifest":
        manifest()
    elif args.action == "audit":
        sys.exit(audit())
    else:
        if not args.label or not args.label.replace("-", "").isalnum():
            parser.error("Use an alphanumeric log label")
        command = args.command[1:] if args.command[:1] == ["--"] else args.command
        if not command or Path(command[0]).resolve() != RTK.resolve():
            parser.error("Checks must run through the repository RTK wrapper")
        sys.exit(run(args.label, command))
