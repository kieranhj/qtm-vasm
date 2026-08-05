#!/usr/bin/env python3
"""Generate src/qtm.asm from PROCassm in the driver (Phase 4).

PROCassm's body is the module's table of contents: its FNassm_* calls are what
fix the layout order (Mod, Play, Song, DMA, the inline divide/ARM-check code,
Data), so the top-level file is a translation of it rather than something
written by hand.  bas2vasm maps those calls onto .include directives.

The original assembles with P%=0 and O%=code% into a 63K buffer that is zeroed
first, so addresses are relative to the module base and every skipped region is
zero: .org 0 with -Fbin reproduces both.

Usage:
    mktoplevel.py <driver.bas>
"""
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import variants

ROOT = Path(__file__).resolve().parent.parent

PROLOGUE = """\
; QTM v1.49b -- top level.  Generated from PROCassm in the driver by
; tools/mktoplevel.py; do not hand-edit.
;
; The original assembles at P%=0 into a pre-zeroed 63K buffer with O%=code%, so
; module addresses are relative to the module base: .org 0 with -Fbin.  The
; include order below is PROCassm's own, and is what fixes the module layout.

\t.include "qtm_offsets.h.asm"
\t.include "swis.h.asm"

\t.org 0
"""


def main():
    argv = list(sys.argv[1:])
    variant = variants.DEFAULT
    if "--variant" in argv:
        i = argv.index("--variant")
        variant = argv[i + 1]
        del argv[i:i + 2]
    driver = argv[0]
    scratch = ROOT / "build" / ("procassm-%s.asm" % variant)
    scratch.parent.mkdir(exist_ok=True)
    r = subprocess.run([sys.executable, str(ROOT / "tools" / "bas2vasm.py"),
                        driver, "--only", "PROCassm", "--variant", variant,
                        "-o", str(scratch)],
                       capture_output=True, text=True)
    sys.stderr.write(r.stderr)
    if r.returncode != 0:
        return 1

    # Drop bas2vasm's own two-line banner; this file carries its own.
    body = scratch.read_text(encoding="utf-8").split("\n")[3:]
    path = variants.shared_dir() / "qtm.asm"
    path.write_text(PROLOGUE + "\n".join(body).rstrip() + "\n",
                    encoding="utf-8", newline="\n")
    print("wrote %s" % path)
    return 0


if __name__ == "__main__":
    sys.exit(main())
