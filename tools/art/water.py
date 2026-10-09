#!/usr/bin/env python3
"""Build the pool, lily pad and reed sprites from the SpriteCook water sheet (asset id in
docs/spritecook-assets.json, "props_sheet_water"). Usage: python3 tools/art/water.py RAW/water.png

The sheet is 2x2: pool, pond (style reference only: the pond is drawn in code in the same layers,
since ponds come in many sizes), lily pads, reeds. Cells are cut and snapped at native size.

The pool becomes a 9-slice template (map "prop_art" "slice": [left, top, right, bottom]): one clean
copy of rim columns 6-13 is inserted after column 13, and of rows 8-12 after row 12, with the
water's sparkles removed. The middle column/row then tiles on the rim's 4px rhythm, and the
sparkles and ladder stay in the corners, so they show once at any pool size.
"""
import os
import subprocess
import sys
import tempfile

import numpy as np
from PIL import Image

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..")
P = os.path.join(ROOT, "assets", "props")
SLICE = (14, 13, 14, 11)  # keep in sync with data/maps/suburbia.json prop_art.pool.slice
COLS = (6, 14)  # source columns copied into the middle
ROWS = (8, 13)  # source rows copied into the middle
BLUE = (0x3A, 0x9A, 0xD9, 255)
SKY = (0x7E, 0xD4, 0xF0, 255)


def main():
    raw = sys.argv[1]
    with tempfile.TemporaryDirectory() as tmp:
        cells = [os.path.join(tmp, n + ".png") for n in ("pool", "pond", "lily", "reeds")]
        subprocess.run([sys.executable, os.path.join(ROOT, "tools/icon_shrink.py"), "--tight", raw, "--grid", "2",
                        "--size", "34", "--out", *cells], check=True, stdout=subprocess.DEVNULL)
        pool = np.array(Image.open(cells[0]).convert("RGBA"))
        Image.open(cells[2]).save(os.path.join(P, "lily.png"))
        Image.open(cells[3]).save(os.path.join(P, "reeds.png"))

    h, w, _ = pool.shape
    # Water pixels between the rims: sparkles (SKY) become plain water in the copied middle.
    def clean(a, water_rows, water_cols):
        a = a.copy()
        sub = a[water_rows[0]:water_rows[1], water_cols[0]:water_cols[1]]
        sub[(sub == SKY).all(axis=-1)] = BLUE
        return a

    mid_cols = clean(pool[:, COLS[0]:COLS[1]], (6, h - 5), (0, COLS[1] - COLS[0]))
    wide = np.concatenate([pool[:, :COLS[1]], mid_cols, pool[:, COLS[1]:]], axis=1)
    mid_rows = clean(wide[ROWS[0]:ROWS[1]], (0, ROWS[1] - ROWS[0]), (4, wide.shape[1] - 4))
    tall = np.concatenate([wide[:ROWS[1]], mid_rows, wide[ROWS[1]:]], axis=0)
    out = Image.fromarray(tall)
    out.save(os.path.join(P, "pool.png"))
    l, t, r, b = SLICE
    assert l + r == out.width - (COLS[1] - COLS[0]) and t + b == out.height - (ROWS[1] - ROWS[0]), "SLICE out of date"
    print(f"pool.png {out.size} slice {SLICE}; lily.png, reeds.png")


if __name__ == "__main__":
    main()
