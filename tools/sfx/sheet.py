"""A contact sheet of every sound, to check them by eye: a spectrogram (time across, pitch up) and the waveform, with
the peak level, DC offset and, for the loops, the jump at the seam. Hard vertical lines in a spectrogram are clicks.

    python3 tools/sfx/sheet.py [out.png]       (default /tmp/sfx_sheet.png)

Exits 1 if any sound clips, sits off centre (DC) or, for a loop, jumps at its seam."""
import glob
import os
import sys
import wave

import numpy as np
from PIL import Image, ImageDraw

LOOPS = ("fire", "murmur", "room")
HERE = os.path.dirname(os.path.abspath(__file__))
files = sorted(glob.glob(os.path.join(HERE, "..", "..", "assets", "sfx", "*.wav")))
out = sys.argv[1] if len(sys.argv) > 1 else "/tmp/sfx_sheet.png"
W, H, cols = 360, 150, 4
rows = (len(files) + cols - 1) // cols
sheet = Image.new("RGB", (W * cols, H * rows), (20, 24, 22))
problems = []
for k, f in enumerate(files):
    with wave.open(f) as w:
        x = np.frombuffer(w.readframes(w.getnframes()), "<i2").astype(float) / 32768
    name = os.path.basename(f)[:-4]
    peak = 20 * np.log10(np.abs(x).max() + 1e-9)
    dc = x.mean()
    seam = abs(x[-1] - x[0]) if name in LOOPS else 0.0
    if np.abs(x).max() > 0.99: problems.append(name + " clips")
    if abs(dc) > 0.005: problems.append(name + " has a DC offset")
    if seam > 0.02: problems.append(name + " jumps at its loop seam")
    n = 256
    hop = max(1, (len(x) - n) // W)
    frames = [np.abs(np.fft.rfft(x[i:i + n] * np.hanning(n)))[:n // 2] for i in range(0, max(1, len(x) - n), hop)][:W]
    S = np.array(frames).T if frames else np.zeros((n // 2, 1))
    S = np.clip((20 * np.log10(S + 1e-6) + 60) / 60, 0, 1)
    tile = Image.new("RGB", (W, H), (20, 24, 22))
    tile.paste(Image.fromarray((S[::-1] * 255).astype(np.uint8)).resize((W - 4, 90)).convert("RGB"), (2, 16))
    d = ImageDraw.Draw(tile)
    xs = np.linspace(0, len(x) - 1, W - 4).astype(int)
    for i in range(len(xs) - 1):
        seg = x[xs[i]:xs[i + 1] + 1]
        d.line([(2 + i, 128 - seg.max() * 20), (2 + i, 128 - seg.min() * 20)], fill=(244, 198, 79))
    d.text((4, 2), "%s  peak %.1f dB  %.2fs%s" % (name, peak, len(x) / 22050, "  seam %.3f" % seam if name in LOOPS else ""), fill=(255, 255, 255))
    sheet.paste(tile, ((k % cols) * W, (k // cols) * H))
sheet.save(out)
print("SHEET", out, "%d sounds" % len(files))
for p in problems: print("PROBLEM", p)
sys.exit(1 if problems else 0)
