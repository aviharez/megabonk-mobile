#!/usr/bin/env python3
"""Build data/maps/suburbia.json (1440x1760) from two hand-designed 720x880 blocks:
tools/maps/suburbia_block.json (A: houses, the pond park, the sports field with the altar) and
tools/maps/suburbia_block_b.json (B: school ground, park with the public pool, parking lot; only
its "size" and "props" are used).

Layout: A top-left and bottom-right, B top-right and bottom-left, so no two neighbours are the same
block. The copies are not mirrored (that made the corners look mirrored and bunched the two ponds and
the two running tracks around the map centre); the "flip" flag per copy is still there, it mirrors
positions only (sprites keep facing the viewer). A block's edge that lies on a seam in one copy lies
on the map edge in the other. Block streets that reach a seam
end in a T-junction. A vertical and a horizontal road with sidewalks run along the seams and join the blocks
into one grid of streets; objects under them are dropped and ground patches are cut back. In the
three copies, roof, tree, shed, bush, planter, mailbox and car colors are re-rolled (fixed seed).
Interactable counts scale with the area; fixed ones (with "at") stay in the top-left block, so
there is still one boss altar and one cage. The Town (phase 13) is in the top-left block too: its
"building" props and the props with "requires" (a Town lot's extras) are kept in the first copy
only; the other copies get a plain house in each building's place. Everything else in the block (spawns, art...) is copied.

Edit a block, then run:  python3 tools/maps/build_suburbia.py
"""
import json
import os
import random

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..")
BLOCK = os.path.join(ROOT, "tools/maps/suburbia_block.json")
BLOCK_B = os.path.join(ROOT, "tools/maps/suburbia_block_b.json")
OUT = os.path.join(ROOT, "data/maps/suburbia.json")

GROUND = {"yard", "field", "garden", "path", "sand", "sidewalk", "driveway", "road", "crosswalk"}
# Seam streets: (sidewalk, road, sidewalk) along x = 720 and y = 880.
V_STRIP = (696, 744)
H_STRIP = (864, 912)
COUNT_SCALE = 3
# Per copy (not the first), colors are re-rolled so the copies don't read as copies.
RECOLOR = {
    "house": ["RED", "BLUE", "PURPLE", "TEAL", "WOOD"],
    "tree": ["", "", "", "GREEN", "RED"],
    "shed": ["WOOD", "RED", "BLUE", "PURPLE", "SKY"],
    "bush": ["", "BUTTER", "SKY"],
    "planter": ["PINK", "BUTTER", "SKY"],
    "mailbox": ["BLUE", "BLUE", "RED", "GOLD"],
    "car": ["", "GOLD", "PAPER"],
}
SEED = 6  # not 4: the seam streets and the bigger walk keep the density about the same


def mirror(p, w):
    q = dict(p)
    x, y, rw, rh = p["rect"]
    q["rect"] = [w - x - rw, y, rw, rh]
    return q


def moved(p, dx, dy):
    q = dict(p)
    x, y, w, h = p["rect"]
    q["rect"] = [x + dx, y + dy, w, h]
    return q


def overlaps(r, a, b, axis):
    lo, hi = (r[0], r[0] + r[2]) if axis == 0 else (r[1], r[1] + r[3])
    return lo < b and hi > a


def cut(p, a, b, axis):
    """Ground props lose the part under a seam street (may split in two); objects are dropped."""
    r = p["rect"]
    if not overlaps(r, a, b, axis):
        return [p]
    if p["kind"] not in GROUND or p["kind"] in ("road", "sidewalk", "crosswalk") or p.get("shape") == "ellipse":
        # Long streets across the seam stay (the seam road draws over them); others go.
        return [p] if p["kind"] in ("road", "sidewalk") else []
    out = []
    lo, size = (r[0], r[2]) if axis == 0 else (r[1], r[3])
    for s, e in ((lo, a), (b, lo + size)):
        if e - s >= 8 and s >= lo and e <= lo + size:
            q = dict(p)
            q["rect"] = list(r)
            q["rect"][axis] = s
            q["rect"][axis + 2] = e - s
            out.append(q)
    return out


def main():
    block = json.load(open(BLOCK))
    block_b = json.load(open(BLOCK_B))
    bw, bh = block["size"]
    assert block_b["size"] == [bw, bh], "both blocks must be the same size"
    props = []
    rng = random.Random(SEED)
    copies = ((block, 0, 0, False), (block_b, bw, 0, False), (block_b, 0, bh, False), (block, bw, bh, False))
    for i, (src, dx, dy, flip) in enumerate(copies):
        for p in src["props"]:
            if i > 0 and "requires" in p:
                continue  # a Town lot's extras: only in the first copy
            q = moved(mirror(p, bw) if flip else p, dx, dy)
            if i > 0 and q["kind"] == "building":
                # The Town's buildings stand in the first copy; the others keep a plain house.
                q["kind"] = "house"
                q.pop("building", None)
            if i > 0 and q["kind"] in RECOLOR:
                c = rng.choice(RECOLOR[q["kind"]])
                q.pop("color", None)
                if c:
                    q["color"] = c
            props.append(q)
    kept = []
    for p in props:
        for a in cut(p, *V_STRIP, 0):
            kept.extend(cut(a, *H_STRIP, 1))
    w, h = bw * 2, bh * 2
    vx, hy = V_STRIP[0], H_STRIP[0]
    seam = [
        {"kind": "sidewalk", "rect": [vx, 0, 8, h]},
        {"kind": "sidewalk", "rect": [vx + 40, 0, 8, h]},
        {"kind": "sidewalk", "rect": [0, hy, w, 8]},
        {"kind": "sidewalk", "rect": [0, hy + 40, w, 8]},
        {"kind": "road", "rect": [vx + 8, 0, 32, h], "lines": True},
        {"kind": "road", "rect": [0, hy + 8, w, 32], "lines": True},
    ]
    # Ground kinds draw in their own order, so the seam streets can simply go first.
    out = dict(block)
    out["size"] = [w, h]
    out["props"] = seam + kept
    inter = []
    for it in block["interactables"]:
        it = dict(it)
        if "at" not in it:
            it["count"] = it["count"] * COUNT_SCALE
        inter.append(it)
    out["interactables"] = inter
    text = json.dumps(out, indent="\t")
    with open(OUT, "w") as f:
        f.write(text + "\n")
    print(f"{OUT}: {w}x{h}, {len(out['props'])} props")


if __name__ == "__main__":
    main()
