# Measurement harnesses

Guest-side helpers for the optimisation work, driven from the Arculator MCP server.
Results and method: [`../../MEASUREMENTS.md`](../../MEASUREMENTS.md).

| file | what |
|---|---|
| `setup.bas` | load a song, start it, print the module base / workspace / jump table |
| `paths.bas` | play N tunes for 5 s each, write the `dma_*` path counters to `res` |
| `step1-paths.csv` | raw output of `paths.bas`, step 1 |

Both are plain text with CR line endings, to be `*Exec`'d into BASIC — copy into the
machine's HostFS sandbox with a `,fff` (Text) suffix, then `*Exec HostFS::HostFS.$.<name>`
followed by `RUN`.

## Gotchas

**Do not type `"` through `type_text`.** The UK keyboard mapping emits `@`, so
`SYS "QTM_Stop"` silently becomes `SYS @QTM_Stop@` and fails with *Unknown or missing
variable*. Anything quoted must come from a file; for typed commands use numeric SWI
numbers instead:

    QTM_Load &47E40   QTM_Start &47E41   QTM_Stop  &47E42
    QTM_Clear &47E44  QTM_Pos   &47E46   QTM_SetSampleSpeed &47E49
    QTM_Debug &47E63  (alpha build only)

**Find the module at runtime.** `OS_Module 18` does not match on "QTM". Instead call
`SYS &47E63 TO J%` — the alpha debug SWI returns `a2_jumptable` — and subtract its listing
offset: `base = J% - &64D8`. The eight words at `J%` are the addresses of the runtime-
unrolled mixer routines, which is where the mixer's cycles actually are.

**Restart deterministically** with `SYS &47E42:SYS &47E46,0,0:SYS &47E41` before every
measurement window, or successive windows measure different parts of the song.

**MODE 15 needs more screen memory** than the default: `SYS &2A,2,&30000` first
(`OS_ChangeDynamicArea` on area 2), otherwise RISC OS silently keeps the current mode.
