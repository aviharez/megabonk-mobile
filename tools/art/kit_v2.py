#!/usr/bin/env python3
"""Game UI kit v2 (docs/BRIEF.md "Update 1", Game UI kit v2) as 9-slice PNG templates.

Every part is drawn here from the colour tokens, measured from the owner's mockups in docs/ui/
(4 mockup px = 1 game px). Output: assets/ui/kit/<part>.png (1 px = 1 game px) and
assets/ui/kit/kit.json ({part: {"slice": [left, top, right, bottom]}} for 9-slice parts; sprites
have no slice). UiArt reads them as "kit/<part>". Templates have a 1 px middle row and column, so
stretching never scales a pixel. Drops (3 px under windows and buttons, 2 under cards, slots,
plates and stickers) are not in the art: UiArt draws the part's INK silhouette lower.

Usage:  python3 tools/art/kit_v2.py        (re-run after changing a part; output is deterministic)
"""
import json
import os

from PIL import Image

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(REPO, "assets", "ui", "kit")

TOK = {
    "bg": "0b1020", "surface": "121a2e", "surface2": "16203a", "well": "0b0f1c", "raised": "1a2540",
    "frame_lo": "1e2a45", "frame": "2e4170", "frame_hi": "5b78b0", "line": "2a3a5e", "muted": "8a9cc2",
    "text": "f4f0e8", "ink": "0e0b16", "lamp": "f5b83d", "lamp_hi": "ffe680", "lamp_lo": "d97a26",
    "lamp_deep": "8a4a1c", "go": "a6e070", "go_lo": "5cb83f", "go_deep": "2f7a34", "alert": "e04a3a",
    "alert_hi": "ff8a6b", "alert_lo": "a3262f", "r_common": "a9b6cf", "r_rare": "3a9ad9",
    "r_epic": "8a3fc4", "r_legend": "f5b83d",
}


def rgb(name):
    h = TOK[name]
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), 255)


class Canvas:
    def __init__(self, w, h):
        self.im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        self.w, self.h = w, h

    def rect(self, x, y, w, h, c):
        for yy in range(y, y + h):
            for xx in range(x, x + w):
                if 0 <= xx < self.w and 0 <= yy < self.h:
                    self.im.putpixel((xx, yy), rgb(c))

    def px(self, x, y, c):
        self.rect(x, y, 1, 1, c)

    def outline(self, c="ink"):
        self.rect(0, 0, self.w, 1, c)
        self.rect(0, self.h - 1, self.w, 1, c)
        self.rect(0, 0, 1, self.h, c)
        self.rect(self.w - 1, 0, 1, self.h, c)


PARTS = {}


def part(name, canvas, sl=None):
    PARTS[name] = (canvas, sl)


# Window frame: INK outline, a 3 px band (light top-left, shaded bottom-right), an inner INK
# line, SURFACE inside. The hatch and the four bolts go on top in UiArt.window().
def window():
    c = Canvas(11, 11)
    c.outline()
    c.rect(1, 1, 9, 9, "frame")
    c.rect(1, 1, 8, 1, "frame_hi")
    c.rect(1, 1, 1, 8, "frame_hi")
    c.rect(9, 2, 1, 8, "frame_lo")
    c.rect(2, 9, 8, 1, "frame_lo")
    c.rect(4, 4, 3, 3, "ink")
    c.rect(5, 5, 1, 1, "surface")
    part("window", c, [5, 5, 5, 5])


# The window's diagonal hatch, a 4x4 tile (SURFACE with a SURFACE-2 line where x + y = 3).
def hatch():
    c = Canvas(4, 4)
    c.rect(0, 0, 4, 4, "surface")
    for i in range(4):
        c.px(3 - i, i, "surface2")
    part("hatch", c)
    b = Canvas(2, 2)
    b.rect(0, 0, 2, 2, "frame_hi")
    part("bolt", b)
    b = Canvas(2, 2)
    b.rect(0, 0, 2, 2, "lamp_deep")
    part("bolt_lamp", b)


# Card (in windows, nav tiles, goods): lit top line, frame sides, two-tone bottom, RAISED fill.
def card(name="card", fill="raised", hi="frame_hi", side="frame", lo="frame_lo"):
    c = Canvas(5, 6)
    c.outline()
    c.rect(1, 1, 3, 4, fill)
    c.rect(1, 1, 3, 1, hi)
    c.rect(1, 2, 1, 3, side)
    c.rect(3, 2, 1, 3, side)
    c.rect(1, 3, 3, 1, lo)
    c.rect(1, 4, 3, 1, side)
    part(name, c, [2, 2, 2, 3])


def well():
    c = Canvas(3, 3)
    c.rect(0, 0, 3, 3, "well")
    part("well", c, [1, 1, 1, 1])
    c = Canvas(3, 3)
    c.outline()
    c.rect(1, 1, 1, 1, "well")
    part("well_ink", c, [1, 1, 1, 1])


# Slot (icon frame): INK, a FRAME ring with a lit inner top, an inner INK line on the other
# sides, WELL inside. Rarity / ready / selected slots: a 2 px ring in that colour.
def slots():
    c = Canvas(7, 7)
    c.outline()
    c.rect(1, 1, 5, 5, "frame")
    c.rect(2, 2, 3, 1, "frame_hi")
    c.rect(2, 3, 3, 2, "ink")
    c.rect(3, 3, 1, 1, "well")
    part("slot", c, [3, 3, 3, 3])
    for name, col in [("common", "r_common"), ("rare", "r_rare"), ("epic", "r_epic"),
                      ("legend", "r_legend"), ("ready", "go"), ("sel", "lamp")]:
        c = Canvas(9, 9)
        c.outline()
        c.rect(1, 1, 7, 7, col)
        c.rect(3, 3, 3, 3, "ink")
        c.rect(4, 4, 1, 1, "well")
        part("slot_" + name, c, [4, 4, 4, 4])


# Block buttons: INK outline, 2 px top bevel, face, 3 px bottom bevel, 2x2 shine at (4, 5).
def buttons():
    for name, hi, face, lo, shine in [("primary", "lamp_hi", "lamp", "lamp_lo", "text"),
                                      ("secondary", "frame_hi", "frame", "frame_lo", "muted"),
                                      ("go", "go", "go_lo", "go_deep", "text")]:
        c = Canvas(9, 12)
        c.outline()
        c.rect(1, 1, 7, 10, face)
        c.rect(1, 1, 7, 2, hi)
        c.rect(1, 8, 7, 3, lo)
        c.rect(4, 5, 2, 2, shine)
        part("btn_" + name, c, [6, 7, 2, 4])
    # Disabled (Max, sold out): no bevels, a LINE ring on SURFACE, WELL along the bottom.
    c = Canvas(5, 6)
    c.outline()
    c.rect(1, 1, 3, 4, "line")
    c.rect(2, 2, 1, 2, "surface")
    c.rect(2, 3, 1, 1, "well")
    part("btn_disabled", c, [2, 2, 2, 3])


# Title plates: 1 px top bevel, face, 2 px bottom bevel (bolts drawn by UiArt.plate()).
def plates():
    for name, hi, face, lo in [("lamp", "lamp_hi", "lamp", "lamp_lo"),
                               ("frame", "frame_hi", "frame", "frame_lo")]:
        c = Canvas(3, 6)
        c.outline()
        c.rect(1, 1, 1, 4, face)
        c.rect(1, 1, 1, 1, hi)
        c.rect(1, 3, 1, 2, lo)
        part("plate_" + name, c, [1, 2, 1, 3])


# Stickers, badges and chips: INK outline around a flat fill (+ a shaded bottom on chips).
def stickers():
    for name, fill in [("sticker", "lamp_hi"), ("badge", "lamp"), ("count", "text"),
                       ("ad", "ink"), ("chip_go", "go_lo"), ("sticker_epic", "r_epic")]:
        c = Canvas(3, 3)
        c.outline()
        c.px(1, 1, fill)
        part(name, c, [1, 1, 1, 1])
    c = Canvas(3, 4)
    c.outline()
    c.rect(1, 1, 1, 2, "frame")
    c.px(1, 2, "frame_lo")
    part("chip", c, [1, 1, 1, 2])
    # Notification dot: a red square with a light top row.
    c = Canvas(9, 9)
    c.outline()
    c.rect(1, 1, 7, 7, "alert")
    c.rect(1, 1, 7, 1, "alert_hi")
    part("dot", c)


# Bars: a WELL track in INK; fills with a 2 px light top and a 1 px dark bottom.
def bars():
    c = Canvas(3, 3)
    c.outline()
    c.px(1, 1, "well")
    part("track", c, [1, 1, 1, 1])
    for name, hi, face, lo in [("lamp", "lamp_hi", "lamp", "lamp_lo"), ("go", "go", "go_lo", "go_deep"),
                               ("hp", "alert_hi", "alert", "alert_lo")]:
        c = Canvas(1, 4)
        c.rect(0, 0, 1, 2, hi)
        c.px(0, 2, face)
        c.px(0, 3, lo)
        part("fill_" + name, c, [0, 2, 0, 1])


# Level pips: 6x5 (INK outline, 4x3 inside); the new one gets a lamp ring.
def pips():
    c = Canvas(6, 5)
    c.outline()
    c.rect(1, 1, 4, 3, "lamp")
    c.rect(1, 1, 4, 1, "lamp_hi")
    part("pip_on", c)
    c = Canvas(6, 5)
    c.outline()
    c.rect(1, 1, 4, 3, "well")
    part("pip_off", c)
    c = Canvas(8, 7)
    c.outline("lamp")
    c.rect(1, 1, 6, 5, "ink")
    c.rect(2, 2, 4, 3, "lamp_hi")
    part("pip_new", c)


# Tabs: the picked one is a secondary block with a lamp bar along the bottom; the others sit
# flat (LINE ring on SURFACE, WELL bottom row).
def tabs():
    c = Canvas(3, 9)
    c.outline()
    c.rect(1, 1, 1, 7, "frame")
    c.rect(1, 1, 1, 2, "frame_hi")
    c.rect(1, 5, 1, 3, "lamp")
    part("tab_on", c, [1, 4, 1, 4])
    c = Canvas(5, 6)
    c.outline()
    c.rect(1, 1, 3, 4, "line")
    c.rect(2, 2, 1, 2, "surface")
    c.rect(2, 3, 1, 1, "well")
    part("tab_off", c, [2, 2, 2, 3])


# Bottom nav strip: INK, FRAME, INK along the top; the hatch fills the rest.
def nav():
    c = Canvas(1, 4)
    c.px(0, 0, "ink")
    c.px(0, 1, "frame")
    c.px(0, 2, "ink")
    c.px(0, 3, "surface")
    part("nav_bar", c, [0, 3, 0, 0])


# Toggle switch (settings), 30x13: a WELL track lit top-left; the knob is a lamp block on the
# right when on, a frame block on the left when off.
def toggles():
    for name, on in [("toggle_on", True), ("toggle_off", False)]:
        c = Canvas(30, 13)
        c.outline()
        c.rect(1, 1, 28, 11, "well")
        c.rect(1, 1, 28, 1, "frame")
        c.rect(1, 1, 1, 11, "frame")
        kx = 15 if on else 1
        hi, face, lo = ("lamp_hi", "lamp", "lamp_lo") if on else ("frame_hi", "frame", "frame_lo")
        c.rect(kx, 0, 15 if on else 14, 13, "ink")
        c.rect(kx + 1, 1, 12, 11, face)
        c.rect(kx + 1, 1, 12, 2, hi)
        c.rect(kx + 1, 10, 12, 1, lo)
        if not on:
            c.rect(kx + 1, 1, 12, 1, hi)
        part(name, c)


# Small icons the screens need that no kit has: a check, a lock, music and sound.
def icons():
    c = Canvas(7, 6)
    for x, y in [(0, 3), (1, 4), (2, 5), (3, 4), (4, 3), (5, 2), (6, 1), (6, 0)]:
        c.px(x, y, "go")
    for x, y in [(1, 3), (2, 4), (3, 3), (4, 2), (5, 1)]:
        c.px(x, y, "go_lo")
    part("check", c)
    c = Canvas(7, 8)
    c.rect(1, 0, 5, 1, "muted")
    c.rect(1, 0, 1, 4, "muted")
    c.rect(5, 0, 1, 4, "muted")
    c.rect(0, 3, 7, 5, "muted")
    c.rect(0, 7, 7, 1, "line")
    c.rect(3, 5, 1, 1, "ink")
    part("lock", c)
    # Music: a beamed note; sound: a speaker with a wave.
    c = Canvas(7, 9)
    c.rect(3, 0, 4, 1, "text")
    c.rect(3, 0, 1, 7, "text")
    c.rect(0, 6, 4, 3, "text")
    part("music", c)
    c = Canvas(9, 7)
    c.rect(0, 2, 2, 3, "text")
    c.rect(2, 1, 1, 5, "text")
    c.rect(3, 0, 1, 7, "text")
    c.rect(5, 2, 1, 3, "text")
    c.rect(7, 1, 1, 5, "text")
    part("sound", c)
    # Close (X) for popup windows, alert-coloured.
    c = Canvas(9, 9)
    for i in range(9):
        for d in (0, 1):
            if i + d < 9:
                c.px(i + d, i, "alert_hi" if d == 0 else "alert")
                c.px(8 - i - d, i, "alert_hi" if d == 0 else "alert")
    part("close", c)
    # Play triangle for the big Play button (paper with a muted shade).
    c = Canvas(9, 13)
    for x in range(9):
        top, bot = x * 6 // 9, 12 - x * 6 // 9
        if top <= bot:
            c.rect(x, top, 1, bot - top + 1, "text")
    c.rect(0, 0, 2, 13, "muted")
    part("play", c)
    # A small house for the Town nav tile: red roof, paper walls, a wood door.
    c = Canvas(18, 17)
    for i in range(9):
        c.rect(8 - i, i, 2 + 2 * i, 1, "ink")
        if i > 0:
            c.rect(9 - i, i, 2 * i, 1, "alert" if i < 7 else "alert_lo")
    c.rect(2, 8, 14, 9, "ink")
    c.rect(3, 9, 12, 7, "text")
    c.rect(3, 9, 12, 1, "r_common")
    c.rect(7, 11, 4, 5, "lamp_lo")
    c.rect(7, 11, 4, 1, "lamp_deep")
    part("house", c)
    # No Ads: a paper ticket with "AD" crossed out in red.
    c = Canvas(19, 15)
    c.rect(1, 2, 17, 11, "ink")
    c.rect(2, 3, 15, 9, "text")
    c.rect(2, 11, 15, 1, "r_common")
    a = ["010", "101", "111", "101", "101"]
    d = ["110", "101", "101", "101", "110"]
    for y in range(5):
        for x in range(3):
            if a[y][x] == "1":
                c.px(5 + x, 5 + y, "ink")
            if d[y][x] == "1":
                c.px(10 + x, 5 + y, "ink")
    for i in range(14):
        c.px(2 + i, 13 - i, "alert")
        c.px(3 + i, 13 - i, "alert_lo" if i % 2 else "alert")
    part("no_ads", c)
    # Pause: two paper bars.
    c = Canvas(8, 11)
    c.rect(0, 0, 3, 11, "text")
    c.rect(5, 0, 3, 11, "text")
    c.rect(2, 1, 1, 10, "muted")
    c.rect(7, 1, 1, 10, "muted")
    part("pause", c)
    # Back: a paper arrow pointing left (sub-screen headers), muted shade below.
    c = Canvas(11, 9)
    for i in range(5):
        c.rect(i, 4 - i, 1, 1 + 2 * i, "text")
    c.rect(4, 3, 7, 3, "text")
    c.rect(5, 6, 6, 1, "muted")
    part("back", c)
    # Next: a paper flag-arrow pointing right (Next on Pick a District, the
    # district summary card), muted shade below.
    c = Canvas(11, 11)
    c.rect(0, 1, 2, 9, "text")
    c.rect(2, 3, 4, 5, "text")
    for i in range(5):
        c.rect(6 + i, 1 + i, 1, 9 - 2 * i, "text")
    c.rect(2, 7, 4, 1, "muted")
    part("next", c)


def main():
    window()
    hatch()
    card()
    well()
    slots()
    buttons()
    plates()
    stickers()
    bars()
    pips()
    tabs()
    nav()
    toggles()
    icons()
    os.makedirs(OUT, exist_ok=True)
    meta = {}
    for name, (c, sl) in sorted(PARTS.items()):
        c.im.save(os.path.join(OUT, name + ".png"))
        meta[name] = {"slice": sl} if sl else {}
    with open(os.path.join(OUT, "kit.json"), "w") as f:
        json.dump(meta, f, indent=1, sort_keys=True)
        f.write("\n")
    print(f"{len(PARTS)} parts -> {os.path.relpath(OUT, REPO)}")


if __name__ == "__main__":
    main()
