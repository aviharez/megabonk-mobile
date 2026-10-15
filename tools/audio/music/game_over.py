"""Game over music (lost runs): a small, sad-but-cute music box in D minor. 78 bpm,
8 bars (24.6 s loop), no drums, so the result screen feels calm after the death sting.
Dm Bb Gm A | Dm F Gm A
"""
from audio_as_code import Reverb
from common import R, line, render_loop, steps, track, up

BPM = 78
CH = [["D3", "F3", "A3"], ["Bb2", "D3", "F3"], ["G2", "Bb2", "D3"], ["A2", "C#3", "E3"],
      ["D3", "F3", "A3"], ["F3", "A3", "C4"], ["G2", "Bb2", "D3"], ["A2", "C#3", "E3"]]
TUNE = [
    ("A5", 1), ("F5", 1), ("D5", 1), ("E5", 0.5), ("F5", 0.5),
    ("D5", 2), (R, 1), ("C5", 0.5), ("D5", 0.5),
    ("Bb4", 1), ("D5", 1), ("G5", 1), ("F5", 1),
    ("E5", 3), (R, 1),
    ("A5", 1), ("F5", 1), ("D5", 1), ("A4", 1),
    ("C5", 1), ("F5", 1), ("A5", 2),
    ("G5", 1), ("F5", 1), ("E5", 1), ("D5", 0.5), ("E5", 0.5),
    ("C#5", 2), ("A4", 1.9),
]

parts = [
    track("Music box", "celesta", line(TUNE, gate=0.95, vel=0.7), gain=0.55, pan=0.1),
    track("Glock", "glockenspiel", line([(up(p, 12) if p else None, d) for p, d in TUNE[15:]], start=16, gate=0.9, vel=0.3),
          gain=0.2, pan=0.3),
    track("Pad", "wavetable_pad", steps([[up(p, 12) for p in c] for c in CH], 4, gate=0.98, vel=0.35), gain=0.22,
          tone={"cutoff_hz": 1400}),
]
harp = []
for i, c in enumerate(CH):
    a, b, cc = c
    harp += steps([a, b, cc, up(a, 12), cc, b, a, b], 0.5, start=i * 4, gate=0.9, vel=0.45)
parts.append(track("Harp", "harp", harp, gain=0.4, pan=-0.2))
parts.append(track("Bass", "double_bass", steps([up(c[0], -12) for c in CH], 4, gate=0.95, vel=0.5), gain=0.35))

if __name__ == "__main__":
    render_loop("game_over", "Mobbed! - Swarmed", BPM, 32, parts, fx=[Reverb(decay_seconds=2.0, mix=0.22)])
