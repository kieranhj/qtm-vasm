# Measurement harnesses

Guest-side helpers for the optimisation work, driven from the Arculator MCP server.
Results and method: [`../../MEASUREMENTS.md`](../../MEASUREMENTS.md).

| file | what |
|---|---|
| `setup.bas` | load a song, start it, print the module base / workspace / jump table |
| `paths.bas` | play N tunes for 5 s each, write the `dma_*` path counters to `res` |
| `turbo.bas` | load the `turbo` build with a prepared sample bank, poke `turbo_bank`, start |
| `step1-paths.csv` | raw output of `paths.bas`, step 1 |

All are plain text with CR line endings, to be `*Exec`'d into BASIC — copy into the
machine's HostFS sandbox with a `,fff` (Text) suffix, then `*Exec HostFS::HostFS.$.<name>`
followed by `RUN`.

## Gotchas

**Do not type `"` through `type_text`.** The UK keyboard mapping emits `@`, so
`SYS "QTM_Stop"` silently becomes `SYS @QTM_Stop@` and fails with *Unknown or missing
variable*. Anything quoted must come from a file; for typed commands use numeric SWI
numbers instead:

    QTM_Load &47E40   QTM_Start &47E41   QTM_Stop  &47E42
    QTM_Clear &47E44  QTM_Pos   &47E46   QTM_SetSampleSpeed &47E49
    QTM_Debug &47E63  (alpha build only)

**Find the module at runtime.** `OS_Module 18` does not match on "QTM". Instead call
`SYS &47E63 TO J%` — the alpha debug SWI returns `a2_jumptable` — and subtract its listing
offset: `base = J% - &64D8`. The eight words at `J%` are the addresses of the runtime-
unrolled mixer routines, which is where the mixer's cycles actually are.

**Restart deterministically** with `SYS &47E42:SYS &47E46,0,0:SYS &47E41` before every
measurement window, or successive windows measure different parts of the song.

**MODE 15 needs more screen memory** than the default: `SYS &2A,2,&30000` first
(`OS_ChangeDynamicArea` on area 2), otherwise RISC OS silently keeps the current mode.

## More gotchas found in step 4

**The module is registered as `QTMTracker`, not `QTM`.** `*RMKill QTM` and
`OS_Module 18,"QTM"` both fail with *Module QTM not found*. Use `*RMKill QTMTracker`.

**`~` does not survive `type_text` either**, so `PRINT ~J%` prints decimal. Anything that
needs hex output should go through a file, as `h11` does — hand-converting the decimal is
how one measurement got pointed at the wrong address.

**Addresses move on every `RMKill`/`RMLoad`.** The runtime-unrolled mixer is in claimed RMA
blocks, and after a few reloads they end up scattered *below* the module rather than above
it. Never reuse an address between runs: read the jump table via `swi_qtmdebug` each time
and derive the profile range from it.

## Comparing audio between two builds

Captures are 48 kHz, resampled from QTM's 83,333 Hz, and two runs start a few milliseconds
apart. A fractional-sample offset therefore makes nearly every sample differ while the
signal is identical — a sample-wise diff will report ~98% "different" and mean nothing.

Use measures insensitive to sub-sample phase:

- **magnitude spectrum correlation** — also insensitive to time shift, so no alignment step
  is needed. This is the one to quote.
- **short-window RMS envelope** — only valid *after* aligning by cross-correlation.

And always run a **negative control**. Correlation against a reference shows two builds are
playing the same music; it does not show that the change under test did anything. Re-run
the modified build with the change's precondition removed (here: unprepared samples) and
confirm the number collapses — 0.999 vs 0.789 is what tells you the patch is live.

For an exact comparison, use the DMA buffer rather than audio: break on `a2_DMAsound`, and
at each break the buffer filled by the previous call is complete (832 bytes for 4 channels,
alternating between two addresses, de-interleaving as `buf[ch::4]`). Match captures on
QTM's position fields — do not assume two module loads start at the same point.

## More gotchas found in step 6

**Do not compare two builds' DMA buffers against each other if you can avoid it.** The
tick (`CIAhandler`) and the DMA fill run off *independent* timers, so a tick boundary can
fall anywhere within a fill and two correct runs need not agree on where. Compare each
build's buffer against a model driven by that build's *own* parameters instead: break at
the end of the fill, read the mixer's inputs and its output together, and reproduce the 832
bytes in Python. No alignment problem, and a stronger result.

**Read the buffer address from a register, never guess which of the two it is.** The two
buffers alternate; picking the wrong one produces a diff that looks exactly like a real bug
(and did, for one confusing minute). At the end of `turbo_fill` the output pointer is in R9,
so the buffer is `R9 - 832`; in stock builds the word at `song_data + &BC` holds the buffer
being filled.

**Derive addresses from the jump table, not from listing offsets.** `turbo` appends three
words to `a2_jumptable` giving `turbo_bank`, `turbo_loop` and `turbo_end` as offsets
*relative to the jump table itself*, so `J% + !(J%+36)` is the bank pointer with no
constants involved. The alpha/gg harnesses still need `J% - &64D8` and `J% - &64F4`
respectively — those differ per build and are exactly the kind of constant that sent a
step-1 measurement 2 KB wide.

**Profile the whole path, not the mixer.** Step 4's "mixer" figure turns out to have covered
`a2_DMAsound` and `a2_chanctrl` as well; step 6's separate module and RMA ranges reproduce it
to within 1 % only when summed. Fix the range definition before comparing across sessions,
and prefer the whole-path number anyway — it is the one that caught Turbo's regression.
