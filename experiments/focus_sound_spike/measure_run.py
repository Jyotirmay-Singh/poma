"""Run only this experiment and sample its own process; never inspect Poma data."""
import ctypes as c
import json
import subprocess
import sys
import time
from pathlib import Path
from ctypes import wintypes as w


class Memory(c.Structure):
    _fields_ = [("cb", w.DWORD), ("PageFaultCount", w.DWORD)] + [(n, c.c_size_t) for n in
        ("PeakWorkingSetSize", "WorkingSetSize", "QuotaPeakPagedPoolUsage", "QuotaPagedPoolUsage",
         "QuotaPeakNonPagedPoolUsage", "QuotaNonPagedPoolUsage", "PagefileUsage", "PeakPagefileUsage", "PrivateUsage")]


def main():
    variant = sys.argv[1]
    assert variant in ("baseline", "assets")
    root = Path(__file__).resolve().parents[2]
    evidence = root / "artifacts/focus-sounds/session-1"
    bundle = evidence / "bundles" / variant
    executable = bundle / "focus_sound_spike.exe"
    report = evidence / (variant + "-playback.json")
    log = evidence / (variant + "-runtime.log")
    samples = []
    failure = None
    flag = "--baseline" if variant == "baseline" else "--self-test"
    with log.open("w") as output:
        child = subprocess.Popen([str(executable), flag, "--report=" + str(report)],
                                 cwd=bundle, stdout=output, stderr=subprocess.STDOUT)
        handle = w.HANDLE(int(child._handle))
        started = time.monotonic()
        try:
            while child.poll() is None:
                elapsed = time.monotonic() - started
                if elapsed > 90:
                    raise TimeoutError("Experiment exceeded 90 seconds")
                memory = Memory()
                memory.cb = c.sizeof(memory)
                creation, end, kernel, user = (w.FILETIME() for _ in range(4))
                if c.windll.psapi.GetProcessMemoryInfo(handle, c.byref(memory), memory.cb) and c.windll.kernel32.GetProcessTimes(handle, c.byref(creation), c.byref(end), c.byref(kernel), c.byref(user)):
                    cpu = ((kernel.dwHighDateTime << 32) + kernel.dwLowDateTime +
                           (user.dwHighDateTime << 32) + user.dwLowDateTime) / 10_000_000
                    samples.append({"elapsed_seconds": elapsed, "cpu_seconds": cpu,
                                    "working_set_bytes": memory.WorkingSetSize,
                                    "private_bytes": memory.PrivateUsage})
                time.sleep(.25)
        except Exception as error:
            child.kill()  # Only the child created above, never a named/system process.
            child.wait()
            failure = str(error)
    result = {"variant": variant, "process_exit_code": child.returncode, "failure": failure, "sample_interval_seconds": .25,
              "scope": "Single isolated unpackaged Windows release run; not a battery/performance guarantee",
              "samples": samples}
    (evidence / (variant + "-resources.json")).write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps({"exit_code": child.returncode, "report": str(report), "resource_samples": len(samples)}))
    if report.exists():
        data = json.loads(report.read_text())
        print(json.dumps({"passed": data.get("passed"), "error": data.get("error"), "checks": len(data.get("checks", []))}))
    sys.exit(child.returncode)


if __name__ == "__main__":
    main()
