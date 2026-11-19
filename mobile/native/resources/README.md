# Completion bell

`raw/completion_bell.wav` is an original Poma sound synthesized without external
recordings by `scripts/generate_completion_bell.py`. It contains a single
two-second bell, mono 44.1 kHz 16-bit PCM (176,444 bytes), with a short attack,
decaying partials and a fade to silence. It is not the looping Tibetan bells
focus sound and has no third-party sample or attribution requirement.

Android includes this directory as native resources. iOS references the same WAV
in Copy Bundle Resources. Flutter includes it for the packaged Windows toast URI.
Regenerate from the repository root with `rtk proxy python scripts/generate_completion_bell.py`.
