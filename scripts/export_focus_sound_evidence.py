"""Export compact reviewable results; retain full logs/binaries in ignored artifacts."""
import hashlib
import json
import statistics
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
EVIDENCE = ROOT / "artifacts/focus-sounds/session-1"
OUTPUT = ROOT / "docs/focus-sounds"
RTK = ROOT / ".tools/rtk/rtk.exe"


def read(path):
    return json.loads(path.read_text(encoding="utf-8"))


def main():
    checks = [read(p) for p in sorted((EVIDENCE / "checks").glob("*.json"))]
    assert len(checks) == 6 and all(c["exit_code"] == 0 for c in checks)
    playback = read(EVIDENCE / "assets-playback.json")
    assert playback["passed"] and len(playback["checks"]) == 88
    bundles = EVIDENCE / "bundles"
    assert (bundles / "library-main.dart.txt").read_bytes() == (bundles / "assets-main.dart.txt").read_bytes()
    assert (bundles / "library-pubspec.lock.txt").read_bytes() == (bundles / "assets-pubspec.lock.txt").read_bytes()
    sizes = {variant: read(bundles / (variant + "-inventory.json"))["runtime_bytes_excluding_pdb"]
             for variant in ("baseline", "library", "assets")}
    samples = read(EVIDENCE / "assets-resources.json")["samples"]
    resources = {"scope": "One Windows x64 release experiment; fixed 250ms observations, not a battery or steady-state performance guarantee",
                 "sample_count": len(samples), "peak_working_set_bytes": max(s["working_set_bytes"] for s in samples),
                 "peak_private_bytes": max(s["private_bytes"] for s in samples)}
    for label, lo, hi in [("pre_initialization_idle", 1, 4.5), ("playing_with_forced_seeks", 6, 16)]:
        section = [s for s in samples if lo <= s["elapsed_seconds"] <= hi]
        resources[label] = {"sample_count": len(section),
                            "median_working_set_bytes": statistics.median(s["working_set_bytes"] for s in section),
                            "median_private_bytes": statistics.median(s["private_bytes"] for s in section),
                            "one_core_cpu_percent": 100 * (section[-1]["cpu_seconds"] - section[0]["cpu_seconds"]) / (section[-1]["elapsed_seconds"] - section[0]["elapsed_seconds"])}
    verification = {
        "date": "2026-11-08", "timezone": "Asia/Kolkata", "scope": "Session 1; production integration not implemented",
        "base_HEAD": "0a001d2b37e80c316449898de7419e50e18d1547", "branch": "codex/focus-soundscapes", "committed": False,
        "sdk": {"flutter": "3.44.2", "dart": "3.12.2", "java": "17.0.19+10"},
        "selected_backend": "flutter_soloud 4.1.7; Windows runtime qualified, mobile runtime pending",
        "rejected_version": {"version": "5.2.3", "reason": "native_toolchain_c >=0.19.3 requires meta ^1.19.0; Flutter 3.44.2 pins meta 1.18.0. No override/SDK upgrade used."},
        "playback": playback, "checks": checks, "flutter_tests": 472, "experiment_lease_tests": 3,
        "asset_verification": read(EVIDENCE / "asset-verification.json"),
        "experiment_footprint": {"runtime_bytes": sizes, "same_final_probe_code_and_lock_for_library_vs_assets": True,
                                 "library_and_probe_overhead_bytes": sizes["library"] - sizes["baseline"],
                                 "asset_bundle_increment_bytes": sizes["assets"] - sizes["library"],
                                 "limitation": "Unpackaged Windows release experiment, not Poma MSIX/store/download size"},
        "resource_observations": resources,
        "open_gates": ["Human equal-perceived-loudness comparison, ten-minute trials and natural joins on headphones/speakers",
                       "Production coordinator/preferences/timer integration (Session 2)", "Production adaptive UI and rendered/assistive review (Session 3)",
                       "Android/iOS background expiry, audio focus, route changes and physical-device acceptance (Session 4)",
                       "macOS/iOS compilation and native tests; Windows sleep/wake observation; release/store size and battery qualification"],
        "failures_and_resolutions": [
            "Initial 5.2.3 resolution failed; selected SDK-compatible 4.1.7 after real qualification.",
            "Initial bell filter produced an unbounded intermediate and exhausted free workspace space; only that resolved task-created file was removed. Replaced with finite sample counts, duration/size caps and timeout; originals/profiles untouched.",
            "Public download workflow initially returned HTML; followed its ordinary second form and wait. Four-digit IDs corrected; no preview masters used.",
            "Plugin junction setup required existing SDK/cache access; reran locked pub get successfully without enabling Developer Mode. Empty native registrants were detected before playback qualification and regenerated.",
            "First spike clock lookup targeted kernel32 instead of kernelbase; failed child was bounded/killed after 90 seconds. Corrected lookup, moved setup under error reporting, and qualified successfully. Failure log retained.",
            "One analyzer style finding corrected; final analysis clean.",
            "A packaging preflight correctly rejected the old APK while the new build was still running; current fresh Windows/Android payload verification passed."],
        "full_evidence_root": "artifacts/focus-sounds/session-1/"
    }
    (OUTPUT / "VERIFICATION.json").write_text(json.dumps(verification, indent=2) + "\n", encoding="utf-8")
    tracked = subprocess.run([RTK, "proxy", "git", "diff", "--name-only"], cwd=ROOT, capture_output=True, text=True, check=True).stdout.splitlines()
    untracked = subprocess.run([RTK, "proxy", "git", "ls-files", "--others", "--exclude-standard"], cwd=ROOT, capture_output=True, text=True, check=True).stdout.splitlines()
    names = sorted(set(tracked + untracked) - {"docs/focus-sounds/SOURCE_MANIFEST.json"})
    assert len(names) < 200
    source = []
    for name in names:
        path = ROOT / name
        if path.is_file():
            with path.open("rb") as stream:
                checksum = hashlib.file_digest(stream, "sha256").hexdigest()
            source.append({"path": name, "bytes": path.stat().st_size, "sha256": checksum})
    (OUTPUT / "SOURCE_MANIFEST.json").write_text(json.dumps({"base_HEAD": verification["base_HEAD"], "uncommitted": True, "files": source}, indent=2) + "\n")
    print(json.dumps({"checks": len(checks), "playback_checks": 88, "source_files_hashed": len(source), "sizes": sizes}))


if __name__ == "__main__":
    main()
