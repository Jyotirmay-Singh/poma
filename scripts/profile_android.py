"""Collect explicit-device Android launch samples without claiming offline acceptance.

Use only with a synthetic Poma validation installation. Ordinary background
process killing is used for cold launches; force-stop is deliberately excluded.
Every external command is routed through RTK and raw Poma-only results are kept.
"""

import argparse
from datetime import datetime, timezone
import json
import math
from pathlib import Path
import re
import subprocess
import time


def percentile(values, p):
    return sorted(values)[max(0, math.ceil(len(values) * p / 100) - 1)] if values else None


class Device:
    def __init__(self, args):
        self.args = args

    def run(self, *parts, check=True):
        result = subprocess.run([self.args.rtk, "proxy", self.args.adb, "-s", self.args.serial, *parts], capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=90)
        if check and result.returncode:
            raise RuntimeError(f"adb {parts[0]} failed: {result.stderr.strip()}")
        return result.stdout + result.stderr

    def shell(self, *parts, check=True):
        return self.run("shell", *parts, check=check)

    def pid(self):
        return self.shell("pidof", self.args.package, check=False).strip()

    def environment(self):
        properties = {}
        for name in ("ro.product.manufacturer", "ro.product.model", "ro.product.device", "ro.product.cpu.abilist", "ro.build.version.release", "ro.build.version.sdk", "ro.build.version.security_patch", "ro.build.fingerprint", "ro.kernel.qemu"):
            properties[name] = self.shell("getprop", name).strip()
        settings = {}
        for namespace, name in (("system", "screen_brightness"), ("system", "screen_brightness_mode"), ("system", "peak_refresh_rate"), ("system", "min_refresh_rate"), ("global", "airplane_mode_on"), ("global", "wifi_on"), ("global", "mobile_data"), ("global", "low_power")):
            settings[f"{namespace}/{name}"] = self.shell("settings", "get", namespace, name).strip()
        return {"properties": properties, "settings": settings, "battery": self.shell("dumpsys", "battery"), "thermal": self.shell("dumpsys", "thermalservice"), "displaySize": self.shell("wm", "size"), "displayDensity": self.shell("wm", "density"), "adbVersion": subprocess.check_output([self.args.rtk, "proxy", self.args.adb, "version"], text=True)}

    def launch(self, kind, ordinal):
        self.shell("input", "keyevent", "KEYCODE_HOME")
        time.sleep(0.6)
        previous_pid = self.pid()
        if kind == "cold":
            self.shell("am", "kill", self.args.package)
            for attempt in range(20):
                if not self.pid():
                    break
                time.sleep(0.25)
                if attempt == 5:
                    self.shell("am", "kill", self.args.package)
            if self.pid():
                return {"ordinal": ordinal, "kind": kind, "valid": False, "reason": "Ordinary background kill did not terminate the process; no force-stop substituted"}
        elif not previous_pid:
            return {"ordinal": ordinal, "kind": kind, "valid": False, "reason": "Warm sample had no retained process"}
        device_time = self.shell("date", "+%s.%N").strip()
        try:
            start_epoch = float(device_time)
        except ValueError:
            start_epoch = None
        start = time.monotonic()
        command = ["am", "start", "-W"]
        if kind == "warm":
            # NEW_TASK | CLEAR_TASK; numeric Intent flags are supported by am.
            command += ["-f", "0x10008000"]
        command += ["-n", self.args.package + "/.MainActivity"]
        output = self.shell(*command)
        roundtrip = (time.monotonic() - start) * 1000
        time.sleep(0.6)
        current_pid = self.pid()
        fields = dict(re.findall(r"^([A-Za-z]+):\s*(.+)$", output, re.MULTILINE))
        logs = self.shell("logcat", "-d", "-b", "all", "-v", "epoch", "-t", "2000", "ActivityTaskManager:I", "wm_activity_fully_drawn_time:I", "am_activity_fully_drawn_time:I", "*:S", check=False)
        drawn = []
        for line in logs.splitlines():
            timestamp = re.match(r"\s*(\d+\.\d+)", line)
            if self.args.package in line and "Fully drawn" in line and timestamp and start_epoch is not None and float(timestamp[1]) >= start_epoch:
                drawn.append(line)
        fully_drawn_ms = None
        if len(drawn) == 1:
            duration = re.search(r":\s*\+(?:(\d+)s)?(\d+)ms", drawn[0])
            if duration:
                fully_drawn_ms = int(duration[1] or 0) * 1000 + int(duration[2])
        valid = fields.get("Status", "").strip() == "ok" and bool(current_pid)
        if kind == "warm" and current_pid != previous_pid:
            valid = False
        return {"ordinal": ordinal, "kind": kind, "valid": valid, "previousPid": previous_pid, "pid": current_pid, "fields": fields, "rawLaunch": output, "hostRoundtripMs": roundtrip, "deviceStartEpoch": start_epoch, "fullyDrawnLines": drawn, "fullyDrawnMs": fully_drawn_ms, "fullyDrawnLimitation": "Only a unique package-matching platform marker after the device start timestamp is used; missing/ambiguous markers remain unmeasured"}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--adb", required=True)
    parser.add_argument("--rtk", default="rtk")
    parser.add_argument("--serial", required=True)
    parser.add_argument("--package", default="dev.poma.poma")
    parser.add_argument("--fixture", required=True, choices=("empty", "100000"))
    parser.add_argument("--samples", type=int, default=30)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--environment-only", action="store_true")
    parser.add_argument("--usable-frame-marker", action="store_true", help="Only for APKs whose Flutter first-frame callback is replaced by Poma's restored-UI marker")
    args = parser.parse_args()
    if args.samples < 1:
        parser.error("samples must be positive")
    device = Device(args)
    if args.output.exists():
        parser.error("output already exists; preserve prior evidence and choose a new path")
    result = {"recordedUtc": datetime.now(timezone.utc).isoformat(), "collector": "profile_android.py/2", "fixture": args.fixture, "serial": args.serial, "package": args.package, "usableFrameMarkerDeclared": args.usable_frame_marker, "environment": device.environment(), "samples": [], "limitations": ["Developer-attached release measurements; not disconnected acceptance.", "Warm requests clear/recreate the activity while retaining the process; Android LaunchState remains authoritative.", "TotalTime is initial display latency, not a usable timer measurement.", "Only explicitly declared, source-verified restored-UI markers can establish usable timer latency.", "No battery saving or energy claim can be derived from USB-powered launch runs."]}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    def save():
        args.output.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    save()
    if not args.environment_only:
        for kind in ("cold", "warm"):
            for index in range(args.samples):
                sample = device.launch(kind, index + 1)
                result["samples"].append(sample)
                save()
                print(json.dumps({"kind": kind, "sample": index + 1, "valid": sample["valid"], "fields": sample.get("fields")}), flush=True)
        result["summary"] = {}
        for kind in ("cold", "warm"):
            samples = [sample for sample in result["samples"] if sample["kind"] == kind and sample["valid"]]
            values = [int(sample["fields"]["TotalTime"]) for sample in samples if sample.get("fields", {}).get("TotalTime", "").strip().isdigit()]
            usable = [sample["fullyDrawnMs"] for sample in samples if sample.get("fullyDrawnMs") is not None] if args.usable_frame_marker else []
            result["summary"][kind] = {"validSamples": len(samples), "totalTimeSamples": len(values), "initialDisplayMedianMs": percentile(values, 50), "initialDisplayP95Ms": percentile(values, 95), "usableTimerSamples": len(usable), "usableTimerMedianMs": percentile(usable, 50), "usableTimerP95Ms": percentile(usable, 95), "launchStates": [sample.get("fields", {}).get("LaunchState") for sample in samples]}
        save()
    print(json.dumps({"output": str(args.output), "summary": result.get("summary")}), flush=True)


if __name__ == "__main__":
    main()
