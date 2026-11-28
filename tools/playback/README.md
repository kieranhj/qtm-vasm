# Best-possible QTM playback

The why and the procedure: [`../../AUDIO.md`](../../AUDIO.md).

Builds two RISC OS apps for one measured machine, to compare by ear:

- `!QTMBest`: the MODs prepared for that machine, QTM's tables replaced, 24 us per frame.
- `!QTMOrig`: the original MODs and QTM 1.49b exactly as shipped (32 us).

```
python tools/playback/build_apps.py --machine a3020    # or a3010
python tools/playback/emulate_apps.py --machine a3020 --song 1   # optional smoke test in Arculator
```

Output in `build/playback/<machine>/`: the two apps, and `qtmcompare-<machine>,ddc`, a !Spark
archive of both inside a folder `QTM<model>` (written by `tools/spark.py`). Each app switches
to MODE 12, plays one of four Rhino MODs on keys 1-4 (S stops, Q quits), and kills QTM on exit.

| File | What it does |
|---|---|
| `prep_best.py` | Prepares one MOD: filters each sample to undo the machine's measured response and QTM's nearest-sample hold, aimed at the note it is mostly played at; then converts it offline to the machine's measured DAC levels. Also builds the volume table. |
| `build_apps.py` | Prepares the four MODs, assembles the player twice, lays out both apps and packs the archive. |
| `arc/player.asm` | The player. The best build finds QTM's data block through its module private word (`OS_Module 18`), sets the load-time linear-to-log table to identity (the samples are already log codes) and the base volume table to the machine's, then 24 us. |
| `machines/*.json` | Machine profiles: which test 1 and test 2 recordings to use, the boost cap, and for a filtered machine where to fade the boost out. Without a test 1 result the datasheet levels are used; without a test 2 result the response is taken as flat. `a3020`, `a3010`, `generic` (unknown VIDC1 hardware) and `a3020-capture` (response corrected in the edit instead). |
| `emulate_apps.py` | Runs both apps in headless Arculator and captures a song. |

The MODs come from the Bitshifters repositories under `D:/bitshifters` (paths in
`build_apps.py`); the prepared MODs are build output and not committed. The table offsets
(`linlognew` at &1B00, `volumetable` at &380) are QTM 1.49b release's.
