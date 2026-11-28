# Getting the best audio out of an Archimedes with QTM

A practical guide for our demos: what limits MOD playback on a VIDC1 Archimedes, what each
fix is worth (measured, not guessed), and the procedure to follow before a party so that both
the live showing and our own capture sound as good as the hardware allows.

Everything here was measured in November 2026 on three machines: an A3020 with the stardot
filter bypass (**A3020**), a second bypassed A3020 (**A3020b**) and an A3010 with its original
filter (**A3010**). The tools are in [`tools/audio/`](tools/audio/README.md) (measuring a
machine) and [`tools/playback/`](tools/playback/README.md) (preparing music for it). The
community write-up is [`docs/archimedes-audio-measured.html`](docs/archimedes-audio-measured.html);
the lab notes, with every intermediate result, are `docs/archie-sound-fidelity.html`. The raw
recordings and their analyses are in `recordings/` (WAVs in Git LFS).

---

## 1. The checklist

For a demo whose music we control, in order of value:

1. **Decide where the music will be heard** (section 6): on party hardware we don't know, or
   from a capture we make ourselves. The two want different settings.
2. **Brief the musician** (section 5): samples at a sensible rate, bright samples (hi-hats,
   rides, cymbals) not normalised to full scale, 4 channels unless 6 or 8 are really needed.
3. **Run QTM at 24 µs** if the CPU budget allows, 32 µs if not; never 48 µs on a machine without
   its filter (section 4.3).
4. **Replace QTM's conversion table** (section 4.1): the datasheet-nearest table on unknown
   hardware (+2 dB on every machine tested), the machine's own measured table on a machine we
   have measured (+3 to +4 dB, and up to 16 dB less harmonic distortion).
5. **Prepare the samples offline** for the target (section 4.2): converted straight to log codes
   at full precision, and filtered to undo the machine's measured frequency response.
6. **Use a 24 MHz screen mode**, or correct for the clock (section 4.4): in a VGA mode an
   A30x0's sound runs 4.9% fast.
7. **Check it**: smoke-test in Arculator, then record both the prepared and unprepared versions
   on the real machine and compare them with `compare_recordings.py` (section 7).
8. **For our own capture** (section 6.2): record from a bypassed machine at line level, and
   correct its measured response in the edit rather than in the samples.

---

## 2. How the sound gets out

VIDC1 has up to 8 channel **slots** and one DAC. QTM writes each MOD channel into the sound DMA
buffer, interleaved; VIDC plays the bytes in turn, each slot with its own stereo position.
The channels are summed afterwards, in analogue. Consequences:

- **No digital mixing loss.** Each channel gets the DAC's full range; nothing clips or loses
  precision from summing.
- **Each channel only owns its slots.** One channel at full volume reaches at most 1/4 of full
  scale in 4-channel mode, 1/8 in 8-slot mode (which a 6-channel MOD uses). Music therefore
  peaks around −11 dBFS on a line input set for a full-scale test tone. That is normal.
- **The DAC is 8-bit logarithmic**: sign plus 7 bits on 8 "chords" of 16 steps, each chord's
  step twice the last (VIDC Datasheet §6.10). About 72 dB of range, but at loud levels its steps
  are about 2 bits coarser than an 8-bit linear sample. Its signal-to-distortion is roughly
  constant, about 35 dB, from full scale down to −42 dBFS, *if* the source has more than 8 bits.
- **RISC OS stores the sign in bit 0** (`(magnitude << 1) | sign`); the board routes VIDC1's
  pins to match (measured, all three machines).
- **The sample rate follows the VIDC clock.** QTM's period is per frame of slots; at 24 µs and
  4 channels each slot is 6 µs. The minimum is 3 µs per slot, so 8-slot modes can't go below
  24 µs.

On the A3010/A3020/A4000 the audio is a thick-film module, the **0194007 Audio Hybrid**
(drawing 0194,500 sheet 2). Per channel: (1) an LM324 subtractor of VIDC's "+" and "−" pins
whose feedback R‖C makes it a **first-order integrator**, then (2) a **third-order Sallen-Key
filter** and a BC239 emitter-follower driver. The stardot bypass for these machines feeds C60/C68
from stage 1, removing stage 2 and keeping the integrator.

---

## 3. What limits quality, measured

| Limit | Measured | Can we fix it? |
|---|---|---|
| **Original filter** (A3010) | 4th-order low-pass, −3 dB at 2.84 kHz; −5 dB at 3.2 kHz, −41 dB at 10 kHz, −64 dB at 20 kHz | Not by software above ~5 kHz. The stardot bypass fixes it. |
| **Integrator left by the bypass** (A3020, A3020b) | 1st-order low-pass at 3.20 / 3.43 kHz; −10 dB at 10 kHz, −16 dB at 20 kHz | Yes, exactly: it is a plain first-order roll-off. |
| **Images** with the filter bypassed | First image at (rate − f) is as loud as the tone before the integrator; at 48 µs an 8 kHz tone images at 12.8 kHz | Yes: run at 24 µs (images start above ~33 kHz). |
| **QTM's conversion table** (`Sound_SoundLog`) | Always rounds up; inputs 120–127 share the top code | Yes: +1.9 to +2.3 dB SINAD with the datasheet-nearest table, every machine. |
| **The real DAC** | Chords 1–3 steps 9–20% too large, level falls back at codes 48 and 64 (all three chips); a different jump at code 112 on each chip (+3.9, −1.5, −5.1 *i*) | Yes, per machine: a measured table, +2.8 to +4.3 dB, THD −33 → −48 dB at −6 dBFS. |
| **± half mismatch** | 0.54 dB flat (A3020), 0.2–0.4 dB at loud levels only (A3020b), < 0.1 dB (A3010): the board's resistors | Yes, per machine, in the measured table. |
| **8-bit linear samples** | Below about −20 dBFS the 8-bit source, not the DAC, limits quality | Yes: convert to log offline from full precision. |
| **QTM's nearest-sample stepping** | −17 dB distortion for a bright test loop, the same at 48, 32 and 24 µs; mostly the images Paula makes too | Partly: its treble droop is exactly correctable in the samples; 2× pre-upsampling would take 6 dB off the rest (not built). |
| **QTM's volume subtract** | Only 46 of 65 volumes distinct (60–64 identical); 0.2–0.7 dB loud; volumes 1–2 distorted | Yes: a volume table from the measured DAC. |
| **Loud channels pulling the others** | With three slots at full scale, a fourth reads +0.5 dB (positive) to −1.8 dB (negative) at 48 µs; −0.4 dB at 12 µs | Partly: faster rates reduce it. |
| **Noise** | About −76 dB below a full-scale sine; hum −87 dB; line whine −98 dB bypassed, −117 dB filtered | Not needed: 35–40 dB below the DAC's own error. |
| **Stereo** | Positions as the datasheet says; 36.7 dB separation at the hard positions | No need. |
| **Screen mode** | In a VGA mode (25.175 MHz) an A30x0's sound runs 4.9% fast, 0.83 semitones sharp | Use a 24 MHz mode, or let QTM measure the clock. |

---

## 4. The fixes in detail

### 4.1 The conversion and volume tables

QTM 1.49b builds two tables at module initialisation, in its data block (whose address it keeps
in its module private word; `OS_Module 18, "QTMTracker"` returns it in R4):

| Table | Offset | Size | Built from |
|---|---|---|---|
| `linlognew`, linear-to-log, used once when a MOD is loaded | `&1B00` | 256 | `Sound_SoundLog` of each signed byte |
| `volumetable`, the base volume table (a subtract from the code byte; `&FE` = silent) | `&0380` | 65 | `Sound_SoundLog` of each volume |

Both can be patched from outside QTM **before `QTM_Load`**, then `QTM_Volume 64` rebuilds the
scaled music and sample volume tables from the new base table. The offsets are QTM 1.49b
release's (`src/release/qtm_offsets.h.asm`); check them for any other build. Kill or reload QTM
afterwards so patched tables don't leak into other software.

Which table:

| Target | Table | Gain over QTM's own |
|---|---|---|
| Unknown machine | Datasheet-nearest (`tools/audio/vidc.py`, `nearest_linlog(2.0)`) | +1.9 to +2.3 dB on all three machines |
| A machine we have measured | Its own, from test 1 (`analyse_codesweep.py` writes it) | +2.8 to +4.3 dB |
| A "typical VIDC" average | Not yet: built from two machines it helped one and hurt the other | needs more machines |

With offline sample preparation (4.2) the conversion table is replaced by an **identity** table
instead: the samples already hold the right log codes and QTM's load-time pass must leave them
alone. That is what `!QTMBest` does.

### 4.2 Preparing the samples (`tools/playback/prep_best.py`)

```
python tools/playback/prep_best.py song.mod out.mod --machine a3020 --report
```

Per sample:

1. **Filter** with a 63-tap linear-phase FIR that undoes the machine's measured analogue
   response (from its test 2 recording) at the output frequencies the sample is mostly played
   at (the median note in the patterns), and the treble droop of QTM's nearest-sample hold
   (|sinc|, exact at every pitch). The boost is capped (+12 dB). On a filtered machine the boost
   is faded out where it can't flatten the response (A3010: from 4.5 to 7 kHz), which leaves
   headroom for the range it can fix. Loops are filtered circularly, so loop points stay seamless.
2. **Scale**: a fixed song gain (−3 dB), then each sample gets as much of its boost as fits under
   full scale (`raw + a·(filtered − raw)`, largest `a ≤ 1`). The passband level never changes, so
   the balance between samples is the musician's.
3. **Convert** each value to the code whose *measured* level, for its half, is nearest. This
   skips the 8-bit linear stage entirely and corrects the ± mismatch.

`--report` lists samples that didn't get the full boost. That list is the musician's to-do
list (section 5): almost always drums, hi-hats and bright loops normalised to full scale.

The volume table for the same machine comes from `prep_best.voltable()`: for each MOD volume,
the subtract whose gain on sines at 0, −6 and −12 dBFS, played through the measured DAC, is
nearest v/64.

A machine profile is a small JSON file in `tools/playback/machines/`. Without a `codesweep` the
datasheet's DAC levels are used; without a `freqresp` the response is taken as flat, so only the
hold droop is corrected. The profiles so far: `a3020`, `a3010`, `generic` (any VIDC1 machine) and
`a3020-capture` (section 6.2).

```json
{
  "label": "A3010, original filter",
  "short": "A3010 (original filter)",
  "codesweep": "recordings/codesweep-test1-mode12-a3010-filter-level-60.json",
  "freqresp": "recordings/freqresp-test2-mode12-a3010-filter-level-60.json",
  "cap_db": 12.0,
  "fade_hz": [4500, 7000]
}
```

What it achieved on STNICCC, recorded from both players and compared level-matched:

| Band | A3020, bypassed | A3010, original filter |
|---|---|---|
| below 2 kHz | within ±0.5 dB | within ±0.5 dB |
| 3–4 kHz | +2.7 dB | +4.3 dB |
| 4–6 kHz | +3.0 dB | +7.8 dB |
| 8–13 kHz | +3.1 to +3.6 dB | (noise floor) |
| 16–24 kHz | −1.5 to −4.4 dB (images gone at 24 µs) | (noise floor) |

By ear: clearer on the A3010; the bypassed A3020 remains much brighter, because no correction
can recover the 24–41 dB the original filter takes above 6 kHz.

### 4.3 Choosing the sample period

| Period | Rate per channel | Images (filter bypassed) | Mixer load, 4 channels |
|---|---|---|---|
| 48 µs | 20.8 kHz | **Audible**: 8 kHz images at 12.8 kHz | ≈ 670 k clocks/s, 10–15% of an 8 MHz ARM2 |
| 32 µs (QTM's default) | 31.25 kHz | Content above ~11 kHz images below 20 kHz | ≈ 1.0 M clocks/s |
| 24 µs | 41.7 kHz | Images start above ~33 kHz | ≈ 1.3 M clocks/s, 20–30% of an ARM2 |

Mixer cost scales with channels mixed × rate (`OPTIMISATION.md` §1: about 8 clocks per byte), so
a 6-channel MOD at 24 µs costs about 1.5× the 4-channel figure. Short slots are not a problem:
levels hold within 0.3 dB down to 3 µs slots. With the original filter fitted the images are
filtered anyway, so the rate matters much less there; it still reduces the interaction between
loud channels.

QTM's RasterMan variants fix the period at build time (`rm24`, `rm48`); `QTM_SetSampleSpeed` is
ignored in them.

### 4.4 Screen mode and clock

On A30x0-class machines the VIDC clock follows the screen mode: 24 MHz in the TV-rate modes
(MODE 12, 13 and friends), 25.175 MHz in VGA modes (MODE 27, 28). RISC OS assumes 24 MHz, so in a
VGA mode the sound runs 4.9% fast. Run music in a 24 MHz mode, or rely on QTM's clock measurement
(`checkclockcalc`, pre-A5000 machines) and check the pitch.

### 4.5 Correcting the response after the Arc

The integrator a bypass leaves is a first-order low-pass, so a first-order treble shelf after the
Arc undoes it exactly (for 3.2–3.4 kHz: +10 dB at 10 kHz). After the Arc costs no headroom and
needs no per-sample aiming, so it is better than the in-sample correction **whenever we control
the playback chain** (an amp with tone controls, or the edit of a capture). It works much less
well on a filtered machine: at 8 kHz the A3010's music is only ~13 dB above the noise, so a big
boost there lifts the hiss with it.

---

## 5. Briefing the musician

- **Leave headroom on bright samples.** A hi-hat, ride or bright loop normalised to full scale
  can only take part of its treble correction (STNICCC's hi-hats: 14–21%; Space Trip's "all
  drums": 15%). Normalise those to about −6 dBFS and let the mix volume do the rest. Bass and
  pads can stay at full scale.
- **Sample rates**: anything from ~8 kHz up works; brighter material benefits from 16–22 kHz
  sources, since content above the sample's own Nyquist can't exist and the correction can only
  work up to it.
- **4 channels unless needed.** 6 or 8 channels use 8 slots, halving each channel's share of the
  DAC and costing 1.5–2× the mixer time.
- **Avoid volumes 1–2 for anything important** with QTM's own table (they distort); with a
  measured volume table they are fine.
- **Write at proper levels, not hot.** Because the log DAC's error is a fixed fraction of the
  level, turning things down costs very little quality on the Arc, unlike an 8-bit linear DAC.
- **Deliver the ProTracker MOD itself**, not a pre-converted file, so the preparation can be
  redone for each target machine.

---

## 6. Two ways the music will be heard

### 6.1 Live, on party hardware we don't control

We usually don't know which machine, whether its filter is bypassed, or what it plays into.
Use what helps on every machine and costs nothing:

- 24 µs (or 32 µs if the CPU budget is tight);
- the **datasheet-nearest conversion table** and a datasheet-derived volume table: +2 dB
  everywhere;
- samples converted offline to log codes from full precision, with **only the hold-droop
  correction** (no machine response correction: on a bypassed machine it would be right, on a
  filtered one too little, on an unknown one a guess). The `generic` profile does exactly this:
  `build_apps.py --machine generic`;
- a 24 MHz screen mode for the music parts;
- the musician's headroom on bright samples (section 5).

If the organisers can tell us the machine, measure one like it (section 7) and prepare for it.

### 6.2 From a capture we make ourselves

This is how we can guarantee the result. Record on **our bypassed A3020**, which we have measured:

1. Build the demo with that machine's measured tables, 24 µs, samples converted offline, using
   the `a3020-capture` profile: the A3020's measured levels and the hold-droop correction, but
   no response correction, because the integrator is corrected in the edit instead (4.5): no
   headroom lost, no per-sample compromise.
2. MODE 12-class screen modes for the music, or check the pitch.
3. Record line-out (the headphone socket; the internal speaker is switched out when a jack is
   in) into a 48 kHz, 24-bit or 16-bit interface. Set the input so the loudest passage peaks
   around −6 dBFS; music on the Arc sits well below a test tone (section 2), so normalise in the
   edit rather than pushing the input.
4. Avoid ground loops: a laptop on battery, or check the silence for 50 Hz harmonics.
5. In the edit: apply the inverse of the measured response (first-order shelf at 3.2 kHz for this
   machine, from `recordings/freqresp-test2-mode12-a3020-no-filter-level-60.json`), cut below
   about 15 Hz and above 20 kHz, then normalise.

---

## 7. Measuring a new machine

Needs the machine, a line input (the Behringer UCA222 at Windows level 60 was fine), and about
15 minutes. Full instructions: [`tools/audio/README.md`](tools/audio/README.md).

```
python tools/audio/build_arc.py                       # programs in build/ and tools/audio/arc/bin/
```

On the Arc, in MODE 12, from the F12 command line, record each to its own WAV:

| Program | Test | Length | Needed for |
|---|---|---|---|
| `codesweep` | 1, DAC code sweep | 2¼ min | the conversion and volume tables |
| `freqresp` | 2, frequency response | 50 s | the response correction |
| `noise` | 3, noise floor | 1 min | optional |
| `slots`, `stereo` | 4, 5 | 2 min, 1 min | optional; system behaviour, not per machine |

```
python tools/audio/analyse_codesweep.py recordings/codesweep-<machine>.wav
python tools/audio/analyse_tests.py freqresp recordings/freqresp-<machine>.wav
```

Then add `tools/playback/machines/<machine>.json` pointing at the two `.json` results, and:

```
python tools/playback/build_apps.py --machine <machine>         # both players + !Spark archive
python tools/playback/emulate_apps.py --machine <machine> --song 2   # smoke test in Arculator
```

Record the same song from `!QTMOrig` and `!QTMBest` on the machine and compare:

```
python tools/playback/compare_recordings.py orig.wav best.wav --out recordings/<song>-<machine>-best-vs-orig
```

Expect the midrange within half a dB and the treble lift the profile predicts. Remember that
Arculator's own output filter (`sound_filter` in `arc.cfg`: 2.2, 3.2 or 5 kHz, no off) means the
emulator only checks that things run, never how they sound.

---

## 8. Not done yet

- **2× pre-upsampled samples**: modelled at 6 dB less stepping distortion, at any rate. Needs the
  patterns' periods halved, which changes how vibrato and portamento behave; not attempted.
- **Noise-shaped log conversion**: choosing codes by error diffusion. Not modelled.
- **A typical-VIDC table**: needs recordings from more machines (the findings page asks for them).
- **Other boards**: the A3000, A310/A305/A440, A410/1–A440/1, A5000 and A540 have different filters
  and may have different integrators; unmeasured.
- **A more aggressive A3010 profile** (+18 dB cap, −6 dB song gain): would stretch its usable top
  end from about 5 to about 6 kHz.
- **Per-song headroom**: Space Trip would get twice as much drum correction with 3 dB more song
  headroom; `prep_best.py --gain` exists but isn't tuned per song.
- **Distortion gains on real music** can't be measured from a music recording; a test that plays a
  known multitone through QTM both ways would.
