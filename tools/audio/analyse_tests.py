"""Analyse recordings of sound tests 2-5 (tools/audio/soundtests.py).

python tools/audio/analyse_tests.py <test> recording.wav [--phases 1,2,4]

<test> is freqresp, noise, slots or stereo. Writes <recording>.json (and .png for freqresp).
--phases names the phases that actually ran (1-based), if the program skipped any; it
prints which it skipped.

Each phase begins and ends with a 1 s full-scale square at about 1 kHz. The analyser finds
the markers as the stretches of sound 0.6-1.15 s long (tones are 0.6 s, steps run
together), takes the phase's real sample rate from the marker pitch (it follows the VIDC
clock, so the screen mode) and its start from the first marker's onset. Levels are read
with a flat-top window, which is amplitude-accurate wherever the tone falls between bins.
"""
import argparse
import json
from pathlib import Path

import numpy as np
from scipy.signal import butter, get_window, sosfiltfilt, welch

import vidc
from analyse_codesweep import load

HERE = Path(__file__).resolve().parent


def runs(active, min_len, max_len):
    d = np.diff(np.r_[0, active.astype(int), 0])
    st, en = np.flatnonzero(d == 1), np.flatnonzero(d == -1)
    return [(a, b) for a, b in zip(st, en) if min_len <= b - a <= max_len]


def tone_level(x, sr, f, tol=0.01):
    """Peak amplitude of the strongest component within f*(1 +- tol), flat-top window."""
    w = get_window("flattop", len(x))
    pad = 4 * len(x)
    S = np.abs(np.fft.rfft((x - x.mean()) * w, pad)) * 2 / w.sum()
    fq = np.fft.rfftfreq(pad, 1 / sr)
    band = (fq >= f * (1 - tol) - 2) & (fq <= f * (1 + tol) + 2)
    k = np.flatnonzero(band)[np.argmax(S[band])]
    return float(S[k]), float(fq[k])


def precise_freq(x, sr, f_guess, tol):
    """Frequency of the strongest component near f_guess: Hann window, 16x zero padding,
    parabolic interpolation on the log magnitude."""
    w = np.hanning(len(x))
    pad = 16 * len(x)
    S = np.abs(np.fft.rfft((x - x.mean()) * w, pad))
    fq = np.fft.rfftfreq(pad, 1 / sr)
    band = np.flatnonzero((fq > f_guess * (1 - tol)) & (fq < f_guess * (1 + tol)))
    k = band[np.argmax(S[band])]
    a, b, c = np.log(S[k - 1:k + 2] + 1e-30)
    return float(fq[k] + 0.5 * (a - c) / (a - 2 * b + c) * (fq[1] - fq[0]))


def find_phases(x, sr, man, only):
    blk = int(0.01 * sr)
    n = len(x) // blk
    # detect in a 300 Hz-5 kHz band: the coupling capacitors settling after a
    # change of DC level, and the carrier at fs (slots test at 48 us), would otherwise join
    # a phase into one long stretch
    sos = butter(4, [300, 5000], "bandpass", fs=sr, output="sos")
    xb = sosfiltfilt(sos, x[:n * blk], axis=0).reshape(n, blk, -1)
    # AC level per 10 ms block (the mean removed: Arculator passes DC, the board does not),
    # left plus right, so a phase's stereo position doesn't change its level
    r = xb.std(axis=1).sum(axis=1)
    floor = np.percentile(r, 5)
    active = r > max(floor * 8, r.max() * 1e-3)
    phases = [p for i, p in enumerate(man["phases"]) if only is None or (i + 1) in only]
    f_nom = phases[0]["fs_nominal"] / (2 * phases[0]["mark_half"])
    cand = []
    for a, b in runs(active, 60, 115):
        seg = x[(a + 10) * blk:(b - 10) * blk].mean(axis=1)
        lvl = float(np.median(r[a + 10:b - 10])) if b - a > 30 else 0.0
        S = np.abs(np.fft.rfft(seg * np.hanning(len(seg))))
        fq = np.fft.rfftfreq(len(seg), 1 / sr)
        f_peak = fq[np.argmax(S)]
        if 0.7 * f_nom < f_peak < 1.6 * f_nom:
            cand.append((a, b, lvl))
    if not cand:
        raise SystemExit("found no markers")
    top = max(c[2] for c in cand)
    marks = [c for c in cand if c[2] > 0.7 * top]
    if len(marks) != 2 * len(phases):
        raise SystemExit(f"found {len(marks)} markers, expected {2 * len(phases)} for "
                         f"{len(phases)} phases. If the program skipped a phase, pass --phases.")
    out = []
    for i, ph in enumerate(phases):
        (a0, a1, _), (b0, b1, _) = marks[2 * i], marks[2 * i + 1]
        f_m = ph["fs_nominal"] / (2 * ph["mark_half"])
        pitches = [precise_freq(x[(a + 15) * blk:(b - 15) * blk].mean(axis=1), sr, f_m, 0.6)
                   for a, b in ((a0, a1), (b0, b1))]
        fs = np.mean(pitches) * 2 * ph["mark_half"]
        lo, hi = (a0 - 5) * blk, (a0 + 20) * blk
        env = np.abs(x[lo:hi] - x[lo:hi].mean(axis=0)).max(axis=1)
        k = int(0.001 * sr)
        e = np.convolve(env, np.ones(k) / k, mode="same")
        onset = lo + int(np.argmax(e > 0.5 * np.median(e[-8 * blk:])))
        segs = ph["segments"]
        mk = [s for s in segs if s["kind"] == "marker"]
        t0 = onset / sr - mk[0]["start"] / fs
        fs_spacing = (mk[1]["start"] - mk[0]["start"]) / ((b0 - a0) * blk / sr)
        mid = slice((a0 + 15) * blk, (a1 - 15) * blk)
        out.append(dict(phase=ph, fs=fs, fs_spacing=fs_spacing, t0=t0,
                        marker_amp=[tone_level(x[mid, c], sr, np.mean(pitches), 0.002)[0]
                                    for c in range(x.shape[1])]))
    return out


def window(p, s, sr, trim=(0.15, 0.05)):
    ts = p["t0"] + s["start"] / p["fs"]
    te = ts + s["count"] / p["fs"]
    d = te - ts
    return int((ts + trim[0] * d) * sr), int((te - trim[1] * d) * sr)


def chan_levels(x, sr, p, s):
    a, b = window(p, s, sr)
    f = s["cps"] * p["fs"]
    return [tone_level(x[a:b, c], sr, f, 0.003)[0] for c in range(x.shape[1])], f


def db(v):
    return float(20 * np.log10(max(v, 1e-12)))


# ------------------------------------------------------------------------------ tests

def freqresp(x, sr, phases):
    res = []
    for p in phases:
        ph = p["phase"]
        T = 1 / p["fs"]
        rows = []
        for s in ph["segments"]:
            if s["kind"] != "tone":
                continue
            lv, f = chan_levels(x, sr, p, s)
            tab = vidc.decode(np.array(s["table"]))
            k = round(s["cps"] * len(tab))
            digital = 2 * np.abs(np.fft.rfft(tab)[k]) / len(tab)      # fundamental of the codes
            pulse = abs(np.sinc(f * 3 * T / 8))                          # each side: 3/8 of the slot
            rows.append(dict(f=f, left=lv[0], right=lv[-1], digital=float(digital), pulse=float(pulse)))
        ref = min(rows, key=lambda r: abs(r["f"] - 1000))
        for r in rows:
            for c in ("left", "right"):
                r[c + "_db"] = db((r[c] / r["digital"]) / (ref[c] / ref["digital"]))
            r["analogue_db"] = (r["left_db"] + r["right_db"]) / 2 - db(r["pulse"] / ref["pulse"])
        res.append(dict(label=ph["label"], fs=p["fs"], rows=rows))
        print(f"\n{ph['label']} (measured {p['fs']:.1f} Hz)")
        print("    f Hz    left dB  right dB   less pulse droop = analogue path")
        for r in rows:
            print(f"  {r['f']:7.1f}  {r['left_db']:+7.2f}  {r['right_db']:+7.2f}   {r['analogue_db']:+7.2f}")
    return res


def noise(x, sr, phases, man):
    res = []

    def describe(seg, fs_amp, label):
        out = dict(label=label)
        for c, name in enumerate(("left", "right")[:x.shape[1]]):
            f, P = welch(seg[:, c], sr, nperseg=sr // 2)
            band = (f >= 20) & (f <= 20000)
            rms = np.sqrt(np.sum(P[band]) * (f[1] - f[0]))
            fs_rms = fs_amp[c] * (np.pi / 4) / np.sqrt(2)         # full-scale sine, from the marker
            spurs = []
            Pd = P.copy()
            for _ in range(6):
                k = int(np.argmax(np.where(f > 30, Pd, 0)))
                spurs.append((float(f[k]), db(np.sqrt(Pd[k] * (f[1] - f[0])) / fs_rms)))
                Pd[max(0, k - 3):k + 4] = 0
            hum = {h: db(np.sqrt(P[np.argmin(np.abs(f - h))] * (f[1] - f[0])) / fs_rms) for h in (50, 100, 150)}
            line = db(np.sqrt(P[(f > 15500) & (f < 15750)].max() * (f[1] - f[0])) / fs_rms)
            out[name] = dict(noise_db=db(rms / fs_rms), spurs=spurs, hum=hum, line_15625=line)
        return out

    for p in phases:
        ph = p["phase"]
        row = dict(label=ph["label"], fs=p["fs"], vidc_mhz=24 * p["fs"] / ph["fs_nominal"])
        for s in ph["segments"]:
            if s["kind"] in ("zero", "negzero"):
                a, b = window(p, s, sr, (0.1, 0.05))
                row[s["kind"]] = describe(x[a:b], p["marker_amp"], s["kind"])
        res.append(row)
    last = phases[-1]
    m2 = [s for s in last["phase"]["segments"] if s["kind"] == "marker"][1]
    t_end = last["t0"] + (m2["start"] + m2["count"]) / last["fs"]
    off = None
    if man.get("dma_off_after"):
        a, b = int((t_end + 1.4) * sr), int((t_end + 5.2) * sr)
        if b <= len(x):
            off = describe(x[a:b], last["marker_amp"], "dma off")
    print("\nnoise 20 Hz-20 kHz, dB re a full-scale sine (left / right)")
    for r in res:
        print(f"  {r['label']:8s} ({r['vidc_mhz']:.3f} MHz)  +0: {r['zero']['left']['noise_db']:6.1f} / {r['zero']['right']['noise_db']:6.1f}"
              f"   -0: {r['negzero']['left']['noise_db']:6.1f} / {r['negzero']['right']['noise_db']:6.1f}"
              f"   15.625 kHz: {r['zero']['left']['line_15625']:6.1f}")
        print("           hum 50/100/150 Hz: " + " ".join(f"{v:6.1f}" for v in r["zero"]["left"]["hum"].values())
              + "   top spurs: " + ", ".join(f"{f:.0f} Hz {d:.0f}" for f, d in r["zero"]["left"]["spurs"][:4]))
    if off:
        print(f"  DMA off              {off['left']['noise_db']:6.1f} / {off['right']['noise_db']:6.1f}"
              + "   top spurs: " + ", ".join(f"{f:.0f} Hz {d:.0f}" for f, d in off["left"]["spurs"][:4]))
    return dict(phases=res, dma_off=off)


def slots(x, sr, phases):
    table = {}
    for p in phases:
        ph = p["phase"]
        for s in ph["segments"]:
            if s["kind"] == "step":
                lv, _ = chan_levels(x, sr, p, s)
                table[(ph["info"]["period_us"], ph["info"]["background"], s["m"], s["sign"])] = float(np.mean(lv))
    keys = [(32, 1), (64, 1), (96, 1), (127, 1), (127, -1)]
    print("\nstep level against 48 us with the other slots at zero, dB")
    print("  period  others   " + "  ".join(f"{'+' if sg > 0 else '-'}{m:<4d}" for m, sg in keys))
    rows = []
    for period in (48, 32, 24, 16, 12):
        for bg in (0, 254):
            if (period, bg, 32, 1) not in table:
                continue
            vals = [db(table[(period, bg, m, sg)] / table[(48, 0, m, sg)]) for m, sg in keys]
            rows.append(dict(period=period, background=bg, db=vals))
            print(f"  {period:3d} us  {'full' if bg else 'zero'}    " + "  ".join(f"{v:+5.2f}" for v in vals))
    return dict(rows=rows)


def stereo(x, sr, phases):
    rows = []
    for p in phases:
        ph = p["phase"]
        lv = np.mean([chan_levels(x, sr, p, s)[0] for s in ph["segments"] if s["kind"] == "step"], axis=0)
        rows.append(dict(position=ph["info"]["position"], left=float(lv[0]), right=float(lv[-1])))
    ref = max(r["left"] for r in rows)
    print("\nposition   left dB   right dB   (re the loudest left)   left share")
    for r in rows:
        r["left_db"], r["right_db"] = db(r["left"] / ref), db(r["right"] / ref)
        r["share"] = r["left"] / (r["left"] + r["right"])
        print(f"  {r['position']:+5d}   {r['left_db']:+7.2f}   {r['right_db']:+7.2f}                         {r['share']:.3f}")
    return dict(rows=rows)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("test", choices=["freqresp", "noise", "slots", "stereo"])
    ap.add_argument("wav")
    ap.add_argument("--phases")
    a = ap.parse_args()
    man = json.loads((HERE / f"{a.test}.json").read_text())
    only = [int(v) for v in a.phases.split(",")] if a.phases else None
    sr, x = load(a.wav)
    if x.shape[1] == 1:
        x = np.repeat(x, 2, axis=1)
    print(f"recording: {sr} Hz, {len(x) / sr:.1f} s, peak {db(np.abs(x).max()):.1f} dBFS")
    phases = find_phases(x, sr, man, only)
    for p in phases:
        ph = p["phase"]
        print(f"  {ph['label']:30s} rate {p['fs']:9.2f} Hz (nominal {ph['fs_nominal']:.2f}, "
              f"spacing check {p['fs_spacing']:.1f}), VIDC clock {24 * p['fs'] / ph['fs_nominal']:.3f} MHz")
    if a.test == "freqresp":
        res = freqresp(x, sr, phases)
    elif a.test == "noise":
        res = noise(x, sr, phases, man)
    elif a.test == "slots":
        res = slots(x, sr, phases)
    else:
        res = stereo(x, sr, phases)
    out = Path(a.wav).with_suffix(".json")
    out.write_text(json.dumps(dict(test=a.test, wav=str(a.wav), sr=sr,
                                   rates=[dict(label=p["phase"]["label"], fs=p["fs"]) for p in phases],
                                   result=res), indent=1, default=float))
    if a.test == "freqresp":
        import matplotlib
        matplotlib.use("Agg")
        import matplotlib.pyplot as plt
        fig, ax = plt.subplots(figsize=(9, 4.5))
        for r, c in zip(res, ("#257de0", "#f47230")):
            f = [v["f"] for v in r["rows"]]
            ax.semilogx(f, [v["left_db"] for v in r["rows"]], color=c, lw=2, label=f"{r['label']} measured")
            ax.semilogx(f, [v["analogue_db"] for v in r["rows"]], color=c, lw=1.2, ls="--",
                        label=f"{r['label']} less the DAC pulse")
        ax.axhline(0, color="#888", lw=0.8)
        ax.set_xlabel("frequency (Hz)")
        ax.set_ylabel("level re 1 kHz (dB)")
        ax.grid(True, which="both", color="#eee")
        ax.legend()
        fig.suptitle(f"Frequency response: {Path(a.wav).name}")
        fig.tight_layout()
        fig.savefig(out.with_suffix(".png"), dpi=110)
    print(f"\nwrote {out}")


if __name__ == "__main__":
    main()
