"""Smoke-test the two apps in headless Arculator: run each, play a song, capture audio.

python tools/playback/emulate_apps.py [--song 1] [--seconds 20]
Writes build/playback/<app>-song<n>.wav and .png.
"""
import argparse
import shutil
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parent.parent
sys.path.insert(0, str(REPO / "tools" / "audio"))
import emulate as E                                 # noqa: E402


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--song", type=int, default=1)
    ap.add_argument("--seconds", type=float, default=20)
    ap.add_argument("--config", default="a3020-riscos311")
    ap.add_argument("--machine", default="a3020")
    a = ap.parse_args()
    out = REPO / "build" / "playback" / a.machine
    for app in ("QTMBest", "QTMOrig"):
        pool = E.MachinePool(str(E.ROOT / "arculator-headless.exe"), str(E.ROOT), str(out / "arculator"))
        mid, m = pool.create(config=a.config)
        try:
            dst = Path(m.hostfs) / f"!{app}"
            if dst.exists():
                shutil.rmtree(dst)
            shutil.copytree(out / "apps" / f"!{app}", dst)
            E.run_ms(m, 12000)
            E.tap(m, E.keymap.SCANCODES["f12"])
            E.run_ms(m, 500)
            E.type_line(m, f"HostFS::HostFS.$.!{app}")
            E.run_ms(m, 3000)
            m.command_text("sound start")
            E.tap(m, *E.keymap.char_to_keystroke(str(a.song)))
            E.run_ms(m, int(a.seconds * 1000))
            m.command_text("sound stop")
            wav = out / f"{app}-song{a.song}.wav"
            wav.write_bytes(E.png.arsn_to_wav(m.command("sound fetch")))
            (out / f"{app}-song{a.song}.png").write_bytes(E.png.arfb_to_png(m.command("screenshot")))
            E.tap(m, *E.keymap.char_to_keystroke("q"))
            E.run_ms(m, 1000)
            print(f"{app}: {wav}")
        finally:
            pool.destroy_all()


if __name__ == "__main__":
    main()
