"""Victory music (escaped through the portal or survived the Final Swarm): a bright brass
march in F major, 124 bpm, 12 bars (23.2 s loop).
F Bb C F | Dm Bb Gm C | F Bb C C
"""
from audio_as_code import Reverb
from common import R, line, render_loop, steps, track, up

BPM = 124
CH = [["F3", "A3", "C4"], ["Bb3", "D4", "F4"], ["C4", "E4", "G4"], ["F3", "A3", "C4"],
      ["D3", "F3", "A3"], ["Bb3", "D4", "F4"], ["G3", "Bb3", "D4"], ["C4", "E4", "G4"],
      ["F3", "A3", "C4"], ["Bb3", "D4", "F4"], ["C4", "E4", "G4"], ["C4", "E4", "G4"]]
ROOTS = ["F2", "Bb1", "C2", "F2", "D2", "Bb1", "G1", "C2", "F2", "Bb1", "C2", "C2"]
TUNE = [
    ("C5", 0.5), ("F5", 0.5), ("A5", 1), ("G5", 0.5), ("F5", 0.5), ("A5", 1),
    ("Bb5", 1.5), ("A5", 0.5), ("G5", 1), ("F5", 1),
    ("E5", 1), ("G5", 1), ("C6", 1.5), ("Bb5", 0.5),
    ("A5", 3), (R, 1),
    ("F5", 0.5), ("A5", 0.5), ("D6", 1), ("C6", 0.5), ("A5", 0.5), ("F5", 1),
    ("D5", 1), ("F5", 1), ("Bb5", 2),
    ("Bb5", 1), ("A5", 1), ("G5", 1), ("F5", 0.5), ("G5", 0.5),
    ("E5", 2), ("G5", 1), ("C5", 1),
    ("C5", 0.5), ("F5", 0.5), ("A5", 1), ("C6", 1), ("A5", 1),
    ("D6", 1.5), ("C6", 0.5), ("Bb5", 1), ("A5", 1),
    ("G5", 1), ("A5", 0.5), ("Bb5", 0.5), ("C6", 1), ("E5", 1),
    ("G5", 2), (R, 2),
]

tune = line(TUNE, gate=0.85, vel=0.85)
parts = [
    track("Trumpet", "trumpet", tune, gain=0.5, pan=0.1),
    track("Glock", "glockenspiel", [n.model_copy(update={"pitch": up(n.pitch, 12), "velocity": 0.35}) for n in tune], gain=0.22, pan=0.3),
    track("Horns", "french_horn", steps([c[1:] for c in CH], 4, gate=0.95, vel=0.55), gain=0.35, pan=-0.2),
]
bass, keys = [], []
for i, r in enumerate(ROOTS):
    bass += steps([r, R, up(r, 7), R, r, R, up(r, 7), R], 0.5, start=i * 4, gate=0.6, vel=0.8)
    keys += steps([R, CH[i], R, CH[i]], 1, start=i * 4, gate=0.4, vel=0.5)
parts.append(track("Tuba", "tuba", bass, gain=0.45))
parts.append(track("Keys", "clavinet", keys, gain=0.25, pan=-0.3))

kick, snare, tamb = [], [], []
for bar in range(12):
    s = bar * 4
    kick += steps([36, R, 36, R], 1, start=s, gate=0.3, vel=0.8)
    snare += steps([R, 38, R, 38], 1, start=s, gate=0.3, vel=0.6) if bar != 11 else \
        steps([(38, 0.4 + 0.035 * k) for k in range(16)], 0.25, start=s, gate=0.5)
    tamb += steps([54] * 8, 0.5, start=s, gate=0.1, vel=0.35)
parts.append(track("Kick", "kick", kick, gain=0.6))
parts.append(track("Snare", "snare", snare, gain=0.4))
parts.append(track("Tambourine", "tambourine", tamb, gain=0.2, pan=0.3))
parts.append(track("Cymbal", "cymbal", steps([49], 1, start=0, vel=0.5), gain=0.25))

if __name__ == "__main__":
    render_loop("victory", "Mobbed! - Made It Out", BPM, 48, parts, fx=[Reverb(decay_seconds=1.2, mix=0.15)])
