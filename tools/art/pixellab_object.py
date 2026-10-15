#!/usr/bin/env python3
"""Turn a PixelLab map object (64x64 raw PNG) into a game sprite.

Crops the raw image to its opaque pixels, makes alpha binary and snaps every colour to the 31 world
colours (palette indices 32+ are the UI night tones and stay out of world art). --force maps
near-identical shades onto one palette colour (PixelLab often splits a wall across BUTTER / DOUGH /
PAPER, which looks blotchy). --list prints each raw colour, its pixel count and where it snaps.

Usage:
  python3 tools/art/pixellab_object.py RAW.png --out assets/town/x.png
        [--force "247,238,181=PAPER;242,238,167=PAPER"] [--list]
"""

import argparse
import os
import sys
from collections import Counter

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
import palette_snap as ps  # noqa: E402

NAMES = ("INK NIGHT SHADE GRAY MIST PAPER WHITE WINE BLOOD RED SALMON RUST ORANGE GOLD BUTTER "
         "DEEP_GREEN LEAF GREEN LIME DEEP_BLUE OCEAN BLUE SKY TEAL PLUM PURPLE BARK WOOD CRUST DOUGH PINK").split()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("raw")
    ap.add_argument("--out")
    ap.add_argument("--force", default="")
    ap.add_argument("--list", action="store_true")
    args = ap.parse_args()

    pal = ps.load_palette(ps.DEFAULT_PALETTE)
    allowed = ps.allowed_indices(pal, set(range(32, len(pal))))
    im = Image.open(args.raw).convert("RGBA")
    a = np.array(im.crop(im.getbbox()))
    mask = a[..., 3] >= 128
    rgb = a[mask][:, :3]
    snapped = ps.snap_colors(rgb, pal, allowed)

    force = {}
    for part in filter(None, args.force.split(";")):
        src, name = part.split("=")
        force[tuple(int(v) for v in src.split(","))] = pal[NAMES.index(name.strip())][:3]
    for i, c in enumerate(map(tuple, rgb)):
        if c in force:
            snapped[i] = force[c]

    if args.list:
        index = {tuple(pal[i][:3]): NAMES[i] for i in range(len(NAMES))}
        snap_of = {}
        for c, s in zip(map(tuple, rgb), map(tuple, snapped)):
            snap_of[c] = index[s]
        for c, n in Counter(map(tuple, rgb)).most_common():
            print(f"{c} {n:4d} -> {snap_of[c]}")

    if args.out:
        out = np.zeros_like(a)
        out[mask, :3] = snapped
        out[mask, 3] = 255
        Image.fromarray(out).save(args.out)
        print(f"{args.out}: {out.shape[1]}x{out.shape[0]}, "
              f"{len(np.unique(snapped, axis=0))} colours")


if __name__ == "__main__":
    main()
