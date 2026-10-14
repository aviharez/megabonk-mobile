#!/usr/bin/env python3
"""Side by side of a game shot (tools/shoot_screens.gd, 540x1170) and its mockup in docs/ui/
(720x1560, scaled to the shot's height), plus a palette scan of the shot.

Usage:  python3 tools/ui_compare.py SHOTS_DIR OUT_DIR shot_name:mockup_name [...]
        python3 tools/ui_compare.py --scan SHOTS_DIR      (palette scan of every PNG in SHOTS_DIR)
The scan counts pixels that are not palette colours; it exits non-zero when any shot has one.
"""
import os
import sys

import numpy as np
from PIL import Image

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def palette():
    p = np.array(Image.open(os.path.join(REPO, "assets", "palette.png")).convert("RGB"))[0]
    return {tuple(int(v) for v in c) for c in p}


def off_palette(path, pal):
    a = np.array(Image.open(path).convert("RGB")).reshape(-1, 3)
    cols, counts = np.unique(a, axis=0, return_counts=True)
    return sum(int(n) for c, n in zip(cols, counts) if tuple(int(v) for v in c) not in pal)


def scan(d):
    pal = palette()
    bad = 0
    for f in sorted(os.listdir(d)):
        if f.endswith(".png"):
            n = off_palette(os.path.join(d, f), pal)
            print(f"{'OK  ' if n == 0 else 'FAIL'} {f}: {n} off-palette pixels")
            bad += n > 0
    return bad


def main():
    if sys.argv[1] == "--scan":
        sys.exit(1 if scan(sys.argv[2]) else 0)
    shots, out = sys.argv[1], sys.argv[2]
    os.makedirs(out, exist_ok=True)
    for pair in sys.argv[3:]:
        s, m = pair.split(":")
        a = Image.open(os.path.join(shots, s + ".png")).convert("RGB")
        b = Image.open(os.path.join(REPO, "docs", "ui", m + ".png")).convert("RGB")
        b = b.resize((round(b.width * a.height / b.height), a.height), Image.LANCZOS)
        c = Image.new("RGB", (a.width + b.width + 12, a.height), (255, 255, 255))
        c.paste(a, (0, 0))
        c.paste(b, (a.width + 12, 0))
        c.save(os.path.join(out, f"{m}_vs.png"))
        print(os.path.join(out, f"{m}_vs.png"))


if __name__ == "__main__":
    main()
