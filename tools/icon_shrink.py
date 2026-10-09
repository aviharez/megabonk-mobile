#!/usr/bin/env python3
"""Shrink a SpriteCook icon to a square game icon, snapped to the palette.

Snaps the source to assets/palette.png (same CIELAB snap as tools/spritecook_shrink.py), crops it
to its content, shrinks it by keeping the dominant colour of each source block so the longer side
fits SIZE (or one sample per block with --method nearest), and centres it on a transparent SIZE x SIZE canvas.

With --grid N the source is an N x N sheet of icons: it is cut into equal cells (row by row) and
each cell becomes one icon, so --out takes one path per cell (use - to skip a cell).

Usage:
  python3 tools/icon_shrink.py ICON.png --out assets/icons/weapons/baguette.png [--size 16] \
        [--exclude 7] [--preview 8]
  python3 tools/icon_shrink.py SHEET.png --grid 2 --out a.png b.png c.png d.png
"""
import argparse
import os
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import palette_snap as ps  # noqa: E402
from spritecook_shrink import shrink_mode, snap  # noqa: E402


def cells(im, grid):
    w, h = im.size
    return [im.crop((c * w // grid, r * h // grid, (c + 1) * w // grid, (r + 1) * h // grid))
            for r in range(grid) for c in range(grid)]


def make_icon(im, pal, allowed, size, method="mode"):
    a = snap(im, pal, allowed)
    ys, xs = np.nonzero(a[..., 3])
    if len(ys) == 0:
        raise SystemExit("icon has no opaque pixels")
    a = a[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
    h, w = a.shape[:2]
    k = min(1.0, size / max(w, h))
    nw, nh = max(1, round(w * k)), max(1, round(h * k))
    if k >= 1.0:
        small = a
    elif method == "nearest":
        small = np.array(Image.fromarray(a).resize((nw, nh), Image.NEAREST))
    else:
        small = shrink_mode(a, nw, nh)
    out = np.zeros((size, size, 4), np.uint8)
    x0, y0 = (size - nw) // 2, (size - nh) // 2
    out[y0:y0 + nh, x0:x0 + nw] = small
    return out


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("icon", help="SpriteCook PNG with one icon, or an N x N sheet with --grid N")
    ap.add_argument("--out", required=True, nargs="+", help="one path per icon; - skips a cell")
    ap.add_argument("--grid", type=int, default=1)
    ap.add_argument("--size", type=int, default=16)
    ap.add_argument("--method", choices=["mode", "nearest"], default="mode",
                    help="mode: dominant colour per block (keeps outlines); nearest: one sample per block "
                         "(keeps small details like a logo)")
    ap.add_argument("--palette", default=ps.DEFAULT_PALETTE)
    ap.add_argument("--exclude", default="", help="extra palette indices to never use (31 is always excluded)")
    ap.add_argument("--tight", action="store_true",
                    help="crop the result to its content instead of a SIZE x SIZE canvas (map props stand on "
                         "their bottom edge)")
    ap.add_argument("--preview", type=int, default=0, metavar="SCALE")
    args = ap.parse_args()

    pal = ps.load_palette(args.palette)
    allowed = ps.allowed_indices(pal, ps.parse_indices(args.exclude))
    parts = cells(Image.open(args.icon), args.grid)
    if len(args.out) != len(parts):
        raise SystemExit(f"--grid {args.grid} has {len(parts)} cells, got {len(args.out)} --out paths")
    for part, path in zip(parts, args.out):
        if path == "-":
            continue
        out = make_icon(part, pal, allowed, args.size, args.method)
        if args.tight:
            ys, xs = np.nonzero(out[..., 3])
            out = out[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
        os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
        Image.fromarray(out).save(path)
        if args.preview:
            p = args.preview
            Image.fromarray(out).resize((args.size * p, args.size * p), Image.NEAREST).save(
                os.path.splitext(path)[0] + "_preview.png")
        print(f"{path}: {out.shape[1]}x{out.shape[0]}")


if __name__ == "__main__":
    main()
