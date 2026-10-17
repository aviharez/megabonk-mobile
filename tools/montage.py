#!/usr/bin/env python3
"""Puts screenshots side by side (nearest scaling) for review:
tools/montage.py OUT.png IN1.png IN2.png ... [--scale=0.5]"""
import sys
from PIL import Image
args = [a for a in sys.argv[1:] if not a.startswith('--')]
scale = float(next((a.split('=')[1] for a in sys.argv if a.startswith('--scale=')), '0.5'))
out, ins = args[0], [Image.open(p).convert('RGB') for p in args[1:]]
ims = [i.resize((int(i.width * scale), int(i.height * scale)), Image.NEAREST) for i in ins]
w = sum(i.width for i in ims) + 4 * (len(ims) - 1)
h = max(i.height for i in ims)
sheet = Image.new('RGB', (w, h), (255, 0, 255))
x = 0
for i in ims:
    sheet.paste(i, (x, 0))
    x += i.width + 4
sheet.save(out)
