# Audio tools

All game audio is made in code, so there are no licences to buy and nothing to credit.
The sounds use [Audio as Code](https://audioascode.com) (MIT, v0.4.0): 70 synthesized
instruments, no recorded samples.

```
pip install --break-system-packages "audio-as-code[loudness]" scipy
# ffmpeg is needed for the OGG files
```

## Sound effects

`python3 tools/audio/aac_sfx.py [ids...]` writes `assets/audio/sfx/<id>.wav`
(44.1 kHz mono, peak -1 dBFS, trimmed). One function per sound (`s_<id>`); times
are in seconds. Tonal and impact sounds are instrument notes; air, water and grit
(swing, dodge, splash, stink, dig...) are numpy noise layers with a smooth sweeping
filter. Takes about 10 s.

Ids must match `tools/audio/sfx.json` and `data/rules/audio.json` (a test checks the
two lists). The in-game volume of each sound is its `db` in `audio.json`.

## Music

One script per track in `tools/audio/music/`, writing `assets/audio/music/<id>.ogg`:

| Track | Script | Plays | Key, tempo, loop |
| --- | --- | --- | --- |
| menu | `menu.py` | Home and every menu | F major, 96 bpm, 40 s |
| gameplay | `gameplay.py` | the run | D minor, 150 bpm, 51 s |
| boss | `boss.py` | Mega Mole and the Final Swarm | D minor, 164 bpm, 47 s |
| game_over | `game_over.py` | result screen after a loss | D minor, 78 bpm, 25 s |
| victory | `victory.py` | result screen after a win | F major, 124 bpm, 23 s |

```
cd tools/audio/music && python3 gameplay.py
```

Each track is a seamless loop: the score is written three times, rendered once, and the
middle copy is cut out, so tails from the end flow into the start the way Godot loops it.
Loops are levelled to -16 LUFS with a look-ahead limiter at -1 dBFS; `music_db` in
`audio.json` sets the in-game level on top. A full render takes several minutes (the
modelled instruments are slow); renders are cached in the temp folder, so re-running
after a level change is instant.

## Old generators

`sfxr.py` (square-wave chiptune SFX, recipes in `sfx.json`) and `chiptune.py` (the first
placeholder music) still work and are kept for reference; their output is no longer shipped.
