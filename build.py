#!/usr/bin/env python3
"""Regenerate the whole vasm port from ref/ and verify it against the module.

Everything under src/ is generated, so this script is the build: it recreates
each file from the detokenised BASIC and the Phase 0 artefacts, then assembles
and compares against ref/QTMModule.

    python build.py            regenerate, assemble, verify
    python build.py --check    verify only, without regenerating
"""
import glob
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent
PY = sys.executable

# Assembly order is fixed by PROCassm and reproduced in src/qtm.asm; this list
# is only the set of files to generate.
SOURCES = ["QTM_Timer", "QTM_VUcode", "QTM_Song", "QTM_Data",
           "QTM_Play", "QTM_DMA", "QTM_Mod"]


def run(args, **kw):
    r = subprocess.run([PY] + args, capture_output=True, text=True, **kw)
    if r.returncode != 0:
        sys.stdout.write(r.stdout)
        sys.stderr.write(r.stderr)
        raise SystemExit("failed: %s" % " ".join(args))
    return r


def driver():
    """QTMv1A49.bas -- the name carries a top-bit-set character."""
    return [p for p in glob.glob(str(ROOT / "ref/source-text/*.bas")) if "v1" in Path(p).name][0]


def generate():
    print("== Phase 0 artefacts ==")
    run(["tools/dumpsyms.py", "emit"])
    run(["tools/textcomprs.py", "emit"])
    run(["tools/listing.py", "swis"])

    print("\n== data blobs ==")
    (ROOT / "src/LOGdata").write_bytes((ROOT / "ref/source-tokenised/LOGdata").read_bytes())
    print("copied src/LOGdata (256 bytes)")
    run(["tools/mkamiperiods.py"])

    print("\n== translation ==")
    for name in SOURCES:
        out = "src/%s.asm" % name.lower()
        r = run(["tools/bas2vasm.py", "ref/source-text/%s.bas" % name, "-o", out])
        todo = [l for l in r.stderr.splitlines() if l.strip().startswith("line ")]
        print("  %-14s %s" % (out, "%d deferred" % len(todo) if todo else "clean"))

    print("\n== top level ==")
    run(["tools/mktoplevel.py", driver()])


def main():
    if "--check" not in sys.argv:
        generate()
    print("\n== verify ==")
    # verify.py writes straight to the terminal, so flush first or its output
    # lands ahead of everything above.
    sys.stdout.flush()
    r = subprocess.run([PY, "tools/verify.py"], text=True)
    return r.returncode


if __name__ == "__main__":
    raise SystemExit(main())
