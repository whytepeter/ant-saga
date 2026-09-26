#!/usr/bin/env python3
"""Make the game's sounds (assets/audio/*.ogg) from recorded CC0 sources.

    python3 tools/process_sounds.py             # all
    python3 tools/process_sounds.py step rain   # only names containing these words

Sources: BigSoundBank (Joseph Sardin, CC0), downloaded as OGG into
source/bigsoundbank/<id>_<name>.ogg (git-ignored; see assets/audio/CREDITS.md
for the list and URLs). Needs ffmpeg.

Everything is cut, cleaned, pitched and levelled the same way so the mix holds
together (Grounded and Smalland are the reference: real garden recordings, the
creatures made bigger by pitching them down, the far-off human world muffled):
  beds      steady stretches, crossfaded into seamless loops, levelled to one
            loudness so the game's mixer only sets their balance
  loops     creature buzzes and water, looped the same way
  hits      single footsteps, strokes, drips and barks found automatically in
            longer takes (onset detection), trimmed, faded, levelled per set
Pitch shifts are plain resampling (speed and pitch together): a bumblebee
slowed to 0.8 sounds like the bus-sized bee it is at 5 mm.
"""
import array
import math
import subprocess
import sys
import tempfile
import wave
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "source" / "bigsoundbank"
OUT = ROOT / "assets" / "audio"
SR = 48000


# ── ffmpeg in and out ─────────────────────────────────────────────────────────

def source(name):
    hits = sorted(SRC.glob(f"*_{name}.ogg"))
    if not hits:
        sys.exit(f"missing source {name} in {SRC}")
    return hits[0]


def decode(name, start=0.0, dur=None, pitch=1.0, af=""):
    """Mono float samples at SR: `dur` seconds of output from `start`, resampled
    by `pitch` (0.8 = slower and lower), through the ffmpeg filter chain `af`."""
    chain = [f"asetrate={int(SR * pitch)}", f"aresample={SR}"] if pitch != 1.0 else [f"aresample={SR}"]
    if af:
        chain.append(af)
    cmd = ["ffmpeg", "-v", "error", "-ss", f"{start:.3f}"]
    if dur is not None:
        cmd += ["-t", f"{dur * pitch:.3f}"]  # source seconds needed for `dur` of output
    cmd += ["-i", str(source(name)), "-ac", "1", "-af", ",".join(chain), "-f", "s16le", "-"]
    raw = subprocess.run(cmd, capture_output=True, check=True).stdout
    return [v / 32768.0 for v in array.array("h", raw)]


def encode(out_name, x, quality=4):
    OUT.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as t:
        tmp = t.name
    with wave.open(tmp, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(array.array("h", (int(max(-1.0, min(1.0, v)) * 32767) for v in x)).tobytes())
    dest = OUT / f"{out_name}.ogg"
    # ffmpeg's own Vorbis encoder (no libvorbis here) only writes stereo: both
    # channels carry the same mono signal, which Godot pans like any other
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", tmp, "-ac", "2", "-c:a", "vorbis", "-strict", "-2",
                    "-q:a", str(quality), str(dest)], check=True)
    Path(tmp).unlink()
    print(f"  {dest.relative_to(ROOT)}  {len(x) / SR:5.2f} s  {dest.stat().st_size // 1024} KB")


# ── shaping ───────────────────────────────────────────────────────────────────

def rms(x):
    return math.sqrt(sum(v * v for v in x) / max(1, len(x)))


def loudest(x, window=0.05):
    """RMS of the loudest `window` s: how hard a hit lands."""
    w = int(window * SR)
    best, acc = 0.0, sum(v * v for v in x[:w])
    for i in range(w, len(x), w // 4):
        seg = x[i - w:i]
        best = max(best, sum(v * v for v in seg))
    return math.sqrt(max(best, acc) / w)


def gain_to(x, level, by=rms):
    g = 10 ** (level / 20.0) / max(1e-6, by(x))
    peak = max(abs(v) for v in x) * g
    if peak > 0.97:  # never clip: back off to a -0.3 dB peak
        g *= 0.97 / peak
    return [v * g for v in x]


def fades(x, fin=0.005, fout=0.05):
    n, a, b = len(x), int(fin * SR), int(fout * SR)
    x = list(x)
    for i in range(min(a, n)):
        x[i] *= i / a
    for i in range(min(b, n)):
        x[n - 1 - i] *= i / b
    return x


def footfall(x, rise=0.02, hold=0.05, tau=0.09):
    """Gives a piece of continuous shuffle the envelope of one step: a quick
    rise into the crunch, a short hold, then a decay."""
    out = list(x)
    for i in range(len(out)):
        t = i / SR
        e = t / rise if t < rise else (1.0 if t < rise + hold else math.exp(-(t - rise - hold) / tau))
        out[i] *= e
    return out


def loop(x, fade=2.0):
    """Crossfades the last `fade` s into the start (equal power): seamless."""
    nf = int(fade * SR)
    body, tail = list(x[:-nf]), x[-nf:]
    for i in range(nf):
        t = i / nf
        body[i] = body[i] * math.sin(t * math.pi / 2) + tail[i] * math.cos(t * math.pi / 2)
    return body


def onsets(x, min_gap=0.3, rise_db=7.0, above_db=5.0):
    """Times (s) where the level jumps: footsteps, strokes, drips, barks."""
    hop = int(0.01 * SR)
    env = []
    for i in range(0, len(x) - hop, hop):
        seg = x[i:i + hop]
        env.append(20 * math.log10(max(1e-6, math.sqrt(sum(v * v for v in seg) / hop))))
    med = sorted(env)[len(env) // 2]
    out, last = [], -1e9
    for i in range(6, len(env)):
        before = max(env[i - 6:i - 1])
        if env[i] - before > rise_db and env[i] > med + above_db and (i - last) * 0.01 >= min_gap:
            out.append(i * 0.01)
            last = i
    return out


def peaks(x, min_gap=0.4):
    """Times (s) of the loudest moments, at least `min_gap` apart: where a
    shuffling take (dry leaves) crunches hardest."""
    hop = int(0.02 * SR)
    env = [math.sqrt(sum(v * v for v in x[i:i + hop]) / hop) for i in range(0, len(x) - hop, hop)]
    gap = int(min_gap / 0.02)
    out = []
    for i in range(gap, len(env) - gap):
        if env[i] == max(env[i - gap:i + gap + 1]):
            out.append(i * 0.02)
    return out


def loudest_time(name, pitch=1.0, af=""):
    """When the single loudest moment of a take happens (s, output time)."""
    x = decode(name, pitch=pitch, af=af)
    hop = int(0.01 * SR)
    env = [sum(v * v for v in x[i:i + hop]) for i in range(0, len(x) - hop, hop)]
    return env.index(max(env)) * 0.01


def hits(name, count, length, pitch=1.0, af="", pre=0.02, min_gap=0.3, rise_db=7.0, spread_db=4.0, skip=0.0,
         at_peaks=False):
    """The `count` most even single hits from a take: each `length` s from just
    before its onset (or, `at_peaks`, swelling into its loudest moment), all
    within `spread_db` of the median loudness."""
    x = decode(name, pitch=pitch, af=af)
    found = []
    for t in (peaks(x, min_gap) if at_peaks else onsets(x, min_gap, rise_db)):
        if t < skip:
            continue
        a = max(0, int((t - pre) * SR))
        seg = x[a:a + int(length * SR)]
        if len(seg) == int(length * SR):
            found.append(seg)
    if not found:
        sys.exit(f"no hits found in {name}")
    levels = [20 * math.log10(max(1e-6, loudest(s))) for s in found]
    med = sorted(levels)[len(levels) // 2]
    good = [s for s, l in zip(found, levels) if abs(l - med) <= spread_db]
    step = max(1, len(good) // count)
    return good[::step][:count], len(found)


# ── the sounds ────────────────────────────────────────────────────────────────
# levels: beds at -26 dBFS RMS, loops at -22, hits peak at -10 (50 ms window);
# the game's mixer (world/garden_audio.gd) sets the balance from there.

BED, LOOP, HIT = -26.0, -22.0, -10.0


def make_all(want):
    def on(name):
        return not want or any(w in name for w in want)

    def bed(out, src, start, dur, pitch=1.0, af="", level=BED, fade=2.0):
        if on(out):
            encode(out, gain_to(loop(decode(src, start, dur + fade, pitch, af), fade), level))

    def one(out, src, start, dur, pitch=1.0, af="", level=HIT, fout=0.2):
        if on(out):
            encode(out, gain_to(fades(decode(src, start, dur, pitch, af), 0.004, fout), level, loudest))

    def set_of(prefix, src, count, length, level=HIT, step=False, **kw):
        if not on(prefix):
            return
        segs, total = hits(src, count, length, **kw)
        for k, s in enumerate(segs):
            s = footfall(s, 0.06 if kw.get("at_peaks") else 0.004) if step else fades(s, 0.004, min(0.12, length / 3))
            encode(f"{prefix}_{k}", gain_to(fades(s, 0.002, 0.03), level, loudest))
        print(f"    ({len(segs)} of {total} hits in {src})")

    # beds: the garden around him
    bed("bed_canopy", "wind_tall_grass", 4.0, 36.0, af="highpass=f=60")
    bed("bed_heat", "sun_and_heat", 1.0, 40.0, af="highpass=f=120,lowpass=f=9000")
    bed("bed_birds", "birds_in_city", 0.5, 84.0, af="highpass=f=300,lowpass=f=9000", fade=3.0)
    bed("bed_dusk", "campaign_night", 46.0, 26.0, af="highpass=f=200")
    bed("bed_rain", "summer_rain_terrace", 2.0, 58.0, af="highpass=f=80", level=-24.0, fade=3.0)
    bed("bed_rain_water", "rain_on_puddle", 1.0, 42.0, af="highpass=f=100")
    bed("bed_cave", "cave", 0.0, 68.0, af="highpass=f=60", fade=3.0)
    bed("bed_glide", "wind_tall_grass", 44.0, 26.0, af="highpass=f=250,lowpass=f=4000")
    # loops out in the world
    bed("loop_lap", "beach_small_waves", 2.0, 46.0, 0.8, "lowpass=f=1400,highpass=f=80", LOOP)
    bed("loop_flies", "many_flies", 8.0, 46.0, 0.9, "highpass=f=90", LOOP)
    bed("loop_bee", "bumblebee_1", 1.2, 5.8, 0.8, "highpass=f=60", LOOP, fade=0.8)
    bed("loop_wings", "flying_chafer", 0.4, 3.6, 0.7, "highpass=f=60", LOOP, fade=0.6)
    bed("loop_cricket", "field_cricket", 1.0, 34.0, 0.9, "highpass=f=300", LOOP)
    bed("loop_chimes", "wind_chimes", 40.0, 60.0, 1.0, "highpass=f=200", LOOP, fade=3.0)
    # far off: the house and the street beyond the fence
    one("far_mower", "mower", 1.5, 41.0, 1.0, "lowpass=f=650,highpass=f=60", -18.0, fout=4.0)
    one("far_dog_0", "barking_dog", 0.0, 4.0, 1.0, "lowpass=f=1600,highpass=f=150", -14.0, fout=0.8)
    one("far_dog_1", "barking_dog", 8.0, 4.5, 1.0, "lowpass=f=1600,highpass=f=150", -14.0, fout=0.8)
    # birds overhead
    for k, src in enumerate(("blackbird_a", "blackbird_b", "blackbird_c", "robin_1", "robin_4")):
        one(f"bird_{k}", src, 0.0, 5.0, 1.0, "highpass=f=900,lowpass=f=8000", -12.0, fout=0.6)
    # weather
    one("thunder_0", "rain_thunder_1", 18.0, 24.0, 1.0, "highpass=f=30", -8.0, fout=4.0)
    one("thunder_1", "rain_thunder_3", 14.0, 26.0, 1.0, "highpass=f=30", -8.0, fout=4.0)
    for k, p in enumerate((0.55, 0.65, 0.78)):  # a raindrop the size of a car, landing close
        one(f"drop_{k}", "splash_small", 0.0, 1.6, p, "lowpass=f=5000,highpass=f=40", -10.0, fout=0.5)
    # water
    one("splash_big", "splash_big", 0.0, 3.2, 0.85, "highpass=f=40", -8.0, fout=0.8)
    one("splash_small", "splash_small", 0.0, 2.4, 1.0, "highpass=f=60", -10.0, fout=0.6)
    set_of("stroke", "rowing_slowly", 4, 0.9, pitch=0.9, af="highpass=f=80", min_gap=0.8)
    set_of("wade", "shoes_in_water", 4, 0.5, af="highpass=f=80", min_gap=0.35)
    set_of("drip", "drops_of_water", 5, 0.8, af="highpass=f=150", min_gap=0.25, rise_db=9.0)
    # Amodu: footsteps (at 5 mm the soil's grains are gravel underfoot)
    set_of("step_soil", "steps_gravel", 6, 0.38, step=True, pitch=0.92, af="highpass=f=70,lowpass=f=9000", min_gap=0.35)
    set_of("step_leaf", "feet_in_leaves", 6, 0.42, step=True, af="highpass=f=90", min_gap=0.45, pre=0.1, at_peaks=True)
    set_of("step_grass", "steps_grass_slow", 4, 0.45, step=True, af="highpass=f=90", min_gap=0.4)
    set_of("step_wood", "steps_wooden_floor", 5, 0.3, af="highpass=f=90", min_gap=0.3, pre=0.012, at_peaks=True)
    set_of("step_hollow", "walk_on_pontoon", 4, 0.35, af="highpass=f=80", min_gap=0.3, pre=0.012, at_peaks=True)
    for k, src in enumerate(("jump_grass_1", "jump_grass_2")):  # from the moment the feet hit
        if on("land"):
            t = loudest_time(src, 0.85)
            one(f"land_{k}", src, max(0.0, t * 0.85 - 0.03), 0.7, 0.85, "highpass=f=40", -8.0, fout=0.25)  # t is output time; -ss takes source time
    one("jump_0", "whoosh_rope", 0.0, 1.0, 0.8, "highpass=f=120", -14.0, fout=0.2)
    one("jump_1", "whoosh_stick", 0.0, 0.53, 0.8, "highpass=f=120", -14.0, fout=0.15)
    one("jump_2", "whoosh_board", 0.0, 0.5, 0.8, "highpass=f=120", -14.0, fout=0.15)
    set_of("grab", "feet_in_leaves", 3, 0.25, step=True, af="highpass=f=300", min_gap=0.45, pre=0.06, skip=20.0, at_peaks=True)
    one("puff_grab", "whoosh_board", 0.0, 0.5, 0.6, "lowpass=f=2500", -18.0, fout=0.2)
    one("ladybird_flight", "flying_chafer", 0.0, 4.9, 0.8, "highpass=f=60", -12.0, fout=1.0)
    # the way home
    one("chime", "chimes_butterfly", 0.0, 2.28, 1.0, "highpass=f=300", -16.0, fout=0.8)


if __name__ == "__main__":
    make_all(sys.argv[1:])
