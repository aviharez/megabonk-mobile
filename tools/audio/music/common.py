"""Shared helpers for the music scores (Audio as Code, https://audioascode.com, MIT).

Every track is a seamless loop: the score is written three times in a row, rendered once,
and the middle copy is cut out, so the reverb and release tails of the copy before it
fall into the start of the loop exactly as they do when Godot loops the OGG.
"""
from __future__ import annotations

import os
import subprocess
import tempfile
import wave

import hashlib
import json

import numpy as np
import pyloudnorm
from scipy.ndimage import minimum_filter1d, uniform_filter1d

from audio_as_code import Note, Song, Tone, Track, render_audio

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
OUT = os.path.join(ROOT, "assets", "audio", "music")
SR = 44100
TARGET_LUFS = -16.0  # data/rules/audio.json "music_db" sets the in-game level on top of this
R = None  # rest


def midi(p):
    if isinstance(p, int):
        return p
    names = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}
    k = names[p[0]]
    i = 1
    while i < len(p) and p[i] in "#b":
        k += 1 if p[i] == "#" else -1
        i += 1
    return k + 12 * (int(p[i:]) + 1)


def name(m):
    return ["C", "C#", "D", "Eb", "E", "F", "F#", "G", "Ab", "A", "Bb", "B"][m % 12] + str(m // 12 - 1)


def up(p, semis):
    return name(midi(p) + semis)


def line(spec, start=0.0, gate=0.9, vel=0.8):
    """spec: [(pitch or None or [chord], beats, optional velocity), ...] -> notes from `start`."""
    notes, t = [], start
    for item in spec:
        p, d = item[0], item[1]
        v = item[2] if len(item) > 2 else vel
        if p is not None:
            for q in (p if isinstance(p, list) else [p]):
                notes.append(Note(pitch=q, start=t, duration=d * gate, velocity=v))
        t += d
    return notes


def steps(seq, step=0.5, start=0.0, gate=0.7, vel=0.8):
    """Even grid: seq items are pitch / chord list / None / (pitch, velocity)."""
    notes = []
    for i, p in enumerate(seq):
        v = vel
        if isinstance(p, tuple):
            p, v = p
        if p is None:
            continue
        for q in (p if isinstance(p, list) else [p]):
            notes.append(Note(pitch=q, start=start + i * step, duration=step * gate, velocity=v))
    return notes


def track(name, inst, notes, gain=0.6, pan=0.0, tone=None, fx=()):
    return dict(name=name, instrument=inst, gain=gain, pan=pan, notes=notes,
                tone=Tone(**tone) if tone else None, effects=tuple(fx))


def limit(x, ceiling, look_ms=5.0):
    """Look-ahead peak limiter: smooth gain that never lets a sample pass the ceiling.
    The loop is padded with its own other end so the gain is seamless across the loop point."""
    L = max(1, int(look_ms / 1000 * SR))
    pad = 4 * L
    y = np.concatenate([x[-pad:], x, x[:pad]])
    need = np.minimum(1.0, ceiling / np.maximum(np.abs(y).max(axis=1), 1e-9))
    g = minimum_filter1d(need, size=2 * L + 1)
    g = uniform_filter1d(g, size=L)
    return (y * g[:, None])[pad:-pad]


def render_loop(track_id, title, bpm, beats, parts, fx=(), seed=11):
    """parts: track dicts whose notes cover one loop (0..beats). Writes <OUT>/<track_id>.ogg."""
    tracks = []
    for t in parts:
        notes = []
        for k in range(3):
            notes += [n.model_copy(update={"start": n.start + k * beats}) for n in t["notes"]]
        tracks.append(Track(**{**t, "notes": tuple(notes)}))
    song = Song(title=title, bpm=bpm, beats=beats * 3, seed=seed, sample_rate=SR,
                tracks=tuple(tracks), effects=tuple(fx))
    key = hashlib.sha1(json.dumps(song.model_dump(mode="json"), sort_keys=True).encode()).hexdigest()[:16]
    cache = os.path.join(tempfile.gettempdir(), "mobbed_music_cache", f"{track_id}_{key}.npy")
    if os.path.exists(cache):
        audio = np.load(cache)
    else:
        audio = render_audio(song, normalize=False).audio.astype(np.float64)
        os.makedirs(os.path.dirname(cache), exist_ok=True)
        np.save(cache, audio)
    spb = 60.0 / bpm
    a, b = round(beats * spb * SR), round(2 * beats * spb * SR)
    loop = audio[a:b]
    meter = pyloudnorm.Meter(SR)
    lufs = meter.integrated_loudness(np.tile(loop, (2, 1)))
    loop *= 10 ** ((TARGET_LUFS - lufs) / 20)
    loop = limit(loop, 0.89)
    final_lufs = meter.integrated_loudness(np.tile(loop, (2, 1)))
    seam = float(np.abs(loop[0] - loop[-1]).max())
    os.makedirs(OUT, exist_ok=True)
    with tempfile.TemporaryDirectory() as tmp:
        wav = os.path.join(tmp, "loop.wav")
        with wave.open(wav, "wb") as w:
            w.setnchannels(2)
            w.setsampwidth(2)
            w.setframerate(SR)
            w.writeframes((np.clip(loop, -1, 1) * 32767).astype(np.int16).tobytes())
        dest = os.path.join(OUT, f"{track_id}.ogg")
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav, "-c:a", "libvorbis", "-q:a", "5", dest], check=True)
    print(f"{track_id:10s} {len(loop) / SR:5.1f}s  {final_lufs:6.1f} LUFS  peak {20 * np.log10(np.abs(loop).max()):5.1f} dBFS  seam {seam:.4f}")
    return dest
