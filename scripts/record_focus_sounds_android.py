"""Record the observed, deliberately limited 2026-11-09 Android device run."""

import hashlib
import json
from pathlib import Path
import re
import subprocess
import xml.etree.ElementTree as ET

from inspect_focus_sounds_android import ROOT, stamp

REPO = Path(__file__).resolve().parents[1]
OUTPUT = REPO / "docs/focus-sounds/SESSION_4_ANDROID_DEVICE_VERIFICATION.json"
SOURCE_OUTPUT = REPO / "docs/focus-sounds/SESSION_4_ANDROID_SOURCE_MANIFEST.json"
RTK = REPO / ".tools/rtk/rtk.exe"


def read(name):
    return json.loads((ROOT / name).read_text(encoding="utf-8"))


def playing(name):
    value = read(name + ".state.json")
    return (
        "isForeground=true" in value["services"]
        and "state=PLAYING(3)" in value["media_session"]
        and "loss: none" in value["audio_own_uid"]
    )


def stopped(name):
    value = read(name + ".state.json")
    return (
        "isForeground=true" not in value["services"]
        and "state=PLAYING(3)" not in value["media_session"]
        and "loss: none" not in value["audio_own_uid"]
    )


def labels(name):
    return [item["label"] for item in read(name + ".json")["ui"]]


def attribute(name, target, key):
    tree = ET.fromstring((ROOT / (name + ".xml")).read_text(encoding="utf-8"))
    return next(
        node.get(key) for node in tree.iter("node")
        if (node.get("text") or node.get("content-desc") or "").startswith(target)
    )


def alarm_checked(name):
    tree = ET.fromstring((ROOT / (name + ".xml")).read_text(encoding="utf-8"))
    return next(node.get("checked") for node in tree.iter("node") if node.get("checkable") == "true")


def notification_ids(name):
    return read(name + ".notifications.json")["ids"]


def history_total(name):
    text = next(text for text in labels(name) if "Today:" in text)
    match = re.search(r"Today: (\d+) sessions?, (\d+) minutes focused", text)
    return tuple(int(part) for part in match.groups()) if match else (0, 0)


def source_and_checks():
    original = json.loads((REPO / "docs/focus-sounds/SESSION_4_SOURCE_MANIFEST.json").read_text(encoding="utf-8"))
    mobile = [entry for entry in original["files"] if entry["path"].startswith("mobile/")]
    changed = [entry["path"] for entry in mobile if hashlib.sha256((REPO / entry["path"]).read_bytes()).hexdigest() != entry["sha256"]]
    expected = {
        "mobile/lib/application/focus_audio_coordinator.dart",
        "mobile/test/focus_audio_mobile_test.dart",
        "mobile/test/focus_audio_support.dart",
    }
    if set(changed) != expected:
        raise RuntimeError("Unexpected application source changes since initial APK: " + repr(changed))
    paths = {entry["path"] for entry in original["files"] if not entry["path"].startswith("docs/")}
    paths.update(["scripts/inspect_focus_sounds_android.py", "scripts/record_focus_sounds_android.py"])
    branch = subprocess.check_output([str(RTK), "proxy", "git", "branch", "--show-current"], cwd=REPO, text=True).strip()
    head = subprocess.check_output([str(RTK), "proxy", "git", "rev-parse", "HEAD"], cwd=REPO, text=True).strip()
    source = {
        **stamp(), "branch": branch, "HEAD": head,
        "state": "Uncommitted Android alert-race correction; earlier Sessions 2/3/4 preserved",
        "baseline_manifest": "docs/focus-sounds/SESSION_4_SOURCE_MANIFEST.json",
        "baseline_mobile_inputs_compared": len(mobile), "changed_mobile_inputs": changed,
        "scope": "Application/native/assets/test/build/helper inputs; documentation and generated verification JSON excluded",
        "files": [{"path": path, "bytes": (REPO / path).stat().st_size, "sha256": hashlib.sha256((REPO / path).read_bytes()).hexdigest()} for path in sorted(paths)],
    }
    SOURCE_OUTPUT.write_text(json.dumps(source, indent=2) + "\n", encoding="utf-8")
    checks = {}
    names = [
        "format-1794205436012924000", "analyze-1794205437646508000",
        "focused-1794205510877891200", "tests-1794205544031098600",
        "android-review-1794205856909895100", "windows-build-1794205968452636900",
    ]
    for name in names:
        path = REPO / "artifacts/focus-sounds/session-4/checks" / (name + ".json")
        value = json.loads(path.read_text(encoding="utf-8"))
        mismatches = [p for p, sha in value["source_sha256"].items() if hashlib.sha256((REPO / p).read_bytes()).hexdigest() != sha]
        if value["exit_code"] != 0 or mismatches:
            raise RuntimeError("Check no longer matches current application source: " + name)
        checks[value["check"]] = {
            "record": path.relative_to(REPO).as_posix(),
            "record_sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
            "log": value["log"], "log_sha256": hashlib.sha256((REPO / value["log"]).read_bytes()).hexdigest(),
            "exit_code": value["exit_code"], "elapsed_seconds": value["elapsed_seconds"],
            "source_inputs_verified": len(value["source_sha256"]), "source_matches_current": True,
            **{key: value[key] for key in ["artifact", "runtime"] if key in value},
        }
        if value["check"] in {"focused", "tests"}:
            log = (REPO / value["log"]).read_text(encoding="utf-8", errors="replace")
            totals = re.findall(r"\+(\d+): All tests passed!", log)
            if not totals:
                raise RuntimeError("Missing successful test total in " + value["log"])
            checks[value["check"]]["tests_passed"] = int(totals[-1])
    return source, checks


def main():
    identity = read("016-device-build.identity.json")
    final_identity = read("381-final-build.identity.json")
    checks = {
        "fresh_launch_off_ready_no_completed_rounds": (
            "Focus sounds\nOff" in labels("001-first-launch")
            and "0 of 4 focus rounds completed" in labels("001-first-launch")
        ),
        "default_volume_35_percent": "35 percent" in labels("010-chooser-lower"),
        "four_previews_android_playing": all(playing(name) for name in [
            "006-bells-preview-playing", "007-waterfall-preview-playing",
            "008-ocean-preview-playing", "012-birds-playing",
        ]),
        "three_timed_previews_end_without_timer_start": (
            all(stopped(name + "-expired") for name in [
                "006-bells-preview", "007-waterfall-preview", "008-ocean-preview",
            ]) and "25 minutes 0 seconds remaining, Focus, Ready" in labels("015-ready-after-previews")
        ),
        "chooser_dismissal_stops_birds_preview": stopped("014-dismissed-silent"),
        "ready_selection_silent": stopped("026-selection-ready-silent"),
        "start_with_alert_onboarding_declined_plays": playing("042-after-alert-decline"),
        "media_pause_leaves_timer_running": (
            stopped("044-running-audio-paused")
            and any("Focus, Running" in text for text in labels("045-running-timer-audio-paused"))
        ),
        "media_play_during_running_focus_plays": playing("047-running-replayed"),
        "timer_pause_stops_audio": stopped("049-paused-timer-silent"),
        "media_play_cannot_resume_paused_timer": (
            stopped("052-play-did-not-resume-timer")
            and "0 minutes 21 seconds remaining, Focus, Paused" in labels("050-paused-timer")
            and "0 minutes 21 seconds remaining, Focus, Paused" in labels("053-timer-remains-paused")
        ),
        "reset_paused_and_running_stops_audio": stopped("056-reset-silent") and stopped("063-reset-running-silent"),
        "explicit_timer_resume_plays": playing("061-resumed"),
        "locked_focus_remains_active_before_deadline": all(playing(f"065-deadline-locked-{seconds}s") for seconds in [10, 30, 55, 59]),
        "locked_deadline_stops_service_session_focus": all(stopped(f"065-deadline-locked-{seconds}s") for seconds in [61, 64, 69]),
        "locked_deadline_releases_audio_track_and_wake_lock": (
            "PARTIAL_WAKE_LOCK" in read("065-deadline-locked-30s.resources.json")["power"]
            and "PARTIAL_WAKE_LOCK" not in read("065-deadline-locked-64s.resources.json")["power"]
            and re.search(r"(?m)^\s+\d+\s+yes\s+\d+\s+", read("065-deadline-locked-30s.resources.json")["media.audio_flinger"]) is not None
            and re.search(r"(?m)^\s+\d+\s+yes\s+\d+\s+", read("065-deadline-locked-64s.resources.json")["media.audio_flinger"]) is None
        ),
        "expired_media_play_stays_silent": stopped("070-expired-play-stays-silent"),
        "force_stop_and_cold_relaunch_silent": stopped("077-force-stop-no-service") and stopped("078-cold-start-silent"),
        "initial_source_unchanged_at_initial_observation": read("073-source-identity.json")["changed"] == [],
    }
    initial_names = list(checks)
    extended = {
        "locked_return_ready_and_one_completion": (
            "5 minutes 0 seconds remaining, Short break, Ready" in labels("081-unlocked-cold-restoration")
            and history_total("084-post-deadline-insights") == (1, 1)
        ),
        "break_start_and_media_play_remain_silent": stopped("087-break-running-silent") and stopped("089-break-play-stays-silent"),
        "mute_blocks_start_and_media_play": stopped("095-muted-focus-silent") and stopped("097-muted-play-stays-silent"),
        "unmute_running_focus_plays": playing("100-unmuted-running"),
        "zero_slider_start_and_media_play_remain_silent": "0 percent" in labels("106-zero-volume-set") and stopped("109-zero-start-silent") and stopped("111-zero-play-stays-silent"),
        "midpoint_slider_and_playback": "50 percent" in labels("115-volume-midpoint-set") and playing("116-midpoint-playing"),
        "muted_preferences_survive_cold_restart": (
            stopped("123-muted-cold-silent") and "Focus sounds\nWaterfall\nMuted" in labels("124-muted-cold-restored")
            and "50 percent" in labels("127-volume-mute-persisted")
            and attribute("127-volume-mute-persisted", "Mute sounds", "checked") == "true"
        ),
        "rapid_bells_waterfall_off_stays_stopped": stopped("133-rapid-off-silent") and "Off\nSelected" in labels("134-rapid-off-selected"),
        "running_selection_explicitly_plays": playing("136-running-selection-plays"),
        "settled_preview_restores_correct_source": (
            playing("152-repro-preview") and playing("155-repro-restored")
            and "description=Tibetan bells, Poma," in read("152-repro-preview.state.json")["media_session"]
            and "description=Waterfall, Poma," in read("155-repro-restored.state.json")["media_session"]
        ),
        "skip_to_ready_break_stops": stopped("144-skip-silent") and any("Short break, Ready" in text for text in labels("145-skip-break-ready")),
        "strict_locks_timer_and_keeps_mute_enabled": (
            all(attribute("166-strict-running-controls", text, "enabled") == "false" for text in ["In progress", "Reset timer", "Skip to next phase"])
            and attribute("166-strict-running-controls", "Mute sounds", "enabled") == "true"
            and stopped("168-strict-mute-silent") and playing("171-strict-unmuted-2")
        ),
        "preview_reset_skip_media_do_not_earn_completions": history_total("179-no-earned-skip-history") == (1, 1),
        "strict_deadline_adds_exactly_one_completion": history_total("183-post-strict-history") == (2, 2),
    }
    corrected = {
        "installed_apk_bytes_match_corrected_build": read("383-installed-apk.json")["sha256"] == final_identity["sha256"] and read("383-installed-apk.json")["bytes"] == final_identity["bytes"],
        "review_update_keeps_preferences_and_five_completions": "Focus sounds\nOff" in labels("301-fixed-launch") and history_total("304-before-history") == (5, 5),
        "corrected_ready_selection_silent": stopped("312-ready-silent"),
        "corrected_navigation_home_keeps_audio_before_deadline": all(playing("313-fixed-precise-background-home-" + str(seconds) + "s") for seconds in [15, 30, 55]),
        "corrected_background_expiry_stops_without_ui": all(stopped("313-fixed-precise-background-home-" + str(seconds) + "s") for seconds in [61, 66]),
        "corrected_completion_notification_survives_audio_expiry": (
            notification_ids("313-fixed-precise-background-home-30s") == [-1124]
            and notification_ids("313-fixed-precise-background-home-66s") == [4]
            and "poma_timer_completion_v1" in str(read("313-fixed-precise-background-home-66s.notifications.json"))
        ),
        "corrected_expiry_releases_native_track_and_wake_lock": (
            "PARTIAL_WAKE_LOCK" in read("313-fixed-precise-background-home-30s.resources.json")["power"]
            and "PARTIAL_WAKE_LOCK" not in read("313-fixed-precise-background-home-66s.resources.json")["power"]
            and re.search(r"(?m)^\s+\d+\s+yes\s+\d+\s+", read("313-fixed-precise-background-home-66s.resources.json")["media.audio_flinger"]) is None
        ),
        "corrected_return_ready_and_exactly_one_completion": (
            any("Short break, Ready" in text for text in labels("313-fixed-precise-background-complete"))
            and history_total("313-fixed-precise-background-history") == (6, 6)
        ),
        "active_force_stop_retires_service_and_focus": playing("342-active-play-2") and stopped("344-active-stopped"),
        "cold_relaunch_before_expiry_restores_running_timer_without_audio": (
            any("Focus, Running" in text for text in labels("345-active-cold-before-expiry"))
            and "Focus sounds\nOcean waves\nSound paused" in labels("345-active-cold-before-expiry")
            and stopped("346-active-cold-before-expiry-silent")
        ),
        "reset_after_active_cold_launch_adds_no_history": stopped("348-active-reset") and history_total("334-force-no-new-completion") == history_total("350-active-no-added-history") == (7, 7),
        "full_review_reset_restores_off_ready_and_zero_rounds": stopped("357-review-reset-stopped") and "Focus sounds\nOff" in labels("359-review-default-ready") and "25 minutes 0 seconds remaining, Focus, Ready" in labels("359-review-default-ready") and "0 of 4 focus rounds completed" in labels("359-review-default-ready"),
        "full_review_reset_clears_history_and_tasks": history_total("361-review-empty-history") == (0, 0) and "Finish your first focus session to see it here." in labels("361-review-empty-history") and any("Add one small, achievable task" in text for text in labels("363-review-empty-tasks")),
        "full_review_reset_restores_volume_mute_and_strict_defaults": "35 percent" in labels("370-review-default-preferences") and attribute("370-review-default-preferences", "Mute sounds", "checked") == "false" and attribute("366-review-default-settings", "Strict mode", "checked") == "false",
        "temporary_review_permissions_restored": (
            alarm_checked("201-review-precise-access") == alarm_checked("375-review-precise-restored") == "false"
            and "SCHEDULE_EXACT_ALARM: deny" in read("376-review-precise-appop.json")["result"]
            and "android.permission.POST_NOTIFICATIONS: granted=false" in final_identity["package_dump"]
        ),
        "final_cold_launch_default_silent_no_notifications": "25 minutes 0 seconds remaining, Focus, Ready" in labels("377-final-cold-default") and "Focus sounds\nOff" in labels("377-final-cold-default") and stopped("378-final-silent") and notification_ids("379-final-notifications") == [],
        "production_still_installed_and_system_volume_zero": final_identity["production_still_installed"] and "volume is 0 in range [0..15]" in read("382-system-media-volume.json")["result"],
    }
    checks.update(extended)
    checks.update(corrected)
    failures = [name for name, passed in checks.items() if not passed]
    if failures:
        raise RuntimeError("Device evidence assertions failed: " + ", ".join(failures))
    source, fresh_checks = source_and_checks()
    regression = {
        "initial_status": "Fail: audio expiry withdraws independent completion request",
        "sound_on_notification_ids_at_66s": notification_ids("210-precise-sound-background-home-66s"),
        "sound_off_control_notification_ids_at_61s": notification_ids("217-precise-off-background-home-61s"),
        "sound_off_control_notification_ids_at_66s": notification_ids("217-precise-off-background-home-66s"),
        "corrected_status": "Pass for the observed Android 15 precise-alert/Home procedure",
        "corrected_notification_ids_at_66s": notification_ids("313-fixed-precise-background-home-66s"),
        "failure_test": "artifacts/focus-sounds/session-4/checks/focused-1794205317670938700.json",
        "resolution": "Mobile native audio expiry disarms/releases audio; normal controller foreground/resume/actions own timer/history reconciliation. Desktop retains immediate reconciliation.",
    }
    if regression["sound_on_notification_ids_at_66s"] != [] or regression["sound_off_control_notification_ids_at_66s"] != [3]:
        raise RuntimeError("Retained regression comparison does not match observations")
    failed = json.loads((REPO / regression["failure_test"]).read_text(encoding="utf-8"))
    if failed["exit_code"] == 0:
        raise RuntimeError("Expected before-fix failure record is missing")
    regression["before_fix_exit_code"] = failed["exit_code"]
    regression["before_fix_log"] = failed["log"]
    started = read("065-deadline-lock.json")["start_action_host_monotonic"]
    timeline = []
    for seconds in [10, 30, 55, 59, 61, 64, 69]:
        name = f"065-deadline-locked-{seconds}s"
        timeline.append({
            "evidence": name + ".state.json",
            "host_seconds_after_start_action": round(read(name + ".state.json")["host_monotonic"] - started, 3),
            "playing_service_and_focus": playing(name),
        })
    fixture_failure = {
        "scope": "ADB/environment and initial UI fixture; not an application regression",
        "retained": [
            "Restricted ADB daemon startup failed; permitted execution succeeded.",
            "Initial start encountered the existing alert onboarding dialog (031/034 UI evidence). Fixture then looked for an unobserved 'Pause focus' label and stopped. After declining onboarding, observed 'Pause' and 'Resume' controls were used successfully.",
            "Android media_session volume --help returned unknown argument and its usage. The documented --set/--get syntax was then used.",
            "STREAM_MUSIC speaker volume was 0/muted. Attempt to set low 3/15 still reported 0. Set 0 again and verified restoration. No audible result is inferred.",
            "Early media-session snapshots captured PAUSED during loading. Later expected-title PLAYING/native-track captures establish playback/restoration; the helper now waits for expected source metadata.",
            "An evidence filename listing initially parsed a nonnumeric prefix; the corrected read-only listing succeeded.",
            "After active force-stop, the resource helper treated pidof exit 1/no output as an error. Scoped allow_empty handling fixed this evidence fixture; no process/wake lock was then confirmed. The first cold reopen occurred after the real one-minute deadline and legitimately added the seventh completion; despite filename 334-force-no-new-completion, its UI says seven. A fresh three-minute trial cold-reopened while still Running, stayed silent, and reset without adding history (342-350).",
        ],
    }
    (ROOT / "fixture-failures.json").write_text(json.dumps(fixture_failure, indent=2) + "\n", encoding="utf-8")
    index = [{"file": f.name, "bytes": f.stat().st_size, "sha256": hashlib.sha256(f.read_bytes()).hexdigest()} for f in sorted(ROOT.iterdir()) if f.is_file() and f.name != "evidence-index.json"]
    index_path = ROOT / "evidence-index.json"
    index_path.write_text(json.dumps(index, indent=2) + "\n", encoding="utf-8")
    value = {
        **stamp(),
        "branch": source["branch"],
        "HEAD": source["HEAD"],
        "state": "Connected Android checks finished, alert race corrected and retested, review test data/reset/permissions restored; source uncommitted. Human listening and physical/external gates remain.",
        "device": {key: identity[key] for key in ["ro.product.model", "ro.product.device", "ro.build.version.release", "ro.build.version.sdk", "ro.product.cpu.abi"]},
        "artifact": {key: final_identity[key] for key in ["package", "apk", "sha256", "bytes"]},
        "initial_artifact": {key: identity[key] for key in ["package", "apk", "sha256", "bytes"]},
        "signing": "Release-mode review build, debug-signed; production identity unchanged",
        "initial_source_identity_at_initial_observation": read("073-source-identity.json"),
        "source_manifest": SOURCE_OUTPUT.relative_to(REPO).as_posix(),
        "source_manifest_sha256": hashlib.sha256(SOURCE_OUTPUT.read_bytes()).hexdigest(),
        "changed_mobile_inputs_since_initial_apk": source["changed_mobile_inputs"],
        "fresh_checks": fresh_checks,
        "counts": {"full_flutter": fresh_checks["tests"]["tests_passed"], "focused_audio_ui": fresh_checks["focused"]["tests_passed"], "physical_evidence_assertions": len(checks)},
        "native_check_reuse": "Prior S4 Kotlin/JVM, C++/Windows/mobile-runtime, payload/license and package audits retain their exact unchanged native/assets/config scope. New Dart behavior has fresh analysis/tests/Android/Windows builds; old Windows review ZIP is not described as rebuilt after the correction.",
        "checks": {key: "Pass" for key in checks},
        "check_scopes": {"initial_apk_before_fix": initial_names + list(extended), "corrected_apk": list(corrected)},
        "regression_and_resolution": regression,
        "locked_deadline": {
            "duration_seconds": 60,
            "screen_state": "Android Dozing, confirmed by dumpsys power at 10 and 30 seconds",
            "timeline": timeline,
            "precision": "Polling bounds only; no speaker-latency or subsecond deadline claim",
            "audio_track": "Own AudioFlinger track present while locked/playing and removed after deadline; raw own-PID rows retained",
            "conditions": "USB/ADB attached; default phone networking/power policy unchanged; speaker stream muted at zero",
        },
        "resources": {
            "units": "Android dumpsys meminfo kB; ps RSS in KiB",
            "playing_pss_kb_at_10s_30s": [104236, 102376],
            "post_stop_pss_kb_at_64s": 94829,
            "playing_ps_rss_kib_at_30s": 198180,
            "cpu": "Raw own-process cumulative CPU time retained at one-second resolution; no precise CPU-rate or battery/energy claim",
            "wake_lock": "Review focus-audio partial wake lock held before expiry, absent after expiry",
        },
        "corrected_background_deadline": {
            "evidence_prefix": "313-fixed-precise-background", "duration_seconds": 60,
            "before": "Five one-minute completions; native Ocean waves + media ID -1124 while Home",
            "after": "Stopped at 61/66-second observations; completion ID 4 visible at 66-second capture before UI reentry; six completed minutes on return; next break Ready",
            "conditions": "Notifications and precise alerts temporarily allowed only for review app; USB/network unchanged; system speaker volume zero",
        },
        "personally_inspected_captures": ["377-final-cold-default.png", "370-review-default-preferences.png"],
        "listening": "Pending, explicitly deferred by user: Continue the device checks; I'll listen later. Speaker stream muted at zero; no hearing/loop-quality claim.",
        "permissions": "Review-only POST_NOTIFICATIONS and precise-alert access temporarily enabled for controlled alert comparison, then restored to denied/off. Final UI/appop/package dump and no notifications retained. System media stream remains original zero.",
        "remaining": [
            "USB/debug tools and network disconnected acceptance, offline first use, audible natural joins/loudness/decays and final recording approval.",
            "Real calls/other audio and wired/Bluetooth route removal/reconnection, task removal, TalkBack and physical text scaling. Exact-alert-permitted completion coexistence is verified; additional OEM/power/denied precise-permission delivery behavior remains governed by OS policy.",
            "All previously pending Windows physical/listening/clean-account and unavailable Mac/Xcode/iPhone gates.",
        ],
        "safety": "Only separate review app installed/updated, exercised and reset. Production dev.poma.poma remains installed and its data was not targeted. No security bypass, microphone grant, Git commit/push/merge or release publication.",
        "evidence_root": str(ROOT.relative_to(REPO)).replace("\\", "/"),
        "evidence_index_sha256": hashlib.sha256(index_path.read_bytes()).hexdigest(),
        "evidence_files": len(index),
        "fixture_failures": fixture_failure,
    }
    OUTPUT.write_text(json.dumps(value, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"record": str(OUTPUT), "source_manifest": str(SOURCE_OUTPUT), "checks_passed": len(checks), "evidence_files": len(index), "listening": "Deferred by user", "device_run": "Finished; final review app default and silent"}))


if __name__ == "__main__":
    main()
