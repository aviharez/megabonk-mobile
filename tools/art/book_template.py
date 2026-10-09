#!/usr/bin/env python3
"""Make assets/icons/book.png, the 16x16 book that tome icons are built from (ContentIcon / Icons).

Shrinks the SpriteCook book (asset ea139f59, see docs/spritecook-assets.json) with
tools/icon_shrink.py, then clears the blank label that shrinking broke into stray GRAY / SHADE
pixels: between the first and last MIST pixel of each cover row, everything becomes MIST (and a
stray GRAY pixel under the book goes). In game
the cover colours (MIST light, SHADE dark) are swapped per tome and a 5x5 symbol goes on the cover.

Usage: python3 tools/art/book_template.py RAW_BOOK.png [--out assets/icons/book.png]
"""
import argparse
import os
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
import palette_snap as ps  # noqa: E402
from icon_shrink import make_icon  # noqa: E402

SHADE, GRAY, MIST = 2, 3, 4
COVER_ROWS = range(1, 11)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("book")
    ap.add_argument("--out", default="assets/icons/book.png")
    args = ap.parse_args()
    pal = ps.load_palette(ps.DEFAULT_PALETTE)
    a = make_icon(Image.open(args.book), pal, ps.allowed_indices(pal, set()), 16)
    for y in COVER_ROWS:
        idx = [x for x in range(16) if a[y, x, 3] and tuple(a[y, x, :3]) == tuple(pal[MIST])]
        if not idx:
            continue
        for x in range(idx[0], idx[-1] + 1):
            if tuple(a[y, x, :3]) in (tuple(pal[GRAY]), tuple(pal[SHADE])):
                a[y, x, :3] = pal[MIST]
    a[14:, :][np.all(a[14:, :, :3] == pal[GRAY], axis=-1)] = 0  # a stray pixel under the book
    Image.fromarray(a).save(args.out)
    print(args.out)


if __name__ == "__main__":
    main()
