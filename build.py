#!/usr/bin/env python3
"""Regenerate the vasm port from ref/ and verify it against the reference binaries.

Everything under src/ is generated, so this script is the build.  The
translated assembly is shared by every variant and goes to src/shared/; only
the config header and the version stamps are per variant, in src/<variant>/.
src/shared/ is regenerated for each variant and must come out identical every
time -- if it does not, something variant-specific has leaked into the shared
sources, and that is reported as a failure.

    python build.py                  all variants
    python build.py release rm48     just these
    python build.py --check          verify only, without regenerating
"""
import hashlib
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent / "tools"))
import variants

ROOT = Path(__file__).resolve().parent
PY = sys.executable

# Files to translate.  Assembly order is fixed by PROCassm and reproduced in
# each variant's qtm.asm, so this is only the set, not the sequence.
SOURCES = ["QTM_Timer", "QTM_VUcode", "QTM_Song", "QTM_Data",
           "QTM_Play", "QTM_DMA", "QTM_Mod"]


def run(args, quiet=True):
    r = subprocess.run([PY] + args, capture_output=True, text=True, cwd=ROOT)
    if r.returncode != 0:
        sys.stdout.write(r.stdout)
        sys.stderr.write(r.stderr)
        raise SystemExit("failed: %s" % " ".join(args))
    return r


def driver():
    """QTMv1A49.bas -- the filename carries a top-bit-set character."""
    return [str(p) for p in (ROOT / "ref/source-text").glob("*.bas")
            if "v1" in p.name][0]


def generate(variant):
    """Regenerate the shared sources plus this variant's own two files.

    The translated assembly is identical for every variant -- the switches
    reach it as .equ symbols and .if blocks -- so it is written once into
    src/shared/.  Only the config header and the two version stamps differ.
    """
    shared = variants.shared_dir()
    shared.mkdir(parents=True, exist_ok=True)
    variants.src_dir(variant).mkdir(parents=True, exist_ok=True)

    run(["tools/dumpsyms.py", "emit", "--variant", variant])
    run(["tools/textcomprs.py", "emit"])
    run(["tools/listing.py", "swis"])
    (shared / "LOGdata").write_bytes((ROOT / "ref/source-tokenised/LOGdata").read_bytes())
    run(["tools/mkamiperiods.py", "--variant", variant])

    deferred = 0
    for name in SOURCES:
        r = run(["tools/bas2vasm.py", "ref/source-text/%s.bas" % name,
                 "--variant", variant, "-o", str(shared / ("%s.asm" % name.lower()))])
        deferred += len([l for l in r.stderr.splitlines()
                         if l.strip().startswith("line ")])
    run(["tools/mktoplevel.py", driver(), "--variant", variant])
    return deferred


def shared_hashes():
    return {f.name: hashlib.sha256(f.read_bytes()).hexdigest()
            for f in sorted(variants.shared_dir().iterdir()) if f.is_file()}


def main():
    argv = [a for a in sys.argv[1:] if not a.startswith("-")]
    check_only = "--check" in sys.argv
    wanted = argv or list(variants.VARIANTS)

    failures, baseline = [], None
    for variant in wanted:
        info = variants.get(variant)
        print("\n=== %s -- %s ===" % (variant, info["note"]))
        if not variants.module_path(variant).exists():
            print("  no reference binary (%s); skipping" % info["module"])
            continue
        if not check_only:
            deferred = generate(variant)
            print("  generated src/%s/ (%s)"
                  % (variant, "%d deferred" % deferred if deferred else "clean"))
            # src/shared/ is regenerated for each variant and must come out
            # identical every time; if it does not, something variant-specific
            # has leaked into the shared sources and the layout is a lie.
            current = shared_hashes()
            if baseline is None:
                baseline = current
            elif current != baseline:
                drifted = [k for k in current if current.get(k) != baseline.get(k)]
                print("  *** src/shared/ differs for this variant: %s"
                      % ", ".join(drifted))
                failures.append(variant)
        sys.stdout.flush()
        r = subprocess.run([PY, "tools/verify.py", "--variant", variant],
                           capture_output=True, text=True, cwd=ROOT)
        tail = [l for l in r.stdout.splitlines()
                if l.startswith(("size", "crc")) or "IDENTICAL" in l]
        for line in tail:
            print("  " + line)
        if r.returncode != 0:
            failures.append(variant)
            sys.stdout.write(r.stdout)
            sys.stderr.write(r.stderr)

    print("\n%d/%d variants byte-identical" % (len(wanted) - len(failures), len(wanted)))
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
