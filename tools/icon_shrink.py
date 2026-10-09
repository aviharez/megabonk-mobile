#!/usr/bin/env python3
"""Shrink a SpriteCook icon to a square game icon, snapped to the palette.

Snaps the source to assets/palette.png (same CIELAB snap as tools/spritecook_shrink.py), crops it
to its content, shrinks it by keeping the dominant colour of each source block so the longer side
fits SIZE, and centres it on a transparent SIZE x SIZE canvas.

Usage:
  python3 tools/icon_shrink.py ICON.png --out assets/icons/weapons/baguette.png [--size 16] \
        [--exclude 7] [--preview 8]
"""
import argparse
import os
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import palette_snap as ps  # noqa: E402
from spritecook_shrink import shrink_mode, snap  # noqa: E402


def make_icon(src, pal, allowed, size):
    a = snap(Image.open(src), pal, allowed)
    ys, xs = np.nonzero(a[..., 3])
    if len(ys) == 0:
        raise SystemExit(f"{src}: no opaque pixels")
    a = a[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
    h, w = a.shape[:2]
    k = min(1.0, size / max(w, h))
    nw, nh = max(1, round(w * k)), max(1, round(h * k))
    small = shrink_mode(a, nw, nh) if k < 1.0 else a
    out = np.zeros((size, size, 4), np.uint8)
    x0, y0 = (size - nw) // 2, (size - nh) // 2
    out[y0:y0 + nh, x0:x0 + nw] = small
    return out


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("icon", help="SpriteCook PNG with one icon")
    ap.add_argument("--out", required=True)
    ap.add_argument("--size", type=int, default=16)
    ap.add_argument("--palette", default=ps.DEFAULT_PALETTE)
    ap.add_argument("--exclude", default="", help="extra palette indices to never use (31 is always excluded)")
    ap.add_argument("--preview", type=int, default=0, metavar="SCALE")
    args = ap.parse_args()

    pal = ps.load_palette(args.palette)
    allowed = ps.allowed_indices(pal, ps.parse_indices(args.exclude))
    out = make_icon(args.icon, pal, allowed, args.size)
    os.makedirs(os.path.dirname(os.path.abspath(args.out)), exist_ok=True)
    Image.fromarray(out).save(args.out)
    if args.preview:
        p = args.preview
        Image.fromarray(out).resize((args.size * p, args.size * p), Image.NEAREST).save(
            os.path.splitext(args.out)[0] + "_preview.png")
    print(f"{args.out}: {args.size}x{args.size}")


if __name__ == "__main__":
    main()
