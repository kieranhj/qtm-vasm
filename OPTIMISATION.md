# Where the headroom is in QTM's mixer

This carries forward the analysis in
[`LSP_ARM250/ANALYSIS.md`](../LSP_ARM250/ANALYSIS.md) §9, written while porting LSP to the
ARM250, and restates it against the code that now exists here. Everything below is
*derived from instruction counts and PRM timings, not measured* — see §5.

> **Step 1 is now done and much of this is measured.** See
> [`MEASUREMENTS.md`](MEASUREMENTS.md). The headline corrections: the mixer:interpreter
> ratio is **23:1** (§1's range holds); the same mixer costs **+40 % cycles** in a
> 256-colour mode than a 2-colour one for byte-identical work, and runs at **1.54–2.16×**
> the textbook instruction timings, so the clock-count model in §3.2.3 understates the
> memory-traffic argument badly; and **52 % of channel-fills cross a sample loop point**,
> which promotes §4 from enabler to the largest single lever. §3.1's flag-budget concern
> sits on the *ending* path, which is 0.3 % of the work.

§3.2 additionally incorporates Steve Harrison's own "QTM Turbo" idea, sent in response to
this repository; it turns out to be the same idea as the lane-packing entry already here,
and his framing of it is the better one.

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

The DDA also forces the sample pointer and the fraction into *separate* registers, since
the carry has to mean "the index advanced" — which is what makes it so expensive in the
register budget of §3.2.1, and why it lands last in §6 rather than first.

### 3.2 Lane-packed output — Steve Harrison's "QTM Turbo"

This was §3.2 here ("lane-packed output with persistent pre-shifted lanes") arrived at from
the LSP side. It is the same idea Steve has had since 1993, and his framing is the clearer
one, so it is quoted and worked through properly below.

> Instead of filling each sample into the DMA buffer with a loop LDRB..process..STRB for
> 208 bytes, then repeating that for each of four channels (4 loops x 208 bytes); your loop
> becomes LDRB each of four (or three) samples, process these bytes into a single word, then
> STR the word to the DMA buffer and you repeat this loop once (1 loop x 208 words) […]
> However to achieve the flexibility needed […] you'd need about 5 registers per active
> channel, plus a couple of scratch registers… and the ARM only has R0-R14.
> — Steve Harrison

**The buffer format already permits this.** The stores are `STRB R6,[R12],R11` where R11 is
the "DMA gap" — the interleave stride, equal to the active channel count. So channel *n*
already owns bytes *n*, *n+stride*, *n+2·stride*… and a word of the buffer is already
exactly one sample for each of four consecutive channels. Turbo is a *transpose of the fill
order*, not a change to the hardware interface. Nothing downstream of the mixer has to move.

#### 3.2.1 The register budget, worked out

Steve's "about 5 per channel" is right, and the two escapes he names are exactly the two
that the arithmetic picks out. Two addressing forms are possible, and they differ in both
cost and register count.

**Form A — bank + scaled index** (what QTM does today, minus the end test):

```arm
    LDRB   Rs,[Rbank,Racc,LSR #12]   ; 3
    SUBS   Rs,Rs,Rvol                ; 1   log-domain volume subtract
    ORRPL  Rout,Rout,Rs,LSL #n       ; 1   <- clamp folded into the pack, see below
    ADD    Racc,Racc,Rinc            ; 1
```

**Form B — DDA with post-indexed conditional load** (§3.1's form, which needs the pointer
and the fraction in separate registers so the carry means "index advanced"):

```arm
    ADDS   Rfrac,Rfrac,Rinc          ; 1
    LDRCSB Rs,[Rptr],#1              ; 3 taken, 1 skipped — pointer bump is free
    ORRPL  Rout,Rout,Rs,LSL #n       ; 1   Rs must persist per channel when skipped
```

| | per channel | shared | 4 chans | 3 chans |
|---|---|---|---|---|
| A, per-channel volume | acc, inc, vol | bank, dest, out, scratch | **16 ✗** | 13 ✓ |
| A, volume out of registers | acc, inc | bank, dest, out, scratch | **12 ✓** | 10 ✓ |
| B, volume out of registers | ptr, frac, inc, scratch | dest, out | **18 ✗** | 14 ✓ |
| B, per-channel volume | + vol | dest, out | ✗ | **17 ✗** |

Against R0–R14 = 15. This reproduces Steve's 1993 conclusion exactly, and sharpens it:
**you can have four channels, or the load-skipping DDA, or per-channel volume registers —
any two, never all three.** Note the loop must be fully unrolled: there is no register left
for a counter (QTM already unrolls its mixers at runtime, so this costs nothing new).

#### 3.2.2 Two things that make the budget less tight than it looks

**The clamp is free once you pack.** Today the any-volume path spends `SUBS` + `MOVMI R6,#0`
to clamp silence. When the destination is an `ORR` into an accumulator, "contribute nothing"
*is* zero — so `ORRPL` does the clamp and the pack in one instruction. One clock per byte
recovered, and it only exists in the packed form.

**Volume need not occupy a register at all.** Volume is constant across a fill; it changes
only at tick boundaries. QTM log volume is 0–255, which is exactly an ARM 8-bit immediate
with no rotation — so `SUBS Rs,Rs,#vol` works, and the immediate can be *patched* at tick
rate. QTM already builds its mixers by runtime code generation (`unroll_code`); this is the
same technique applied 50 times a second instead of once. That removes all four volume
registers at zero per-byte cost and zero memory cost — and it is a strictly better answer
than Steve's fallback of pre-built copies of each sample at different volumes, which costs
*N* × sample memory and quantises every volume slide and tremolo.

Per-tick codegen also dissolves the other combinatorial problem: with all channels in one
loop there are 2⁴ combinations of full-volume/any-volume/ending/silent, which is far too
many to hold as prebuilt templates. Generating the ~100 instructions of a short unrolled
body per tick costs on the order of 0.3 % of the CPU. (On ARM3 this needs a cache flush per
tick; Turbo is an ARM2 proposition anyway.)

That gets 4 channels, full volume control, and packing into **12 registers with three
spare** — better than Steve expected. What it still cannot reach is Form B's skipped load.

#### 3.2.3 What it actually saves — and where the honest uncertainty is

Per 4-byte word, including `MOV Rout,#0` and the `STR`:

| | clocks/byte | vs today |
|---|---|---|
| today, any-volume | 8 | — |
| today, full-volume | 6 | — |
| Turbo Form A, volume | 6.75 | −16 % vs any-vol, **worse than full-vol** |
| Turbo Form A, prescaled | 5.75 | −28 % / −4 % |
| Turbo Form B, prescaled (inc ≈ 0.5) | 4.75 | **−41 %** |

Two things fall out of this that are worth being blunt about:

1. **On instruction count alone, packing is nearly worthless.** It trades a 2-clock `STRB`
   for a 1-clock `ORR` plus an amortised 0.75, saving 0.25 clocks/byte. Almost all of the
   −41 % in the last row comes from §3.1's *skipped load*, not from the packing. Turbo and
   §3.1 are not independent wins to be added up — §3.1 is the win, and packing is mostly a
   way of paying for it.

2. **But instruction count is probably the wrong metric here.** Four `STRB`s put four write
   cycles on the bus; one `STR` puts one. That is a **4× reduction in write traffic to the
   DMA buffer**, plus one sequential pass over it instead of four strided passes that defeat
   MEMC page mode. On a machine where video DMA has priority over the CPU, bus traffic can
   cost far more than the CPU clock count implies — and this is very likely where Steve's
   "somewhere around 1/2" comes from, since it is exactly what a clock-count analysis fails
   to see.

   This also merges Turbo with §3.4: in a high-bandwidth screen mode they are the same
   argument. It is the single strongest reason to measure rather than model.

#### 3.2.4 The guard gap stops being optional

§4 is listed below as an *enabler*. For Turbo it is a hard **prerequisite**, for a
structural reason: today each channel is filled in its own pass, so `a2_chanctrl` can split
that pass at that channel's sample end and dispatch to `a2_endanyvol` / `a2_repanyvol` /
`a2_clearing`. One interleaved loop has four independent sample boundaries in it and cannot
be split four ways. Either every channel is guaranteed not to end mid-fill, or Turbo does
not work at all.

The guard must cover one fill at the maximum increment — 208 × ~4.0 ≈ 832 bytes per sample,
under 26 KB for a full 31-sample MOD. Looping samples get their loop data pre-copied into
the guard; one-shot samples get silence.

This also frees the addressing. QTM indexes `[R0,R1,ASR #12]` with R0 = sample *end* and R1
a negative offset precisely so the sign bit is the end test. With no end test, `LSR` becomes
usable and offsets can be positive from a shared bank base — which is what makes Form A's
single shared `Rbank` register legal in the table above.

#### 3.2.5 The framing that makes it worth doing

At 4-channel Form A prescaled, the mixer costs ~479 k clocks/sec against ~667 k today. That
is *less than three channels cost today* (~500 k). So the pitch is not "the mixer gets 28 %
cheaper" — it is:

> **QTM Turbo buys you the fourth channel for free.**

And if the bandwidth argument in §3.2.3 holds up, it buys more than that.

One correction to what this section said before: it claimed FIQ banked registers could
relieve the pressure. They cannot. FIQ banks R8–R14, it does not add to the fifteen visible
at once. Its only benefit here is letting per-channel state persist between fills without
save/restore, which is a per-fill saving, not a per-byte one.

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
itself. §3.2.4 upgrades it from "enabler" to hard prerequisite for Turbo.

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

Turbo (§3.2) is the target. The order below is forced by §3.2.4 — the guard gap has to
exist before a packed loop can be written at all — and by §3.2.3, which says the decisive
question is a bandwidth question that only measurement can answer.

1. ~~**Measure the baseline.**~~ **Done** — [`MEASUREMENTS.md`](MEASUREMENTS.md). Cycle-exact
   range profiling under Arculator, not border markers, because the runtime-generated
   mixers are spread over thousands of addresses that a "hottest instruction" view cannot
   sum.
2. ~~**Settle the bandwidth question cheaply.**~~ **Superseded by step 1.** The throwaway
   `STRB`-vs-`STR` loop is unnecessary: the mode comparison already answers it on the real
   mixer, with byte-identical work in both modes, which is stronger evidence than a
   synthetic loop would have been.
3. **Offline sample-prep pass** (§4) — now the largest known lever, not just an enabler:
   guard gap sized for one fill at maximum increment,
   loop data pre-copied, silence for one-shots. Purely a data change — the unmodified
   module must still build byte-identical, which `build.py` verifies.
4. **Remove the end-of-sample split** using the guard gap: `a2_chanctrl` collapses, the
   per-fill split disappears, addressing moves to bank + positive `LSR` offset. Still
   4 separate strided passes. Measurable on its own, and a prerequisite for everything after.
5. **Turbo Form A** (§3.2.1): one interleaved pass, `ORRPL` clamp fold, volume as a
   tick-patched immediate. This is the milestone — 4 channels, full volume, 12 registers.
6. **Per-tick codegen** of the specialised loop body, if step 5 shows the template
   combinations are a problem in practice rather than in theory.
7. **Turbo Form B** (§3.1 + §3.2): the skipped load. Needs 3 channels, or a cleverer answer
   to the persistent-scratch problem. Most of the theoretical win lives here.
8. Keep §3.4 in view throughout: it may be larger than everything above, and costs no code.

Steps 1–2 were the decision, and they came out in Turbo's favour. Steps 3–4 are worth
doing regardless, because they simplify the mixer, are independently measurable, and — on
the step 1 numbers — carry more of the win than the inner-loop work does.
