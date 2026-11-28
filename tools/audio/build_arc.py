"""Build the Arc test programs into build/ as RISC OS Absolutes (name,ff8).

python tools/audio/build_arc.py
"""
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parent.parent
VASM = REPO / "tools" / "vasmarm_std_win32.exe"
OUT = REPO / "build"


def main():
    sys.path.insert(0, str(HERE))
    import codesweep
    import soundtests
    codesweep.write()
    soundtests.write()
    OUT.mkdir(exist_ok=True)
    for name in ("codesweep", *soundtests.TESTS):
        src = HERE / "arc" / f"{name}.asm"
        dst = OUT / f"{name},ff8"
        r = subprocess.run([str(VASM), "-m2", "-Fbin", "-quiet", "-L", str(OUT / f"{name}.lst"),
                            "-o", str(dst), src.name], cwd=src.parent)
        if r.returncode:
            return r.returncode
        print(f"{dst} ({dst.stat().st_size} bytes)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
