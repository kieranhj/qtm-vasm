#!/usr/bin/env python3
"""Produce the guard-gap mixer by patching the generated qtm_dma.asm.

Writes src/<variant>/qtm_dma.asm, which vasm picks up ahead of the shared copy
because the variant directory comes first on the include path.  Generated
rather than checked in, so it survives regeneration of the file it patches --
and so the diff against stock QTM stays visible as a short list of edits
instead of a 1600-line fork.

**This build only works against samples prepared by tools/prep.**  Without a
guard gap the mixer reads past the loop end into whatever follows.

The change rests on two facts established by measurement, not assumption
(MEASUREMENTS.md):

  * QTM ends a looping sample at its loop end -- at note-on, qtm_play.asm does
    `CMP R3,#2 / ADDGT R1,R3,R2` so length becomes rep_off+rep_len.  Confirmed
    live: DMA_address == DMA_repaddr on every active channel.  So the repeat
    loops and the plain loops index from the *same* address and differ only by
    the wrap.

  * The wrap is `SUBGE R1,R1,R5,LSL #12`, inline and branchless, one clock per
    byte on the 52% of channel-fills measured as repeating.  There is no
    per-fill split to remove -- this instruction is the whole cost.

So the patch is: delete that instruction from the three repeat loops, and
normalise the offset once per fill instead.  The normalisation goes at the
*top* of a2_chanctrl rather than after the fill, because the unrolled routines
return straight to a2_DMAchannels and never run a tail there -- and because
`CMN R1,#0x1000` immediately after recomputes the flags, so nothing downstream
sees the ones the fixup leaves behind.

Usage:
    patch_dma.py [--variant gg]
"""
import argparse
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
import variants                                                # noqa: E402

# The unrolled routines, in the order their records appear in unroll_table.
GROUPS = ["endanyvol", "endfullvol", "repanyvol", "repfullvol",
          "repnovol", "clearing", "anyvolume", "fullvolume"]

# Loop bodies losing their wrap, and the new instruction count for the
# matching unroll_table record.
DEWRAP = {"repanyvol": 5, "repfullvol": 3, "repnovol": 2}

FIXUP = """
; --- guard gap: normalise the offset once per fill -------------------------
; The inner loops no longer wrap, so the offset arrives here having run past
; the repeat end into the guard.  Bring it back before anything reads it.
; R14 is free (stacked on entry); the CMN below recomputes the flags.
	CMP	R1,#0
	BLT	gg_offset_ok
	CMP	R5,#3                                           ;replen<3 means not looping
	BLT	gg_offset_ok
	MOV	R14,R5,LSL #0xC
gg_offset_wrap:
	SUBS	R1,R1,R14
	BGE	gg_offset_wrap
gg_offset_ok:
; ---------------------------------------------------------------------------
"""

ANCHOR = "LDMIA\tR8,{R0-R5}"
SUBGE = re.compile(r"^\tSUBGE\tR1,R1,R5,LSL #0xC\b")
BODY = re.compile(r"^\t\.long\t\(\(dmarep << 8\) \+ (\d+)\)")


def strip_wraps(lines):
    """Delete the per-byte wrap from each repeat loop body."""
    hits = []
    for want in DEWRAP:
        label = "a2_%s_loop:" % want
        try:
            i = next(n for n, l in enumerate(lines) if l.startswith(label))
        except StopIteration:
            raise SystemExit("patch_dma: no %s" % label)
        j = next((n for n in range(i, min(i + 14, len(lines)))
                  if SUBGE.match(lines[n])), None)
        if j is None:
            raise SystemExit("patch_dma: no SUBGE wrap in %s" % label)
        hits.append(j)
    for j in sorted(hits, reverse=True):
        del lines[j]
    return len(hits)


def retime_table(lines):
    """Drop one instruction from the affected unroll_table body records.

    Walked positionally: unroll_code reads (count << 8) + ninstr records and a
    0 terminator per routine, so the groups are identified by order, not by the
    comments -- two routines legitimately share the same record value.
    """
    try:
        start = next(n for n, l in enumerate(lines)
                     if l.startswith("unroll_table:"))
    except StopIteration:
        raise SystemExit("patch_dma: no unroll_table")
    g, done = 0, 0
    for n in range(start + 1, len(lines)):
        line = lines[n]
        if re.match(r"^\t\.long\t0\s*$", line):
            g += 1
            if g >= len(GROUPS):
                break
            continue
        m = BODY.match(line)
        if m and GROUPS[g] in DEWRAP:
            want = DEWRAP[GROUPS[g]]
            if int(m.group(1)) != want + 1:
                raise SystemExit("patch_dma: %s body is %s instructions, "
                                 "expected %d" % (GROUPS[g], m.group(1), want + 1))
            lines[n] = line.replace("+ %s)" % m.group(1), "+ %d)" % want, 1) \
                + "   ;guard gap: was %s, wrap removed" % m.group(1)
            done += 1
    if done != len(DEWRAP):
        raise SystemExit("patch_dma: retimed %d records, expected %d"
                         % (done, len(DEWRAP)))
    return done


def add_fixup(lines):
    """Insert the per-fill normalisation at the top of a2_chanctrl.

    The same LDMIA appears three times -- the ARM3 mixer has its own
    dispatchers -- so the anchor is scoped to a2_chanctrl.  The ARM3 path is
    deliberately left stock: the target here is an 8 MHz ARM2, and QTM picks
    the a2_ routines on it via the armchip test.  An ARM3 build would need the
    same treatment.
    """
    try:
        top = next(n for n, l in enumerate(lines)
                   if l.startswith("a2_chanctrl:"))
    except StopIteration:
        raise SystemExit("patch_dma: no a2_chanctrl")
    idx = [n for n in range(top, min(top + 30, len(lines)))
           if ANCHOR in lines[n]]
    if len(idx) != 1:
        raise SystemExit("patch_dma: %d anchors in a2_chanctrl, expected 1"
                         % len(idx))
    lines[idx[0]:idx[0] + 1] = [lines[idx[0]]] + FIXUP.strip("\n").split("\n")
    return 1


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--variant", default="gg")
    a = ap.parse_args()

    src = variants.shared_dir() / "qtm_dma.asm"
    lines = src.read_text(encoding="utf-8").split("\n")

    n_wrap = strip_wraps(lines)
    n_tab = retime_table(lines)
    n_fix = add_fixup(lines)

    head = ["; GUARD-GAP MIXER -- generated by tools/gg/patch_dma.py.",
            "; Modified translation, NOT byte-identical to any QTM release.",
            "; Requires samples prepared by tools/prep; without a guard it",
            "; reads past the loop end.", ""]
    out = variants.src_dir(a.variant) / "qtm_dma.asm"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text("\n".join(head + lines), encoding="utf-8", newline="\n")

    # vasm resolves .include relative to the including file's own directory
    # before it consults -I, so an overlay is invisible while the top-level
    # file still sits in src/shared/.  Copy it next to the overlay; anything
    # not overlaid still falls back to src/shared/ via -I.
    top = variants.src_dir(a.variant) / "qtm.asm"
    top.write_bytes((variants.shared_dir() / "qtm.asm").read_bytes())

    print("patch_dma: %d wraps removed, %d records retimed, %d fixup -> %s"
          % (n_wrap, n_tab, n_fix, out))
    return 0


if __name__ == "__main__":
    sys.exit(main())
