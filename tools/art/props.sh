#!/usr/bin/env bash
# Rebuild assets/props/ from the downloaded SpriteCook prop images (asset ids in
# docs/spritecook-assets.json). Usage: tools/art/props.sh RAW_DIR
# RAW_DIR holds house2.png (the front-facing house), propsA.png and propsB.png (2x2 sheets) as
# downloaded. Each prop is cut from its cell and shrunk so its longer side is --size.
set -euo pipefail
R=${1:?raw dir}
cd "$(dirname "$0")/../.."
P=assets/props
shrink() { python3 tools/icon_shrink.py --tight "$@" >/dev/null; }
# Snap to the palette and crop only (34x34 as it came back; no shrinking).
shrink "$R/house2.png" --size 34 --out $P/house.png
shrink "$R/propsA.png" --grid 2 --size 22 --out $P/tree.png - - -
shrink "$R/propsA.png" --grid 2 --size 14 --out - $P/bush.png - -
shrink "$R/propsA.png" --grid 2 --size 22 --out - - $P/shed.png -
shrink "$R/propsA.png" --grid 2 --size 20 --out - - - $P/car.png
shrink "$R/propsB.png" --grid 2 --size 18 --out $P/bench.png - - -
shrink "$R/propsB.png" --grid 2 --size 26 --out - $P/swing.png - -
shrink "$R/propsB.png" --grid 2 --size 24 --out - - $P/pine.png -
shrink "$R/propsB.png" --grid 2 --size 22 --out - - - $P/apple_tree.png
python3 tools/palette_snap.py --check $P/*.png
