#!/usr/bin/env python3
"""Placeholder chiptune: renders the three music tracks to OGG.

Four channels like an old console: two pulse waves (lead, harmony arpeggio),
a stepped triangle (bass) and noise drums (kick is a short pitched sweep).
Each song is a chord progression plus seeded melody phrases, so a re-render
gives the same file. The note tails that run past the end are wrapped round
to the start, so the loop point is seamless. Placeholder only: the brief
says these get replaced by licensed music later (same file names).

    python3 tools/audio/chiptune.py            # all three
    python3 tools/audio/chiptune.py boss       # one

Needs numpy and ffmpeg (libvorbis). Output: assets/audio/music/<id>.ogg
"""
import random
import subprocess
import sys
import tempfile
import wave
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets" / "audio" / "music"
RATE = 32000

MAJOR = [0, 2, 4, 5, 7, 9, 11]
MINOR = [0, 2, 3, 5, 7, 8, 10]
PHRYGIAN = [0, 1, 3, 5, 7, 8, 10]

# Chords are (root offset from the key, "maj" / "min" / "dim" / "pow").
SONGS = {
    "menu": {
        "bpm": 104, "key": 60, "scale": MAJOR, "seed": 3, "swing": 0.12,
        "duty": 0.25, "lead_oct": 12, "bass": "bounce", "drums": "light", "arp": "up",
        "chords": [(0, "maj"), (9, "min"), (5, "maj"), (7, "maj"),
                   (0, "maj"), (9, "min"), (2, "min"), (7, "maj")] * 2,
    },
    "gameplay": {
        "bpm": 138, "key": 57, "scale": MINOR, "seed": 11, "swing": 0.0,
        "duty": 0.5, "lead_oct": 12, "bass": "drive", "drums": "rock", "arp": "updown",
        "chords": [(0, "min"), (8, "maj"), (3, "maj"), (10, "maj"),
                   (0, "min"), (8, "maj"), (5, "min"), (7, "maj")] * 3,
    },
    "boss": {
        "bpm": 164, "key": 52, "scale": PHRYGIAN, "seed": 23, "swing": 0.0,
        "duty": 0.125, "lead_oct": 12, "bass": "gallop", "drums": "double", "arp": "down",
        "chords": [(0, "pow"), (1, "maj"), (0, "pow"), (10, "maj"),
                   (0, "pow"), (1, "maj"), (3, "maj"), (1, "maj")] * 3,
    },
}

TRIADS = {"maj": [0, 4, 7], "min": [0, 3, 7], "dim": [0, 3, 6], "pow": [0, 7, 12]}
MIX = {"lead": 0.20, "harm": 0.08, "bass": 0.30, "drums": 0.32}


def freq(m):
    return 440.0 * 2.0 ** ((m - 69) / 12.0)


def env(n, attack=0.004, decay=0.12, sustain=0.55, release=0.02):
    t = np.arange(n) / RATE
    e = np.where(t < attack, t / attack, sustain + (1 - sustain) * np.exp(-(t - attack) / decay))
    r = int(release * RATE)
    if n > r > 0:
        e[-r:] *= np.linspace(1, 0, r)
    return e


def pulse(m, n, duty):
    ph = (np.arange(n) * freq(m) / RATE) % 1.0
    return np.where(ph < duty, 1.0, -1.0)


def triangle(m, n):
    ph = (np.arange(n) * freq(m) / RATE) % 1.0
    tri = 4.0 * np.abs(ph - 0.5) - 1.0
    return np.round(tri * 7.5) / 7.5  # 16 steps, like the console's


def noise(n, rng, period=1):
    v = rng.uniform(-1, 1, n // period + 1)
    return np.repeat(v, period)[:n]


def kick(n):
    t = np.arange(n) / RATE
    f = 40 + 110 * np.exp(-t * 35)
    ph = np.cumsum(f) / RATE
    return np.sin(2 * np.pi * ph) * np.exp(-t * 18)


class Track:
    def __init__(self, length):
        self.buf = {k: np.zeros(length + RATE * 2) for k in MIX}
        self.length = length

    def add(self, ch, start, wave_):
        self.buf[ch][start:start + len(wave_)] += wave_

    def mix(self):
        out = sum(self.buf[k] * MIX[k] for k in MIX)
        # Tails past the loop end wrap round to the start.
        tail = out[self.length:]
        out = out[:self.length].copy()
        out[:len(tail)] += tail[:self.length]
        return out / max(1e-6, np.max(np.abs(out))) * 0.85


def scale_notes(key, scale, lo, hi):
    return [m for m in range(lo, hi + 1) if (m - key) % 12 in scale]


def phrase(rng, chords, key, scale, octave):
    """A melody over len(chords) bars: list of (bar, step16, length16, midi)."""
    notes = []
    pool = scale_notes(key, scale, key + octave - 3, key + octave + 12)
    rhythms = [[0, 4, 8, 12], [0, 6, 8, 12, 14], [0, 3, 6, 8, 12], [0, 2, 4, 8, 10, 12], [0, 8, 10, 12]]
    motif = rng.choice(rhythms)
    prev = key + octave
    for b, (root, kind) in enumerate(chords):
        tones = [key + root + i for i in TRIADS[kind]]
        rhythm = motif if b % 2 == 0 else rng.choice(rhythms)
        for i, s in enumerate(rhythm):
            length = (rhythm[i + 1] if i + 1 < len(rhythm) else 16) - s
            if s % 8 == 0:
                # Strong beats: the chord tone nearest the last note.
                cands = [t + 12 * o for t in tones for o in range(-1, 3)]
                cands = [c for c in cands if pool[0] <= c <= pool[-1]]
                m = min(cands, key=lambda c: abs(c - prev) + rng.random() * 3)
            else:
                idx = min(range(len(pool)), key=lambda j: abs(pool[j] - prev))
                idx = max(0, min(len(pool) - 1, idx + rng.choice([-2, -1, 1, 1, 2])))
                m = pool[idx]
            if rng.random() < 0.08 and s != 0:
                continue  # a rest now and then
            notes.append((b, s, length, m))
            prev = m
    return notes


def render(name, song):
    rng = random.Random(song["seed"])
    nrng = np.random.default_rng(song["seed"])
    step = 60.0 / song["bpm"] / 4.0  # one 16th
    bars = len(song["chords"])
    length = int(round(bars * 16 * step * RATE))
    tr = Track(length)
    key = song["key"]

    def at(bar, s):
        sw = song["swing"] * step if s % 2 == 1 else 0.0
        return int(round(((bar * 16 + s) * step + sw) * RATE))

    def dur(n16):
        return max(1, int(n16 * step * RATE))

    # Melody: 4-bar phrases A A' B A over the progression.
    chords = song["chords"]
    a = phrase(rng, chords[:4], key, song["scale"], song["lead_oct"])
    b = phrase(rng, chords[4:8], key, song["scale"], song["lead_oct"])
    for blk in range(0, bars, 4):
        src = b if (blk // 4) % 4 == 2 else a
        for (bar, s, l, m) in src:
            m2 = m
            if (blk // 4) % 4 == 1 and rng.random() < 0.25:
                m2 = m + rng.choice([-2, 2, 3])  # A' varies a few notes
            n = dur(l) - int(0.01 * RATE)
            tr.add("lead", at(blk + bar, s), pulse(m2, n, song["duty"]) * env(n, decay=0.18, sustain=0.5))

    for bar, (root, kind) in enumerate(chords):
        tones = [key + root + i for i in TRIADS[kind]]
        # Harmony: 16th arpeggio an octave below the lead.
        arp = tones + [tones[0] + 12]
        if song["arp"] == "down":
            arp = arp[::-1]
        elif song["arp"] == "updown":
            arp = arp + arp[-2:0:-1]
        for s in range(16):
            n = dur(1)
            tr.add("harm", at(bar, s), pulse(arp[s % len(arp)], n, 0.5) * env(n, decay=0.05, sustain=0.3))
        # Bass.
        b0 = key + root - 24 if key + root - 24 >= 33 else key + root - 12
        pat = {
            "bounce": [(0, 4, b0), (4, 2, b0 + 7), (8, 4, b0), (12, 2, b0 + 7), (14, 2, b0 + 12)],
            "drive": [(s, 2, b0 + (12 if s in (6, 14) else 0)) for s in range(0, 16, 2)],
            "gallop": [(s + o, 1 if o < 2 else 2, b0) for s in range(0, 16, 4) for o in (0, 1, 2)],
        }[song["bass"]]
        for s, l, m in pat:
            n = dur(l) - int(0.008 * RATE)
            tr.add("bass", at(bar, s), triangle(m, n) * env(n, decay=0.3, sustain=0.8))
        # Drums.
        kit = song["drums"]
        kicks = {"light": [0, 8], "rock": [0, 6, 8], "double": [0, 2, 4, 6, 8, 10, 12, 14]}[kit]
        snares = {"light": [12], "rock": [4, 12], "double": [4, 12]}[kit]
        hats = {"light": [4, 8, 14], "rock": list(range(0, 16, 2)), "double": list(range(0, 16, 2))}[kit]
        for s in kicks:
            tr.add("drums", at(bar, s), kick(int(0.12 * RATE)) * 0.9)
        for s in snares:
            n = int(0.13 * RATE)
            tr.add("drums", at(bar, s), noise(n, nrng, 2) * np.exp(-np.arange(n) / RATE * 28) * 0.6)
        for s in hats:
            n = int(0.03 * RATE)
            tr.add("drums", at(bar, s), noise(n, nrng, 1) * np.exp(-np.arange(n) / RATE * 120) * 0.25)
        if bar % 4 == 3:
            # Fill on the phrase's last beat.
            for s in (13, 14, 15):
                n = int(0.06 * RATE)
                tr.add("drums", at(bar, s), noise(n, nrng, 3) * np.exp(-np.arange(n) / RATE * 40) * 0.45)

    return tr.mix(), length / RATE


def write_ogg(name, samples):
    OUT.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory() as tmp:
        wav = Path(tmp) / (name + ".wav")
        with wave.open(str(wav), "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(RATE)
            w.writeframes((np.clip(samples, -1, 1) * 32767).astype("<i2").tobytes())
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", str(wav), "-c:a", "libvorbis", "-q:a", "3",
                        "-map_metadata", "-1", str(OUT / (name + ".ogg"))], check=True)


def main(argv):
    names = argv or list(SONGS)
    for n in names:
        if n not in SONGS:
            raise SystemExit("no song %r (have %s)" % (n, ", ".join(SONGS)))
        samples, secs = render(n, SONGS[n])
        write_ogg(n, samples)
        size = (OUT / (n + ".ogg")).stat().st_size
        print("%-9s %5.1f s  %4d KB" % (n, secs, size // 1024))


if __name__ == "__main__":
    main(sys.argv[1:])
