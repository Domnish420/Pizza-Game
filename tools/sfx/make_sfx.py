"""Make Crust Empire's sound effects: every sound is generated here from sine waves and shaped noise, so it can be
rebuilt and tweaked like the models.

    python3 tools/sfx/make_sfx.py            # all of them
    python3 tools/sfx/make_sfx.py ding cut   # just these

Writes assets/sfx/<name>.wav (mono, 16-bit, 22.05 kHz). The game plays them with Art.sfx(name) (one-shots) and
Art.loop(name, level) (the background loops: fire, murmur, room). The style is a toy kitchen: soft, warm, short,
never harsh; nothing louder than about -3 dB. See tools/sfx/README.md."""
import os
import sys
import wave

import numpy as np

SR = 22050
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "assets", "sfx")
rng = np.random.default_rng(7)


# ---------------------------------------------------------------- building blocks
def t_(dur):
    return np.arange(int(SR * dur)) / SR


def env(n, attack=0.004, decay=0.2, hold=0.0):
    """a quick rise, an optional hold, then an exponential fall (decay = seconds to fall to about 1/e)"""
    t = np.arange(n) / SR
    e = np.minimum(1.0, t / max(attack, 1e-4))
    fall = np.exp(-np.maximum(0.0, t - attack - hold) / max(decay, 1e-4))
    return e * fall


def tone(f, dur, decay=0.3, attack=0.003, partials=((1.0, 1.0),), f_end=None):
    """a struck or plucked tone; partials are (frequency ratio, amplitude); f_end glides the pitch"""
    t = t_(dur)
    f = np.full_like(t, f) if f_end is None else f * (f_end / f) ** (t / dur)
    ph = 2 * np.pi * np.cumsum(f) / SR
    s = sum(a * np.sin(ph * r) * np.exp(-t / (decay / max(r, 1.0) ** 0.5)) for r, a in partials)
    return _tail(s * env(len(t), attack, 1e9))


def _tail(x, ms=10.0):
    """every part ends with a short fade, so stopping before it has died away never clicks"""
    k = min(len(x), int(SR * ms / 1000))
    if k > 1: x[-k:] *= np.linspace(1, 0, k)
    return x


def shaped_noise(dur, lo, hi, tilt=0.0, seamless=False):
    """noise with only the frequencies lo..hi Hz (tilt < 0 makes it darker); made in the frequency domain, so it
    loops without a seam when seamless"""
    n = int(SR * dur)
    spec = rng.normal(size=n // 2 + 1) + 1j * rng.normal(size=n // 2 + 1)
    f = np.fft.rfftfreq(n, 1 / SR)
    band = ((f >= lo) & (f <= hi)).astype(float)
    # soft edges, so it does not ring
    band = np.convolve(band, np.hanning(9) / np.hanning(9).sum(), mode="same")
    spec *= band * np.where(f > 0, (np.maximum(f, 1.0) / 1000.0) ** tilt, 0.0)
    x = np.fft.irfft(spec, n)
    return x / (np.abs(x).max() + 1e-9)


def burst(dur, lo, hi, decay, attack=0.002):
    x = shaped_noise(dur, lo, hi)
    return _tail(x * env(len(x), attack, decay), 6.0)


def place(dst, src, at, gain=1.0):
    i = int(at * SR)
    j = min(len(dst), i + len(src))
    dst[i:j] += src[:j - i] * gain
    return dst


def mix(*xs):
    """add sounds of different lengths (each from the start)"""
    out = np.zeros(max(len(x) for x in xs))
    for x in xs: out[:len(x)] += x
    return out


def silence(dur):
    return np.zeros(int(SR * dur))


def fade(x, ms_in=3.0, ms_out=12.0):
    a, b = int(SR * ms_in / 1000), int(SR * ms_out / 1000)
    if a: x[:a] *= np.linspace(0, 1, a)
    if b: x[-b:] *= np.linspace(1, 0, b)
    return x


def norm(x, peak_db=-4.0):
    return x / (np.abs(x).max() + 1e-9) * 10 ** (peak_db / 20)


def periodic_am(n, rate, depth, phase=0.0):
    """an amplitude wobble with a whole number of cycles over n samples (so a loop stays seamless)"""
    cycles = max(1, round(rate * n / SR))
    return 1.0 - depth * 0.5 * (1 + np.sin(2 * np.pi * cycles * np.arange(n) / n + phase))


# ---------------------------------------------------------------- the sounds
def tap():
    """a soft wooden tok: buttons and things you touch"""
    return norm(fade(mix(tone(820, 0.09, 0.025, partials=((1, 1), (2.3, 0.35))), 0.15 * burst(0.03, 1500, 5000, 0.006))), -9)


def ding():
    """a new order: a small bright bell"""
    return norm(fade(tone(1320, 1.0, 0.45, partials=((1, 1), (2.76, 0.4), (5.4, 0.15))), ms_out=250), -8)


def bell():
    """the pass bell: a pizza going out (the desk bell, ding!)"""
    x = tone(2093, 1.4, 0.7, partials=((1, 1), (2.32, 0.5), (4.25, 0.25), (6.1, 0.08)))
    return norm(fade(mix(x, 0.25 * burst(0.02, 3000, 8000, 0.004)), ms_out=300), -7)


def cash():
    """the till: a drawer clunk, two chimes and a jingle of coins"""
    x = silence(0.9)
    place(x, mix(burst(0.08, 200, 1500, 0.02), 0.6 * tone(110, 0.08, 0.03)), 0.0, 0.8)
    place(x, tone(2637, 0.6, 0.25, partials=((1, 1), (2.7, 0.3))), 0.06, 0.6)
    place(x, tone(3322, 0.6, 0.3, partials=((1, 1), (2.7, 0.3))), 0.16, 0.6)
    for k in range(7):
        place(x, tone(rng.uniform(4000, 6500), 0.12, 0.03), 0.22 + k * rng.uniform(0.02, 0.05), 0.18)
    return norm(fade(x, ms_out=150), -7)


def bad():
    """something went wrong (burnt, walked out): a soft low bwomp, falling"""
    x = tone(320, 0.42, 0.22, partials=((1, 1), (2, 0.35), (3, 0.15)), f_end=190)
    return norm(fade(x, ms_out=40), -9)


def up():
    """something done well: three plucked notes up"""
    x = silence(0.7)
    for k, f in enumerate((1047, 1319, 1568)):
        place(x, tone(f, 0.45, 0.16, partials=((1, 1), (2, 0.2), (3, 0.08))), k * 0.075, 0.7)
    return norm(fade(x, ms_out=120), -8)


def punch():
    """the clock: a time card punched, ka-chunk, and the clock's little bell"""
    x = silence(0.55)
    for at, g in ((0.0, 0.8), (0.085, 1.0)):
        place(x, mix(burst(0.07, 150, 1800, 0.02), 0.8 * tone(95, 0.09, 0.035)), at, g)
    place(x, tone(2350, 0.4, 0.18, partials=((1, 1), (2.7, 0.25))), 0.13, 0.35)
    return norm(fade(x), -6)


def plop():
    """a ladle of sauce landing on the dough"""
    x = mix(tone(190, 0.16, 0.05, f_end=520) * 0.9, 0.5 * burst(0.12, 150, 1100, 0.04))
    return norm(fade(x, ms_out=30), -8)


def scoop():
    """the ladle dipping into the sauce pan: a short wet slurp"""
    n = int(0.26 * SR)
    t = np.arange(n) / SR
    x = shaped_noise(0.26, 250, 1400) * env(n, 0.02, 0.07, 0.06)
    x += 0.5 * np.sin(2 * np.pi * np.cumsum(260 + 400 * t / t[-1]) / SR) * env(n, 0.01, 0.05, 0.04)
    return norm(fade(x, ms_out=30), -10)


def sprinkle():
    """cheese or a topping going on: a light patter"""
    x = silence(0.32)
    for k in range(11):
        place(x, burst(0.03, 1800, 7000, 0.006), rng.uniform(0.0, 0.24), rng.uniform(0.3, 1.0))
    return norm(fade(x), -13)


def slap():
    """dough pressed and stretched on the marble: a soft floury pat"""
    x = mix(burst(0.12, 90, 1200, 0.03), 0.6 * tone(85, 0.12, 0.04))
    return norm(fade(x, ms_out=20), -11)


def peel():
    """the peel sliding a pizza across the oven's stone"""
    n = int(0.42 * SR)
    t = np.arange(n) / SR
    x = shaped_noise(0.42, 700, 3800, tilt=-0.6) * np.sin(np.pi * t / t[-1]) ** 1.5
    x += 0.3 * shaped_noise(0.42, 60, 300) * np.sin(np.pi * t / t[-1])
    return norm(fade(x, ms_out=20), -10)


def cut():
    """the pizza wheel rolling through the crust: a run of tiny crunches"""
    x = silence(0.46)
    k = 0.0
    while k < 0.4:
        place(x, burst(0.012, 2200, 7500, 0.003), k, rng.uniform(0.35, 1.0))
        k += rng.uniform(0.008, 0.022)
    n = len(x)
    x *= np.sin(np.pi * np.arange(n) / n) ** 0.6
    return norm(fade(x), -11)


def log():
    """a log thrown on the fire: a wooden thunk, then a crackle"""
    x = silence(0.9)
    place(x, mix(tone(150, 0.25, 0.07, partials=((1, 1), (2.6, 0.4))), 0.8 * burst(0.1, 100, 1500, 0.03)), 0.0)
    for k in range(9):
        place(x, burst(0.01, 1500, 8000, 0.002), 0.18 + rng.uniform(0, 0.65), rng.uniform(0.2, 0.7))
    return norm(fade(x), -6)


def ring():
    """the phone: two short trills"""
    x = silence(1.15)
    for at in (0.0, 0.55):
        n = int(0.42 * SR)
        t = np.arange(n) / SR
        tr = (np.sin(2 * np.pi * 440 * t) + np.sin(2 * np.pi * 480 * t)) * (0.5 + 0.5 * np.tanh(3.0 * np.sin(2 * np.pi * 20 * t)))
        place(x, tr * env(n, 0.01, 1e9) * np.minimum(1, (t[-1] - t) / 0.02), at)
    return norm(fade(x), -10)


def knock():
    """a delivery at the back door: three knocks"""
    x = silence(0.6)
    for k in range(3):
        place(x, mix(tone(180, 0.12, 0.03, partials=((1, 1), (2.4, 0.5))), 0.7 * burst(0.05, 200, 2500, 0.012)), k * 0.15, 0.9 if k else 1.0)
    return norm(fade(x), -7)


def app():
    """the delivery app: a two-note ping"""
    x = silence(0.45)
    place(x, tone(1318, 0.25, 0.08), 0.0)
    place(x, tone(1760, 0.3, 0.1), 0.085)
    return norm(fade(x), -10)


def ticket():
    """a ticket pulled off the rail: a quick paper rip"""
    n = int(0.14 * SR)
    x = shaped_noise(0.14, 900, 6500) * env(n, 0.005, 0.04)
    x *= 0.6 + 0.4 * np.tanh(2.5 * np.sin(2 * np.pi * 38 * np.arange(n) / SR))
    return norm(fade(x), -13)


# ---------------------------------------------------------------- the background loops (seamless)
def fire():
    """the wood fire: a dark roar that breathes, and crackles"""
    d = 6.0
    n = int(d * SR)
    base = shaped_noise(d, 40, 900, tilt=-1.2, seamless=True) * periodic_am(n, 0.5, 0.35) * periodic_am(n, 1.5, 0.2, 1.0)
    x = base * 0.5
    for k in range(70):
        at = rng.uniform(0, d - 0.02)
        place(x, burst(0.015, 1200, 9000, rng.uniform(0.002, 0.006)), at, rng.uniform(0.1, 0.9))
    return norm(x, -6)


def murmur():
    """the dining room: voices you cannot make out, and now and then a fork on a plate"""
    d = 8.0
    n = int(d * SR)
    x = np.zeros(n)
    for v in range(7):
        lo = rng.uniform(180, 320)
        voice = shaped_noise(d, lo, lo * rng.uniform(3.0, 5.0), tilt=-0.5, seamless=True)
        voice *= periodic_am(n, rng.uniform(2.5, 4.5), 0.75, rng.uniform(0, 6.28)) * periodic_am(n, rng.uniform(0.2, 0.5), 0.6, rng.uniform(0, 6.28))
        x += voice
    x /= np.abs(x).max()
    for k in range(6):
        place(x, tone(rng.uniform(3000, 4800), 0.25, 0.05, partials=((1, 1), (2.4, 0.3))), rng.uniform(0, d - 0.3), 0.12)
    return norm(x, -8)


def room():
    """the kitchen's room tone: the extractor fan's hum and air"""
    d = 4.0
    n = int(d * SR)
    t = np.arange(n) / SR
    hum = 0.5 * np.sin(2 * np.pi * 100 * t) + 0.25 * np.sin(2 * np.pi * 200 * t) + 0.1 * np.sin(2 * np.pi * 300 * t)
    air = shaped_noise(d, 80, 2500, tilt=-1.0, seamless=True)
    return norm(0.25 * hum + air, -10)


SOUNDS = {f.__name__: f for f in (tap, ding, bell, cash, bad, up, punch, plop, scoop, sprinkle, slap, peel, cut, log, ring,
                                  knock, app, ticket, fire, murmur, room)}
LOOPS = ("fire", "murmur", "room")


def write(name, x):
    os.makedirs(OUT, exist_ok=True)
    pcm = (np.clip(x, -1, 1) * 32767).astype("<i2")
    path = os.path.join(OUT, name + ".wav")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    print("WROTE %-9s %5.2f s %6.1f KB%s" % (name, len(x) / SR, os.path.getsize(path) / 1024, "  (loop)" if name in LOOPS else ""))


if __name__ == "__main__":
    names = sys.argv[1:] or list(SOUNDS)
    bad_names = [n for n in names if n not in SOUNDS]
    if bad_names:
        sys.exit("unknown sounds: " + " ".join(bad_names))
    for nm in names:
        write(nm, SOUNDS[nm]())
