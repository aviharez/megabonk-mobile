#!/usr/bin/env bash
# Rebuild assets/props/ from the downloaded SpriteCook prop images (asset ids in
# docs/spritecook-assets.json). Usage: tools/art/props.sh RAW_DIR
# RAW_DIR holds house2.png (the front-facing house) as downloaded.
set -euo pipefail
R=${1:?raw dir}
cd "$(dirname "$0")/../.."
P=assets/props
shrink() { python3 tools/icon_shrink.py "$@" >/dev/null; }
# Snap to the palette and crop only (34x34 as it came back; no shrinking).
shrink "$R/house2.png" --size 34 --out $P/house.png
python3 tools/palette_snap.py --check $P/*.png
