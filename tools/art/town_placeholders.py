#!/usr/bin/env python3
"""Placeholder Town building sprites (phase 13) until the PixelLab art is approved: the Suburbia
house (assets/props/house.png) with its red roof ramp swapped per building. Writes
assets/town/<id>.png (only files that don't exist yet, so approved art is never overwritten;
--force rewrites them all).

Usage:  python3 tools/art/town_placeholders.py [--force]
"""
import os
import sys

from PIL import Image

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
NAMES = ("INK NIGHT SHADE GRAY MIST PAPER WHITE WINE BLOOD RED SALMON RUST ORANGE GOLD BUTTER DEEP_GREEN "
         "LEAF GREEN LIME DEEP_BLUE OCEAN BLUE SKY TEAL PLUM PURPLE BARK WOOD CRUST DOUGH PINK").split()
ROOF = ["SALMON", "RED", "BLOOD", "WINE"]
RAMPS = {
    "bakery": ["DOUGH", "CRUST", "WOOD", "BARK"],
    "pigeon_coop": ["SKY", "BLUE", "OCEAN", "DEEP_BLUE"],
    "office": ["PINK", "PURPLE", "PLUM", "NIGHT"],
    "gym": ["BUTTER", "GOLD", "ORANGE", "RUST"],
}
IMPORT = '[remap]\n\nimporter="image"\ntype="Image"\n'


def main():
    force = "--force" in sys.argv
    pal = Image.open(os.path.join(REPO, "assets", "palette.png")).convert("RGBA")
    col = {NAMES[i]: pal.getpixel((i, 0)) for i in range(len(NAMES))}
    src = Image.open(os.path.join(REPO, "assets", "props", "house.png")).convert("RGBA")
    os.makedirs(os.path.join(REPO, "assets", "town"), exist_ok=True)
    for bid, ramp in RAMPS.items():
        out_path = os.path.join(REPO, "assets", "town", bid + ".png")
        if os.path.exists(out_path) and not force:
            print("kept", out_path)
            continue
        swap = {col[a][:3]: col[b] for a, b in zip(ROOF, ramp)}
        img = src.copy()
        for y in range(img.size[1]):
            for x in range(img.size[0]):
                p = img.getpixel((x, y))
                if p[3] and p[:3] in swap:
                    img.putpixel((x, y), swap[p[:3]])
        img.save(out_path)
        if not os.path.exists(out_path + ".import"):
            open(out_path + ".import", "w").write(IMPORT)
        print("wrote", out_path)


if __name__ == "__main__":
    main()
