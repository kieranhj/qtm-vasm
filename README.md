# qtm-vasm

Porting **QTM (QTheMusic) v1.49b** by Steve Harrison from tokenised BBC BASIC V assembler
source to plain [vasm](http://sun.hasenbraten.de/vasm/) ARM assembler.

**Success criterion: the vasm build must be byte-identical to the released `QTMModule`**
(26 624 bytes, dated 19 Mar 2023), which is checked in at `ref/QTMModule` as the acceptance
target.

See [`PLAN.md`](PLAN.md) for the full plan, findings and risk register. Start at Phase 0.

## Why

QTM is the de-facto Soundtracker/MOD player for the Acorn Archimedes, and its DMA fill
routine is the single largest consumer of CPU time when playing music on a stock 8 MHz ARM2.
Getting it into vasm puts it in the same toolchain as `rasterman-vasm` and `LSP_ARM250`,
which is the precondition for experimenting with the mixer inner loop.

v1.49b is specifically the right version to port: unlike v1.45, it does **no assembly-time
code generation** (the DMA unrolling moved into the module at runtime), so the conversion is
a rule-driven text transformation rather than a metaprogramming exercise.

## Layout

```
PLAN.md                   the plan — read this first
ref/QTMModule             released v1.49b binary; the byte-identity target
ref/source-tokenised/     original tokenised BASIC V sources, unaltered
ref/source-text/          detokenised text of the same, for reading and diffing
ref/docs/                 QTM licence, copyright, history, technical docs
tools/detok.py            BBC BASIC V detokeniser
tools/vasmarm_std_win32.exe   vasm 1.8k, ARM backend 0.4h, std syntax
src/                      the vasm port (empty — Phase 1 onwards)
build/                    build output (gitignored)
```

`ref/source-tokenised/` and `ref/QTMModule` are unaltered copies from `QTMv1-49b.zip` and
must stay that way — they are the ground truth everything is measured against.

## Provenance and licence

QTM and its source code are **© Steve Harrison, 1993–2023**, released as freeware with the
source in the public domain under the conditions in [`ref/docs/Licence`](ref/docs/Licence).
Those conditions are short and worth reading; the two that bind this repository are:

- the original author must be credited, along with the QTM web address
  (`www.pi-star.co.uk/qtm`);
- **modified versions of the source must be clearly identified as such**, and the author
  asked to be notified.

**This repository contains a modified form of the QTM source code** — a mechanical
translation from BBC BASIC V assembler to vasm syntax. It is not an official Steve Harrison
release. The intent is byte-identical output, but the *source form* is altered and this
should be stated plainly anywhere the work is distributed or published.

vasm is © Volker Barthelmann; the ARM backend is © Frank Wille.
