"""Build the two comparison apps for one measured machine.

python tools/playback/build_apps.py [--machine a3020] [--hostfs DIR]

  build/playback/<machine>/apps/!QTMBest  prepared MODs, this machine's tables, 24 us
  build/playback/<machine>/apps/!QTMOrig  the original MODs and QTM exactly as shipped
  build/playback/<machine>/qtmcompare-<machine>,ddc  both, in a !Spark archive, inside a
                                          folder QTM<model number> (e.g. QTM3010)

Both carry QTM 1.49b (ref/QTMModule). Host filenames use the ,xxx filetype suffix
(HostFS / ArcEm convention): !Run,feb  !RunImage,ff8  QTMModule,ffa  songs ,ffd.
--hostfs also copies both apps into a HostFS directory, for Arculator.
"""
import argparse
import json
import shutil
import subprocess
import sys
from pathlib import Path

import prep_best

HERE = Path(__file__).resolve().parent
REPO = HERE.parent.parent
VASM = REPO / "tools" / "vasmarm_std_win32.exe"
PLAYBACK = REPO / "build" / "playback"
OUT = PLAYBACK

SONGS = [
    ("Push", Path(r"D:/bitshifters/push/data/music/particles_15.mod")),
    ("STNICCC", Path(r"D:/bitshifters/stniccc-archie/data/music/Arc-NIC10.mod")),
    ("SpaceTrip", Path(r"D:/bitshifters/allstar-parts/data/music/space_trip_fatman_10.mod")),
    ("Mikroreise", Path(r"D:/bitshifters/mikroreise/data/music2/mikroreise.mod")),
]

RUN = """| !Run for !{app}
Set {app}$Dir <Obey$Dir>
RMLoad <{app}$Dir>.QTMModule
WimpSlot -min 32K -max 32K
Run <{app}$Dir>.!RunImage
"""


def assemble(best, dst):
    r = subprocess.run([str(VASM), "-m2", "-Fbin", "-quiet", "-D", f"BEST={best}", "-I", str(OUT),
                        "-L", str(OUT / f"player{best}.lst"), "-o", str(dst), "player.asm"],
                       cwd=HERE / "arc")
    if r.returncode:
        raise SystemExit("assembly failed")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--machine", default="a3020")
    ap.add_argument("--hostfs")
    a = ap.parse_args()
    global OUT
    OUT = PLAYBACK / a.machine
    OUT.mkdir(parents=True, exist_ok=True)
    m = prep_best.load_machine(a.machine)
    (OUT / "banner.inc").write_text(
        f'\t.ascii\t"QTM best playback: {m["short"]} tables, 24 us,"\n'
        '\t.byte\t13,10\n'
        '\t.ascii\t"samples corrected for its response and converted to its measured DAC levels"\n',
        newline="\n")
    (OUT / "voltab.bin").write_bytes(prep_best.voltable(m))
    apps = OUT / "apps"
    if apps.exists():
        shutil.rmtree(apps)
    report = {}
    for app, best in (("QTMBest", 1), ("QTMOrig", 0)):
        d = apps / f"!{app}"
        d.mkdir(parents=True)
        (d / "!Run,feb").write_text(RUN.format(app=app), newline="\n")
        assemble(best, d / "!RunImage,ff8")
        shutil.copy(REPO / "ref" / "QTMModule", d / "QTMModule,ffa")
        for name, src in SONGS:
            if best:
                report[name] = prep_best.prepare(src, d / f"{name},ffd", a.machine)
            else:
                shutil.copy(src, d / f"{name},ffd")
    (OUT / "prep-report.json").write_text(json.dumps(dict(machine=m["label"], songs=report), indent=1))
    print(f"built {apps}")
    vt = list((OUT / "voltab.bin").read_bytes())
    print("volume table (subtract per MOD volume, every 8th):", vt[::8])
    folder = OUT / ("QTM" + "".join(ch for ch in a.machine if ch.isdigit())[:4])
    if folder.exists():
        shutil.rmtree(folder)
    folder.mkdir()
    for app in ("QTMBest", "QTMOrig"):
        shutil.copytree(apps / f"!{app}", folder / f"!{app}")
    sys.path.insert(0, str(REPO / "tools"))
    import spark
    archive = OUT / f"qtmcompare-{a.machine},ddc"
    spark.pack(str(folder), str(archive))
    print(f"{archive} ({archive.stat().st_size:,} bytes)")
    if a.hostfs:
        for app in ("QTMBest", "QTMOrig"):
            dst = Path(a.hostfs) / f"!{app}"
            if dst.exists():
                shutil.rmtree(dst)
            shutil.copytree(apps / f"!{app}", dst)
        print(f"copied to {a.hostfs}")


if __name__ == "__main__":
    main()
