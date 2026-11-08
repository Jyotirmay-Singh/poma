"""Build matched library/assets variants from identical final spike sources."""
import subprocess
from pathlib import Path

spike = Path(__file__).resolve().parent
root = spike.parents[1]
rtk = root / ".tools/rtk/rtk.exe"
manifest = spike / "pubspec.yaml"
original = manifest.read_text()
log_path = root / "artifacts/focus-sounds/session-1/footprint-build.log"


def build(variant, log):
    command = [rtk, "proxy", "powershell", "-NoProfile", "-ExecutionPolicy", "Bypass",
               "-File", spike / "run_flutter.ps1", "build", "windows", "--release", "--no-pub"]
    subprocess.run(command, cwd=root, stdout=log, stderr=subprocess.STDOUT, check=True, timeout=600)
    subprocess.run([rtk, "proxy", "python", spike / "record_bundle.py", variant], cwd=root, check=True)


try:
    with log_path.open("w") as log:
        try:
            assert "  assets:\n" in original
            manifest.write_text(original.split("  assets:\n")[0])
            build("library", log)
        finally:
            manifest.write_text(original)
        build("assets", log)
finally:
    manifest.write_text(original)
