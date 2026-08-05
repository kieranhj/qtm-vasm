# Where the headroom is in QTM's mixer

This carries forward the analysis in
[`LSP_ARM250/ANALYSIS.md`](../LSP_ARM250/ANALYSIS.md) §9, written while porting LSP to the
ARM250, and restates it against the code that now exists here. Everything below is
*derived from instruction counts and PRM timings, not measured* — see §5.

The byte-identical port is what makes any of it actionable: the mixer is now editable in
the same toolchain as `LSP_ARM250` and `rasterman-vasm`, and there are four verified
baselines to regress against.

---

## 1. The cost is the mixer, not the interpreter

The DMA fill workload is fixed by the hardware configuration, not by the player:
4 channels × 20 833 Hz = **83 333 bytes/sec**, whatever sits on top.

| | per second | share of 8 MHz ARM2 |
|---|---|---|
| **Mixer** — 83 333 bytes × 8 clocks | ≈670 k clocks | ≈8 % nominal; **≈10–15 %** allowing for ARM2+MEMC1 at ~4–4.7 MIPS, more in a high-bandwidth screen mode |
| **Interpreter** — ~50 ticks/sec × 400–2000 clocks | ≈20–100 k clocks | **≈0.25–1.25 %** |

**Roughly 10:1 to 30:1 in favour of the mixer.** The ordering is safe; the magnitudes are
not. This is why swapping in an LSP-style stream frontend would attack ~1 % of the cost —
on the Amiga, Paula *is* the mixer, so LSP's 8× tick reduction is transformative there and
nearly irrelevant here (ANALYSIS §9.1–9.2).

## 2. What v1.49b already does

More than its reputation suggests, and worth knowing before changing anything:

- **Runtime-constructed unrolled mixers.** v1.45 unrolled at *assembly* time via
  `FOR arm2dma=1 TO dma`; v1.49b builds them at runtime from templates, which is how 63 KB
  became 26 KB. The templates are `a2_*_unroll` in `src/shared/qtm_dma.asm`.
- **Separate ARM2 and ARM3 paths**, with ARM3 cache detection via `MRC CP15`.
- **A full-volume path** that drops the clamp: 6 clocks/byte instead of 8.
- **`a2_clearing`** for silent channels, and `chanendflags` to skip finished ones.
- Log-domain volume subtract with an even-only table; precomputed period→increment tables;
  Amiga→Arc pitch conversion done once at note-set time.

The steady-state ARM2 templates, as they now read in the port:

```arm
a2_anyvol_loop:                    a2_fullvol_loop:
    LDRB  R6,[R0,R1,ASR #12]  ; 3      LDRB  R6,[R0,R1,ASR #12]  ; 3
    SUBS  R6,R6,R3            ; 1      STRB  R6,[R12],R11        ; 2
    MOVMI R6,#0               ; 1      ADD   R1,R1,R2            ; 1
    STRB  R6,[R12],R11        ; 2                                ; = 6
    ADD   R1,R1,R2            ; 1
                              ; = 8
```

For the straightforward algorithm this is close to optimal. `LSP_ARM250`'s mixer costs
~33 clocks per 4-channel frame against QTM's ~32.

## 3. The four ideas, ranked

All need prototyping and measurement.

### 3.1 Exploit increment < 1 — the largest opportunity

MOD samples are typically 8–16 kHz source material played at 20.8 kHz, so the resampling
increment is usually below 1.0 and **the same source byte is fetched and re-scaled 2–3
times consecutively**. A DDA / conditional-load restructure fetches only when the index
genuinely advances:

```arm
    ADDS   R1,R1,R2        ; 1   accumulate; C set when the integer part advances
    LDRCSB R6,[R0],#1      ; 3 when taken, 1 when skipped
    ...clamp...
    STRB   R6,[R12],R11    ; 2
```

The fiddly part is flag interaction: `SUBS` must not clobber the accumulate's carry, and
`MOVMI` must not act on stale flags when the load is skipped. Solvable with a second
register holding the last scaled value, at the cost of some of the saving.

**The existing code is direct evidence this concern is real.** `a2_endanyvol_unroll`
already juggles exactly this, for a different purpose — using `ADDS` flags to fold the
end-of-sample test into the load:

```arm
    ADDS   R1,R1,R2        ; CS if -ve cleared, VS if +ve gets too large
    LDRLTB R6,[R0,R1,ASR #12]
    MOVGE  R6,#0           ; v1.48: optimised to avoid BGE a2_clearend
```

So the flag budget in the ending path is already spoken for. A DDA restructure likely has
to come *after* §4 removes the need for that test.

### 3.2 Lane-packed output with persistent pre-shifted lanes

Hold each channel's scaled byte *already shifted into its output lane*, `ORR` four
together, one `STR` per frame: 4 clocks for 4 bytes versus 8 for four `STRB`s. Combined
with §3.1, a lane is only recomputed when that channel's index advances.

This is **not** what `LSP_ARM250` does — it recomputes every lane every frame and therefore
breaks even. The saving only materialises if lane values persist across frames.

Register pressure is the blocker: 4 lanes + 4 accumulators + 4 increments + 4 base
pointers + volumes + destination exceeds the register file. Needs volume packing (as LSP
does) and probably FIQ-mode banked registers.

### 3.3 Word fetch with shift extraction

At small increments one `LDR` covers 4 source bytes, usable for ~10 output bytes;
extraction via `AND`/`LSR` costs 2 clocks against 3 for `LDRB`.

### 3.4 Screen mode / video bandwidth

On ARM2 this may dominate every code-level tweak. MEMC gives video DMA priority, so the
mixer's wall-clock cost is substantially worse in a 256-colour mode than at 2 bpp. If the
objective is "more CPU left for the demo", the bandwidth budget is a bigger lever than the
inner loop.

## 4. The enabler: LSP's `ecart` guard gap

The one LSP idea that *does* transfer, and it is a precondition rather than a win in
itself.

Pre-pad every sample offline with a gap pre-filled with its own loop data. The mixer can
then overrun the nominal sample end freely, which means:

- no end-of-sample test anywhere in the inner loop;
- **no per-fill split** — QTM currently dispatches through `a2_chanctrl` to
  `a2_endanyvol` / `a2_repanyvol` / `a2_clearing` / `a2_not_ending` and splits each fill
  around the sample boundary. With a guard gap, every fill becomes one straight unrolled
  block plus a single cheap modulo fixup per channel per fill.

On its own that is a per-fill saving, not a per-byte one. Its real value is that a
branch-free inner loop is what makes §3.1 and §3.2 tractable at all — and, as §3.1 notes,
what frees the flags they need.

So the productive hybrid is **not** "LSP frontend + QTM backend". It is QTM kept whole,
plus an offline sample-preparation pass borrowed from LSP — log conversion, guard-gap
padding, loop pre-copy — which then unlocks a restructured inner loop.

## 5. Measure first

The numbers in §1 are derived, not measured, and nothing here should be acted on before
the real split is known.

Two things have changed since the analysis was written, both in our favour:

1. **The tokenised-source obstacle is gone.** ANALYSIS §9.6 notes that instrumenting QTM
   meant "working in a detokenised form and re-tokenising, or patching the assembled
   module". The mixer is now ordinary vasm source, and `build.py` verifies any unmodified
   build byte-for-byte against four references — so an experiment can be diffed against a
   known-good baseline rather than eyeballed.

2. **QTM has its own instrumentation already.** The `alpha` variant adds ten counters
   inside the DMA fill path (`dma_calls`, `dma_efv`, `dma_eav`, `dma_rnv`, `dma_rfv`,
   `dma_rav`, `dma_clc`, `dma_fv`, `dma_an`, `dma_ce`) plus a `swi_qtmdebug` to read them.
   That gives the *distribution across mixer paths* — how often the full-volume path is
   taken, how often channels are ending or repeating — which is exactly what decides
   whether §3.1 and §4 are worth doing. It costs 200 bytes and is already byte-identical
   to its reference, so it is a trustworthy measurement build.

   `python build.py alpha` produces it.

For wall-clock, the approach from ANALYSIS §9.6 still applies: border-colour markers around
`a2_DMAsound` and `CIAhandler`, run under Arculator configured as an 8 MHz ARM2. The
equivalent markers already exist in `LSP_ARM250` around `LSP_Player_standard` and
`Paula_remplissage_DMA_416`, so the two are directly comparable.

## 6. Order of work

1. Measure with the `alpha` build: which mixer paths dominate, and the real mixer /
   interpreter split.
2. Prototype the offline sample-prep pass (§4) — guard gap, log conversion, loop pre-copy.
   Verify the unmodified module still builds byte-identical, so the change is isolated to
   the data.
3. With the end-of-sample test gone, attempt §3.1.
4. Only then consider §3.2, which needs FIQ banked registers and is the most invasive.
5. Keep §3.4 in view throughout: it may be larger than 1–3 combined, and costs no code.
