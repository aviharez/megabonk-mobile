#!/usr/bin/env python3
"""Merge several game sheets (one clip each) into one strip with named clips.

The enemy renderer draws each enemy type from one texture with equally sized frames, so a boss
with several animations needs them in one strip. Every clip is padded to the largest frame size,
aligned on its sidecar origin (the feet), and listed in the output sidecar:

  {"format": "game.sheet", "frame_w": W, "frame_h": H, "frames": N, "fps": F, "origin": [x, y],
   "default": "walk", "clips": {"walk": {"start": 0, "frames": 4, "fps": 8}, ...}, "source": {...}}

The first clip is the default (it loops); the game plays the others on demand.

Usage: python3 tools/sheet_clips.py --out assets/bosses/mega_mole.png \
           walk=build/.../mole_walk.png burrow=... attack=... hit=...
"""
import argparse
import json
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import palette_snap as ps  # noqa: E402


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("clips", nargs="+", metavar="NAME=SHEET.png")
    ap.add_argument("--out", required=True)
    args = ap.parse_args()

    clips = []
    for c in args.clips:
        name, path = c.split("=", 1)
        meta = json.load(open(ps.sidecar_path(path)))
        clips.append((name, Image.open(path).convert("RGBA"), meta))
    # Shared frame: room left/above the origin and right/below it, over all clips.
    left = max(m["origin"][0] for _, _, m in clips)
    top = max(m["origin"][1] for _, _, m in clips)
    right = max(m["frame_w"] - m["origin"][0] for _, _, m in clips)
    bottom = max(m["frame_h"] - m["origin"][1] for _, _, m in clips)
    fw, fh = left + right, top + bottom
    total = sum(m["frames"] for _, _, m in clips)
    out = Image.new("RGBA", (fw * total, fh))
    table, at, sources = {}, 0, {}
    for name, im, m in clips:
        ox, oy = left - m["origin"][0], top - m["origin"][1]
        for i in range(m["frames"]):
            fr = im.crop((i * m["frame_w"], 0, (i + 1) * m["frame_w"], m["frame_h"]))
            out.alpha_composite(fr, ((at + i) * fw + ox, oy))
        table[name] = {"start": at, "frames": m["frames"], "fps": m["fps"]}
        sources[name] = m.get("source", {})
        at += m["frames"]
    out.save(args.out)
    meta = {
        "format": "game.sheet", "frame_w": fw, "frame_h": fh, "frames": total, "fps": clips[0][2]["fps"],
        "origin": [left, top], "default": clips[0][0], "clips": table,
        "source": {"generator": "tools/sheet_clips.py", "clips": sources, "sheet": os.path.basename(args.out)},
    }
    with open(ps.sidecar_path(args.out), "w") as fp:
        json.dump(meta, fp, indent=2)
        fp.write("\n")
    pal = ps.load_palette(ps.DEFAULT_PALETTE)
    problems, ncol = ps.verify(args.out, pal, set(), meta)
    if problems:
        raise SystemExit(f"{args.out}: " + "; ".join(problems))
    print(f"OK   {args.out}: {len(clips)} clips, {total} frames {fw}x{fh}, {ncol} palette colours")


if __name__ == "__main__":
    main()
