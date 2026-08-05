#!/usr/bin/env python3
"""Table-driven converter: detokenised BBC BASIC assembler -> vasm ARM (Phase 1).

Scope is deliberately mechanical.  Anything requiring judgement -- the macro
functions, the frozen data blocks -- is left for later phases and reported
rather than guessed at.  Run tools/checkfile.py afterwards to diff the result
against the golden listing; do not trust the output of this on its own.

Usage:
    bas2vasm.py <QTM_Timer.bas> [-o out.asm]
"""
import argparse
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import basexpr
import dumpsyms

LINENO = re.compile(r"^\s*\d+ ?")

SHIFTS = ("LSL", "LSR", "ASR", "ROR")

# Directives that map one-for-one.
DATA_DIRECTIVES = {
    "EQUD": (".long", 4), "DCD": (".long", 4),
    "EQUW": (".short", 2), "DCW": (".short", 2),
    "EQUB": (".byte", 1), "DCB": (".byte", 1),
}


class Unhandled(Exception):
    pass


# DEF blocks that assemble nothing into the module.  PROCinit_offsets runs a
# throwaway pass into a scratch buffer purely to compute offsets, and
# FNtableoffsets describes the runtime workspace layout rather than module
# content -- none of its labels appear in the golden listing.  Both are owned
# by tools/dumpsyms.py, which turns them into src/qtm_offsets.h.asm.
SKIP_DEFS = {"PROCinit_offsets", "FNtableoffsets"}

# FN calls that splice in another source file rather than expanding a macro.
FN_INCLUDES = {
    "FNtimercode": "qtm_timer.asm",
    "FNvucode": "qtm_vucode.asm",
    # PROCassm's body is the module's table of contents: these calls are what
    # fixes the layout order (Mod, Play, Song, DMA, inline driver code, Data).
    "FNassm_mod": "qtm_mod.asm",
    "FNassm_main": "qtm_play.asm",
    "FNassm_initsong": "qtm_song.asm",
    "FNassm_dma": "qtm_dma.asm",
    "FNassm_tables": "qtm_data.asm",
}

# Regions the original patches *after* assembly, in PROCvalidatecrc.  Because
# betatest%=TRUE the module always gets stamped, so what the EQUS assembles is
# not what ships (PLAN.md 0.4).  These are the bytes observed in ref/QTMModule,
# frozen rather than reproduced: the patch reads MID$(TIME$,5,11), so a build
# today would differ.  Each replaces the next EQUS after the named label.
#
#   helpdate         the leading " (" becomes "b (" -- $(code%+helpdate) is
#                    rewritten, then code%?helpdate=ASC"b" for the beta build
#   helptextversion  "v"+ver$ is written at +8 and the beta letter at +13,
#                    which consumes one of the six CHR$31 padding bytes
POST_PATCH = {
    "helpdate": b"b (19 Mar 2023) \xa9 Steve Harrison",
    "helptextversion":
        b"|\t\t\x1f\x1f\x1f\x1f\x1fv1.49b \xa9 1993-2023 Steve Harrison"
        b"\t\t\t\x1f\x1f\x1f|\r",
}

# Blocks reserved with "P%+=n" and filled in after assembly, which therefore
# hold real data in the shipped module rather than the zeros the reservation
# implies.  Keyed by the label that immediately precedes the reservation.
POST_FILL = {
    "loglintab": ('.incbin "LOGdata"',
                  "OSCLI \"Load ... LOGdata\" in the driver"),
    "amigaperiodz": ('.include "qtm_amiperiods.asm"',
                     "PROCinit_amiperiods writes here after assembly"),
}

# Build-time BASIC variables.  ver$ and dmachoice come from the driver; date$
# is frozen to the shipped module's date rather than today's, because
# betatest%=TRUE makes the original stamp the build date (see PLAN.md 0.4).
STRING_ENV = {
    "ver$": "1.49",
    "date$": "19 Mar 2023",
    "datestamp$": "14:54:39 19 Mar 2023",
}


# ------------------------------------------------------- hand-encoded PSR/CP

# FNmrs/FNmsr/FNmrc/FNmcr exist because the 1993 BASIC assembler had no ARMv3
# PSR or coprocessor mnemonics, so they build the word by hand and poke it into
# memory.  That is also why they never appear in the golden listing -- they
# bypass [OPT entirely.  These are emitted as .long rather than as vasm
# mnemonics: letting vasm re-encode them would add a byte-identity risk for no
# benefit (PLAN.md 2), and the bit layouts below are transcribed from the FNs.
CONDITIONS = ["EQ", "NE", "CS", "CC", "MI", "PL", "VS", "VC",
              "HI", "LS", "GE", "LT", "GT", "LE", "AL", "NV"]

MSR_FIELDS = {"c": 0x10000, "x": 0x20000, "s": 0x40000, "f": 0x80000}


def cond_code(text):
    text = text.strip().upper()
    if not text:
        text = "AL"
    if text not in CONDITIONS:
        raise Unhandled("bad condition %r" % text)
    return CONDITIONS.index(text)


def reg_num(text):
    m = re.match(r"^[Rr#]?(\d+)$", text.strip())
    if not m:
        raise Unhandled("bad register %r" % text)
    return int(m.group(1))


def encode_mrs(cond, operands):
    dest, psr = [p.strip() for p in operands.split(",")]
    if psr.upper() != "CPSR":
        raise Unhandled("MRS of %r" % psr)
    return cond_code(cond) << 28 | 0x010F0000 | reg_num(dest) << 12


def encode_msr(cond, operands):
    psr, src = [p.strip() for p in operands.split(",")]
    if not psr.upper().startswith("CPSR_"):
        raise Unhandled("MSR to %r" % psr)
    word = cond_code(cond) << 28 | 0x0120F000 | reg_num(src)
    for ch in psr[5:]:
        if ch not in MSR_FIELDS:
            raise Unhandled("bad MSR field %r" % ch)
        word |= MSR_FIELDS[ch]
    return word


def encode_mrc(cond, operands):
    parts = [p.strip() for p in operands.split(",")]
    if len(parts) < 5:
        raise Unhandled("MRC operands %r" % operands)
    cp = int(re.sub(r"(?i)^cp", "", parts[0]))
    opc1 = int(parts[1])
    rd = reg_num(parts[2])
    crn = int(re.sub(r"(?i)^c", "", parts[3]))
    crm = int(re.sub(r"(?i)^c", "", parts[4]))
    opc2 = int(parts[5]) if len(parts) > 5 else 0
    return (cond_code(cond) << 28 | 0x0E100010 | opc1 << 21 | crn << 16
            | rd << 12 | cp << 8 | opc2 << 5 | crm)


PSR_ENCODERS = {"FNmrs": encode_mrs, "FNmsr": encode_msr, "FNmrc": encode_mrc}


# ------------------------------------------------------------------ scanning

def split_statements(line):
    """Split a BASIC line into (statement, comment) pairs.

    ':' separates statements.  A ';' starts a comment, but that comment ends at
    the next ':' rather than at end of line -- the assembler consumes one
    statement at a time and ':' terminates the statement, comment and all.

    This is not a nicety.  QTM_Play line 1230 reads

        ;EQUD 0;EQUD 0:EQUD 0

    and the golden listing shows the comment printed as ";EQUD 0;EQUD 0" with a
    real EQUD 0 assembled at 0x4310 from the tail.  Treating ';' as running to
    end of line loses that word and shifts everything after it.
    """
    out, cur, comment, i, in_str = [], "", "", 0, False
    while i < len(line):
        c = line[i]
        if c == '"':
            in_str = not in_str
            cur += c
        elif not in_str and c == ";":
            end = line.find(":", i)
            if end < 0:
                out.append((cur.strip(), line[i:].rstrip()))
                return out
            comment = line[i:end].rstrip()
            out.append((cur.strip(), comment))
            cur, comment = "", ""
            i = end
            continue
        elif not in_str and c == ":":
            out.append((cur.strip(), comment))
            cur, comment = "", ""
        else:
            cur += c
        i += 1
    out.append((cur.strip(), comment))
    return out


# ---------------------------------------------------------------- expressions

# Constructs where BASIC and vasm disagree, so the value must be folded here
# rather than handed to vasm: bitwise word-operators (which truncate their
# operands first), float literals, and shifts (which bind looser than +/- in
# BASIC but tighter in vasm).
NEEDS_FOLD = re.compile(r"\bAND\b|\bOR\b|\bEOR\b|\bDIV\b|\bMOD\b|\bASC\b|<<|>>|\d\.\d")


def conv_expr(text, env):
    """Translate a BASIC expression, folding only where semantics differ.

    Anything vasm can compute identically is left symbolic, so the generated
    source still reads as offsets rather than a wall of magic numbers.
    """
    text = text.strip()
    if not text:
        return text
    if NEEDS_FOLD.search(text):
        try:
            value = basexpr.trunc(basexpr.evaluate(text, env))
        except Exception:
            pass
        else:
            # BASIC's integers are 32-bit and wrap; QTM_Mod has
            # "TST R0,#%1110<<29", which is 0x1C0000000 before truncation.
            # vasm reaches the same answer but warns, so wrap it here.
            if not -0x80000000 <= value < 0x80000000:
                value &= 0xFFFFFFFF
            return ("0x%X" % value) if abs(value) >= 10 else str(value)
    # Left symbolic: just fix the literal syntax.
    text = re.sub(r"&([0-9A-Fa-f]+)", r"0x\1", text)
    text = re.sub(r"%([01]+)", r"0b\1", text)
    text = re.sub(r"\bAND\b", "&", text)
    text = re.sub(r"\bOR\b", "|", text)
    text = re.sub(r"\bEOR\b", "^", text)
    # BASIC pads decimals with leading zeros to keep columns aligned
    # ("EQUB 049"); vasm rejects those.  Applied after the hex rewrite so the
    # digits inside 0x00FF are left alone.
    text = re.sub(r"(?<![\w.])0+(\d)", r"\1", text)
    return text


def conv_cond(text, env):
    """Translate an IF condition for vasm's .if.

    Kept symbolic rather than folded so the build switches survive into the
    source, which is what Phase 6's RasterMan variant needs.  BASIC's truth
    values are 0 and -1, and vasm's .if takes any non-zero as true, so a bare
    flag passes through; NOT and the comparison operators need rewriting.
    """
    text = text.strip()
    m = re.match(r"^NOT\s+(.*)$", text, re.I)
    if m:
        return "(%s) == 0" % m.group(1).strip().rstrip("%")
    text = text.replace("<>", "!=")
    text = re.sub(r"(?<![<>!=])=(?!=)", "==", text)
    text = re.sub(r"([A-Za-z_][A-Za-z0-9_]*)%", r"\1", text)
    text = re.sub(r"&([0-9A-Fa-f]+)", r"0x\1", text)
    # The flags are 0 / -1, so bitwise operators give the right answer and,
    # unlike && and ||, are what vasm's .if understands.
    text = re.sub(r"\bAND\b", "&", text)
    text = re.sub(r"\bOR\b", "|", text)
    return re.sub(r"\bEOR\b", "^", text)


def strip_outer_parens(text):
    """Remove parens wrapping a whole immediate.

    vasm's ARM backend rejects "#(a-b)" with "instruction not supported on
    selected architecture" while accepting "#a-b"; BASIC sources parenthesise
    freely, so strip the redundant pair.
    """
    text = text.strip()
    while text.startswith("(") and text.endswith(")"):
        depth = 0
        for i, c in enumerate(text):
            if c == "(":
                depth += 1
            elif c == ")":
                depth -= 1
                if depth == 0 and i != len(text) - 1:
                    return text           # parens do not wrap the whole thing
        text = text[1:-1].strip()
    return text


def split_operands(text):
    """Split on commas at bracket depth 0, ignoring commas inside strings.

    QTM_Mod has SWINE 256+ASC"," -- splitting that on the quoted comma breaks
    the operand in half.
    """
    parts, cur, depth, in_str = [], "", 0, False
    for c in text:
        if c == '"':
            in_str = not in_str
        if in_str:
            cur += c
            continue
        if c in "[{(":
            depth += 1
        elif c in "]})":
            depth -= 1
        if c == "," and depth == 0:
            parts.append(cur)
            cur = ""
        else:
            cur += c
    parts.append(cur)
    return parts


def conv_operand(part, env):
    part = part.strip()
    if not part:
        return part

    # [R12,#offset] / [R11,R6,LSL#2] -- recurse into the addressing mode.
    m = re.match(r"^\[(.*)\](!?)$", part, re.S)
    if m:
        inner = ",".join(conv_operand(p, env) for p in split_operands(m.group(1)))
        return "[%s]%s" % (inner, m.group(2))

    # Register lists pass through untouched.
    if part.startswith("{"):
        return part

    # "LSLR2" and "LSL R2" -> "LSL R2"; "LSL#12" -> "LSL #12".
    m = re.match(r"^(%s)\s*#(.*)$" % "|".join(SHIFTS), part, re.I)
    if m:
        return "%s #%s" % (m.group(1).upper(), conv_expr(m.group(2), env))
    m = re.match(r"^(%s)\s*(R\d+|PC|LR)$" % "|".join(SHIFTS), part, re.I)
    if m:
        return "%s %s" % (m.group(1).upper(), m.group(2).upper())
    if part.upper() == "RRX":
        return "RRX"

    if part.startswith("#"):
        value = strip_outer_parens(conv_expr(part[1:], env))
        # vasm's ARM backend cannot parse an immediate beginning with '(',
        # even when the parens do not wrap the whole expression, as in
        # "#(channeldata-song_data)-64".  Those are always constant here, so
        # fold them; readability is preserved by the source comment alongside.
        if value.startswith("("):
            try:
                folded = basexpr.trunc(basexpr.evaluate(part[1:], env))
            except Exception:
                pass
            else:
                value = ("0x%X" % folded) if abs(folded) >= 10 else str(folded)
        if value.startswith("("):
            # Still parenthesised, so it references labels and cannot be folded
            # here (e.g. "#(endSWItable-startSWItable)/4").  A leading "0+"
            # gets it past vasm's parser without changing the value.
            value = "0+" + value
        return "#" + value

    # Bare register or shifted register with no immediate.
    if re.match(r"^(R\d+|PC|LR|SP)!?$", part, re.I):
        return part.upper()
    return conv_expr(part, env)


# -------------------------------------------------------------------- strings

def eval_string(text, env):
    """Evaluate a BASIC string expression to bytes.

    Handles the forms actually present: literals, '+', CHR$<expr> and
    STRING$(n,<expr>).  FNcompress is refused here; those 26 sites come from
    the frozen ref/helptext.txt (Phase 3), not from re-running the compressor.
    """
    if "FNcompress" in text:
        raise Unhandled("FNcompress site -- use frozen ref/helptext.txt")
    out = bytearray()
    i = 0
    text = text.strip()
    while i < len(text):
        c = text[i]
        if c == " " or c == "+":
            i += 1
            continue
        if c == '"':
            j = text.index('"', i + 1)
            out += text[i + 1:j].encode("latin-1")
            i = j + 1
            continue
        m = re.match(r"[A-Za-z_][A-Za-z0-9_]*\$", text[i:])
        if m and m.group() in STRING_ENV:
            out += STRING_ENV[m.group()].encode("latin-1")
            i += m.end()
            continue
        m = re.match(r"STR\$\s*", text[i:])
        if m:
            i += m.end()
            expr, i = read_arg(text, i, text[i:i + 1] == "(")
            out += str(basexpr.trunc(basexpr.evaluate(expr, env))).encode("latin-1")
            continue
        m = re.match(r"CHR\$\s*(\(?)", text[i:])
        if m:
            i += m.end()
            expr, i = read_arg(text, i, m.group(1) == "(")
            out.append(basexpr.trunc(basexpr.evaluate(expr, env)) & 0xFF)
            continue
        m = re.match(r"STRING\$\s*\(", text[i:])
        if m:
            i += m.end()
            args, i = read_args(text, i)
            n = basexpr.trunc(basexpr.evaluate(args[0], env))
            out += eval_string(args[1], env) * n
            continue
        raise Unhandled("string expression %r" % text)
    return bytes(out)


def read_arg(text, i, bracketed):
    if bracketed:
        depth, start = 1, i
        while depth:
            if text[i] == "(":
                depth += 1
            elif text[i] == ")":
                depth -= 1
                if depth == 0:
                    return text[start:i], i + 1
            i += 1
    m = re.match(r"[0-9&%A-Za-z_]+", text[i:])
    return m.group(), i + m.end()


def read_args(text, i):
    args, cur, depth, in_str = [], "", 1, False
    while i < len(text):
        c = text[i]
        if c == '"':
            in_str = not in_str
        if not in_str:
            if c in "([":
                depth += 1
            elif c in ")]":
                depth -= 1
                if depth == 0:
                    args.append(cur)
                    return args, i + 1
            elif c == "," and depth == 1:
                args.append(cur)
                cur = ""
                i += 1
                continue
        cur += c
        i += 1
    raise Unhandled("unterminated argument list")


def emit_bytes(data):
    """Render bytes as .byte, keeping printable runs readable."""
    parts, run = [], ""
    for b in data:
        if 32 <= b < 127 and b != 34 and b != 92:
            run += chr(b)
        else:
            if run:
                parts.append('"%s"' % run)
                run = ""
            parts.append("0x%02X" % b)
    if run:
        parts.append('"%s"' % run)
    return parts


# ------------------------------------------------------------------ translate

class Converter:
    def __init__(self, env):
        self.env = env
        self.out = []
        self.notes = []
        self.cond_stack = []
        self.mode = "basic"
        self.current_def = None
        self.block_depth = 0
        self.pending_data = False
        self.pending_labels = []
        # Whether the code currently being emitted is part of *this* build.
        # Sites inside a false conditional were never assembled by the
        # original, so there is nothing in the listing to match them against.
        self.active_stack = []
        self.golden_labels = {}
        self.adr_sites = []
        self.adr_count = 0
        self.prefix = "L"
        self.last_label = None
        self.patch_pending = None
        self.frozen_help = {}

    def active(self):
        return all(self.active_stack)

    def push_cond(self, basic_cond):
        try:
            self.active_stack.append(bool(basexpr.evaluate(basic_cond, self.env)))
        except Exception:
            self.active_stack.append(True)

    def note(self, lineno, message, text):
        self.notes.append((lineno, message, text))
        self.out.append("\t; TODO(%d): %s -- %s" % (lineno, message, text))

    def flush_labels(self):
        """Emit labels held back while waiting to see whether code follows."""
        for name, comment in self.pending_labels:
            self.out.append("%-52s %s" % (name + ":", comment) if comment
                            else name + ":")
        self.pending_labels = []

    def emit(self, text, comment=""):
        if comment:
            self.out.append("%-52s %s" % (text, comment))
        else:
            self.out.append(text)

    # -- assembly statements

    def asm_statement(self, stmt, comment, lineno):
        if not stmt:
            if comment:
                self.emit("\t" + comment)
            return

        # Label, possibly sharing its line with a directive.
        m = re.match(r"^\.([A-Za-z_][A-Za-z0-9_]*%?)(.*)$", stmt)
        if m:
            name = m.group(1).rstrip("%")
            rest = m.group(2).strip()
            self.last_label = name
            if name in POST_PATCH:
                self.patch_pending = name
            # A label sitting between data and code needs the alignment padding
            # emitted *before* it, not after.  In the original, err_cmddisable
            # lands at the unaligned 0x0A02 while its first instruction is at
            # 0x0A04, and BASIC rounds branch destinations up to the next word
            # (BVS at 0x09D8 encodes offset 9, i.e. target 0x0A04).  Putting
            # the label after the padding reproduces that, and vasm will not
            # accept a branch to an unaligned label at all.  Data labels are
            # unaffected: they are followed by more data, so no align is due.
            if self.pending_data:
                self.pending_labels.append((name, comment if not rest else ""))
                if rest:
                    self.asm_statement(rest, comment, lineno)
                return
            if rest:
                self.emit(name + ":")
                self.asm_statement(rest, comment, lineno)
            else:
                self.emit(name + ":", comment)
            return

        # Split on the mnemonic itself rather than on whitespace: the sources
        # contain EQUS"..." with no separator, and the string may start with a
        # tab, which str.split would swallow.
        # The data directives may run straight into their operand with no
        # separator -- the period tables are written "DCW1712:DCW1616:..." --
        # so match those names explicitly before falling back to the general
        # rule, which would otherwise read "DCW1712" as one identifier.
        head = (re.match(r"^(EQU[BWDS]|DC[BWDS])\s*(.*)$", stmt, re.I | re.S)
                or re.match(r"^([A-Za-z][A-Za-z0-9_]*)(.*)$", stmt, re.S))
        if not head:
            self.note(lineno, "unparsed statement", stmt)
            return
        mnemonic = head.group(1).upper()
        rest = head.group(2).strip()

        if mnemonic == "ALIGN":
            self.flush_labels()
            self.emit("\t.p2align 2", comment)
            self.pending_data = False
            return
        if mnemonic == "OPT":
            return
        if mnemonic in ("EQUS", "DCS"):
            self.flush_labels()
            self.data_string(rest, comment, lineno)
            self.pending_data = True
            return
        if mnemonic in DATA_DIRECTIVES:
            self.flush_labels()
            directive, _ = DATA_DIRECTIVES[mnemonic]
            values = [conv_expr(p, self.env) for p in split_operands(rest)]
            self.emit("\t%s\t%s" % (directive, ",".join(values)), comment)
            self.pending_data = True
            return
        # Everything from here on emits code.  BBC BASIC's assembler word-aligns
        # before assembling an instruction but not before data, so "EQUS ...17
        # bytes..." followed by a SWI puts the SWI on the next word boundary
        # with no ALIGN in the source (QTM_Mod line 599: 0x6C4 + 17 = 0x6D5,
        # SWI at 0x6D8).  Labels do not trigger it -- 42 labels in the module
        # sit at unaligned addresses inside string tables.
        if self.pending_data:
            self.emit("\t.p2align 2")
            self.pending_data = False
        self.flush_labels()

        if stmt in FN_INCLUDES:
            self.emit('\t.include "%s"' % FN_INCLUDES[stmt], comment)
            return
        m = re.match(r'^(FN\w+)\("([^"]*)","(.*)"\)$', stmt)
        if m and m.group(1) in PSR_ENCODERS:
            try:
                word = PSR_ENCODERS[m.group(1)](m.group(2), m.group(3))
            except Unhandled as exc:
                self.note(lineno, str(exc), stmt)
                return
            self.emit("\t.long\t0x%08X" % word,
                      comment or "; %s" % stmt)
            return

        m = re.match(r'^FNlong_adr\("([^"]*)",(\d+),(\w+)\)$', stmt)
        if m:
            self.long_adr(m.group(1), int(m.group(2)), m.group(3),
                          comment, lineno, stmt)
            return

        if mnemonic.startswith("FN"):
            self.note(lineno, "macro call (Phase 2)", stmt)
            return
        if mnemonic.startswith("SWI"):
            m = re.match(r'^"([^"]+)"$', rest)
            if m:
                self.emit("\t%s\t%s" % (mnemonic, m.group(1)), comment)
                return

        operands = ",".join(conv_operand(p, self.env) for p in split_operands(rest))
        if operands:
            self.emit("\t%s\t%s" % (mnemonic, operands), comment)
        else:
            self.emit("\t%s" % mnemonic, comment)

    def long_adr(self, cond, reg, target, comment, lineno, stmt):
        """Expand FNlong_adr into the ADD/SUB-from-PC pair it generates.

        The direction comes from the golden listing, because it cannot be
        decided here (addresses are not known) nor deferred to vasm (its .if
        resolves a not-yet-seen label to 0).  Consuming the listing's sites in
        address order matches them to the calls in source order; the gap each
        one encodes is checked against the target label's address, so a
        mis-pairing is caught rather than silently emitted.
        """
        if not self.active():
            # Excluded from this build (a RasterMan-only path), so the original
            # never assembled it and there is no site to match against.
            self.note(lineno, "FNlong_adr in an excluded block (Phase 6)", stmt)
            return
        if not self.adr_sites:
            self.note(lineno, "no FNlong_adr site left in the listing", stmt)
            return

        addr, word1, word2 = self.adr_sites.pop(0)
        is_sub = (word1 & 0x02F00000) == 0x02400000
        gap = (word1 & 0xFF) | ((word2 & 0xFF) << 8)

        want = self.golden_labels.get(target)
        if want is None:
            self.note(lineno, "FNlong_adr target %r not in listing" % target, stmt)
            return
        expect = (addr + 8 - want) if is_sub else (want - addr - 8)
        if expect != gap or ((word1 >> 12) & 0xF) != reg:
            self.note(lineno, "FNlong_adr site 0x%04X does not match target %s "
                              "(gap 0x%X vs 0x%X)" % (addr, target, gap, expect), stmt)
            return

        tag = "%s_adr%d" % (self.prefix, self.adr_count)
        self.adr_count += 1
        span = ("%s+8-%s" % (tag, target)) if is_sub else ("%s-%s-8" % (target, tag))

        # Emitted as .long, exactly as FNlong_adr does ("EQUD optcode1%"),
        # rather than as ADD/SUB mnemonics.  The second word always uses
        # rotate 12 with the high byte of the gap, and when that byte is a
        # multiple of 4 the same value has another valid encoding that vasm
        # prefers: for gap 0x5C3C it picked rotate 11 / imm 0x17 against the
        # original's rotate 12 / imm 0x5C.  Both mean 0x5C00, but only one is
        # byte-identical.  Composing the word here removes the choice.
        base = 0x02400000 if is_sub else 0x02800000
        base |= cond_code(cond) << 28 | reg << 12
        self.emit(tag + ":", comment or ("; " + stmt))
        self.emit("\t.long\t0x%08X+((%s)&0xFF)" % (base | 0xF << 16, span))
        self.emit("\t.long\t0x%08X+(((%s)&0xFF00)>>8)"
                  % (base | 0xC << 8 | reg << 16, span))

    def data_string(self, rest, comment, lineno):
        # A frozen post-assembly patch takes precedence over what the source
        # would have assembled here.
        if self.patch_pending:
            data = POST_PATCH[self.patch_pending]
            self.emit("\t.byte\t%s" % ",".join(emit_bytes(data)),
                      "; frozen post-assembly patch (%s)" % self.patch_pending)
            self.patch_pending = None
            return
        if lineno in self.frozen_help:
            text, data = self.frozen_help[lineno]
            self.emit("\t; %s" % text[:96])
            self.emit("\t.byte\t%s" % ",".join("0x%02X" % b for b in data),
                      "; frozen FNcompress output")
            return
        m = re.match(r"^STRING\$\((.*),CHR\$0\)$", rest.strip())
        if m and "," not in m.group(1):
            n = basexpr.trunc(basexpr.evaluate(m.group(1), self.env))
            self.emit("\t.skip\t%d" % n, comment)
            return
        try:
            data = eval_string(rest, self.env)
        except Exception as exc:
            self.note(lineno, str(exc), "EQUS " + rest)
            return
        self.emit("\t.byte\t%s" % ",".join(emit_bytes(data)), comment)

    # -- BASIC statements between ] and [OPT

    # BASIC scaffolding around the assembly: the REM header, the DEF FN
    # wrapper and its "=opt%" return.  Carries nothing into the output.
    # BASIC scaffolding: the REM header, the DEF FN wrapper and its return, the
    # DATA tables, and the buffer/loop bookkeeping around the assembly passes
    # (PROCassm allocates and zeroes code%, then runs FOR opt%=12 TO 14).
    SCAFFOLD = re.compile(
        r"^(REM\b|END$|DEF\s|=opt%$|ENDPROC$|DATA\b|DIM\s|LOCAL\s"
        r"|PRINT|FOR\s|NEXT\b|OSCLI|INPUT\b)", re.I)

    def basic_statement(self, stmt, comment, lineno):
        if not stmt or stmt == "]":
            return
        if self.SCAFFOLD.match(stmt):
            return
        # A held label must come out before anything a BASIC statement emits:
        # ".amigaperiodz" is immediately followed by "]:P%+=4608/2", and the
        # label belongs at the start of that reserved block, not after it.
        # pending_data is left set, since BASIC does not align before data.
        self.flush_labels()

        # Single-line form: ]:IF cond THEN [OPT opt%: ... :]
        # The closing ] ends the conditional, so remember to emit .endif there.
        m = re.match(r"^IF\s+(.*?)\s+THEN\s*\[OPT\s+opt%$", stmt, re.I)
        if m:
            self.emit("\t.if %s" % conv_cond(m.group(1), self.env))
            self.cond_stack.append(True)
            self.push_cond(m.group(1))
            self.mode = "asm"
            return

        # Block form: ]:IF cond THEN / [OPT opt% ... ] / ELSE / ... / ENDIF.
        # Here ENDIF closes it, so nothing is pushed.
        m = re.match(r"^IF\s+(.*?)\s+THEN$", stmt, re.I)
        if m:
            self.emit("\t.if %s" % conv_cond(m.group(1), self.env))
            self.block_depth += 1
            self.push_cond(m.group(1))
            return
        if re.match(r"^ELSE$", stmt, re.I):
            if self.block_depth:
                self.emit("\t.else")
                if self.active_stack:
                    self.active_stack[-1] = not self.active_stack[-1]
            return
        if re.match(r"^ENDIF$", stmt, re.I):
            # BBC BASIC treats an ENDIF with no open block as a no-op, and
            # QTM_Song line 847 has exactly that.  Emitting .endif for it
            # would unbalance the output and fail to assemble.
            if self.block_depth:
                self.block_depth -= 1
                if self.active_stack:
                    self.active_stack.pop()
                self.emit("\t.endif")
            else:
                self.emit("\t; (stray ENDIF in source -- a no-op in BASIC)")
            return

        # IF cond THEN <assign> ELSE <assign> -- a build-time variable, not
        # emitted code, so resolve it here and fold the result into the env.
        m = re.match(r"^IF\s+(.*?)\s+THEN\s+(.*?)(?:\s+ELSE\s+(.*))?$", stmt, re.I)
        if m and "=" in m.group(2):
            try:
                taken = basexpr.evaluate(m.group(1), self.env)
            except Exception:
                self.note(lineno, "conditional needs review", stmt)
                return
            branch = m.group(2) if taken else m.group(3)
            if branch:
                self.basic_statement(branch.strip(), "", lineno)
            return

        # Offset-assembly bookkeeping with no vasm equivalent: P%/O%/L% set the
        # origin, the output pointer and the buffer limit (.org and -Fbin cover
        # all three), and "!c=0" is the loop that pre-zeroes the 63K buffer.
        # Checked before the general assignment rule, which would match these.
        # "P%+=n" is NOT included here: it reserves space and is handled above,
        # sometimes as a data fill.  Only the plain assignments are bookkeeping.
        if re.match(r"^([OL]%\s*\+?=|P%\s*=)", stmt) or re.match(r"^[!?]\w+\s*=", stmt):
            return

        # Plain assignment to a build-time variable.
        m = re.match(r"^([A-Za-z_][A-Za-z0-9_]*%?)\s*=\s*(.+)$", stmt)
        if m:
            try:
                self.env[m.group(1).rstrip("%")] = basexpr.evaluate(m.group(2), self.env)
            except Exception:
                self.note(lineno, "assignment not constant", stmt)
            return

        m = re.match(r"^IF\s+(.*)$", stmt, re.I)
        if m:
            self.note(lineno, "conditional needs review", stmt)
            return
        if re.match(r"^\[OPT\s+opt%$", stmt, re.I):
            self.mode = "asm"
            return
        m = re.match(r"^P%\s*\+=\s*(.+)$", stmt)
        if m:
            n = basexpr.trunc(basexpr.evaluate(m.group(1), self.env))
            # Some of these reservations are filled in after assembly, so the
            # shipped module has data where the source reserves zeros.
            if self.last_label in POST_FILL:
                directive, why = POST_FILL[self.last_label]
                self.emit("\t%s" % directive,
                          "; %d bytes -- %s" % (n, why))
                self.last_label = None
                return
            self.emit("\t.skip\t%d" % n, comment)
            return
        self.note(lineno, "BASIC statement", stmt)

    # -- driver

    def convert(self, lines):
        for lineno, raw in enumerate(lines, 1):
            line = LINENO.sub("", raw).rstrip()
            if not line.strip():
                self.out.append("")
                continue
            for stmt, comment in split_statements(line):
                m = re.match(r"^DEF\s+(FN|PROC)([A-Za-z0-9_]+)", stmt, re.I)
                if m:
                    self.current_def = m.group(1) + m.group(2)
                    self.mode = "basic"
                if self.current_def in SKIP_DEFS:
                    continue
                if self.mode == "asm":
                    if stmt == "]":
                        self.mode = "basic"
                        if self.cond_stack:
                            self.cond_stack.pop()
                            if self.active_stack:
                                self.active_stack.pop()
                            self.emit("\t.endif")
                        continue
                    self.asm_statement(stmt, comment, lineno)
                else:
                    self.basic_statement(stmt, comment, lineno)
        self.flush_labels()
        return self.out


HELP_HEADER = re.compile(r"^; (\S+):(\d+)\s+r2=(\S+)\s+offset=0x([0-9A-F]+)")


def load_frozen_help(source_name):
    """The frozen FNcompress outputs, keyed by source line.

    ref/helptext.txt is produced by tools/textcomprs.py, which located every
    one of its 26 strings inside ref/QTMModule -- that check is what makes
    freezing them safe.  The compressor itself is not re-run here.
    """
    path = Path(__file__).resolve().parent.parent / "ref" / "helptext.txt"
    if not path.exists():
        return {}
    frozen, pending, text = {}, None, ""
    for line in path.read_text(encoding="utf-8").splitlines():
        m = HELP_HEADER.match(line)
        if m:
            pending = int(m.group(2)) if m.group(1) == source_name else None
            text = ""
            continue
        if pending and line.startswith("; "):
            text = line[2:]
        elif pending and line.strip().startswith(".byte"):
            data = bytes(int(v, 16) for v in
                         line.split(".byte", 1)[1].strip().split(","))
            frozen[pending] = (text, data)
            pending = None
    return frozen


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("source")
    ap.add_argument("-o", "--output")
    ap.add_argument("--only", metavar="DEF",
                    help="convert just one DEF block, e.g. PROCassm")
    args = ap.parse_args()

    env, _, labels, _ = dumpsyms.derive()
    for name, value, _ in dumpsyms.CONFIG:
        env.setdefault(name, value)
    for name, off in labels:
        env.setdefault(name, off)

    text = Path(args.source).read_text(encoding="utf-8")
    if args.only:
        lines, keep, seen = text.split("\n"), [], False
        for ln in lines:
            body = LINENO.sub("", ln)
            if re.match(r"^DEF\s+%s\b" % re.escape(args.only), body.strip()):
                seen = True
            elif seen and re.match(r"^(ENDPROC|=opt%)\b", body.strip()):
                break
            if seen:
                keep.append(ln)
        if not keep:
            print("no DEF %s in %s" % (args.only, args.source), file=sys.stderr)
            return 1
        text = "\n".join(keep)

    conv = Converter(env)
    conv.prefix = Path(args.source).stem.lower()

    # Give the converter the golden listing, and narrow the FNlong_adr sites to
    # this file's address range -- found from the labels it defines -- so the
    # sites pair up with the calls in source order.
    import listing as golden
    _, conv.golden_labels, _ = golden.parse()
    defined = [LINENO.sub("", ln).strip()[1:].split()[0].rstrip("%")
               for ln in text.split("\n")
               if re.match(r"^\s*\d+ ?\.[A-Za-z_]", ln)]
    here = [conv.golden_labels[n] for n in defined if n in conv.golden_labels]
    if here:
        lo, hi = min(here), max(here)
        conv.adr_sites = [s for s in golden.long_adr_sites() if lo <= s[0] <= hi]

    conv.frozen_help = load_frozen_help(Path(args.source).name)

    out = conv.convert(text.split("\n"))

    header = ["; Generated from %s by tools/bas2vasm.py -- do not hand-edit."
              % Path(args.source).name,
              "; Mechanical translation; verify against ref/listing.txt.",
              ""]
    body = "\n".join(header + out) + "\n"
    if args.output:
        Path(args.output).write_text(body, encoding="utf-8", newline="\n")
        print("wrote %s (%d lines)" % (args.output, len(out)))
    else:
        sys.stdout.write(body)

    if conv.notes:
        print("\n%d item(s) need attention:" % len(conv.notes), file=sys.stderr)
        for lineno, message, snippet in conv.notes:
            print("  line %-5d %s: %s" % (lineno, message, snippet[:70]),
                  file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
