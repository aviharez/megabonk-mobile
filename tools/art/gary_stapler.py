#!/usr/bin/env python3
"""Gary: clean face without dark red, stapler kept red.

The palette's dark red (index 7) turns Gary's eye-bag shading into what looks like a bloody eye,
so his sheets are shrunk with --exclude 7. That also turns the red stapler brown. This takes both
shrinks of the same SpriteCook sheet and copies the red pixels (palette 7, 8, 9) back from the
with-red version, only below the head (lower part of each frame), where the stapler is held.

Usage: python3 tools/art/gary_stapler.py WITH_RED.png NO_RED.png OUT.png [--below 0.5]
Both inputs must come from tools/spritecook_shrink.py with the same --scale (same frame layout).
"""
import argparse
import json
import os
import shutil
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
import palette_snap as ps  # noqa: E402

RED = (7, 8, 9)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("with_red")
    ap.add_argument("no_red")
    ap.add_argument("out")
    ap.add_argument("--below", type=float, default=0.5, help="only rows below this fraction of the frame height")
    args = ap.parse_args()
    pal = ps.load_palette(ps.DEFAULT_PALETTE)
    a = np.array(Image.open(args.with_red).convert("RGBA"))
    b = np.array(Image.open(args.no_red).convert("RGBA"))
    if a.shape != b.shape:
        raise SystemExit(f"layouts differ: {a.shape} vs {b.shape}")
    reds = np.zeros(a.shape[:2], bool)
    for i in RED:
        reds |= (a[..., 3] == 255) & (a[..., :3] == pal[i]).all(-1)
    reds[: int(a.shape[0] * args.below)] = False
    out = b.copy()
    out[reds] = a[reds]
    Image.fromarray(out).save(args.out)
    meta = json.load(open(ps.sidecar_path(args.no_red)))
    meta["source"]["sheet"] = os.path.basename(args.out)
    meta["source"]["hand_edit"] = "tools/art/gary_stapler.py"
    with open(ps.sidecar_path(args.out), "w") as fp:
        json.dump(meta, fp, indent=2)
        fp.write("\n")
    problems, ncol = ps.verify(args.out, pal, set(), meta)
    if problems:
        raise SystemExit("; ".join(problems))
    print(f"OK   {args.out}: {int(reds.sum())} stapler pixels restored, {ncol} palette colours")


if __name__ == "__main__":
    main()
