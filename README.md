# qtm-vasm

Porting **QTM (QTheMusic) v1.49b** by Steve Harrison from tokenised BBC BASIC V assembler
source to plain [vasm](http://sun.hasenbraten.de/vasm/) ARM assembler.

**Success criterion: the vasm build must be byte-identical to the released `QTMModule`**
(26 624 bytes, dated 19 Mar 2023), which is checked in at `ref/QTMModule` as the acceptance
target.

**Status: achieved, for all four build variants.** `python build.py` regenerates the port
from `ref/` and verifies each one byte-for-byte:

| Variant | Bytes | CRC | |
|---|---|---|---|
| `release` | 26 624 | `9AA00EE5` | the shipped build |
| `rm24` | 27 152 | `94B863BD` | RasterMan, 24 µs, 4-channel |
| `rm48` | 27 028 | `D7CB9D54` | RasterMan, 48 µs, 4/8-channel |
| `alpha` | 26 824 | `BE7CF127` | alpha test: DMA instrumentation, debug SWI |

The release module loads and plays under Arculator, so all five acceptance criteria in
PLAN.md §5 are met. Only `release` has a published binary; the other three references were
captured from the original BASIC (see `tools/emulator/README.md`).

See [`PLAN.md`](PLAN.md) for the plan and findings; §5a–§5e record what each phase actually
turned up, including the four BBC BASIC assembler behaviours that the original rule table
missed.

## Building

```
python build.py                  all four variants
python build.py release rm48     just these
python build.py --check          verify without regenerating
```

**Everything under `src/` is generated** — from the detokenised BASIC in `ref/source-text/`
plus each variant's golden listing. Edit the tools, not the output.

The translated assembly is **shared by all four variants** (326 KB in `src/shared/`); what
differs is 8 KB per variant in `src/<variant>/` — the config header of `.equ` switches, and
the version stamps that `PROCvalidatecrc` writes after assembly. `build.py` regenerates the
shared tree for each variant and fails if it comes out different, so a variant-specific
leak cannot slip in unnoticed. `tools/variants.py` defines the configurations.

`tools/checkfile.py src/release/qtm_dma.asm` places a single file at its real address and
diffs it against the module, which is how each was brought up individually.

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
ref/listing*.txt          golden per-line listings, one per variant
ref/QTMModule-*           reference binaries for the non-shipped variants
ref/helptext.txt          frozen FNcompress outputs (generated)
build.py                  regenerate everything and verify
tools/detok.py            BBC BASIC V detokeniser
tools/bas2vasm.py         BBC BASIC assembler → vasm converter
tools/checkfile.py        place one file at its real address and diff it
tools/variants.py         the four build configurations
tools/verify.py           assemble and compare against the reference binary
tools/emulator/           how ref/listing.txt was captured, under Arculator
tools/vasmarm_std_win32.exe   vasm 1.8k, ARM backend 0.4h, std syntax
src/shared/               the vasm port — identical for every variant
src/<variant>/            per-variant switches and version stamps
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
