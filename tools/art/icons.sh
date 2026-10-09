#!/usr/bin/env bash
# Rebuild assets/icons/ from the downloaded SpriteCook icon sheets (asset ids in
# docs/spritecook-assets.json). Usage: tools/art/icons.sh RAW_DIR
# RAW_DIR holds baguette.png, sheet1.png .. sheet6.png (2x2 sheets) as downloaded.
set -euo pipefail
R=${1:?raw dir}
cd "$(dirname "$0")/../.."
W=assets/icons/weapons I=assets/icons/items
shrink() { python3 tools/icon_shrink.py "$@" >/dev/null; }
shrink "$R/baguette.png" --out $W/baguette.png
shrink "$R/sheet1.png" --grid 2 --out - $W/hot_coffee.png $W/rubber_duck.png $W/stapler.png
shrink "$R/sheet1.png" --grid 2 --method nearest --out $W/faulty_toaster.png - - -
shrink "$R/sheet2.png" --grid 2 --out $W/fireworks.png $W/garden_gnomes.png $W/leaf_blower.png $W/sharp_feathers.png
shrink "$R/sheet3.png" --grid 2 --out $W/stinky_socks.png $I/alarm_clock.png $I/angry_neighbor.png $I/band_aid.png
shrink "$R/sheet4.png" --grid 2 --out $I/clone_machine.png - - $I/hot_sauce.png
shrink "$R/sheet4.png" --grid 2 --method nearest --out - $I/energy_drink.png $I/golden_toilet.png -
shrink "$R/sheet5.png" --grid 2 --out $I/lucky_penny.png $I/magnet_keychain.png $I/microwave_meltdown.png $I/pinata.png
shrink "$R/sheet6.png" --grid 2 --out $I/protein_bar.png $I/rubber_boots.png $I/static_sweater.png $I/whoopee_cushion.png
python3 tools/palette_snap.py --check $W/*.png $I/*.png
