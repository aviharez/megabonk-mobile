"""Sound effects, made in code with Audio as Code (https://audioascode.com, MIT) plus
numpy noise layers for air / water / grit that no instrument covers.

    pip install --break-system-packages "audio-as-code" scipy
    python3 tools/audio/aac_sfx.py [ids...]      # all sounds, or only the ids given

Writes assets/audio/sfx/<id>.wav (44.1 kHz mono 16-bit, peak -1 dBFS, trimmed).
Ids must match tools/audio/sfx.json and data/rules/audio.json. Times in the recipes
are seconds (scores run at 60 bpm, so 1 beat = 1 s). Deterministic: same code, same files.
"""
from __future__ import annotations

import os
import sys
import wave

import numpy as np
from scipy.signal import butter, sosfilt

from audio_as_code import Delay, Distortion, Filter, Note, Reverb, Song, Tone, Track, Tremolo
from audio_as_code import render_audio

SR = 44100
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "assets", "audio", "sfx")


# --- building blocks -----------------------------------------------------------------

def n(pitch, start, dur, vel=0.8):
    return Note(pitch=pitch, start=start, duration=dur, velocity=vel)


def T(inst, notes, gain=0.8, tone=None, fx=(), name=None):
    return Track(name=name or inst, instrument=inst, gain=gain, notes=tuple(notes),
                 tone=Tone(**tone) if tone else None, effects=tuple(fx))


def aac(*tracks, fx=(), seed=3):
    """Render instrument tracks (times in seconds) to a mono float array."""
    tracks = [Track(**{**t.model_dump(), "name": f"{i}_{t.name}"}) for i, t in enumerate(tracks)]
    end = max(x.start + x.duration for t in tracks for x in t.notes)
    song = Song(title="sfx", bpm=60, beats=end, seed=seed, sample_rate=SR, tracks=tuple(tracks), effects=tuple(fx))
    a = render_audio(song, normalize=False).audio
    return a.mean(axis=1).astype(np.float64)


def env(length, attack=0.003, decay=None, hold=0.0, curve=4.0):
    """Attack ramp, optional hold, then exponential-ish decay to 0 over the rest."""
    t = np.arange(length) / SR
    e = np.ones(length)
    if attack > 0:
        e *= np.clip(t / attack, 0, 1)
    rest_start = attack + hold
    span = max(1e-4, (length / SR) - rest_start)
    k = np.clip((t - rest_start) / span, 0, 1)
    e *= (1 - k) ** curve if decay is None else np.exp(-np.maximum(0, t - rest_start) / decay)
    return e


def noise(dur, f0, f1=None, q=1.2, gain=0.6, attack=0.003, decay=None, hold=0.0, curve=3.0,
          am_hz=0.0, am_depth=0.0, color="white", seed=1, kind="band"):
    """Filtered noise burst. Band (or low/high pass) centre glides f0 -> f1 (geometric)."""
    rng = np.random.default_rng(seed)
    m = int(dur * SR)
    x = rng.standard_normal(m)
    if color == "brown":
        x = np.cumsum(x); x -= np.convolve(x, np.ones(400) / 400, mode="same"); x /= np.abs(x).max() + 1e-9
    f1 = f0 if f1 is None else f1
    fc = f0 * (f1 / f0) ** (np.arange(m) / max(1, m - 1))
    out = svf(x, fc, q, kind)
    out /= np.abs(out).max() + 1e-9
    e = env(m, attack, decay, hold, curve)
    if am_hz:
        t = np.arange(m) / SR
        e *= 1 - am_depth * (0.5 + 0.5 * np.sin(2 * np.pi * am_hz * t))
    return out * e * gain


def svf(x, fc, q, kind):
    """Zero-delay state variable filter with a per-sample cutoff (no zipper clicks)."""
    g = np.tan(np.pi * np.clip(fc, 20, SR * 0.45) / SR)
    k = 1.0 / max(q, 0.3) if kind == "band" else 1.4142
    a1 = 1 / (1 + g * (g + k)); a2 = g * a1; a3 = g * a2
    ic1 = ic2 = 0.0
    out = np.empty_like(x)
    mode = {"band": 1, "low": 2, "high": 0}[kind]
    for i in range(len(x)):
        v0 = x[i]
        v3 = v0 - ic2
        v1 = a1[i] * ic1 + a2[i] * v3
        v2 = ic2 + a2[i] * ic1 + a3[i] * v3
        ic1 = 2 * v1 - ic1
        ic2 = 2 * v2 - ic2
        out[i] = v1 if mode == 1 else (v2 if mode == 2 else v0 - k * v1 - v2)
    return out


def tone(dur, f0, f1=None, wave="sine", gain=0.5, attack=0.002, decay=None, hold=0.0, curve=2.0,
         vib_hz=0.0, vib_amt=0.0, jitter=0.0, seed=2):
    """Simple oscillator with an exponential pitch glide (whistles, zaps, squeaks)."""
    rng = np.random.default_rng(seed)
    m = int(dur * SR)
    t = np.arange(m) / SR
    f1 = f0 if f1 is None else f1
    f = f0 * (f1 / f0) ** (t / max(dur, 1e-4))
    if vib_hz:
        f = f * (1 + vib_amt * np.sin(2 * np.pi * vib_hz * t))
    if jitter:
        steps = rng.standard_normal(m // 200 + 2)
        f = f * (1 + jitter * np.interp(np.arange(m), np.arange(len(steps)) * 200, steps))
    ph = 2 * np.pi * np.cumsum(f) / SR
    if wave == "sine":
        y = np.sin(ph)
    elif wave == "square":
        y = np.tanh(4 * np.sin(ph))
    elif wave == "saw":
        y = 2 * ((ph / (2 * np.pi)) % 1) - 1
    else:  # triangle
        y = 2 * np.abs(2 * ((ph / (2 * np.pi)) % 1) - 1) - 1
    return y * env(m, attack, decay, hold, curve) * gain


def mix(*layers):
    """layers: arrays, or (offset_seconds, array)."""
    items = [(0.0, l) if isinstance(l, np.ndarray) else l for l in layers]
    length = max(int(o * SR) + len(a) for o, a in items)
    out = np.zeros(length)
    for o, a in items:
        s = int(o * SR)
        out[s:s + len(a)] += a
    return out


def lowpass(x, hz):
    return sosfilt(butter(2, hz, btype="low", fs=SR, output="sos"), x)


def highpass(x, hz):
    return sosfilt(butter(2, hz, btype="high", fs=SR, output="sos"), x)


# --- the sounds ----------------------------------------------------------------------
# Kept short and soft-edged where they repeat a lot (hit, kill, gem, weapon sounds);
# bigger and more musical for rare moments (level up, chest, boss, run end).

def s_hit():
    return mix(
        aac(T("kick_808", [n(36, 0, 0.1, 0.9)], tone={"tuning_semitones": 14, "decay_seconds": 0.1})),
        noise(0.06, 2400, 900, q=1.0, gain=0.45, decay=0.015),
    )


def s_crit():
    return mix(
        aac(T("kick_808", [n(36, 0, 0.12, 1.0)], tone={"tuning_semitones": 10, "decay_seconds": 0.12}),
            T("fm_percussion", [n(56, 0, 0.12, 0.8)], gain=0.6, tone={"tuning_semitones": 12, "decay_seconds": 0.12})),
        noise(0.1, 3500, 1200, q=0.8, gain=0.6, decay=0.025),
        (0.01, tone(0.12, 1800, 900, "square", gain=0.12, decay=0.04)),
    )


def s_kill():
    return mix(
        aac(T("sub_bass", [n("D4", 0, 0.14, 0.9)], tone={"glide_semitones": -14, "glide_seconds": 0.09})),
        noise(0.07, 1800, 500, q=1.5, gain=0.35, decay=0.02, seed=3),
        (0.0, tone(0.05, 900, 1600, "sine", gain=0.25, decay=0.015)),
    )


def s_hurt():
    return mix(
        aac(T("kick_808", [n(36, 0, 0.25, 1.0)], tone={"decay_seconds": 0.18}),
            T("sync_lead", [n("A4", 0, 0.22, 0.9)], gain=0.55,
              tone={"glide_semitones": -10, "glide_seconds": 0.2, "cutoff_hz": 2200}),
            fx=[Distortion(drive=3, mix=0.35)]),
        noise(0.12, 900, 300, q=0.8, gain=0.3, decay=0.04),
    )


def s_dodge():
    return mix(noise(0.16, 900, 4500, q=1.6, gain=0.7, attack=0.05, curve=2.0, seed=5),
               (0.03, tone(0.1, 1200, 2400, "sine", gain=0.12, attack=0.02)))


def s_gem():
    return aac(T("fm_bell", [n("E6", 0, 0.05, 0.6), n("B6", 0.045, 0.12, 0.65)],
                 tone={"decay_seconds": 0.15, "fm_index": 1.2}),
               T("glockenspiel", [n("B6", 0.045, 0.1, 0.35)], gain=0.4, tone={"decay_seconds": 0.15}))


def s_level_up():
    run = ["C5", "E5", "G5", "C6"]
    return aac(
        T("fm_bell", [n(p, i * 0.075, 0.15, 0.8) for i, p in enumerate(run)] + [n("E6", 0.3, 0.4, 0.75), n("G6", 0.3, 0.4, 0.6)],
          tone={"decay_seconds": 0.6}),
        T("trance_pluck", [n(p, i * 0.075, 0.1, 0.6) for i, p in enumerate(["C4", "E4", "G4", "C5"])] + [n("C5", 0.3, 0.35, 0.6)], gain=0.5),
        T("glockenspiel", [n("G6", 0.3, 0.3, 0.6), n("C7", 0.38, 0.35, 0.5), n("E7", 0.46, 0.3, 0.4)], gain=0.45),
        T("clap", [n(39, 0.3, 0.1, 0.4)], gain=0.25),
        fx=[Reverb(decay_seconds=0.8, mix=0.18)],
    )


def s_card():
    return mix(noise(0.08, 2500, 6000, q=1.2, gain=0.35, attack=0.01, seed=8),
               (0.02, aac(T("trance_pluck", [n("G5", 0, 0.08, 0.7), n("D6", 0.05, 0.12, 0.7)], gain=0.6))))


def s_click():
    return aac(T("fm_percussion", [n(56, 0, 0.04, 0.7)], tone={"tuning_semitones": 16, "decay_seconds": 0.1}),
               T("xylophone", [n("G5", 0, 0.05, 0.45)], gain=0.4, tone={"decay_seconds": 0.1}))


def s_chest():
    return mix(
        aac(T("kick_909", [n(36, 0, 0.15, 0.9)], tone={"tuning_semitones": 7, "decay_seconds": 0.15}),
            T("toms", [n(45, 0.02, 0.15, 0.7)], gain=0.6)),
        noise(0.06, 1200, 500, q=1.0, gain=0.3, decay=0.02, seed=9),
        (0.12, aac(T("celesta", [n(p, i * 0.05, 0.25, 0.75) for i, p in enumerate(["G5", "B5", "D6", "G6", "B6"])]),
                   T("fm_bell", [n("D7", 0.25, 0.4, 0.4)], gain=0.4),
                   fx=[Reverb(decay_seconds=0.7, mix=0.2)])),
    )


def s_beam():
    return mix(
        aac(T("string_machine", [n("C5", 0, 0.32, 0.6)], gain=0.5,
              tone={"glide_semitones": 12, "glide_seconds": 0.3, "cutoff_hz": 3000}),
            T("glockenspiel", [n(p, 0.04 + i * 0.05, 0.12, 0.45) for i, p in enumerate(["C6", "E6", "G6", "C7", "E7"])], gain=0.4)),
        noise(0.3, 1500, 7000, q=2.0, gain=0.18, attack=0.15, curve=2.0, seed=10),
    )


def s_gold():
    return aac(T("glockenspiel", [n("B6", 0, 0.06, 0.8), n("E7", 0.05, 0.12, 0.8)], tone={"decay_seconds": 0.2}),
               T("fm_bell", [n("E7", 0.05, 0.1, 0.35)], gain=0.35, tone={"decay_seconds": 0.15}))


def s_pot():
    rng = np.random.default_rng(12)
    shards = [(0.01 + i * 0.022 + rng.uniform(0, 0.01), tone(0.05, rng.uniform(2500, 5500), None, "sine",
               gain=0.12, decay=0.012, seed=20 + i)) for i in range(6)]
    return mix(
        aac(T("toms", [n(45, 0, 0.1, 0.8)], gain=0.6, tone={"decay_seconds": 0.1}),
            T("fm_percussion", [n(56, 0, 0.1, 0.6)], gain=0.4, tone={"tuning_semitones": 5, "decay_seconds": 0.1})),
        noise(0.18, 3500, 1800, q=0.7, gain=0.45, decay=0.04, seed=12),
        *shards,
    )


def s_shrine():
    chord = ["A4", "C#5", "E5", "A5"]
    return mix(
        aac(T("fm_bell", [n(p, i * 0.04, 0.6, 0.6) for i, p in enumerate(chord)], tone={"decay_seconds": 1.0}),
            T("wavetable_pad", [n(p, 0, 0.55, 0.4) for p in ["A3", "E4"]], gain=0.35, tone={"cutoff_hz": 2500}),
            T("celesta", [n(p, 0.2 + i * 0.05, 0.2, 0.5) for i, p in enumerate(["E6", "A6", "C#7", "E7"])], gain=0.45),
            fx=[Reverb(decay_seconds=1.2, mix=0.25)]),
        noise(0.5, 3000, 8000, q=2.5, gain=0.08, attack=0.2, curve=2.0, seed=13),
    )


def s_key():
    return aac(T("glockenspiel", [n("E6", 0, 0.08, 0.7), n("G#6", 0.06, 0.08, 0.7), n("B6", 0.12, 0.2, 0.75)]),
               T("tambourine", [n(54, 0, 0.1, 0.4), n(54, 0.06, 0.1, 0.35), n(54, 0.12, 0.1, 0.4)], gain=0.35,
                 tone={"decay_seconds": 0.12}))


def s_cage():
    return mix(
        aac(T("fm_percussion", [n(56, 0, 0.1, 0.9), n(56, 0.07, 0.15, 0.8)], gain=0.7,
              tone={"tuning_semitones": -3, "decay_seconds": 0.2, "fm_index": 4, "fm_ratio": 1.41}),
            T("trance_pluck", [n("C5", 0.12, 0.08, 0.6), n("G5", 0.16, 0.12, 0.6)], gain=0.5)),
        noise(0.05, 4000, None, q=2.0, gain=0.25, decay=0.012, seed=14),
    )


def s_merchant():
    return aac(T("vibraphone", [n("E5", 0, 0.22, 0.8), n("C5", 0.22, 0.4, 0.75)], tone={"decay_seconds": 0.8}),
               T("kalimba", [n("E6", 0, 0.15, 0.4), n("C6", 0.22, 0.25, 0.4)], gain=0.35),
               fx=[Reverb(decay_seconds=0.9, mix=0.2)])


def s_buy():
    return mix(
        aac(T("glockenspiel", [n("B5", 0, 0.08, 0.8), n("E6", 0.07, 0.25, 0.8)]),
            T("fm_bell", [n("E7", 0.07, 0.2, 0.35)], gain=0.35, tone={"decay_seconds": 0.3})),
        noise(0.05, 6000, None, q=1.5, gain=0.15, decay=0.015, seed=15),
    )


def s_portal():
    return mix(
        aac(T("wavetable_pad", [n("A3", 0, 0.75, 0.7), n("E4", 0, 0.75, 0.55)], gain=0.5,
              tone={"glide_semitones": 12, "glide_seconds": 0.6, "cutoff_hz": 1500, "filter_env_octaves": 2, "filter_decay_seconds": 0.6}),
            T("fm_bell", [n(p, 0.45 + i * 0.04, 0.4, 0.55) for i, p in enumerate(["A5", "C#6", "E6", "A6"])], gain=0.5),
            fx=[Reverb(decay_seconds=1.0, mix=0.25)]),
        noise(0.7, 300, 5000, q=1.5, gain=0.35, attack=0.4, curve=2.5, seed=16),
    )


def s_swing():
    return noise(0.15, 500, 2200, q=1.4, gain=0.8, attack=0.04, curve=2.0, seed=17)


def s_staple():
    return mix(
        aac(T("fm_percussion", [n(56, 0, 0.03, 0.8), n(56, 0.028, 0.03, 0.6)], tone={"tuning_semitones": 18, "decay_seconds": 0.1, "fm_index": 3})),
        noise(0.03, 5000, None, q=1.5, gain=0.25, decay=0.006, seed=18),
    )


def s_feather():
    return noise(0.12, 3000, 5000, q=1.2, gain=0.55, attack=0.02, curve=2.0, am_hz=45, am_depth=0.7, seed=19)


def s_squeak():
    return mix(tone(0.13, 900, 1500, "square", gain=0.35, attack=0.01, hold=0.06, curve=1.5, vib_hz=28, vib_amt=0.03),
               tone(0.13, 1800, 3000, "sine", gain=0.12, attack=0.01, hold=0.06, curve=1.5))


def s_throw():
    return noise(0.12, 400, 1500, q=1.3, gain=0.7, attack=0.03, curve=2.0, seed=20)


def s_splash():
    return mix(
        noise(0.2, 3500, 700, q=0.9, gain=0.55, attack=0.004, decay=0.06, seed=21),
        tone(0.08, 400, 900, "sine", gain=0.35, decay=0.03),
        (0.04, tone(0.06, 600, 1300, "sine", gain=0.2, decay=0.02, seed=4)),
    )


def s_stink():
    return lowpass(mix(noise(0.2, 180, 120, q=0.8, gain=0.7, attack=0.03, curve=2.0, am_hz=22, am_depth=0.6, color="brown", seed=22),
                       tone(0.18, 90, 70, "saw", gain=0.12, attack=0.03, curve=2.0)), 1200)


def s_bonk():
    return mix(
        aac(T("toms", [n(45, 0, 0.12, 0.9)], tone={"decay_seconds": 0.12, "brightness": 0.7}),
            T("xylophone", [n("C5", 0, 0.08, 0.6)], gain=0.5, tone={"decay_seconds": 0.1})),
        tone(0.06, 700, 350, "triangle", gain=0.3, decay=0.02),
    )


def s_gust():
    return noise(0.16, 700, 1400, q=0.9, gain=0.7, attack=0.03, hold=0.05, curve=2.0, am_hz=17, am_depth=0.3, seed=23)


def s_zap():
    return mix(
        tone(0.13, 1200, 500, "saw", gain=0.3, decay=0.06, jitter=0.25),
        noise(0.13, 5000, 2500, q=0.8, gain=0.35, decay=0.04, am_hz=60, am_depth=0.8, seed=24),
        aac(T("fm_percussion", [n(56, 0, 0.08, 0.6)], gain=0.4, tone={"tuning_semitones": 6, "fm_index": 8, "decay_seconds": 0.1})),
    )


def s_launch():
    return mix(noise(0.18, 600, 3000, q=1.5, gain=0.4, attack=0.01, curve=1.5, seed=25),
               tone(0.18, 800, 2600, "sine", gain=0.22, attack=0.01, curve=1.5))


def s_boom():
    return mix(
        aac(T("kick_808", [n(36, 0, 0.4, 1.0)], tone={"tuning_semitones": -2, "decay_seconds": 0.35})),
        noise(0.45, 1800, 150, q=0.6, gain=0.7, decay=0.12, kind="low", seed=26),
        (0.03, noise(0.25, 4000, 2000, q=1.0, gain=0.15, decay=0.05, am_hz=40, am_depth=0.9, seed=27)),
    )


def s_spit():
    return mix(noise(0.08, 1500, 900, q=1.2, gain=0.5, decay=0.02, seed=28),
               tone(0.09, 500, 180, "sine", gain=0.45, decay=0.03))


def s_fuse():
    return mix(
        aac(T("theremin", [n("C4", 0, 0.7, 0.7)], gain=0.5,
              tone={"glide_semitones": 12, "vibrato_depth_cents": 30, "vibrato_rate_hz": 9})),
        noise(0.7, 6000, 4000, q=1.0, gain=0.12, attack=0.1, curve=1.5, am_hz=30, am_depth=0.5, seed=29),
    )


def s_pop():
    return mix(
        noise(0.03, 2500, None, q=0.5, gain=0.9, decay=0.006, seed=30),
        aac(T("kick_808", [n(36, 0, 0.2, 0.9)], tone={"tuning_semitones": 3, "decay_seconds": 0.2})),
        (0.02, noise(0.22, 1600, 400, q=0.9, gain=0.45, decay=0.06, seed=31)),
    )


def s_windup():
    return mix(tone(0.24, 150, 600, "saw", gain=0.3, attack=0.02, hold=0.15, curve=1.0, vib_hz=25, vib_amt=0.04),
               noise(0.24, 600, 2400, q=1.5, gain=0.2, attack=0.15, curve=1.0, seed=32))


def s_boss_roar():
    growl = aac(T("reese_bass", [n("A1", 0, 1.0, 1.0)], gain=0.8,
                  tone={"glide_semitones": -5, "glide_seconds": 0.9, "cutoff_hz": 900, "detune_cents": 30}),
                T("hoover", [n("A2", 0.05, 0.9, 0.8)], gain=0.45,
                  tone={"glide_semitones": -7, "glide_seconds": 0.8, "cutoff_hz": 1600}),
                fx=[Distortion(drive=4, mix=0.5)])
    return mix(growl, noise(1.0, 700, 250, q=0.7, gain=0.4, attack=0.08, curve=1.5, am_hz=24, am_depth=0.5, seed=33))


def s_boss_dig():
    rng = np.random.default_rng(34)
    scrapes = [(i * 0.06 + rng.uniform(0, 0.02), noise(0.05, rng.uniform(900, 2000), 400, q=1.0, gain=0.3, decay=0.012, seed=40 + i))
               for i in range(7)]
    return mix(noise(0.45, 200, 120, q=0.7, gain=0.6, attack=0.02, curve=1.5, kind="low", color="brown", seed=34), *scrapes)


def s_boss_slam():
    return mix(
        aac(T("kick_808", [n(36, 0, 0.6, 1.0)], gain=1.0, tone={"tuning_semitones": -5, "decay_seconds": 0.6}),
            T("timpani", [n("C2", 0, 0.6, 1.0)], gain=0.7),
            T("sub_bass", [n("E1", 0, 0.6, 0.9)], gain=0.6, tone={"glide_semitones": -5, "glide_seconds": 0.4})),
        noise(0.6, 1200, 100, q=0.6, gain=0.6, decay=0.15, kind="low", seed=35),
        (0.05, noise(0.35, 3000, 1500, q=0.8, gain=0.12, decay=0.08, am_hz=35, am_depth=0.9, seed=36)),
    )


def s_rocks():
    hits = [(t, aac(T("toms", [n(45, 0, 0.08, v)], gain=0.7, tone={"decay_seconds": 0.1, "brightness": 0.4}), seed=50 + i))
            for i, (t, v) in enumerate([(0, 0.9), (0.05, 0.7), (0.09, 0.8), (0.14, 0.6)])]
    return mix(*hits, noise(0.2, 2500, 1200, q=0.8, gain=0.3, decay=0.05, am_hz=30, am_depth=0.8, seed=37))


def s_boss_down():
    return mix(
        s_boom() * 1.0,
        (0.15, aac(T("trumpet", [n("C5", 0, 0.12, 0.8), n("C5", 0.14, 0.1, 0.7), n("G5", 0.26, 0.7, 0.9)], gain=0.6),
                   T("trombone", [n("E4", 0.26, 0.7, 0.7), n("C4", 0.26, 0.7, 0.7)], gain=0.5),
                   T("timpani", [n("C2", 0.26, 0.6, 0.9)], gain=0.6),
                   T("cymbal", [n(49, 0.26, 0.6, 0.5)], gain=0.3),
                   fx=[Reverb(decay_seconds=1.0, mix=0.2)])),
    )


def s_elite():
    return aac(T("french_horn", [n("D3", 0, 0.18, 0.9), n("G#3", 0.17, 0.25, 0.9)], gain=0.7),
               T("tuba", [n("D2", 0, 0.18, 0.8), n("G#2", 0.17, 0.25, 0.8)], gain=0.5),
               T("cymbal", [n(49, 0.17, 0.25, 0.35)], gain=0.25, tone={"decay_seconds": 0.4}),
               fx=[Reverb(decay_seconds=0.7, mix=0.15)])


def s_alarm():
    notes = []
    for i in range(4):
        notes += [n("A5" if i % 2 == 0 else "E5", i * 0.18, 0.16, 0.85)]
    return aac(T("sync_lead", notes, gain=0.6, tone={"cutoff_hz": 3000}),
               T("synthesizer", [n(x.pitch, x.start, x.duration, 0.6) for x in notes], gain=0.3),
               fx=[Reverb(decay_seconds=0.5, mix=0.12)])


def s_final():
    chord = ["D3", "A3", "D4", "F4"]
    roll = [n("D2", i * 0.05, 0.06, 0.4 + 0.4 * i / 20) for i in range(20)]
    return aac(
        T("timpani", roll + [n("D2", 1.0, 1.0, 1.0)], gain=0.7),
        T("trombone", [n(p, 1.0, 1.0, 0.95) for p in chord], gain=0.5),
        T("trumpet", [n("D5", 1.0, 0.9, 0.95), n("A4", 1.0, 0.9, 0.8)], gain=0.5),
        T("cymbal", [n(49, 1.0, 1.0, 0.8)], gain=0.4, tone={"decay_seconds": 1.2}),
        T("reese_bass", [n("D1", 1.0, 1.0, 0.9)], gain=0.5, tone={"cutoff_hz": 600}),
        fx=[Reverb(decay_seconds=1.2, mix=0.2)],
    )


def s_bills():
    return mix(
        aac(T("bell", [n("C6", 0, 0.12, 0.8)], gain=0.6, tone={"decay_seconds": 0.3}),
            T("tuba", [n("C3", 0.12, 0.15, 0.85), n("B2", 0.27, 0.15, 0.8), n("Bb2", 0.42, 0.35, 0.85)], gain=0.6)),
        noise(0.1, 4000, 2500, q=1.5, gain=0.2, am_hz=40, am_depth=0.8, seed=38),
    )


def s_death():
    return aac(T("theremin", [n("G4", 0, 0.3, 0.8), n("F#4", 0.32, 0.3, 0.8), n("F4", 0.64, 0.3, 0.8), n("E4", 0.96, 0.9, 0.8)],
                 tone={"vibrato_depth_cents": 40, "vibrato_rate_hz": 6}),
               T("tuba", [n("G2", 0, 0.3, 0.6), n("F#2", 0.32, 0.3, 0.6), n("F2", 0.64, 0.3, 0.6), n("E2", 0.96, 0.9, 0.6)], gain=0.5),
               fx=[Reverb(decay_seconds=0.8, mix=0.15)])


def s_revive():
    gliss = ["C5", "E5", "G5", "C6", "E6", "G6", "C7"]
    return aac(T("harp", [n(p, i * 0.035, 0.5, 0.7) for i, p in enumerate(gliss)]),
               T("fm_bell", [n(p, 0.25, 0.5, 0.6) for p in ["C6", "E6", "G6"]], gain=0.45, tone={"decay_seconds": 0.8}),
               T("wavetable_pad", [n("C4", 0, 0.6, 0.5), n("G4", 0, 0.6, 0.4)], gain=0.3,
                 tone={"glide_semitones": 5, "glide_seconds": 0.3}),
               fx=[Reverb(decay_seconds=1.0, mix=0.25)])


def s_heartbeat():
    beat = lambda v: aac(T("kick_808", [n(36, 0, 0.14, v)], tone={"tuning_semitones": -3, "decay_seconds": 0.15}))
    return lowpass(mix(beat(0.9), (0.17, beat(0.7))), 450)  # muffled, like through a chest


def s_escape():
    return aac(
        T("trumpet", [n("G4", 0, 0.1, 0.8), n("C5", 0.11, 0.1, 0.85), n("E5", 0.22, 0.1, 0.85), n("G5", 0.33, 0.55, 0.95)], gain=0.6),
        T("french_horn", [n("C4", 0.33, 0.55, 0.7), n("E4", 0.33, 0.55, 0.7)], gain=0.45),
        T("glockenspiel", [n("C7", 0.33, 0.3, 0.6), n("G7", 0.45, 0.3, 0.5)], gain=0.35),
        T("timpani", [n("C2", 0.33, 0.5, 0.8)], gain=0.5),
        T("cymbal", [n(49, 0.33, 0.5, 0.4)], gain=0.25),
        fx=[Reverb(decay_seconds=1.0, mix=0.2)],
    )


def s_charge():
    # One rung of the charge ladder (the game replays it 10x, each step higher, up to an
    # octave). A buzzy synth note that bends up a little, so it can't be mistaken for the
    # bell-like gem / gold pickups, with a soft tick on top to mark each step.
    return mix(
        tone(0.13, 523.25, 554.37, "square", gain=0.32, attack=0.004, hold=0.07, curve=1.5, vib_hz=18, vib_amt=0.01),
        tone(0.13, 1046.5, 1108.7, "triangle", gain=0.22, attack=0.004, hold=0.07, curve=1.5),
        tone(0.13, 261.63, 277.18, "sine", gain=0.25, attack=0.004, hold=0.07, curve=1.5),
        noise(0.03, 5000, None, q=1.5, gain=0.12, decay=0.008, seed=60),
    )


SOUNDS = {k[2:]: v for k, v in globals().items() if k.startswith("s_") and callable(v)}


def finish(x, peak=0.89):
    x = highpass(x, 35.0)
    a = np.abs(x)
    thr = a.max() * 0.003
    idx = np.nonzero(a > thr)[0]
    x = x[: idx[-1] + int(0.005 * SR)] if len(idx) else x
    x = x[max(0, idx[0] - int(0.001 * SR)):] if len(idx) else x
    fade = min(len(x) // 2, int(0.012 * SR))
    x[-fade:] *= np.linspace(1, 0, fade)
    x[:16] *= np.linspace(0, 1, 16)
    return x / (np.abs(x).max() + 1e-9) * peak


def write(path, x):
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((np.clip(x, -1, 1) * 32767).astype(np.int16).tobytes())


def main(ids):
    os.makedirs(OUT, exist_ok=True)
    for sid in ids or sorted(SOUNDS):
        x = finish(SOUNDS[sid]())
        write(os.path.join(OUT, f"{sid}.wav"), x)
        rms = float(np.sqrt(np.mean(x ** 2)))
        print(f"{sid:10s} {len(x) / SR:5.2f}s rms {rms:.3f}")


if __name__ == "__main__":
    main(sys.argv[1:])
