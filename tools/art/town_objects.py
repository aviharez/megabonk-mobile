#!/usr/bin/env python3
"""The Town's in-run objects (phase 13), hand-pixelled on the palette like the other small props
(docs/BRIEF.md "PixelLab rules": sprites of 16 px or less are drawn by hand). One per building,
standing on its lot in Suburbia: Bakery's bread stall, Pigeon Coop's pigeon loft, Office's coffee
machine, Gym's pull-up bar. 1 px INK outline, light from the top left. Writes assets/props/<id>.png.

Usage:  python3 tools/art/town_objects.py
"""
import os

from PIL import Image

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
NAMES = ("INK NIGHT SHADE GRAY MIST PAPER WHITE WINE BLOOD RED SALMON RUST ORANGE GOLD BUTTER DEEP_GREEN "
         "LEAF GREEN LIME DEEP_BLUE OCEAN BLUE SKY TEAL PLUM PURPLE BARK WOOD CRUST DOUGH PINK").split()
KEY = {
    "K": "INK", "n": "NIGHT", "s": "SHADE", "g": "GRAY", "m": "MIST", "p": "PAPER", "w": "WHITE",
    "B": "BLOOD", "R": "RED", "r": "SALMON", "u": "RUST", "O": "ORANGE", "G": "GOLD", "y": "BUTTER",
    "b": "BARK", "o": "WOOD", "c": "CRUST", "d": "DOUGH", "L": "BLUE", "S": "SKY", "D": "OCEAN",
}

ART = {
    # A market stall: red-and-white awning, two loaves and a baguette on the counter.
    "bread_stall": [
        ".KKKKKKKKKKKKKK.",
        "KrrppprrrpppRRRK",
        "KRRmmmRRRmmmBBBK",
        ".KRKKmKRKKmKBKK.",
        "..KcbbbbbbbboK..",
        "..KcbKKKbbbboK..",
        "..KcKycGKbKKoK..",
        "..KcKGGuKKycKK..",
        ".KKKKKKKKKGuKKK.",
        "KddddddddddddcoK",
        "KcccccccccccccoK",
        "KoKKKKKKKKKKKKbK",
        "KoK.........KbK.",
        "KoK.........KbK.",
        "KKK.........KKK.",
    ],
    # A loft box on a post: round door, a pigeon sitting on the roof.
    "pigeon_loft": [
        "......KKK.....",
        ".....KmmgK....",
        "....KmwKgsK...",
        "...KKmmmgsKK..",
        "..KccccccccoK.",
        ".KccccccccccoK",
        "KKKKKKKKKKKKKK",
        ".KdcccccccccoK",
        ".KcccKKKKccooK",
        ".KcccKnnKccooK",
        ".KcccKnnKcoobK",
        ".KoooooooooobK",
        ".KKKKKKKKKKKKK",
        "......KoK.....",
        "......KoK.....",
        "......KbK.....",
        ".....KKKKK....",
    ],
    # An office coffee machine: grey body, red button, a paper cup steaming under the spout.
    "coffee_machine": [
        "..KKKKKKKKK..",
        ".KmmmmmmmmgK.",
        ".KmKKKKKKmsK.",
        ".KmKSSLLKmsK.",
        ".KmKKKKKKmsK.",
        ".KmmmmrRmgsK.",
        ".KgggggBggsK.",
        ".KgKKKKKKgsK.",
        ".KgKn.w.KgsK.",
        ".KgKnKKKKgsK.",
        ".KgKnKpKKgsK.",
        ".KgKnKmKKgsK.",
        ".KgKKKKKKgsK.",
        ".KggggggggsK.",
        ".KKKKKKKKKKK.",
    ],
    # A pull-up bar: two posts and a bar, a dumbbell at its foot.
    "pullup_bar": [
        "KKKKKKKKKKKKKKK",
        "KmmmmmmmmmmmmgK",
        "KKmKKKKKKKKKgKK",
        ".KmK.......KgK.",
        ".KmK.......KgK.",
        ".KmK.......KgK.",
        ".KmK.......KgK.",
        ".KmK.......KgK.",
        ".KmK.......KgK.",
        ".KmK.KK.KK.KgK.",
        ".KmKKsKKKsKKgK.",
        ".KmKKnKggKnKgK.",
        ".KmKKsKKKsKKgK.",
        "KKgKKKK.KKKKsKK",
        "KssssK.....KssK",
        "KKKKKK.....KKKK",
    ],
}
IMPORT = '[remap]\n\nimporter="image"\ntype="Image"\n'


def main():
    pal = Image.open(os.path.join(REPO, "assets", "palette.png")).convert("RGBA")
    col = {NAMES[i]: pal.getpixel((i, 0)) for i in range(len(NAMES))}
    for name, rows in ART.items():
        w = max(len(r) for r in rows)
        assert all(len(r) == w for r in rows), (name, [len(r) for r in rows])
        img = Image.new("RGBA", (w, len(rows)), (0, 0, 0, 0))
        for y, row in enumerate(rows):
            for x, ch in enumerate(row):
                if ch != ".":
                    img.putpixel((x, y), col[KEY[ch]])
        path = os.path.join(REPO, "assets", "props", name + ".png")
        img.save(path)
        if not os.path.exists(path + ".import"):
            open(path + ".import", "w").write(IMPORT)
        print("wrote", path, img.size)


if __name__ == "__main__":
    main()
