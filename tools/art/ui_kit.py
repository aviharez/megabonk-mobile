#!/usr/bin/env python3
"""Cut the UI parts out of the SpriteCook UI-kit component sheets, snapped to the palette and
shrunk to game scale (one shrink factor for every sheet, so every part keeps the same pixel size).

    python3 tools/art/ui_kit.py RAW/kit1_sheet1.png RAW/kit2_sheet1.png RAW/kit3_sheet1.png --out assets/ui [--preview DIR]

The sheets are kit 1 (menus), kit 2 (in-run) and kit 3 (Phase 9 dark UI), asset ids in
docs/spritecook-assets.json ("ui_kit1_sheet1", "ui_kit2_sheet1", "ui_kit3_sheet1"); all three are
needed, since ui_kit.json is rewritten from every part. PARTS / PARTS2 hold each part's rectangle on its 2048x2048
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


# Kit 3 (Phase 9 dark design system, home) sheet. Drawn chunkier: an art pixel is about 16 source
# pixels (outline runs of 15 + 1), so SCALE3 keeps 1 art pixel = 1 UI pixel like kits 1 and 2.
# Its alpha is soft (a dark glow around every part, no binary-alpha source to fall back on), so
# pixels under CUTOFF3 are dropped before snapping.
SCALE3 = 16
CUTOFF3 = 200
PARTS3 = {
    "play_button": (49, 30, 643, 279, None),
    "button_orange": (730, 46, 618, 257, None),
    "button_off": (1387, 42, 612, 267, None),
    "nav_blue": (44, 353, 313, 356, None),
    "nav_green": (385, 353, 314, 356, None),
    "nav_orange": (727, 353, 313, 356, None),
    "nav_purple": (1068, 353, 313, 356, None),
    "nav_blue_pressed": (44, 739, 313, 356, None),
    "nav_green_pressed": (385, 738, 314, 357, None),
    "nav_orange_pressed": (727, 739, 313, 356, None),
    "nav_purple_pressed": (1068, 738, 313, 357, None),
    "coin_plate": (1451, 355, 536, 204, None),
    "gear_button": (1452, 586, 247, 230, None),
    "gear_button_pressed": (1740, 586, 247, 230, None),
    "ribbon_red": (1392, 853, 624, 217, None),
    "ad_sticker": (1769, 1140, 192, 187, None),
    "side_panel": (50, 1141, 643, 828, None),
    "alert": (1509, 1153, 172, 174, None),
    "seg_track": (769, 1181, 645, 139, None),
    "seg_fill": (784, 1357, 396, 118, None),
    "coin_big": (1467, 1364, 214, 214, None),
    "gear": (1749, 1364, 222, 220, None),
    "sack": (1189, 1580, 292, 357, None),
    "padlock_big": (809, 1588, 284, 349, None),
    "mystery": (1595, 1618, 314, 319, None),
}

# Kit 3b (Phase 9, level-up + HUD; child of kit 3) sheet: art pixel about 13 source px, soft alpha.
SCALE3B = 13
PARTS3B = {
    "level_ring": (33, 25, 192, 190, None),
    "pause_btn": (1815, 25, 200, 190, None),
    "timer_plate": (1443, 32, 349, 144, None),
    "heart": (887, 36, 121, 113, None),
    "hp_track": (1025, 42, 389, 93, None),
    "xp_track": (246, 44, 603, 95, None),
    "hp_fill": (1033, 150, 376, 62, None),
    "xp_fill": (254, 154, 472, 60, None),
    "header": (79, 241, 931, 174, None),
    "coin": (1418, 253, 127, 130, None),
    "skull": (1612, 253, 126, 130, None),
    "clock": (1814, 253, 136, 130, None),
    "sticker": (1070, 273, 196, 115, None),
    "card_red": (1101, 420, 903, 228, None),
    "window": (41, 432, 1023, 695, None),
    "card_blue": (1101, 659, 902, 220, None),
    "card_gold": (1100, 890, 904, 237, None),
    "frame_red": (52, 1154, 252, 257, None),
    "frame_blue": (336, 1154, 251, 257, None),
    "frame_green": (619, 1154, 251, 257, None),
    "frame_purple": (903, 1154, 252, 257, None),
    "frame_gold": (1187, 1154, 252, 257, None),
    "pip_on": (1498, 1230, 98, 99, None),
    "pip_off": (1650, 1230, 97, 99, None),
    "sticker_b": (1805, 1235, 199, 116, None),
    "bubble": (1857, 1448, 123, 124, None),
    "reroll": (47, 1460, 272, 263, None),
    "reroll_pressed": (340, 1460, 279, 264, None),
    "skip": (654, 1461, 268, 262, None),
    "skip_pressed": (939, 1462, 269, 261, None),
    "banish": (1240, 1461, 268, 263, None),
    "banish_pressed": (1530, 1461, 269, 262, None),
    "sticker_c": (1838, 1608, 171, 116, None),
    "info_bar": (44, 1755, 1961, 252, None),
}


# Written to --out. name: (source part, kind, info)
#   "sprite": as is.
#   "slice": [left, top, right, bottom] borders, "mid": [column, row] of the clean middle.
#   "ramp": palette names [light, face, dark] that ui_art.gd swaps for a face colour's ramp,
#   "rows": only these rows of the source part (before slicing).
#   "grid": hand-pixelled here (GRIDS), where the sheet's art doesn't survive the cut.
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
    # Kit 3 (Phase 9 dark UI). The second row of nav tiles on the sheet only differs by noise
    # (4-26 px), so there is one tile per colour; pressed = the usual 1px sink.
    "play_button": ("k3_play_button", "slice", {"slice": [4, 4, 4, 4], "mid": [20, 8]}),
    "button_orange": ("k3_button_orange", "slice", {"slice": [4, 4, 4, 3], "mid": [19, 7]}),
    "button_off": ("k3_button_off", "slice", {"slice": [4, 4, 4, 4], "mid": [19, 8]}),
    "nav_blue": ("k3_nav_blue", "slice", {"slice": [2, 2, 2, 9], "mid": [9, 6]}),
    "nav_green": ("k3_nav_green", "slice", {"slice": [2, 2, 2, 9], "mid": [9, 6]}),
    "nav_orange": ("k3_nav_orange", "slice", {"slice": [2, 2, 2, 9], "mid": [9, 6]}),
    "nav_purple": ("k3_nav_purple", "slice", {"slice": [2, 2, 2, 9], "mid": [9, 6]}),
    "plate_dark": ("k3_coin_plate", "slice", {"slice": [2, 2, 3, 3], "mid": [20, 6]}),
    "panel_dark": ("k3_side_panel", "slice", {"slice": [3, 4, 3, 4], "mid": [20, 4]}),
    "icon_button": ("k3_gear_button", "slice", {"slice": [2, 2, 2, 2], "mid": [3, 3]}),
    "ribbon_red": ("k3_ribbon_red", "slice", {"slice": [10, 7, 10, 6], "mid": [25, 7]}),
    "track_dark": ("k3_seg_track", "slice", {"slice": [2, 3, 2, 3], "mid": [5, 3]}),
    "fill_gold": ("k3_seg_fill", "slice", {"slice": [2, 2, 2, 2], "mid": [12, 3], "ramp": ["BUTTER", "GOLD", "ORANGE"]}),
    # the blue nav tile's face without its label strip: a square kind/rarity frame, any colour
    "icon_face": ("k3_nav_blue", "slice", {"slice": [2, 2, 2, 2], "mid": [9, 6], "rows": [*range(14), 21], "ramp": ["SKY", "BLUE", "OCEAN"]}),
    "seg_track": ("k3_seg_track", "sprite", {}),
    "gear_button": ("k3_gear_button", "sprite", {}),
    "ad_sticker": ("k3_ad_sticker", "sprite", {}),
    "alert": ("k3_alert", "sprite", {}),
    "star": (None, "grid", {"grid": "STAR"}),
    "coin_big": ("k3_coin_big", "sprite", {}),
    "gear": ("k3_gear", "sprite", {}),
    "sack": ("k3_sack", "sprite", {}),
    "padlock_big": ("k3_padlock_big", "sprite", {}),
    "mystery": ("k3_mystery", "sprite", {}),
    # Kit 3b (level-up + HUD). One template per colour family, recoloured through its ramp
    # (cards and icon frames are the red ones; the gold card's glow snapped to BARK / WOOD).
    # "mirror": the right border is the left one flipped (the sheet's red and blue cards have
    # the New sticker fused over their top-right corner, the window's right edge is ragged).
    "lv_window": ("k3b_window", "slice", {"slice": [6, 8, 6, 6], "mid": [40, 20], "mirror": True}),
    "lv_header": ("k3b_header", "slice", {"slice": [3, 3, 3, 4], "mid": [20, 5], "mirror": True}),
    "lv_card": ("k3b_card_red", "slice", {"slice": [3, 3, 3, 3], "mid": [30, 8], "rows": list(range(1, 18)),
                                          "mirror": True, "recolor": {"WINE": "BLOOD"}, "ramp": ["SALMON", "RED", "BLOOD"]}),
    "lv_frame": ("k3b_frame_red", "slice", {"slice": [2, 2, 2, 3], "mid": [9, 9], "ramp": ["SALMON", "RED", "BLOOD"]}),
    "lv_sticker": ("k3b_sticker", "slice", {"slice": [2, 2, 2, 2], "mid": [7, 4], "ramp": ["PINK", "PURPLE", "PLUM"]}),
    "lv_bubble": ("k3b_bubble", "sprite", {}),
    "lv_pip_on": ("k3b_pip_on", "sprite", {}),
    "lv_pip_off": ("k3b_pip_off", "sprite", {}),
    # icons cut out of the action buttons (the pressed ones for skip / banish: there the face is a
    # shade darker than the icon, on the normal ones they share colours)
    "lv_die": ("k3b_reroll", "icon", {"face": ["BLUE", "OCEAN", "DEEP_BLUE"]}),
    # the skip / banish icons share their button's colours on the sheet, so cut out they lose
    # their shape; hand-pixelled after the sheet's (lighter fill so they read on the face)
    "lv_ffwd": (None, "grid", {"grid": "FFWD"}),
    "lv_x": (None, "grid", {"grid": "XMARK"}),
    "info_bar": ("k3b_info_bar", "slice", {"slice": [3, 3, 3, 3], "mid": [60, 14], "mirror": True}),
    "info_icon": ("k3b_info_bar", "crop", {"rect": [4, 4, 12, 11], "drop": ["NIGHT"]}),
    "hud_track": ("k3b_xp_track", "slice", {"slice": [2, 2, 2, 2], "mid": [20, 3], "mirror": True}),
    "hud_fill": ("k3b_xp_fill", "slice", {"slice": [1, 1, 1, 1], "mid": [17, 2], "mirror": True, "ramp": ["BUTTER", "GOLD", "ORANGE"]}),
    "hud_timer": ("k3b_timer_plate", "slice", {"slice": [3, 2, 3, 2], "mid": [20, 5], "mirror": True}),
    "hud_ring": ("k3b_level_ring", "sprite", {}),
    "hud_pause": ("k3b_pause_btn", "sprite", {}),
    "hud_heart": ("k3b_heart", "sprite", {}),
    "hud_coin": ("k3b_coin", "sprite", {}),
    "hud_skull": ("k3b_skull", "sprite", {}),
    "hud_clock": ("k3b_clock", "sprite", {}),
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


def cut(sheet, pal, allowed, rect, scale=SCALE, cutoff=None):
    x, y, w, h = rect[:4]
    im = sheet.crop((x, y, x + w, y + h))
    if cutoff is not None:
        c = np.array(im)
        c[..., 3] = np.where(c[..., 3] >= cutoff, 255, 0)
        im = Image.fromarray(c)
    a = snap(im, pal, allowed)
    a = shrink_mode(a, max(1, round(w / scale)), max(1, round(h / scale)))
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


# Hand-pixelled parts: one palette index per character (base 32: 0 INK ... 9 RED, a SALMON,
# c ORANGE, d GOLD, e BUTTER), "." transparent.
GRIDS = {
    # the progress star (the sheet's is 7 px and reads as a blob once shrunk)
    "STAR": [
        "....0....",
        "...0e0...",
        "..0eed0..",
        "0eeedddd0",
        ".0edddc0.",
        "..0dddc0.",
        ".0dd0dc0.",
        "0cc0.0cc0",
        "000...000",
    ],
    "FFWD": [
        "0....0......",
        "00...00.....",
        "0e0..0e0....",
        "0ee0.0ee0...",
        "0eee00eee0..",
        "0eeee0eeee0.",
        "0eed00eed0..",
        "0ed0.0ed0...",
        "0d0..0d0....",
        "00...00.....",
        "0....0......",
    ],
    "XMARK": [
        ".00.....00.",
        "0aa0...0aa0",
        "0aaa0.0aaa0",
        ".0aaa0aaa0.",
        "..0aaaaa0..",
        "...0aaa0...",
        "..0aaaaa0..",
        ".0aa909aa0.",
        "0a990.0a990",
        "0990...0990",
        ".00.....00.",
    ],
}


def grid(pal, rows):
    a = np.zeros((len(rows), len(rows[0]), 4), np.uint8)
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch != ".":
                a[y, x, :3], a[y, x, 3] = pal[int(ch, 32)], 255
    return a


def icon_out(a, face, inset=2):
    """The icon baked into a square button: drops the outline + `inset` - 1 face pixels, then
    flood-fills from the edge through the button's `face` colours and clears them, so only the
    icon is left."""
    a = a[inset:-inset, inset:-inset].copy()
    h, w = a.shape[:2]
    is_face = np.zeros((h, w), bool)
    for c in face:
        is_face |= (a[..., :3] == c).all(2)
    is_face &= a[..., 3] > 0
    seen = np.zeros((h, w), bool)
    stack = [(y, x) for y in range(h) for x in (0, w - 1)] + [(y, x) for x in range(w) for y in (0, h - 1)]
    while stack:
        y, x = stack.pop()
        if not (0 <= y < h and 0 <= x < w) or seen[y, x] or not is_face[y, x]:
            continue
        seen[y, x] = True
        stack += [(y + 1, x), (y - 1, x), (y, x + 1), (y, x - 1)]
    a[seen] = 0
    return trim(a)


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
    ap.add_argument("sheets", nargs="+", help="kit 1, kit 2, kit 3 and kit 3b sheets")
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
    if len(sheets) > 2:
        parts.update({"k3_" + name: cut(sheets[2], pal, allowed, rect, SCALE3, CUTOFF3) for name, rect in PARTS3.items()})
    if len(sheets) > 3:
        parts.update({"k3b_" + name: cut(sheets[3], pal, allowed, rect, SCALE3B, CUTOFF3) for name, rect in PARTS3B.items()})
    names = palette_names()
    meta = {}
    out = parts if ap_all else {}
    for name, (src, kind, info) in SHIP.items():
        a = parts[src] if src else None
        entry = {k: v for k, v in info.items() if k not in ("mid", "rows", "mirror", "recolor", "rect", "drop", "face", "inset", "grid")}
        byname = {n: i for i, n in names.items()}
        if "rows" in info:
            a = a[info["rows"]]
        for f, t in info.get("recolor", {}).items():
            a = a.copy()
            a[(a[..., :3] == pal[byname[f]]).all(2) & (a[..., 3] > 0), :3] = pal[byname[t]]
        if kind == "slice":
            a = template(a, info["slice"], info["mid"])
            if info.get("mirror"):
                assert info["slice"][0] == info["slice"][2], "mirror needs left == right"
                a = a.copy()
                a[:, -info["slice"][2]:] = a[:, :info["slice"][0]][:, ::-1]
        elif kind == "grid":
            a = grid(pal, GRIDS[info["grid"]])
        elif kind == "crop":
            x, y, w, h = info["rect"]
            a = a[y:y + h, x:x + w].copy()
            for n in info["drop"]:
                a[(a[..., :3] == pal[byname[n]]).all(2)] = 0
            a = trim(a)
        elif kind == "icon":
            a = icon_out(a, [pal[byname[n]] for n in info["face"]], info.get("inset", 2))
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
