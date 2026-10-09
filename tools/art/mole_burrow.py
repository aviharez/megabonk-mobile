#!/usr/bin/env python3
"""Mega Mole burrow clip, built from his own sprite (SpriteCook's burrow didn't dig).

Takes frame 0 of a shrunk sheet (the walk) and makes N frames where he sinks into the ground:
each frame moves him down by DEPTHS[i] pixels, cuts everything below the ground line (his
feet), and draws a dirt mound across the hole. Played forwards to dig down, backwards to pop up.

Usage: python3 tools/art/mole_burrow.py WALK.png OUT.png
"""
import json
import os
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
import palette_snap as ps  # noqa: E402

DEPTHS = [6, 14, 22, 30]
DIRT = (0, 26, 27, 28)  # outline, dark brown, brown, light brown (palette indices)


def mound(fw, ground, half, pal):
    """A low dithered dirt mound, `half` px each side of the centre, sitting on the ground line."""
    m = np.zeros((ground + 2, fw, 4), np.uint8)
    cx = fw // 2
    for dy, w in ((0, half), (-1, half - 1), (-2, half - 3), (-3, half - 6)):
        y = ground + dy
        for x in range(cx - w, cx + w + 1):
            edge = x in (cx - w, cx + w) or dy == -3
            c = DIRT[0] if edge else DIRT[1 + (x + y) % 3]
            m[y, x, :3] = pal[c]
            m[y, x, 3] = 255
    return m


def main():
    src, dst = sys.argv[1], sys.argv[2]
    meta = json.load(open(ps.sidecar_path(src)))
    pal = ps.load_palette(ps.DEFAULT_PALETTE)
    a = np.array(Image.open(src).convert("RGBA"))
    fw, fh = meta["frame_w"], meta["frame_h"]
    base = a[:, :fw]
    ground = meta["origin"][1]
    cols = np.where(base[..., 3].any(0))[0]
    half = (cols.max() - cols.min()) // 2 + 2
    n = len(DEPTHS)
    out = np.zeros((fh, fw * n, 4), np.uint8)
    for i, d in enumerate(DEPTHS):
        f = np.zeros_like(base)
        f[d:ground + 1] = base[: ground + 1 - d]
        m = mound(fw, ground, min(half, fw // 2 - 1), pal)
        on = m[..., 3] > 0
        f[: ground + 2][on] = m[on]
        out[:, i * fw:(i + 1) * fw] = f
    Image.fromarray(out).save(dst)
    meta.update({"frames": n})
    meta["source"]["sheet"] = os.path.basename(dst)
    meta["source"]["hand_edit"] = "tools/art/mole_burrow.py (sinking frames from frame 0)"
    with open(ps.sidecar_path(dst), "w") as fp:
        json.dump(meta, fp, indent=2)
        fp.write("\n")
    problems, ncol = ps.verify(dst, pal, set(), meta)
    if problems:
        raise SystemExit("; ".join(problems))
    print(f"OK   {dst}: {n} frames {fw}x{fh}, {ncol} palette colours")


if __name__ == "__main__":
    main()
