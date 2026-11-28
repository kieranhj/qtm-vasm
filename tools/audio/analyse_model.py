"""Offline analysis of QTM's sample path on VIDC1, before any recordings.

python tools/audio/analyse_model.py [--json out.json]

1. QTM's linear-to-log table against the datasheet DAC curve.
2. The distortion from doing volume as a subtract on the log code.
3. Playback of a looped sample by nearest-sample stepping, and what 2x pre-upsampling buys.
4. The first DAC image from the time-division output with the filter bypassed.

Everything is modelled from the datasheet curve (vidc.py). The recordings are what will
tell us how far the real chip and board differ from it.
"""
import argparse
import json

import numpy as np
from scipy.signal import get_window

import vidc

N = 1 << 14
CYC = 37                                  # coherent test-tone cycles in N points


def measure(y):
    return vidc.snr_thd(np.asarray(y, dtype=float), CYC)


def nearest_level(target):
    """Magnitude code whose DAC level is nearest to each target (units of i)."""
    return np.argmin(np.abs(vidc.MAG[None, :] - np.abs(target)[:, None]), axis=1)


# ---------------------------------------------------------------------------- 1. table

def table_analysis():
    os_tab = vidc.os_linlog()
    near = vidc.nearest_linlog(2.0)
    xs = np.arange(-128, 128)
    vals = vidc.decode(os_tab[vidc.to_unsigned(xs)])
    nvals = vidc.decode(near[vidc.to_unsigned(xs)])
    fit = (np.abs(xs) >= 4) & (np.abs(xs) <= 110)
    scale = float(np.sum(vals[fit] * xs[fit]) / np.sum(xs[fit] ** 2))
    pos = (xs >= 4) & (xs <= 110)
    higher = int(np.sum(vals[pos] > nvals[pos]))
    lower = int(np.sum(vals[pos] < nvals[pos]))

    rows = []
    for db in (0, -6, -12, -18, -24, -30, -36, -42):
        amp = 127 * 10 ** (db / 20)
        x = vidc.sine_8bit(N, CYC, amp)
        xf = amp * np.sin(2 * np.pi * CYC * np.arange(N) / N + 0.3)
        y_os = vidc.decode(os_tab[vidc.to_unsigned(x)])
        y_nr = vidc.decode(near[vidc.to_unsigned(x)])
        y_hi = np.sign(xf) * vidc.MAG[nearest_level(xf * 2.0)]
        rows.append(dict(level=db, linear8=measure(x)[0], os=measure(y_os)[0],
                         os_thd=measure(y_os)[1], nearest=measure(y_nr)[0],
                         hires=measure(y_hi)[0]))
    return dict(scale=scale, higher=higher, lower=lower,
                clip=[int(x) for x in xs if 0 < x and os_tab[x] == os_tab[127]],
                rows=rows,
                curve=[dict(x=int(x), os=float(v), ideal=2.0 * int(x))
                       for x, v in zip(xs, vals) if x >= 0])


# ---------------------------------------------------------------------------- 2. volume

def volume_analysis():
    os_tab = vidc.os_linlog()
    codes = os_tab[vidc.to_unsigned(vidc.sine_8bit(N, CYC, 127))]
    full = vidc.decode(codes)
    a_full = measure(full)[2]
    out = []
    for v in range(1, 65):
        sub = vidc.qtm_volume_sub(v, os_tab)
        y = vidc.decode(vidc.apply_volume(codes, sub))
        sinad, thd, a = measure(y)
        y_best = np.sign(full) * vidc.MAG[nearest_level(np.abs(full) * v / 64)]
        b_sinad, b_thd, _ = measure(y_best)
        out.append(dict(vol=v, sub=sub, gain_db=20 * np.log10(a / a_full),
                        ideal_db=20 * np.log10(v / 64), sinad=sinad, thd=thd,
                        best_sinad=b_sinad, best_thd=b_thd))
    return out


# ---------------------------------------------------------------------------- 3. resampling

def sine_loop(length=64, cycles=5, amp=110):
    t = np.arange(length)
    return np.round(amp * np.sin(2 * np.pi * cycles * t / length))


def play_nearest(sample, src_rate, fs, seconds=0.5, frac_bits=12):
    """QTM-style DDA: 12-bit fractional position, truncated to the sample before."""
    inc = int(round(src_rate / fs * (1 << frac_bits)))
    n = int(fs * seconds)
    pos = (np.arange(n, dtype=np.int64) * inc) >> frac_bits
    return sample[pos % len(sample)], inc * fs / (1 << frac_bits)


def classify(y, fs, f0, src, lim=20000.0):
    """Split the audible band (below 20 kHz and fs/2) of a played sine into the tone,
    images of the sample's own rate (k*src +- f0; Paula makes these on the Amiga too),
    and everything else (aliasing caused by stepping at fs). Both in dB re the tone."""
    w = get_window("blackmanharris", len(y))
    P = np.abs(np.fft.rfft((y - y.mean()) * w)) ** 2
    f = np.fft.rfftfreq(len(y), 1 / fs)
    tol = 6 * fs / len(y)
    band = f < min(lim, fs / 2)
    tone = np.abs(f - f0) < tol
    img = np.zeros_like(band)
    for k in range(1, int(lim / src) + 2):
        img |= (np.abs(f - (k * src - f0)) < tol) | (np.abs(f - (k * src + f0)) < tol)
    T = P[band & tone].sum()
    db = lambda m: float(10 * np.log10(max(P[band & m].sum(), 1e-30) / T))
    return db(img & ~tone), db(~img & ~tone), db(~tone)


def resampling_analysis():
    base = sine_loop(64, 5)
    up = np.round(np.fft.irfft(np.fft.rfft(base), 128) * 2)      # band-limited 2x copy
    rows = []
    for period_us in (48, 32, 24):
        fs = 1e6 / period_us
        for mult, label in ((1, "C-3"), (2, "C-4"), (4, "C-5")):
            src = 8363.0 * mult                  # ProTracker C-3 rate at finetune 0
            y, src_eff = play_nearest(base, src, fs)
            f0 = src_eff * 5 / 64
            *_, tot = classify(y, fs, f0, src_eff)
            y2, src2 = play_nearest(up, src * 2, fs)
            *_, tot2 = classify(y2, fs, src2 * 5 / 128, src2 / 2)
            rows.append(dict(period=period_us, note=label, f0=f0, total=tot, up_total=tot2))
    return rows


# ---------------------------------------------------------------------------- 4. DAC images

def image_analysis():
    out = []
    for period_us in (48, 32, 24):
        fs = 1e6 / period_us
        frames = 4096
        for f in (2000.0, 4000.0, 8000.0):
            x = 120 * np.sin(2 * np.pi * f * np.arange(frames) / fs)
            vals = np.zeros((frames, 4))
            vals[:, 0] = np.sign(x) * vidc.MAG[nearest_level(x * 2)]
            L, _, fr = vidc.tdm_output(vals, period_us / 4, [1.0, 0.5, 0.5, 0.5], oversample=24)
            w = get_window("blackmanharris", len(L))
            P = np.abs(np.fft.rfft((L - L.mean()) * w)) ** 2
            fq = np.fft.rfftfreq(len(L), 1 / fr)

            def pk(t):
                k = int(np.argmin(np.abs(fq - t)))
                return P[max(0, k - 3):k + 4].max()
            out.append(dict(period=period_us, fs=fs, f=f, img_f=fs - f,
                            img=float(10 * np.log10(pk(fs - f) / pk(f)))))
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--json")
    a = ap.parse_args()
    res = dict(table=table_analysis(), volume=volume_analysis(),
               resampling=resampling_analysis(), images=image_analysis())

    t = res["table"]
    print(f"OS table: {t['scale']:.3f} i per input step; inputs sharing the top code: {t['clip']}")
    print(f"versus the nearest level, x = 4..110: OS picks higher {t['higher']}, lower {t['lower']}")
    print("SINAD dB  level  8-bit linear  OS table (THD)  nearest-level table  16-bit source")
    for r in t["rows"]:
        print(f"         {r['level']:5d}  {r['linear8']:11.1f}  {r['os']:7.1f} ({r['os_thd']:6.1f})  {r['nearest']:18.1f}  {r['hires']:13.1f}")
    subs = [r["sub"] for r in res["volume"]]
    print(f"\nvolume: {len(set(subs) | {0})} distinct levels out of 65")
    print("vol  sub  gain dB (ideal)  SINAD   THD | nearest-level SINAD  THD")
    for r in res["volume"]:
        if r["vol"] in (64, 60, 56, 48, 40, 32, 24, 16, 8, 4, 2, 1):
            print(f"{r['vol']:3d} {r['sub']:4d}  {r['gain_db']:6.2f} ({r['ideal_db']:6.2f})  {r['sinad']:5.1f} {r['thd']:6.1f} | {r['best_sinad']:19.1f} {r['best_thd']:5.1f}")
    print("\nplayback of a looped sine sample (5 cycles in 64 bytes): audible distortion, dB re tone")
    for r in res["resampling"]:
        print(f"{r['period']} us {r['note']} ({r['f0']:4.0f} Hz)  as-is {r['total']:6.1f}   2x upsampled {r['up_total']:6.1f}")
    print("\nfirst DAC image, one channel hard left, 4-channel mode, no filter, no integrator")
    for r in res["images"]:
        print(f"{r['period']} us: {r['f']:5.0f} Hz tone -> image at {r['img_f']:6.0f} Hz, {r['img']:5.1f} dB")
    if a.json:
        with open(a.json, "w") as fh:
            json.dump(res, fh, default=float, indent=1)


if __name__ == "__main__":
    main()
