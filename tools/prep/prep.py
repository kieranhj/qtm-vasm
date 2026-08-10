#!/usr/bin/env python3
"""Offline sample preparation for a guard-gap QTM mixer (OPTIMISATION.md step 3).

Everything here is work the runtime currently does, or would have to do, and
which can be done once on the host instead.  For demo development that is the
whole point: the more that moves offline, the simpler the code that has to run
on the Archimedes.

Three jobs:

  1. **Log conversion.**  QTM converts sample data from signed linear to VIDC
     8-bit log at load time (`convsamps` in qtm_song.asm) with a 256-byte
     lookup table.  Doing it offline deletes that pass entirely.

     The table is not QTM's: `init_databanks` builds it by calling RISC OS
     `Sound_SoundLog` 256 times with the system volume forced to 127.  So it
     belongs to the host OS, and the only honest way to have it offline is to
     capture it -- see linlog.bin, and the provenance note in README.md.
     Verified byte-identical against QTM's own output on a real load.

  2. **Guard gap.**  Pad every sample so the mixer may overrun its nominal end
     by one full DMA fill without reading anything invalid.  A looping sample
     gets its loop data pre-copied into the guard; a one-shot gets silence.
     That is what lets the inner loop drop its end-of-sample test and lets a
     fill stop being split at the loop point -- measured at 52% of all
     channel-fills in MEASUREMENTS.md, which is why this is the first change.

  3. **Guard sizing.**  The guard only has to cover one fill at the fastest
     rate *that sample is actually played at*, which is a per-sample question
     answerable offline by reading the pattern data.  A bass sample never
     played high needs almost nothing.  See `analyse()` for what is counted.

Usage:
    prep.py <song.mod> [-o out.qtmp] [--us 48] [--fill 208] [--report]
    prep.py <song.mod> --verify        model-check the guard gap (see verify.py)
"""
import argparse
import struct
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent

PAL_CLOCK = 7093789.2      # Amiga PAL sample clock
FILL = 208                 # samples per channel per DMA fill (QTM's `dma`)
US = 48                    # microseconds per channel sample
PT_MIN_PERIOD = 113        # ProTracker's clamp; the floor a slide can reach

MAGIC = b"QTMP"
VERSION = 1


def load_lut():
    p = HERE / "linlog.bin"
    lut = p.read_bytes()
    if len(lut) != 256:
        raise SystemExit("%s: expected 256 bytes, got %d" % (p, len(lut)))
    return lut


class Sample:
    __slots__ = ("index", "name", "length", "finetune", "volume",
                 "loop_start", "loop_len", "data", "guard", "max_inc", "why",
                 "off")

    @property
    def loops(self):
        # ProTracker: a repeat length of 2 bytes (1 word) or less means no loop.
        return self.loop_len > 2

    @property
    def play_len(self):
        """How much of the sample is ever played.

        QTM decides this at note-on (qtm_play.asm):

            CMP   R3,#2
            ADDGT R1,R3,R2      ; repeating -> length = rep_off + rep_len
            ADD   R0,R0,R1      ; end address

        so a looping sample ends at its loop end and anything past that is
        dead weight.  Truncating there is not just a saving: it is what puts
        the loop immediately before the end pointer, which is where the
        steady-state loop's negative offset needs valid data.
        """
        if self.loops:
            return min(self.loop_start + self.loop_len, self.length)
        return self.length

    @property
    def total(self):
        return self.play_len + self.guard


class Mod:
    def __init__(self, raw):
        self.raw = raw
        if len(raw) < 1084:
            raise SystemExit("too short to be a MOD")
        self.tag = raw[1080:1084]
        self.channels = {b"M.K.": 4, b"M!K!": 4, b"FLT4": 4,
                         b"4CHN": 4, b"6CHN": 6, b"8CHN": 8}.get(self.tag)
        if self.channels is None:
            raise SystemExit("unsupported format %r -- 31-instrument "
                             "4/6/8-channel only" % self.tag)
        self.title = raw[:20].split(b"\0")[0].decode("latin-1")
        self.samples = []
        for i in range(31):
            h = raw[20 + i * 30: 50 + i * 30]
            s = Sample()
            s.index = i + 1
            s.name = h[:22].split(b"\0")[0].decode("latin-1").strip()
            s.length = struct.unpack(">H", h[22:24])[0] * 2
            s.finetune = h[24] & 0x0F
            s.volume = h[25]
            s.loop_start = struct.unpack(">H", h[26:28])[0] * 2
            s.loop_len = struct.unpack(">H", h[28:30])[0] * 2
            s.guard = 0
            s.max_inc = 0.0
            s.why = ""
            self.samples.append(s)
        self.songlength = raw[950]
        self.sequence = list(raw[952:1080])
        self.npatterns = max(self.sequence) + 1
        self.pattern_bytes = self.npatterns * 64 * self.channels * 4
        self.sample_start = 1084 + self.pattern_bytes
        off = self.sample_start
        for s in self.samples:
            s.data = raw[off:off + s.length]
            if len(s.data) < s.length:          # truncated file; pad with silence
                s.data = s.data + b"\0" * (s.length - len(s.data))
            off += s.length
        self.trailing = off

    def notes(self):
        """Yield (sample, period, effect, param) for every note in every pattern."""
        base = 1084
        per_row = self.channels * 4
        for p in range(self.npatterns):
            for r in range(64):
                o = base + p * 64 * per_row + r * per_row
                for c in range(self.channels):
                    b0, b1, b2, b3 = self.raw[o + c * 4: o + c * 4 + 4]
                    period = ((b0 & 0x0F) << 8) | b1
                    smp = (b0 & 0xF0) | (b2 >> 4)
                    yield smp, period, b2 & 0x0F, b3


def increment(period, us):
    """Resampling increment: source bytes consumed per output sample."""
    if period <= 0:
        return 0.0
    return (PAL_CLOCK / (2.0 * period)) / (1e6 / us)


def analyse(mod, us, fill, floor_period):
    """Per-sample worst-case increment, from what the song actually plays.

    Three things can raise a sample's pitch above the periods written in the
    pattern data, and all three have to be counted or the guard is too small:

      * arpeggio (effect 0xy) transposes up by max(x,y) semitones for part of
        the row, and those periods never appear in the data;
      * portamento up (1xx) and tone portamento (3xx) slide the period down
        continuously, bounded only by the player's clamp;
      * a sample can be played by a note whose own period is lower than any
        note that names it, via a portamento that keeps the previous sample.

    The last is why `floor_period` applies to any sample touched by a slide.
    """
    cur = [0] * (mod.channels)          # sample currently sounding per channel
    per_row = mod.channels * 4
    base = 1084
    slid = set()
    seen = {}
    for p in range(mod.npatterns):
        for r in range(64):
            o = base + p * 64 * per_row + r * per_row
            for c in range(mod.channels):
                b0, b1, b2, b3 = mod.raw[o + c * 4: o + c * 4 + 4]
                period = ((b0 & 0x0F) << 8) | b1
                smp = (b0 & 0xF0) | (b2 >> 4)
                eff, par = b2 & 0x0F, b3
                if smp:
                    cur[c] = smp
                s = cur[c]
                if not s or s > 31:
                    continue
                if period:
                    inc = increment(period, us)
                    if inc > seen.get(s, 0.0):
                        seen[s] = inc
                if eff == 0x0 and par:      # arpeggio
                    semis = max(par >> 4, par & 0x0F)
                    if period:
                        inc = increment(period, us) * (2.0 ** (semis / 12.0))
                        if inc > seen.get(s, 0.0):
                            seen[s] = inc
                if eff in (0x1, 0x3):       # slides that can reach the clamp
                    slid.add(s)
    for s in mod.samples:
        inc = seen.get(s.index, 0.0)
        why = "unused" if inc == 0.0 else "pattern data"
        if s.index in slid:
            fl = increment(floor_period, us)
            if fl > inc:
                inc, why = fl, "portamento floor (period %d)" % floor_period
            else:
                why = "pattern data (slide present, below floor)"
        s.max_inc = inc
        s.why = why
        # One fill of overrun from the worst legal starting offset, +1 for the
        # partial step the fixed-point index can be carrying.
        s.guard = 0 if s.length == 0 else int(fill * inc) + 2


def build_guard(s, body):
    """Guard region, built from the already-converted, truncated body.

    A one-shot gets silence -- 0x00 in log format, which is lut[0] and what
    `a2_clearing` stores, so an overrun sounds exactly like the current
    `MOVGE R6,#0` in a2_endanyvol_loop.

    A looping sample gets the loop, repeated.  Because the body has been
    truncated at the loop end, the bytes immediately *before* the end pointer
    are already the loop, and these are the bytes immediately after it -- so
    the negative-offset read is correct on both sides without a per-byte wrap.
    """
    if s.guard == 0:
        return b""
    if not s.loops:
        return b"\0" * s.guard
    lo, hi = s.loop_start, s.play_len
    if hi <= lo:
        return b"\0" * s.guard          # malformed loop; treat as one-shot
    out = bytearray()
    i = lo
    while len(out) < s.guard:
        out.append(body[i])
        i += 1
        if i >= hi:
            i = lo
    return bytes(out)


def prepare(mod, lut, us, fill, floor_period):
    analyse(mod, us, fill, floor_period)
    # Bank offset 0 is a silence word, and it is what lets the packed mixer
    # drop its dispatch entirely.  A dead or silenced channel is pointed here
    # with an increment of 0: the pointer never moves, every read returns
    # 0x00, and `SUBS 0,0 / ORRPL` contributes nothing to its lane.  So there
    # is no separate clearing path and no per-channel state to branch on --
    # which matters because a quarter of channel-fills are dead channels
    # (MEASUREMENTS.md Result 3) and one interleaved loop cannot branch four
    # ways.  Being a fixed point, it needs no guard.
    bank = bytearray(b"\0" * 4)
    for s in mod.samples:
        s.off = len(bank)
        body = bytes(lut[b] for b in s.data[:s.play_len])
        bank += body + build_guard(s, body)
        while len(bank) % 4:
            bank.append(0)
    return bytes(bank)


def write_out(path, mod, bank, us, fill):
    recs = bytearray()
    for s in mod.samples:
        # play_len is the end pointer QTM derives at note-on, so the end
        # address is simply off+play_len -- no separate loop base needed.
        recs += struct.pack("<5I", s.off, s.play_len,
                            s.loop_start if s.loops else 0xFFFFFFFF,
                            s.loop_len if s.loops else 0,
                            s.guard)
    song = mod.raw[:1084 + mod.pattern_bytes]
    hdr = struct.pack("<4s6I", MAGIC, VERSION, fill, us, 31, len(song), len(bank))
    hdr += b"\0" * (64 - len(hdr))
    path.write_bytes(hdr + bytes(recs) + song + bank)
    return len(hdr) + len(recs) + len(song) + len(bank)


def report(mod, bank, us, fill):
    print("%s  [%s, %d channels, %d patterns]"
          % (mod.title or "(untitled)", mod.tag.decode("latin-1"),
             mod.channels, mod.npatterns))
    print("  %d uS/channel, fill %d samples\n" % (us, fill))
    print("  %-3s %-22s %7s %7s %7s %7s  %s"
          % ("#", "name", "length", "loop", "maxinc", "guard", "sized by"))
    body = guard = 0
    for s in mod.samples:
        if not s.length:
            continue
        body += s.length
        guard += s.guard
        print("  %-3d %-22s %7d %7s %7.3f %7d  %s"
              % (s.index, s.name[:22], s.length,
                 ("%d+%d" % (s.loop_start, s.loop_len)) if s.loops else "-",
                 s.max_inc, s.guard, s.why))
    print("\n  sample bytes %d -> bank %d  (+%d guard, +%.1f%%)"
          % (body, len(bank), guard, 100.0 * guard / body if body else 0))


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("mod")
    ap.add_argument("-o", "--out")
    ap.add_argument("--us", type=int, default=US)
    ap.add_argument("--fill", type=int, default=FILL)
    ap.add_argument("--min-period", type=int, default=PT_MIN_PERIOD,
                    help="period floor a portamento can reach (default %d)"
                         % PT_MIN_PERIOD)
    ap.add_argument("--report", action="store_true")
    a = ap.parse_args()

    mod = Mod(Path(a.mod).read_bytes())
    lut = load_lut()
    bank = prepare(mod, lut, a.us, a.fill, a.min_period)
    if a.report:
        report(mod, bank, a.us, a.fill)
    out = Path(a.out) if a.out else Path(a.mod).with_suffix(".qtmp")
    n = write_out(out, mod, bank, a.us, a.fill)
    print("wrote %s (%d bytes)" % (out, n))
    return 0


if __name__ == "__main__":
    sys.exit(main())
