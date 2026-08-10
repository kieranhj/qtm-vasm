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

Against R0–R14 = 15 — but **14 in practice**, which is a correction to what this section
said before. R13 is the stack pointer and every unrolled routine ends
`LDMFD R13!,{R4-R6,R12,PC}^`, so it has to survive the loop. It *can* be freed by parking
it in workspace for the duration (~4 instructions per fill, affordable against 208 bytes),
but that has to be a deliberate choice rather than an accounting assumption. Every row
below is one register tighter than it looks.

This is what makes the shared bank base decisive rather than merely tidy: collapsing four
per-channel base registers into one is the difference between not fitting and fitting with
room to spare. The prepared bank from `tools/prep` already lays every sample out
contiguously, so the base exists — what it costs is bank-relative offsets, which are
computed at note-on in `qtm_play.asm`, so Turbo cannot be confined to `qtm_dma.asm`.

This reproduces Steve's 1993 conclusion exactly, and sharpens it:
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

> **Now measured.** `tools/bench/bench.asm` on an 8 MHz ARM2 gives Form A at **−25.2 %**
> against the any-volume path, against the −15.6 % this section's clock-count model
> predicts and the −25 % the access-count model predicts. It also beats the *full-volume*
> path by 7.2 %, which falsifies the warning below that Form A would be slower there. See
> [`MEASUREMENTS.md`](MEASUREMENTS.md) step 5. The reasoning below is kept because the two
> models disagreeing is the point; the access-based one won.

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

§4 is listed below as an *enabler*. For Turbo it is a hard **prerequisite**, for a register
reason rather than the structural one claimed here previously.

QTM handles looping inline: `a2_repanyvol_loop` wraps with
`SUBGE R1,R1,R5,LSL #12` every byte. Turbo could do the same — but per channel, which
costs both an extra instruction *and* an extra live register (the repeat length) for each
of the four channels. Four more registers is fatal to a budget that has at most three
spare. So either the samples are pre-padded so no wrap is needed inside the fill, or Turbo
does not fit.

The dispatch is a second, weaker reason: with four channels in one loop, per-channel
routine selection means 2⁴ combinations, which is what §3.2.2's per-tick codegen exists to
solve.

The guard must cover one fill at the maximum increment — 208 × ~4.0 ≈ 832 bytes per sample,
under 26 KB for a full 31-sample MOD. Looping samples get their loop data pre-copied into
the guard; one-shot samples get silence.

This also frees the addressing. QTM indexes `[R0,R1,ASR #12]` with R0 = sample *end* and R1
a negative offset precisely so the sign bit is the end test. With no end test, `LSR` becomes
usable and offsets can be positive from a shared bank base — which is what makes Form A's
single shared `Rbank` register legal in the table above.

#### 3.2.4a Implementation spec — built, and it loses

> **Built and measured.** `python build.py turbo` produces exactly what this section
> specifies. It is byte-exact against QTM's mixer and **+49 % on `coolbeans`, +16 % on
> `changing-waves`** — a substantial regression. See
> [`MEASUREMENTS.md`](MEASUREMENTS.md) step 6. The section is kept as written because the
> error is instructive and is *not* in the inner loop, which performs as step 5 promised:
> its instructions measure 8–10 % cheaper each. The error is the silence word, in bold
> below. §3.2.4b has what to do instead.

Settled while starting the integration; recorded so the remaining work is a job rather
than an open question. Measured basis: [`MEASUREMENTS.md`](MEASUREMENTS.md) step 5.

**The loop is static, not generated.** `FILL` is 208 and the unroll factor is 26, both
fixed, so the ×26 packed body can simply be assembled into the module — about 480
instructions, ~1.9 KB. QTM's `unroll_code` machinery is not involved at all. This removes
the per-tick code generation that §3.2.2 assumed was necessary; the only runtime patching
is 104 volume immediates, and only when a channel's volume actually changes.

**The dispatch disappears via a silence word — this is the error.** `tools/prep` reserves bank offset 0 as
four zero bytes. A dead or silenced channel is pointed there with an increment of 0: the
pointer never moves, every read returns 0x00, and `SUBS 0,#0` / `ORRPL` contributes
nothing to its lane. No clearing path, no branch — which is what makes one interleaved
loop possible at all, given a quarter of channel-fills are dead channels. Being a fixed
point it needs no guard.

**`a2_chanctrl` already computes everything Turbo needs** — `R0` base, `R1` offset,
`R2` arc increment, `R3` log volume. The eight `LDR{cond} PC,jmp_a2_*` dispatch sites
(qtm_dma.asm 674, 680, 696, 703, 709, 720, 734, 740) become returns; the two silent ones
additionally set `R2` to 0. **Increment 0 is a safe "silent" signal** because `a2_chanctrl`
already rejects a zero pitch for a live channel (`CMPNE R2,#0 / BLE a2_chanend`).

**Bank-relative offsets cost two instructions per channel per fill**, not a rewrite of
note-on as §3.2.1 feared:

    SUB  Rt,R0,Rbank            ; sample end, relative to the bank
    ADD  Racc,R1,Rt,LSL #12     ; ...plus QTM's negative offset = absolute 20.12

and the inverse on writeback. The bank must be ≤ 1 MB for `LSR #12` to address it, which
every prepared bank is by a wide margin.

**The bank base lives in `rm_use_word`** (workspace 0x420), which no non-RasterMan build
references.

Remaining: the writeback path (offset back to QTM's representation, with the guard-gap
wrap fixup from step 4), and getting the bank base set at load time. Everything else above
is specified.

*(Both were done. The writeback turned out to need no new arithmetic at all: `a2_chanctrl`
already computes the post-fill offset in R6, to decide whether the sample ends, and with the
guard gap that value is correct as it stands. The bank base went in the module rather than
the workspace, addressed PC-relatively, and is published to the loader through three words
appended to `a2_jumptable`.)*

#### 3.2.4b What to do instead

The measurement says the packing is worth having and the silence word is not. Restated
plainly: **the dispatch was never a cost, it was how QTM avoids work**, and the four paths
it selects between differ by up to *everything* — a really-ended channel costs literally
nothing, and that is 39 % of `coolbeans` channel-fills. Trading a 0.6 % dispatch saving for
a 40 % work saving is a bad trade however elegantly it is done.

So §3.2.2's per-tick code generation, which §3.2.4a dropped as unnecessary, is the answer
after all. Generate the packed body from only the lanes that are live: a fill with two live
channels emits `MOV` + 2 × 4 + `STR` = 10 instructions per word instead of 18, and still
writes the buffer once per four bytes. The 2⁴ (or 3⁴ with volume classes) combinations that
§3.2.4 called "far too many to hold as prebuilt templates" are no obstacle to *generating*
one body per tick — which was the original argument.

One caution before building it. On this session's numbers that comes out at roughly **−3 %
against gg, not −25 %**: at 2.44 live lanes per fill, `coolbeans` needs about 2446
instructions per fill against gg's 2311, and only wins because Turbo's instructions measure
2.55 cycles against gg's 2.77. The packing's advantage is real but thin once QTM is allowed
to skip again, and the estimate is an estimate. Benchmark it — a variant of
`tools/bench/bench.asm` with 2 and 3 live lanes would settle it in an afternoon and before
any codegen is written.

The parts of Turbo that are keepers regardless: the guard gap (step 4), the offline sample
prep, the tick-patched volume immediates, and `ORRPL` doing the clamp and the pack in one
instruction.

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
- **no per-byte wrap.** An earlier version of this section claimed QTM splits each fill
  around the sample boundary. It does not — `a2_chanctrl` picks *one* routine for the
  whole fill, and `a2_repanyvol_loop` handles looping inline and branchlessly with
  `SUBGE R1,R1,R5,LSL #12` after the `ADDS`. So the cost of looping is one instruction
  per byte, not a split. A guard gap replaces that with a single fixup per fill.

That is a per-byte saving of 1 clock on the 52 % of channel-fills measured as repeating —
worth roughly 7 % of the mixer on its own. Its real value is that a
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
3. ~~**Offline sample-prep pass**~~ **Done** — `tools/prep`, log conversion byte-identical
   to QTM's own, per-sample guard sizing from the pattern data, 17/17 songs verified.
4. ~~**Remove the end-of-sample split** using the guard gap.~~ **Done** — `build.py gg`,
   measured at −3.6 % (≈ −6 % corpus-typical). The "split" turned out not to exist; the
   cost was one inline `SUBGE` per byte, and the model predicted the saving to 0.3 %.
5. ~~**Turbo Form A**~~ **Done, and it loses** — `build.py turbo`. Byte-exact, and **+49 %
   / +16 %** on two tunes. The inner loop performs as benchmarked; §3.2.4a's silence word
   is what costs, by giving up QTM's ability to skip dead and silent channels. See
   §3.2.4b and [`MEASUREMENTS.md`](MEASUREMENTS.md) step 6.
6. **Per-tick codegen** of the specialised loop body. No longer conditional — it is the
   only way to keep the packing *and* the skipping. **Benchmark it first**: the estimate in
   §3.2.4b is about −3 %, not −25 %, and that is thin enough to be worth an hour of
   `tools/bench` before an afternoon of code generation.
7. **Turbo Form B** (§3.1 + §3.2): the skipped load. Needs 3 channels, or a cleverer answer
   to the persistent-scratch problem. Most of the theoretical win lives here.
8. Keep §3.4 in view throughout: it may be larger than everything above, and costs no code.

Steps 1–2 were the decision, and they came out in Turbo's favour. Steps 3–4 are the ones
that survived: they simplify the mixer, are independently measurable, and — unlike step 5 —
are wins in situ as well as in the benchmark.

The through-line of steps 4–6 is one lesson learned three times: **on this machine, measure
the whole path, not the loop.** Step 4's saving was smaller than the instruction count
implied because the instruction removed was the cheapest one. Step 5's benchmark was right
about the loop and silent about the fact that the loop would now run four times as often.
Both errors are invisible from inside the inner loop and obvious from outside it.
