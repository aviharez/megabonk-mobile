"""In-run music: an upbeat, slightly goofy D minor chase. 150 bpm, 32 bars (51.2 s loop).

A  (bars 1-8)   Dm Bb F C x2          main hook on the sync lead (owner-approved test loop)
B  (bars 9-16)  Gm Bb Dm A x2         lead answers, xylophone arpeggios join
A2 (bars 17-24) A again               hook doubled by xylophone an octave up, busier stabs
C  (bars 25-32) Bb C Am Dm Gm Bb A A  breakdown: marimba call and response, drums thin out,
                                      then a snare roll that throws the loop back to A
"""
from common import R, line, render_loop, steps, track, up

BPM = 150

A_CH = [["D3", "F3", "A3"], ["Bb2", "D3", "F3"], ["F3", "A3", "C4"], ["C3", "E3", "G3"]] * 2
B_CH = [["G2", "Bb2", "D3"], ["Bb2", "D3", "F3"], ["D3", "F3", "A3"], ["A2", "C#3", "E3"]] * 2
C_CH = [["Bb2", "D3", "F3"], ["C3", "E3", "G3"], ["A2", "C3", "E3"], ["D3", "F3", "A3"],
        ["G2", "Bb2", "D3"], ["Bb2", "D3", "F3"], ["A2", "C#3", "E3"], ["A2", "C#3", "E3"]]
CHORDS = A_CH + B_CH + A_CH + C_CH
ROOTS = ["D2", "Bb1", "F2", "C2"] * 2 + ["G1", "Bb1", "D2", "A1"] * 2 + ["D2", "Bb1", "F2", "C2"] * 2 + \
        ["Bb1", "C2", "A1", "D2", "G1", "Bb1", "A1", "A1"]

MEL_A = [
    "D5", R, "A4", "D5", "F5", R, "E5", "D5",
    "D5", R, "F5", R, "Bb4", R, R, R,
    "C5", R, "A4", "C5", "F5", R, "E5", "C5",
    "E5", R, "G5", R, "E5", "D5", "C5", R,
    "D5", R, "A4", "D5", "F5", R, "G5", "A5",
    "Bb5", R, "A5", "G5", "F5", R, "D5", R,
    "A5", R, "G5", "F5", "C5", R, "F5", R,
    "E5", "F5", "G5", R, "C5", R, R, R,
]
MEL_B = [
    "G5", R, "D5", R, "Bb4", R, "D5", "G5",
    "F5", R, "D5", R, "Bb4", "C5", "D5", R,
    "A5", R, "F5", R, "D5", R, "F5", "A5",
    "G5", R, "E5", R, "C#5", R, "A4", R,
    "Bb4", "C5", "D5", R, "G5", R, "F5", "G5",
    "F5", "E5", "D5", R, "F5", R, "Bb5", R,
    "A5", R, "F5", "D5", "A5", R, "F5", "D5",
    "C#5", "D5", "E5", R, "A4", R, R, R,
]
HOOK_C = [
    "D5", R, "F5", R, "D5", "C5", "Bb4", R,
    "E5", R, "G5", R, "E5", "D5", "C5", R,
    "C5", R, "E5", R, "A5", "G5", "E5", R,
    "D5", R, "F5", "A5", "D6", R, R, R,
    "Bb4", R, "D5", "G5", "Bb5", R, "A5", "G5",
    "F5", R, "D5", "Bb4", "F5", R, "D5", R,
    "E5", R, "C#5", R, "A4", R, "C#5", "E5",
    "A5", R, "G5", R, "E5", R, "C#5", R,
]

parts = []

# bass: bouncy root / octave eighths; in C the first four bars only hit on the beat
bass = []
for i, r in enumerate(ROOTS):
    o = up(r, 12)
    bar = [r, R, o, r, R, r, o, R] if not (24 <= i < 28) else [r, R, R, R, o, R, R, R]
    bass += steps(bar, 0.5, start=i * 4, gate=0.6, vel=0.85)
parts.append(track("Bass", "fm_bass", bass, gain=0.6))

# offbeat clavinet stabs (busier in A2: also on the beat before the snare)
stabs = []
for i, c in enumerate(CHORDS):
    if 24 <= i < 28:
        continue
    pat = [R, c] * 4 if not (16 <= i < 24) else [R, c, R, c, R, c, c, c]
    stabs += steps(pat, 0.5, start=i * 4, gate=0.35, vel=0.6)
parts.append(track("Stabs", "clavinet", stabs, gain=0.32, pan=-0.3))

parts.append(track("Pad", "string_machine",
                   steps([[up(p, 12) for p in c] for c in CHORDS], 4, gate=0.98, vel=0.35), gain=0.18, pan=0.2))

lead = steps(MEL_A + MEL_B + MEL_A, 0.5, gate=0.7, vel=0.75)
parts.append(track("Lead", "sync_lead", lead, gain=0.38, pan=0.1))

# xylophone: arpeggios in B, hook doubled an octave up in A2
xylo = []
for i, c in enumerate(B_CH):
    a, b, cc = [up(p, 24) for p in c]
    xylo += steps([a, b, cc, b], 1, start=32 + i * 4, gate=0.4, vel=0.5)
xylo += steps([up(p, 12) if p else None for p in MEL_A], 0.5, start=64, gate=0.5, vel=0.45)
parts.append(track("Xylo", "xylophone", xylo, gain=0.3, pan=0.35))

parts.append(track("Marimba", "marimba", steps(HOOK_C, 0.5, start=96, gate=0.6, vel=0.8), gain=0.55, pan=-0.15))
parts.append(track("Kalimba", "kalimba", steps([up(p, 12) if p else None for p in HOOK_C[32:]], 0.5, start=112, gate=0.6, vel=0.5),
                   gain=0.3, pan=0.3))

# drums
kick, snare, hat, fill = [], [], [], []
for bar in range(32):
    s = bar * 4
    if 24 <= bar < 28:
        kick += steps([36], 1, start=s, vel=0.9)
        hat += steps([42] * 8, 0.5, start=s, gate=0.12, vel=0.3)
        continue
    kick += steps([36, R, R, 36, R, R, 36, R], 0.5, start=s, gate=0.3, vel=0.95)
    if bar == 31:  # snare roll back into A
        snare += steps([(38, 0.35 + 0.04 * k) for k in range(16)], 0.25, start=s, gate=0.5)
        continue
    snare += steps([R, 38, R, 38], 1, start=s, gate=0.25, vel=0.75)
    hat += steps([42, 42, 42, 54] * 2, 0.5, start=s, gate=0.12, vel=0.4)
    if bar in (7, 15, 23):
        fill += steps([45, 45, 45, 45, 38, 38, 38, 38], 0.25, start=s + 2, gate=0.2, vel=0.7)
parts.append(track("Kick", "kick_909", kick, gain=0.8))
parts.append(track("Snare", "electronic_snare", snare, gain=0.5))
parts.append(track("Hat", "drum_machine", hat, gain=0.25, pan=0.25))
parts.append(track("Fill", "drum_machine", fill, gain=0.45))
parts.append(track("Crash", "cymbal", steps([49], 1, start=0, vel=0.5) + steps([49], 1, start=64, vel=0.5), gain=0.25))

if __name__ == "__main__":
    render_loop("gameplay", "Mobbed! - Swarm Chase", BPM, 128, parts)
