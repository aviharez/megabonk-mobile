#!/usr/bin/env python3
"""Shrink a SpriteCook sprite or animation sheet to game size, snapped to the palette.

SpriteCook returns pixel art bigger than the game uses (34-76 px) and with off-palette colours.
This script snaps every frame to assets/palette.png (CIELAB, binary alpha, magenta never used),
shrinks all frames by ONE factor (so motion keeps its proportions), keeps the dominant colour of
each source block (keeps outlines; averaging turns them to mush), optionally redraws a knight
visor that shrinking blurs, and writes a game sheet plus sidecar JSON in the same format as
tools/palette_snap.py:

  {"format": "game.sheet", "frame_w": W, "frame_h": H, "frames": N, "fps": F,
   "origin": [x, y], "source": {...}}

Frames are one horizontal row with a 1px transparent border; origin is the feet (bottom centre).

Usage:
  python3 tools/spritecook_shrink.py SHEET.png --frames 4 --scale 0.788 --fps 8 \
        --out assets/characters/sir_loaf_idle.png [--visor] [--asset-id ID] [--preview 8]
"""
import argparse
import json
import os
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import palette_snap as ps  # noqa: E402

HELMET = (0, 2, 3, 4, 19, 20, 21)  # palette indices that belong to the helmet
GREY = (3, 4)


def snap(im, pal, allowed):
    a = np.array(im.convert("RGBA"))
    op = a[..., 3] >= 128
    out = np.zeros_like(a)
    if op.any():
        out[op, :3] = ps.snap_colors(a[op][:, :3], pal, allowed)
        out[op, 3] = 255
    return out


def shrink_mode(a, w, h):
    """Dominant colour per source block; a block is transparent when less than half is opaque."""
    H, W = a.shape[:2]
    out = np.zeros((h, w, 4), np.uint8)
    for y in range(h):
        for x in range(w):
            ys, ye = y * H // h, max((y + 1) * H // h, y * H // h + 1)
            xs, xe = x * W // w, max((x + 1) * W // w, x * W // w + 1)
            blk = a[ys:ye, xs:xe].reshape(-1, 4)
            vis = blk[blk[:, 3] > 0]
            if len(vis) * 2 < len(blk):
                continue
            cols, cnt = np.unique(vis, axis=0, return_counts=True)
            out[y, x] = cols[cnt.argmax()]
    return out


def index_map(a, pal):
    lut = {tuple(c): i for i, c in enumerate(pal)}
    return np.array([[lut.get(tuple(p[:3]), -1) if p[3] else -1 for p in row] for row in a])


def find_visor(ii):
    """(row, left, right) of the visor brim in source pixels: the first row with a run of >= 6
    grey pixels, widened left over helmet colours until the bread starts. None if not found."""
    H, W = ii.shape
    for y in range(H):
        run = 0
        for x in range(W):
            run = run + 1 if ii[y, x] in GREY else 0
            if run >= 6:
                xr = x
                while xr + 1 < W and ii[y, xr + 1] in GREY:
                    xr += 1
                xl = x - 5
                while xl - 1 >= 0 and ii[y, xl - 1] in HELMET:
                    xl -= 1
                if ii[y, xl] == 0:
                    xl += 1
                return y, xl, xr
    return None


def draw_visor(out, pal, y0, x0, x1):
    """Clean grille: dark line, light brim, two rows of bars, lower plate, chin outline."""
    h, w = out.shape[:2]

    def put(y, x, c):
        if 0 <= y < h and 0 <= x < w:
            out[y, x, :3] = pal[c]
            out[y, x, 3] = 255

    for x in range(x0, x1 + 1):
        put(y0 - 1, x, 0)
        put(y0, x, 4)
        put(y0 + 3, x, 3)
    for y in (y0 + 1, y0 + 2):
        for x in range(x0, x1 + 1):
            put(y, x, 3 if x in (x0, x1) else (4 if (x - x0) % 2 == 0 else 0))
    put(y0 + 3, x0 - 1, 0)
    for x in range(x0 + 1, x1):
        put(y0 + 4, x, 3)
        put(y0 + 5, x, 0)
    put(y0 + 4, x0, 0)
    put(y0 + 4, x1, 0)
    for y in range(y0 - 1, y0 + 5):
        put(y, x1 + 1, 0)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("sheet", help="SpriteCook PNG: one frame, or N frames in one row")
    ap.add_argument("--frames", type=int, default=1)
    ap.add_argument("--scale", type=float, required=True, help="shrink factor, same for every clip of a character")
    ap.add_argument("--fps", type=float, default=8)
    ap.add_argument("--out", required=True)
    ap.add_argument("--visor", action="store_true", help="redraw the knight visor on every frame")
    ap.add_argument("--asset-id", default="", help="SpriteCook asset id, stored in the sidecar")
    ap.add_argument("--palette", default=ps.DEFAULT_PALETTE)
    ap.add_argument("--preview", type=int, default=0, metavar="SCALE")
    args = ap.parse_args()

    pal = ps.load_palette(args.palette)
    allowed = ps.allowed_indices(pal, set())
    src = Image.open(args.sheet).convert("RGBA")
    fw_src = src.width // args.frames
    small = []
    for i in range(args.frames):
        a = snap(src.crop((i * fw_src, 0, (i + 1) * fw_src, src.height)), pal, allowed)
        w, h = round(fw_src * args.scale), round(src.height * args.scale)
        out = shrink_mode(a, w, h)
        if args.visor:
            v = find_visor(index_map(a, pal))
            if v is None:
                raise SystemExit(f"frame {i}: no visor brim found")
            y, xl, xr = v
            draw_visor(out, pal, round(y * args.scale), round(xl * args.scale) + 1, round(xr * args.scale))
        small.append(out)

    # One crop box for all frames keeps the motion; 1px transparent border around each frame.
    boxes = [Image.fromarray(f).getbbox() for f in small]
    if any(b is None for b in boxes):
        raise SystemExit("a frame is empty after shrinking")
    L, T = min(b[0] for b in boxes), min(b[1] for b in boxes)
    R, B = max(b[2] for b in boxes), max(b[3] for b in boxes)
    fw, fh = R - L + 2, B - T + 2
    sheet = Image.new("RGBA", (fw * args.frames, fh))
    for i, f in enumerate(small):
        sheet.alpha_composite(Image.fromarray(f).crop((L, T, R, B)), (i * fw + 1, 1))
    os.makedirs(os.path.dirname(os.path.abspath(args.out)), exist_ok=True)
    sheet.save(args.out)
    meta = {
        "format": "game.sheet", "frame_w": fw, "frame_h": fh, "frames": args.frames, "fps": args.fps,
        "origin": [fw // 2, fh - 2],
        "source": {"generator": "SpriteCook", "asset_id": args.asset_id, "scale": args.scale,
                   "sheet": os.path.basename(args.out)},
    }
    side = ps.sidecar_path(args.out)
    with open(side, "w") as fh_:
        json.dump(meta, fh_, indent=2)
        fh_.write("\n")
    problems, ncol = ps.verify(args.out, pal, set(), meta)
    if problems:
        raise SystemExit(f"{args.out}: " + "; ".join(problems))
    print(f"OK   {args.out}: {args.frames} frames {fw}x{fh}, {ncol} palette colours, sidecar {side}")
    if args.preview:
        bg = Image.new("RGBA", sheet.size, (58, 52, 70, 255))
        bg.alpha_composite(sheet)
        bg.resize((sheet.width * args.preview, sheet.height * args.preview), Image.NEAREST).save(
            os.path.splitext(args.out)[0] + "_preview.png")


if __name__ == "__main__":
    main()
