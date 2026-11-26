# Plan: porting QTM v1.49b from tokenised BBC BASIC V to vasm

**Goal:** a vasm build of QTM v1.49b that is byte-identical to the released `QTMModule`
(26 624 bytes, dated 19 Mar 2023) shipped in `QTMv1-49b.zip`.

Source: `C:\Users\khcon\OneDrive\Retro\Archie\Contributed\Steve\QTMv1-49b.zip` → `Source/` (10 tokenised BASIC
files, ~9 130 detokenised lines).

---

## 0. Findings that shape the plan

Four things were established by inspecting the actual source before planning. Two make the
job much easier than expected; two change what "byte-identical" can even mean.

### 0.1 v1.49b has no assembly-time code generation loops — this is the big one

v1.45 unrolled its DMA mixers at *assembly* time:

```basic
.a2_anyvolume
]:FOR arm2dma=1 TO dma:[OPT opt%
LDRB    R6,[R0,R1,ASR#12]
...
]:NEXT:[OPT opt%
```

That is exactly the construct that makes BBC BASIC assembler sources hard to port — the
BASIC program *is* the macro processor, and 208 iterations of it are 63 KB of module.

**v1.49b removed this.** The module now unrolls at *runtime* (`QTM_DMA` header: "ARM2
auto-unrolling dma interface"), which is precisely how 63 KB became 26 KB. A survey of all
ten files finds **zero `FOR` loops emitting assembly**.

### 0.2 The remaining BASIC/assembly interleaving is all simple conditionals

69 escape points (`]:` … `:[OPT`) across the source, distributed:

| File | escapes | nature |
|---|---|---|
| `QTM_DMA` | 41 | all `IF qtmrast%` or `IF alphatest%` |
| `QTM_Mod` | 12 | conditionals |
| `QTM_Data` | 6 | conditionals |
| `QTM_Play` | 4 | conditionals |
| `QTM_Song`, `QTM_VUcode` | 2 each | conditionals |
| `QTMv1À49` | 2 | pass structure |
| `QTM_Timer`, `TextComprs`, `LOGtable` | 0 | — |

Every one maps onto a vasm `.if` / `.endif`. Typical form:

```basic
]:IF qtmrast% THEN [OPT opt%:MOV R0,#0:STRB R0,[R9,#rm_dmainprogress]:]
```
→
```
    .if qtmrast
    MOV R0,#0
    STRB R0,[R9,#rm_dmainprogress]
    .endif
```

### 0.3 The build's own CRC check is stale and cannot be the acceptance test

`QTMv1À49` carries:

```basic
filesize%=63064
paulvigay32bitcrc%=&F2B0FC32
```

Verified numerically: `~zlib_crc32(v1.45 QTMModule2)` = `0xF2B0FC32`, and 63 064 is the
v1.45 module size. **Both constants are v1.45 leftovers.** The shipped v1.49b module is
26 624 bytes with `~crc32` = `0x9AA00EE5`, and no prefix of it hashes to the stored value.

The CRC machinery itself (`PROCassmcrc`, poly `&EDB88320`, init `&FFFFFFFF`, final `MVN`,
then a further BASIC `NOT` — i.e. *inverted* zlib CRC-32) is still worth reusing as a
harness, but the expected value must be recomputed from the shipped binary, not taken from
the source.

### 0.4 The released module is not reproducible from a fresh BASIC build

`betatest%=TRUE` in v1.49b, so `PROCvalidatecrc` always takes its "non-release" branch:

```basic
IF crcvalue%<>paulvigay32bitcrc% OR alphatest% OR betatest% OR qtmrast% THEN
 date$=MID$(TIME$,5,11)
 $(code%+helpdate)="c ("+date$+") © Steve Harrison"
 IF betatest% code%?helpdate=ASC"b":code%?helpchar=ASC" "
```

The **current build date** is stamped into the module after assembly. Running `Assemble`
today produces a module that differs from the shipped one in that string.

The shipped module contains, at offset `0x2AD7`:

```
1.49b (19 Mar 2023)
```

**Consequence for the goal:** "byte-identical" must be defined as *identical to the shipped
`QTMModule`*. The vasm source should emit that date string as a literal and must **not**
reproduce the BASIC's date-patching logic. Same for the two other post-assembly patches
(`helptextversion`, `helpchar`) — bake in the observed result.

---

## 1. Target configuration

Build the default (non-RasterMan) variant first. From `QTMv1À49`:

| Symbol | Release value |
|---|---|
| `qtmrast%` | `FALSE` |
| `dmachoice` | `32` |
| `maxchans` | `8` |
| `alphatest%` | `FALSE` |
| `betatest%` | `TRUE` |
| `ver$` | `"1.49"` |
| `datestamp$` | `"14:54:39 19 Mar 2023"` |

Assembly is offset assembly with `P%=0` (`FOR opt%=12 TO 14 STEP 2`, `P%=0:O%=code%`), so
module addresses are relative to the module base. In vasm: `.org 0`, `-Fbin`. The 63 KB
buffer is **zero-filled before assembly**, so every reserved or skipped region is zero.

Assembly order (from `PROCassm`), which fixes the module layout:

```
FNassm_mod      ; QTM_Mod  (incl. timer + VU code)
FNassm_main     ; QTM_Play
FNassm_initsong ; QTM_Song
FNassm_dma      ; QTM_DMA
r0_div_r1, armcheck, ...   ; inline in QTMv1À49
```

followed by post-assembly fills: `PROCinit_amiperiods` (writes at fixed offset
`amigaperiodz`) and `OSCLI"Load … LOGdata "+STR$~(loglintab+code%)`.

---

## 2. Phases

### Phase 0 — Ground truth and harness (do this first, it de-risks everything)

1. **Freeze the detokeniser.** One already exists (written for the v1.45 analysis) and
   handles BASIC V tokens including the `C6`/`C7`/`C8` extension tables and `8D` line-number
   encoding. Promote it to a checked-in tool; its output is the canonical text source.
2. **Capture a golden listing.** Run the original build under Arculator/RPCEmu with
   `opt%=13`/`15` (listing enabled) and `*Spool` the output. This yields, per source line,
   the address and assembled bytes.

   This artefact is the single highest-value thing in the whole project: it converts
   "the binary differs somewhere in 26 KB" into "line 4170 of QTM_Mod assembled differently",
   which is the difference between a week and an afternoon on every encoding mismatch.
3. **Dump every BASIC-computed symbol.** Add a `PROCdumpsyms` that prints every offset
   constant from `PROCinit_offsets`, `FNtableoffsets`, `PROCmodvars` and `PROCdefinecodes`
   as `NAME = &xxxx`. Spool it. This becomes `qtm_offsets.h.asm` verbatim.
4. **Build the diff harness** (Python, runs on Windows, no emulator needed):
   - assemble with vasm → `build/qtm.bin`
   - `cmp` against the shipped `QTMModule`
   - on mismatch, report the first differing offset, a hex window either side, and the
     matching source line from the golden listing
   - report inverted-zlib CRC-32 for parity with the original harness

### Phase 1 — Mechanical translation

Write a **table-driven converter** (detokenised BASIC → vasm) rather than hand-editing
9 130 lines. Rules, all verified present in the source:

| BBC BASIC assembler | vasm | notes |
|---|---|---|
| `.label` | `label:` | strip trailing `%` (e.g. `.fttabstart%`) |
| `:` statement separator | newline | must respect strings and comments |
| `;comment` | `;comment` | vasm accepts `;` |
| `&FF` | `0xFF` | |
| `%1010` | `0b1010` | |
| `EQUD` / `DCD` | `.long` | |
| `EQUW` / `DCW` | `.word` | |
| `EQUB` / `DCB` | `.byte` | |
| `EQUS "x"` / `DCS` | `.byte "x"` | no implicit terminator in either |
| `EQUS STRING$(n,CHR$0)` | `.skip n` | 3 sites |
| `ALIGN` | `.p2align 2` | |
| `MOV R0,R0,LSLR2` | `MOV R0,R0,LSL R2` | 32 sites (`LSLR0`, `LSRR6`, …) |
| `SWI "OS_WriteC"` | `SWI OS_WriteC` | 33 distinct names → `swis.h.asm` of `.equ`s |
| `LDMGEFD`, `STMNEIA`, `SUBCSS` | unchanged | standard ARM ordering already |
| `TEQP`, `LDMFD R13!,{…}^`, `MOVS PC,R14` | unchanged | vasm `-m250` handles 26-bit forms |
| `]:IF x THEN … :[OPT opt%` | `.if x` / `.endif` | 69 sites, see §0.2 |

The 33 string SWIs are the only external name dependency; `LSP_ARM250/swis.h.asm` is a
usable starting point for the numbers.

### Phase 2 — Replace the BASIC macro functions

Nine `FN`s emit instructions. Call-site counts measured:

| Function | sites | Recommended treatment |
|---|---|---|
| `FNlong_adr(cond$,reg%,addr%)` | 51 | vasm macro replicating the ADD/SUB-from-`R12` sequence |
| `FNmega_adr(cond$,reg%,addr%)` | 6 | vasm macro |
| `FNdiv(it)` | 34 | vasm macro (unrolled divide step) |
| `FNmrs` / `FNmsr` | 11 / 12 | emit `.long` with the FN's computed encoding |
| `FNmrc` / `FNmcr` | 4 / 1 | emit `.long` with the FN's computed encoding |
| `FNAUdiv` | 2 | vasm macro |
| `FNgetnum` | helper | not emitted; used by the above |

For `FNmrs`/`FNmsr`/`FNmrc`/`FNmcr`, **prefer `.long` over native vasm mnemonics.** These
were hand-encoded because the 1993 BASIC assembler had no ARMv3 PSR or coprocessor support;
letting vasm re-encode them introduces an avoidable byte-identity risk for no benefit.

For the three macros, the acceptance test is per-call-site: extract the expected bytes for
each of the 51/6/34 sites from the golden listing and assert the macro reproduces them.

### Phase 3 — Reproduce the BASIC-computed data

Five distinct generators. **The guiding principle is: freeze outputs, do not port
algorithms.** Every one of these is deterministic and produces a fixed byte string, so
re-implementing the algorithm buys nothing and risks divergence.

1. **`PROCinit_offsets` + `FNtableoffsets`** — struct offsets, produced partly by a
   throwaway assembly pass into a scratch buffer and partly by scalar BASIC assignments
   (`CIAdelay=00`, `speed=08`, …). → freeze as `.equ` from the Phase 0 symbol dump.
   Keep the assertion `generalusebuffer = generaluse_addr - song_data` as a vasm
   compile-time check.
2. **`PROCmodvars`, `PROCinit`** — more constants. → same treatment.
3. **`PROCinit_amiperiods`** — six 72-entry `DCW` tuning tables written at fixed offset
   `amigaperiodz`. Already literal in the source. → transcribe verbatim as `.word`.
4. **`TextComprs`** (`FNcompress`, `PROCdefinecodes`, `PROCsetspecial`, `PROCsortorder`,
   `PROCorderarray`) — compresses 28 help/syntax strings against the `OS_PrettyPrint`
   known-word table, using a sort whose stability is a BASIC implementation detail.
   → **do not port.** Dump the 28 resulting byte strings from the real build, emit them as
   `.byte` blocks with the original plaintext preserved in comments beside each.
5. **`LOGdata`** — 256-byte log→linear table loaded at `loglintab`. → `.incbin`.

Plus the post-assembly patches from §0.4: emit `1.49b (19 Mar 2023)` and the
`helptextversion` / `helpchar` bytes as literals matching the shipped module.

### Phase 4 — Layout

- `.org 0`, single section, `-Fbin`.
- Verify vasm's fill byte for gaps is `0x00` (the BASIC pre-zeroes its buffer). If vasm
  pads with anything else, use explicit `.skip`.
- The module header's offsets to code/help/command/SWI tables are all label arithmetic and
  need no special handling.
- Total output length must be exactly 26 624 bytes.

### Phase 5 — Verification

Acceptance criteria, in order:

1. `vasm` assembles clean.
2. Output is 26 624 bytes.
3. `cmp` against the shipped `QTMModule` reports no differences. **This is the test** —
   the CRC is only a convenience.
4. Inverted zlib CRC-32 = `0x9AA00EE5`.
5. Module loads and plays under Arculator (ARM2 and ARM3 configs) and RPCEmu.

### Phase 6 — Build variants

Only after (5) passes. Re-introduce `qtmrast%` (RasterMan edition, 24 µs/4-channel and
48 µs/8-channel) and `alphatest%` as vasm `.equ` switches. Each variant needs its own
reference binary built from the original BASIC for comparison — the RasterMan edition is
what integrates with `rasterman-vasm`, so it matters for the wider project.

---

## 3. Suggested file ordering

Port in ascending difficulty so the translation rules and harness are proven on easy files:

| Order | File | Lines | Escapes | Why |
|---|---|---|---|---|
| 1 | `QTM_Timer` | 343 | 0 | pilot: pure assembly, no metaprogramming |
| 2 | `QTM_VUcode` | 447 | 2 | |
| 3 | `QTM_Song` | 848 | 2 | |
| 4 | `QTM_Data` | 395 | 6 | mostly `.equ`; unblocks everything else |
| 5 | `QTM_Play` | 1 240 | 4 | |
| 6 | `QTM_DMA` | 1 694 | 41 | all conditionals, but the densest |
| 7 | `QTM_Mod` | 3 180 | 12 | largest; contains all `FNcompress` sites |
| 8 | `QTMv1À49` | 818 | 2 | driver → becomes `qtm.asm` top level + build script |

Note that assembly *order* in the output is `Mod, Play, Song, DMA` regardless of porting
order; the top-level file just `.include`s them in that sequence.

---

## 4. Risk register

| Risk | Likelihood | Mitigation |
|---|---|---|
| **Immediate-encoding divergence** — `MOV R0,#&FF000000` has multiple valid rotate/imm encodings; vasm may pick differently from 1993 BASIC | High | Golden listing diff per line; fall back to `.long` for stubborn cases |
| **`ADR` encoding** — BASIC emits `ADD/SUB Rn,PC,#imm`; vasm's `-opt-adr` changes behaviour | High | Choose `-opt-adr` deliberately, verify against listing; `ADRL` needs explicit handling |
| **vasm multi-pass optimisation** shortening branches/literals differently | Medium | Disable optimisation flags; the source uses no `LDR Rn,=` literal pools, which removes the usual culprit |
| **`FNcompress` output not reproducible** | Medium | Sidestepped by freezing the 28 outputs (§3.4) |
| **Symbol dump incomplete** — a computed constant missed | Medium | The `generalusebuffer` assertion catches layout drift; add more `.if`-based asserts |
| **Detokeniser bug** on a rare token | Low | Round-trip check: re-tokenise and compare against the original file |
| **No RISC OS machine available** to produce golden artefacts | Low | Arculator is already in the tree (`Repos/arculator`) with a HostFS share |

The first two are the ones that will actually consume time. Both are entirely handled by
the golden listing, which is why Phase 0 comes first.

---

## 5. Deliverables

What was actually built (the plan above is left as written; this is the outcome):

```
qtm-vasm/
  build.py                # regenerate every variant from ref/, assemble, verify
  tools/
    detok.py              # BASIC V → text
    variants.py           # the four build configurations
    basexpr.py            # BASIC expression parser: evaluate or re-render
    bas2vasm.py           # the converter
    dumpsyms.py           # offset constants → qtm_offsets.h.asm
    textcomprs.py         # FNcompress, verified against the module → helptext.txt
    listing.py            # golden listing: parse, reconstruct, SWIs, labels
    mkamiperiods.py       # period tables from the driver
    mktoplevel.py         # qtm.asm from PROCassm
    checkfile.py          # place one file at its real address and diff it
    verify.py             # assemble one variant and compare
    emulator/             # how the listings were captured
  ref/
    QTMModule             # shipped 1.49b binary, the acceptance target
    QTMModule-{rm24,rm48,alpha}   # references for the non-shipped variants
    listing{,-rm24,-rm48,-alpha}.txt   # golden per-line listings
    helptext.txt          # frozen FNcompress outputs
  src/
    shared/               # the port — identical for every variant
      qtm.asm  qtm_mod.asm  qtm_play.asm  qtm_song.asm  qtm_dma.asm
      qtm_timer.asm  qtm_vucode.asm  qtm_data.asm
      qtm_amiperiods.asm  swis.h.asm  LOGdata
    {release,rm24,rm48,alpha}/
      qtm_offsets.h.asm   # switches and offsets
      stamp_*.asm         # version stamps, and one STR$-built string
```

Differences from the plan worth noting: there is no `macros.h.asm` (`FNlong_adr` is
expanded inline and the other macro FNs turned out to be dead, §5a), `symbols.txt` never
existed as a spooled artefact because the offsets proved derivable on the host (§5a), and
`src/` is split shared/per-variant (§5g).

---

## 5a. Phase 0 outcome — corrections to the above

Phase 0 is complete except for the golden listing. Four claims in this plan turned
out to be wrong, and two of them shrink Phase 2 substantially.

**Phases 0(b) and 0(c) did not need the emulator.** Both were expected to require a
`PROCdumpsyms` run under Arculator. In fact every offset constant is a literal or a
constant expression, and `FNcompress` is a pure function of inputs already in the
tree — so both are derived on the host by `tools/dumpsyms.py` and
`tools/textcomprs.py`. More importantly both *self-check* against ground truth:

- all 26 compressed strings were located in `ref/QTMModule`, tiling contiguously
  with single zero terminators from `0x305D` to `0x3671`;
- the offsets satisfy the original build's own assertion
  (`generalusebuffer = generaluse_addr - song_data`, both 1032) and a second one
  implied by the source (`dma_clc = unused_e`, both 2812) that reaches the part of
  the layout the first does not.

Only the golden listing (0a) still needs RISC OS — see `tools/emulator/README.md`.

**§3.4 says 28 `FNcompress` sites; there are 26.**

**§2 Phase 2's call-site table is wrong, and four of the nine `FN`s are dead.**
Counting non-comment call sites only:

| Function | plan said | actual | note |
|---|---|---|---|
| `FNlong_adr` | 51 | 22 | |
| `FNmrs` / `FNmsr` / `FNmrc` | 11 / 12 / 4 | 10 / 11 / 3 | |
| `FNmega_adr` | 6 | **0** | defined, only ever named in REMs |
| `FNdiv` | 34 | **0** | all 32 calls are inside `FNAUdiv` |
| `FNAUdiv` | 2 | **0** | its one mention is commented out (`;FNAUdiv`) |
| `FNmcr` | 1 | **0** | defined, never called |

So Phase 2 is one vasm macro (`FNlong_adr`, 22 sites) plus 24 hand-encoded words
(`FNmrs`/`FNmsr`/`FNmrc`) emitted as `.long`, not nine constructs across 119 sites.

**`PROCmodvars` is empty** (`DEF PROCmodvars` / `ENDPROC`), so §3.2 has nothing to
do. Likewise `amigaperiodz`, `loglintab`, `helpdate`, `helpchar` and
`helptextversion` are ordinary assembly labels, not BASIC-computed constants.

Two smaller notes for later phases:

- vasm's std syntax rejects `name = value` and `name .equ value` in column 0 —
  only `.equ name,value` parses. `.if` / `.fail` work as expected.
- `FNmrs`/`FNmsr`/`FNmrc` poke their words straight into memory rather than going
  through `[OPT`, so their 24 words will be missing from the golden listing.

## 5b. Phase 1 outcome — translation rules the §1 table was missing

All seven files convert and assemble. `QTM_Timer` and `QTM_Data` are **byte-identical**
to their slices of the shipped module (`0x2298..0x25F0` and `0x6728..0x6800`); the other
five are correct up to their first unexpanded macro, which is all that can be asked of
Phase 1. What remains is 45 Phase-2 macro sites and the 26 Phase-3 frozen strings.

Four behaviours of the BBC BASIC assembler were not in §1 and each one silently corrupts
the output if missed. All were found by `tools/checkfile.py`, which places a single
converted file at its real address using the listing's label addresses and diffs it
against the module.

1. **A `;` comment ends at the next `:`, not at end of line.** The assembler consumes one
   statement at a time and `:` terminates the statement, comment included. `QTM_Play`
   line 1230 is `;EQUD 0;EQUD 0:EQUD 0` and the listing shows the comment printed as
   `;EQUD 0;EQUD 0` with a real `EQUD 0` assembled at `0x4310`. Treating `;` as
   end-of-line loses that word and shifts everything after it.

2. **The assembler word-aligns before an instruction, but not before data.** `QTM_Mod`
   line 599 emits a 17-byte `EQUS` at `0x6C4`, and the next `SWI` is at `0x6D8` with no
   `ALIGN` in the source. vasm does not do this, so a `.p2align 2` has to be inserted.

3. **Labels are not aligned, and branch destinations round up.** 42 labels in the module
   sit at unaligned addresses inside string tables. `err_cmddisable` is at `0x0A02` while
   its first instruction is at `0x0A04`, and `BVS err_cmddisable` at `0x09D8` encodes
   offset 9, i.e. it targets `0x0A04`. So alignment padding goes *before* a label that
   precedes code, and data labels are left where they are.

4. **A stray `ENDIF` is a no-op.** `QTM_Song` line 847 has an `ENDIF` with no matching
   `IF`; BASIC ignores it. Emitting `.endif` for it unbalances the output.

Three vasm quirks, all confirmed by probe:

- Only `.equ name,value` parses; `name = value` and `name .equ value` in column 0 are read
  as mnemonics.
- An immediate may not begin with `(`, even when the parens do not wrap the whole
  expression. `#(a-b)` fails; `#a-b` and `#0+(a-b)/4` work.
- `.if` wants bitwise `|`/`&`, not `||`/`&&`. BASIC's `TRUE` is `-1`, so the flags carry
  over unchanged.

Constant expressions are folded in the converter only where BASIC's semantics differ from
vasm's — its bitwise operators truncate float operands (`((1<<12)*0.01) AND &FF00` is 0,
confirmed by the listing's `13A05000`), and its shifts bind looser than `+`/`-`. Everything
else stays symbolic so the source still reads as offsets.

## 5c. Phase 2 outcome — macros expanded

All 45 macro sites are expanded. **Four of the seven files are now byte-identical** to
their slices of the shipped module:

| File | Extent | Status |
|---|---|---|
| `qtm_timer` | `0x2298..0x25F0` | identical |
| `qtm_vucode` | `0x25F0..0x2AC0` | identical |
| `qtm_dma` | `0x5624..0x6658` | identical |
| `qtm_data` | `0x6728..0x6800` | identical |
| `qtm_song` | `0x4C18..0x5624` | identical except `loglintab` (Phase 3 `.incbin`) |
| `qtm_play` | `0x3674..0x4C18` | identical except `amigaperiodz` (Phase 3 tables) |
| `qtm_mod` | `0x0000..0x3074` | identical except `0x2ADB..0x3073` (Phase 3 help text) |

Every remaining byte is Phase 3 data. All code matches.

**`FNlong_adr` must be emitted as `.long`, not as ADD/SUB mnemonics.** This is the
immediate-encoding risk in §4 landing exactly where predicted. The second word of the pair
always uses rotate 12 with the gap's high byte; when that byte is a multiple of 4 the same
value has a second valid encoding, and vasm prefers it. For gap `0x5C3C` vasm emitted
rotate 11 / imm `0x17` against the original's rotate 12 / imm `0x5C` — both mean `0x5C00`,
only one is byte-identical. Composing the word from the label arithmetic removes the
choice, and matches what `FNlong_adr` actually does (`EQUD optcode1%`).

**The ADD/SUB direction cannot be decided by conditional assembly.** vasm's `.if` resolves
a not-yet-seen label to 0, so `.if (target-here-8) < 0` takes the wrong branch on any
forward reference. The direction is instead taken from the golden listing, where
`FNlong_adr`'s two `EQUD`s appear with their real addresses — 19 sites, the other 3 of the
22 being inside `qtmrast` blocks this build excludes. Each site's encoded gap is checked
against its target label's address, so a mis-pairing is caught rather than emitted.

`FNmrs` / `FNmsr` / `FNmrc` are emitted as `.long` from a transcription of the FNs' bit
layouts. Unlike `FNlong_adr` these never appear in the listing at all — they poke memory
directly, bypassing `[OPT` — so `tools/checkfile.py` against the module is the only
check on them, and it passes for all 24.

## 5d. Phase 3 outcome — all seven files byte-identical

Every converted file now matches its slice of the shipped module exactly:

| Extent | File | Bytes |
|---|---|---|
| `0x0000..0x3674` | `qtm_mod` (includes `qtm_timer`, `qtm_vucode`) | 14 068 |
| `0x3674..0x4C18` | `qtm_play` | 5 540 |
| `0x4C18..0x5624` | `qtm_song` | 2 572 |
| `0x5624..0x6658` | `qtm_dma` | 4 148 |
| `0x6728..0x6800` | `qtm_data` | 216 |

The one region not yet covered is `0x6658..0x6728` (208 bytes: `r0_div_r1`, `divloo`,
`armcheck`, `addpclr4`), which is assembled inline by the driver's `PROCassm` between
`FNassm_dma` and `FNassm_tables`. That belongs to Phase 4's top-level file.

The five generators were handled as §3 intended — frozen, not re-implemented:

1. **`FNcompress`** — the 26 outputs come from `ref/helptext.txt`, keyed by source line.
   Each was located in `ref/QTMModule` before being frozen, which is what makes this safe.
2. **`LOGdata`** — `.incbin` of the original 256-byte file, staged to `src/LOGdata`.
3. **`PROCinit_amiperiods`** — the 16 × 72 × 2 = 2304-byte period tables, transcribed from
   the driver's `DCW` block to `src/shared/qtm_amiperiods.asm`.
4. **`PROCinit_offsets` / `FNtableoffsets`** — already frozen in Phase 0(b).
5. **Post-assembly patches** — `helpdate` and `helptextversion` are emitted as the bytes
   observed in the shipped module, since `PROCvalidatecrc` stamps `MID$(TIME$,5,11)` and a
   build today would differ. The net effect of the beta patches is small and worth
   recording: `helpdate`'s leading `" ("` becomes `"b ("`, and `"v"+ver$` written at
   `helptextversion+8` consumes one of the six `CHR$31` padding bytes.

Two reservations in the source (`P%+=n`) are filled in after assembly rather than left as
zeros, so they are substituted rather than skipped: `loglintab` (256) and `amigaperiodz`
(2304). Any future `P%+=` site should be checked against the module before assuming it is
a genuine gap.

One converter bug worth noting, because it was silent: the data directives can run
straight into their operand with no separator — the period tables are written
`DCW1712:DCW1616:...` — and the general mnemonic rule read `DCW1712` as a single
identifier, dropping 158 of the 1152 values. Only the size check (2304 bytes) caught it.

## 5e. Phases 4 and 5 outcome — byte-identical

```
size   built 26624, reference 26624  OK
crc    built 9AA00EE5, expected 9AA00EE5  OK
IDENTICAL -- acceptance test passed.
```

**All five §5 acceptance criteria are met.** The build is byte-identical, and the module
loads and plays under Arculator. (Which config, and RPCEmu, were not separately recorded —
byte-identity makes wider testing a formality rather than a risk, but it has not been done.)

Phase 6 is the remaining work.

**`src/shared/qtm.asm` is generated, not written.** `PROCassm`'s body *is* the module's table of
contents — its `FNassm_*` calls are what fix the layout order — so the top level is a
translation of it (`tools/mktoplevel.py`), with those calls mapped onto `.include`. Nothing
about the order is asserted by hand.

`.org 0` with `-Fbin` reproduces both halves of the original's arrangement: `P%=0` makes
addresses module-relative, and the pre-zeroed 63K buffer makes every reserved region zero.
No explicit `.skip` padding was needed, and vasm's fill byte never came into it — the only
gaps are the ones the source reserves.

Everything under `src/` is generated from `ref/`. `python build.py` recreates it all and
verifies; `python build.py --check` verifies without regenerating. A from-scratch rebuild
after deleting `src/` reproduces the module exactly, so the pipeline — not just the current
output — is what has been checked.

Two things this phase turned up:

- **A folded constant exceeded 32 bits.** `QTM_Mod` has `TST R0,#%1110<<29`, i.e.
  `0x1C0000000`. BASIC wraps to 32 bits and so does vasm, which is why the output was
  already correct, but vasm warned. Folded values are now wrapped explicitly.
- **`P%+=n` is not always a gap.** An over-broad rule that treated all `P%`/`O%`/`L%`
  assignments as bookkeeping swallowed the two data fills, and the build came out 2560
  bytes short — exactly `amigaperiodz` (2304) plus `loglintab` (256). The size check caught
  it immediately; a byte diff alone would have been far less obvious.

Three `FNlong_adr` sites remain deferred, all inside `qtmrast` blocks this variant
excludes. They are Phase 6 work, not gaps in this build.

## 5f. Phase 6 outcome — all four variants byte-identical

```
release  26624 bytes  crc 9AA00EE5  IDENTICAL
rm24     27152 bytes  crc 94B863BD  IDENTICAL
rm48     27028 bytes  crc D7CB9D54  IDENTICAL
alpha    26824 bytes  crc BE7CF127  IDENTICAL
```

Only the release build has a published binary; the other three references were captured
from the original BASIC alongside their listings (`tools/emulator/README.md`). Each
listing was validated against its own module first — reconstructing from it mismatches in
**0 bytes** across the ~75% it covers, the same check that validated the release capture.

`tools/variants.py` holds the four configurations and the paths to their artefacts, and
everything downstream takes `--variant`.  The translated assembly is **shared**: see
§5g.

**`alphatest` is a real code variant**, not a changed help string as §6 implied. It adds
ten instrumentation counters *inside* the DMA fill path, a `swi_qtmdebug` entry and a
`Debug` command — 200 bytes in total, and of some interest for the mixer work since it
instruments the hot loop.

The 22 `FNlong_adr` call sites are split across the variants rather than shared; each
build assembles its own subset and the rest are reported as not assembled:

| Sites | Gated by | In |
|---|---|---|
| 19 | always | all builds |
| `qtmrmtext` | `qtmrast` | rm24, rm48 |
| 2 × `CIAhandler` | `NOT qtmrast` | release, alpha |
| `a2_jumptable`, `unroll_a2_DMA` | `alphatest` | alpha |

The post-assembly help patches are no longer hardcoded. They are read out of each
variant's own reference binary at generation time, since both the version letter (`b`
beta, `a` alpha, `r` RasterMan) and the stamped build date vary. The captured references
carry `05 Aug 1992` — the emulator's clock — which is a good illustration of why §0.4's
"freeze the observed bytes" rule matters more than reproducing the patch logic.

## 5g. One source, four builds

The first cut of Phase 6 gave each variant its own copy of every file.  That was not
inherent -- five of the seven were already identical, and the rest differed for three
reasons, each fixable:

1. **Constants were folded at conversion time.**  Expressions are now parsed to an AST and
   *re-rendered* as fully parenthesised vasm expressions, so `dmarep<<8 OR 6` stays an
   expression and takes its value from the variant's `.equ`.  Only floats and `ASC` are
   still folded, because vasm cannot express them.  Full parenthesisation also removes any
   dependence on vasm's precedence matching BASIC's -- it mostly does, but BASIC gives
   `EOR` the same precedence as `OR` while C-like grammars put `^` between `&` and `|`.

2. **`FNlong_adr` took its ADD/SUB direction from the listing.**  It is now computed by
   vasm branchlessly: `(d>>31)` is 0 or -1, which gives both the opcode bit and, via
   `(d^(d>>31))-(d>>31)`, the magnitude.  Note the sign and magnitude come from *different*
   expressions, because the original's do -- `gap%=ABS(addr%-P%-8)` but
   `IF addr%<P% THEN SUB` -- so a target 0-7 bytes ahead is an ADD of a magnitude derived
   from a negative difference.  Sites inside a switched-off `.if` are emitted normally and
   skipped by vasm, so nothing is variant-specific any more.

3. **Build-time BASIC variables never reached vasm.**  `dmarep` was resolved during
   conversion; it is now emitted as a conditional `.equ`, mirroring
   `IF qtmrast% THEN dmarep=dma/4 ELSE dmarep=dma`.

What remains genuinely per-variant is 8 KB against 326 KB shared:

```
src/shared/      qtm.asm, the seven translated files, qtm_amiperiods.asm,
                 swis.h.asm (the union across variants), LOGdata
src/<variant>/   qtm_offsets.h.asm  -- the switches and offsets
                 stamp_*.asm        -- the version stamps, and one string
                                       built with STR$ from a build constant
```

`build.py` regenerates `src/shared/` for every variant and **fails if the result differs**,
so a variant-specific leak cannot pass unnoticed.  That check earned its place immediately:
it caught `qtm_mod.asm` still varying by one line after the first attempt looked complete.

## 6. Effort and sequencing note

The v1.49b choice matters enormously. Porting **v1.45** would have meant reproducing
assembly-time unrolling driven by BASIC `FOR` loops, with 63 KB of output to match; porting
**v1.49b** is a rule-driven text transformation plus five frozen data blobs. If the aim is a
vasm QTM, v1.49b is the version to do it on.

Phase 0 is roughly a third of the total effort and should not be short-cut — without the
golden listing, every immediate-encoding mismatch is a blind bisect through a 26 KB binary.

Once byte-identity is achieved, the payoff for the wider project is direct: QTM's mixer
becomes editable in the same toolchain as `LSP_ARM250` and `rasterman-vasm`, which is the
precondition for the inner-loop experiments in `ANALYSIS.md` §9.4.
