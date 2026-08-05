#!/usr/bin/env python3
"""Parse the golden listing from the original BASIC build (Phase 0a artefact).

ref/listing.txt is a *Spool of the build with OPT bit 0 set on both passes, so
each line is

    AAAAAAAA WWWWWWWW   <source text>

with the address, the assembled value, and the source.  Two useful properties:

  * The width of the value field gives the byte count -- "81" is one byte,
    "7962" two, "E0810380" four -- and the value is little-endian.  EQUS longer
    than four bytes lists no value at all, so long strings are the one thing
    that cannot be recovered here.

  * Both passes are listed.  Pass 1 resolves not-yet-defined labels to P%, so
    its values are wrong on forward references (EQUD initqtm lists as 00000004
    at address 4, against 00000194 in pass 2).  Later lines win, which yields
    pass 2 without having to find the boundary.

There is one listing per build variant, each captured alongside its own
reference binary; --variant selects which.

Usage:
    listing.py check              reconstruct and compare against the reference
    listing.py labels             print every label and its address
    listing.py swis               write src/shared/swis.h.asm (union of all
                                  variants, so one header serves every build)
    listing.py at ADDR            show the listing lines around an address

All except "swis" take --variant NAME; "swis" reads every variant by design.
"""
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import variants

ROOT = Path(__file__).resolve().parent.parent
LISTING = variants.listing_path(variants.DEFAULT)
REF = variants.module_path(variants.DEFAULT)


CURRENT = variants.DEFAULT


def use(name):
    """Point this module at one variant's listing and reference binary."""
    global LISTING, REF, CURRENT
    CURRENT = name
    LISTING = variants.listing_path(name)
    REF = variants.module_path(name)

# Post-assembly fills, which by definition cannot appear in the listing:
# PROCinit_amiperiods assembles with opt%=12 (listing off) and LOGdata is
# *Load-ed over loglintab.  Offsets are label values read from the listing.
POST_FILL = [("amigaperiodz", 2304), ("loglintab", 256)]

LINE = re.compile(r"^([0-9A-F]{8}) ((?:[0-9A-F]{2})+)?\s*(.*)$")
LABEL = re.compile(r"^\.([A-Za-z_][A-Za-z0-9_]*)%?")


def parse():
    """Return (cells, labels, lines).

    cells maps address -> (nbytes, value) with later lines overriding earlier,
    i.e. pass 2.  lines maps address -> source text, same rule.
    """
    raw = LISTING.read_bytes().decode("latin-1")
    cells, labels, lines = {}, {}, {}
    for text in raw.replace("\r", "\n").split("\n"):
        text = text.rstrip()
        if not text:
            continue
        m = LINE.match(text)
        if not m:
            continue
        addr = int(m.group(1), 16)
        src = m.group(3).strip()
        if src:
            lines[addr] = text.rstrip()
        lab = LABEL.match(src)
        if lab:
            labels[lab.group(1)] = addr
        if m.group(2):
            hexval = m.group(2)
            cells[addr] = (len(hexval) // 2, int(hexval, 16))
    return cells, labels, lines


def long_adr_sites():
    """The FNlong_adr expansions, as (address, word1, word2).

    Unlike FNmrs/FNmsr/FNmrc -- which poke memory directly and so never reach
    the listing -- FNlong_adr emits through "[OPT opt%:EQUD optcode1%:EQUD
    optcode2%:]", so both words are listed with their real addresses.  That
    gives the ADD/SUB direction, which is otherwise undecidable at conversion
    time: vasm's .if mis-evaluates a forward label reference (it resolves the
    label to 0), so the sign cannot be chosen with conditional assembly.
    """
    raw = LISTING.read_bytes().decode("latin-1")
    words = {}
    for text in raw.replace("\r", "\n").split("\n"):
        m = re.match(r"^([0-9A-F]{8}) ([0-9A-F]{8})\s+EQUD optcode(1|2)%", text.strip())
        if m:
            words[int(m.group(1), 16)] = (m.group(3), int(m.group(2), 16))
    return [(a, words[a][1], words[a + 4][1])
            for a in sorted(words)
            if words[a][0] == "1" and (a + 4) in words]


def reconstruct(cells, size):
    """Lay the listed values into a buffer, with a coverage mask."""
    buf = bytearray(size)
    seen = bytearray(size)
    over = []
    for addr, (n, value) in cells.items():
        if addr + n > size:
            over.append(addr)
            continue
        for i in range(n):
            buf[addr + i] = (value >> (8 * i)) & 0xFF
            seen[addr + i] = 1
    return buf, seen, over


def main():
    argv = list(sys.argv[1:])
    if "--variant" in argv:
        i = argv.index("--variant")
        use(argv[i + 1])
        del argv[i:i + 2]
    action = argv[0] if argv else "check"
    sys.argv = [sys.argv[0]] + argv
    cells, labels, lines = parse()

    if action == "swis":
        # The union across all variants, so one header serves every build:
        # each listing only names the SWIs its own build happens to use
        # (XOS_Claim/XOS_Release in the release build, XOS_WriteN in RasterMan).
        # Numbers come from the assembled words rather than an external table.
        swis = {}
        for name in variants.VARIANTS:
            if not variants.listing_path(name).exists():
                continue
            use(name)
            for addr, text in sorted(parse()[2].items()):
                m = re.match(r"^[0-9A-F]{8} ([0-9A-F]{8})\s+SWI[A-Z]*\s+\"([^\"]+)\"", text)
                if m:
                    num = int(m.group(1), 16) & 0xFFFFFF
                    if swis.setdefault(m.group(2), num) != num:
                        raise SystemExit("SWI %s has two numbers" % m.group(2))
        out = ["; SWI numbers used by QTM v1.49b, across all build variants.",
               "; Extracted by tools/listing.py from the assembled words in the",
               "; golden listings, so these are the numbers the original used.",
               ""]
        for name in sorted(swis):
            out.append("    .equ %-28s,0x%06X" % (name, swis[name]))
        path = variants.shared_dir() / "swis.h.asm"
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text("\n".join(out) + "\n", encoding="utf-8", newline="\n")
        print("wrote %s (%d SWIs)" % (path, len(swis)))
        return 0

    if action == "labels":
        for name in sorted(labels):
            print("%-28s 0x%04X" % (name, labels[name]))
        return 0

    if action == "at":
        want = int(sys.argv[2], 0)
        for addr in sorted(a for a in lines if abs(a - want) <= 32):
            mark = ">>" if addr == want else "  "
            print("%s %s" % (mark, lines[addr]))
        return 0

    ref = REF.read_bytes()
    buf, seen, over = reconstruct(cells, len(ref))

    covered = sum(seen)
    print("listing: %d value cells, %d labels" % (len(cells), len(labels)))
    print("coverage: %d/%d bytes (%.1f%%)" % (covered, len(ref), 100.0 * covered / len(ref)))
    if over:
        print("warning: %d cells past end of module (first 0x%04X)" % (len(over), over[0]))

    # Regions the listing structurally cannot cover.
    excused = bytearray(len(ref))
    for name, length in POST_FILL:
        if name in labels:
            start = labels[name]
            print("excusing %-14s 0x%04X..0x%04X (post-assembly fill)"
                  % (name, start, start + length))
            for i in range(start, min(start + length, len(ref))):
                excused[i] = 1

    bad = [i for i in range(len(ref))
           if seen[i] and not excused[i] and buf[i] != ref[i]]
    print("\nmismatches vs %s: %d" % (REF.name, len(bad)))
    if bad:
        # Group into runs so the date patch shows up as one region, not 18 bytes.
        runs, start, prev = [], bad[0], bad[0]
        for i in bad[1:]:
            if i != prev + 1:
                runs.append((start, prev))
                start = i
            prev = i
        runs.append((start, prev))
        for lo, hi in runs[:20]:
            got = bytes(buf[lo:hi + 1])
            want = ref[lo:hi + 1]
            print("  0x%04X..0x%04X (%d)  listing=%r  module=%r"
                  % (lo, hi, hi - lo + 1, got[:24], want[:24]))
        if len(runs) > 20:
            print("  ... and %d more runs" % (len(runs) - 20))
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
