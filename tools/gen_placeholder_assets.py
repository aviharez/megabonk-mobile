#!/usr/bin/env python3
"""Generate the temporary placeholder assets: palette, pixel font, app icon.

Stdlib only. Run from the repo root:  python3 tools/gen_placeholder_assets.py
Outputs:
  assets/palette.png          32x1, one pixel per palette color (temporary palette)
  assets/fonts/pixel.png/.fnt 5x7 bitmap font in BMFont text format (Godot imports .fnt)
  assets/icon/icon.png        32x32 app icon, icon_192.png is the same at 6x (nearest)
"""
import os
import struct
import zlib

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# Temporary 32-color palette. Replace with the final Lospec pick (see BRIEF open items).
# Index 31 (bright magenta) is reserved for enemy projectiles and must appear nowhere else.
PALETTE = [
    # neutrals 0-6
    "0e0b16", "2a2238", "4a3f5c", "7a6f8a", "b3aabf", "f4f0e8", "ffffff",
    # reds 7-10
    "5c1a24", "a3262f", "e04a3a", "ff8a6b",
    # oranges / yellows 11-14
    "8a4a1c", "d97a26", "f5b83d", "ffe680",
    # greens 15-18
    "1f4a2a", "2f7a34", "5cb83f", "a6e070",
    # blues / teal 19-23
    "13304f", "1f5c8a", "3a9ad9", "7ed4f0", "2a8a7a",
    # purples 24-25
    "4a2470", "8a3fc4",
    # browns / skin 26-29
    "3d2418", "6e4428", "b07a4a", "e8b88a",
    # pink 30, reserved enemy-projectile magenta 31
    "d9579a", "ff2bd6",
]
assert len(PALETTE) == 32 and len(set(PALETTE)) == 32


def rgb(hexstr):
    return tuple(int(hexstr[i:i + 2], 16) for i in (0, 2, 4))


def write_png(path, width, height, pixels):
    """pixels: list of rows, each a list of (r, g, b, a)."""
    raw = b"".join(b"\x00" + b"".join(struct.pack("4B", *p) for p in row) for row in pixels)

    def chunk(tag, data):
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    png = b"\x89PNG\r\n\x1a\n"
    png += chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(raw, 9))
    png += chunk(b"IEND", b"")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as f:
        f.write(png)


# 5x7 glyphs ("#" = ink). Width varies per glyph; advance = width + 1.
GLYPHS = {
    "A": [".###.", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"],
    "B": ["####.", "#...#", "#...#", "####.", "#...#", "#...#", "####."],
    "C": [".###.", "#...#", "#....", "#....", "#....", "#...#", ".###."],
    "D": ["####.", "#...#", "#...#", "#...#", "#...#", "#...#", "####."],
    "E": ["#####", "#....", "#....", "####.", "#....", "#....", "#####"],
    "F": ["#####", "#....", "#....", "####.", "#....", "#....", "#...."],
    "G": [".###.", "#...#", "#....", "#.###", "#...#", "#...#", ".####"],
    "H": ["#...#", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"],
    "I": ["###", ".#.", ".#.", ".#.", ".#.", ".#.", "###"],
    "J": ["..###", "...#.", "...#.", "...#.", "#..#.", "#..#.", ".##.."],
    "K": ["#...#", "#..#.", "#.#..", "##...", "#.#..", "#..#.", "#...#"],
    "L": ["#....", "#....", "#....", "#....", "#....", "#....", "#####"],
    "M": ["#...#", "##.##", "#.#.#", "#.#.#", "#...#", "#...#", "#...#"],
    "N": ["#...#", "#...#", "##..#", "#.#.#", "#..##", "#...#", "#...#"],
    "O": [".###.", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."],
    "P": ["####.", "#...#", "#...#", "####.", "#....", "#....", "#...."],
    "Q": [".###.", "#...#", "#...#", "#...#", "#.#.#", "#..#.", ".##.#"],
    "R": ["####.", "#...#", "#...#", "####.", "#.#..", "#..#.", "#...#"],
    "S": [".####", "#....", "#....", ".###.", "....#", "....#", "####."],
    "T": ["#####", "..#..", "..#..", "..#..", "..#..", "..#..", "..#.."],
    "U": ["#...#", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."],
    "V": ["#...#", "#...#", "#...#", "#...#", "#...#", ".#.#.", "..#.."],
    "W": ["#...#", "#...#", "#...#", "#.#.#", "#.#.#", "#.#.#", ".#.#."],
    "X": ["#...#", "#...#", ".#.#.", "..#..", ".#.#.", "#...#", "#...#"],
    "Y": ["#...#", "#...#", ".#.#.", "..#..", "..#..", "..#..", "..#.."],
    "Z": ["#####", "....#", "...#.", "..#..", ".#...", "#....", "#####"],
    "0": [".###.", "#...#", "#..##", "#.#.#", "##..#", "#...#", ".###."],
    "1": [".#.", "##.", ".#.", ".#.", ".#.", ".#.", "###"],
    "2": [".###.", "#...#", "....#", "...#.", "..#..", ".#...", "#####"],
    "3": ["####.", "....#", "....#", ".###.", "....#", "....#", "####."],
    "4": ["...#.", "..##.", ".#.#.", "#..#.", "#####", "...#.", "...#."],
    "5": ["#####", "#....", "####.", "....#", "....#", "#...#", ".###."],
    "6": [".###.", "#....", "#....", "####.", "#...#", "#...#", ".###."],
    "7": ["#####", "....#", "...#.", "..#..", ".#...", ".#...", ".#..."],
    "8": [".###.", "#...#", "#...#", ".###.", "#...#", "#...#", ".###."],
    "9": [".###.", "#...#", "#...#", ".####", "....#", "....#", ".###."],
    ".": [".", ".", ".", ".", ".", ".", "#"],
    ",": ["..", "..", "..", "..", "..", ".#", "#."],
    "!": ["#", "#", "#", "#", "#", ".", "#"],
    "?": [".###.", "#...#", "....#", "...#.", "..#..", ".....", "..#.."],
    ":": [".", ".", "#", ".", ".", "#", "."],
    "-": ["...", "...", "...", "###", "...", "...", "..."],
    "+": ["...", "...", ".#.", "###", ".#.", "...", "..."],
    "=": ["...", "...", "###", "...", "###", "...", "..."],
    "/": ["....#", "....#", "...#.", "..#..", ".#...", "#....", "#...."],
    "'": ["#", "#", ".", ".", ".", ".", "."],
    '"': ["#.#", "#.#", "...", "...", "...", "...", "..."],
    "(": [".#", "#.", "#.", "#.", "#.", "#.", ".#"],
    ")": ["#.", ".#", ".#", ".#", ".#", ".#", "#."],
    "%": ["##..#", "##..#", "...#.", "..#..", ".#...", "#..##", "#..##"],
    "<": ["...", "..#", ".#.", "#..", ".#.", "..#", "..."],
    ">": ["...", "#..", ".#.", "..#", ".#.", "#..", "..."],
    "_": ["....", "....", "....", "....", "....", "....", "####"],
    "#": [".#.#.", "#####", ".#.#.", ".#.#.", ".#.#.", "#####", ".#.#."],
}
GLYPH_H = 7
SPACE_ADVANCE = 3


def gen_font():
    names = list(GLYPHS.keys())
    cols = 16
    cell_w, cell_h = 6, 8
    rows = (len(names) + cols - 1) // cols
    w, h = cols * cell_w, rows * cell_h
    img = [[(0, 0, 0, 0)] * w for _ in range(h)]
    chars = []
    for i, ch in enumerate(names):
        glyph = GLYPHS[ch]
        assert len(glyph) == GLYPH_H, ch
        gw = max(len(r) for r in glyph)
        x0, y0 = (i % cols) * cell_w, (i // cols) * cell_h
        for y, row in enumerate(glyph):
            for x, c in enumerate(row.ljust(gw, ".")):
                if c == "#":
                    img[y0 + y][x0 + x] = (255, 255, 255, 255)
        chars.append((ord(ch), x0, y0, gw, GLYPH_H, gw + 1))
        if ch.isalpha():  # lowercase renders as uppercase
            chars.append((ord(ch.lower()), x0, y0, gw, GLYPH_H, gw + 1))
    chars.append((32, 0, 0, 0, 0, SPACE_ADVANCE))
    write_png(os.path.join(ROOT, "assets/fonts/pixel.png"), w, h, img)
    lines = [
        'info face="Pixel" size=8 bold=0 italic=0 charset="" unicode=1 stretchH=100 smooth=0 aa=1 padding=0,0,0,0 spacing=0,0',
        f"common lineHeight=10 base=8 scaleW={w} scaleH={h} pages=1 packed=0",
        'page id=0 file="pixel.png"',
        f"chars count={len(chars)}",
    ]
    for cid, x, y, cw, chh, adv in sorted(chars):
        # yoffset 1 puts the 7px glyph's last row on the baseline (base=8).
        lines.append(f"char id={cid} x={x} y={y} width={cw} height={chh} xoffset=0 yoffset=1 xadvance={adv} page=0 chnl=15")
    with open(os.path.join(ROOT, "assets/fonts/pixel.fnt"), "w") as f:
        f.write("\n".join(lines) + "\n")


def gen_palette():
    write_png(os.path.join(ROOT, "assets/palette.png"), 32, 1, [[rgb(c) + (255,) for c in PALETTE]])


# 32x32 placeholder icon: a helmeted loaf face. Letters map to palette indices.
ICON = [
    "................................",
    "................................",
    "...........0000000000...........",
    ".........00444444444400.........",
    "........0444555544444440........",
    ".......044455544444444440.......",
    "......04445444444444444440......",
    "......04444444444444444440......",
    ".....0444444444444444444440.....",
    ".....0000000000000000000000.....",
    ".....0333300003333000033330.....",
    ".....0000000000000000000000.....",
    "....0RRRRRRRRRRRRRRRRRRRRRR0....",
    "...0RYYYYYYYYYYYYYYYYYYYYYYR0...",
    "...0RYYYYYYYYYYYYYYYYYYYYYYR0...",
    "..0RYYYY00YYYYYYYYYY00YYYYYYR0..",
    "..0RYYYY00YYYYYYYYYY00YYYYYYR0..",
    "..0RYYYYYYYYYYYYYYYYYYYYYYYYR0..",
    "..0RYYYPPYYYYYYYYYYYYYYPPYYYR0..",
    "..0RYYYYYYYY00000000YYYYYYYYR0..",
    "..0RYYYYYYYYY0MMMM0YYYYYYYYYR0..",
    "..0RYYYYYYYYYY0000YYYYYYYYYYR0..",
    "..0RYYYYYYYYYYYYYYYYYYYYYYYYR0..",
    "...0RYYYYYYYYYYYYYYYYYYYYYYR0...",
    "...0RRYYYYYYYYYYYYYYYYYYYYRR0...",
    "....0RRRRRRRRRRRRRRRRRRRRRR0....",
    ".....0000000000000000000000.....",
    "................................",
    "................................",
    "................................",
    "................................",
    "................................",
]
ICON_KEY = {"0": 0, "3": 3, "4": 4, "5": 5, "R": 28, "Y": 29, "P": 30, "M": 8}
ICON_BG = 19


def gen_icon():
    img = []
    for row in ICON:
        assert len(row) == 32, row
        img.append([rgb(PALETTE[ICON_KEY[c] if c in ICON_KEY else ICON_BG]) + (255,) for c in row])
    write_png(os.path.join(ROOT, "assets/icon/icon.png"), 32, 32, img)
    scale = 6
    big = [[px for px in row for _ in range(scale)] for row in img for _ in range(scale)]
    write_png(os.path.join(ROOT, "assets/icon/icon_192.png"), 192, 192, big)


if __name__ == "__main__":
    gen_palette()
    gen_font()
    gen_icon()
    print("ok")
