# Offline sample preparation

Step 3 of [`../../OPTIMISATION.md`](../../OPTIMISATION.md) §6. Moves work off the
Archimedes and into the build, so the runtime mixer can get simpler rather than larger.

    prep.py   <song.mod> [-o out.qtmp] [--us 48] [--report]
    verify.py <song.mod> ...        model-check the guard gap against QTM's real arithmetic

## What it does

**Log conversion.** QTM converts samples from signed linear to VIDC 8-bit log at load
time (`convsamps`), a straight 256-byte table lookup. Done offline, that pass disappears.

**Guard gap.** Each sample is padded so the mixer may overrun by a whole fill without
reading anything invalid — the loop, pre-copied, for a looping sample; silence for a
one-shot. That is what lets the inner loop drop `SUBGE R1,R1,R5,LSL #12`, and more
importantly frees the per-channel repeat-length register that Turbo needs.

**Guard sizing.** Sized per sample from the fastest rate that sample is actually played
at, read out of the pattern data — a bass sample never played high needs almost nothing.
Arpeggio (`0xy`) is counted at `max(x,y)` semitones because those periods never appear in
the data; any sample touched by portamento (`1xx`/`3xx`) falls back to a period floor,
`--min-period`, default ProTracker's 113.

## Layout

A looping sample is laid out as `[body][loop][guard]`, and the manifest's `loop_base`
points at the end of that extra loop copy. The extra copy is not waste: QTM's steady-state
loop indexes *backwards* from the repeat end with a negative offset, so it needs valid data
on both sides of that point — one copy behind it, the guard in front.

## Provenance of `linlog.bin`

**This table is RISC OS's, not QTM's.** `init_databanks` builds it by calling
`Sound_SoundLog` 256 times with the system volume forced to 127. There is no algorithm to
port, so the table is captured rather than derived — dumped from a real load under
Arculator (A3000, RISC OS 3.11) and verified byte-identical against QTM's own converted
output for a whole song.

The practical consequence: it is correct for this RISC OS, and a build targeting a machine
whose `Sound_SoundLog` differs would need a recapture. For demo work against a known
target that is fine, but it is the one thing here that is not self-contained.

Positive inputs map to even values and negatives to odd — VIDC carries the sign in bit 0,
which is also why QTM's volume table does `AND R0,R0,#0xFE`: the volume subtract must
never carry into the sign.

## Verification

`verify.py` models both mixers in Python using QTM's exact fixed-point arithmetic (emit
from the offset *before* the increment; wrap after) and asserts the guard version is
byte-identical to the current one, for every looping sample, at every increment the guard
was sized for, swept across starting phases. It also asserts one-shot guards are silent,
and that no read leaves the trailing region.

    17/17 songs verified

Increments beyond a sample's sized maximum are deliberately *not* swept — that is out of
contract by construction, and is checked as a bounds property instead.
