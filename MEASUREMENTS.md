# Step 1 — measured baseline

Where QTM's time actually goes on an 8 MHz ARM2, measured rather than derived. This is
step 1 of [`OPTIMISATION.md`](OPTIMISATION.md) §6, and it replaces the estimates in §1 and
§3.2.3 with numbers.

## Setup

| | |
|---|---|
| Machine | Arculator `a3000-riscos311` — A3000, ARM2 @ 8 MHz, 4 MB, RISC OS 3.11 |
| Build | `alpha` (`python build.py alpha`), byte-identical to `ref/QTMModule-alpha` |
| Sample rate | **48 µs / channel**, set at runtime via `QTM_SetSampleSpeed` |
| Channels | 4 (measured: `dma_calls` / fills = exactly 4.0) |
| Song | `coolbeans.mod` (M.K., 4-channel) unless stated; corpus of 7 for Result 3 |
| Window | 5 s, after a 1 s settle, from a deterministic restart |

The alpha build is the instrument because it is the only variant carrying the ten `dma_*`
path counters and `swi_qtmdebug`. It is byte-identical to its reference, so it is a
trustworthy measurement build — but note it also *is* the instrument's cost: the counters
add a handful of instructions per channel-fill to the dispatch path.

### Why 48 µs, and how

48 µs is the standard setup for an 8 MHz machine (24 µs is a 12 MHz aspiration). The
compile-time `uS`/`dma` constants only set the *default*: `QTM_SetSampleSpeed` takes
16–96 µs at runtime on non-RasterMan builds, so the byte-identical `alpha` build can be run
at 48 µs without synthesising a new variant. Confirmed three ways:

- `a2_DMAsound` entry count fell from 300 to 199 per 2 s — 208 samples × 48 µs = 9.984 ms,
  so 100.2 fills/sec;
- VIDC's own sound register reads back 83,333 Hz;
- 4 × 208 × 100.2 = **83,333 bytes/sec**, which is exactly the figure OPTIMISATION.md §1
  assumes.

**§1 was right, for 48 µs.** `dma` is samples *per channel per fill* and `uS` is the
per-channel period — the pair I first measured (32 µs, the `release` default) is 1.5×
busier at 125,000 bytes/sec.

### Method

Cycle-exact per-instruction profiling over an address range; the range total is the
aggregate. This is necessary because QTM builds its mixers at runtime, so the inner loops
live in ~28 KB of generated code outside the module and are spread over thousands of
distinct addresses — a "top N hottest" view cannot sum them, but a range total can.

Addresses (this session; the RMA base moves between runs — derive it from
`swi_qtmdebug`, which returns `a2_jumptable`, and subtract its listing offset `&64D8`):

| range | address | what |
|---|---|---|
| ALL | `&1821F04 + &11000` | module + workspace + generated code |
| MIXER | `&182A4E4 + &6B20` | the eight runtime-unrolled inner loops |
| DISPATCH | `&1827578 + &900` | `a3_DMAsound` … `a2_chanctrl` and friends |

Determinism comes from `QTM_Stop` / `QTM_Pos 0,0` / `QTM_Start` before each window. Two
independent measurements of the same window agreed to **0.06 %** on instruction count, so
the workload really is identical across runs — which is what makes the mode comparison a
controlled experiment.

> Trap worth recording: driving BASIC through `type_text` on a UK layout emits `@` where
> `"` is meant, so every `SYS "QTM_Stop"` silently failed with *Unknown or missing
> variable* and the song was never restarted. Use numeric SWI numbers (`SYS &47E42`) for
> typed commands, or put anything quoted in a file and `*Exec` it.

## Result 1 — the split

MODE 0 (640×256, 1 bpp), 5 s = 40,000,000 cycles:

| | cycles | share of machine | share of QTM |
|---|---:|---:|---:|
| Mixer (unrolled inner loops) | 3,563,680 | **8.91 %** | 89.7 % |
| DMA dispatch (per fill, per channel) | 257,061 | 0.64 % | 6.5 % |
| Interpreter + everything else | 154,184 | **0.39 %** | 3.9 % |
| **QTM total** | 3,974,925 | **9.94 %** | |

**Mixer : interpreter = 23 : 1.** §1 predicted 10:1–30:1 and put the interpreter at
0.25–1.25 %; measured 0.39 %. The estimate holds, toward the lopsided end.

So the ordering in §1 is confirmed: an LSP-style stream frontend would attack 0.39 % of
the machine. There is nothing to win there.

## Result 2 — bandwidth sensitivity

Identical work, only the screen mode changed:

| | MODE 0 (1 bpp) | MODE 15 (8 bpp) | delta |
|---|---:|---:|---:|
| QTM total cycles | 3,974,925 | 5,533,967 | **+39.2 %** |
| Mixer cycles | 3,563,680 | 4,990,311 | **+40.0 %** |
| Mixer instructions | 1,347,383 | 1,346,549 | −0.06 % |
| Mixer mean cycles/instruction | 2.645 | 3.706 | +40.1 % |

The instruction counts are the same to within 0.06 %, so **the entire +40 % is video DMA
stealing cycles from the CPU.** MODE 15 costs 8× MODE 0's video bandwidth
(160 KB vs 20 KB per frame) and the mixer pays 40 % for it.

### The memory tax on the inner loop

417,664 output bytes per window. Against the templates' textbook cost, weighted by the
measured path mix (5.53 cycles/byte):

| | cycles/byte | vs textbook |
|---|---:|---:|
| Textbook (PRM instruction timings) | 5.53 | 1.00× |
| Measured, MODE 0 | 8.53 | **1.54×** |
| Measured, MODE 15 | 11.95 | **2.16×** |

**This is the most important number in step 1.** The clock-count model in
OPTIMISATION.md §3.2.3 understates real cost by 54 % in the cheapest screen mode and by
116 % in a 256-colour one — and it understates it precisely because it ignores memory
traffic, which is what Turbo attacks.

Measured instructions/byte is 3.23 against 3.31 predicted from the path mix, so the
template model itself is sound; it is only the *cycles* that the model gets wrong.

## Result 3 — path distribution

Seven tunes, 5 s each from position 0, 2008 channel-fills each
(raw: [`tools/measure/step1-paths.csv`](tools/measure/step1-paths.csv)):

| tune | steady any-vol | steady full-vol | repeat any-vol | repeat full-vol | dead | ending |
|---|---:|---:|---:|---:|---:|---:|
| coolbeans | 30.5 % | 0 % | 24.4 % | 6.1 % | 39.1 % | 0 % |
| chgwaves | 23.3 % | 0 % | 30.9 % | 2.9 % | 0 % | 0 % |
| mazefunky | 11.2 % | 23.3 % | 22.2 % | 0 % | 6.9 % | 0.8 % |
| punnik | 5.4 % | 6.9 % | 19.6 % | 0 % | 66.9 % | 0.4 % |
| autumn | 23.6 % | 1.6 % | 54.3 % | 0 % | 18.9 % | 0.5 % |
| squidring | 4.8 % | 0 % | **95.2 %** | 0 % | 0 % | 0 % |
| dlzsajt | 6.1 % | 3.9 % | 12.0 % | 34.9 % | 36.0 % | 0.4 % |
| **mean** | **15.0 %** | **5.1 %** | **36.9 %** | **6.3 %** | **24.0 %** | **0.3 %** |

Plus a *repeat-no-volume* path (looping but silent) averaging 9.4 %, and 36 % in
`chgwaves`. Rows do not quite reach 100 %: about 3 % of dispatches take
`a2_endnovol`-style routes that reach `a2_clearchannel` without touching one of these
nine counters.

An earlier version of this table used `raven-stereo`, which is a stereo test rather than a
tune and skewed full-volume badly (55 % on its own). It is replaced here by three complex
tunes; the effect of dropping it is noted below.

Three things fall out, and two of them change the plan:

**Repeating dominates — 52 % of all channel-fills are in the looping state.** In
`squidring` it is 95 %. The clean steady-state loop that §3 spends all its effort on is
only 20 % of the work.

What those 52 % actually cost needs care, and an earlier draft of this section got it
wrong. There is **no per-fill split**: `a2_chanctrl` selects one routine for the whole
fill, and `a2_repanyvol_loop` wraps inline and branchlessly with
`SUBGE R1,R1,R5,LSL #12` straight after the `ADDS`. So looping costs *one instruction per
byte* — 9 clocks/byte against the steady path's 8 — not a split. Removing it with a guard
gap is worth about 7 % of the mixer, not the much larger figure a split would have implied.

§4 keeps its promotion to first in the queue, but for a different reason: it is what makes
Turbo fit in the register file (§3.2.4), and it is a pure data change that can be verified
offline.

**Ending is negligible — 0.3 %.** §3.1 spends a paragraph on `a2_endanyvol_unroll`'s flag
juggling. It is real, but it is on a path that essentially never runs. The flag-budget
argument in §3.1 should be about the *repeat* paths instead.

**Full volume is a minority but not a rounding error — 11 % overall, 23 % in
`mazefunky`.** The first tune measured showed `dma_fv` = 0 and nearly supported concluding
the 6-clock full-volume path was dead code; the wider corpus does not. This matters
directly, because Turbo Form A at a modelled 6.75 clocks/byte would be *slower* than
today's 6-clock full-volume loop. Turbo therefore needs its own full-volume variant, and
the per-tick codegen of §3.2.2 is a requirement rather than an optimisation. (With raven
included this looked far more urgent at 19 %; at 11 % it is a real but secondary concern.)

**A third of all channel-fills produce silence** — 24 % dead plus 9 % looping-but-silent,
reaching 67 % in `punnik`. Cheap per byte (one `STRB`) but each still pays full dispatch,
which is another count against the four-pass structure.

## What this says about Turbo

Counting memory accesses rather than instructions, for the any-volume steady path:

| | fetches | reads | writes | total/byte |
|---|---:|---:|---:|---:|
| today | 5 | 1 | 1 | 7.00 |
| Turbo Form A | 4 | 1 | 0.25 | 5.25 |

−25 %, against the −16 % that instruction counting predicted. Measured cycles track
accesses well (8.53 cycles for 7 accesses in MODE 0; 11.95 for 7 in MODE 15), so Form A
should land near **−25 % in both modes** — better than §3.2.3's estimate, still short of
Steve's "around 1/2".

The half only appears with the skipped load (Form B), and Form B needs three channels or
a cleverer answer to the persistent-scratch problem. That ranking is unchanged; what has
changed is that the memory-traffic argument is now measured fact rather than a hypothesis,
and it is worth 1.5–2.2× what the clock-count model credited it with.

## Step 4 — the guard-gap mixer, measured

The `gg` variant (`python build.py gg`) is the first build here that is *not* a translation
of the original. `tools/gg/patch_dma.py` deletes `SUBGE R1,R1,R5,LSL #12` from the three
repeat loops and normalises the offset once per fill at the top of `a2_chanctrl` instead.
It has no reference binary and never will; the four that do still verify 4/4.

Samples come from `tools/prep`, loaded into an RMA block and pointed at by rewriting only
the **start address** in QTM's sample table — `rep_off` and `rep_len` carry over unchanged,
because the end pointer QTM derives is just `start + rep_off + rep_len`. No loader changes.

`coolbeans`, MODE 0, 48 µs, 5 s from position 0:

| | alpha (stock) | gg (guard gap) | change |
|---|---:|---:|---:|
| Mixer cycles | 3,563,680 | 3,436,574 | **−3.57 %** |
| Mixer instructions | 1,347,383 | 1,220,919 | −9.39 % |
| Share of machine | 8.91 % | 8.59 % | −0.32 pt |

**The model predicted this almost exactly.** 610 repeating fills × 208 bytes = 126,880
instructions that should disappear; 126,464 did. Each cost 1.005 cycles — a bare
instruction fetch, which is why a 9.4 % instruction cut is only a 3.6 % cycle cut: the
`SUBGE` was the cheapest instruction in the loop, and the expensive `LDRB`/`STRB` remain.

`coolbeans` is below average for looping (30.4 % against the corpus's 52.5 %), so a typical
tune should see about **−6 %**. That is the whole of the guard gap's direct value, and it
is worth restating that this is not why it matters: it matters because it frees the
per-channel repeat-length register that Turbo cannot afford.

The path counters are identical between the two builds (`an` 611, `rav` 487, `rfv` 123,
`ce` 783), confirming the dispatch decisions are unchanged and the two runs are mixing the
same music.

### Does it sound right?

Exact equivalence was already proved offline (`tools/prep/verify.py`, 17/17 songs). The
emulator's job is to confirm the ARM implementation matches that model.

Captured 5 s from each build at the same song position and compared:

| | value |
|---|---|
| Peak / RMS | 5847/10051, 3280/3730 vs 5849/9973, 3278/3736 |
| Spectral correlation (<16 kHz) | **0.999436** |
| Envelope error (10 ms RMS windows) | mean 0.85 %, median 0.34 % |
| Near-clipping samples | 0 in both |

The captures are **not** bit-identical, and cannot be: the emulator resamples 83,333 Hz to
48,000 Hz, and the two runs start ~12 ms apart, so a fractional-sample offset makes almost
every sample differ while the signal is the same. That is why the comparison is done on
quantities insensitive to sub-sample phase. Sample-wise comparison of the captures is
meaningless here and was discarded as such, not massaged.

### The negative control

Correlation with the stock build shows the two are the same music, but not that the guard
gap is doing anything — a patch that quietly failed to apply would score just as well. So
the same `gg` build was run again against **unprepared** samples, with the bank repoint
removed and nothing else changed:

| | spectral correlation vs stock |
|---|---:|
| `gg` + prepared samples | **0.999010** |
| `gg` + unprepared samples | **0.789279** |

Without a guard the mixer reads past the loop end into whatever follows, and it is plainly
audible. That establishes both halves of the claim: the patch is live and load-bearing, and
the prepared data is what makes it correct.

### What is still owed

A byte-for-byte comparison of the DMA buffer — the mixer's exact output, before any
resampling. The mechanics work: break on `a2_DMAsound`, and at each break the buffer filled
by the *previous* call can be read whole (832 bytes, alternating `&01F07000`/`&01F06000`,
de-interleaving cleanly into 4 × 208). What is missing is a way to guarantee both builds
are at the same song position, since each `RMKill`/`RMLoad` re-lays the RMA and playback
starts a few fills apart. The fix is to match captures on QTM's own position fields in the
workspace rather than assuming two runs align — worth doing before trusting a *small*
difference, though the negative control already covers the large ones.

## Step 5 — Turbo Form A, benchmarked in isolation

Turbo needs bank-relative offsets, which are computed at note-on, so it cannot be confined
to `qtm_dma.asm` the way step 4 was. Before paying for that, the inner loop was measured on
its own: `tools/bench/bench.asm`, four candidate loops each filling one 832-byte DMA buffer
(4 channels × 208, stride 4 — QTM's real layout), run under Arculator with QTM's sound
shut down. A3000, MODE 0, 10 fills per test, 8320 bytes each.

The four channels read from regions 8 KB apart, deliberately: reading them all from one
DRAM page would flatter the packed loops, which is exactly what is under test.

| test | cycles | cycles/byte | textbook | measured/textbook | accesses/byte |
|---|---:|---:|---:|---:|---:|
| 0 QTM any-volume (today) | 114,502 | 13.76 | 8.00 | 1.72× | 7.00 |
| 1 QTM full-volume | 92,256 | 11.09 | 6.00 | 1.85× | 5.00 |
| **2 Turbo Form A** | **85,595** | **10.29** | 6.75 | 1.52× | 5.75 |
| 3 Turbo prescaled | 80,089 | 9.63 | 5.75 | 1.67× | 4.75 |

**Turbo Form A is −25.2 % against the path QTM actually uses.** The clock-count model in
§3.2.3 predicted −15.6 %; counting memory accesses predicted −25 %. The measurement lands
on the access-based figure almost exactly, which is the clearest confirmation yet that
Steve's bandwidth intuition is the right way to think about this machine and instruction
counting is not.

Two results that change the design:

**Form A beats the full-volume path too, by 7.2 %.** §3.2.3 warned that Form A at a
modelled 6.75 clocks/byte would be *slower* than today's 6-clock full-volume loop, and that
Turbo would therefore need its own full-volume variant with per-tick codegen to select it.
That is now measured to be false: packing wins even against the cheaper loop, because it is
trading instruction-count for memory traffic and traffic is what costs. Per-tick codegen
drops from a requirement to an option worth maybe 6 % more (test 3 over test 2).

**Prescaled samples buy less than expected.** Test 3 removes the volume subtract entirely
and gains only 6.4 % over test 2, for *N* × sample memory. Tick-patched volume immediates
keep that gain at zero memory cost, so prescaling stays off the table.

### Caveats specific to this benchmark

Absolute cycles/byte are higher than the in-situ figures above (13.76 for pure any-volume
against QTM's path-averaged 8.53) because this runs one path with no cheap clearing fills
mixed in, from application RAM rather than the RMA, with a harsher four-region access
pattern. The *relative* comparison is the result; the absolute numbers are not comparable
with Result 2. All four tests share those conditions, so the ratio is sound.

Every channel also uses the same increment (0.8125) and none of the loops handles a sample
ending, so this measures steady-state throughput only.

## Caveats

- One machine (A3000/ARM2/MEMC1), one emulator. Arculator's cycle model is good but is a
  model; a real A3000 would be the final word.
- Seven tunes is enough to show the spread, not enough to claim a population mean. Pick
  real, complex tunes: test/demo modules distort the mix badly (see the `raven` note).
- About 3 % of channel dispatches are not attributed to any of the nine counters.
- The foreground is an idle BASIC prompt. Shares of the machine are therefore shares
  against a near-idle foreground; absolute mixer cycles are the transferable number.
- The alpha build's counters are themselves in the dispatch path, inflating the 0.64 %
  dispatch figure slightly.
- MODE 15 dispatch/interpreter were not measured separately; only ALL and MIXER.
