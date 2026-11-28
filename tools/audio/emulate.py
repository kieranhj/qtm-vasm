"""Run an Arc test program in headless Arculator and capture what it plays as a WAV.

python tools/audio/emulate.py codesweep [--config a3000-riscos311] [--seconds 140]

Writes build/<name>-arculator.wav and build/<name>-arculator.png (a screenshot at the
end). Uses the headless build and Python client in D:/archie/mine/arculator (set
ARCULATOR_ROOT to point elsewhere). This checks the program and the analyser end to end:
Arculator's log-to-linear table is the datasheet curve, so the analysis of this capture
should come back matching the model exactly, apart from Arculator's own output filter.
"""
import argparse
import os
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
ROOT = Path(os.environ.get("ARCULATOR_ROOT", r"D:\archie\mine\arculator"))
sys.path.insert(0, str(ROOT / "mcp"))

from arculator_mcp import keys as keymap          # noqa: E402
from arculator_mcp import png                     # noqa: E402
from arculator_mcp.client import MachinePool      # noqa: E402


def run_ms(m, ms):
    while ms > 0:
        step = min(ms, 1000)
        m.command_json(f"run_us {step * 1000}")
        ms -= step


def tap(m, scancode, shift=False):
    if shift:
        m.command_text(f"key {keymap.SCANCODES['lshift']} 1")
    m.command_text(f"key {scancode} 1")
    run_ms(m, 40)
    m.command_text(f"key {scancode} 0")
    if shift:
        m.command_text(f"key {keymap.SCANCODES['lshift']} 0")
    run_ms(m, 40)


def type_line(m, text):
    for ch in text:
        tap(m, *keymap.char_to_keystroke(ch))
    tap(m, keymap.SCANCODES["return"])


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("name")
    ap.add_argument("--config", default="a3000-riscos311")
    ap.add_argument("--seconds", type=float, default=140)
    a = ap.parse_args()

    prog = REPO / "build" / f"{a.name},ff8"
    work = REPO / "build" / "arculator"
    pool = MachinePool(str(ROOT / "arculator-headless.exe"), str(ROOT), str(work))
    mid, m = pool.create(config=a.config)
    try:
        (Path(m.hostfs) / prog.name).write_bytes(prog.read_bytes())
        print(f"booting {a.config}...")
        run_ms(m, 12000)
        tap(m, keymap.SCANCODES["f12"])
        run_ms(m, 500)
        m.command_text("sound start")
        type_line(m, f"HostFS::HostFS.$.{a.name}")
        print(f"running {a.name} for {a.seconds:.0f} s of emulated time...")
        run_ms(m, int(a.seconds * 1000))
        m.command_text("sound stop")
        data = m.command("sound fetch")
        wav = REPO / "build" / f"{a.name}-arculator.wav"
        wav.write_bytes(png.arsn_to_wav(data))
        rate, ch, frames, _ = png.decode_arsn(data)
        print(f"{wav} ({frames / rate:.1f} s at {rate} Hz)")
        shot = REPO / "build" / f"{a.name}-arculator.png"
        shot.write_bytes(png.arfb_to_png(m.command("screenshot")))
        print(shot)
    finally:
        pool.destroy_all()


if __name__ == "__main__":
    main()
