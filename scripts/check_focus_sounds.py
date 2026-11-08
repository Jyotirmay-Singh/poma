"""Run Session 1 checks with retained logs, using the existing RTK/toolchains."""
import json
import os
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
RTK = ROOT / ".tools/rtk/rtk.exe"
EVIDENCE = ROOT / "artifacts/focus-sounds/session-1/checks"
FLUTTER = [str(RTK), "proxy", "powershell", "-NoProfile", "-ExecutionPolicy", "Bypass",
           "-File", str(ROOT / "scripts/flutter.ps1")]
COMMANDS = {
    "analyze": FLUTTER + ["analyze", "--no-pub"],
    "tests": FLUTTER + ["test", "--no-pub"],
    "windows-build": FLUTTER + ["build", "windows", "--release"],
    "android-build": FLUTTER + ["build", "apk", "--debug", "--target-platform", "android-arm64"],
    "windows-native": [str(RTK), "proxy", "powershell", "-NoProfile", "-ExecutionPolicy", "Bypass",
                       "-File", str(ROOT / "scripts/test_windows_native.ps1")],
    "android-native": [str(RTK), "proxy", "powershell", "-NoProfile", "-Command",
                       "& 'D:/pomodoro/mobile/android/gradlew.bat' :app:testDebugUnitTest --console=plain"],
}


def main():
    EVIDENCE.mkdir(parents=True, exist_ok=True)
    environment = os.environ.copy()
    environment.update(JAVA_HOME="D:/Android/jdk/jdk-17.0.19+10", ANDROID_HOME="D:/Android/sdk",
                       ANDROID_SDK_ROOT="D:/Android/sdk", FLUTTER_ROOT="D:/SDKs/flutter",
                       TEMP=str(ROOT / ".tools/tmp"), TMP=str(ROOT / ".tools/tmp"))
    environment["PATH"] = environment["JAVA_HOME"] + "/bin;" + environment["PATH"]
    failures = 0
    for name in sys.argv[1:]:
        command = COMMANDS[name]
        log = EVIDENCE / (name + ".log")
        print("Starting " + name, flush=True)
        start = time.monotonic()
        with log.open("w", encoding="utf-8") as output:
            result = subprocess.run(command, cwd=ROOT / "mobile/android" if name == "android-native" else ROOT,
                                    env=environment, stdout=output, stderr=subprocess.STDOUT, timeout=900)
        elapsed = time.monotonic() - start
        record = {"check": name, "exit_code": result.returncode, "elapsed_seconds": elapsed,
                  "command": command, "log": log.relative_to(ROOT).as_posix()}
        (EVIDENCE / (name + ".json")).write_text(json.dumps(record, indent=2) + "\n")
        print(f"{name}: exit {result.returncode}, {elapsed:.1f}s", flush=True)
        if result.returncode:
            failures += 1
            print(log.read_text(encoding="utf-8", errors="replace")[-4000:], flush=True)
    sys.exit(1 if failures else 0)


if __name__ == "__main__":
    main()
