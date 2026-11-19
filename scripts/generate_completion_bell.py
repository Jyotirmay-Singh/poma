"""Reproduce Poma's original completion bell; no external samples or libraries."""

from array import array
from math import exp, pi, sin
from pathlib import Path
import sys
import wave


def main():
    sample_rate = 44100
    seconds = 2
    partials = ((880, 1.0, 2.4), (2376, 0.35, 3.8), (4664, 0.13, 6.0))
    samples = []
    for index in range(sample_rate * seconds):
        time = index / sample_rate
        attack = min(1.0, time / 0.008)
        release = min(1.0, (seconds - time) / 0.2)
        samples.append(attack * release * sum(
            amplitude * exp(-decay * time) * sin(2 * pi * frequency * time)
            for frequency, amplitude, decay in partials
        ))
    scale = 0.72 * 32767 / max(abs(value) for value in samples)
    pcm = array("h", (round(value * scale) for value in samples))
    if sys.byteorder != "little":
        pcm.byteswap()
    target = Path(__file__).resolve().parents[1] / "mobile/native/resources/raw/completion_bell.wav"
    target.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(target), "wb") as output:
        output.setparams((1, 2, sample_rate, 0, "NONE", "not compressed"))
        output.writeframes(pcm.tobytes())
    print(f"Completion bell: {target.stat().st_size} bytes, {seconds}s mono PCM")


if __name__ == "__main__":
    main()
