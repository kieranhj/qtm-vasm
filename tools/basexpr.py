#!/usr/bin/env python3
"""Parser for the BBC BASIC constant expressions embedded in QTM's assembly.

Expressions are parsed to an AST, which is then either evaluated (when the
value must be frozen) or re-rendered as a fully parenthesised vasm expression
(when it should stay symbolic so it can vary per build variant).

Rendering rather than folding is what lets one source serve all four variants:
"dmarep<<8 OR 6" has a different value in each build, but as an expression it
is the same in all of them.

Only two things have to be folded, because vasm cannot express them at all:
floating point (BASIC's bitwise operators truncate their operands first, so
"((1<<12)*0.01) AND &FF00" is 0, confirmed by the golden listing's 13A05000)
and ASC of a string literal.

Full parenthesisation avoids having to reason about whether vasm's precedence
matches BASIC's. It mostly does, but BASIC gives EOR the same precedence as OR
while C-like grammars put ^ between & and |, so the agreement is not something
to rely on.

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

# BASIC operator -> vasm operator, for the ones that differ in spelling.
VASM_OP = {"AND": "&", "OR": "|", "EOR": "^", "DIV": "/", "MOD": "%",
           "=": "==", "<>": "!=", ">>>": ">>"}


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


# AST nodes are tuples: ("num", v) ("sym", name) ("bin", op, l, r) ("un", op, x)

class Parser:
    def __init__(self, tokens):
        self.t = tokens
        self.i = 0

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

    def parse(self):
        node = self.or_()
        if self.i != len(self.t):
            raise ExprError("trailing tokens in %r" % (self.t,))
        return node

    def binary(self, sub, ops):
        node = sub()
        while True:
            for op in ops:
                if self.accept(op):
                    node = ("bin", op, node, sub())
                    break
            else:
                return node

    def or_(self):
        return self.binary(self.and_, ("OR", "EOR"))

    def and_(self):
        return self.binary(self.cmp_, ("AND",))

    def cmp_(self):
        return self.binary(self.shift, ("<=", ">=", "<>", "=", "<", ">"))

    def shift(self):
        return self.binary(self.add, ("<<", ">>>", ">>"))

    def add(self):
        return self.binary(self.mul, ("+", "-"))

    def mul(self):
        return self.binary(self.unary, ("*", "/", "DIV", "MOD"))

    def unary(self):
        if self.accept("-"):
            return ("un", "-", self.unary())
        if self.accept("+"):
            return self.unary()
        if self.accept("NOT"):
            return ("un", "NOT", self.unary())
        return self.power()

    def power(self):
        node = self.atom()
        if self.accept("^"):
            return ("bin", "^", node, self.unary())
        return node

    def atom(self):
        kind, val = self.take()
        if kind == "op" and val == "(":
            node = self.or_()
            if not self.accept(")"):
                raise ExprError("missing )")
            return node
        if kind == "op" and val == "TRUE":
            return ("num", -1)
        if kind == "op" and val == "FALSE":
            return ("num", 0)
        if kind == "op" and val == "NOT":
            return ("un", "NOT", self.unary())
        if kind == "hex":
            return ("num", int(val[1:], 16))
        if kind == "bin":
            return ("num", int(val[1:], 2))
        if kind == "num":
            return ("num", float(val) if "." in val else int(val))
        if kind == "name" and val.upper() == "ASC":
            bracketed = self.accept("(")
            k, s = self.take()
            if k != "str":
                raise ExprError("ASC needs a string literal")
            if bracketed and not self.accept(")"):
                raise ExprError("missing ) after ASC")
            return ("num", ord(s[1]) if len(s) > 2 else 0)
        if kind == "name":
            return ("sym", val)
        raise ExprError("unexpected token %r" % (val,))


def parse(text):
    return Parser(tokenize(text)).parse()


# ------------------------------------------------------------------ evaluate

def eval_ast(node, env):
    kind = node[0]
    if kind == "num":
        return node[1]
    if kind == "sym":
        name = node[1]
        for key in (name, name.rstrip("%")):
            if key in env:
                return env[key]
        raise ExprError("unknown symbol %r" % name)
    if kind == "un":
        x = eval_ast(node[2], env)
        return -x if node[1] == "-" else ~trunc(x)
    op, l, r = node[1], eval_ast(node[2], env), eval_ast(node[3], env)
    if op == "+":
        return l + r
    if op == "-":
        return l - r
    if op == "*":
        return l * r
    if op == "/":
        return l / r
    if op == "^":
        return l ** r
    if op == "DIV":
        return trunc(trunc(l) / trunc(r))
    if op == "MOD":
        a, b = trunc(l), trunc(r)
        return a - trunc(a / b) * b
    if op == "<<":
        return trunc(l) << trunc(r)
    if op == ">>":
        return trunc(l) >> trunc(r)
    if op == ">>>":
        return to32(l) >> trunc(r)
    if op == "AND":
        return trunc(l) & trunc(r)
    if op == "OR":
        return trunc(l) | trunc(r)
    if op == "EOR":
        return trunc(l) ^ trunc(r)
    res = {"<=": l <= r, ">=": l >= r, "<>": l != r,
           "=": l == r, "<": l < r, ">": l > r}[op]
    return -1 if res else 0


def evaluate(text, env):
    """Evaluate a BASIC constant expression; raises ExprError if not constant."""
    return eval_ast(parse(text), env)


# -------------------------------------------------------------------- render

def needs_folding(node):
    """True if the tree contains something vasm cannot express."""
    if node[0] == "num":
        return isinstance(node[1], float)
    if node[0] == "sym":
        return False
    return any(needs_folding(k) for k in node[2:])


def fmt_int(v):
    """Hex for anything sizeable, and mind the sign: "0x%X" of a negative
    number yields "0x-1000000", which vasm rejects."""
    v = trunc(v)
    if abs(v) < 10:
        return str(v)
    return ("-0x%X" % -v) if v < 0 else ("0x%X" % v)


def render_ast(node):
    kind = node[0]
    if kind == "num":
        return fmt_int(node[1])
    if kind == "sym":
        return node[1].rstrip("%")
    if kind == "un":
        inner = render_ast(node[2])
        return "(-%s)" % inner if node[1] == "-" else "(~%s)" % inner
    op = VASM_OP.get(node[1], node[1])
    return "(%s %s %s)" % (render_ast(node[2]), op, render_ast(node[3]))


def render(text, env):
    """Render as a vasm expression, folding only the parts vasm cannot do."""
    node = parse(text)
    if needs_folding(node):
        value = trunc(eval_ast(node, env))
        if not -0x80000000 <= value < 0x80000000:
            value &= 0xFFFFFFFF
        return fmt_int(value)
    return render_ast(node)
