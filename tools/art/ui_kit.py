#!/usr/bin/env python3
"""Cut the UI parts out of the SpriteCook UI-kit component sheets, snapped to the palette and
shrunk to game scale (one shrink factor for every sheet, so every part keeps the same pixel size).

    python3 tools/art/ui_kit.py RAW/kit1_sheet1.png RAW/kit2_sheet1.png --out assets/ui [--preview DIR]

The sheets are kit 1 (menus) and kit 2 (in-run), asset ids in docs/spritecook-assets.json
("ui_kit1_sheet1", "ui_kit2_sheet1"). PARTS / PARTS2 hold each part's rectangle on its 2048x2048
sheet (from extract_ui_kit_components, renamed after what the part really is). The art pixel is
about 10.5 source pixels (outlines run 10-12).

Every part first loses the generator's light MIST/GRAY fringe along its bottom edge (it reads as a
white outline in game), then is trimmed to its pixels.

Parts in SHIP are written to --out (assets/ui/): sprites as they are, 9-slice templates cut from
the shrunk part as its corners plus one clean middle column and row (at "mid", a spot with no
rivet), so a template is (left + 1 + right) x (top + 1 + bottom) pixels and stretches to any size
without scaling any pixel. The slices and recolor ramps go to assets/ui/ui_kit.json, read by
scripts/ui/ui_art.gd. Without --all only SHIP is written.
"""
import json
import argparse
import os
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
import palette_snap as ps  # noqa: E402
from spritecook_shrink import shrink_mode, snap  # noqa: E402

SCALE = 10.5  # source pixels per art pixel

# name: (x, y, w, h, slice [left, top, right, bottom] or None)
PARTS = {
    "button_green": (40, 36, 759, 214, None),
    "button_grey": (829, 35, 761, 215, None),
    "button_green_pressed": (42, 287, 756, 152, None),
    "button_grey_pressed": (830, 287, 756, 152, None),
    "square_button": (1631, 45, 170, 186, None),
    "square_button_pressed": (1834, 45, 167, 186, None),
    "arrow_left": (1627, 276, 169, 196, None),
    "arrow_right": (1827, 276, 171, 197, None),
    "window": (34, 639, 1039, 748, None),
    "ribbon": (1122, 653, 868, 215, None),
    "tag": (1357, 864, 393, 109, None),
    "bar_track": (1099, 990, 767, 117, None),
    "tile": (1098, 1125, 280, 288, None),
    "tile_selected": (1395, 1124, 295, 298, None),
    "tile_locked": (1713, 1127, 295, 304, None),
    "map_card": (39, 1415, 1030, 352, None),
    "pip_on": (1115, 1470, 99, 109, None),
    "pip_off": (1447, 1470, 99, 108, None),
    "toggle_on": (1644, 1476, 204, 107, None),
    "toggle_off": (1643, 1601, 199, 106, None),
    "scroll_track": (1776, 1751, 86, 267, None),
    "scroll_thumb": (1910, 1781, 65, 204, None),
    "ad_icon": (1462, 1774, 205, 209, None),
    "padlock": (477, 1813, 113, 154, None),
    "coin": (261, 1821, 136, 147, None),
    "plate": (665, 1824, 339, 148, None),
    "plate_green": (1050, 1825, 349, 150, None),
    "dot": (72, 1845, 86, 96, None),
}
# Kit 2 (in-run) sheet.
PARTS2 = {
    "xp_frame": (53, 65, 1114, 128, None),
    "xp_fill": (1210, 91, 780, 76, None),
    "hp_frame": (54, 229, 521, 125, None),
    "hp_fill": (622, 253, 470, 80, None),
    "boss_frame": (54, 391, 1261, 131, None),
    "boss_fill": (1360, 420, 627, 82, None),
    "name_plate": (465, 551, 386, 115, None),
    "banner": (55, 680, 1219, 246, None),
    "pause": (1609, 847, 202, 207, None),
    "card": (55, 959, 406, 789, None),
    "card_gold": (510, 959, 404, 789, None),
    "new_badge": (1038, 959, 322, 107, None),
    "stick_base": (1495, 1091, 460, 471, None),
    "action": (974, 1101, 452, 230, None),
    "action_pressed": (974, 1363, 452, 236, None),
    "stick_knob": (1633, 1577, 194, 206, None),
    "arrow": (1133, 1620, 101, 158, None),
    "heart": (91, 1822, 154, 151, None),
    "clock": (338, 1820, 138, 146, None),
    "skull": (587, 1820, 134, 145, None),
    "coin2": (827, 1821, 136, 145, None),
    "key": (1066, 1821, 144, 147, None),
    "die": (1314, 1821, 140, 147, None),
    "ffwd": (1566, 1836, 131, 123, None),
    "xmark": (1809, 1829, 126, 134, None),
}


# Written to --out. name: (source part, kind, info)
#   "sprite": as is.
#   "slice": [left, top, right, bottom] borders, "mid": [column, row] of the clean middle.
#   "ramp": palette names [light, face, dark] that ui_art.gd swaps for a face colour's ramp,
#   "fill": the palette name of the inside that ui_art.gd swaps for a fill colour.
SHIP = {
    "button": ("button_grey", "slice", {"slice": [6, 7, 6, 8], "mid": [36, 9], "ramp": ["MIST", "GRAY", "NIGHT"]}),
    "button_small": ("button_grey", "slice", {"slice": [3, 3, 3, 4], "mid": [36, 9], "ramp": ["MIST", "GRAY", "NIGHT"]}),
    "window": ("window", "slice", {"slice": [7, 7, 7, 9], "mid": [49, 30], "fill": "NIGHT"}),
    "row": ("plate", "slice", {"slice": [5, 5, 5, 5], "mid": [16, 6], "fill": "SHADE"}),
    "ribbon": ("ribbon", "slice", {"slice": [12, 9, 12, 9], "mid": [41, 9]}),
    "tag": ("tag", "slice", {"slice": [4, 4, 4, 4], "mid": [18, 4], "ramp": ["SKY", "BLUE", "OCEAN"]}),
    "tile": ("tile", "slice", {"slice": [5, 5, 5, 5], "mid": [13, 12]}),
    "tile_selected": ("tile_selected", "slice", {"slice": [5, 5, 5, 5], "mid": [13, 12]}),
    "pip_on": ("pip_on", "sprite", {}),
    "pip_off": ("pip_off", "sprite", {}),
    "toggle_on": ("toggle_on", "sprite", {}),
    "toggle_off": ("toggle_off", "sprite", {}),
    "coin": ("coin", "sprite", {}),
    "padlock": ("padlock", "sprite", {}),
    "dot": ("dot", "sprite", {}),
    # Kit 2 (in-run).
    "bar": ("xp_frame", "slice", {"slice": [4, 4, 4, 4], "mid": [50, 5]}),
    "boss_bar": ("boss_frame", "slice", {"slice": [4, 4, 4, 4], "mid": [60, 5]}),
    "name_plate": ("name_plate", "slice", {"slice": [4, 4, 4, 4], "mid": [18, 5]}),
    "banner": ("banner", "slice", {"slice": [7, 7, 7, 7], "mid": [58, 11]}),
    "card": ("card", "slice", {"slice": [6, 6, 6, 7], "mid": [19, 30]}),
    "card_gold": ("card_gold", "slice", {"slice": [6, 6, 6, 7], "mid": [19, 30]}),
    "action": ("action", "slice", {"slice": [4, 5, 5, 6], "mid": [20, 10]}),
    "action_pressed": ("action_pressed", "slice", {"slice": [4, 5, 5, 6], "mid": [20, 10]}),
    "new_badge": ("new_badge", "slice", {"slice": [2, 4, 2, 4], "mid": [15, 5]}),
    "pause": ("pause", "sprite", {}),
    "stick_base": ("stick_base", "sprite", {}),
    "stick_knob": ("stick_knob", "sprite", {}),
    "heart": ("heart", "sprite", {}),
    "clock": ("clock", "sprite", {}),
    "skull": ("skull", "sprite", {}),
    "key": ("key", "sprite", {}),
    "die": ("die", "sprite", {}),
    "ffwd": ("ffwd", "sprite", {}),
    "xmark": ("xmark", "sprite", {}),
}
# Hand touch-ups after shrinking: name -> [(x, y, palette index)]. The pips get a 1px top-left
# glint like the buttons' bevel (as plain blocks they also read as upscaled to check_assets.py).
TOUCH = {
    "pip_on": [(1, 1, 5)],
    "pip_off": [(1, 1, 2)],
}


def palette_names():
    import re
    src = open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "scripts", "core", "palette.gd")).read()
    return {int(i): n for n, i in re.findall(r"^const ([A-Z_]+) := (\d+)$", src, re.M)}


def cut(sheet, pal, allowed, rect):
    x, y, w, h = rect[:4]
    a = snap(sheet.crop((x, y, x + w, y + h)), pal, allowed)
    a = shrink_mode(a, max(1, round(w / SCALE)), max(1, round(h / SCALE)))
    return trim(defringe(a, pal))


def defringe(a, pal):
    """Clears MIST/GRAY pixels in the bottom 5 rows that have nothing under them (bottom-up)."""
    light = {tuple(pal[3]), tuple(pal[4])}
    a = a.copy()
    h = a.shape[0]
    for y in range(h - 1, max(-1, h - 6), -1):
        for x in range(a.shape[1]):
            if a[y, x, 3] and tuple(a[y, x, :3]) in light and (y == h - 1 or not a[y + 1, x, 3]):
                a[y, x] = 0
    return a


def trim(a):
    ys, xs = np.nonzero(a[..., 3])
    return a[ys.min():ys.max() + 1, xs.min():xs.max() + 1]


def template(a, sl, mid):
    """Corners + one middle column/row: rows [0, top) + mid row + [h - bottom, h), same for columns."""
    left, top, right, bottom = sl
    h, w = a.shape[:2]
    rows = list(range(top)) + [mid[1]] + list(range(h - bottom, h))
    cols = list(range(left)) + [mid[0]] + list(range(w - right, w))
    assert top <= mid[1] < h - bottom and left <= mid[0] < w - right, "mid inside the borders"
    return a[np.ix_(rows, cols)]


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("sheets", nargs="+", help="kit 1 sheet, then kit 2 sheet")
    ap.add_argument("--out", required=True)
    ap.add_argument("--preview", help="also write a contact sheet (8x) of every part here")
    ap.add_argument("--palette", default=ps.DEFAULT_PALETTE)
    ap.add_argument("--all", action="store_true", help="also write every cut part (for review)")
    args = ap.parse_args()
    pal = ps.load_palette(args.palette)
    allowed = ps.allowed_indices(pal, set())
    sheets = [Image.open(p).convert("RGBA") for p in args.sheets]
    ap_all = args.all
    os.makedirs(args.out, exist_ok=True)
    parts = {name: cut(sheets[0], pal, allowed, rect) for name, rect in PARTS.items()}
    if len(sheets) > 1:
        parts.update({name: cut(sheets[1], pal, allowed, rect) for name, rect in PARTS2.items()})
    names = palette_names()
    meta = {}
    out = parts if ap_all else {}
    for name, (src, kind, info) in SHIP.items():
        a = parts[src]
        entry = {k: v for k, v in info.items() if k != "mid"}
        if kind == "slice":
            a = template(a, info["slice"], info["mid"])
        for x, y, i in TOUCH.get(name, []):
            a = a.copy()
            a[y, x, :3] = pal[i]
            a[y, x, 3] = 255
        out[name] = a
        meta[name] = entry
    for name, a in out.items():
        Image.fromarray(a).save(os.path.join(args.out, name + ".png"))
        print("%-22s %3dx%-3d" % (name, a.shape[1], a.shape[0]))
    with open(os.path.join(args.out, "ui_kit.json"), "w") as f:
        json.dump(meta, f, indent="\t")
        f.write("\n")
    parts = out
    if args.preview:
        k, pad = 8, 4
        cols = 4
        names = list(parts)
        cw = max(p.shape[1] for p in parts.values()) + pad
        ch = max(p.shape[0] for p in parts.values()) + pad
        rows = (len(names) + cols - 1) // cols
        board = Image.new("RGBA", (cols * cw * k, rows * ch * k), (255, 0, 255, 255))
        for i, n in enumerate(names):
            im = Image.fromarray(parts[n]).resize((parts[n].shape[1] * k, parts[n].shape[0] * k), Image.NEAREST)
            board.alpha_composite(im, ((i % cols) * cw * k, (i // cols) * ch * k))
        board.convert("RGB").save(os.path.join(args.preview, "ui_kit_parts.png"))


if __name__ == "__main__":
    main()
