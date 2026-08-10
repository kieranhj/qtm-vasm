#!/usr/bin/env python3
"""Assemble one variant of the vasm port and compare it against its reference.

Byte-for-byte equality with the shipped module is the acceptance test; the CRC
is reported only for parity with the original build's harness (and note that the
build's own stored CRC is a v1.45 leftover -- see PLAN.md 0.3, so the value
checked here is recomputed from the shipped binary, not taken from the source).

When the output differs, the first differing offset is correlated against
ref/listing.txt -- the golden per-line listing from the original BASIC build --
so a mismatch reports which source line assembled differently rather than just
an address.  The listing is optional: without it the diff still works, it just
cannot name the line.

Usage:
    verify.py [--variant NAME]             assemble, then compare
    verify.py [--variant NAME] --no-build  compare an existing build/qtm-<variant>.bin
"""
import re
import subprocess
import sys
import zlib
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import variants

ROOT = Path(__file__).resolve().parent.parent
VASM = ROOT / "tools" / "vasmarm_std_win32.exe"
VARIANT = variants.DEFAULT
if "--variant" in sys.argv:
    VARIANT = sys.argv[sys.argv.index("--variant") + 1]

# A variant that overlays modified sources keeps its own copy of the top-level
# file, because vasm resolves .include relative to the including file's
# directory before -I; assembling src/shared/qtm.asm would silently pull in the
# shared copies of everything and ignore the overlay.
TOP = variants.src_dir(VARIANT) / "qtm.asm"
if not TOP.exists():
    TOP = variants.shared_dir() / "qtm.asm"
OUT = ROOT / "build" / ("qtm-%s.bin" % VARIANT)
REF = variants.module_path(VARIANT)
LISTING = variants.listing_path(VARIANT)

# Taken from the reference binary rather than asserted: only the release build
# has a published size and CRC, and the variants' references were captured
# locally (see tools/emulator/README.md).
EXPECT_SIZE = REF.stat().st_size
EXPECT_CRC = ~zlib.crc32(REF.read_bytes()) & 0xFFFFFFFF

CONTEXT = 16                     # bytes either side of a mismatch


def crc(data):
    return ~zlib.crc32(data) & 0xFFFFFFFF


def build():
    if not TOP.exists():
        print("no %s yet -- nothing to assemble (Phase 1 not started)" % TOP)
        return False
    OUT.parent.mkdir(exist_ok=True)
    cmd = [str(VASM), "-m250", "-Fbin",
           "-I", str(variants.src_dir(VARIANT)),   # config header, stamps, overlays
           "-I", str(variants.shared_dir()),        # the shared sources
           "-o", str(OUT), str(TOP)]
    print("$ " + " ".join(cmd))
    r = subprocess.run(cmd, capture_output=True, text=True)
    sys.stdout.write(r.stdout)
    sys.stderr.write(r.stderr)
    if r.returncode != 0:
        print("vasm failed (exit %d)" % r.returncode)
        return False
    return True


# ----------------------------------------------------------------- listing

LISTING_LINE = re.compile(r"^([0-9A-Fa-f]{6,8})\s+([0-9A-Fa-f]{8})\s")


def load_listing():
    """Map address -> source text, from a *Spool'd opt%=13/15 BASIC listing.

    Each listed line starts with an address and the assembled word.  Lines the
    BASIC assembler pokes directly into memory (FNmrs/FNmsr/FNmrc/FNmcr, 28
    sites) never reach the listing, so gaps here are expected, not corruption.
    """
    if not LISTING.exists():
        return None
    table = {}
    for raw in LISTING.read_text(encoding="latin-1", errors="replace").splitlines():
        m = LISTING_LINE.match(raw.strip())
        if m:
            table[int(m.group(1), 16)] = raw.rstrip()
    return table


def nearest(table, offset):
    """The listed line at or immediately before offset."""
    best = None
    for addr in table:
        if addr <= offset and (best is None or addr > best):
            best = addr
    return (best, table[best]) if best is not None else (None, None)


# ----------------------------------------------------------------- compare

def hexdump(data, start, end, mark):
    lines = []
    lo = max(0, start) & ~0xF
    for base in range(lo, min(end, len(data)), 16):
        chunk = data[base:base + 16]
        cells = []
        for i, b in enumerate(chunk):
            cells.append(("[%02X]" if base + i == mark else " %02X ") % b)
        text = "".join(chr(b) if 32 <= b < 127 else "." for b in chunk)
        lines.append("  %06X %s %s" % (base, "".join(cells), text))
    return "\n".join(lines)


def compare():
    if not OUT.exists():
        print("no build output at %s" % OUT)
        return 1
    got = OUT.read_bytes()
    want = REF.read_bytes()

    print("\nsize   built %d, reference %d  %s"
          % (len(got), len(want),
             "OK" if len(got) == len(want) == EXPECT_SIZE else "MISMATCH"))
    print("crc    built %08X, expected %08X  %s"
          % (crc(got), EXPECT_CRC, "OK" if crc(got) == EXPECT_CRC else "MISMATCH"))

    if got == want:
        print("\nIDENTICAL -- acceptance test passed.")
        return 0

    diffs = [i for i in range(min(len(got), len(want))) if got[i] != want[i]]
    if not diffs:
        print("\ncommon prefix matches; lengths differ by %d bytes"
              % abs(len(got) - len(want)))
        return 1

    first = diffs[0]
    print("\n%d differing bytes; first at 0x%04X (%d)" % (len(diffs), first, first))

    table = load_listing()
    if table:
        addr, text = nearest(table, first)
        if addr is None:
            print("listing: no line at or before 0x%04X" % first)
        else:
            print("listing: 0x%04X (+%d bytes) %s" % (addr, first - addr, text))
    else:
        print("listing: %s absent -- cannot name the source line "
              "(see PLAN.md Phase 0.2)" % LISTING.name)

    print("\nbuilt:")
    print(hexdump(got, first - CONTEXT, first + CONTEXT, first))
    print("reference:")
    print(hexdump(want, first - CONTEXT, first + CONTEXT, first))
    return 1


def main():
    if "--no-build" not in sys.argv:
        if not build():
            return 1
    if not variants.has_reference(VARIANT):
        # An experimental variant has no ground truth to be identical to;
        # report what was built so a change in size is at least visible.
        got = OUT.read_bytes()
        print("\nsize   built %d  (no reference -- experimental variant)"
              % len(got))
        print("crc    built %08X" % crc(got))
        return 0
    return compare()


if __name__ == "__main__":
    sys.exit(main())
