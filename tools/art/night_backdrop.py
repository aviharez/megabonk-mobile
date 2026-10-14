#!/usr/bin/env python3
"""Home backdrop at night for UI kit v2 (docs/BRIEF.md "Update 1", Backgrounds): the phase 9
backdrop (assets/ui/home/backdrop.png) with its purple-grey night moved onto the kit's night-blue
ramp; warm lamp light and lit windows (GOLD, BUTTER, ORANGE, RUST, CRUST, DOUGH, SALMON) and the
moon (PAPER, WHITE) are kept. Writes assets/ui/home/backdrop_night.png (same size, same plinth spot).

Usage:  python3 tools/art/night_backdrop.py
"""
import os

from PIL import Image

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
NAMES = ("INK NIGHT SHADE GRAY MIST PAPER WHITE WINE BLOOD RED SALMON RUST ORANGE GOLD BUTTER DEEP_GREEN "
         "LEAF GREEN LIME DEEP_BLUE OCEAN BLUE SKY TEAL PLUM PURPLE BARK WOOD CRUST DOUGH PINK ENEMY_SHOT "
         "BG SURFACE SURFACE_2 WELL RAISED FRAME_LO FRAME FRAME_HI LINE MUTED R_COMMON").split()
MAP = {
    "INK": "BG", "NIGHT": "SURFACE", "SHADE": "RAISED", "GRAY": "LINE", "MIST": "FRAME",
    "PLUM": "SURFACE_2", "DEEP_GREEN": "FRAME_LO", "LEAF": "LINE", "BARK": "FRAME_LO", "WOOD": "LINE",
    "DEEP_BLUE": "RAISED", "OCEAN": "FRAME", "TEAL": "FRAME", "BLUE": "FRAME_HI",
}


def main():
    pal = Image.open(os.path.join(REPO, "assets", "palette.png")).convert("RGBA")
    col = {NAMES[i]: pal.getpixel((i, 0)) for i in range(pal.size[0])}
    by_rgb = {v[:3]: k for k, v in col.items()}
    src = Image.open(os.path.join(REPO, "assets", "ui", "home", "backdrop.png")).convert("RGBA")
    out = src.copy()
    for y in range(src.size[1]):
        for x in range(src.size[0]):
            p = src.getpixel((x, y))
            if p[3] == 0:
                continue
            name = by_rgb[p[:3]]
            if name in MAP:
                out.putpixel((x, y), col[MAP[name]])
    out.save(os.path.join(REPO, "assets", "ui", "home", "backdrop_night.png"))
    print("assets/ui/home/backdrop_night.png", out.size)


if __name__ == "__main__":
    main()
