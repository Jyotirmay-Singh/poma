"""Refuse test-evidence reuse if the previously tested core or lockfile changed."""

import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BASELINE = "2613cbcb552095c5a37573729d2086def3ed81a8"
ALLOWED = {
    "mobile/lib/ui/settings_screen.dart",
    "mobile/lib/ui/legal_screen.dart",
    "mobile/lib/release_metadata.dart",
    "mobile/lib/main.dart",  # Reviewed addition: offline native-license registration only.
}


def git(*args):
    # Git is read-only here; the CI host need not install a command-output filter.
    wrapper = ROOT / ".tools/rtk/rtk.exe"
    prefix = [str(wrapper), "proxy"] if wrapper.is_file() else []
    return subprocess.check_output([*prefix, "git", *args], cwd=ROOT)


def main():
    paths = git("ls-tree", "-r", "--name-only", BASELINE, "--", "mobile/lib",
                "mobile/android/app/src/main/kotlin", "mobile/ios/Runner", "mobile/pubspec.lock").decode().splitlines()
    mismatches = []
    checked = 0
    # Verify that the reviewed entry-point change is only license registration.
    main_path = "mobile/lib/main.dart"
    license_addition = (
        "    yield LicenseEntryWithLineBreaks([\n"
        "      'Android native runtime dependencies',\n"
        "    ], await rootBundle.loadString('assets/licenses/android-native.txt'));\n"
    )
    main_text = (ROOT / main_path).read_text(encoding="utf-8")
    old_main = git("show", BASELINE + ":" + main_path).decode().replace("\r\n", "\n")
    if main_text.count(license_addition) != 1 or main_text.replace(license_addition, "") != old_main:
        mismatches.append(main_path + " (outside license registration)")
    checked += 1
    # Version/assets are reviewed release changes; the package graph must not change.
    manifest = (ROOT / "mobile/pubspec.yaml").read_text(encoding="utf-8")
    for asset in ("licenses/android-native.txt", "legal/privacy.txt", "legal/notices.txt"):
        manifest = manifest.replace(f"    - assets/{asset}\n", "")
    import re
    manifest = re.sub(r"^version: .*", "version: BASELINE", manifest, flags=re.M)
    old_manifest = git("show", BASELINE + ":mobile/pubspec.yaml").decode().replace("\r\n", "\n")
    old_manifest = re.sub(r"^version: .*", "version: BASELINE", old_manifest, flags=re.M)
    if manifest != old_manifest:
        mismatches.append("mobile/pubspec.yaml (outside version/legal assets)")
    checked += 1
    for name in paths:
        if name in ALLOWED or not (
            name.startswith("mobile/lib/") or name.endswith((".kt", ".swift")) or name.endswith("pubspec.lock")
        ):
            continue
        checked += 1
        current = ROOT / name
        old = git("show", BASELINE + ":" + name).replace(b"\r\n", b"\n")
        if not current.is_file() or current.read_bytes().replace(b"\r\n", b"\n") != old:
            mismatches.append(name)
    # New production files outside the reviewed About/legal boundary also require review.
    old_paths = set(paths)
    for pattern in ("mobile/lib/**/*.dart", "mobile/android/app/src/main/kotlin/**/*.kt", "mobile/ios/Runner/*.swift"):
        for path in ROOT.glob(pattern):
            name = path.relative_to(ROOT).as_posix()
            if name not in old_paths and name not in ALLOWED:
                mismatches.append(name)
    if mismatches:
        raise SystemExit("Core changed: record affected ledger IDs and run their regression checks: " + ", ".join(mismatches))
    print(f"Baseline {BASELINE}: {checked} core/lockfile inputs unchanged; reuse 183 named results. About/legal/build changes require focused checks.")


if __name__ == "__main__":
    main()
