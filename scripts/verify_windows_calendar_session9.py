"""Bind Session 9 local acceptance evidence. No network, credentials or OS writes."""
from __future__ import annotations

import argparse
from collections import defaultdict
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import re
import statistics
import xml.etree.ElementTree as ET
import zipfile

from windows_release import ROOT, source_identity

EVIDENCE = ROOT / "artifacts/windows/calendar-session9"


def read_json(path: Path):
    return json.loads(path.read_text(encoding="utf-8-sig"))


def digest(path: Path) -> str:
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def flutter_result(name: str) -> dict:
    rows = [json.loads(line) for line in (EVIDENCE / name).read_text(
        encoding="utf-8-sig").splitlines() if line.startswith("{")]
    done = [row for row in rows if row.get("type") == "done"]
    return {"passed": bool(done and done[-1]["success"]),
            "tests": sum(row.get("type") == "testDone" and not row.get("hidden")
                         and row.get("result") == "success" for row in rows),
            "errors": sum(row.get("type") == "error" for row in rows), "log": name}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--package", type=Path, required=True)
    args = parser.parse_args()
    package = args.package.resolve()
    inventory = read_json(package.parent / "build-inventory.json")
    source = source_identity()
    if source["sourceTreeSha256"] != inventory["source"]["sourceTreeSha256"]:
        raise ValueError("Implementation inputs changed after the production build")
    compilation = read_json(ROOT / "artifacts/windows/Poma-1.0.0.2017-session9/build-inventory.json")
    compiled_changes = [e["path"] for e in compilation["source"]["files"]
                        if e["path"].startswith("mobile/") and digest(ROOT / e["path"]) != e["sha256"]]
    if compiled_changes:
        raise ValueError(f"Application inputs changed after compilation: {compiled_changes}")
    before = read_json(EVIDENCE / "before.json")
    changes = [entry["path"] for entry in before["files"]
               if not (ROOT / entry["path"]).is_file()
               or digest(ROOT / entry["path"]) != entry["sha256"]]
    allowed = {
        "README.md", "THIRD_PARTY_NOTICES.md", "docs/ARCHITECTURE.md", "docs/LOCAL_DATA.md",
        "docs/NOTIFICATIONS.md", "docs/PRIVACY_POLICY.md", "docs/PRIVACY_REVIEW.md",
        "docs/RELEASE_CHECKLIST.md", "docs/WINDOWS_CALENDAR_PROGRESS.md",
        "docs/WINDOWS_DESKTOP_RELEASE.md", "mobile/assets/legal/privacy-windows.txt",
        "mobile/assets/licenses/windows-native.txt", "mobile/lib/application/app_controller.dart",
        "mobile/windows/runner/CMakeLists.txt", "mobile/windows/runner/desktop_host.cpp",
        "release/windows/INSTALL.md",
    }
    unexpected = sorted(set(changes) - allowed)
    if unexpected:
        raise ValueError(f"Unexpected pre-existing input changes: {unexpected}")
    mobile = [entry for entry in before["files"] if entry["path"].startswith(
        ("mobile/android/", "mobile/ios/")) or entry["path"] == "mobile/.metadata"]
    mobile_changes = [e["path"] for e in mobile if digest(ROOT / e["path"]) != e["sha256"]]
    if mobile_changes:
        raise ValueError("Mobile native/metadata inputs changed")
    previous = read_json(ROOT / "artifacts/windows/calendar-session8/review.json")
    historical = dict(previous["historicalArtifactsUnchanged"])
    historical["artifacts/windows/Poma-1.0.0.2016-session8/Poma-1.0.0.2016-x64.msix"] = previous["packageSha256"]
    for name, expected in historical.items():
        if digest(ROOT / name) != expected:
            raise ValueError(f"Historical artifact changed: {name}")
    if digest(ROOT / "mobile/pubspec.lock") != previous["lockfileSha256"]:
        raise ValueError("Lockfile changed")

    findings = []
    markers = [b"session9-synthetic-access", b"session9-synthetic-refresh",
               b"Fictional review event", b"Synthetic private occurrence",
               b"synthetic-private-body", b"synthetic-private-storage-detail",
               b"reviewVisibility", b"reviewTextScale", b"fictional-review-profile"]
    patterns = {
        "Google access-token-shaped value": rb"ya29\.[A-Za-z0-9_-]{20,}",
        "Google refresh-token-shaped value": rb"1//[A-Za-z0-9_-]{25,}",
        "private-key PEM": rb"-----BEGIN (?:RSA |EC |ENCRYPTED )?PRIVATE KEY-----",
        "literal credential JSON value": rb'"(?:access_token|refresh_token)"\s*:\s*"[^"\s]{16,}"',
        "authorization-return query": rb"[?&](?:code|access_token|refresh_token)=[A-Za-z0-9._~-]{20,}",
    }
    scanned_bytes = 0
    with zipfile.ZipFile(package) as archive:
        names = set(archive.namelist())
        if "AppxSignature.p7x" in names:
            raise ValueError("Session 9 verification package must remain unsigned")
        for entry in inventory["files"]:
            payload = archive.read(entry["path"])
            if hashlib.sha256(payload).hexdigest() != entry["sha256"]:
                raise ValueError(f"Payload differs from audit: {entry['path']}")
        for name in archive.namelist():
            if name.endswith("/"):
                continue
            payload = archive.read(name)
            scanned_bytes += len(payload)
            path = Path(name)
            if (path.suffix.lower() in {".pfx", ".p12", ".key", ".db", ".sqlite", ".jks", ".pdb", ".log"}
                    or path.name.startswith(".env")
                    or re.search(r"client_secret.*[.]json$|^(credentials|tokens?)[.]json$", path.name, re.I)):
                findings.append({"file": name, "kind": "prohibited private/development filename"})
            for marker in markers:
                if marker in payload or marker.decode().encode("utf-16-le") in payload:
                    findings.append({"file": name, "kind": "selected synthetic/review marker"})
            for label, pattern in patterns.items():
                if re.search(pattern, payload):
                    findings.append({"file": name, "kind": label})
        manifest = ET.fromstring(archive.read("AppxManifest.xml"))
        identity = next(e.attrib for e in manifest.iter() if e.tag.endswith("}Identity"))
        if identity != {"Name": "JyotirmaySingh.Poma.Desktop", "Publisher": "CN=Jyotirmay Singh",
                        "Version": "1.0.0.2017", "ProcessorArchitecture": "x64"}:
            raise ValueError("Package identity changed")
        startup = [e.attrib for e in manifest.iter() if e.tag.endswith("}StartupTask")]
        if len(startup) != 1 or startup[0].get("Enabled") != "false":
            raise ValueError("Startup is not disabled by default")
        notices = archive.read("Licenses/Flutter-and-packages.txt").decode("utf-8")
        for name in ["oauth2", "http", "crypto", "timezone", "sqlite3"]:
            if not re.search(rf"\b{name}\b", notices):
                raise ValueError(f"Missing package license: {name}")
        payload_hashes = {e["path"]: e["sha256"] for e in inventory["files"]}
        package_files = len(names)

    log_files = list(EVIDENCE.glob("*.log")) + list(EVIDENCE.glob("*tests*.json"))
    for path in log_files:
        payload = path.read_bytes()
        # UTF-16 native redirection can occur on older PowerShell hosts.
        if payload.startswith((b"\xff\xfe", b"\xfe\xff")):
            payload = payload.decode("utf-16").encode()
        for label, pattern in patterns.items():
            if re.search(pattern, payload):
                findings.append({"file": path.name, "kind": label})
    logging_calls = []
    for folder, globs in [(ROOT / "mobile/lib/application", ["calendar*.dart"]),
                          (ROOT / "mobile/lib/data", ["*calendar*.dart"]),
                          (ROOT / "mobile/windows/runner", ["*.cpp", "*.h"])]:
        for glob in globs:
            for path in folder.glob(glob):
                if re.search(r"\b(?:print|debugPrint|printf|OutputDebugString[AW]?)\s*\(|developer[.]log\s*\(|std::(?:cout|cerr)",
                             path.read_text(encoding="utf-8")):
                    logging_calls.append(path.relative_to(ROOT).as_posix())
    if findings or logging_calls:
        raise ValueError(f"Inspect bounded privacy findings (values withheld): {findings}; logging paths: {logging_calls}")

    samples = read_json(EVIDENCE / "resource-samples.json")
    groups = defaultdict(list)
    for sample in samples:
        groups[sample["condition"]].append(sample)
    resources = {}
    for condition, rows in groups.items():
        resources[condition] = {"samples": len(rows), "observedSeconds": sum(r["seconds"] for r in rows)}
        for key in ["cpuPercentOfOneCore", "workingSetBytes", "privateBytes"]:
            values = [r[key] for r in rows]
            resources[condition][key] = {"min": min(values), "median": statistics.median(values), "max": max(values)}
    runtime = read_json(EVIDENCE / "runtime-observations.json")
    runtime_summary = read_json(EVIDENCE / "runtime-summary.json")
    if not runtime_summary["passed"]:
        raise ValueError("Isolated runtime did not pass")
    counter_deltas = {}
    for condition in runtime["conditions"]:
        counter_deltas[condition["condition"]] = {
            key: condition["after"][key] - value
            for key, value in condition["before"].items() if type(value) is int}
        counter_deltas[condition["condition"]]["foregroundTickerActive"] = condition["after"]["foregroundTickerActive"]
    xml_files = sorted((ROOT / "mobile/build/app/test-results/testDebugUnitTest").glob("TEST-*.xml"))
    android_tests = []
    for path in xml_files:
        root = ET.parse(path).getroot()
        android_tests.append(dict(root.attrib))
        if int(root.get("failures", "0")) or int(root.get("errors", "0")):
            raise ValueError("Android unit tests failed")
    apk = ROOT / "mobile/build/app/outputs/flutter-apk/app-debug.apk"
    with zipfile.ZipFile(apk) as archive:
        native_libs = [name for name in archive.namelist() if name.startswith("lib/") and name.endswith(".so")]
        if "lib/arm64-v8a/libsqlite3.so" not in native_libs:
            raise ValueError("Android SQLite native asset missing")
    final_tests = flutter_result("flutter-tests-final.json")
    if not final_tests["passed"]:
        raise ValueError("Final Flutter regression failed")
    analysis = (EVIDENCE / "analysis-final.log").read_text(encoding="utf-8-sig")
    if "No issues found" not in analysis:
        raise ValueError("Final static analysis is not clean")
    native_log = (EVIDENCE / "baseline-native-host.log").read_text(encoding="utf-8-sig")
    if "211 native checks passed" not in native_log:
        raise ValueError("Native check receipt missing")
    review = {
        "reviewedUtc": datetime.now(timezone.utc).isoformat(), "displayDate": "26 October 2026 (Asia/Calcutta)",
        "baseCommit": source["baseCommit"], "branch": source["branch"], "uncommittedWorkingTree": source["uncommitted"],
        "windowsVersion": "1.0.0.2017", "mobileVersion": "1.0.0+2007",
        "sourceTreeSha256": source["sourceTreeSha256"], "sourceInputs": source["files"],
        "compilationInventory": "artifacts/windows/Poma-1.0.0.2017-session9/build-inventory.json",
        "compiledApplicationInputChanges": compiled_changes,
        "lockfileSha256": source["lockfileSha256"], "changedPreexistingInputs": changes,
        "unrelatedBaselineChanges": unexpected, "mobilePlatformInputsCompared": len(mobile),
        "mobilePlatformChanges": mobile_changes, "historicalArtifactsUnchanged": historical,
        "packagePath": package.relative_to(ROOT).as_posix(), "packageSha256": digest(package),
        "exeSha256": payload_hashes["poma.exe"], "aotSha256": payload_hashes["data/app.so"],
        "packageUnsigned": True, "packageIdentity": identity, "startupTask": startup[0],
        "checks": {"flutter": final_tests, "baselineFlutter": flutter_result("baseline-flutter-host.json"),
                   "windowsNative": 211, "calendarConfiguration": 11, "analysis": "clean",
                   "format": (EVIDENCE / "format-final.log").read_text(encoding="utf-8-sig").strip(),
                   "androidNativeTests": android_tests, "androidStatus": read_json(EVIDENCE / "android-status-final.json")},
        "androidApk": {"sha256": digest(apk), "bytes": apk.stat().st_size, "nativeLibs": native_libs,
                       "scope": "ARM64 debug compatibility only; no device install"},
        "privacyInspection": {"packageFiles": package_files, "uncompressedBytes": scanned_bytes,
                              "logFiles": len(log_files), "credentialPatternFindings": findings,
                              "appOwnedLoggingCallPaths": logging_calls, "markersTested": len(markers),
                              "scope": "all uncompressed production package members, selected logs and calendar/native logging source; no personal event capture; bounded patterns only"},
        "resources": resources, "counterDeltas": counter_deltas,
        "runtimeSummary": runtime_summary, "runtimeObservations": runtime,
        "runtimeLimitations": ["Review build precedes the reset-error wording repair and two helper style fixes; separate identity retained.",
                               "Android compilation, Flutter tests and analysis overlapped parts of this host campaign; comparisons are descriptive, not causal performance guarantees.",
                               "Synthetic transport and instrumented counters do not establish live network, OS disk/frame traces or toast delivery."],
        "unrun": ["live Google consent/revocation/Testing expiry/event comparison/account replacement",
                  "trusted installation/clean user/upgrade", "physical Explorer/tray/monitors/scales/Narrator/high contrast/lock",
                  "startup enabled/disabled at actual sign-in", "installed toast/DND/denial/actions",
                  "physical sleep/hibernate", "iOS/Xcode and physical Android/iPhone"],
        "distribution": "unsigned local verification only; no signing, installation, trust or publication",
    }
    (EVIDENCE / "review.json").write_text(json.dumps(review, indent=2) + "\n", encoding="utf-8")
    print(f"Bound {final_tests['tests']} Flutter tests, {len(source['files'])} source inputs and {len(samples)} resource samples.")
    print(f"Production package SHA-256: {review['packageSha256']}")


if __name__ == "__main__":
    main()
