# Capturing the golden listing (Phase 0a)

This is the one Phase 0 artefact that cannot be derived on the host: it has to come
out of the original BBC BASIC assembler. Phase 0(b) and 0(c) turned out to be
derivable and self-checking, so this is the only step needing RISC OS.

The result, `ref/listing.txt`, is what turns "the 26 KB binary differs somewhere"
into "line N assembled differently". `tools/verify.py` reads it automatically.

## Why patching `opt%` is safe

`ListPtch` changes the assembly pass from `FOR opt%=12 TO 14 STEP 2` to
`13 TO 15`, i.e. it sets OPT bit 0 (listing) on both passes. This does **not**
change the generated code, which is worth stating because `FNlong_adr` branches
on `opt%`:

```basic
IF (opt% AND 3)=0 OR (opt% AND 3)=1 THEN [OPT opt%:MOV R0,R0:MOV R0,R0:]:=opt%
```

That test distinguishes pass 1 from pass 2 via OPT bit 1 (error reporting), and
bit 0 does not disturb it:

| pass | original | `AND 3` | patched | `AND 3` | branch taken |
|---|---|---|---|---|---|
| 1 | 12 | 0 | 13 | 1 | NOP placeholder — same |
| 2 | 14 | 2 | 15 | 3 | real ADD/SUB pair — same |

Both passes are listed, so each address appears twice. `verify.py` keys its
table by address, so the second (final) pass wins, which is the one that matters.

## Known gaps in the listing

`FNmrs`, `FNmsr` and `FNmrc` do not go through `[OPT`; they poke the encoded word
straight into memory:

```basic
IF (opt% AND 1<<2)=(1<<2) THEN addr%=O%:O%+=4 ELSE addr%=P%
...
!addr%=mc%
```

So the 24 words they emit (10 + 11 + 3) will be **absent** from the listing. Gaps
at those addresses are expected, not a capture failure. `FNmega_adr`, `FNAUdiv`
and `FNmcr` are defined but never called, so they contribute nothing.

## Steps

1. Copy `ref/source-tokenised/` into the Arculator HostFS share, e.g. to
   `Repos/arculator/hostfs/QTM/`, and copy `ListPtch` in beside it.
   Keep the files binary-identical — they are tokenised BASIC, not text.

2. Boot Arculator with a RISC OS 3.11 config (`configs/A3000 4mb.cfg` or
   `ARM3.cfg`; the build needs a 320K wimpslot, so 4 MB is comfortable).

3. Open a task window / command line and, from the QTM directory:

   ```
   *Dir  <wherever the QTM files landed>
   *Set  QTMAssemble$Dir @
   *WimpSlot -min 320K -max 320K
   *BASIC
   ```

   `@` is the current directory, which is what the sources expect
   `QTMAssemble$Dir` to point at.

4. At the BASIC `>` prompt:

   ```
   LOAD "QTMv1<A>49"
   *Exec ListPtch
   RUN
   ```

   `<A>` is the top-bit-set character in the real filename — use tab-completion
   or copy the name rather than typing it. `*Exec` feeds the patch lines in as
   if typed, so BASIC's own tokeniser does the work and no tokeniser is needed
   on the host.

   Do **not** save the program afterwards — the tokenised originals under `ref/`
   must stay unaltered.

5. At the `Press R to build ... RasterMan edition` prompt, **wait** (2 seconds).
   Pressing R selects the wrong variant; the target is the default build
   (`qtmrast%=FALSE`, `dmachoice=32`, `maxchans=8`).

6. When it asks `Save module name:`, enter anything, e.g. `Built`.

7. Copy the generated `listing` file back to `ref/listing.txt` on the host.
   It is text; converting LF/CRLF is harmless, but do not let anything touch
   the tokenised sources on the way back.

## Checking the capture

The module built inside the emulator will **not** match `ref/QTMModule`: with
`betatest%=TRUE`, `PROCvalidatecrc` stamps today's date into the help string
(PLAN.md §0.4). Expect a difference around offset `0x2AD7`, and only there.
That difference is in fact a useful confirmation that the run behaved as
analysed. The listing itself is unaffected, because the date is patched in after
assembly.
