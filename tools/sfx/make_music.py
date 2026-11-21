"""Make Crust Empire's music: a gentle waltz on plucked strings, a mandolin with tremolo on the long notes over a
guitar's oom-pah-pah, in G major. Like the sounds, it is generated (Karplus-Strong plucked strings, numpy only), so it
can be rebuilt and changed.

    python3 tools/sfx/make_music.py

Writes assets/sfx/music.ogg (needs ffmpeg with libvorbis) and loops without a seam: whatever is still ringing past
the end is added back onto the start, so looped, every note's tail carries on across the join. The game plays
it on the title screen and quietly between services (not in service), with Art.loop("music", level)."""
import os
import subprocess
import sys
import tempfile
import wave

import numpy as np

SR = 32000
BPM = 84.0
BEAT = 60.0 / BPM
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "assets", "sfx", "music.ogg")
rng = np.random.default_rng(11)

NOTE = {"C": 0, "C#": 1, "D": 2, "D#": 3, "E": 4, "F": 5, "F#": 6, "G": 7, "G#": 8, "A": 9, "A#": 10, "B": 11}


def hz(name):
    """'F#5' -> its frequency"""
    pitch, octave = name[:-1], int(name[-1])
    return 440.0 * 2 ** ((NOTE[pitch] + 12 * (octave + 1) - 69) / 12.0)


def pluck(f, dur, damp=0.996, bright=0.6):
    """a plucked string (Karplus-Strong): a burst of noise round a loop the length of one period, softened a little
    each time round. Made at the nearest whole period, then resampled to the exact pitch so it is in tune."""
    n_out = int(dur * SR)
    period = max(2, int(round(SR / f + 0.5)))
    made_f = SR / (period - 0.5)                 # (averaging with the next sample shortens the loop by half a sample)
    n = int(n_out * f / made_f) + period + 2
    buf = rng.uniform(-1, 1, period)
    # a softer pluck: some of the noise's top end taken off before it starts
    for _ in range(int((1 - bright) * 4)): buf = 0.5 * (buf + np.roll(buf, 1))
    out = np.empty(n)
    k = 0
    while k < n:
        m = min(period, n - k)
        out[k:k + m] = buf[:m]
        buf = damp * 0.5 * (buf + np.roll(buf, -1))
        k += period
    # resample to the exact pitch (made_f -> f), which also makes it n_out long
    t = np.arange(n_out) * (f / made_f)
    y = np.interp(t, np.arange(n), out)
    y -= y.mean()
    tail = min(n_out, int(0.02 * SR))
    y[-tail:] *= np.linspace(1, 0, tail)
    return y


def mandolin(f, dur, vel=1.0):
    """a mandolin course: two strings a hair apart, bright, short-lived"""
    a = pluck(f * 2 ** (3 / 1200), dur, 0.993, 0.85)
    b = pluck(f * 2 ** (-3 / 1200), dur, 0.993, 0.85)
    return vel * 0.5 * (a + b)


def guitar(f, dur, vel=1.0):
    """a nylon-ish guitar note: rounder and longer"""
    return vel * pluck(f, dur, 0.997, 0.35)


# the piece: (melody notes as (note, beats, tremolo)), a bass note and a chord for each bar, in 3/4
MELODY = [
    [("D5", 1, 0), ("B4", 1, 0), ("D5", 1, 0)], [("G5", 2, 1), ("F#5", 1, 0)],
    [("E5", 1, 0), ("G5", 1, 0), ("E5", 1, 0)], [("B4", 3, 1)],
    [("C5", 1, 0), ("E5", 1, 0), ("G5", 1, 0)], [("A5", 2, 1), ("G5", 1, 0)],
    [("F#5", 1, 0), ("E5", 1, 0), ("D5", 1, 0)], [("A4", 3, 1)],
    [("D5", 1, 0), ("B4", 1, 0), ("D5", 1, 0)], [("G5", 1, 0), ("A5", 1, 0), ("B5", 1, 0)],
    [("G5", 2, 1), ("E5", 1, 0)], [("B4", 1, 0), ("D5", 1, 0), ("E5", 1, 0)],
    [("C5", 1, 0), ("E5", 1, 0), ("A5", 1, 0)], [("F#5", 1, 0), ("A5", 1, 0), ("F#5", 1, 0)],
    [("G5", 3, 1)], [(None, 1, 0), ("D5", 1, 0), ("B4", 1, 0)],
]
BASS = ["G2", "G2", "E2", "E2", "C3", "C3", "D3", "D3", "G2", "G2", "E2", "E2", "A2", "D3", "G2", "G2"]
CHORDS = {"G": ["G3", "B3", "D4"], "E": ["G3", "B3", "E4"], "C": ["G3", "C4", "E4"], "D": ["F#3", "A3", "D4"],
          "A": ["A3", "C4", "E4"]}


def piece():
    bars = len(MELODY)
    length = bars * 3 * BEAT
    total = length + 3.0                         # once round, and room for the last notes to ring over the end
    x = np.zeros(int(total * SR))

    def put(sig, at, gain):
        i = int(max(0.0, at + rng.normal(0, 0.006)) * SR)       # a human hand: a few milliseconds early or late
        j = min(len(x), i + len(sig))
        x[i:j] += gain * sig[:j - i]

    for rep in range(1):
        t0 = rep * length
        for b in range(bars):
            bar_t = t0 + b * 3 * BEAT
            # the guitar: the bass on one, the chord on two and three (oom-pah-pah)
            put(guitar(hz(BASS[b]), 2.6, 1.0), bar_t, 0.55)
            chord = CHORDS[BASS[b][0]]
            for beat in (1, 2):
                for k, nm in enumerate(chord):
                    put(guitar(hz(nm), 1.2, 0.8), bar_t + beat * BEAT + k * 0.012, 0.16 if beat == 1 else 0.13)
            # the mandolin: the tune, with tremolo on the long notes
            at = bar_t
            for nm, beats, trem in MELODY[b]:
                if nm is not None:
                    f = hz(nm)
                    if trem:
                        steps = int(beats * BEAT / 0.085)
                        for s in range(steps):
                            put(mandolin(f, 0.35, 0.75 + 0.25 * rng.random()), at + s * 0.085, 0.26 * (1.0 - 0.25 * s / steps))
                    else:
                        put(mandolin(f, 1.4), at, 0.34)
                at += beats * BEAT
    # a touch of room: a few soft early reflections
    room = np.zeros_like(x)
    for d, g in ((0.031, 0.22), (0.047, 0.16), (0.071, 0.1), (0.113, 0.06)):
        room[int(d * SR):] += g * x[:len(x) - int(d * SR)]
    x = x + room
    # fold what rings on past the end back onto the start: looped, every note's tail carries on across the seam
    n = int(round(length * SR))
    y = x[:n].copy()
    y[:len(x) - n] += x[n:]
    return y / np.abs(y).max() * 10 ** (-3 / 20)


if __name__ == "__main__":
    y = piece()
    with tempfile.TemporaryDirectory() as tmp:
        wav = os.path.join(tmp, "music.wav")
        with wave.open(wav, "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(SR)
            w.writeframes((np.clip(y, -1, 1) * 32767).astype("<i2").tobytes())
        os.makedirs(os.path.dirname(OUT), exist_ok=True)
        r = subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav, "-c:a", "libvorbis", "-q:a", "4", OUT])
        if r.returncode != 0: sys.exit("ffmpeg could not write " + OUT)
    print("WROTE music  %.1f s (%d bars at %d bpm)  %.1f KB" % (len(y) / SR, len(MELODY), BPM, os.path.getsize(OUT) / 1024))
