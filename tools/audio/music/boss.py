"""Boss / Final Swarm music: same D minor world, heavier and faster. 164 bpm, 32 bars (46.8 s loop).

A  (bars 1-8)   Dm Dm Bb C Dm Dm Eb A     chromatic riff (D Eb D C) on a distorted lead,
                                          reese bass with a flat-two kick, four on the floor
A2 (bars 9-16)  A again                   trumpets double the riff, toms on the turnarounds
B  (bars 17-24) Gm Eb Bb A x2             big horn melody in half time over the drums
B2 (bars 25-32) B again                   16th arpeggios on top, timpani, back into A
"""
from audio_as_code import Distortion
from common import R, line, midi, name, render_loop, steps, track, up

BPM = 164

A_ROOTS = ["D2", "D2", "Bb1", "C2", "D2", "D2", "Eb2", "A1"]
B_ROOTS = ["G1", "Eb2", "Bb1", "A1"] * 2
ROOTS = A_ROOTS * 2 + B_ROOTS * 2
CH = {"D": ["D3", "F3", "A3"], "Bb": ["Bb2", "D3", "F3"], "C": ["C3", "E3", "G3"], "Eb": ["Eb3", "G3", "Bb3"],
      "A": ["A2", "C#3", "E3"], "G": ["G2", "Bb2", "D3"]}
CHORDS = [CH[r[:-1]] for r in ROOTS]

RIFF = [
    "D5", R, "D5", "Eb5", "D5", R, "C5", R,
    "D5", R, "F5", R, "E5", R, "C#5", R,
    "D5", R, "Bb4", R, "F5", R, "D5", R,
    "E5", R, "C5", R, "G5", R, "E5", R,
    "A5", R, "A5", "Bb5", "A5", R, "G5", R,
    "F5", R, "E5", R, "D5", R, "C#5", R,
    "Eb5", R, "G5", R, "Bb5", R, "G5", R,
    "A5", R, R, R, "C#5", R, "E5", R,
]
HORN = [  # (pitch, beats) per 4 bars, twice
    ("G4", 2), ("Bb4", 1), ("D5", 1), ("Eb5", 2), ("D5", 1), ("C5", 1),
    ("D5", 2), ("F5", 1), ("D5", 1), ("C#5", 2), ("E5", 1), ("A4", 1),
    ("G4", 2), ("Bb4", 1), ("D5", 1), ("G5", 2), ("F5", 1), ("Eb5", 1),
    ("F5", 2), ("D5", 1), ("Bb4", 1), ("A4", 4),
]

parts = []

bass = []
for i, r in enumerate(ROOTS):
    m = midi(r)
    bar = [m, m, m + 12, m, m + 1, m, m - 1, m] if i < 16 else [m, R, m, m, m + 12, R, m, m]
    bass += steps([name(x) if isinstance(x, int) else x for x in bar], 0.5, start=i * 4, gate=0.75, vel=0.9)
parts.append(track("Bass", "reese_bass", bass, gain=0.55, tone={"cutoff_hz": 900, "detune_cents": 18}))
parts.append(track("Sub", "sub_bass", steps([r for r in ROOTS], 4, gate=0.95, vel=0.7), gain=0.35))

lead = steps(RIFF * 2, 0.5, gate=0.75, vel=0.8)
parts.append(track("Lead", "sync_lead", lead, gain=0.34, pan=0.1, tone={"cutoff_hz": 3500},
                   fx=[Distortion(drive=2.5, mix=0.35)]))
parts.append(track("Trumpets", "trumpet", steps([up(p, -12) if p else None for p in RIFF], 0.5, start=32, gate=0.6, vel=0.75),
                   gain=0.35, pan=-0.2))

stabs = []
for i, c in enumerate(CHORDS[:16]):
    stabs += steps([c, R, R, c, R, R, c, R], 0.5, start=i * 4, gate=0.3, vel=0.6)
parts.append(track("Stabs", "supersaw", stabs, gain=0.22, pan=-0.25, tone={"cutoff_hz": 2500}))

horn = line(HORN * 2, start=64, gate=0.95, vel=0.85)
parts.append(track("Horns", "french_horn", horn, gain=0.55, pan=-0.1))
parts.append(track("Trombone", "trombone", [n.model_copy(update={"pitch": up(n.pitch, -12)}) for n in horn], gain=0.4, pan=0.15))
parts.append(track("Strings", "string_machine", steps([[up(p, 12) for p in c] for c in CHORDS[16:]], 4, start=64, gate=0.98, vel=0.4),
                   gain=0.2, tone={"cutoff_hz": 3000}))

arp = []
for i, c in enumerate(CHORDS[24:]):
    a, b, cc = [up(p, 24) for p in c]
    arp += steps([a, b, cc, b] * 4, 0.25, start=96 + i * 4, gate=0.5, vel=0.5)
parts.append(track("Arp", "trance_pluck", arp, gain=0.25, pan=0.35))

kick, snare, hat, toms, timp, crash = [], [], [], [], [], []
for bar in range(32):
    s = bar * 4
    half = 16 <= bar < 32
    kick += steps([36, R, 36, R, 36, R, 36, 36] if not half else [36, R, R, 36, R, R, 36, R], 0.5, start=s, gate=0.3, vel=0.95)
    snare += steps([R, 38, R, 38] if not half else [R, R, 38, R], 1, start=s, gate=0.25, vel=0.8)
    hat += steps([(42, 0.45), (42, 0.3), (42, 0.55), (42, 0.3)] * 4, 0.25, start=s, gate=0.1)
    if bar in (7, 15, 23, 31):
        toms += steps([45, 45, 45, 45, 45, 45, 45, 45], 0.25, start=s + 2, gate=0.4, vel=0.8)
    if bar in (0, 8, 16, 24):
        crash += steps([49], 1, start=s, vel=0.7)
        timp += steps(["D2" if bar < 16 else "G1"], 1, start=s, vel=0.9)
    if bar >= 24 and bar % 2 == 0:
        timp += steps([ROOTS[bar]], 1, start=s + 2, vel=0.6)
parts.append(track("Kick", "kick_909", kick, gain=0.85))
parts.append(track("Snare", "electronic_snare", snare, gain=0.55))
parts.append(track("Hat", "metal_hat", hat, gain=0.22, pan=0.25))
parts.append(track("Toms", "toms", toms, gain=0.5))
parts.append(track("Crash", "cymbal", crash, gain=0.3))
parts.append(track("Timpani", "timpani", timp, gain=0.5))

if __name__ == "__main__":
    render_loop("boss", "Mobbed! - Mega Mole", BPM, 128, parts)
