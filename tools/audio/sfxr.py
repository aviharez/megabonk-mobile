#!/usr/bin/env python3
"""sfxr-style sound effect generator: renders tools/audio/sfx.json to WAV.

A port of the synth in Tomas Pettersson's sfxr (square / saw / sine / noise
oscillator, attack-sustain-punch-decay envelope, frequency slide, vibrato,
arpeggio, duty sweep, repeat, phaser, low/high-pass filters), plus its
"preset" generators (pickup, laser, explosion, powerup, hit, jump, blip).

Each sound in sfx.json is {"id", "preset" (optional), "seed", "set": {param:
value}}: the preset is rolled with the seed, then "set" overrides single
parameters. Same file in, same WAVs out.

    python3 tools/audio/sfxr.py                # every sound
    python3 tools/audio/sfxr.py hit kill       # just these
    python3 tools/audio/sfxr.py --list         # ids, length, peak

Output: assets/audio/sfx/<id>.wav, 22050 Hz, 16-bit mono, peak-normalized to
"peak" (default 0.8). Loudness between sounds is set in data/rules/audio.json.
"""
import json
import math
import random
import struct
import sys
import wave
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SPEC = Path(__file__).with_name("sfx.json")
OUT = ROOT / "assets" / "audio" / "sfx"
RATE = 44100  # synth rate; written at RATE / 2
SUPERSAMPLE = 8

DEFAULTS = {
    "wave": 0,  # 0 square, 1 saw, 2 sine, 3 noise
    "base_freq": 0.3, "freq_limit": 0.0, "freq_ramp": 0.0, "freq_dramp": 0.0,
    "duty": 0.0, "duty_ramp": 0.0,
    "vib_strength": 0.0, "vib_speed": 0.0,
    "env_attack": 0.0, "env_sustain": 0.3, "env_punch": 0.0, "env_decay": 0.4,
    "lpf_freq": 1.0, "lpf_ramp": 0.0, "lpf_resonance": 0.0,
    "hpf_freq": 0.0, "hpf_ramp": 0.0,
    "pha_offset": 0.0, "pha_ramp": 0.0,
    "repeat_speed": 0.0,
    "arp_speed": 0.0, "arp_mod": 0.0,
}


# --- Presets (as in sfxr's generator buttons) ---------------------------------

def preset(name, rng):
    p = dict(DEFAULTS)
    rnd = lambda n: rng.randint(0, n)
    frnd = lambda r: rng.random() * r
    if name == "pickup":
        p["base_freq"] = 0.4 + frnd(0.5)
        p["env_sustain"] = frnd(0.1)
        p["env_decay"] = 0.1 + frnd(0.4)
        p["env_punch"] = 0.3 + frnd(0.3)
        if rnd(1):
            p["arp_speed"] = 0.5 + frnd(0.2)
            p["arp_mod"] = 0.2 + frnd(0.4)
    elif name == "laser":
        p["wave"] = rnd(2)
        if p["wave"] == 2 and rnd(1):
            p["wave"] = rnd(1)
        p["base_freq"] = 0.5 + frnd(0.5)
        p["freq_limit"] = max(0.2, p["base_freq"] - 0.2 - frnd(0.6))
        p["freq_ramp"] = -0.15 - frnd(0.2)
        if rnd(2) == 0:
            p["base_freq"] = 0.3 + frnd(0.6)
            p["freq_limit"] = frnd(0.1)
            p["freq_ramp"] = -0.35 - frnd(0.3)
        if rnd(1):
            p["duty"] = frnd(0.5)
            p["duty_ramp"] = frnd(0.2)
        else:
            p["duty"] = 0.4 + frnd(0.5)
            p["duty_ramp"] = -frnd(0.7)
        p["env_sustain"] = 0.1 + frnd(0.2)
        p["env_decay"] = frnd(0.4)
        if rnd(1):
            p["env_punch"] = frnd(0.3)
        if rnd(2) == 0:
            p["pha_offset"] = frnd(0.2)
            p["pha_ramp"] = -frnd(0.2)
        if rnd(1):
            p["hpf_freq"] = frnd(0.3)
    elif name == "explosion":
        p["wave"] = 3
        if rnd(1):
            p["base_freq"] = 0.1 + frnd(0.4)
            p["freq_ramp"] = -0.1 + frnd(0.4)
        else:
            p["base_freq"] = 0.2 + frnd(0.7)
            p["freq_ramp"] = -0.2 - frnd(0.2)
        p["base_freq"] *= p["base_freq"]
        if rnd(4) == 0:
            p["freq_ramp"] = 0.0
        if rnd(2) == 0:
            p["repeat_speed"] = 0.3 + frnd(0.5)
        p["env_sustain"] = 0.1 + frnd(0.3)
        p["env_decay"] = frnd(0.5)
        if rnd(1) == 0:
            p["pha_offset"] = -0.3 + frnd(0.9)
            p["pha_ramp"] = -frnd(0.3)
        p["env_punch"] = 0.2 + frnd(0.6)
        if rnd(1):
            p["vib_strength"] = frnd(0.7)
            p["vib_speed"] = frnd(0.6)
        if rnd(2) == 0:
            p["arp_speed"] = 0.6 + frnd(0.3)
            p["arp_mod"] = 0.8 - frnd(1.6)
    elif name == "powerup":
        if rnd(1):
            p["wave"] = 1
        else:
            p["duty"] = frnd(0.6)
        if rnd(1):
            p["base_freq"] = 0.2 + frnd(0.3)
            p["freq_ramp"] = 0.1 + frnd(0.4)
            p["repeat_speed"] = 0.4 + frnd(0.4)
        else:
            p["base_freq"] = 0.2 + frnd(0.3)
            p["freq_ramp"] = 0.05 + frnd(0.2)
            if rnd(1):
                p["vib_strength"] = frnd(0.7)
                p["vib_speed"] = frnd(0.6)
        p["env_sustain"] = frnd(0.4)
        p["env_decay"] = 0.1 + frnd(0.4)
    elif name == "hit":
        p["wave"] = rnd(2)
        if p["wave"] == 2:
            p["wave"] = 3
        if p["wave"] == 0:
            p["duty"] = frnd(0.6)
        p["base_freq"] = 0.2 + frnd(0.6)
        p["freq_ramp"] = -0.3 - frnd(0.4)
        p["env_sustain"] = frnd(0.1)
        p["env_decay"] = 0.1 + frnd(0.2)
        if rnd(1):
            p["hpf_freq"] = frnd(0.3)
    elif name == "jump":
        p["duty"] = frnd(0.6)
        p["base_freq"] = 0.3 + frnd(0.3)
        p["freq_ramp"] = 0.1 + frnd(0.2)
        p["env_sustain"] = 0.1 + frnd(0.3)
        p["env_decay"] = 0.1 + frnd(0.2)
        if rnd(1):
            p["hpf_freq"] = frnd(0.3)
        if rnd(1):
            p["lpf_freq"] = 1.0 - frnd(0.6)
    elif name == "blip":
        p["wave"] = rnd(1)
        if p["wave"] == 0:
            p["duty"] = frnd(0.6)
        p["base_freq"] = 0.2 + frnd(0.4)
        p["env_sustain"] = 0.1 + frnd(0.1)
        p["env_decay"] = frnd(0.2)
        p["hpf_freq"] = 0.1
    elif name is not None:
        raise SystemExit("unknown preset %r" % name)
    return p


# --- Synth ---------------------------------------------------------------------

def synth(p, seed):
    rng = random.Random(seed ^ 0x5F3759DF)
    st = {}

    def reset(restart):
        if not restart:
            st["phase"] = 0
        st["fperiod"] = 100.0 / (p["base_freq"] ** 2 + 0.001)
        st["fmaxperiod"] = 100.0 / (p["freq_limit"] ** 2 + 0.001)
        st["fslide"] = 1.0 - p["freq_ramp"] ** 3 * 0.01
        st["fdslide"] = -(p["freq_dramp"] ** 3) * 0.000001
        st["duty"] = 0.5 - p["duty"] * 0.5
        st["duty_slide"] = -p["duty_ramp"] * 0.00005
        am = p["arp_mod"]
        st["arp_mod"] = 1.0 - am * am * 0.9 if am >= 0 else 1.0 + am * am * 10.0
        st["arp_time"] = 0
        st["arp_limit"] = 0 if p["arp_speed"] == 1.0 else int((1.0 - p["arp_speed"]) ** 2 * 20000 + 32)
        if not restart:
            st["fltp"] = 0.0
            st["fltdp"] = 0.0
            st["fltw"] = p["lpf_freq"] ** 3 * 0.1
            st["fltw_d"] = 1.0 + p["lpf_ramp"] * 0.0001
            st["fltdmp"] = min(0.8, 5.0 / (1.0 + p["lpf_resonance"] ** 2 * 20.0) * (0.01 + st["fltw"]))
            st["fltphp"] = 0.0
            st["flthp"] = p["hpf_freq"] ** 2 * 0.1
            st["flthp_d"] = 1.0 + p["hpf_ramp"] * 0.0003
            st["vib_phase"] = 0.0
            st["vib_speed"] = p["vib_speed"] ** 2 * 0.01
            st["vib_amp"] = p["vib_strength"] * 0.5
            st["env_vol"] = 0.0
            st["env_stage"] = 0
            st["env_time"] = 0
            st["env_len"] = [max(1, int(p["env_attack"] ** 2 * 100000)),
                             max(1, int(p["env_sustain"] ** 2 * 100000)),
                             max(1, int(p["env_decay"] ** 2 * 100000))]
            fph = p["pha_offset"] ** 2 * 1020.0
            st["fphase"] = -fph if p["pha_offset"] < 0 else fph
            fdph = p["pha_ramp"] ** 2
            st["fdphase"] = -fdph if p["pha_ramp"] < 0 else fdph
            st["ipp"] = 0
            st["pbuf"] = [0.0] * 1024
            st["noise"] = [rng.uniform(-1, 1) for _ in range(32)]
            st["rep_time"] = 0
            st["rep_limit"] = 0 if p["repeat_speed"] == 0 else int((1.0 - p["repeat_speed"]) ** 2 * 20000 + 32)

    reset(False)
    out = []
    playing = True
    two_pi = 2.0 * math.pi
    wave_type = int(p["wave"])
    lpf_on = p["lpf_freq"] != 1.0
    while playing and len(out) < RATE * 4:
        st["rep_time"] += 1
        if st["rep_limit"] and st["rep_time"] >= st["rep_limit"]:
            st["rep_time"] = 0
            reset(True)
        st["arp_time"] += 1
        if st["arp_limit"] and st["arp_time"] >= st["arp_limit"]:
            st["arp_limit"] = 0
            st["fperiod"] *= st["arp_mod"]
        st["fslide"] += st["fdslide"]
        st["fperiod"] *= st["fslide"]
        if st["fperiod"] > st["fmaxperiod"]:
            st["fperiod"] = st["fmaxperiod"]
            if p["freq_limit"] > 0:
                playing = False
        rf = st["fperiod"]
        if st["vib_amp"] > 0:
            st["vib_phase"] += st["vib_speed"]
            rf = st["fperiod"] * (1.0 + math.sin(st["vib_phase"]) * st["vib_amp"])
        period = max(8, int(rf))
        st["duty"] = min(0.5, max(0.0, st["duty"] + st["duty_slide"]))
        st["env_time"] += 1
        stage = st["env_stage"]
        if st["env_time"] > st["env_len"][stage]:
            st["env_time"] = 0
            st["env_stage"] += 1
            stage = st["env_stage"]
            if stage == 3:
                break
        et = st["env_time"]
        if stage == 0:
            env = et / st["env_len"][0]
        elif stage == 1:
            env = 1.0 + (1.0 - et / st["env_len"][1]) * 2.0 * p["env_punch"]
        else:
            env = 1.0 - et / st["env_len"][2]
        st["fphase"] += st["fdphase"]
        iphase = min(1023, abs(int(st["fphase"])))
        if st["flthp_d"] != 1.0:
            st["flthp"] = min(0.1, max(0.00001, st["flthp"] * st["flthp_d"]))
        ss = 0.0
        for _ in range(SUPERSAMPLE):
            st["phase"] += 1
            if st["phase"] >= period:
                st["phase"] %= period
                if wave_type == 3:
                    st["noise"] = [rng.uniform(-1, 1) for _ in range(32)]
            fp = st["phase"] / period
            if wave_type == 0:
                s = 0.5 if fp < st["duty"] else -0.5
            elif wave_type == 1:
                s = 1.0 - fp * 2.0
            elif wave_type == 2:
                s = math.sin(fp * two_pi)
            else:
                s = st["noise"][st["phase"] * 32 // period]
            pp = st["fltp"]
            st["fltw"] = min(0.1, max(0.0, st["fltw"] * st["fltw_d"]))
            if lpf_on:
                st["fltdp"] += (s - st["fltp"]) * st["fltw"]
                st["fltdp"] -= st["fltdp"] * st["fltdmp"]
            else:
                st["fltp"] = s
                st["fltdp"] = 0.0
            st["fltp"] += st["fltdp"]
            st["fltphp"] += st["fltp"] - pp
            st["fltphp"] -= st["fltphp"] * st["flthp"]
            s = st["fltphp"]
            ipp = st["ipp"]
            st["pbuf"][ipp & 1023] = s
            s += st["pbuf"][(ipp - iphase + 1024) & 1023]
            st["ipp"] = (ipp + 1) & 1023
            ss += s * env
        out.append(ss / SUPERSAMPLE)
    # Down to RATE / 2 by averaging pairs.
    half = [(out[i] + out[i + 1]) * 0.5 for i in range(0, len(out) - 1, 2)]
    return half


def render(entry):
    seed = int(entry.get("seed", 0))
    p = preset(entry.get("preset"), random.Random(seed))
    for k, v in entry.get("set", {}).items():
        if k not in DEFAULTS:
            raise SystemExit("%s: unknown parameter %r" % (entry["id"], k))
        p[k] = v
    samples = synth(p, seed)
    peak = max((abs(s) for s in samples), default=0.0)
    gain = float(entry.get("peak", 0.8)) / peak if peak > 0 else 0.0
    # 4 ms fade at both ends: no clicks from a hard start or stop.
    fade = int(RATE / 2 * 0.004)
    n = len(samples)
    for i in range(min(fade, n)):
        f = i / fade
        samples[i] *= f
        samples[n - 1 - i] *= f
    return [max(-1.0, min(1.0, s * gain)) for s in samples]


def write_wav(path, samples):
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE // 2)
        w.writeframes(b"".join(struct.pack("<h", int(s * 32767)) for s in samples))


def main(argv):
    spec = json.loads(SPEC.read_text())
    sounds = spec["sounds"]
    ids = [a for a in argv if not a.startswith("--")]
    listing = "--list" in argv
    known = {s["id"] for s in sounds}
    for i in ids:
        if i not in known:
            raise SystemExit("no sound %r in %s" % (i, SPEC.name))
    for s in sounds:
        if ids and s["id"] not in ids:
            continue
        samples = render(s)
        if not samples or max(abs(x) for x in samples) < 0.05:
            raise SystemExit("%s: silent result, check its parameters" % s["id"])
        dur = len(samples) / (RATE / 2)
        if not listing:
            write_wav(OUT / (s["id"] + ".wav"), samples)
        print("%-12s %5.2f s  %s" % (s["id"], dur, s.get("note", "")))


if __name__ == "__main__":
    main(sys.argv[1:])
