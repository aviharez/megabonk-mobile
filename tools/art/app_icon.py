#!/usr/bin/env python3
"""Build the app icons from a SpriteCook pixel icon (background included, full bleed).

Snaps it to assets/palette.png (CIELAB, like the other SpriteCook art; the enemy-shot magenta is
never used), crops the centre 64x64 (smaller art is centred on its own background colour, the
most common edge colour), and writes only whole-number scales, so no pixel is ever resampled:

  assets/icon/icon.png              64x64   (project icon)
  assets/icon/icon_192.png          192x192 (x3, Android legacy launcher icon)
  assets/icon/icon_fg_432.png       432x432 (x5 = 320 px in the middle, a little past the 288 px a
                                             launcher shows of an adaptive icon, so the art
                                             fills it; the rest is clear)
  assets/icon/icon_bg_432.png       432x432 (the background colour, solid)
  assets/icon/icon_mono_432.png     432x432 (themed icons, Android 13+: the hero's lit
                                             pixels, all WHITE; launchers use only the shape)

Usage: python3 tools/art/app_icon.py SPRITECOOK_PIXEL.png
"""
import os
import sys
from collections import Counter

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
sys.path.insert(0, os.path.dirname(HERE))
import palette_snap as ps  # noqa: E402
from spritecook_shrink import snap  # noqa: E402

SIZE = 64
LEGACY = 192
VISIBLE = 288
OUT = os.path.join(ROOT, "assets", "icon")


def main():
    if len(sys.argv) != 2:
        raise SystemExit(__doc__)
    pal = ps.load_palette(os.path.join(ROOT, "assets", "palette.png"))
    allowed = ps.allowed_indices(pal, [])
    a = snap(Image.open(sys.argv[1]), pal, allowed)
    h, w = a.shape[:2]
    # Bigger art: keep the centre.
    cy, cx = max(0, (h - SIZE) // 2), max(0, (w - SIZE) // 2)
    a = a[cy:cy + SIZE, cx:cx + SIZE]
    h, w = a.shape[:2]
    # Fill colour: the most common opaque colour along the edges.
    edge = np.concatenate([a[0], a[-1], a[:, 0], a[:, -1]])
    edge = [tuple(p[:3]) for p in edge if p[3] == 255]
    bg = Counter(edge).most_common(1)[0][0]
    canvas = np.zeros((SIZE, SIZE, 4), np.uint8)
    canvas[...] = (*bg, 255)
    y0, x0 = (SIZE - h) // 2, (SIZE - w) // 2
    region = canvas[y0:y0 + h, x0:x0 + w]
    op = a[..., 3] == 255
    region[op] = a[op]
    icon = Image.fromarray(canvas, "RGBA")
    icon.save(os.path.join(OUT, "icon.png"))
    icon.resize((LEGACY, LEGACY), Image.NEAREST).save(os.path.join(OUT, "icon_192.png"))
    k = -(-VISIBLE // SIZE)  # round up: the art fills all the launcher shows
    big = SIZE * k
    fg = Image.new("RGBA", (432, 432), (0, 0, 0, 0))
    fg.paste(icon.resize((big, big), Image.NEAREST), ((432 - big) // 2, (432 - big) // 2))
    fg.save(os.path.join(OUT, "icon_fg_432.png"))
    Image.new("RGBA", (432, 432), (*bg, 255)).save(os.path.join(OUT, "icon_bg_432.png"))
    mono = np.zeros((SIZE, SIZE, 4), np.uint8)
    # The hero's silhouette: everything joined to the centre that isn't sky,
    # a motion line or a critter, with the darkest pixels (visor slits, mouth,
    # inner outlines) cut out so it reads as a face and not a blob.
    rgb = canvas[..., :3].astype(np.int32)
    luma = 0.299 * rgb[..., 0] + 0.587 * rgb[..., 1] + 0.114 * rgb[..., 2]
    green = (rgb[..., 1] > rgb[..., 0] + 20) & (rgb[..., 1] > rgb[..., 2] + 20)
    purple = (rgb[..., 2] > rgb[..., 1] + 30) & (rgb[..., 0] > rgb[..., 1] + 30)
    sky = np.all(rgb == np.array(bg), axis=-1)
    white = np.all(rgb == 255, axis=-1)
    sky_pad = np.pad(sky, 1)
    near_sky = sky_pad[:-2, 1:-1] | sky_pad[2:, 1:-1] | sky_pad[1:-1, :-2] | sky_pad[1:-1, 2:]
    solid = ~sky & ~(white & near_sky) & ~green & ~purple
    hero = _component(solid, SIZE // 2, SIZE // 2)
    shape = hero & (luma >= 45)
    mono[shape] = (255, 255, 255, 255)
    mono_big = Image.new("RGBA", (432, 432), (0, 0, 0, 0))
    mono_big.paste(Image.fromarray(mono, "RGBA").resize((big, big), Image.NEAREST), ((432 - big) // 2, (432 - big) // 2))
    mono_big.save(os.path.join(OUT, "icon_mono_432.png"))
    print(f"icon {w}x{h} (centre of the source) on {SIZE}x{SIZE}, background #%02X%02X%02X -> {OUT}" % bg)


def _component(mask, y, x):
    """The 4-connected part of `mask` holding (y, x)."""
    out = np.zeros_like(mask)
    stack = [(y, x)]
    h, w = mask.shape
    while stack:
        cy, cx = stack.pop()
        if 0 <= cy < h and 0 <= cx < w and mask[cy, cx] and not out[cy, cx]:
            out[cy, cx] = True
            stack += [(cy + 1, cx), (cy - 1, cx), (cy, cx + 1), (cy, cx - 1)]
    return out


if __name__ == "__main__":
    main()
