#!/usr/bin/env python3
"""Build assets/tiles/*.png (tileable ground textures) from the downloaded SpriteCook textures.

Each texture is snapped to the palette at full size (no shrinking: they tile at 1:1), then some
palette colours are swapped where snapping went wrong:
  sand:    PAPER -> DOUGH (the light gradient snapped into white bands)
  grass:   toned down (owner): flowers and LIME speckles become LEAF, and lone GREEN tuft pixels
           (no GREEN 4-neighbour, wrapping) become LEAF, so only the bigger tufts stay
  asphalt: one step lighter (NIGHT -> SHADE, SHADE -> GRAY, DEEP_BLUE -> NIGHT), the old road
           colour, so dark enemies stay readable on it
Asset ids are in docs/spritecook-assets.json.

Usage: python3 tools/art/textures.py RAW_DIR   (RAW_DIR holds grass, asphalt, paving, sand, soil .png)
"""
import os
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
import palette_snap as ps  # noqa: E402
from spritecook_shrink import snap  # noqa: E402

NAMES = ("INK NIGHT SHADE GRAY MIST PAPER WHITE WINE BLOOD RED SALMON RUST ORANGE GOLD BUTTER DEEP_GREEN "
         "LEAF GREEN LIME DEEP_BLUE OCEAN BLUE SKY TEAL PLUM PURPLE BARK WOOD CRUST DOUGH PINK").split()
SWAPS = {
    "grass": {"BUTTER": "LEAF", "PAPER": "LEAF", "LIME": "LEAF"},
    "sand": {"PAPER": "DOUGH"},
    "asphalt": {"NIGHT": "SHADE", "SHADE": "GRAY", "DEEP_BLUE": "NIGHT"},
}


def main():
    raw = sys.argv[1]
    pal = ps.load_palette(ps.DEFAULT_PALETTE)
    allowed = ps.allowed_indices(pal, set())
    for name in ["grass", "asphalt", "paving", "sand", "soil"]:
        a = snap(Image.open(os.path.join(raw, name + ".png")), pal, allowed)
        src = a.copy()
        for frm, to in SWAPS.get(name, {}).items():
            m = np.all(src[..., :3] == pal[NAMES.index(frm)], axis=-1) & (src[..., 3] > 0)
            a[m, :3] = pal[NAMES.index(to)]
        if name == "grass":
            green = np.all(a[..., :3] == pal[NAMES.index("GREEN")], axis=-1)
            nb = sum(np.roll(green, s, axis=ax) for s in (1, -1) for ax in (0, 1))
            a[green & (nb == 0), :3] = pal[NAMES.index("LEAF")]
        out = f"assets/tiles/{name}.png"
        Image.fromarray(a).save(out)
        print(out, a.shape[1], a.shape[0])


if __name__ == "__main__":
    main()
