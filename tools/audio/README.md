# Archimedes sound measurements

Tools for measuring what VIDC1 and the board actually do, so QTM's tables and sample
preparation can be tuned to the real hardware. Write-up and findings:
<https://claude.ai/artifact/KG2G4D2CeDEciRAaE6jbPh>

| File | What it does |
|---|---|
| `vidc.py` | Model of the DAC (datasheet §6.10), QTM's linear-to-log table and volume subtract, and the time-division output |
| `analyse_model.py` | Offline analysis from the model, before any recordings |
| `codesweep.py` | Test 1's sequence; writes `arc/codesweep_seq.asm` and `codesweep.json` |
| `arc/codesweep.asm` | Test 1 for the Arc: plays raw DAC codes through its own sound handler |
| `build_arc.py` | Builds the Arc tests into `build/<name>,ff8` |
| `emulate.py` | Runs a test in headless Arculator and captures `build/<name>-arculator.wav` |
| `analyse_codesweep.py` | Analyses a recording of test 1 |

Needs Python 3 with numpy, scipy and matplotlib.

Built copies of the five Arc programs are in `arc/bin/` (`name,ff8` = RISC OS Absolute),
for anyone who wants to record a machine without building them. Rebuild with `build_arc.py`
and copy them there if the sources change. Findings for a general audience:
`docs/archimedes-audio-measured.html`.

## Test 1: the DAC code sweep

```
python tools/audio/build_arc.py                          # -> build/codesweep,ff8
python tools/audio/emulate.py codesweep                  # optional: check it in Arculator
python tools/audio/analyse_codesweep.py <recording>.wav  # -> <recording>.json/.png/-linlog.bin
```

On the Arc (RISC OS 3), from the F12 command line or outside the desktop, run `codesweep`.
It runs for about 2 minutes 15 seconds in 1-channel mode at 48 µs, stereo centre, then
puts the sound system back. Escape aborts and restores.

Recording, with the UCA222 or any line input:

- 48 kHz, 16-bit or better, stereo. Line out or headphones of the Arc to line in.
- Set the input gain first. Run the program, watch the meter during the first marker
  (the loud 1 kHz tone, 1 s in, the loudest thing in the test), aim for about −6 dBFS
  peak, then press Escape.
- Start recording, run the program, stop recording after it says "Done".
- Nothing else should be playing sound. Keep the volume and tone controls of anything
  between the Arc and the recorder fixed for the whole run.

The analyser finds the markers itself and works out the Arc's real sample rate from them,
so the start and end of the recording don't need to be trimmed.

Expected under Arculator: the datasheet curve, to within a fixed 0.02 i at the lowest
codes, which is integer rounding in Arculator's own audio path.

## Tests 2-5

Built by `build_arc.py` from `soundtests.py`, on a shared engine (`arc/engine.asm`,
`arc/engine_blob.asm`). Each phase starts and ends with a 1 s full-scale marker.

| Program | Test | Length | What it plays |
|---|---|---|---|
| `freqresp` | 2, frequency response | ~50 s | 31 sine tones, 20 Hz-20 kHz at 24 us, then to 9.5 kHz at 48 us |
| `noise` | 3, noise floor | ~60 s | +0 and -0 silence in MODEs 12, 13, 27, 28, then 5 s with sound DMA off |
| `slots` | 4, slot settling | ~115 s | 4 channels at 48, 32, 24, 16, 12 us; one slot plays, the others at 0 or full scale |
| `stereo` | 5, stereo positions | ~60 s | a 100 Hz square at each of the 7 positions |

```
python tools/audio/analyse_tests.py <freqresp|noise|slots|stereo> <recording>.wav [--phases 1,2]
```

Start each in MODE 12. `noise` changes mode itself and puts the original back; it skips any
mode the monitor can't show and says so, in which case pass `--phases` with the ones that
ran. Same recording set-up and gain as test 1, one WAV per program.

Under Arculator: `sound_filter` in `arc.cfg` selects a 2.2, 3.2 or 5 kHz second-order
low-pass (there is no off), which `freqresp` measures; MODEs 27 and 28 are skipped; and
`slots` phases with the other slots at full scale overflow Arculator's 16-bit mix, so
only phases 1, 3, 5, 7, 9 analyse there. None of these apply to real hardware.
