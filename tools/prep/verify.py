#!/usr/bin/env python3
"""Prove the guard gap changes nothing audible, before any ARM code is written.

The claim to be checked is that a mixer which runs off the end of a sample into
a prepared guard produces *byte-identical* output to QTM's current mixer, which
wraps in the inner loop.  That is cheap to check exhaustively in Python and
expensive to debug on the Archimedes, so it is checked here.

Both models use QTM's actual arithmetic, taken from a2_repanyvol_loop:

    LDRB  R6,[R4,R1,ASR #12]      ; R4 = repeat END address, R1 = -ve offset
    ...
    ADDS  R1,R1,R2
    SUBGE R1,R1,R5,LSL #12        ; wrap by repeat length, every byte

so the byte is emitted from the offset *before* the increment, and the wrap
happens after.  The guard model is identical except that it drops the SUBGE and
does one fixup at the end of the fill -- which is the entire saving being
claimed, and the reason the sample layout in prep.py looks the way it does.

Usage:
    verify.py <song.mod> [<song.mod> ...] [--us 48] [--fill 208]
"""
import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import prep                                                    # noqa: E402


def ref_loop(body, rep_off, rlen, start, inc_fx, n):
    """QTM as it is today: negative offset from the repeat end, SUBGE per byte."""
    base = rep_off + rlen
    r1 = start
    out = bytearray()
    for _ in range(n):
        out.append(body[base + (r1 >> 12)])
        r1 += inc_fx
        if r1 >= 0:
            r1 -= rlen << 12
    return bytes(out), r1


def guard_loop(bank, loop_base, rlen, start, inc_fx, n, limit):
    """With a guard gap: no per-byte wrap, one fixup per fill.

    `limit` is the last byte of this sample's trailing region; reading past it
    would mean the guard was undersized, so that is an assertion, not a wrap.
    """
    r1 = start
    out = bytearray()
    for _ in range(n):
        i = loop_base + (r1 >> 12)
        if i > limit:
            raise AssertionError("read %d past trailing region end %d" % (i, limit))
        out.append(bank[i])
        r1 += inc_fx
    while r1 >= 0:
        r1 -= rlen << 12
    return bytes(out), r1


def check(path, us, fill):
    mod = prep.Mod(Path(path).read_bytes())
    lut = prep.load_lut()
    bank = prep.prepare(mod, lut, us, fill, prep.PT_MIN_PERIOD)
    lo, checked, worst, oneshot = [], 0, 0, 0

    # One-shot samples: a2_endanyvol_loop emits silence once the offset goes
    # non-negative (ADDS / LDRLTB / MOVGE), so the guard must read as 0x00 for
    # the whole overrun.  Cheap to check, and it is the only thing the guard
    # has to do for a non-looping sample.
    for s in mod.samples:
        if not s.length or s.loops or s.max_inc <= 0:
            continue
        oneshot += 1
        end = s.off + s.play_len
        if s.guard < int(fill * s.max_inc) + 1:
            lo.append("sample %d: one-shot guard %d too small" % (s.index, s.guard))
            continue
        tail = bank[end:end + s.guard]
        if any(tail):
            lo.append("sample %d: one-shot guard is not silent at +%d"
                      % (s.index, next(i for i, v in enumerate(tail) if v)))

    for s in mod.samples:
        if not s.length or not s.loops or s.max_inc <= 0:
            continue
        body = bytes(lut[b] for b in s.data[:s.play_len])
        rlen = s.loop_len
        # The end pointer QTM derives at note-on: addr + rep_off + rep_len,
        # which after truncation is just the end of the body.
        loop_base = s.off + s.play_len

        # Only increments the guard was sized for.  Going faster than
        # analyse() promised is out of contract by construction, and is
        # checked separately below as a bounds property rather than silently
        # tested here -- an earlier version swept 0.5 and 1.0 unconditionally
        # and "failed" on samples whose guard was correctly sized smaller.
        incs = sorted({s.max_inc, s.max_inc * 0.99, s.max_inc / 2,
                       s.max_inc / 3, s.max_inc / 8})
        for inc in incs:
            if inc <= 0:
                continue
            inc_fx = int(inc * 4096)
            if inc_fx <= 0:
                continue
            # Every legal starting phase within the loop, coarsely swept.
            step = max(1, rlen // 37)
            for k in range(0, rlen, step):
                start = -(rlen << 12) + (k << 12)
                limit = s.off + s.play_len + s.guard - 1
                a, ra = ref_loop(body, s.loop_start, rlen, start, inc_fx, fill)
                try:
                    b, rb = guard_loop(bank, loop_base, rlen, start,
                                       inc_fx, fill, limit)
                except AssertionError as e:
                    lo.append("sample %d inc %.3f start %d: %s"
                              % (s.index, inc, k, e))
                    continue
                checked += 1
                if a != b:
                    i = next(j for j, (x, y) in enumerate(zip(a, b)) if x != y)
                    lo.append("sample %d inc %.3f start %d: byte %d %02x!=%02x"
                              % (s.index, inc, k, i, a[i], b[i]))
                elif ra != rb:
                    lo.append("sample %d inc %.3f start %d: offset %d != %d"
                              % (s.index, inc, k, ra, rb))
                # How far into the trailing region did we actually read?
                reach = (start + fill * inc_fx) >> 12
                worst = max(worst, reach)

        # The guard must cover the worst overrun, with the loop copy in front.
        need = int(fill * s.max_inc) + 1
        if s.guard < need:
            lo.append("sample %d: guard %d < needed %d" % (s.index, s.guard, need))
        if loop_base + need > s.off + s.play_len + s.guard:
            lo.append("sample %d: overrun leaves the bank" % s.index)

    name = Path(path).stem
    if lo:
        print("FAIL %-26s %d cases" % (name, checked))
        for m in lo[:8]:
            print("      " + m)
        return 1
    print("ok   %-26s %5d loop fills, %2d one-shot samples, deepest overrun %d"
          % (name, checked, oneshot, worst))
    return 0


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("mods", nargs="+")
    ap.add_argument("--us", type=int, default=prep.US)
    ap.add_argument("--fill", type=int, default=prep.FILL)
    a = ap.parse_args()
    bad = sum(check(m, a.us, a.fill) for m in a.mods)
    print("\n%d/%d songs verified" % (len(a.mods) - bad, len(a.mods)))
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
