#!/usr/bin/env python3
"""Rebuild the in-run object art from the downloaded SpriteCook sheets (asset ids in
docs/spritecook-assets.json): map objects (assets/props/), XP gems (assets/gems/), weapon shots and
weapon objects (assets/shots/) and enemy shots (assets/shots/enemy/).

RAW_DIR holds, as downloaded:
  mapD.png    2x2: chest, pot, shrine, pigeon cage
  mapE.png    2x2: portal, merchant, cage key, mole rock
  smallF.png  3x3: gem small, gem mid, gem big / feather, staple, rocket / spit bullet, pellet, cup
  sheet1.png  icon sheet 1 (rubber duck, bottom-left)
  sheet2.png  icon sheet 2 (garden gnome, top-right)
  baguette.png  the 32x32 Baguette icon

Colour variants (elite / boss chest, the three shrines) are palette-ramp swaps, not generations.
Shots that fly in a direction (feather, staple, rocket) and the Baguette swing are baked into strips
of turned frames (frame k points at angle k * 360 / TURNS, Godot angles: 0 = right, 90 = down) with
a RotSprite-style turn: Scale2x three times, turn with nearest sampling, then shrink by dominant
colour, so every pixel stays a palette colour on the grid. Enemy shots are recoloured to the
reserved enemy-shot magenta (index 31), which appears nowhere else.

Usage:  python3 tools/art/run_art.py RAW_DIR [--preview DIR]
"""
import argparse
import math
import os
import sys

import numpy as np
from PIL import Image

TOOLS = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, TOOLS)
import palette_snap as ps  # noqa: E402
from icon_shrink import cells  # noqa: E402
from spritecook_shrink import shrink_mode, snap  # noqa: E402

REPO = os.path.dirname(TOOLS)
PAL = ps.load_palette(ps.DEFAULT_PALETTE)
ALLOWED = ps.allowed_indices(PAL, set(ps.RESERVED))

# Palette indices (scripts/core/palette.gd).
INK, NIGHT, SHADE, GRAY, MIST, PAPER, WHITE = 0, 1, 2, 3, 4, 5, 6
WINE, BLOOD, RED, SALMON, RUST, ORANGE, GOLD, BUTTER = 7, 8, 9, 10, 11, 12, 13, 14
DEEP_BLUE, OCEAN, BLUE, SKY, TEAL, PLUM, PURPLE = 19, 20, 21, 22, 23, 24, 25
BARK, WOOD, CRUST, DOUGH, PINK, ENEMY_SHOT = 26, 27, 28, 29, 30, 31

SHOT_TURNS = 16
SWING_TURNS = 32
SWING_LENGTHS = [16, 20, 24, 28, 32, 36, 40]


def crop(a):
    ys, xs = np.nonzero(a[..., 3])
    return a[ys.min():ys.max() + 1, xs.min():xs.max() + 1]


def fit(a, size):
    """Shrink a snapped sprite (dominant colour per block) so its longer side is `size`."""
    a = crop(a)
    h, w = a.shape[:2]
    k = size / max(w, h)
    if k >= 1.0:
        return a
    return crop(shrink_mode(a, max(1, round(w * k)), max(1, round(h * k))))


def cell(raw, name, grid, i):
    return snap(cells(Image.open(os.path.join(raw, name)), grid)[i], PAL, ALLOWED)


def recolor(a, mapping):
    out = a.copy()
    idx = index_map(a)
    for src, dst in mapping.items():
        out[idx == src, :3] = PAL[dst]
    return out


def index_map(a):
    lut = {tuple(int(v) for v in c): i for i, c in enumerate(PAL)}
    idx = np.full(a.shape[:2], -1)
    for y, x in zip(*np.nonzero(a[..., 3])):
        idx[y, x] = lut[tuple(int(v) for v in a[y, x, :3])]
    return idx


def scale2x(a):
    h, w = a.shape[:2]
    p = np.pad(a, ((1, 1), (1, 1), (0, 0)), mode="edge")
    eq = lambda u, v: (u == v).all(-1)  # noqa: E731
    B, D, E, F, H = p[:-2, 1:-1], p[1:-1, :-2], p[1:-1, 1:-1], p[1:-1, 2:], p[2:, 1:-1]
    out = np.zeros((h * 2, w * 2, 4), a.dtype)
    ok = ~eq(B, H) & ~eq(D, F)
    for (dy, dx), (u, v) in {(0, 0): (D, B), (0, 1): (B, F), (1, 0): (D, H), (1, 1): (H, F)}.items():
        m = (ok & eq(u, v))[..., None]
        out[dy::2, dx::2] = np.where(m, u, E)
    return out


def turned(a, native_deg, target_deg, length):
    """`a` turned from pointing at native_deg to target_deg, shrunk so its long axis is `length` px."""
    big = scale2x(scale2x(scale2x(crop(a))))
    src_len = axis_length(a, native_deg)
    im = Image.fromarray(big).rotate(native_deg - target_deg, resample=Image.NEAREST, expand=True)
    r = crop(np.array(im))
    k = length / (src_len * 8.0)
    h, w = r.shape[:2]
    return crop(shrink_mode(r, max(1, round(w * k)), max(1, round(h * k))))


def axis_length(a, deg):
    """Extent of the opaque pixels along the direction `deg`."""
    ys, xs = np.nonzero(a[..., 3])
    t = xs * math.cos(math.radians(deg)) + ys * math.sin(math.radians(deg))
    return float(t.max() - t.min() + 1)


def strip(frames, size):
    """Frames centred in size x size cells, left to right."""
    out = np.zeros((size, size * len(frames), 4), np.uint8)
    for i, f in enumerate(frames):
        h, w = f.shape[:2]
        y0, x0 = (size - h) // 2, i * size + (size - w) // 2
        out[y0:y0 + h, x0:x0 + w] = f
    return out


def native_angle(a):
    """Direction of a sprite's long axis (degrees, image y down), pointing to the upper right."""
    ys, xs = np.nonzero(a[..., 3])
    pts = np.stack([xs - xs.mean(), ys - ys.mean()])
    w, v = np.linalg.eigh(np.cov(pts))
    dx, dy = v[:, w.argmax()]
    if dx < 0:
        dx, dy = -dx, -dy
    return math.degrees(math.atan2(dy, dx))


def shot_strip(a, native_deg, length, turns=SHOT_TURNS):
    frames = [turned(a, native_deg, 360.0 * k / turns, length) for k in range(turns)]
    return strip(frames, max(max(f.shape[:2]) for f in frames))


def outside(a):
    """Transparent pixels connected to the image border (4-neighbours)."""
    t = np.pad(a[..., 3] == 0, 1, constant_values=True)
    o = np.zeros_like(t)
    o[0, 0] = True
    while True:
        g = grow(o) & t
        if (g == o).all():
            return o[1:-1, 1:-1]
        o = g


def grow(m):
    g = m.copy()
    g[1:] |= m[:-1]
    g[:-1] |= m[1:]
    g[:, 1:] |= m[:, :-1]
    g[:, :-1] |= m[:, 1:]
    return g


def see_through(a):
    """Drops the INK lines around holes (cage bars): at half size they would fill the gaps."""
    holes = (a[..., 3] == 0) & ~outside(a)
    out = a.copy()
    out[grow(holes) & (index_map(a) == INK), 3] = 0
    return out


def outlined(a):
    """A 1px INK outline around the sprite (grows it by 2)."""
    a = np.pad(a, ((1, 1), (1, 1), (0, 0)))
    ring = grow(a[..., 3] > 0) & (a[..., 3] == 0)
    a[ring, :3] = PAL[INK]
    a[ring, 3] = 255
    return a


def to_enemy_shot(a):
    """Reserved magenta fill, INK outline, the lightest colour kept as a WHITE highlight."""
    idx = index_map(a)
    lum = PAL.astype(float) @ [0.299, 0.587, 0.114]
    out = a.copy()
    seen = sorted({int(i) for i in idx[idx >= 0]}, key=lambda i: lum[i])
    for i in seen:
        dst = INK if i in (INK, NIGHT) else WHITE if i == seen[-1] and lum[i] > 200 else ENEMY_SHOT
        out[idx == i, :3] = PAL[dst]
    return out


def save(a, rel, previews, scale=8):
    path = os.path.join(REPO, rel)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    Image.fromarray(a).save(path)
    print(f"{rel}: {a.shape[1]}x{a.shape[0]}")
    if previews:
        bg = Image.new("RGBA", (a.shape[1], a.shape[0]), (90, 110, 90, 255))
        bg.alpha_composite(Image.fromarray(a))
        bg.resize((a.shape[1] * scale, a.shape[0] * scale), Image.NEAREST).save(
            os.path.join(previews, rel.replace("/", "_")))


# Wood ramp of the chest -> blue (elite) and purple (boss); found by tools/art/run_art.py --colors.
CHEST_ELITE = {BARK: DEEP_BLUE, WOOD: OCEAN, CRUST: BLUE}
CHEST_BOSS = {BARK: NIGHT, WOOD: PLUM, CRUST: PURPLE}
# The shrine crystal (SKY with a WHITE glint as generated) -> red (risk) and gold (challenge).
SHRINE_RISK = {SKY: RED}
SHRINE_CHALLENGE = {SKY: GOLD}


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("raw")
    ap.add_argument("--preview", default="", help="also write 8x previews on a grass-green ground here")
    ap.add_argument("--colors", action="store_true", help="print the palette indices of each cell and stop")
    args = ap.parse_args()
    R, pv = args.raw, args.preview
    if pv:
        os.makedirs(pv, exist_ok=True)

    D = [cell(R, "mapD.png", 2, i) for i in range(4)]
    E = [cell(R, "mapE.png", 2, i) for i in range(4)]
    F = [cell(R, "smallF.png", 3, i) for i in range(9)]
    if args.colors:
        for name, a in [("chest", D[0]), ("shrine", D[2])]:
            idx = index_map(a)
            u, n = np.unique(idx[idx >= 0], return_counts=True)
            print(name, dict(zip(u.tolist(), n.tolist())))
        return

    # Map objects (stand on their bottom edge, so cropped tight).
    chest = fit(D[0], 16)
    save(chest, "assets/props/chest.png", pv)
    save(recolor(chest, CHEST_ELITE), "assets/props/chest_elite.png", pv)
    save(recolor(chest, CHEST_BOSS), "assets/props/chest_boss.png", pv)
    save(fit(D[1], 11), "assets/props/pot.png", pv)
    shrine = fit(D[2], 18)
    save(shrine, "assets/props/shrine_charge.png", pv)
    save(recolor(shrine, SHRINE_RISK), "assets/props/shrine_risk.png", pv)
    save(recolor(shrine, SHRINE_CHALLENGE), "assets/props/shrine_challenge.png", pv)
    save(fit(see_through(D[3]), 18), "assets/props/cage.png", pv)
    save(fit(E[0], 18), "assets/props/portal.png", pv)
    save(fit(E[1], 18), "assets/props/merchant.png", pv)
    save(fit(E[2], 11), "assets/props/key.png", pv)

    # XP gems: three shapes as well as three colours.
    save(fit(F[0], 9), "assets/gems/gem_small.png", pv)
    save(fit(F[1], 10), "assets/gems/gem_mid.png", pv)
    save(fit(F[2], 12), "assets/gems/gem_big.png", pv)

    # Weapon shots. Directional ones are strips of SHOT_TURNS frames.
    # The feather flies quill first (its sharp end is lower left).
    save(shot_strip(F[3], native_angle(F[3]) + 180.0, 10), "assets/shots/feather.png", pv)
    save(shot_strip(F[4], 0.0, 7), "assets/shots/staple.png", pv)
    save(shot_strip(F[5], native_angle(F[5]), 10), "assets/shots/rocket.png", pv)
    save(fit(F[7], 4), "assets/shots/pellet.png", pv)
    save(fit(F[8], 8), "assets/shots/cup.png", pv)
    save(fit(cell(R, "sheet1.png", 2, 2), 8), "assets/shots/duck.png", pv)
    save(fit(cell(R, "sheet2.png", 2, 1), 11), "assets/shots/gnome.png", pv)

    # Baguette swing: one row per blade length, SWING_TURNS frames per row; the crust end
    # (upper right in the icon) points outward.
    bag = snap(Image.open(os.path.join(R, "baguette.png")), PAL, ALLOWED)
    deg = native_angle(bag)
    size = SWING_LENGTHS[-1] + 2
    rows = [strip([turned(bag, deg, 360.0 * k / SWING_TURNS, n) for k in range(SWING_TURNS)], size)
            for n in SWING_LENGTHS]
    save(np.concatenate(rows, axis=0), "assets/shots/baguette_swing.png", pv, scale=2)

    # Enemy shots in the reserved magenta.
    save(outlined(to_enemy_shot(fit(F[6], 4))), "assets/shots/enemy/bullet.png", pv)
    save(outlined(to_enemy_shot(fit(E[3], 5))), "assets/shots/enemy/rock.png", pv)


if __name__ == "__main__":
    main()
