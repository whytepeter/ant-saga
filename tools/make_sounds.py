#!/usr/bin/env python3
"""Synthesise the game's sound effects into assets/audio/ (16-bit mono WAV).

    python3 tools/make_sounds.py            # all of them
    python3 tools/make_sounds.py rain bee   # only names containing these words

Everything is made here from noise, oscillators and filters: no downloads,
nothing to license. The sounds are pitched and weighted for a 5 mm boy in a
garden (x360): a raindrop landing near him is a heavy thud and splash, a bee is
a deep engine drone, a dragonfly a helicopter chop, birds call from far
overhead. Loops carry a WAV 'smpl' loop point, so Godot's importer loops them.
"""
import math
import random
import struct
import sys
import wave
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "audio"
SR = 44100
TAU = 2.0 * math.pi


# ── building blocks ───────────────────────────────────────────────────────────

def silence(seconds):
    return [0.0] * int(seconds * SR)


def noise(n, rnd):
    g = rnd.random
    return [g() * 2.0 - 1.0 for _ in range(n)]


def lowpass(x, cutoff):
    a = 1.0 - math.exp(-TAU * cutoff / SR)
    y, s = [0.0] * len(x), 0.0
    for i, v in enumerate(x):
        s += a * (v - s)
        y[i] = s
    return y


def highpass(x, cutoff):
    lp = lowpass(x, cutoff)
    return [a - b for a, b in zip(x, lp)]


def bandpass(x, f0, q):
    """RBJ band-pass (constant 0 dB peak gain)."""
    w = TAU * f0 / SR
    alpha = math.sin(w) / (2.0 * q)
    b0, b2 = alpha, -alpha
    a0, a1, a2 = 1.0 + alpha, -2.0 * math.cos(w), 1.0 - alpha
    b0, b2, a1, a2 = b0 / a0, b2 / a0, a1 / a0, a2 / a0
    y = [0.0] * len(x)
    x1 = x2 = y1 = y2 = 0.0
    for i, v in enumerate(x):
        out = b0 * v + b2 * x2 - a1 * y1 - a2 * y2
        x2, x1, y2, y1 = x1, v, y1, out
        y[i] = out
    return y


def pink(n, rnd):
    """Pink-ish noise: white summed through a few one-pole low-passes."""
    w = noise(n, rnd)
    return [a * 0.5 + b * 0.8 + c * 1.2 for a, b, c in zip(w, lowpass(w, 800), lowpass(w, 150))]


def brown(n, rnd, cutoff=60.0):
    return lowpass(noise(n, rnd), cutoff)


def env_exp(n, attack, decay):
    """Fast linear attack (s), then exponential decay with time constant `decay` (s)."""
    na = max(1, int(attack * SR))
    out = [0.0] * n
    for i in range(n):
        out[i] = i / na if i < na else math.exp(-(i - na) / (decay * SR))
    return out


def mul(a, b):
    return [x * y for x, y in zip(a, b)]


def add_at(dst, src, start, gain=1.0):
    for i, v in enumerate(src):
        j = start + i
        if 0 <= j < len(dst):
            dst[j] += v * gain


def sweep(n, f0, f1, amp=1.0, harmonics=(1.0,), shape=1.0):
    """A tone gliding from f0 to f1 (curve `shape`), with optional harmonics."""
    out, ph = [0.0] * n, 0.0
    for i in range(n):
        t = (i / max(1, n - 1)) ** shape
        ph += TAU * (f0 + (f1 - f0) * t) / SR
        out[i] = amp * sum(h * math.sin(ph * (k + 1)) for k, h in enumerate(harmonics))
    return out


def reverb(x, wet=0.35, size=1.0, tail=1.5):
    """A small Schroeder reverb (four combs, two all-passes) for distance."""
    x = x + [0.0] * int(tail * SR)
    combs = [int(d * size) for d in (1557, 1617, 1491, 1422)]
    out = [0.0] * len(x)
    for d in combs:
        buf, fb = [0.0] * d, 0.78
        for i, v in enumerate(x):
            y = buf[i % d]
            buf[i % d] = v + y * fb
            out[i] += y * 0.25
    for d, g in ((225, 0.5), (556, 0.5)):
        buf = [0.0] * d
        for i, v in enumerate(out):
            b = buf[i % d]
            y = -v * g + b
            buf[i % d] = v + b * g
            out[i] = y
    return [a * (1.0 - wet) + b * wet for a, b in zip(x, out)]


def seamless(x, fade):
    """Crossfades the last `fade` seconds into the start: a click-free loop."""
    nf = int(fade * SR)
    body = x[:-nf]
    tail = x[-nf:]
    for i in range(nf):
        t = i / nf
        body[i] = body[i] * t + tail[i] * (1.0 - t)
    return body


def normalize(x, peak=0.89):
    m = max(1e-9, max(abs(v) for v in x))
    return [v * peak / m for v in x]


def fade_edges(x, fin=0.003, fout=0.01):
    n, a, b = len(x), int(fin * SR), int(fout * SR)
    for i in range(min(a, n)):
        x[i] *= i / a
    for i in range(min(b, n)):
        x[n - 1 - i] *= i / b
    return x


def write(name, x, loop=False):
    OUT.mkdir(parents=True, exist_ok=True)
    path = OUT / f"{name}.wav"
    frames = b"".join(struct.pack("<h", int(max(-1.0, min(1.0, v)) * 32767)) for v in x)
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(frames)
    if loop:
        # append a 'smpl' chunk: one forward loop over the whole file
        smpl = struct.pack("<9I", 0, 0, int(1e9 / SR), 60, 0, 0, 0, 1, 0)
        smpl += struct.pack("<6I", 0, 0, 0, len(x) - 1, 0, 0)
        data = path.read_bytes() + b"smpl" + struct.pack("<I", len(smpl)) + smpl
        data = data[:4] + struct.pack("<I", len(data) - 8) + data[8:]
        path.write_bytes(data)
    print(f"  {path.relative_to(ROOT)}  {len(x) / SR:.2f} s{'  (loop)' if loop else ''}")


# ── ambience ──────────────────────────────────────────────────────────────────

def wind(rnd):
    """Wind through the grass canopy overhead: a soft roar in slow gusts, with
    leaf rustle riding the gusts and, now and then, a tall blade creaking."""
    n = int(18 * SR)
    base = lowpass(pink(n, rnd), 700)
    gust = [0.55 + 0.25 * math.sin(TAU * 0.07 * i / SR) + 0.2 * math.sin(TAU * 0.19 * i / SR + 1.3) for i in range(n)]
    rustle = highpass(noise(n, rnd), 2500)
    flick = lowpass([1.0 if rnd.random() < 0.004 else 0.0 for _ in range(n)], 30)
    x = [b * g + r * g * g * (0.15 + 3.0 * f) for b, g, r, f in zip(base, gust, rustle, flick)]
    for t in (4.0, 11.5):  # a grass blade flexing: a slow woody groan
        m = int(1.6 * SR)
        groan = mul(sweep(m, 95, 70, 0.35, (1.0, 0.5, 0.3, 0.2)), [math.sin(math.pi * i / m) ** 2 for i in range(m)])
        add_at(x, lowpass(groan, 600), int(t * SR))
    return seamless(normalize(x, 0.7), 2.0)


def bird(rnd, kind):
    """A bird call from high overhead, with a little distance on it."""
    x = silence(2.6)
    if kind == "warble":  # robin-ish: quick varied notes
        t = 0.05
        for _ in range(rnd.randint(6, 10)):
            d = rnd.uniform(0.05, 0.12)
            f0 = rnd.uniform(2500, 5500)
            note = mul(sweep(int(d * SR), f0, f0 * rnd.uniform(0.7, 1.4), 0.6, (1.0, 0.15)), env_exp(int(d * SR), 0.01, d / 3))
            add_at(x, note, int(t * SR))
            t += d + rnd.uniform(0.01, 0.06)
    elif kind == "cheep":  # sparrow-ish: repeated short cheeps
        for k in range(rnd.randint(3, 5)):
            d = 0.07
            note = mul(sweep(int(d * SR), 4200, 3200, 0.7, (1.0, 0.3)), env_exp(int(d * SR), 0.005, 0.03))
            add_at(x, note, int((0.1 + k * rnd.uniform(0.18, 0.26)) * SR))
    elif kind == "coo":  # wood pigeon: low soft hoots
        for k, d in enumerate((0.35, 0.5, 0.3, 0.3)):
            f = 520 if k != 1 else 470
            note = mul(sweep(int(d * SR), f, f * 0.9, 0.8, (1.0, 0.2, 0.05)),
                       [math.sin(math.pi * i / int(d * SR)) for i in range(int(d * SR))])
            add_at(x, note, int((0.1 + k * 0.5) * SR))
    else:  # blackbird: slow fluty glides
        t = 0.1
        for _ in range(4):
            d = rnd.uniform(0.2, 0.35)
            f0 = rnd.uniform(1600, 2600)
            note = mul(sweep(int(d * SR), f0, f0 * rnd.uniform(0.8, 1.3), 0.7, (1.0, 0.08), 0.6),
                       [math.sin(math.pi * i / int(d * SR)) for i in range(int(d * SR))])
            add_at(x, note, int(t * SR))
            t += d + 0.08
    return normalize(fade_edges(reverb(x, 0.3, 1.3, 1.0)), 0.8)


def crickets(rnd):
    """Evening crickets: pulse trains of a high tone, three singers."""
    n = int(8 * SR)
    x = [0.0] * n
    for carrier, rate, gap, gain in ((4300, 32, 0.52, 1.0), (4750, 28, 0.66, 0.6), (5100, 36, 0.44, 0.4)):
        t = rnd.uniform(0, gap)
        while t < 8.0 - 0.2:
            for p in range(rnd.choice((3, 4))):
                d = 0.018
                pulse = mul(sweep(int(d * SR), carrier, carrier * 0.98, gain), [math.sin(math.pi * i / int(d * SR)) for i in range(int(d * SR))])
                add_at(x, pulse, int((t + p / rate) * SR))
            t += gap * rnd.uniform(0.9, 1.1)
    return normalize(lowpass(x, 9000), 0.6)


def water_lap(rnd):
    """The Rut's ripples at 5 mm: slow slapping little waves and the odd plop."""
    n = int(8 * SR)
    body = bandpass(noise(n, rnd), 500, 0.7)
    swell = [0.5 + 0.5 * math.sin(TAU * 0.5 * i / SR + 0.8 * math.sin(TAU * 0.13 * i / SR)) for i in range(n)]
    x = [b * s ** 3 for b, s in zip(body, swell)]
    for _ in range(5):
        d = int(0.12 * SR)
        plop = mul(sweep(d, 420, 180, 0.6), env_exp(d, 0.002, 0.04))
        add_at(x, plop, rnd.randint(0, n - d))
    return seamless(normalize(x, 0.7), 1.0)


# ── weather ───────────────────────────────────────────────────────────────────

def rain_loop(rnd):
    """Rain at 5 mm: a hissing roar full of ticks, and every few moments a big
    drop thudding down somewhere near."""
    n = int(10 * SR)
    hiss = bandpass(pink(n, rnd), 2500, 0.4)
    x = [h * 0.5 for h in hiss]
    ticks = [0.0] * n
    for _ in range(2600):
        ticks[rnd.randint(0, n - 1)] += rnd.uniform(-1, 1)
    x = [a + b for a, b in zip(x, bandpass(ticks, 3200, 1.2))]
    for _ in range(22):  # distant heavy drops
        d = int(0.35 * SR)
        thud = mul(lowpass(noise(d, rnd), 180), env_exp(d, 0.004, 0.08))
        add_at(x, thud, rnd.randint(0, n - d), rnd.uniform(1.0, 2.5))
    return seamless(normalize(x, 0.75), 1.0)


def drop_impact(rnd):
    """A raindrop the size of a car landing close by: a thump, a splash and spatter."""
    n = int(1.2 * SR)
    x = [0.0] * n
    add_at(x, mul(sweep(int(0.3 * SR), 70, 38, 1.0), env_exp(int(0.3 * SR), 0.002, 0.07)), 0)
    splash = mul(bandpass(noise(int(0.6 * SR), rnd), rnd.uniform(900, 1500), 0.6), env_exp(int(0.6 * SR), 0.004, 0.12))
    add_at(x, splash, int(0.005 * SR), 1.4)
    for _ in range(rnd.randint(6, 12)):  # the spray coming down
        d = int(0.03 * SR)
        tick = mul(bandpass(noise(d, rnd), rnd.uniform(1500, 4000), 2.0), env_exp(d, 0.001, 0.008))
        add_at(x, tick, int(rnd.uniform(0.12, 0.8) * SR), rnd.uniform(0.3, 0.8))
    return normalize(fade_edges(x), 0.9)


def thunder(rnd):
    n = int(7 * SR)
    rumble = brown(n, rnd, 90)
    roll = [0.0] * n
    for _ in range(6):  # the rolls: each swells in and dies away
        s, w, g = int(rnd.uniform(0.1, 4.5) * SR), rnd.uniform(0.4, 1.5) * SR, rnd.uniform(0.5, 1.0)
        for i in range(s, n):
            roll[i] += g * math.exp(-(i - s) / w) * min(1.0, (i - s) / (0.15 * SR))
    x = [a * (0.15 + b) for a, b in zip(rumble, roll)]
    crack = mul(lowpass(noise(int(0.5 * SR), rnd), 1800), env_exp(int(0.5 * SR), 0.003, 0.12))
    add_at(x, crack, int(0.05 * SR), 0.15)
    return normalize(fade_edges(reverb(x, 0.25, 1.8, 1.5), 0.01, 0.5), 0.9)


# ── creatures ─────────────────────────────────────────────────────────────────

def bee(rnd):
    """A bee the size of a car: a deep engine drone with a wing-beat flutter.
    Frequencies complete whole cycles in 2 s, so it loops without a seam."""
    n = 2 * SR
    f = 110.0
    x = [0.0] * n
    for i in range(n):
        t = i / SR
        ph = TAU * f * t + 0.6 * math.sin(TAU * 3.0 * t)
        saw = sum(math.sin(ph * k) / k for k in range(1, 9))
        x[i] = saw * (0.75 + 0.25 * math.sin(TAU * 8.0 * t))
    air = bandpass(noise(n + SR // 2, rnd), 350, 0.8)
    air = seamless(air, 0.5)
    return normalize([a * 0.8 + b * 0.5 for a, b in zip(x, air)], 0.8)


def dragonfly(rnd):
    """A dragonfly like a small helicopter: a low chop of four wings."""
    n = 2 * SR
    body = lowpass(noise(n + SR // 2, rnd), 400)
    body = seamless(body, 0.5)
    x = [0.0] * n
    for i in range(n):
        t = i / SR
        chop = max(0.0, math.sin(TAU * 26.0 * t)) ** 4
        x[i] = body[i] * (0.25 + chop) + 0.3 * math.sin(TAU * 52.0 * t) * chop
    return normalize(x, 0.8)


def wing_whirr(rnd):
    """A ladybird taking off: a short whirring buzz."""
    n = int(0.7 * SR)
    x = [0.0] * n
    for i in range(n):
        t = i / SR
        x[i] = math.sin(TAU * 180.0 * t + math.sin(TAU * 30.0 * t)) * (0.6 + 0.4 * math.sin(TAU * 22.0 * t))
    x = [a + b * 0.5 for a, b in zip(x, bandpass(noise(n, rnd), 600, 1.0))]
    e = [min(1.0, i / (0.08 * SR)) * min(1.0, (n - i) / (0.3 * SR)) for i in range(n)]
    return normalize(mul(x, e), 0.8)


# ── Amodu ─────────────────────────────────────────────────────────────────────

def step_soil(rnd):
    """A footstep on soil at 5 mm: crunching grains under a sandal, a soft thud."""
    n = int(0.28 * SR)
    x = mul(lowpass(noise(n, rnd), rnd.uniform(1400, 2200)), env_exp(n, 0.003, 0.035))
    add_at(x, mul(sweep(int(0.1 * SR), 110, 70, 0.5), env_exp(int(0.1 * SR), 0.002, 0.025)), 0)
    for _ in range(rnd.randint(5, 11)):  # grains cracking
        d = int(0.006 * SR)
        add_at(x, mul(bandpass(noise(d, rnd), rnd.uniform(2500, 6000), 3.0), env_exp(d, 0.0005, 0.0015)),
               int(rnd.uniform(0.0, 0.07) * SR), rnd.uniform(0.3, 0.9))
    return normalize(fade_edges(x), 0.85)


def step_hard(rnd):
    """A sandal on paving, wood or plastic: a tap and a short ring."""
    n = int(0.22 * SR)
    x = mul(bandpass(noise(n, rnd), rnd.uniform(1200, 2200), 1.5), env_exp(n, 0.001, 0.012))
    add_at(x, mul(sweep(n, rnd.uniform(320, 520), 300, 0.25), env_exp(n, 0.001, 0.05)), 0)
    return normalize(fade_edges(x), 0.8)


def land(rnd):
    """Landing hard from a big leap: a heavy thud and a spray of soil."""
    n = int(0.9 * SR)
    x = mul(sweep(n, 80, 40, 1.0), env_exp(n, 0.002, 0.09))
    add_at(x, mul(lowpass(noise(int(0.4 * SR), rnd), 1500), env_exp(int(0.4 * SR), 0.003, 0.06)), 0, 0.8)
    for _ in range(14):
        d = int(0.008 * SR)
        add_at(x, mul(bandpass(noise(d, rnd), rnd.uniform(2000, 5000), 3.0), env_exp(d, 0.0005, 0.002)),
               int(rnd.uniform(0.03, 0.5) * SR), rnd.uniform(0.2, 0.6))
    return normalize(fade_edges(x), 0.9)


def jump(rnd):
    """The whoosh of a leap."""
    n = int(0.35 * SR)
    src = noise(n, rnd)
    x = [0.0] * n
    for k in range(4):  # a band of noise sweeping up
        a, b = k * n // 4, (k + 1) * n // 4
        seg = bandpass(src[a:b], 400 + 500 * k, 0.8)
        x[a:b] = seg
    e = [math.sin(math.pi * i / n) ** 1.5 for i in range(n)]
    return normalize(lowpass(mul(x, e), 3000), 0.7)


def splash(rnd):
    """Falling into the Rut: a splash with bubbles."""
    n = int(1.4 * SR)
    x = mul(bandpass(noise(n, rnd), 1100, 0.5), env_exp(n, 0.004, 0.18))
    add_at(x, mul(lowpass(noise(int(0.3 * SR), rnd), 300), env_exp(int(0.3 * SR), 0.002, 0.07)), 0, 1.2)
    for _ in range(12):
        d = int(0.05 * SR)
        f0 = rnd.uniform(300, 700)
        add_at(x, mul(sweep(d, f0, f0 * 2.2, 0.4), env_exp(d, 0.002, 0.02)), int(rnd.uniform(0.1, 1.0) * SR))
    return normalize(fade_edges(x), 0.9)


def stroke(rnd):
    """A swimming stroke: a softer slosh."""
    n = int(0.6 * SR)
    e = [math.sin(math.pi * i / n) ** 2 for i in range(n)]
    x = mul(bandpass(noise(n, rnd), rnd.uniform(500, 800), 0.6), e)
    for _ in range(3):
        d = int(0.04 * SR)
        f0 = rnd.uniform(400, 800)
        add_at(x, mul(sweep(d, f0, f0 * 1.8, 0.3), env_exp(d, 0.002, 0.015)), int(rnd.uniform(0.2, 0.5) * SR))
    return normalize(fade_edges(x), 0.7)


def glide_wind(rnd):
    """Air rushing past while gliding on a seed puff."""
    n = int(6 * SR)
    x = bandpass(pink(n, rnd), 700, 0.5)
    wob = [0.8 + 0.2 * math.sin(TAU * 0.4 * i / SR) * math.sin(TAU * 0.17 * i / SR) for i in range(n)]
    return seamless(normalize(mul(x, wob), 0.7), 1.0)


def grab(rnd):
    """Hands and feet taking hold of a surface: a short scrape."""
    n = int(0.2 * SR)
    x = mul(bandpass(noise(n, rnd), rnd.uniform(1400, 2400), 1.2), env_exp(n, 0.004, 0.04))
    return normalize(fade_edges(x), 0.7)


def puff(rnd):
    """Grabbing a seed puff: a soft fluffy whump."""
    n = int(0.6 * SR)
    e = [math.sin(math.pi * i / n) ** 3 for i in range(n)]
    return normalize(mul(lowpass(noise(n, rnd), 900), e), 0.6)


def chime(rnd):
    """A gentle bell when Amodu reaches the next landmark on the way home."""
    n = int(2.5 * SR)
    x = [0.0] * n
    for f, g, d in ((660, 1.0, 0.9), (990, 0.5, 0.6), (1320, 0.35, 0.45), (1760, 0.2, 0.3), (2640, 0.1, 0.2)):
        for i in range(n):
            x[i] += g * math.sin(TAU * f * 1.003 * i / SR) * math.exp(-i / (d * SR))
    return normalize(fade_edges(reverb(x, 0.25, 1.0, 1.0)), 0.6)


# ── the list ──────────────────────────────────────────────────────────────────

SOUNDS = [
    ("amb_wind", wind, True),
    ("amb_crickets", crickets, True),
    ("water_lap", water_lap, True),
    ("rain_loop", rain_loop, True),
    ("thunder", thunder, False),
    ("bee_drone", bee, True),
    ("dragonfly_chop", dragonfly, True),
    ("wing_whirr", wing_whirr, False),
    ("glide_wind", glide_wind, True),
    ("jump", jump, False),
    ("land", land, False),
    ("splash", splash, False),
    ("grab", grab, False),
    ("puff_grab", puff, False),
    ("chime", chime, False),
] + [(f"bird_{k}", (lambda kind: lambda rnd: bird(rnd, kind))(k), False) for k in ("warble", "cheep", "coo", "fluty")] \
  + [(f"drop_{k}", drop_impact, False) for k in range(3)] \
  + [(f"step_soil_{k}", step_soil, False) for k in range(4)] \
  + [(f"step_hard_{k}", step_hard, False) for k in range(3)] \
  + [(f"stroke_{k}", stroke, False) for k in range(2)]


def main():
    want = sys.argv[1:]
    for i, (name, fn, loop) in enumerate(SOUNDS):
        if want and not any(w in name for w in want):
            continue
        write(name, fn(random.Random(1000 + i)), loop)


if __name__ == "__main__":
    main()
