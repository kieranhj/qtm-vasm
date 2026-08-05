# Plan: porting QTM v1.49b from tokenised BBC BASIC V to vasm

**Goal:** a vasm build of QTM v1.49b that is byte-identical to the released `QTMModule`
(26 624 bytes, dated 19 Mar 2023) shipped in `QTMv1-49b.zip`.

Source: `C:\Users\khcon\OneDrive\Archie\Steve\QTMv1-49b.zip` → `Source/` (10 tokenised BASIC
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

```
qtm-vasm/
  tools/
    detok.py              # BASIC V → text (exists, promote)
    bas2vasm.py           # Phase 1 rule-driven converter
    verify.py             # cmp + CRC + listing-correlated diff
  ref/
    QTMModule             # shipped 1.49b binary, the acceptance target
    listing.txt           # golden per-line listing from the BASIC build
    symbols.txt           # dumped offset constants
    helptext.bin          # frozen FNcompress outputs
  src/
    qtm.asm               # top level: config .equs + includes in assembly order
    swis.h.asm            # 33 SWI numbers
    qtm_offsets.h.asm     # frozen .equ constants
    macros.h.asm          # FNlong_adr / FNmega_adr / FNdiv / FNAUdiv
    qtm_mod.asm  qtm_play.asm  qtm_song.asm  qtm_dma.asm
    qtm_timer.asm  qtm_vucode.asm  qtm_data.asm
    LOGdata               # .incbin
  build.bat / Makefile
```

---

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
