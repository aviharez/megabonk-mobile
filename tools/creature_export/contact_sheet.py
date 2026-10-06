#!/usr/bin/env python3
"""Preview only: lay out every snapped candidate (game.sheet PNG + JSON) as labeled rows.

usage: python3 tools/creature_export/contact_sheet.py build/creature_candidates [--scale 6]
Writes <dir>/contact_sheet.png. Rows are grouped by enemy folder; each row shows all frames.
"""

import argparse
import glob
import json
import os

from PIL import Image, ImageDraw, ImageFont

BG = (52, 96, 60, 255)      # preview backdrop only, not a game asset
FRAME_BG = (64, 112, 72, 255)
TEXT = (255, 255, 255, 255)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("dir")
    ap.add_argument("--scale", type=int, default=6)
    args = ap.parse_args()
    s = args.scale
    rows = []
    for meta_path in sorted(glob.glob(os.path.join(args.dir, "*", "*.json"))):
        with open(meta_path) as f:
            meta = json.load(f)
        if meta.get("format") != "game.sheet":
            continue
        png = meta_path[:-5] + ".png"
        src = meta["source"]
        label = (f"{os.path.basename(os.path.dirname(png))}: {os.path.basename(png)}  "
                 f"{src.get('family')}/{src.get('archetype')} seed {src.get('seed')}  "
                 f"{meta['frames']}x {meta['frame_w']}x{meta['frame_h']} @{meta['fps']}fps")
        rows.append((label, Image.open(png).convert("RGBA"), meta))
    if not rows:
        raise SystemExit("no game.sheet candidates found")
    font = ImageFont.load_default()
    label_h, gap, margin = 14, 4, 8
    width = max(margin * 2 + r[2]["frames"] * (r[2]["frame_w"] * s + gap) for r in rows)
    width = max(width, 520)
    height = margin + sum(label_h + r[2]["frame_h"] * s + margin for r in rows)
    sheet = Image.new("RGBA", (width, height), BG)
    draw = ImageDraw.Draw(sheet)
    y = margin
    for label, img, meta in rows:
        draw.text((margin, y), label, fill=TEXT, font=font)
        y += label_h
        fw, fh = meta["frame_w"], meta["frame_h"]
        for i in range(meta["frames"]):
            fr = img.crop((i * fw, 0, (i + 1) * fw, fh)).resize((fw * s, fh * s), Image.NEAREST)
            x = margin + i * (fw * s + gap)
            sheet.paste(FRAME_BG, (x, y, x + fw * s, y + fh * s))
            sheet.alpha_composite(fr, (x, y))
        y += fh * s + margin
    out = os.path.join(args.dir, "contact_sheet.png")
    sheet.save(out)
    print(f"wrote {out} ({len(rows)} candidates, {sheet.size[0]}x{sheet.size[1]})")


if __name__ == "__main__":
    main()
