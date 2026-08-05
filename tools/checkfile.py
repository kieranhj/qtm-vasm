#!/usr/bin/env python3
"""Assemble one converted file in isolation and diff it against ref/QTMModule.

This is what makes Phase 1 tractable file by file.  The golden listing gives an
address for all 605 labels, so a single translated file can be assembled at its
real address, with every label it references but does not define supplied as an
.equ stub.  The result is compared byte-for-byte against the corresponding slice
of the shipped module -- no need to wait until the whole port links.

On a mismatch the offending word is reported alongside the original source line
from the listing, which is the point of having captured it.

Usage:
    checkfile.py src/qtm_timer.asm
"""
import re
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import listing as golden
import variants

ROOT = Path(__file__).resolve().parent.parent
VASM = ROOT / "tools" / "vasmarm_std_win32.exe"
REF = variants.module_path(variants.DEFAULT)
WORK = ROOT / "build"

LABEL_DEF = re.compile(r"^([A-Za-z_][A-Za-z0-9_]*):")
# '#' must not be excluded here: "[R11,#ch16-textdata]" references a real label
# through an immediate, and skipping those leaves it undefined (resolving to 0).
IDENT = re.compile(r"(?<![\w.])([A-Za-z_][A-Za-z0-9_]*)")

# Directives and mnemonics must not be mistaken for label references.
NOT_LABELS = set("""
    LSL LSR ASR ROR RRX PC LR SP CPSR SPSR
""".split())


def defined_labels(text):
    return [m.group(1) for m in (LABEL_DEF.match(l) for l in text.splitlines()) if m]


def header_symbols(src_root):
    """Names already provided by the shared headers, so not external."""
    names = set()
    for name in ("qtm_offsets.h.asm", "swis.h.asm"):
        path = src_root / name
        if path.exists():
            for m in re.finditer(r"^\s*\.equ\s+([A-Za-z_][A-Za-z0-9_]*)",
                                 path.read_text(encoding="utf-8"), re.M):
                names.add(m.group(1))
    return names


def referenced(text):
    names = set()
    for line in text.splitlines():
        line = line.split(";")[0]
        line = re.sub(r'"[^"]*"', "", line)      # string data holds no labels
        # Directive lines are scanned too: FNlong_adr expands to .long with
        # label arithmetic in it, and skipping those leaves the target
        # unstubbed, which surfaces as "illegal relocation" rather than as an
        # undefined symbol.
        if line.strip().startswith((".include", ".p2align", ".org")):
            continue
        # Drop the mnemonic field; operands are what can name a label.
        body = line.strip()
        if LABEL_DEF.match(body):
            body = body[body.index(":") + 1:]
        parts = body.split(None, 1)
        if len(parts) < 2:
            continue
        for m in IDENT.finditer(parts[1]):
            name = m.group(1)
            if name.upper() in NOT_LABELS:
                continue
            if re.fullmatch(r"[Rr]\d+", name):
                continue
            names.add(name)
    return names


def main():
    global REF
    argv = list(sys.argv[1:])
    variant = variants.DEFAULT
    if "--variant" in argv:
        i = argv.index("--variant")
        variant = argv[i + 1]
        del argv[i:i + 2]
    golden.use(variant)
    REF = variants.module_path(variant)
    src = Path(argv[0])
    text = src.read_text(encoding="utf-8")

    cells, labels, lines = golden.parse()

    # Labels from .include'd files are defined too, so they must not also be
    # stubbed -- vasm would report them as redefined.
    mine = defined_labels(text)
    included = ""
    for inc in re.findall(r'^\s*\.include\s+"([^"]+)"', text, re.M):
        path = src.parent / Path(inc).name
        if path.exists():
            body = path.read_text(encoding="utf-8")
            mine += defined_labels(body)
            included += "\n" + body
    known = [n for n in mine if n in labels]
    if not known:
        print("none of this file's labels appear in the listing -- cannot place it")
        return 2
    start = min(labels[n] for n in known)
    missing = [n for n in mine if n not in labels]

    # Everything referenced but not defined here, that the listing knows about.
    externals = sorted(referenced(text + included) - set(mine) - header_symbols(src.parent))
    stubs = ["; Auto-generated stubs: labels defined in other files, taken from",
             "; the golden listing so this file can be placed and checked alone.",
             ""]
    unresolved = []
    for name in externals:
        if name in labels:
            stubs.append("    .equ %-24s,0x%04X" % (name, labels[name]))
        else:
            unresolved.append(name)

    WORK.mkdir(exist_ok=True)
    stub_path = WORK / (src.stem + "_stubs.h.asm")
    stub_path.write_text("\n".join(stubs) + "\n", encoding="utf-8", newline="\n")

    top = WORK / (src.stem + "_test.asm")
    top.write_text(
        '\t.include "%s"\n\t.include "%s"\n\t.include "%s"\n'
        '\t.org 0x%X\n\t.include "%s"\n'
        % ((src.parent / "qtm_offsets.h.asm").as_posix(),
           (src.parent / "swis.h.asm").as_posix(),
           stub_path.as_posix(), start, src.as_posix()),
        encoding="utf-8", newline="\n")

    out = WORK / (src.stem + ".bin")
    lst = WORK / (src.stem + ".lst")
    r = subprocess.run([str(VASM), "-m250", "-Fbin", "-o", str(out),
                        "-I", str(src.parent), "-L", str(lst), str(top)],
                       capture_output=True, text=True)
    errors = [l for l in (r.stdout + r.stderr).splitlines()
              if "error" in l.lower() or l.startswith(">")]
    if r.returncode != 0:
        print("vasm failed:")
        print("\n".join(errors[:40]))
        return 1

    got = out.read_bytes()
    ref = REF.read_bytes()[start:start + len(got)]

    print("placed at 0x%04X, %d bytes" % (start, len(got)))
    if unresolved:
        print("unresolved (not in listing): %s" % ", ".join(unresolved[:10]))
    if missing:
        print("labels not found in listing: %s" % ", ".join(missing[:10]))

    if got == ref:
        print("\nIDENTICAL to ref/QTMModule[0x%04X:0x%04X]" % (start, start + len(got)))
        return 0

    # Where did the layout first drift?  Comparing our label addresses against
    # the listing's localises a missing or extra run of bytes far better than
    # the byte diff, which only shows the first forward reference to notice.
    ours = {}
    if lst.exists():
        body = lst.read_text(encoding="latin-1", errors="replace")
        tail = body.split("Symbols:", 1)[-1]
        for m in re.finditer(r"^(\S+)\s+EXPR\((\d+)=0x[0-9a-f]+\)", tail, re.M):
            ours[m.group(1)] = int(m.group(2))
    shared = [(labels[n], n) for n in mine if n in labels and n in ours]
    # A label between data and code is deliberately moved to the following word
    # boundary, because BASIC rounds branch destinations up and vasm rejects a
    # branch to an unaligned label.  That is expected, not drift.
    drifted = [(a, n, ours[n] - a) for a, n in sorted(shared)
               if ours[n] != a and ours[n] != (a + 3) & ~3]
    if drifted:
        addr, name, delta = drifted[0]
        print("layout drift: %d of %d labels misplaced; first is %s "
              "(listing 0x%04X, ours 0x%04X, %+d)"
              % (len(drifted), len(shared), name, addr, ours[name], delta))
        prior = [(a, n) for a, n in sorted(shared) if a < addr]
        if prior:
            print("last correct label before it: %s at 0x%04X" % (prior[-1][1], prior[-1][0]))

    bad = [i for i in range(len(got)) if got[i] != ref[i]]
    print("\n%d differing bytes of %d; first at 0x%04X (+%d into the file)"
          % (len(bad), len(got), start + bad[0], bad[0]))
    todo = [(n, l) for n, l in enumerate(text.splitlines(), 1) if "TODO(" in l]
    if todo:
        print("first unexpanded site: %s" % todo[0][1].strip()[:88])
    shown = set()
    for i in bad:
        word = start + (i & ~3)
        if word in shown:
            continue
        shown.add(word)
        print("\n  0x%04X  ours=%s  module=%s"
              % (word,
                 got[word - start:word - start + 4].hex().upper(),
                 ref[word - start:word - start + 4].hex().upper()))
        if word in lines:
            print("  listing: %s" % lines[word])
        if len(shown) >= 15:
            print("\n  ... %d more differing bytes" % (len(bad) - len(shown)))
            break
    return 1


if __name__ == "__main__":
    sys.exit(main())
