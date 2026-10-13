#!/usr/bin/env python3
"""Cut the Phase 9 home screen art (SpriteCook) into assets/ui/home/, snapped to the palette.

    python3 tools/art/home_art.py RAW_DIR [--out assets/ui/home] [--preview DIR]

RAW_DIR holds the downloaded SpriteCook images (asset ids in docs/spritecook-assets.json):
  backdrop_px.png   "home_backdrop"   152x272 night street (edit of the first backdrop: no sign, no
                                      name plate, no UI / hero)
  logo_deco.png     "logo_deco"       68x68 2x2 sheet: leaf sprigs x3, radish critter
  critters.png      "home_critters"   100x100 2x2 sheet: blue, green, purple, red critters
  kit3_sheet1.png   "ui_kit3_sheet1"  kit 3 component sheet (nav icons cut again at a 2x pixel)

The home screen draws sprites (hero, critters, nav icons, logo decorations) at 2x over the 1x
backdrop and kit frames, as the concept does. So sprites are cut at half size here: the 2x2
sheets shrink by 2, and the sack / padlock / mystery icons come off the kit 3 sheet at 22-28
source px per art px instead of kit 3's 16.

The backdrop is very dark and sits between the palette's dark steps, so a plain snap flattens it
(the sky turns to one INK / NIGHT field). It is snapped with its CIELAB lightness lifted by LIFT
first, which keeps the lit windows, stone plinth and the purple glow behind the houses.
Its sky (rows above SKY_ROWS) still snaps to INK with a noisy INK / NIGHT edge; the concept's sky
is night blue-purple all the way up, so INK there becomes NIGHT (the stars and moon stay).

It is then widened and heightened so any phone shape shows only art: 20 px more each side, in
bands (SIDES): sky rows copy a starry stretch of the same rows from inside the picture (mirroring
would double the moon), the left house rows copy the houses behind the lamp post (it stands at
x 0), and the road rows are mirrored. Above and below go bands of sky and of road, repeated from
the top and bottom rows with every other copy flipped. backdrop.json gives the plinth top centre
in the extended image, so the game can stand the hero on it. The art has no sign, plate or
other text container: the home screen shows no names over the scene.
"""
import argparse
import json
import os
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import palette_snap as ps  # noqa: E402
from spritecook_shrink import shrink_mode, snap  # noqa: E402
from ui_kit import CUTOFF3, PARTS3, cut, grid, trim  # noqa: E402

SIDE = 20  # extra columns each side
SKY = 120  # extra rows above
ROAD = 120  # extra rows below
SKY_BAND = 24  # top rows that are only stars (the moon starts lower)
ROAD_BAND = 30  # bottom rows that are only dark road
LIFT = 1.45  # CIELAB lightness factor before the snap
SKY_ROWS = 64  # source rows of open sky (above the lamp and roofs)
# (first row, last row, source column to copy from, None = mirror the edge, "edge" = repeat the
# edge column: the right edge's manhole rows, where a mirror would make a second manhole)
SIDES = {
    "left": [(0, 52, 30), (52, 130, 28), (130, 272, None)],
    "right": [(0, 64, 110), (64, 165, None), (165, 182, "edge"), (182, 272, None)],
}
# Plinth top centre in the 152x272 source (measured on the image).
PLINTH = (68, 147)

ICONS = {"sack": 22, "padlock_big": 22, "mystery": 28}  # source px per art px
CRITTERS = ["critter_blue", "critter_green", "critter_purple", "critter_red"]  # quadrants, reading order
DECO = ["leaf_a", "leaf_b", "radish", "leaf_c"]
# Hand-pixelled: the play triangle on the PLAY button (the kit has none). Palette index per
# character in base 32 (b RUST, c ORANGE, d GOLD), "." transparent.
PLAY_TRI = [
    "bb........",
    "bdb.......",
    "bdcb......",
    "bdccb.....",
    "bdcccb....",
    "bdccccb...",
    "bdcccccb..",
    "bdccccccb.",
    "bdcccccccb",
    "bcccccccb.",
    "bccccccb..",
    "bcccccb...",
    "bccccb....",
    "bcccb.....",
    "bccb......",
    "bcb.......",
    "bb........",
]


def lifted_snap(img, pal, allowed):
    rgb = np.array(img.convert("RGB"))
    targets = pal[allowed]
    lab_t = ps.srgb_to_lab(targets)
    uniq, inv = np.unique(rgb.reshape(-1, 3), axis=0, return_inverse=True)
    lab = ps.srgb_to_lab(uniq)
    lab[:, 0] = np.minimum(100.0, lab[:, 0] * LIFT)
    d = ((lab[:, None, :] - lab_t[None, :, :]) ** 2).sum(-1)
    out = np.full(rgb.shape[:2] + (4,), 255, np.uint8)
    out[..., :3] = targets[d.argmin(1)][inv.reshape(-1)].reshape(rgb.shape)
    return out


def backdrop(src, pal, allowed):
    a = lifted_snap(src, pal, allowed)
    sky = a[:SKY_ROWS]
    sky[(sky[..., :3] == pal[0]).all(-1)] = np.append(pal[1], 255)
    h, w = a.shape[:2]
    out = np.zeros((h + SKY + ROAD, w + 2 * SIDE, 4), np.uint8)
    mid = np.zeros((h, w + 2 * SIDE, 4), np.uint8)
    mid[:, SIDE:SIDE + w] = a
    for side, edge, mirror in (("left", 0, a[:, 1:SIDE + 1][:, ::-1]), ("right", w - 1, a[:, w - SIDE - 1:w - 1][:, ::-1])):
        x0 = 0 if side == "left" else SIDE + w
        for y0, y1, x in SIDES[side]:
            if x is None:
                band = mirror[y0:y1]
            elif x == "edge":
                band = np.repeat(a[y0:y1, edge:edge + 1], SIDE, axis=1)
            else:
                band = a[y0:y1, x:x + SIDE]
            mid[y0:y1, x0:x0 + SIDE] = band
    out[SKY:SKY + h] = mid
    for i in range(SKY // SKY_BAND + 1):
        band = mid[:SKY_BAND] if i % 2 else mid[:SKY_BAND][:, ::-1]
        y = SKY - (i + 1) * SKY_BAND
        top = max(0, y)
        out[top:y + SKY_BAND] = band[top - y:]
    for i in range(ROAD // ROAD_BAND + 1):
        band = mid[h - ROAD_BAND:] if i % 2 else mid[h - ROAD_BAND:][:, ::-1]
        y = SKY + h + i * ROAD_BAND
        end = min(out.shape[0], y + ROAD_BAND)
        out[y:end] = band[:end - y]
    meta = {
        "plinth": [PLINTH[0] + SIDE, PLINTH[1] + SKY],
        "art": [SIDE, SKY, w, h],
    }
    return out, meta


def quadrants(img, pal, allowed, half=True):
    a = snap(img, pal, allowed)
    h, w = a.shape[:2]
    out = []
    for qy in range(2):
        for qx in range(2):
            q = trim(a[qy * h // 2:(qy + 1) * h // 2, qx * w // 2:(qx + 1) * w // 2])
            if half:
                q = trim(shrink_mode(q, max(1, round(q.shape[1] / 2)), max(1, round(q.shape[0] / 2))))
            out.append(q)
    return out


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("raw")
    ap.add_argument("--out", default="assets/ui/home")
    ap.add_argument("--preview")
    ap.add_argument("--palette", default=ps.DEFAULT_PALETTE)
    args = ap.parse_args()
    pal = ps.load_palette(args.palette)
    allowed = ps.allowed_indices(pal, set())
    raw = lambda n: Image.open(os.path.join(args.raw, n)).convert("RGBA")  # noqa: E731
    os.makedirs(args.out, exist_ok=True)
    out = {}
    bd, meta = backdrop(raw("backdrop_px.png"), pal, allowed)
    out["backdrop"] = bd
    for name, a in zip(CRITTERS, quadrants(raw("critters.png"), pal, allowed)):
        out[name] = a
    for name, a in zip(DECO, quadrants(raw("logo_deco.png"), pal, allowed)):
        out[name] = a
    kit3 = raw("kit3_sheet1.png")
    for name, scale in ICONS.items():
        out["icon_" + name] = cut(kit3, pal, allowed, PARTS3[name], scale, CUTOFF3)
    out["play_tri"] = grid(pal, PLAY_TRI)
    for name, a in out.items():
        Image.fromarray(a).save(os.path.join(args.out, name + ".png"))
        print("%-16s %3dx%-3d" % (name, a.shape[1], a.shape[0]))
    with open(os.path.join(args.out, "backdrop.json"), "w") as f:
        json.dump(meta, f, indent="\t")
        f.write("\n")
    if args.preview:
        os.makedirs(args.preview, exist_ok=True)
        Image.fromarray(bd).resize((bd.shape[1] * 3, bd.shape[0] * 3), Image.NEAREST).save(os.path.join(args.preview, "backdrop_x3.png"))
        small = [a for n, a in out.items() if n != "backdrop"]
        W = sum(a.shape[1] + 4 for a in small)
        H = max(a.shape[0] for a in small)
        sheet = Image.new("RGBA", (W, H), (60, 60, 70, 255))
        x = 0
        for a in small:
            sheet.alpha_composite(Image.fromarray(a), (x, 0))
            x += a.shape[1] + 4
        sheet.resize((W * 8, H * 8), Image.NEAREST).save(os.path.join(args.preview, "home_parts_x8.png"))


if __name__ == "__main__":
    main()
