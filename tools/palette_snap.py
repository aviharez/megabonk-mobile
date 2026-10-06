#!/usr/bin/env python3
"""Snap a procedural-pixel-creatures sheet to the game palette and repack it as a game sheet.

Input: a sheet PNG written by tools/creature_export (or the generator itself) and its metadata
JSON (ppc.spritesheet). Output: one horizontal row of equally sized frames, each with at least a
1px fully transparent border, plus a sidecar JSON:

  {"format": "game.sheet", "frame_w": W, "frame_h": H, "frames": N, "fps": F,
   "origin": [x, y], "source": {...}}

origin is the pixel inside a frame (padding included) that sits on the creature's ground point.

Colour rules: alpha becomes binary (>= --alpha-threshold is opaque), every opaque pixel maps to the
nearest palette colour in CIELAB (D65). Palette index 31 (enemy projectile magenta) is never a
target; --exclude adds more indices. The output is verified before the script exits; any violation
exits non-zero.

Usage:
  python3 tools/palette_snap.py SHEET.png [--meta SHEET.json] --out OUT.png [--clip walk_E]
        [--exclude 6,30] [--alpha-threshold 128] [--preview 8]
  python3 tools/palette_snap.py --check OUT.png [--exclude 6,30]
"""

import argparse
import json
import os
import sys

import numpy as np
from PIL import Image

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DEFAULT_PALETTE = os.path.join(REPO, "assets", "palette.png")
RESERVED = {31}  # bright magenta: enemy projectiles only


def load_palette(path):
    im = Image.open(path).convert("RGBA")
    if im.size[1] != 1:
        raise SystemExit(f"palette {path} must be 1px tall, is {im.size}")
    px = np.array(im)[0]
    return px[:, :3].astype(np.uint8)


def srgb_to_lab(rgb):
    """rgb: (..., 3) uint8 -> (..., 3) float CIELAB (D65)."""
    c = rgb.astype(np.float64) / 255.0
    lin = np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)
    m = np.array([[0.4124564, 0.3575761, 0.1804375],
                  [0.2126729, 0.7151522, 0.0721750],
                  [0.0193339, 0.1191920, 0.9503041]])
    xyz = lin @ m.T
    xyz /= np.array([0.95047, 1.0, 1.08883])
    e, k = 216 / 24389, 24389 / 27
    f = np.where(xyz > e, np.cbrt(xyz), (k * xyz + 16) / 116)
    L = 116 * f[..., 1] - 16
    a = 500 * (f[..., 0] - f[..., 1])
    b = 200 * (f[..., 1] - f[..., 2])
    return np.stack([L, a, b], axis=-1)


def parse_indices(s):
    out = set()
    if s:
        for part in s.split(","):
            part = part.strip()
            if part:
                out.add(int(part))
    return out


def allowed_indices(palette, exclude):
    return [i for i in range(len(palette)) if i not in RESERVED and i not in exclude]


def snap_colors(rgb, palette, allowed):
    """rgb: (N,3) uint8 -> (N,3) uint8 snapped to palette[allowed] by CIELAB distance."""
    targets = palette[allowed]
    lab_t = srgb_to_lab(targets)
    uniq, inv = np.unique(rgb, axis=0, return_inverse=True)
    lab_u = srgb_to_lab(uniq)
    d = ((lab_u[:, None, :] - lab_t[None, :, :]) ** 2).sum(-1)
    return targets[d.argmin(1)][inv.reshape(-1)]


def verify(png_path, palette, exclude, meta=None):
    """Returns a list of problems (empty when the sheet is valid)."""
    problems = []
    im = Image.open(png_path)
    if im.mode != "RGBA":
        im = im.convert("RGBA")
    a = np.array(im)
    alpha = a[..., 3]
    bad_alpha = np.setdiff1d(np.unique(alpha), [0, 255])
    if bad_alpha.size:
        problems.append(f"alpha values other than 0/255: {bad_alpha.tolist()[:10]}")
    opaque = a[alpha == 255][:, :3]
    allowed = allowed_indices(palette, exclude)
    allowed_set = {tuple(palette[i]) for i in allowed}
    reserved_set = {tuple(palette[i]) for i in RESERVED} | {tuple(palette[i]) for i in exclude if i < len(palette)}
    uniq = {tuple(c) for c in np.unique(opaque, axis=0)} if opaque.size else set()
    off = [c for c in uniq if c not in allowed_set]
    reserved_hits = [c for c in off if c in reserved_set]
    if reserved_hits:
        problems.append("reserved/excluded palette colours used: " + ", ".join("#%02x%02x%02x" % c for c in reserved_hits))
    off_pal = [c for c in off if c not in reserved_set]
    if off_pal:
        problems.append(f"{len(off_pal)} off-palette colours, e.g. " + ", ".join("#%02x%02x%02x" % c for c in off_pal[:5]))
    if meta is not None:
        fw, fh, n = meta["frame_w"], meta["frame_h"], meta["frames"]
        if a.shape[1] != fw * n or a.shape[0] != fh:
            problems.append(f"image is {a.shape[1]}x{a.shape[0]}, sidecar says {n} frames of {fw}x{fh}")
        else:
            for i in range(n):
                fr = alpha[:, i * fw:(i + 1) * fw]
                if fr[0].any() or fr[-1].any() or fr[:, 0].any() or fr[:, -1].any():
                    problems.append(f"frame {i} has opaque pixels on its 1px border")
                if not fr.any():
                    problems.append(f"frame {i} is empty")
    return problems, len(uniq)


def sidecar_path(png):
    return os.path.splitext(png)[0] + ".json"


def check_file(path, palette, exclude):
    meta = None
    sc = sidecar_path(path)
    if os.path.exists(sc):
        with open(sc) as f:
            meta = json.load(f)
        if meta.get("format") != "game.sheet":
            meta = None
    problems, ncol = verify(path, palette, exclude, meta)
    w, h = Image.open(path).size
    if problems:
        print(f"FAIL {path}")
        for p in problems:
            print("  - " + p)
        return False
    desc = f"{meta['frames']} frames of {meta['frame_w']}x{meta['frame_h']}" if meta else f"{w}x{h} (no game.sheet sidecar)"
    print(f"OK   {path}: {desc}, {ncol} palette colours, alpha binary, index 31 unused")
    return True


def snap(args, palette, exclude):
    meta_path = args.meta or os.path.splitext(args.sheet)[0] + ".json"
    with open(meta_path) as f:
        meta = json.load(f)
    if meta.get("format") != "ppc.spritesheet":
        raise SystemExit(f"{meta_path}: not a ppc.spritesheet metadata file")
    clips = meta["clips"]
    if args.clip:
        sel = [c for c in clips if c["name"] == args.clip or c["state"] == args.clip]
        if not sel:
            raise SystemExit(f"clip '{args.clip}' not in {[c['name'] for c in clips]}")
        clip = sel[0]
    else:
        clip = clips[0]
    pages = meta["pages"]
    page_imgs = {}
    base_dir = os.path.dirname(os.path.abspath(args.sheet))
    for i, p in enumerate(pages):
        path = args.sheet if len(pages) == 1 else os.path.join(base_dir, p["file"])
        page_imgs[i] = np.array(Image.open(path).convert("RGBA"))
    gw, gh = meta["frameWidth"], meta["frameHeight"]
    frames = []
    for fr in clip["frames"]:
        pg = page_imgs[fr.get("page", 0)]
        frames.append(pg[fr["y"]:fr["y"] + gh, fr["x"]:fr["x"] + gw].copy())
    stack = np.stack(frames)  # (N, gh, gw, 4)

    # binary alpha, then snap opaque colours
    opaque = stack[..., 3] >= args.alpha_threshold
    if not opaque.any():
        raise SystemExit("sheet has no opaque pixels")
    allowed = allowed_indices(palette, exclude)
    out = np.zeros_like(stack)
    out[opaque, :3] = snap_colors(stack[opaque][:, :3], palette, allowed)
    out[opaque, 3] = 255

    # crop to the union of content bounds over all frames, then add a 1px transparent border
    any_op = opaque.any(0)
    ys, xs = np.nonzero(any_op)
    y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
    pad = 1
    cw, ch = x1 - x0, y1 - y0
    fw, fh = cw + 2 * pad, ch + 2 * pad
    n = len(frames)
    sheet = np.zeros((fh, fw * n, 4), np.uint8)
    for i in range(n):
        sheet[pad:pad + ch, i * fw + pad:i * fw + pad + cw] = out[i, y0:y1, x0:x1]
    origin = [int(meta["originX"] - x0 + pad), int(meta["originY"] - y0 + pad)]
    if not (0 <= origin[0] < fw and 0 <= origin[1] < fh):
        print(f"warning: origin {origin} lies outside the {fw}x{fh} frame", file=sys.stderr)

    creature = meta.get("creature", {})
    side = {
        "format": "game.sheet",
        "frame_w": int(fw),
        "frame_h": int(fh),
        "frames": n,
        "fps": int(clip["fps"]),
        "origin": origin,
        "source": {
            "generator": meta.get("framework", "Procedural Pixel Creatures"),
            "generator_version": meta.get("generatorVersion"),
            "family": creature.get("family"),
            "archetype": args.archetype or creature.get("archetype"),
            "seed": args.seed if args.seed is not None else creature.get("seed"),
            "name": creature.get("name"),
            "content_id": creature.get("contentId"),
            "clip": clip["name"],
            "loop": clip.get("loop", True),
            "sheet": os.path.basename(args.sheet),
        },
    }
    os.makedirs(os.path.dirname(os.path.abspath(args.out)), exist_ok=True)
    Image.fromarray(sheet, "RGBA").save(args.out)
    with open(sidecar_path(args.out), "w") as f:
        json.dump(side, f, indent=2)
        f.write("\n")
    if args.preview:
        s = args.preview
        prev = Image.fromarray(sheet, "RGBA").resize((sheet.shape[1] * s, sheet.shape[0] * s), Image.NEAREST)
        prev.save(os.path.splitext(args.out)[0] + "_preview.png")
    print(f"wrote {args.out}: {n} frames of {fw}x{fh}, fps {side['fps']}, origin {origin}")
    return check_file(args.out, palette, exclude)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("sheet", nargs="?", help="generator sheet PNG")
    ap.add_argument("--meta", help="generator metadata JSON (default: SHEET with .json)")
    ap.add_argument("--out", help="output game sheet PNG (sidecar JSON is written next to it)")
    ap.add_argument("--clip", help="clip name or state (default: first clip in the metadata)")
    ap.add_argument("--palette", default=DEFAULT_PALETTE)
    ap.add_argument("--exclude", default="", help="extra palette indices to never use, e.g. 6,30 (31 is always excluded)")
    ap.add_argument("--alpha-threshold", type=int, default=128)
    ap.add_argument("--archetype", help="override source.archetype in the sidecar")
    ap.add_argument("--seed", type=int, help="override source.seed in the sidecar")
    ap.add_argument("--preview", type=int, default=0, metavar="SCALE", help="also write OUT_preview.png upscaled SCALE x (nearest)")
    ap.add_argument("--check", metavar="FILE", nargs="+", help="only verify existing game sheet(s)")
    args = ap.parse_args()

    palette = load_palette(args.palette)
    if len(palette) != 32:
        print(f"warning: palette has {len(palette)} colours, expected 32", file=sys.stderr)
    exclude = parse_indices(args.exclude)

    if args.check:
        ok = all([check_file(p, palette, exclude) for p in args.check])
        return 0 if ok else 1
    if not args.sheet or not args.out:
        ap.error("SHEET and --out are required (or use --check FILE)")
    return 0 if snap(args, palette, exclude) else 1


if __name__ == "__main__":
    sys.exit(main())
