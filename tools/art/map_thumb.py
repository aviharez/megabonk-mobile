#!/usr/bin/env python3
"""Cut a map's thumbnail for the map select screen out of a whole-map render, at 1x (no scaling).

    godot --path . -s res://tools/render_map.gd -- --map=suburbia --seed=7 --out=/tmp/map.png
    python3 tools/art/map_thumb.py /tmp/map.png suburbia 14 338

x, y: top-left of the crop in the render (the render has an 8px border). The size is the
MapCard thumbnail (scripts/ui/map_screen.gd THUMB). Writes assets/maps/<map>_thumb.png.
"""
import os
import sys

from PIL import Image

W, H = 164, 52

render, map_id, x, y = sys.argv[1], sys.argv[2], int(sys.argv[3]), int(sys.argv[4])
im = Image.open(render).convert("RGBA").crop((x, y, x + W, y + H))
os.makedirs("assets/maps", exist_ok=True)
out = "assets/maps/%s_thumb.png" % map_id
im.save(out)
print(out, im.size)
