#!/usr/bin/env python3
"""Palette + grid check on every PNG in assets/ (the phase 6 gate).

Per file: every opaque pixel is a palette colour, alpha is binary, index 31 (enemy projectile
magenta) is unused (all three via tools/palette_snap.py), and the image is not an upscale (every
pixel an NxN block, N = 2..4, at any offset), which would put it off the game's pixel grid.
assets/palette.png is skipped; launcher icons (assets/icon/) are whole-number upscales on purpose
and only get the palette check.

Usage:  python3 tools/check_assets.py        exits non-zero on any failure
"""
import glob
import os
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import palette_snap  # noqa: E402

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def upscale_factor(path):
    a = np.array(Image.open(path).convert("RGBA")).astype(int)
    for k in (2, 3, 4):
        for ox in range(k):
            for oy in range(k):
                b = a[oy:, ox:]
                h, w = (b.shape[0] // k) * k, (b.shape[1] // k) * k
                # At least 3 blocks a side: in a tiny sprite (a 9x9 pip) one or two blocks of flat
                # fill at some offset would look "upscaled"; a real upscale repeats everywhere.
                if h < 3 * k or w < 3 * k:
                    continue
                b = b[:h, :w].reshape(h // k, k, w // k, k, 4)
                if (b == b[:, :1, :, :1]).all():
                    return k
    return 0


def main():
    palette = palette_snap.load_palette(palette_snap.DEFAULT_PALETTE)
    files = sorted(glob.glob(os.path.join(REPO, "assets", "**", "*.png"), recursive=True))
    failed = 0
    for f in files:
        rel = os.path.relpath(f, REPO)
        if rel == os.path.join("assets", "palette.png"):
            continue
        ok = palette_snap.check_file(f, palette, set(palette_snap.RESERVED))
        k = 0 if rel.startswith(os.path.join("assets", "icon") + os.sep) else upscale_factor(f)
        if k:
            print(f"FAIL {rel}: every pixel is a {k}x{k} block (upscaled, off the pixel grid)")
            ok = False
        failed += not ok
    print(f"{len(files) - 1} assets checked, {failed} failed")
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
