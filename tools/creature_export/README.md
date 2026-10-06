# Enemy sprite pipeline

Enemy sprites come from [procedural-pixel-creatures](https://github.com/idlerunner00/procedural-pixel-creatures)
(MIT). This folder holds a small .NET 8 console app that compiles the generator's engine-independent
Core straight from a local checkout (nothing is copied into this repo) and exports small candidates.
`tools/palette_snap.py` then remaps them to `assets/palette.png` and repacks them into the game's
sheet format. Candidates go to `build/creature_candidates/` (gitignored) and are only imported into
`assets/` after the owner approves them.

## Build and run

Needs the .NET 8 SDK (here: `~/.dotnet`, 8.0.425) and Python 3 with Pillow and numpy.

```sh
export DOTNET_ROOT=$HOME/.dotnet PATH=$HOME/.dotnet:$PATH DOTNET_CLI_TELEMETRY_OPTOUT=1
dotnet build -c Release tools/creature_export
# generator checkout elsewhere:  -p:PpcRoot=/path/to/procedural-pixel-creatures
# (default: $HOME/Documents/Playgrounds/tools/procedural-pixel-creatures)
dotnet run -c Release --project tools/creature_export -- --help
dotnet run -c Release --project tools/creature_export -- --list-families   # archetypes + gene names
```

The exporter walks `--seeds`, keeps seeds whose sampled archetype (gene `form`) matches
`--archetype`, applies `--size` and `--gene name=value` overrides (number, or option id for choice
genes), exports direction 0 (east; the game mirrors for west) with no shadow, and keeps the
candidate if the exported frame (incl. the generator's 1px padding) fits in `--max-frame`. Per
candidate it writes `<name>_s<seed>.png` (raw generator sheet) and `<name>_s<seed>.json`
(generator `ppc.spritesheet` metadata, plus `creature.archetype` and `creature.seed`).

Note: the archetype comes from the seed, so overriding `form` with `--gene` would only change the
template, not re-sample the anatomy. Filter with `--archetype` instead.

## Candidate commands (Phase 6 first pass)

Run from the repo root. All use the walk clip at 12 fps (the walk loop is 4–5 frames at this size).

```sh
R="dotnet run -c Release --project tools/creature_export --"
OUT=build/creature_candidates

# Blob: slow chaser, horde filler (amorphous slime/ooze, pulse instead of hop keeps the frame small)
$R --family amorphous --archetype slime --seeds 21,25 --count 2 --size 0.1 --gene move=pulse --gene crown=none --gene eyes.size=1 --gene mouth=wide --clip walk --fps 12 --max-frame 20 --name blob_slime --out $OUT/raw/blob
$R --family amorphous --archetype ooze --seeds 17,114 --count 2 --size 0.1 --gene move=pulse --gene eyes.size=1 --gene mouth=wide --clip walk --fps 12 --max-frame 20 --name blob_ooze --out $OUT/raw/blob

# Skitter: fast, low HP, packs (arthropod spider: short legs, tiny abdomen, big head and eyes)
$R --family arthropod --archetype spider --seeds 2,14,20,28 --count 4 --size 0 --gene legs.length=0.3 --gene legs.spread=0.5 --gene abdomen.size=0 --gene head.size=1 --gene head.eyes=bead --gene head.eyeSize=1 --gene head.mouth=fangs --gene head.mouthSize=1 --clip walk --fps 12 --max-frame 22 --name skitter_spider --out $OUT/raw/skitter

# Chomper: pause then charge (quadruped boar/beast: short body, no tail, big head and jaw)
$R --family quadruped --archetype boar --seeds 34,51 --count 2 --size 0 --gene torso.length=0 --gene tail.length=0 --gene head.snout=0.2 --gene head.size=1 --gene head.jaw=1 --gene head.eyeSize=1 --gene head.teeth=tusks --gene legs.length=0.2 --clip walk --fps 12 --max-frame 28 --name chomper_boar --out $OUT/raw/chomper
$R --family quadruped --archetype beast --seeds 5,16 --count 2 --size 0 --gene torso.length=0 --gene tail.length=0 --gene head.size=1 --gene head.jaw=1 --gene head.eyeSize=1 --gene head.teeth=fangs --gene legs.length=0.2 --gene neck.length=0 --clip walk --fps 12 --max-frame 28 --name chomper_beast --out $OUT/raw/chomper

# Snap + repack every raw sheet, 8x previews, then the contact sheet
for f in $OUT/raw/*/*.png; do
  python3 tools/palette_snap.py "$f" --out "$OUT/$(basename "$(dirname "$f")")/$(basename "$f")" --preview 8
done
python3 tools/creature_export/contact_sheet.py $OUT          # -> $OUT/contact_sheet.png (6x, labeled)
```

To browse more seeds, widen `--seeds` (e.g. `1-300`) and raise `--count`.

## palette_snap.py

```sh
python3 tools/palette_snap.py SHEET.png --out OUT.png [--meta SHEET.json] [--clip walk_E] \
    [--exclude 6,30] [--alpha-threshold 128] [--preview 8]
python3 tools/palette_snap.py --check OUT.png [MORE.png ...] [--exclude ...]
```

- Alpha becomes 0 or 255 (`>= --alpha-threshold` is opaque).
- Opaque pixels map to the nearest palette colour in CIELAB (D65). Index 31 (projectile magenta) is
  never a target; `--exclude` removes more indices.
- Repack: frames of the chosen clip are cropped to the union of their content bounds, then get a
  1px transparent border, laid out in one horizontal row. Sidecar `OUT.json`:
  `{"format":"game.sheet","frame_w","frame_h","frames","fps","origin":[x,y],"source":{generator, generator_version, family, archetype, seed, name, content_id, clip, loop, sheet}}`.
  `origin` is the ground point inside a frame (padding included), from the generator metadata.
- The output is verified before exit (palette colours only, binary alpha, index 31 unused, empty
  frame borders, sizes match the sidecar); any failure exits 1. `--check` runs only that check.
