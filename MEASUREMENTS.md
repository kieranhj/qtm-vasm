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
