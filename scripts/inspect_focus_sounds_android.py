"""Scoped, opt-in ADB evidence helper for the separately installed review app.

Never targets the production package or clears device/application data.
"""

import argparse
import datetime as dt
import hashlib
import json
from pathlib import Path
import re
import subprocess
import time
import xml.etree.ElementTree as ET

ADB = r"D:\Android\sdk\platform-tools\adb.exe"
SERIAL = "ZD222FJN34"
PACKAGE = "com.jyotirmaysingh.poma.focussoundsreview"
ROOT = Path(r"D:\pomodoro\artifacts\focus-sounds\session-4\android-device-20261109")


def adb(*args, binary=False, allow_empty=False):
    result = subprocess.run(
        [ADB, "-s", SERIAL, *args], capture_output=True, timeout=35,
    )
    # Android pidof returns 1 with no output when a deliberately stopped app
    # has no process. Preserve other command failures as evidence.
    empty_process = allow_empty and result.returncode == 1 and not result.stdout and not result.stderr
    if result.returncode and not empty_process:
        raise RuntimeError(result.stderr.decode(errors="replace"))
    return result.stdout if binary else result.stdout.decode(errors="replace")


def stamp():
    return {"utc": dt.datetime.now(dt.timezone.utc).isoformat(), "host_monotonic": time.monotonic()}


def save(label, suffix, data):
    ROOT.mkdir(parents=True, exist_ok=True)
    target = ROOT / f"{label}.{suffix}"
    if isinstance(data, bytes):
        target.write_bytes(data)
    else:
        target.write_text(data, encoding="utf-8")
    return str(target)


def ui(label, screen=False, quiet=False):
    adb("shell", "uiautomator", "dump", "/data/local/tmp/poma-review-ui.xml")
    xml = adb("shell", "cat", "/data/local/tmp/poma-review-ui.xml")
    tree = ET.fromstring(xml)
    packages = {n.get("package") for n in tree.iter("node") if n.get("package")}
    review_permission_dialog = "Poma Sounds Review" in xml and any(p.endswith("permissioncontroller") for p in packages)
    review_settings = "Poma Sounds Review" in xml and "com.android.settings" in packages
    if PACKAGE not in packages and not review_permission_dialog and not review_settings:
        print(json.dumps({"review_visible": False, "note": "Review app is not exposed in the UI; no capture retained."}))
        return None
    save(label, "xml", xml)
    items = []
    for node in tree.iter("node"):
        text = node.get("text") or node.get("content-desc")
        if text:
            items.append({k: v for k, v in {
                "label": text, "bounds": node.get("bounds"),
                "clickable": node.get("clickable"), "enabled": node.get("enabled"),
                "package": node.get("package"), "class": node.get("class"),
            }.items()})
    record = {**stamp(), "ui": items}
    save(label, "json", json.dumps(record, indent=2))
    if screen:
        record["screenshot"] = save(label, "png", adb("exec-out", "screencap", "-p", binary=True))
    if not quiet:
        print(json.dumps(record, ensure_ascii=False))
    return tree


def tap(label, target, contains=False, index=0, class_name=None):
    tree = ui(label + "-before", quiet=True)
    if tree is None:
        raise RuntimeError("Review app is not visible")
    matches = []
    for node in tree.iter("node"):
        text = node.get("text") or node.get("content-desc") or ""
        if (target in text if contains else target == text) and node.get("enabled") == "true" and (class_name is None or node.get("class") == class_name):
            matches.append(node)
    if index >= len(matches):
        raise RuntimeError(f"Target {target!r} not found (matches={len(matches)})")
    node = matches[index]
    values = [int(v) for v in re.findall(r"\d+", node.get("bounds", ""))]
    if len(values) != 4:
        raise RuntimeError("Missing bounds")
    x, y = (values[0] + values[2]) // 2, (values[1] + values[3]) // 2
    adb("shell", "input", "tap", str(x), str(y))
    save(label + "-action", "json", json.dumps({**stamp(), "action": "tap", "target": target, "matched": node.attrib, "x": x, "y": y}, indent=2))
    print(json.dumps({"action": "tap", "matched": node.get("text") or node.get("content-desc"), "x": x, "y": y, **stamp()}))
    return x, y


def brief_ui(label, screen=False):
    tree = ui(label, screen, quiet=True)
    if tree is not None:
        print(json.dumps({"label": label, "ui": [n.get("text") or n.get("content-desc") for n in tree.iter("node") if n.get("text") or n.get("content-desc")], **stamp()}))
    return tree


def repeat(label, target, count):
    if not 1 <= count <= 30:
        raise ValueError("Repeat limit is 30")
    x, y = tap(label, target)
    for _ in range(count - 1):
        adb("shell", "input", "tap", str(x), str(y))
        time.sleep(0.12)
    save(label + "-repeat", "json", json.dumps({**stamp(), "target": target, "count": count, "x": x, "y": y}, indent=2))
    print(json.dumps({"target": target, "count": count, **stamp()}))


def volume(label, percent):
    if not 0 <= percent <= 100:
        raise ValueError("Invalid volume")
    tree = ui(label + "-before", quiet=True)
    parent = next(n for n in tree.iter("node") if n.get("content-desc") == "Focus sounds volume")
    thumb = next(n for n in tree.iter("node") if n.get("class") == "android.widget.SeekBar")
    bounds = [int(v) for v in re.findall(r"\d+", parent.get("bounds"))]
    thumb_bounds = [int(v) for v in re.findall(r"\d+", thumb.get("bounds"))]
    x, y = (thumb_bounds[0] + thumb_bounds[2]) // 2, (thumb_bounds[1] + thumb_bounds[3]) // 2
    # Read the actual slider bounds; endpoints are reached inside its hit area.
    destination = bounds[0] + 2 if percent == 0 else bounds[2] - 2 if percent == 100 else (bounds[0] + bounds[2]) // 2
    if percent not in {0, 50, 100}:
        raise ValueError("This physical fixture supports endpoints and midpoint only")
    adb("shell", "input", "swipe", str(x), str(y), str(destination), str(y), "400")
    save(label + "-action", "json", json.dumps({**stamp(), "slider_bounds": bounds, "thumb_bounds": thumb_bounds, "requested_percent": percent, "destination": destination}, indent=2))
    print(json.dumps({"slider_requested": percent, **stamp()}))


def rapid_switch(label):
    tree = ui(label + "-before", quiet=True)
    controls = {}
    for n in tree.iter("node"):
        if n.get("class") == "android.widget.RadioButton" and n.get("enabled") == "true":
            name = (n.get("content-desc") or n.get("text") or "").split("\n")[0]
            values = [int(v) for v in re.findall(r"\d+", n.get("bounds", ""))]
            controls[name] = ((values[0] + values[2]) // 2, (values[1] + values[3]) // 2)
    actions = []
    for name in ["Tibetan bells", "Waterfall", "Off"]:
        x, y = controls[name]
        adb("shell", "input", "tap", str(x), str(y))
        actions.append({"name": name, "x": x, "y": y, **stamp()})
    save(label + "-action", "json", json.dumps(actions, indent=2))
    print(json.dumps({"rapid_switch": actions}))


def wait_playing(label, timeout=10, title=None):
    until = time.monotonic() + timeout
    attempt = 0
    while True:
        attempt += 1
        observed = state(f"{label}-{attempt}")
        title_current = title is None or f"description={title}, Poma," in observed["media_session"]
        if title_current and "state=PLAYING(3)" in observed["media_session"] and "isForeground=true" in observed["services"]:
            return observed
        if time.monotonic() >= until:
            raise RuntimeError("Review audio did not reach Playing within the loading window")
        time.sleep(0.3)


def scroll(label, direction):
    tree = ui(label + "-before", quiet=True)
    if tree is None:
        raise RuntimeError("Review app is not visible")
    nodes = [n for n in tree.iter("node") if n.get("scrollable") == "true"]
    if not nodes:
        raise RuntimeError("No scrollable control exposed")
    values = [int(v) for v in re.findall(r"\d+", nodes[0].get("bounds", ""))]
    x = (values[0] + values[2]) // 2
    top = values[1] + (values[3] - values[1]) // 4
    bottom = values[3] - (values[3] - values[1]) // 4
    start, end = (bottom, top) if direction == "down" else (top, bottom)
    adb("shell", "input", "swipe", str(x), str(start), str(x), str(end), "450")
    save(label + "-action", "json", json.dumps({**stamp(), "action": "scroll", "direction": direction, "bounds": nodes[0].get("bounds")}, indent=2))
    print(json.dumps({"scroll": direction, **stamp()}))


def state(label):
    services = adb("shell", "dumpsys", "activity", "services", PACKAGE)
    sessions = adb("shell", "dumpsys", "media_session")
    own = []
    active = False
    for line in sessions.splitlines():
        if "Media button session is" in line and PACKAGE in line:
            own.append(line)
        if re.match(r"^    \S.*\(userId=", line):
            active = PACKAGE in line
        elif active and line.strip() and len(line) - len(line.lstrip()) < 6:
            active = False
        if active:
            own.append(line)
    audio = adb("shell", "dumpsys", "audio")
    uid = adb("shell", "cmd", "package", "list", "packages", "-U", PACKAGE).strip().split("uid:")[-1]
    own_audio = [line for line in audio.splitlines() if PACKAGE in line or re.search(rf"\b{re.escape(uid)}\b", line)]
    result = {**stamp(), "services": services, "media_session": "\n".join(own), "audio_own_uid": "\n".join(own_audio)}
    save(label, "state.json", json.dumps(result, indent=2))
    match = re.search(r"state=PlaybackState \{state=([^,]+)", result["media_session"])
    print(json.dumps({**stamp(), "evidence": str(ROOT / f"{label}.state.json"), "service_active": "isForeground=true" in services, "media_state": match.group(1) if match else None, "focus_owned": "loss: none" in result["audio_own_uid"]}))
    return result


def identity(label, apk_path=None):
    apk = Path(apk_path or r"D:\pomodoro\artifacts\focus-sounds\session-4\builds\android-review-1794200768379284800\app-release.apk")
    result = {**stamp(), "package": PACKAGE, "apk": str(apk), "sha256": hashlib.sha256(apk.read_bytes()).hexdigest(), "bytes": apk.stat().st_size}
    for prop in ["ro.product.model", "ro.product.device", "ro.build.version.release", "ro.build.version.sdk", "ro.product.cpu.abi"]:
        result[prop] = adb("shell", "getprop", prop).strip()
    result["package_dump"] = adb("shell", "dumpsys", "package", PACKAGE)
    result["production_still_installed"] = adb("shell", "pm", "path", "dev.poma.poma").strip().startswith("package:")
    save(label, "identity.json", json.dumps(result, indent=2))
    print(json.dumps({k: v for k, v in result.items() if k != "package_dump"}))


def logs(label):
    pid = adb("shell", "pidof", PACKAGE).strip()
    if not pid:
        raise RuntimeError("Review process is not running")
    output = adb("logcat", "--pid=" + pid, "-d", "-v", "threadtime", "-t", "2000")
    save(label, "logcat.txt", output)
    errors = [line for line in output.splitlines() if re.search(r"FATAL EXCEPTION|Fatal signal|UnsatisfiedLinkError|SecurityException|ForegroundServiceStartNotAllowed|ANR in|AudioTrack.*error|Failed to", line, re.I)]
    print(json.dumps({"pid": pid, "lines": len(output.splitlines()), "potential_errors": errors}))


def media(label, action):
    if action not in {"play", "pause", "stop"}:
        raise ValueError("Unsupported media action")
    sessions = adb("shell", "dumpsys", "media_session")
    button = next((line for line in sessions.splitlines() if "Media button session is" in line), "")
    if PACKAGE not in button:
        raise RuntimeError("Review app is not the media-button target; action was not sent")
    adb("shell", "cmd", "media_session", "dispatch", action)
    save(label + "-action", "json", json.dumps({**stamp(), "media_dispatch": action, "checked_target": button}, indent=2))
    print(json.dumps({"media_dispatch": action, **stamp()}))


def resources(label):
    pid = adb("shell", "pidof", PACKAGE, allow_empty=True).strip()
    result = {**stamp(), "pid": pid}
    if pid:
        result["meminfo"] = adb("shell", "dumpsys", "meminfo", PACKAGE)
        result["process"] = adb("shell", "ps", "-p", pid, "-o", "PID,NAME,TIME,RSS,STAT")
        for service in ["media.aaudio", "media.audio_flinger"]:
            dump = adb("shell", "dumpsys", service)
            result[service] = "\n".join(line for line in dump.splitlines() if re.search(rf"\b{pid}\b|\b10530\b", line))
    power = adb("shell", "dumpsys", "power")
    result["power"] = "\n".join(line for line in power.splitlines() if "mWakefulness=" in line or "poma" in line.lower())
    save(label, "resources.json", json.dumps(result, indent=2))
    current_power = [line for line in result["power"].splitlines() if "mWakefulness=" in line or "PARTIAL_WAKE_LOCK" in line]
    active_tracks = [line for line in result.get("media.audio_flinger", "").splitlines() if not re.match(r"\s*\d\d-\d\d ", line)]
    print(json.dumps({"label": label, "pid": pid, "process": result.get("process"), "power_current": current_power, "active_flinger_own": active_tracks, **stamp()}))


def locked_deadline(label):
    tap(label + "-start", "Start focus")
    started = time.monotonic()
    state(label + "-initial")
    brief_ui(label + "-running", True)
    adb("shell", "input", "keyevent", "KEYCODE_SLEEP")
    save(label + "-lock", "json", json.dumps({**stamp(), "key": "KEYCODE_SLEEP", "start_action_host_monotonic": started, "duration_seconds": 60}, indent=2))
    for elapsed in [10, 30, 55, 59, 61, 64, 69]:
        time.sleep(max(0, started + elapsed - time.monotonic()))
        state(f"{label}-locked-{elapsed}s")
        if elapsed in [10, 30, 64]:
            resources(f"{label}-locked-{elapsed}s")
    adb("shell", "input", "keyevent", "KEYCODE_WAKEUP")
    save(label + "-wakeup", "json", json.dumps(stamp(), indent=2))
    print(json.dumps({"locked_deadline_complete": True, "note": "Woke screen; did not dismiss security or reopen app", **stamp()}))


def notifications(label):
    dump = adb("shell", "dumpsys", "notification")
    headers = [line.strip() for line in dump.splitlines() if "NotificationRecord(" in line and f"pkg={PACKAGE}" in line]
    result = {**stamp(), "own_record_headers": headers, "ids": [int(m.group(1)) for line in headers if (m := re.search(r"\bid=(-?\d+)", line))]}
    save(label, "notifications.json", json.dumps(result, indent=2))
    print(json.dumps(result))


def background_deadline(label, title):
    tap(label + "-start", "Start focus")
    started = time.monotonic()
    wait_playing(label + "-playing", title=title)
    brief_ui(label + "-running", True)
    notifications(label + "-media-notification")
    tap(label + "-tasks", "Tasks")
    wait_playing(label + "-navigation-playing", title=title)
    adb("shell", "input", "keyevent", "KEYCODE_HOME")
    save(label + "-home", "json", json.dumps({**stamp(), "start_action_host_monotonic": started, "duration_seconds": 60}, indent=2))
    for elapsed in [15, 30, 55, 61, 66]:
        time.sleep(max(0, started + elapsed - time.monotonic()))
        state(f"{label}-home-{elapsed}s")
        if elapsed in [30, 66]:
            resources(f"{label}-home-{elapsed}s")
            notifications(f"{label}-home-{elapsed}s")
    print(adb("shell", "am", "start", "-W", "-n", PACKAGE + "/dev.poma.poma.MainActivity"))
    tap(label + "-return-focus", "Focus")
    brief_ui(label + "-complete", True)
    tap(label + "-insights", "Insights")
    brief_ui(label + "-history", True)


def silent_background_deadline(label):
    tap(label + "-start", "Start focus")
    started = time.monotonic()
    state(label + "-initial-silent")
    brief_ui(label + "-running", True)
    adb("shell", "input", "keyevent", "KEYCODE_HOME")
    save(label + "-home", "json", json.dumps({**stamp(), "start_action_host_monotonic": started, "duration_seconds": 60}, indent=2))
    for elapsed in [55, 61, 66]:
        time.sleep(max(0, started + elapsed - time.monotonic()))
        notifications(f"{label}-home-{elapsed}s")
    print(adb("shell", "am", "start", "-W", "-n", PACKAGE + "/dev.poma.poma.MainActivity"))
    brief_ui(label + "-complete", True)


def main():
    p = argparse.ArgumentParser()
    p.add_argument("action", choices=["ui", "tap", "state", "key", "scroll", "preview", "identity", "logs"])
    p.add_argument("label")
    p.add_argument("target", nargs="?")
    p.add_argument("--contains", action="store_true")
    p.add_argument("--screen", action="store_true")
    p.add_argument("--index", type=int, default=0)
    a = p.parse_args()
    if not re.fullmatch(r"[a-zA-Z0-9_-]+", a.label):
        p.error("Label must be a simple filename")
    if a.action == "ui":
        ui(a.label, a.screen)
    elif a.action == "tap":
        tap(a.label, a.target, a.contains, a.index)
    elif a.action == "state":
        state(a.label)
    elif a.action == "identity":
        identity(a.label)
    elif a.action == "logs":
        logs(a.label)
    elif a.action == "scroll":
        if a.target not in {"up", "down"}:
            p.error("Scroll direction must be up or down")
        scroll(a.label, a.target)
    elif a.action == "preview":
        tap(a.label, f"Preview {a.target} for up to 10 seconds")
        time.sleep(0.6)
        state(a.label + "-playing")
        tree = ui(a.label + "-playing", True, quiet=True)
        print(json.dumps({"preview_ui": any(n.get("content-desc") == f"Previewing {a.target}" for n in tree.iter("node"))}))
        time.sleep(11)
        state(a.label + "-expired")
        tree = ui(a.label + "-expired", quiet=True)
        print(json.dumps({"preview_expired_ui": not any((n.get("content-desc") or "").startswith("Previewing") for n in tree.iter("node"))}))
    else:
        if a.target not in {"KEYCODE_HOME", "KEYCODE_BACK", "KEYCODE_SLEEP", "KEYCODE_WAKEUP", "KEYCODE_MEDIA_PAUSE", "KEYCODE_MEDIA_PLAY"}:
            p.error("Unsupported key")
        adb("shell", "input", "keyevent", a.target)
        save(a.label + "-action", "json", json.dumps({**stamp(), "key": a.target}, indent=2))


if __name__ == "__main__":
    main()
