#!/usr/bin/env python3
"""Derive QTM's BASIC-computed offset constants, for Phase 0(b).

The PLAN expected these to need a PROCdumpsyms run under an emulator.  They do
not: every one is either a literal scalar assignment or a constant expression,
and the FNtableoffsets labels come from a throwaway assembly pass over a body
containing nothing but zero fills and explicit P% adjustments.  So the whole set
is derivable here, and -- importantly -- it self-checks, because the original
build asserts

    generalusebuffer = generaluse_addr - song_data      (QTMv1A49 line 680)

which ties the scalar arithmetic to the simulated layout.  If either side is
wrong, that assertion fails rather than silently producing a bad header.

Usage:
    dumpsyms.py check     derive, run the assertion, print the symbols
    dumpsyms.py emit      write src/qtm_offsets.h.asm
"""
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "ref" / "source-text"

LINENO = re.compile(r"^\s*\d+ ?")

import variants

# The build switches come from tools/variants.py, so the offsets header is
# generated per variant: dma, uS, maxchans and the shifts all differ between
# the release and RasterMan builds, and QTM_DMA folds "dmarep=dma/4" from them.
CONFIG = variants.constants(variants.DEFAULT)
CURRENT = variants.DEFAULT


def use(name):
    global CONFIG, CURRENT
    CONFIG = variants.constants(name)
    CURRENT = name



def source_lines(name):
    text = (SRC / name).read_text(encoding="utf-8")
    return [LINENO.sub("", ln) for ln in text.split("\n")]


def body(lines, start_re, end_re="^ENDPROC"):
    out, inside = [], False
    for ln in lines:
        if not inside:
            if re.match(start_re, ln.strip()):
                inside = True
            continue
        if re.match(end_re, ln.strip()):
            break
        out.append(ln)
    return out


def strip_comment(ln):
    """Drop a trailing :REM (BASIC) or ; (assembler) comment.

    Neither body contains a string literal that could hold one of these, so a
    plain split is safe.
    """
    ln = re.split(r":\s*REM\b", ln, maxsplit=1)[0]
    return ln.split(";", 1)[0].rstrip()


# BASIC writes 00, 08, 09 for alignment; Python would reject those as literals.
LEADING_ZERO = re.compile(r"\b0+(\d)")


def basic_eval(expr, env):
    expr = LEADING_ZERO.sub(r"\1", expr)
    expr = expr.replace("&", "0x")
    return int(eval(expr, {"__builtins__": {}}, dict(env)))


# ------------------------------------------------------- scalar constants

ASSIGN = re.compile(r"^([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.+)$")

# Scratch variables of the throwaway assembly pass, not module constants.
LOCALS = {"dataoffs", "dataoffs_size", "opt"}


def scalar_constants():
    """The `name = expr` lines in PROCinit_offsets, in source order."""
    env, ordered = {}, []
    for ln in body(source_lines("QTM_Data.bas"), r"^DEF PROCinit_offsets"):
        ln = strip_comment(ln).strip()
        if not ln or ln == ":" or ln.startswith("REM"):
            continue
        m = ASSIGN.match(ln)
        if not m:
            continue
        name, expr = m.group(1), m.group(2).strip()
        if not expr or name in LOCALS:
            continue
        try:
            value = basic_eval(expr, env)
        except Exception:
            continue          # LOCAL/DIM lines and the throwaway assembly pass
        env[name] = value
        ordered.append((name, value, expr))
    return env, ordered


# ------------------------------------------------------- FNtableoffsets layout

STRINGFILL = re.compile(r"EQUS\s+STRING\$\(([^,]+),CHR\$0\)")
SKIP = re.compile(r"P%\+=(\d+(?:\*\d+)?)")


def table_offsets():
    """Simulate the FNtableoffsets pass: labels -> offset from song_data.

    The body is only zero fills, EQUD/EQUB, explicit P%+= skips and one ALIGN,
    so a literal walk is exact rather than an approximation.
    """
    labels, pc = [], 0
    for ln in body(source_lines("QTM_Data.bas"), r"^DEF FNtableoffsets", r"^=opt%"):
        code = strip_comment(ln).strip()
        if not code:
            continue
        for stmt in code.split(":"):
            stmt = stmt.strip()
            # A label may share its line with a directive (".rm_use_word EQUD 0"),
            # so consume the label and go on to assemble the remainder.
            if stmt.startswith("."):
                name, _, stmt = stmt[1:].partition(" ")
                labels.append((name.rstrip("%"), pc))
                stmt = stmt.strip()
            if not stmt:
                continue
            if STRINGFILL.search(stmt):
                pc += basic_eval(STRINGFILL.search(stmt).group(1), {})
            elif SKIP.search(stmt):
                pc += basic_eval(SKIP.search(stmt).group(1), {})
            elif re.match(r"^EQUD\b", stmt):
                pc += 4
            elif re.match(r"^EQUW\b", stmt):
                pc += 2
            elif re.match(r"^EQUB\b", stmt):
                pc += 1
            elif stmt == "ALIGN":
                pc = (pc + 3) & ~3
    return labels, pc


# ------------------------------------------------------- output

def derive():
    env, scalars = scalar_constants()
    labels, end = table_offsets()
    return env, scalars, labels, end


def assertions(env, labels):
    """Cross-checks tying the scalar arithmetic to the simulated layout.

    The first is the original build's own check.  The second is one it does not
    make but which follows from the source: dma_clc is defined by summing the
    table sizes by hand, so it must land exactly on the unused_e label.  It
    covers the part of the layout that lies beyond the first check's reach.
    """
    lab = dict(labels)
    return [
        ("generalusebuffer == generaluse_addr - song_data   (QTMv1A49:680)",
         env["generalusebuffer"], lab["generaluse_addr"] - lab["song_data"]),
        ("dma_clc          == unused_e",
         env["dma_clc"], lab["unused_e"]),
    ]


def main():
    argv = list(sys.argv[1:])
    if "--variant" in argv:
        i = argv.index("--variant")
        use(argv[i + 1])
        del argv[i:i + 2]
    action = argv[0] if argv else "check"
    env, scalars, labels, end = derive()
    checks = assertions(env, labels)
    ok = all(a == b for _, a, b in checks)

    if action == "check":
        print("== config ==")
        for name, value, _ in CONFIG:
            print("  %-18s = %d" % (name, value))
        print("\n== FNtableoffsets labels (offset from song_data) ==")
        for name, off in labels:
            print("  %-18s = &%04X  (%d)" % (name, off, off))
        print("  %-18s = &%04X  (%d)" % ("<size>", end, end))
        print("\n== PROCinit_offsets scalars: %d ==" % len(scalars))
        for name, value, expr in scalars:
            print("  %-18s = &%04X  (%-6d)  <- %s" % (name, value, value, expr))
        print("\n== assertions ==")
        for desc, a, b in checks:
            print("  %-3s %s   (%d vs %d)"
                  % ("OK" if a == b else "***", desc, a, b))
        return 0 if ok else 1

    if action == "emit":
        if not ok:
            for desc, a, b in checks:
                if a != b:
                    print("refusing to emit: failed %s (%d != %d)" % (desc, a, b))
            return 1
        out = ["; QTM v1.49b -- offset constants (Phase 0b).",
               "; Generated by tools/dumpsyms.py from ref/source-text; do not hand-edit.",
               "; Variant: %s -- %s." % (CURRENT, variants.get(CURRENT)["note"]),
               "",
               "; ---- build configuration ----"]
        # vasm's std syntax accepts only the `.equ name,value` form here: a bare
        # `name = value` in column 0 is read as a mnemonic and rejected.
        for name, value, note in CONFIG:
            c = ("    ; " + note) if note else ""
            out.append("    .equ %-18s,%d%s" % (name, value, c))
        out += ["", "; ---- FNtableoffsets: offsets from song_data ----"]
        for name, off in labels:
            out.append("    .equ %-18s,0x%04X" % (name, off))
        out.append("    .equ %-18s,0x%04X" % ("song_data_size", end))
        out += ["", "; ---- PROCinit_offsets scalars ----"]
        for name, value, expr in scalars:
            out.append("    .equ %-18s,0x%04X    ; %s" % (name, value, expr))
        out += ["",
                "; Compile-time restatement of the original build's own check",
                "; (QTMv1A49 line 680).",
                "    .if generalusebuffer != (generaluse_addr - song_data)",
                '    .fail "Data offsets misaligned!"',
                "    .endif",
                ""]
        path = variants.src_dir(CURRENT) / "qtm_offsets.h.asm"
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text("\n".join(out), encoding="utf-8", newline="\n")
        print("wrote %s (%d labels, %d scalars)" % (path, len(labels), len(scalars)))
        return 0

    print(__doc__)
    return 2


if __name__ == "__main__":
    sys.exit(main())
