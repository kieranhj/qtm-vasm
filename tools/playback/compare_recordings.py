"""Compare recordings of the same song from !QTMOrig and !QTMBest.

python tools/playback/compare_recordings.py orig.wav best.wav [--out prefix]

1. Aligns the two by cross-correlating their low-passed envelopes, and keeps the overlap.
2. Matches levels in the midrange (200 Hz-1 kHz), which the prep leaves alone, and reports
   the raw level difference too.
3. Long-term spectra (Welch, both channels), and their difference by band: what the best
   build changes, as heard.
4. The 16-24 kHz band, where QTM's images land at 32 us and where 24 us moves them out of.
Writes <prefix>.png and <prefix>.json.
"""
import argparse
import json
import sys
from pathlib import Path

import numpy as np
from scipy.signal import butter, correlate, sosfiltfilt, welch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "audio"))
from analyse_codesweep import load                  # noqa: E402

BANDS = [(20, 100), (100, 200), (200, 500), (500, 1000), (1000, 2000), (2000, 3000),
         (3000, 4000), (4000, 6000), (6000, 8000), (8000, 10000), (10000, 13000),
         (13000, 16000), (16000, 20000), (20000, 24000)]


def envelope(x, sr):
    m = sosfiltfilt(butter(4, 1500, "low", fs=sr, output="sos"), x.mean(axis=1))
    b = sr // 100
    k = len(m) // b
    return np.sqrt(np.mean(m[:k * b].reshape(k, b) ** 2, axis=1)), b


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("orig")
    ap.add_argument("best")
    ap.add_argument("--out")
    a = ap.parse_args()
    sr, xo = load(a.orig)
    sr2, xb = load(a.best)
    assert sr == sr2
    eo, b = envelope(xo, sr)
    eb, _ = envelope(xb, sr)
    c = correlate(eb - eb.mean(), eo - eo.mean(), mode="full")
    lag = (np.argmax(c) - (len(eo) - 1)) * b           # best is `lag` samples later
    if lag >= 0:
        xb = xb[lag:]
    else:
        xo = xo[-lag:]
    n = min(len(xo), len(xb))
    xo, xb = xo[:n], xb[:n]
    eo, _ = envelope(xo, sr)
    eb, _ = envelope(xb, sr)
    k = min(len(eo), len(eb))
    corr = float(np.corrcoef(eo[:k], eb[:k])[0, 1])

    f, Po = welch(xo, sr, nperseg=8192, axis=0)
    _, Pb = welch(xb, sr, nperseg=8192, axis=0)
    Po, Pb = Po.mean(axis=1), Pb.mean(axis=1)
    mid = (f >= 200) & (f < 1000)
    match = 10 * np.log10(Po[mid].sum() / Pb[mid].sum())
    raw = 10 * np.log10(np.mean(xb ** 2) / np.mean(xo ** 2))
    rows = []
    for lo, hi in BANDS:
        s = (f >= lo) & (f < hi)
        rows.append(dict(lo=lo, hi=hi,
                         orig_db=float(10 * np.log10(Po[s].sum() / Po.sum())),
                         best_db=float(10 * np.log10(Pb[s].sum() / Po.sum()) + match),
                         change_db=float(10 * np.log10(Pb[s].sum() / Po[s].sum()) + match)))
    print(f"aligned: best starts {lag / sr * 1000:+.0f} ms later; overlap {n / sr:.1f} s; "
          f"envelope correlation {corr:.3f}")
    print(f"level: best is {raw:+.1f} dB overall; {-match:+.1f} dB in 200 Hz-1 kHz "
          f"(the comparison below is matched there)")
    print("\n   band Hz         orig share   change with best")
    for r in rows:
        print(f"  {r['lo']:5d}-{r['hi']:<5d}      {r['orig_db']:6.1f} dB      {r['change_db']:+6.1f} dB")

    out = Path(a.out) if a.out else Path(a.best).with_name(Path(a.best).stem + "-vs-orig")
    out.with_suffix(".json").write_text(json.dumps(dict(
        orig=a.orig, best=a.best, lag_ms=lag / sr * 1000, overlap_s=n / sr, envelope_corr=corr,
        raw_level_db=raw, mid_match_db=match, bands=rows), indent=1))
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    fig, ax = plt.subplots(2, 1, figsize=(9, 7), sharex=True)
    ax[0].semilogx(f[1:], 10 * np.log10(Po[1:]), color="#f47230", lw=1, label="QTM as shipped (32 us)")
    ax[0].semilogx(f[1:], 10 * np.log10(Pb[1:]) + match, color="#257de0", lw=1, label="best (24 us), level-matched")
    ax[0].set_ylabel("power (dB)")
    ax[0].legend()
    d = 10 * np.log10(Pb[1:] / Po[1:]) + match
    sm = np.convolve(d, np.ones(9) / 9, mode="same")
    ax[1].semilogx(f[1:], sm, color="#257de0", lw=1.5)
    ax[1].axhline(0, color="#888", lw=0.8)
    ax[1].set_ylabel("best minus shipped (dB)")
    ax[1].set_xlabel("frequency (Hz)")
    ax[1].set_ylim(-25, 15)
    for axx in ax:
        axx.grid(True, which="both", color="#eee")
    fig.suptitle(f"{Path(a.best).name} against {Path(a.orig).name}")
    fig.tight_layout()
    fig.savefig(out.with_suffix(".png"), dpi=110)
    print(f"\nwrote {out}.png and .json")


if __name__ == "__main__":
    main()
