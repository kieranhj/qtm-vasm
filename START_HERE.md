# qtm-vasm: start here

A byte-identical port of QTM v1.49b (Steve Harrison's MOD player module for the Acorn
Archimedes) from tokenised BBC BASIC V assembler to vasm. A modified source form, not an
official QTM release. Port + tooling.

| | |
|---|---|
| GitHub | https://github.com/kieranhj/qtm-vasm (public) |
| Upstream | QTM v1.49b by Steve Harrison, http://www.pi-star.co.uk/qtm (original in `ref/`) |
| Local path | D:\archie\mine\qtm-vasm (moved from OneDrive\Archie\Repos\qtm-vasm on 2026-11-22) |
| Branch | main; other: turbo-measurement |
| Last commit | 2026-08-10: Summarise what the mixer measurements found, and rank what is left |

## What's in here
- `build.py`: regenerates `src\` from `ref\` and verifies each variant byte for byte.
- `tools\`: detokeniser, BASIC-to-vasm converter, variants, verify, checkfile, bundled vasm.
- `ref\`: original tokenised sources, detokenised text, QTMModule, golden listings, docs.
- `src\shared\` + `src\<variant>\`: the generated port (do not edit; edit the tools).
- `PLAN.md` (plan and phase findings), `OPTIMISATION.md` (mixer measurements and ranked ideas).

## Build and run
- `make`: `python build.py` (works, 2026-11-22): all four variants (release, rm24, rm48, alpha)
  byte-identical, output `build\qtm-<variant>.bin`. `make check` verifies without regenerating.
- Needs Python 3 only; vasm is `tools\vasmarm_std_win32.exe`.
- `build\qtm-gg.bin` (the guard-gap build Nemesis loads) comes from `build.py gg` on the
  turbo-measurement branch; main's `make` leaves it alone.

## Local changes
- Working tree clean; no stashes. turbo-measurement (pushed) is 11 commits ahead of main: the
  mixer measurements and the QTM Turbo / guard-gap builds (last: 2026-08-10 "Step 5: build QTM
  Turbo, and measure it as a regression").
- PLAN.md names the source zip at `C:\Users\khcon\OneDrive\Retro\Archie\Contributed\Steve\QTMv1-49b.zip` (not moved).

## Status and next steps
- Goal achieved: all four variants byte-identical; the release module plays under Arculator.
- Next is optimisation of the mixer: OPTIMISATION.md section 7 ranks what is left.

## See also
- README.md, PLAN.md, OPTIMISATION.md, tools/emulator/README.md.
- D:\archie\mine\Nemesis (uses qtm-gg.bin), D:\archie\mine\rasterman-vasm.
