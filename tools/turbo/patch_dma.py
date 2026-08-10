#!/usr/bin/env python3
"""Produce the QTM Turbo mixer by patching the generated qtm_dma.asm.

Turbo is Steve Harrison's idea: stop writing the DMA buffer a byte at a time.
QTM interleaves four channels into one buffer -- channel c lives at buf[c],
buf[c+4], ... -- so the four bytes of every word belong to four different
channels.  Today each is written by its own `STRB` from its own pass over the
buffer.  Turbo mixes all four channels in one interleaved loop, ORs them into
a register, and writes one `STR` per four bytes.

Measured at **-24.8 %** against the any-volume path in `tools/bench`
(MEASUREMENTS.md step 5).  Almost none of that is instruction count -- a
clock-count model says -15.6 %.  It is bus traffic: four write cycles become
one, and one sequential pass over the buffer replaces four strided ones.

This builds on top of the guard gap (`tools/gg`), which is a hard prerequisite
rather than an optional extra -- see OPTIMISATION.md 3.2.4.  A per-byte wrap
would cost both an instruction and a live register *per channel*, and Turbo has
neither to spare.  So the gg patch is applied first, in full.

The design (OPTIMISATION.md 3.2.4a) turns on three facts, all of which make the
job smaller than the original analysis assumed:

  * **The loop is static.**  `dma` is 208 and the unroll factor is 26, both
    fixed, so the packed body is simply assembled in -- 468 instructions.
    QTM's `unroll_code` machinery is not involved and there is no per-tick code
    generation.  The only runtime patching is 104 volume immediates, and only
    for a lane whose volume actually changed.

  * **The dispatch disappears via a silence word.**  `tools/prep` reserves bank
    offset 0 as four zero bytes.  A dead or silenced channel is pointed there
    with an increment of 0: the pointer never moves, every read returns 0x00,
    and `SUBS`/`ORRPL` contributes nothing to its lane.  This is what makes one
    interleaved loop possible at all -- a quarter of channel-fills are dead
    channels (MEASUREMENTS.md Result 3) and one loop cannot branch four ways.

  * **`a2_chanctrl` already computes everything Turbo needs** -- base address,
    offset, increment and log volume.  Its eight `LDR{cond} PC,jmp_a2_*`
    dispatch sites become returns instead, and the offset for the next fill is
    the value chanctrl has *already* worked out in R6 to decide whether the
    sample ends.  With the guard gap that value needs no per-byte wrap, only
    the once-per-fill normalisation gg installs at the top of chanctrl.

Two things Turbo does not do, both deliberate:

  * **Four channels only.**  It packs exactly four lanes into a word; with any
    other `chans_use` the handler returns without filling.  Guarded, not
    assumed.
  * **No transparent-sound path.**  `a2_TRNSchannels` also calls a2_chanctrl,
    expecting it to fill.  Under Turbo it no longer does, so that path is
    silent.  It is not on the route being measured.

**This build only works against samples prepared by tools/prep**, and needs the
bank base poked into `turbo_bank` at load time -- the last three words of
`a2_jumptable` are its offset, the loop's, and the loop's end, so the harness
can find all three from the debug SWI.

Usage:
    patch_dma.py [--variant turbo]
"""
import argparse
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent))
import variants                                                 # noqa: E402
sys.path.insert(0, str(HERE.parent / "gg"))
import patch_dma as gg                                          # noqa: E402

WORDS = 26          # output words per unrolled iteration; 208 / 26 = 8 passes
WORDLEN = 18 * 4    # bytes of one packed word body

# The eight dispatch sites, in source order, and what each becomes.  Keyed by
# the jump-table symbol so a change to the generated file cannot silently
# match the wrong line.
DISPATCH = [
    ("jmp_a2_endfullvol",  "LDREQ", "\tBEQ\tturbo_ret_fullvol"),
    ("jmp_a2_endanyvol",   "LDR",   "\tB\tturbo_ret"),
    ("jmp_a2_repnovol",    "LDRGE", "\tBGE\tturbo_ret_silent"),
    ("jmp_a2_repfullvol",  "LDREQ", "\tBEQ\tturbo_ret_repfullvol"),
    ("jmp_a2_repanyvol",   "LDR",   "\tB\tturbo_ret_repanyvol"),
    ("jmp_a2_clearing",    "LDR",   None),      # rewritten as a silent return
    ("jmp_a2_fullvolume",  "LDREQ", "\tBEQ\tturbo_ret_fullvol"),
    ("jmp_a2_anyvolume",   "LDR",   "\tB\tturbo_ret"),
]

CLEARING = """\tMOV	R0,#0                                           ;turbo: bank offset 0 is the silence word...
	MOV	R2,#0                                           ;...and a zero increment never leaves it
	MOV	R3,#0
	LDMFD	R13!,{R6,PC}^"""

# a2_chanend's first exit -- the channel has "really ended", so stock QTM
# writes nothing at all for it and relies on the buffer already being zero.
# Turbo always fills all four lanes, so it needs the silence parameters here
# too.  Plain MOVs, so the flags the LDMCSFD tests are untouched.
CHANEND = """	MOV	R0,#0                                           ;turbo: silence this lane
	MOV	R2,#0
	MOV	R3,#0
"""

TURBO = """
; ===========================================================================
; QTM Turbo -- one interleaved, lane-packed mixer for all four channels.
; Generated by tools/turbo/patch_dma.py.  See OPTIMISATION.md 3.2.4.
;
; QTM's DMA buffer already interleaves the channels a byte apart, so the four
; bytes of a word are the four channels' contributions to the same instant.
; Turbo builds that word in a register and stores it once, instead of four
; strided STRBs from four separate passes.
; ===========================================================================

turbo_DMAsound:
	LDRB	R5,[R9,#chans_use]
	CMP	R5,#4                                           ;Turbo packs exactly four lanes into a word
	LDMNEFD	R13!,{PC}                                   ;anything else: no fill (see the header comment)
	ADD	R8,R9,#DMA_blocks - song_data
	LDR	R4,[R9,#chanendflags]
	MOVS	R6,#0                                          ;put channel count as 0
	MOVS	R6,R6,LSL #1                                   ;(move 0>>1 - clear C flag)
turbo_chanloop:                                      ;relys on C flag CLEAR at this point!!!
	BL	a2_chanctrl                                     ;-> R0=20.12 bank offset, R1=next offset, R2=inc, R3=vol
	STRCC	R1,[R8,#DMA_offset]
	ADR	R14,turbo_acc
	STR	R0,[R14,R6,LSL #2]
	ADD	R14,R14,#turbo_inc - turbo_acc
	STR	R2,[R14,R6,LSL #2]
	ADD	R14,R14,#turbo_vol - turbo_inc
	STR	R3,[R14,R6,LSL #2]
	MOV	R4,R4,LSR #2
	ADD	R8,R8,#0x18
	ADD	R6,R6,#1
	CMP	R6,R5                                           ;this will CLEAR the C flag if R6-R5 < 0 (all the time)!
	BNE	turbo_chanloop
	BL	turbo_fill
	LDMFD	R13!,{PC}


	; The eight dispatch sites in a2_chanctrl arrive here instead of jumping
	; into an unrolled mixer.  Everything Turbo needs is already in hand:
	; R0 (or R4, repeating) is the sample end, R1 the negative offset into it,
	; R2 the increment, R3 the log volume, and R6 the offset after this fill --
	; which chanctrl computed to decide whether the sample ends, and which the
	; guard gap makes correct without a per-byte wrap.

turbo_ret_fullvol:
	MOV	R3,#0                                           ;full volume subtracts nothing
	B	turbo_ret
turbo_ret_repfullvol:
	MOV	R3,#0
turbo_ret_repanyvol:
	MOV	R0,R4                                           ;a repeat indexes from the repeat address...
	STR	R4,[R8,#DMA_address]                            ;...which becomes the DMA address from now on
	B	turbo_ret
turbo_ret_silent:                                    ;repeat, but the volume is below audible
	STR	R4,[R8,#DMA_address]
	MOV	R0,#0                                           ;the silence word...
	MOV	R2,#0                                           ;...which a zero increment never leaves
	MOV	R3,#0
	MOV	R1,R6
	LDMFD	R13!,{R4-R6,R12,PC}^
turbo_ret:
	LDR	R14,turbo_bank
	SUB	R14,R0,R14                                      ;sample end, relative to the bank
	ADD	R0,R1,R14,LSL #0xC                              ;...plus QTM's negative offset = absolute 20.12
	MOV	R1,R6                                           ;offset after this fill, for the caller to store
	LDMFD	R13!,{R4-R6,R12,PC}^


	.p2align 2
turbo_acc:
	.long	0,0,0,0                                       ;20.12 bank offsets, one per lane
turbo_inc:
	.long	0,0,0,0                                       ;...and their increments; loaded as one LDMIA
turbo_vol:
	.long	0,0,0,0
turbo_lastvol:
	.long	-1,-1,-1,-1                                   ;impossible, so the first fill patches every lane
turbo_bank:
	.long	0                                             ;sample bank base -- set by the loader
turbo_subs_op:
	SUBS	R11,R11,#0                                    ;patch template, never executed


turbo_fill:
	STMFD	R13!,{R0-R12,R14}
	; Volume is not a register: it is an immediate inside the loop, patched
	; when it changes.  QTM's log volume is 0-255, exactly an 8-bit immediate
	; with no rotation, so the whole range fits.  ARM2 has no cache, so a
	; store into the loop below is live on the next fetch.
	ADR	R11,turbo_vol
	ADD	R10,R11,#turbo_lastvol - turbo_vol
	LDR	R12,turbo_subs_op
	ADR	R14,turbo_loop
	MOV	R4,#0
turbo_vlane:
	LDR	R1,[R11,R4,LSL #2]
	LDR	R2,[R10,R4,LSL #2]
	CMP	R1,R2
	BEQ	turbo_vnext                                     ;unchanged, which is the common case
	STR	R1,[R10,R4,LSL #2]
	ORR	R1,R12,R1                                       ;-> SUBS R11,R11,#vol
	ADD	R2,R14,R4,LSL #4                                ;lane L is 4 instructions further into the word...
	ADD	R2,R2,#8                                        ;...past the MOV and its own LDRB
	MOV	R3,#turbo_words
turbo_vsite:
	STR	R1,[R2],#turbo_wordlen
	SUBS	R3,R3,#1
	BGT	turbo_vsite
turbo_vnext:
	ADD	R4,R4,#1
	CMP	R4,#4
	BLT	turbo_vlane
	MOV	R14,R9                                          ;song_data, wanted back after R9 is reused
	ADR	R0,turbo_acc
	LDMIA	R0,{R1-R8}                                    ;acc0-3 then inc0-3, in one load
	LDR	R0,turbo_bank
	LDR	R9,[R14,#DMABuffer]
	ADD	R12,R9,#dma * 4
turbo_loop:
	.rept turbo_words
	MOV	R10,#0
	LDRB	R11,[R0,R1,LSR #0xC]
	SUBS	R11,R11,#0                                    ;<- patched: lane 0 volume
	ORRPL	R10,R10,R11                                   ;PL both clamps and packs, in one instruction
	ADD	R1,R1,R5
	LDRB	R11,[R0,R2,LSR #0xC]
	SUBS	R11,R11,#0                                    ;<- patched: lane 1 volume
	ORRPL	R10,R10,R11,LSL #8
	ADD	R2,R2,R6
	LDRB	R11,[R0,R3,LSR #0xC]
	SUBS	R11,R11,#0                                    ;<- patched: lane 2 volume
	ORRPL	R10,R10,R11,LSL #0x10
	ADD	R3,R3,R7
	LDRB	R11,[R0,R4,LSR #0xC]
	SUBS	R11,R11,#0                                    ;<- patched: lane 3 volume
	ORRPL	R10,R10,R11,LSL #0x18
	ADD	R4,R4,R8
	STR	R10,[R9],#4                                     ;one write cycle where there were four
	.endr
	CMP	R9,R12
	BLT	turbo_loop
	LDMFD	R13!,{R0-R12,PC}
turbo_end:

; ===========================================================================
"""

HEAD = ["; QTM TURBO MIXER -- generated by tools/turbo/patch_dma.py.",
        "; Modified translation, NOT byte-identical to any QTM release.",
        "; Requires samples prepared by tools/prep, and the bank base poked",
        "; into turbo_bank at load time.  Four channels only.",
        ""]


def find(lines, pred, what):
    try:
        return next(n for n, l in enumerate(lines) if pred(l))
    except StopIteration:
        raise SystemExit("patch_dma: no %s" % what)


def replace_dmasound(lines):
    """Swap a2_DMAsound's per-channel loop for a branch to the Turbo one.

    Everything from `ADD R8,R9,#DMA_blocks` to the routine's `LDMFD R13!,{PC}`
    goes: the channel loop moves into the Turbo block so it can reach the lane
    parameter block with a plain ADR.  The prologue stays put because the DMA
    entry vector patches point at it.
    """
    top = find(lines, lambda l: l.startswith("a2_DMAsnd_in:"), "a2_DMAsnd_in")
    i = find(lines[top:], lambda l: l.startswith("\tADD\tR8,R9,#DMA_blocks"),
             "DMA_blocks setup in a2_DMAsound") + top
    j = find(lines[i:], lambda l: l.startswith("\tLDMFD\tR13!,{PC}"),
             "end of a2_DMAsound") + i
    lines[i:j + 1] = ["\tB\tturbo_DMAsound                                    "
                      ";turbo: one packed loop for all four channels"]
    return j + 1 - i


def replace_dispatch(lines):
    """Turn the eight mixer jumps into returns.

    Matched on the jump-table symbol rather than by position, and the whole
    list is checked to be in the expected order, so a regenerated qtm_dma.asm
    cannot quietly wire a site to the wrong handler.  The `.if alphatest`
    counter blocks in front of each site are left alone: the path distribution
    stays measurable and directly comparable with alpha and gg.
    """
    seen = []
    for n, line in enumerate(lines):
        m = re.match(r"^\t(LDR|LDREQ|LDRGE)\tPC,(jmp_a2_\w+)", line)
        if m:
            seen.append((n, m.group(2), m.group(1)))
    if [s for _, s, _ in seen] != [s for s, _, _ in DISPATCH]:
        raise SystemExit("patch_dma: dispatch sites are %s, expected %s"
                         % ([s for _, s, _ in seen], [s for s, _, _ in DISPATCH]))
    for (n, sym, cond), (_, want_cond, new) in zip(seen, DISPATCH):
        if cond != want_cond:
            raise SystemExit("patch_dma: %s is %s, expected %s"
                             % (sym, cond, want_cond))
        if new is None:                     # a2_clearchannel
            lines[n] = CLEARING
        else:
            lines[n] = new + "                                          ;turbo"
    return len(seen)


def silence_chanend(lines):
    """Give a2_chanend's really-ended exit the silence parameters."""
    top = find(lines, lambda l: l.startswith("a2_chanend:"), "a2_chanend")
    i = find(lines[top:], lambda l: l.startswith("\tLDMCSFD\tR13!,{R4-R6,R12,PC}"),
             "a2_chanend really-ended exit") + top
    lines[i:i] = CHANEND.rstrip("\n").split("\n")
    return 1


def add_block(lines):
    """Drop the Turbo block in after a2_chanend, and publish its addresses.

    The three words appended to a2_jumptable are turbo_bank, turbo_loop and
    turbo_end as offsets *from the jump table itself*.  The harness already
    gets the jump table's address from the alpha debug SWI, so it can reach all
    three by addition alone -- no module base, and none of the hardcoded
    listing offsets that sent one step-1 measurement at the wrong address.
    """
    top = find(lines, lambda l: l.startswith("a2_chanend:"), "a2_chanend")
    i = find(lines[top:], lambda l: l.startswith("\tLDMFD\tR13!,{R4-R6,R12,PC}^"),
             "end of a2_chanend") + top
    lines[i + 1:i + 1] = ([".equ turbo_words,%d" % WORDS,
                           ".equ turbo_wordlen,%d" % WORDLEN]
                          + TURBO.split("\n"))
    j = find(lines, lambda l: l.startswith("\t.long\t0")
             and "terminate with 0-word" in l, "jump table terminator")
    lines[j + 1:j + 1] = [
        "\t.long\tturbo_bank - a2_jumptable                      "
        ";turbo: relative to here, for the loader...",
        "\t.long\tturbo_loop - a2_jumptable                      "
        ";...and for the profiling range",
        "\t.long\tturbo_end - a2_jumptable"]
    return 1


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--variant", default="turbo")
    a = ap.parse_args()

    src = variants.shared_dir() / "qtm_dma.asm"
    lines = src.read_text(encoding="utf-8").split("\n")

    # The guard gap first, in full: Turbo cannot afford the per-byte wrap's
    # instruction or its per-channel repeat-length register.
    n_wrap = gg.strip_wraps(lines)
    gg.retime_table(lines)
    gg.add_fixup(lines)

    n_ds = replace_dmasound(lines)
    n_disp = replace_dispatch(lines)
    silence_chanend(lines)
    add_block(lines)

    out = variants.src_dir(a.variant) / "qtm_dma.asm"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text("\n".join(HEAD + lines), encoding="utf-8", newline="\n")

    # vasm resolves .include relative to the including file's own directory
    # before it consults -I, so the overlay is invisible while the top-level
    # file still sits in src/shared/.
    top = variants.src_dir(a.variant) / "qtm.asm"
    top.write_bytes((variants.shared_dir() / "qtm.asm").read_bytes())

    print("patch_dma: guard gap (%d wraps), %d lines of a2_DMAsound replaced, "
          "%d dispatch sites returned, %d-word packed loop -> %s"
          % (n_wrap, n_ds, n_disp, WORDS, out))
    return 0


if __name__ == "__main__":
    sys.exit(main())
