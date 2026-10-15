"""Menu music: a relaxed night-street groove in F major (the relative major of the run's
D minor), 96 bpm, 16 bars (40 s loop). The kalimba tune opens with the run hook's shape
(D A D F -> F C F A), so the two tracks sound like one game.

A (bars 1-8)  F Am Bb C x2      kalimba tune, electric piano, soft beat
B (bars 9-16) Dm Bb F C Gm Bb C C  tune climbs, vibraphone answers
"""
from common import R, render_loop, steps, track, up

BPM = 96

CH = [["F3", "A3", "C4", "E4"], ["A3", "C4", "E4", "G4"], ["Bb3", "D4", "F4", "A4"], ["C4", "E4", "G4", "Bb4"]] * 2 + \
     [["D3", "F3", "A3", "C4"], ["Bb3", "D4", "F4", "A4"], ["F3", "A3", "C4", "E4"], ["C4", "E4", "G4", "Bb4"],
      ["G3", "Bb3", "D4", "F4"], ["Bb3", "D4", "F4", "A4"], ["C4", "E4", "G4", "Bb4"], ["C4", "E4", "G4", "Bb4"]]
ROOTS = ["F2", "A1", "Bb1", "C2"] * 2 + ["D2", "Bb1", "F2", "C2", "G1", "Bb1", "C2", "C2"]

MEL = [
    "F5", R, "C5", "F5", "A5", R, "G5", "F5",
    "E5", R, R, R, "C5", R, R, R,
    "D5", R, "Bb4", "D5", "F5", R, "E5", "D5",
    "C5", R, R, R, "G4", R, R, R,
    "F5", R, "C5", "F5", "A5", R, "Bb5", "C6",
    "A5", R, "G5", R, "E5", R, "C5", R,
    "D5", R, "F5", R, "Bb5", R, "A5", "G5",
    "G5", R, R, R, "E5", R, R, R,
    "A5", R, "F5", R, "D5", R, "F5", "A5",
    "G5", R, "F5", R, "D5", R, R, R,
    "C6", R, "A5", R, "F5", R, "A5", "C6",
    "Bb5", R, "A5", R, "G5", R, R, R,
    "G5", R, "Bb5", R, "D6", R, "C6", "Bb5",
    "A5", R, "F5", R, "D5", R, "F5", R,
    "E5", R, "G5", R, "C6", R, "Bb5", R,
    "G5", R, "E5", R, "C5", R, R, R,
]
# vibraphone answers in B: a few long notes in the gaps of the tune
VIBES = [(41, "D5"), (45, "F5"), (49, "A5"), (53, "E5"), (57, "F5"), (61, "G5"), (62, "E5")]

parts = []
keys = []
for i, c in enumerate(CH):
    keys += steps([c, R, R, c, R, R, c, R], 0.5, start=i * 4, gate=0.8, vel=0.5)  # 1, 2.5, 4: lazy syncopation
parts.append(track("Keys", "electric_piano", keys, gain=0.4, pan=-0.2, tone={"brightness": 0.4}))

bass = []
for i, r in enumerate(ROOTS):
    fifth = up(r, 7)
    bass += steps([r, R, R, r, fifth, R, up(r, 12), R], 0.5, start=i * 4, gate=0.8, vel=0.75)
parts.append(track("Bass", "bass_guitar", bass, gain=0.55, tone={"brightness": 0.35}))

parts.append(track("Tune", "kalimba", steps(MEL, 0.5, gate=0.9, vel=0.8), gain=0.55, pan=0.15))
parts.append(track("Tune echo", "marimba", steps([up(p, -12) if p else None for p in MEL[64:]], 0.5, start=32, gate=0.8, vel=0.4),
                   gain=0.25, pan=-0.3))
from audio_as_code import Note
parts.append(track("Vibes", "vibraphone", [Note(pitch=p, start=b, duration=min(2.5, 63.9 - b), velocity=0.5) for b, p in VIBES], gain=0.3, pan=0.35))
parts.append(track("Pad", "wavetable_pad", steps([[up(p, -12) for p in c[:3]] for c in CH], 4, gate=0.98, vel=0.3),
                   gain=0.16, tone={"cutoff_hz": 1200}))

kick, clap, shaker = [], [], []
for bar in range(16):
    s = bar * 4
    kick += steps([36, R, R, R, R, R, 36, 36] if bar % 2 else [36, R, R, R, 36, R, R, R], 0.5, start=s, gate=0.3, vel=0.7)
    clap += steps([R, 39, R, 39], 1, start=s, gate=0.2, vel=0.45)
    shaker += steps([(54, 0.25), (54, 0.4)] * 4, 0.5, start=s, gate=0.1)
parts.append(track("Kick", "kick_808", kick, gain=0.55, tone={"decay_seconds": 0.35}))
parts.append(track("Clap", "clap", clap, gain=0.25, pan=0.1))
parts.append(track("Shaker", "tambourine", shaker, gain=0.18, pan=0.3, tone={"decay_seconds": 0.12}))

if __name__ == "__main__":
    from audio_as_code import Reverb
    render_loop("menu", "Mobbed! - Night Street", BPM, 64, parts, fx=[Reverb(decay_seconds=1.4, mix=0.14)])
