#!/usr/bin/env python3
"""Evaluator for the BBC BASIC constant expressions embedded in QTM's assembly.

These cannot be passed through to vasm textually, because BASIC's semantics
differ in two ways that change the emitted bytes:

  * Arithmetic is floating point, but the bitwise operators truncate toward
    zero first.  QTM_Timer relies on this:

        MOVNE R5,#((1<<12)*0.01) AND &FF00

    is 40.96 -> 40 -> 40 AND 0xFF00 -> 0, and the golden listing confirms the
    assembled word is 13A05000, i.e. MOVNE R5,#0.

  * Shifts bind *looser* than + and -, unlike C and unlike vasm.

So constant expressions are evaluated here and emitted as plain integers.

BBC BASIC V operator precedence, tightest first:
    ^                       (power)
    unary - + NOT
    * / DIV MOD
    + -
    << >> >>>
    = <> < > <= >=
    AND
    OR EOR
"""
import re

TOKEN = re.compile(r"""
    (?P<hex>&[0-9A-Fa-f]+)
  | (?P<bin>%[01]+)
  | (?P<str>"[^"]*")
  | (?P<num>\d+\.\d+|\.\d+|\d+)
  | (?P<name>[A-Za-z_][A-Za-z0-9_]*%?)
  | (?P<op><<|>>>|>>|<=|>=|<>|[-+*/^()=<>,])
  | (?P<ws>\s+)
""", re.VERBOSE)

WORDOPS = {"AND", "OR", "EOR", "DIV", "MOD", "NOT", "TRUE", "FALSE"}


class ExprError(Exception):
    pass


def tokenize(text):
    out, i = [], 0
    while i < len(text):
        m = TOKEN.match(text, i)
        if not m:
            raise ExprError("bad character %r in %r" % (text[i], text))
        i = m.end()
        if m.lastgroup == "ws":
            continue
        val = m.group()
        if m.lastgroup == "name" and val.upper() in WORDOPS:
            out.append(("op", val.upper()))
        else:
            out.append((m.lastgroup, val))
    return out


def trunc(x):
    """BASIC converts to integer by truncating toward zero before bitwise ops."""
    return int(x)


def to32(x):
    return trunc(x) & 0xFFFFFFFF


class Parser:
    def __init__(self, tokens, env):
        self.t = tokens
        self.i = 0
        self.env = env

    def peek(self):
        return self.t[self.i] if self.i < len(self.t) else (None, None)

    def take(self):
        tok = self.peek()
        self.i += 1
        return tok

    def accept(self, value):
        kind, val = self.peek()
        if kind == "op" and val == value:
            self.i += 1
            return True
        return False

    # ---- precedence climb

    def parse(self):
        v = self.or_()
        if self.i != len(self.t):
            raise ExprError("trailing tokens at %d in %r" % (self.i, self.t))
        return v

    def or_(self):
        v = self.and_()
        while True:
            if self.accept("OR"):
                v = trunc(v) | trunc(self.and_())
            elif self.accept("EOR"):
                v = trunc(v) ^ trunc(self.and_())
            else:
                return v

    def and_(self):
        v = self.cmp_()
        while self.accept("AND"):
            v = trunc(v) & trunc(self.cmp_())
        return v

    def cmp_(self):
        v = self.shift()
        for op in ("<=", ">=", "<>", "=", "<", ">"):
            if self.accept(op):
                r = self.shift()
                # BASIC's TRUE is -1
                res = {"<=": v <= r, ">=": v >= r, "<>": v != r,
                       "=": v == r, "<": v < r, ">": v > r}[op]
                return -1 if res else 0
        return v

    def shift(self):
        v = self.add()
        while True:
            if self.accept("<<"):
                v = trunc(v) << trunc(self.add())
            elif self.accept(">>>"):
                v = (to32(v) >> trunc(self.add()))
            elif self.accept(">>"):
                v = trunc(v) >> trunc(self.add())
            else:
                return v

    def add(self):
        v = self.mul()
        while True:
            if self.accept("+"):
                v = v + self.mul()
            elif self.accept("-"):
                v = v - self.mul()
            else:
                return v

    def mul(self):
        v = self.unary()
        while True:
            if self.accept("*"):
                v = v * self.unary()
            elif self.accept("/"):
                v = v / self.unary()
            elif self.accept("DIV"):
                v = trunc(trunc(v) / trunc(self.unary()))
            elif self.accept("MOD"):
                a, b = trunc(v), trunc(self.unary())
                v = a - trunc(a / b) * b
            else:
                return v

    def unary(self):
        if self.accept("-"):
            return -self.unary()
        if self.accept("+"):
            return self.unary()
        if self.accept("NOT"):
            return ~trunc(self.unary())
        return self.power()

    def power(self):
        v = self.atom()
        if self.accept("^"):
            return v ** self.unary()
        return v

    def atom(self):
        kind, val = self.take()
        if kind == "op" and val == "(":
            v = self.or_()
            if not self.accept(")"):
                raise ExprError("missing )")
            return v
        if kind == "op" and val == "TRUE":
            return -1
        if kind == "op" and val == "FALSE":
            return 0
        if kind == "hex":
            return int(val[1:], 16)
        if kind == "bin":
            return int(val[1:], 2)
        if kind == "num":
            return float(val) if ("." in val) else int(val)
        if kind == "name" and val.upper() == "ASC":
            # ASC"x" and ASC("x") -- the character code of the first character.
            bracketed = self.accept("(")
            k, s = self.take()
            if k != "str":
                raise ExprError("ASC needs a string literal")
            if bracketed and not self.accept(")"):
                raise ExprError("missing ) after ASC")
            return ord(s[1]) if len(s) > 2 else 0
        if kind == "name":
            key = val.rstrip("%")
            if val in self.env:
                return self.env[val]
            if key in self.env:
                return self.env[key]
            raise ExprError("unknown symbol %r" % val)
        raise ExprError("unexpected token %r" % (val,))


def evaluate(text, env):
    """Evaluate a BASIC constant expression; raises ExprError if not constant."""
    return Parser(tokenize(text), env).parse()


def is_constant(text, env):
    try:
        evaluate(text, env)
        return True
    except (ExprError, ZeroDivisionError, TypeError):
        return False
