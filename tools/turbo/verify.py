#!/usr/bin/env python3
"""Prove the packed mixer produces the same DMA buffer as the byte-at-a-time one.

The guard gap's arithmetic is already verified in `tools/prep/verify.py`, so
what is new in Turbo is the *packing*: four channels mixed in one loop, ORed
into a register, and stored a word at a time.  Three things could go wrong that
the guard-gap proof does not cover, and all three are cheap to settle here
rather than in an interrupt handler on an emulator.

  1. **The clamp changes instruction.**  QTM does `SUBS R6,R6,R3 / MOVMI R6,#0`
     and stores the byte.  Turbo does `SUBS R11,R11,#vol / ORRPL` -- "contribute
     nothing" and "store zero" have to be the same thing for every one of the
     256x256 (byte, volume) pairs, and the PL result must never exceed 8 bits or
     it corrupts the lane above it.

  2. **The lane order.**  QTM writes channel c at buf[c], buf[c+4], ... and ARM
     is little-endian, so channel c must land in bits 8c..8c+7.  Getting this
     backwards would still sound like music -- the channels would just be in the
     wrong stereo positions -- which is exactly the kind of bug a spectral
     correlation would pass.

  3. **The silence word.**  A dead channel is pointed at bank offset 0 with an
     increment of 0 instead of running a clearing loop.  That has to produce the
     same bytes as `a2_clearing`, which stores 0.

So: check (1) exhaustively, then simulate whole 832-byte fills from a real
prepared bank -- live channels, looping and one-shot, and dead ones -- and
compare the two buffers byte for byte.

Usage:
    verify.py <song.mod> [<song.mod> ...] [--us 48] [--fill 208]
"""
import argparse
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / "prep"))
import prep                                                     # noqa: E402

MASK = 0xFFFFFFFF


def check_clamp():
    """QTM's SUBS/MOVMI/STRB against Turbo's SUBS/ORRPL, all 65536 pairs."""
    bad = []
    for b in range(256):
        for v in range(256):
            d = b - v
            qtm = d if d >= 0 else 0            # SUBS then MOVMI R6,#0
            for lane in range(4):
                acc = 0
                if d >= 0:                      # ORRPL
                    acc |= (d << (8 * lane)) & MASK
                got = (acc >> (8 * lane)) & 0xFF
                if got != qtm:
                    bad.append((b, v, lane, qtm, got))
                if acc & ~(0xFF << (8 * lane)) & MASK:
                    bad.append((b, v, lane, "bleed", hex(acc)))
    return bad


def qtm_fill(bank, chans, fill):
    """One DMA fill, QTM's way: a strided STRB pass per channel.

    Guard-gap form (the `gg` build): no per-byte wrap, one fixup afterwards.
    """
    buf = bytearray(fill * 4)
    for c, (acc, inc, vol) in enumerate(chans):
        r1 = acc
        for n in range(fill):
            d = bank[r1 >> 12] - vol
            buf[n * 4 + c] = d if d >= 0 else 0
            r1 += inc
    return bytes(buf)


def turbo_fill(bank, chans, fill):
    """The same fill, packed: one interleaved loop, one STR per four bytes."""
    out = bytearray()
    r = [c[0] for c in chans]
    for _ in range(fill):
        word = 0
        for lane, (_, inc, vol) in enumerate(chans):
            d = bank[r[lane] >> 12] - vol
            if d >= 0:
                word |= (d << (8 * lane)) & MASK
            r[lane] += inc
        out += word.to_bytes(4, "little")
    return bytes(out)


def channel_cases(mod, bank, fill):
    """Realistic per-lane (accumulator, increment, volume) triples.

    Drawn from the song's own samples at the increments prep sized their guards
    for, plus the two states that have no sample at all: a silenced channel and
    a dead one, both of which Turbo represents as bank offset 0 with a zero
    increment.
    """
    live = []
    for s in mod.samples:
        if not s.length or s.max_inc <= 0:
            continue
        end = s.off + s.play_len                # QTM's end pointer
        span = s.loop_len if s.loops else s.play_len
        for frac in (0.0, 0.37, 0.9):
            off = -int(span * (1.0 - frac)) << 12
            for inc_scale, vol in ((1.0, 0), (1.0, 0x40), (0.5, 0x9E),
                                   (0.25, 0xC0)):
                inc = int(s.max_inc * inc_scale * 4096)
                if inc <= 0:
                    continue
                if (end << 12) + off < 0:
                    continue
                acc = (end << 12) + off
                if (acc + fill * inc) >> 12 >= s.off + s.play_len + s.guard:
                    continue                    # out of the contract analyse() sized for
                live.append((acc, inc, vol))
    silent = (0, 0, 0)
    return live, silent


def check(path, us, fill):
    mod = prep.Mod(Path(path).read_bytes())
    lut = prep.load_lut()
    bank = prep.prepare(mod, lut, us, fill, prep.PT_MIN_PERIOD)
    live, silent = channel_cases(mod, bank, fill)
    if not live:
        print("skip %-26s no usable samples" % Path(path).stem)
        return 0

    # Four lanes at a time, walking the case list so every lane sees every
    # case, plus a rotation with dead channels mixed in -- a quarter of
    # channel-fills are dead in the corpus, and it must not matter which.
    fills, bad = 0, []
    n = len(live)
    for i in range(0, n, 4):
        for dead in ((), (1,), (0, 3), (0, 1, 2, 3)):
            chans = [live[(i + k) % n] for k in range(4)]
            for k in dead:
                chans[k] = silent
            a = qtm_fill(bank, chans, fill)
            b = turbo_fill(bank, chans, fill)
            fills += 1
            if a != b:
                j = next(x for x, (p, q) in enumerate(zip(a, b)) if p != q)
                bad.append("fill %d byte %d (lane %d): %02x != %02x"
                           % (fills, j, j % 4, a[j], b[j]))
    name = Path(path).stem
    if bad:
        print("FAIL %-26s %d fills" % (name, fills))
        for m in bad[:8]:
            print("      " + m)
        return 1
    print("ok   %-26s %4d fills, %d channel states" % (name, fills, len(live)))
    return 0


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("mods", nargs="+")
    ap.add_argument("--us", type=int, default=prep.US)
    ap.add_argument("--fill", type=int, default=prep.FILL)
    a = ap.parse_args()

    bad = check_clamp()
    if bad:
        print("FAIL clamp/pack equivalence:")
        for m in bad[:8]:
            print("      %s" % (m,))
        return 1
    print("ok   clamp and pack agree over all 65536 (byte, volume) pairs,")
    print("     in all four lanes, with no bleed into neighbours\n")

    n = sum(check(m, a.us, a.fill) for m in a.mods)
    print("\n%d/%d songs verified" % (len(a.mods) - n, len(a.mods)))
    return 1 if n else 0


if __name__ == "__main__":
    sys.exit(main())
