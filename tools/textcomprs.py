#!/usr/bin/env python3
"""Reimplementation of QTM's TextComprs FNcompress, for Phase 0(c).

The BASIC compressor squeezes each help/syntax string against the OS_PrettyPrint
known-word dictionary, replacing a matched word with CHR$27 + CHR$<code>.  It is
a pure function of (text, r2) plus the DATA table, so it can be reproduced off
the emulator -- and the results checked directly against ref/QTMModule, which is
what makes this trustworthy rather than a guess.

Both the dictionary and the 26 call sites are parsed out of the detokenised
sources rather than transcribed, so there is no hand-copying step to get wrong
(the dictionary contains literal TAB characters, for instance).

Usage:
    textcomprs.py check     compress every call site, locate each in ref/QTMModule
    textcomprs.py emit      write ref/helptext.txt (hex + plaintext per string)
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "ref" / "source-text"
MODULE = ROOT / "ref" / "QTMModule"

# ---------------------------------------------------------------- source parsing

# Detokenised lines look like "  130 DEF FNcompress(...)": strip the number field.
LINENO = re.compile(r"^\s*\d+ ?")


def source_lines(name):
    text = (SRC / name).read_text(encoding="utf-8")
    return [LINENO.sub("", ln) for ln in text.split("\n")]


def basic_string(s):
    """Read a BASIC string literal starting at s[0] == '"'; return (value, rest)."""
    assert s.startswith('"'), s
    end = s.index('"', 1)
    return s[1:end], s[end + 1:]


def read_dictionary():
    """PROCdefinecodes: READ the DATA table into (code, word) pairs plus r2pos.

    Returns lists indexed from 1, matching the BASIC arrays.  Index 0 is unused
    padding and r2pos[len] is the &FF terminator, exactly as BASIC sees it.
    """
    r2pos = [None]   # r2pos(0) unused
    code = [None]
    word = [None]
    for ln in source_lines("TextComprs.bas"):
        m = re.match(r"^DATA\s+(.*)$", ln)
        if not m:
            continue
        rest = m.group(1)
        if rest.strip() == "42":         # maxwords%, READ separately
            continue
        if rest.strip() == "&FF":        # terminator
            r2pos.append(0xFF)
            code.append(None)
            word.append(None)
            break
        first, rest = rest.split(",", 1)
        second, rest = rest.split(",", 1)
        value, _ = basic_string(rest.strip())
        r2pos.append(int(first))
        code.append(int(second))
        word.append(value)
    return r2pos, code, word


# ---------------------------------------------------------------- the compressor

def order_array(nums, length):
    """PROCorderarray -- descending insertion sort, transcribed literally.

    nums is passed by value in BASIC and order() by reference, so we copy nums
    and return order.  The exact swap sequence matters: it decides the order in
    which equal-length words get to claim a match, which is the whole reason the
    PLAN calls the sort stability a BASIC implementation detail.
    """
    nums = list(nums)                       # BASIC passes nums() by value
    order = [0] * (length + 1)
    for fill in range(1, length + 1):
        order[fill] = fill
    number = 2
    while True:
        if number <= length and nums[number] > nums[number - 1]:
            current = number
            while True:
                nums[number], nums[number - 1] = nums[number - 1], nums[number]
                order[number], order[number - 1] = order[number - 1], order[number]
                number -= 1
                if number == 1 or nums[number] < nums[number - 1]:
                    break
            number = current
        number += 1
        if number > length:
            break
    return order


class Compressor:
    def __init__(self):
        self.r2pos, self.code, self.word = read_dictionary()
        self.nwords = len(self.word) - 2      # entries 1..nwords; last is &FF

    def set_special(self, r2):
        """PROCsetspecial -- splice the command name into the r2pos<>-1 entries."""
        full = list(self.word)
        for w in range(1, self.nwords + 1):
            if self.r2pos[w] != -1:
                base = self.word[w]
                p = self.r2pos[w]
                full[w] = base[:p] + r2 + base[p:]
        return full

    def compress(self, text, r2):
        full = self.set_special(r2)
        lengths = [0] * (self.nwords + 1)
        for w in range(1, self.nwords + 1):
            lengths[w] = len(full[w])
        order = order_array(lengths, self.nwords)

        pos = 0          # BASIC pos%, 1-based; 0 means "not found"
        w = 1
        while w != self.nwords + 1:
            cur = order[w]
            needle = full[cur]
            # INSTR(text$, needle$, pos%+1), 1-based, 0 if absent
            pos = text.find(needle, pos) + 1 if needle else 0
            if pos > 0:
                text = (text[:pos - 1]
                        + "\x1b" + chr(self.code[cur])
                        + text[pos + len(needle) - 1:])
            else:
                w += 1
        return text


# ---------------------------------------------------------------- call sites

CALL = re.compile(r'EQUS\s+FNcompress\("(.*)","([^"]*)"\)\s*$')


def call_sites():
    """The 26 EQUS FNcompress(...) sites in QTM_Mod, in source order."""
    sites = []
    for i, ln in enumerate(source_lines("QTM_Mod.bas"), 1):
        m = CALL.match(ln.strip())
        if m:
            sites.append((i, m.group(1), m.group(2)))
    return sites


def encode(s):
    """BASIC strings here are Latin-1 bytes (the (c) sign in particular)."""
    return s.encode("latin-1")


def main():
    action = sys.argv[1] if len(sys.argv) > 1 else "check"
    comp = Compressor()
    sites = call_sites()
    module = MODULE.read_bytes()

    results = []
    misses = 0
    for lineno, text, r2 in sites:
        out = encode(comp.compress(text, r2))
        off = module.find(out)
        if off < 0:
            misses += 1
        results.append((lineno, text, r2, out, off))

    if action == "check":
        for lineno, text, r2, out, off in results:
            mark = "0x%04X" % off if off >= 0 else "NOT FOUND"
            print("%-10s line %-6d %3d->%3d bytes  %s"
                  % (mark, lineno, len(text), len(out), r2))
        print("\n%d/%d located in ref/QTMModule" % (len(results) - misses, len(results)))
        return 1 if misses else 0

    if action == "emit":
        out_path = ROOT / "ref" / "helptext.txt"
        lines = ["; QTM v1.49b -- frozen FNcompress outputs (Phase 0c).",
                 "; Generated by tools/textcomprs.py; every string below was located",
                 "; in ref/QTMModule at the offset given, which is the proof it is right.",
                 "; Do not hand-edit.", ""]
        for lineno, text, r2, out, off in results:
            lines.append("; QTM_Mod.bas:%d  r2=%s  offset=0x%04X" % (lineno, r2, off))
            lines.append("; %s" % text)
            lines.append("  .byte " + ",".join("0x%02X" % b for b in out))
            lines.append("")
        out_path.write_text("\n".join(lines), encoding="utf-8", newline="\n")
        print("wrote %s (%d strings)" % (out_path, len(results)))
        return 1 if misses else 0

    print(__doc__)
    return 2


if __name__ == "__main__":
    sys.exit(main())
