#!/usr/bin/env python3
"""Write the enemy critter sheets (assets/enemies/<id>.png + .json) from hand-cleaned pixel grids.

    python3 tools/art/critters.py [--out assets/enemies] [--preview DIR]

Source art (asset ids in docs/spritecook-assets.json):
  "enemy_critters_1"  2x2 SpriteCook sheet 8c30f9d2 (100x100): blob, skitter, spitter, bloater
  "enemy_critters_2"  2x2 SpriteCook sheet 60df65eb (100x100): chomper (mouth shut), floating
                      eyeball, chomper (jaw open), eyeball. The eyeballs halve to ~13 px, too big for the
                      Gnat (6-8 px), so the Gnat is hand-pixelled below instead.

Each 50x50 quadrant was snapped to the palette and halved: the shape mask keeps a pixel where at
least 2 of its 4 source pixels are opaque, the outline is rebuilt as 1 px INK on the mask's edge,
and the inside takes INK where 2+ source pixels are INK, else the most common other colour. The
cleanest of the four 2x2 sampling offsets was kept and then cleaned by hand (eyes and pupils
redrawn, broken outline pixels closed). The result is stored below as text, so the sheets
rebuild without the downloads and every pixel can be reviewed here.

Frames per sheet: the open-eye frames (one, or the Gnat's two wing frames), then the same frames
with the eyes closed (blink). Closed frames are made here, not generated: inside each EYES box
every pixel that is not on the silhouette's edge becomes the lid colour, and one INK row is drawn
across the box, short of its end columns (the shut lid line). The sidecar gives "loop" (open frames) and "blink" (index of
the first closed frame), "poses" (extra frames after the closed ones, e.g. the Chomper's open-jaw
"charge"), plus "origin" = feet (bottom centre of the opaque pixels).

Grids: one palette index per character in base 32 (0 INK, 4 MIST, 5 PAPER, 6 WHITE, 7 WINE,
8 BLOOD, 9 RED, a SALMON, b RUST, c ORANGE, d GOLD, e BUTTER, j DEEP_BLUE, k OCEAN, l BLUE,
m SKY, o PLUM, p PURPLE), "." transparent. Every frame keeps a 1 px empty border (the batch
shader draws the elite outline there).
"""
import argparse
import json
import os
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
import palette_snap as ps  # noqa: E402

SHEET_1 = "8c30f9d2-2d38-4f81-b37e-8f25628615a9"
SHEET_2 = "60df65eb-cfd6-4fee-ad52-e1632b074182"

# --- Sheet 1 (open eyes, facing right) ----------------------------------------------------------
BLOB = [
    "....................",
    ".......0............",
    "......0l0...........",
    "......0kl0..........",
    ".......0k000........",
    ".....00lkllm00......",
    "....0kllllllkm0.....",
    "...0kklleeeelm0.....",
    "..0kkllemeeeel0.....",
    "..0kklleeeee0e00....",
    ".0kkllleeee00el0....",
    ".0kkllldeee00el0....",
    ".0kkllllddddell0....",
    ".0kkllllllllllll00..",
    ".0k0lm0lllllllll00..",
    ".0k0k0llllllllllk0..",
    ".0kk0klllllllllk0...",
    "..0kkkkkkllllkkk0...",
    "...0jkkkkkkkkkj0....",
    "....0kkk00000j0.....",
    "....0kk0....0j0.....",
    ".....00......0......",
    "....................",
]
SKITTER = [
    "...................",
    ".........0.........",
    "........0o0........",
    "..000....000.......",
    "..0pp00....00......",
    "...000000...00.....",
    ".......0o00000.....",
    ".......0ppppp30....",
    "......0pp0000000...",
    ".....0op06660660...",
    ".....0pp06600600...",
    "...000pp06600600...",
    "..0pppppo0000000...",
    ".0p00ppppp0pp0p0...",
    ".00.0oppppppppp000.",
    "....0ooppppppp0oo0.",
    "....0ooop333o0.00..",
    "..000oooooo00......",
    ".00opo000000p0.....",
    "...000......0000...",
    "............0o0....",
    ".............00....",
    "...................",
]
# Walk cycle (4 frames): SpriteCook animate_game_art of SKITTER at 2x (asset 8cc36f64 -> 94b30e55),
# snapped (no greens), halved the same way at offset (0, 0); the first frame is the still pose above.
SKITTER_WALK = [
    [
        "...................",
        ".........0.........",
        "..000...0o00.......",
        "..0pp00..0.00......",
        "...000000...00.....",
        ".......0o00000.....",
        ".......0ppppp30....",
        "......00p0000000...",
        ".....00p00000000...",
        ".....0op06660660...",
        ".....0pp06600600...",
        ".....0pp06600600...",
        "....0pppo0000300...",
        "...0pppppp0pp0p0...",
        "..0ppoppppppppp00..",
        "..0o0ooppppppp0o0..",
        "...00ooop333o000...",
        ".....0ooooo00......",
        ".....0o00000.......",
        ".....000000........",
        ".....0o0o0.........",
        "......0.0..........",
        "...................",
        "...................",
        "...................",
    ],
    [
        "...................",
        "...................",
        ".........0.........",
        "...00...0o0........",
        "..0p0....00........",
        "..00p00....0.......",
        "....0000...00......",
        ".......00...00.....",
        ".......0o00000.....",
        ".......0ppppp30....",
        "......0pp0000000...",
        ".....0op06660660...",
        ".....0pp06600600...",
        ".....0pp06600600...",
        "....0pppo0000000...",
        "....0ppppp0pp0p0...",
        "...0p0ppppppppp0...",
        "....0ooppppppp00...",
        "....00oop333o0000..",
        ".....000ooo00......",
        "......0p0000.......",
        ".......000.........",
        ".......0o0.........",
        "........00.........",
        "...................",
    ],
    [
        "...................",
        ".........0.........",
        "........0o00.......",
        "..00000..0.00......",
        "..0p00000...00.....",
        "...0...0o00000.....",
        ".......0ppppp30....",
        "......0pp0000000...",
        ".....0op06660660...",
        ".....0pp06600600...",
        ".....0pp06600600...",
        "....0pppo0600600...",
        "....0ppppp0pp0p0...",
        "...0poppppppppp0...",
        "..0ppooppppppp0o0..",
        "..000ooop333o0oo0..",
        "..000ooooo0oo000...",
        "....0ooo00000......",
        "...0po0000000......",
        "...000....0........",
        "...0o0.............",
        "...00..............",
        "....0..............",
        "...................",
        "...................",
    ],
    [
        "...................",
        "...................",
        "...................",
        ".........0.........",
        "........0o0........",
        "..000....000.......",
        "..0pp00....00......",
        "...000000...00.....",
        ".......0o00000.....",
        ".......0ppppp30....",
        "......0pp0000000...",
        ".....0op06660660...",
        ".....0pp06600600...",
        "...000pp06600600...",
        "..0pppppo0000000...",
        ".0p00ppppp0pp0p0...",
        ".00.0oppppppppp000.",
        "....0ooppp00pp0oo0.",
        "....0ooop0..00.00..",
        "..000ooooo000......",
        ".00opo000000p0.....",
        "...000......0000...",
        "............0o0....",
        ".............00....",
        "...................",
    ],
]
SPITTER = [
    "....................",
    ".........0000.......",
    "........066660......",
    ".......06666660.....",
    ".....00666600660....",
    "....0706666006670...",
    "...079706666667790..",
    "...07990777777990...",
    "..079999900000990...",
    "..079999077777790...",
    "..0999907777777090..",
    ".07999900000777090..",
    ".07799900000777090..",
    ".0709a9000007770900.",
    ".070909088988770900.",
    "..0009990999980970..",
    "..077799900008970...",
    "...0777799999970....",
    "....077777777000....",
    "....07900000070.....",
    ".....00......0......",
    "....................",
]
# Mouth poses: SpriteCook animate_game_art of SPITTER at 2x (upload 1a6b6f52 -> 9922cc80), snapped (no
# greens), halved at offset (0, 0). Its frames 1-2 lost the mouth interior to background removal
# (holes), so the wide-open pose stays SPITTER above; frame 4 (shut) is the walking pose, frame 3
# (half open) eases the mouth shut after a spit.
SPITTER_SHUT = [
    ".......................",
    "..........0000.........",
    ".........066660........",
    "........06666660.......",
    "......00666600660......",
    ".....077666600660......",
    "....0790666600660......",
    "....07976666666670.....",
    "...079997666666790.....",
    "...079999766667990.....",
    "...0999999777799990....",
    "...0999990000009990....",
    "..099999997777799900...",
    ".099999999999999990700.",
    ".09077999999999999000..",
    ".000777999999999970....",
    "...077779999999770.....",
    "....0777777777770......",
    ".....077777777000......",
    ".....07900000070.......",
    "......00......0........",
    ".......................",
]
SPITTER_HALF = [
    "........................",
    "............00..........",
    "..........006600........",
    ".........0666660........",
    ".........06666660.......",
    "........0666600660......",
    ".......07666600660......",
    "......070666600660......",
    ".....07976666666670.....",
    ".....07997666666790.....",
    "....079999766667990.....",
    "....079999977779990.....",
    "....0999999999999990....",
    "...09999990q00009990....",
    "..0999999900000q9990000.",
    ".0999899998887779990700.",
    ".000077999999999999000..",
    "....0779999999999970....",
    "....077779999999770.....",
    ".....0777777777770......",
    "......07777777770.......",
    "......07900000070.......",
    ".......00......0........",
    "........................",
]
BLOATER = [
    "......................",
    "........0000..........",
    "......00cddd00........",
    "....00ddr000dr000.....",
    "...0ccd06660d06660....",
    "..0ccd066000d066000...",
    "..0ccd066000d06600d0..",
    "...0cd066666d06666d0..",
    "..0cddd00000d00000d0..",
    "..0cddddcdddddddc000..",
    ".0ccdddddcdddcdddd0d0.",
    ".0crdddddddddddded00..",
    ".0crrcbdcddddddddd0...",
    ".0ccccdddcdddddcdd0...",
    ".0ccccdddddddddddc0...",
    "..0ccccdcddddddddc0...",
    "...0bcccccdddddcc0....",
    "...0cdcccccccccc0b0...",
    "...0cc000cccc00000....",
    "...000...0000.........",
    "......................",
]

# --- Sheet 2 (Chomper; the generated Gnats were too big for 6-8 px and are not used) ----------
CHOMPER = [
    ".......................",
    "........0000...0000....",
    "......00uuuu000uuuu0...",
    ".....070000uuu0000uu0..",
    "....07066600u006660u0..",
    "...07u066060u066060uu0.",
    "..07uu046060u046060uu0.",
    "..07uuu0000uuu0000uuu0.",
    ".077uuuuuuuuuuuuuuuuu0.",
    ".07uuuuu0000000000000..",
    ".07uuuuu0660660660660..",
    ".07uuuu00000000000000..",
    ".077uuu000uuuuuuuuuu0..",
    ".070uuuuuuuuuuuuuuuu00.",
    ".070u0uuuuuuuuuuuuu0u0.",
    ".070707uuuuuuuuuuuu00..",
    "..070777uuuuuuuuuu70...",
    "...0777777uuuuuu770....",
    "....07777777777000.....",
    ".....07u000000070......",
    "......00.......0.......",
    ".......................",
]
# Charge pose (jaw wide open): the second Chomper on sheet 2, same head.
CHOMPER_CHARGE = [
    ".......................",
    "........0000...0000....",
    "......00uuuu000uuuu0...",
    ".....070000uuu0000uu0..",
    "....07066600u006660u0..",
    "...07u066060u066060uu0.",
    "..07uu046060u046060uu0.",
    "..07uuu0000uuu0000uuu0.",
    ".077uuuuuuuuuuuuuuuuu0.",
    "..007uuuuuu0005050000..",
    "..07uuuuuu0500000000...",
    "..07uuuuu00000000000...",
    "..07uuuuu00000000000...",
    "..07uuuu000000000000...",
    "..07uuuu000000000000...",
    "..070uuu000000000000...",
    "..070u0uu089999980000..",
    "..070u0uu080990900000..",
    "...07077uu050050500u0..",
    "...077777uuu00000uu0...",
    "....07777777uuuuu70....",
    ".....07770000000000....",
    "......0u0......070.....",
    ".......0........0......",
    ".......................",
]

# --- Hand-pixelled Gnat: interiors only, the 1 px INK outline is added around them ------------
GNAT_BODY = [  # eyeball, pupil looking right
    ".665.",
    "66500",
    "65500",
    ".444.",
]
GNAT_WINGS = [  # (frame) -> wing pixels relative to the body's top-left, MIST
    [(-2, -2), (-1, -1), (6, -2), (5, -1)],  # up
    [(-2, 1), (-1, 1), (6, 1), (5, 1)],  # out
]

# Eye boxes (x0, y0, x1, y1 inclusive, lid colour, lid line row) per sheet, in frame pixels.
EYES = {
    "blob": [(6, 7, 14, 12, "l", 10)],
    "skitter": "p",  # walk cycle: eyes found per frame (eye_boxes)
    "spitter": [(8, 3, 16, 11, "9", 7)],  # in the shut-mouth frame (feet-aligned, 24x24)
    "bloater": [(7, 3, 11, 8, "d", 6), (12, 3, 17, 8, "d", 6)],
    "gnat": [(3, 3, 7, 6, "4", 5)],
    "chomper": [(6, 3, 11, 7, "u", 5), (13, 3, 18, 7, "u", 5)],
}
OPEN = {"blob": [BLOB], "skitter": SKITTER_WALK, "spitter": [SPITTER_SHUT], "bloater": [BLOATER], "chomper": [CHOMPER]}
# Extra poses after the closed frames, named in the sidecar's "poses" (name -> frame index).
POSES = {"chomper": {"charge": CHOMPER_CHARGE}, "spitter": {"mouth_open": SPITTER, "mouth_half": SPITTER_HALF}}
# How frames of different sizes line up: "top" (top-left, the Chomper's head stays put) or
# "feet" (bottom centre).
ALIGN = {"spitter": "feet"}
# Loop speed of the open-eye frames (static sheets have a 1-frame loop; the number is unused there
# but the sheet format wants a positive fps).
FPS = {"gnat": 12.0, "skitter": 12.0}
STATIC_FPS = 8.0
SOURCE = {
    "blob": {"generator": "SpriteCook", "asset_id": SHEET_1, "cell": "top-left", "hand_edit": "tools/art/critters.py"},
    "skitter": {"generator": "SpriteCook", "asset_id": SHEET_1, "cell": "top-right", "walk": {"generator": "SpriteCook animate_game_art", "upload": "8cc36f64-50de-4c83-bd4e-ab654ab5b7c5", "asset_id": "94b30e55-8b4b-4de4-ae04-36655235c033", "frames": 4}, "hand_edit": "tools/art/critters.py"},
    "spitter": {"generator": "SpriteCook", "asset_id": SHEET_1, "cell": "bottom-left", "mouth": {"generator": "SpriteCook animate_game_art", "upload": "1a6b6f52-20cc-44b6-9cba-55bc583edc54", "asset_id": "9922cc80-978a-49e6-b6c1-5f726c54a8dd", "frames_used": [3, 4]}, "hand_edit": "tools/art/critters.py"},
    "bloater": {"generator": "SpriteCook", "asset_id": SHEET_1, "cell": "bottom-right", "hand_edit": "tools/art/critters.py"},
    "chomper": {"generator": "SpriteCook", "asset_id": SHEET_2, "cell": "top-left + bottom-left", "hand_edit": "tools/art/critters.py"},
    "gnat": {"generator": "hand-pixelled", "hand_edit": "tools/art/critters.py"},
}


def grid(rows):
    w = max(len(r) for r in rows)
    g = np.full((len(rows), w), -1, int)
    for y, r in enumerate(rows):
        for x, ch in enumerate(r):
            if ch not in ". ":
                g[y, x] = int(ch, 32)
    return g


def outlined(g):
    """Adds a 1 px INK outline (4-neighbours) around the opaque pixels of g, plus a 1 px border."""
    g = np.pad(g, 2, constant_values=-1)
    m = g >= 0
    ring = ~m & (np.roll(m, 1, 0) | np.roll(m, -1, 0) | np.roll(m, 1, 1) | np.roll(m, -1, 1))
    g[ring] = 0
    return g


def gnat_frames():
    out = []
    for wings in GNAT_WINGS:
        g = np.full((12, 13), -1, int)
        ox, oy = 4, 4
        g[oy:oy + 4, ox:ox + 5] = grid(GNAT_BODY)
        for dx, dy in wings:
            g[oy + dy, ox + dx] = 4
        g = outlined(g)
        ys, xs = np.nonzero(g >= 0)
        out.append(g)
    # One crop for both frames.
    ys = np.concatenate([np.nonzero(f >= 0)[0] for f in out])
    xs = np.concatenate([np.nonzero(f >= 0)[1] for f in out])
    return [f[ys.min() - 1:ys.max() + 2, xs.min() - 1:xs.max() + 2] for f in out]


def closed(g, boxes):
    g = g.copy()
    m = g >= 0
    edge = m & ~(np.roll(m, 1, 0) & np.roll(m, -1, 0) & np.roll(m, 1, 1) & np.roll(m, -1, 1))
    for x0, y0, x1, y1, lid, line in boxes:
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                if m[y, x] and not edge[y, x]:
                    g[y, x] = 0 if y == line and x0 < x < x1 else int(lid, 32)
    return g


def eye_boxes(g, lid):
    """Eye boxes found in a frame: each 4-connected patch of WHITE (the eye whites), grown by 1 px
    to take in its INK rim, lid line through its middle row. For animated frames, where the head
    moves and fixed boxes would miss the eyes."""
    white = g == 6
    seen = np.zeros_like(white)
    boxes = []
    for y, x in zip(*np.nonzero(white)):
        if seen[y, x]:
            continue
        stack, pts = [(y, x)], []
        seen[y, x] = True
        while stack:
            cy, cx = stack.pop()
            pts.append((cy, cx))
            for ny, nx in ((cy + 1, cx), (cy - 1, cx), (cy, cx + 1), (cy, cx - 1)):
                if 0 <= ny < g.shape[0] and 0 <= nx < g.shape[1] and white[ny, nx] and not seen[ny, nx]:
                    seen[ny, nx] = True
                    stack.append((ny, nx))
        ys = [p[0] for p in pts]
        xs = [p[1] for p in pts]
        y0, y1, x0, x1 = min(ys) - 1, max(ys) + 1, min(xs) - 1, max(xs) + 1
        boxes.append((x0, y0, x1, y1, lid, (y0 + y1 + 1) // 2))
    return boxes


def to_rgba(g, pal):
    a = np.zeros(g.shape + (4,), np.uint8)
    on = g >= 0
    a[on, :3] = pal[g[on]]
    a[on, 3] = 255
    return a


def build():
    """name -> (frames, number of open frames, {pose: frame index})."""
    frames = {k: [grid(f) for f in v] for k, v in OPEN.items()}
    frames["gnat"] = gnat_frames()
    sheets = {}
    for name, opened in frames.items():
        extra = [grid(f) for f in POSES.get(name, {}).values()]
        h = max(f.shape[0] for f in opened + extra)
        w = max(f.shape[1] for f in opened + extra)
        if ALIGN.get(name) == "feet":
            pad = lambda f: np.pad(f, ((h - f.shape[0], 0), ((w - f.shape[1]) // 2, w - f.shape[1] - (w - f.shape[1]) // 2)), constant_values=-1)  # noqa: E731
        else:
            pad = lambda f: np.pad(f, ((0, h - f.shape[0]), (0, w - f.shape[1])), constant_values=-1)  # noqa: E731
        opened = [pad(f) for f in opened]
        # EYES as a string = the lid colour, eyes found per frame (animated walk cycles).
        shut = [closed(f, eye_boxes(f, EYES[name]) if isinstance(EYES[name], str) else EYES[name]) for f in opened]
        n = len(opened)
        poses = {p: 2 * n + i for i, p in enumerate(POSES.get(name, {}))}
        sheets[name] = (opened + shut + [pad(f) for f in extra], n, poses)
    return sheets


def check(name, frames):
    for f in frames:
        if (f[0] >= 0).any() or (f[-1] >= 0).any() or (f[:, 0] >= 0).any() or (f[:, -1] >= 0).any():
            raise SystemExit(f"{name}: a frame has no empty 1 px border")
        if (f == 31).any():
            raise SystemExit(f"{name}: uses the reserved enemy-shot magenta")
        m = f >= 0
        inner = np.pad(m, 1)[1:-1, 1:-1]
        ring = m & ~(np.roll(m, 1, 0) & np.roll(m, -1, 0) & np.roll(m, 1, 1) & np.roll(m, -1, 1))
        bad = ring & (f != 0) & inner
        if bad.sum() > 0:
            raise SystemExit(f"{name}: outline pixels not INK at (x, y) {list(zip(*np.nonzero(bad)[::-1]))}")


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--out", default="assets/enemies")
    ap.add_argument("--preview")
    args = ap.parse_args()
    pal = ps.load_palette(ps.DEFAULT_PALETTE)
    os.makedirs(args.out, exist_ok=True)
    sheets = build()
    previews = []
    for name, (frames, n, poses) in sheets.items():
        check(name, frames)
        h, w = frames[0].shape
        strip = np.concatenate([to_rgba(f, pal) for f in frames], axis=1)
        Image.fromarray(strip).save(os.path.join(args.out, name + ".png"))
        ys, xs = np.nonzero(frames[0] >= 0)
        meta = {
            "format": "game.sheet", "frame_w": w, "frame_h": h, "frames": len(frames), "fps": FPS.get(name, STATIC_FPS),
            "loop": n, "blink": n, "origin": [int(round((xs.min() + xs.max()) / 2)), int(ys.max())],
            "poses": poses, "source": SOURCE[name],
        }
        with open(os.path.join(args.out, name + ".json"), "w") as f:
            json.dump(meta, f, indent="\t")
            f.write("\n")
        previews.append(strip)
        print("%-8s %2dx%-2d x%d" % (name, w, h, len(frames)))
    if args.preview:
        os.makedirs(args.preview, exist_ok=True)
        W = max(p.shape[1] for p in previews)
        H = sum(p.shape[0] + 2 for p in previews)
        sheet = Image.new("RGBA", (W, H), (47, 122, 52, 255))
        y = 0
        for p in previews:
            sheet.alpha_composite(Image.fromarray(p), (0, y))
            y += p.shape[0] + 2
        sheet.resize((W * 8, H * 8), Image.NEAREST).save(os.path.join(args.preview, "critters_x8.png"))


if __name__ == "__main__":
    main()
