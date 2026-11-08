"""Prepare reproducible draft loops. DSP measurements never certify listening."""
from __future__ import annotations

import hashlib
import json
import re
import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TOOLS = ROOT / ".tools/focus-sounds-tools"
FFMPEG = TOOLS / "ffmpeg.exe"
FFPROBE = TOOLS / "ffprobe.exe"
WORK = ROOT / "artifacts/focus-sounds/session-1"
MANIFEST = ROOT / "docs/focus-sounds/ASSET_PROVENANCE.json"
CHOICES = {
    "bells-1110": "tibetan_bells", "waterfall-0219": "waterfall",
    "ocean-0265": "ocean_waves", "forest-2715": "forest_birds",
}
COMMANDS = []


def run(args):
    COMMANDS.append([str(a) for a in args])
    result = subprocess.run(args, capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=90)
    if result.returncode:
        raise RuntimeError(result.stderr[-4000:])
    return result


def probe(path):
    data = json.loads(run([FFPROBE, "-v", "error", "-show_streams", "-show_format", "-of", "json", path]).stdout)
    stream = next(s for s in data["streams"] if s["codec_type"] == "audio")
    return {"duration_seconds": float(data["format"]["duration"]), "channels": stream["channels"],
            "sample_rate_hz": int(stream["sample_rate"]), "codec": stream["codec_name"],
            "format": data["format"]["format_name"], "bytes": path.stat().st_size,
            "sha256": hashlib.file_digest(path.open("rb"), "sha256").hexdigest()}


def loudness(path):
    result = run([FFMPEG, "-hide_banner", "-nostdin", "-i", path, "-af",
                  "loudnorm=I=-23:TP=-3:LRA=11:print_format=json", "-f", "null", "-"])
    return json.loads(re.findall(r'\{\s*"input_i".*?\}', result.stderr, re.S)[-1])


def seam_measure(path):
    # Compare the cyclic boundary step with ordinary sample-to-sample changes.
    # This detects a gross click; it cannot detect distracting phrasing or texture.
    from array import array
    result = subprocess.run([FFMPEG, "-v", "error", "-nostdin", "-i", str(path),
                             "-f", "f32le", "-acodec", "pcm_f32le", "-"], capture_output=True, check=True)
    samples = array("f")
    samples.frombytes(result.stdout)
    channels = probe(path)["channels"]
    boundary = max(abs(samples[ch] - samples[-channels + ch]) for ch in range(channels))
    differences = [abs(samples[i] - samples[i - channels]) for i in range(channels, len(samples), 20)]
    differences.sort()
    p99 = differences[int(len(differences) * .99)]
    return {"max_boundary_sample_step": boundary, "sample_step_p99": p99,
            "boundary_below_p99": boundary <= p99 + 1e-6,
            "interpretation": "Numeric click diagnostic only; listening is pending"}


def main():
    provenance = json.loads(MANIFEST.read_text(encoding="utf-8"))
    masters = WORK / "masters"
    comparison = WORK / "comparison"
    masters.mkdir(parents=True, exist_ok=True)
    comparison.mkdir(exist_ok=True)
    prepared = []
    for candidate in provenance["candidates"]:
        key = candidate["candidate_id"]
        original = ROOT / candidate["original_path"]
        original_info = probe(original)
        candidate["original_media"] = original_info
        loop = masters / (key + "-loop.wav")
        if candidate["category"] == "tibetanBells":
            graph = ("[0:a]aresample=48000,aformat=channel_layouts=mono,asplit=3[a][b][c];"
                     "[a]adelay=3000[a1];[b]adelay=43000[b1];[c]adelay=83000[c1];"
                     "[a1][b1][c1]amix=inputs=3:normalize=0,apad=whole_len=5760000,atrim=end_sample=5760000,asetpts=N/SR/TB[out]")
            steps = ["Keep the complete source decay; mono 48 kHz", "Place full strikes at 3, 43, 83 seconds in a 120-second cycle; no overlapping decays"]
        else:
            duration = min(90.0, original_info["duration_seconds"] - 6)
            seam = 3 if candidate["category"] == "oceanWaves" else 2
            graph = (f"[0:a]atrim=start=3:duration={duration},asetpts=PTS-STARTPTS,aresample=48000,asplit=2[a][b];"
                     f"[a]atrim=start={seam},asetpts=PTS-STARTPTS[tail];"
                     f"[b]atrim=end={seam},asetpts=PTS-STARTPTS[head];"
                     f"[tail][head]acrossfade=d={seam}:c1=qsin:c2=qsin[out]")
            steps = [f"Take {duration:.6f} seconds from t=3 seconds; 48 kHz; retain source channel count",
                     f"Rotate head by {seam} seconds, equal-power wrap crossfade tail into head ({seam} seconds)"]
        run([FFMPEG, "-v", "error", "-nostdin", "-y", "-i", original,
             "-filter_complex", graph, "-map", "[out]", "-t", "120", "-fs", "40000000", "-c:a", "pcm_s24le", loop])
        assert probe(loop)["duration_seconds"] <= 120.01
        measurement = loudness(loop)
        if candidate["category"] == "tibetanBells":
            # Never compress a natural bell decay to meet an LRA target.
            gain = min(-23 - float(measurement["input_i"]), -3 - float(measurement["input_tp"]))
            normalize = f"volume={gain:.6f}dB"
            normalization_step = "Constant gain based on gated active-passage loudness with -3 dBTP headroom; preserve complete bell dynamics"
        else:
            normalize = ("loudnorm=I=-23:TP=-3:LRA=11:linear=true:"
                         f"measured_I={measurement['input_i']}:measured_TP={measurement['input_tp']}:"
                         f"measured_LRA={measurement['input_lra']}:measured_thresh={measurement['input_thresh']}:"
                         f"offset={measurement['target_offset']}")
            normalization_step = "Two-pass loudness normalization: -23 LUFS-I, -3 dBTP ceiling, LRA 11"
        master = masters / (key + "-master.wav")
        run([FFMPEG, "-v", "error", "-nostdin", "-y", "-i", loop, "-af", normalize,
             "-ar", "48000", "-t", "120", "-fs", "40000000", "-c:a", "pcm_s24le", master])
        encoded = comparison / (key + ".ogg")
        run([FFMPEG, "-v", "error", "-nostdin", "-y", "-i", master,
             "-map_metadata", "-1", "-c:a", "libvorbis", "-q:a", "4", encoded])
        measured = loudness(encoded)
        assert float(measured["input_tp"]) <= -2, (key, measured)
        info = probe(encoded)
        result = {"candidate_id": key, "status": "Prepared draft; not auditioned or final",
                  "editing_steps": steps + [normalization_step,
                                             "Encode Ogg Vorbis quality 4; remove inherited metadata"],
                  "ffmpeg_filter_graph": graph, "normalization_filter": normalize,
                  "prepared_path": encoded.relative_to(ROOT).as_posix(), **info,
                  "measured_loudness": measured, "seam_diagnostic": seam_measure(encoded),
                  "listening_acceptance": "Pending", "backend_acceptance": "Pending"}
        if key in CHOICES:
            output = ROOT / "mobile/assets/audio" / (CHOICES[key] + ".ogg")
            output.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(encoded, output)
            result["final_asset_path"] = output.relative_to(ROOT).as_posix()
            result["selection_reason"] = ("Provisional plan-first candidate; not a listening preference" if key != "forest-2715"
                                          else "Accessible original CC0 forest alternative; Freesound original requires login. Not a listening preference")
        prepared.append(result)
        print(f"{key}: {info['duration_seconds']:.3f}s, {info['bytes']:,} bytes, {measured['input_i']} LUFS, {measured['input_tp']} dBTP", flush=True)
    provenance["status"] = "Eight prepared comparisons; four bundled draft candidates; listening pending"
    provenance["preparation_tool"] = run([FFMPEG, "-version"]).stdout.splitlines()[0]
    provenance["tool_archive"] = json.loads((TOOLS / "source.json").read_text())
    provenance["prepared_assets"] = prepared
    MANIFEST.write_text(json.dumps(provenance, indent=2) + "\n", encoding="utf-8")
    (WORK / "preparation-commands.json").write_text(json.dumps(COMMANDS, indent=2) + "\n")


if __name__ == "__main__":
    main()
