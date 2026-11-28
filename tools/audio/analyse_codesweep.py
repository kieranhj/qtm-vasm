"""Analyse a recording of test 1, the DAC code sweep (tools/audio/arc/codesweep.asm).

python tools/audio/analyse_codesweep.py recording.wav [--out build/codesweep-result]

Any WAV rate, mono or stereo, 16/24/32-bit or float. Start recording before running the
program and stop after it says "Done"; extra silence either side is fine.

1. Finds the two 1 kHz markers and from their spacing works out the Arc's sample rate in
   the recorder's clock (the two are not locked).
2. For each step, measures the 100 Hz fundamental by lock-in over whole cycles, and turns
   it into a level: a square between V and 0 has a fundamental of 2V/pi.
3. Scales the levels to the datasheet's units of i using the upper chords, then reports
   per code and per chord: the error against the datasheet curve in steps, the +/- half
   mismatch, +0 against -0, the noise floor, and which byte layout the board uses.
4. Writes <out>.json, <out>.png, and <out>-linlog.bin: a 256-byte linear-to-log table that
   picks the nearest *measured* level, in the same format as tools/prep/linlog.bin.
"""
import argparse
import json
from pathlib import Path

import numpy as np
from scipy.io import wavfile

import vidc

HERE = Path(__file__).resolve().parent


def load(path):
    sr, x = wavfile.read(path)
    if x.dtype.kind == "i":
        x = x.astype(np.float64) / np.iinfo(x.dtype).max
    elif x.dtype.kind == "u":
        x = (x.astype(np.float64) - 128) / 128
    x = x.astype(np.float64)
    if x.ndim == 1:
        x = x[:, None]
    return sr, x


def envelope(x, sr, f, win_s=0.02):
    t = np.arange(len(x)) / sr
    z = x * np.exp(-2j * np.pi * f * t)
    k = max(1, int(win_s * sr))
    c = np.cumsum(np.r_[0, z])
    return np.abs((c[k:] - c[:-k]) / k) * 2, k


def regions(mask):
    d = np.diff(np.r_[0, mask.astype(int), 0])
    return list(zip(np.flatnonzero(d == 1), np.flatnonzero(d == -1)))


def find_markers(mono, sr, man):
    # The Arc's sample rate follows the VIDC clock, which on A3020/A4000/A5000 class
    # machines depends on the screen mode (24, 25.175 or 36 MHz), so find the marker's
    # actual pitch first: the strongest tone within -30%/+60% of nominal.
    f_nom = man["fs_nominal"] / (2 * man["mark_half"])
    blk = sr // 10
    rms = np.sqrt(np.mean(mono[:len(mono) // blk * blk].reshape(-1, blk) ** 2, axis=1))
    first = int(np.argmax(rms > 0.5 * rms.max()))          # the first marker is full scale
    seg = mono[(first + 2) * blk:(first + 12) * blk]
    spec = np.abs(np.fft.rfft(seg * np.hanning(len(seg)), 8 * len(seg)))
    fq = np.fft.rfftfreq(8 * len(seg), 1 / sr)
    band = (fq > 0.7 * f_nom) & (fq < 1.6 * f_nom)
    f_m = fq[band][np.argmax(spec[band])]
    env, k = envelope(mono, sr, f_m)
    thr = 0.5 * env.max()
    regs = [r for r in regions(env > thr) if (r[1] - r[0]) > 0.5 * sr]
    if len(regs) < 2:
        raise SystemExit(f"found {len(regs)} marker(s), need 2: is the whole run recorded?")
    (a0, a1), (b0, b1) = regs[0], regs[-1]
    # the moving average is centred k/2 late on a rising edge
    t1, t2 = (a0 + k / 2) / sr, (b0 + k / 2) / sr
    segs = man["segments"]
    marks = [s for s in segs if s["kind"] == "marker"]
    n = marks[1]["start"] - marks[0]["start"]
    fs_arc = n / (t2 - t1)
    # second estimate from the marker's pitch
    mid = mono[a0 + (a1 - a0) // 4:a1 - (a1 - a0) // 4]
    w = np.hanning(len(mid))
    spec = np.abs(np.fft.rfft(mid * w, 16 * len(mid)))
    fq = np.fft.rfftfreq(16 * len(mid), 1 / sr)
    band = (fq > 0.9 * f_m) & (fq < 1.1 * f_m)
    f_meas = fq[band][np.argmax(spec[band])]
    return t1 - marks[0]["start"] / fs_arc, fs_arc, f_meas * 2 * man["mark_half"]


def lockin(x, sr, t0, t1, f):
    """Fundamental amplitude of x at f over the whole cycles inside [t0, t1)."""
    n0 = int(np.ceil(t0 * sr))
    cycles = int(np.floor((t1 - n0 / sr) * f))
    n1 = n0 + int(round(cycles * sr / f))
    seg = x[n0:n1]
    t = np.arange(n0, n1) / sr
    return 2 * np.abs(np.sum(seg * np.exp(-2j * np.pi * f * t))) / len(seg)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("wav")
    ap.add_argument("--out", default=None)
    ap.add_argument("--channel", choices=["mean", "left", "right"], default="mean")
    a = ap.parse_args()
    out = Path(a.out) if a.out else Path(a.wav).with_suffix("")
    man = json.loads((HERE / "codesweep.json").read_text())

    sr, x = load(a.wav)
    chans = {"left": x[:, 0], "right": x[:, -1]}
    mono = x.mean(axis=1)
    sig = {"mean": mono, **chans}[a.channel]
    t_zero, fs_arc, fs_pitch = find_markers(mono, sr, man)
    print(f"recording: {sr} Hz, {x.shape[1]} channel(s), {len(x) / sr:.1f} s")
    print(f"Arc sample rate in the recorder's clock: {fs_arc:.2f} Hz from marker spacing,"
          f" {fs_pitch:.2f} Hz from marker pitch (nominal {man['fs_nominal']:.2f})")
    peak = np.abs(x).max()
    print(f"peak level {20 * np.log10(peak):.1f} dBFS" + ("  ** CLIPPED: lower the input gain **" if peak > 0.99 else ""))

    f_step = fs_arc / (2 * man["half"])
    meas = {}
    silence = []
    for s in man["segments"]:
        ts = t_zero + s["start"] / fs_arc
        te = ts + s["count"] / fs_arc
        t0, t1 = ts + 0.12 * (te - ts), te - 0.05 * (te - ts)
        if s["kind"] == "step":
            amps = {k: lockin(v, sr, t0, t1, f_step) * np.pi / 2 for k, v in
                    {"mean": mono, **chans}.items()}
            meas[(s["m"], s["sign"])] = amps
        elif s["kind"] == "silence" and s["count"] < 3000:
            n0, n1 = int(t0 * sr), int(t1 * sr)
            silence.append((lockin(sig, sr, t0, t1, f_step) * np.pi / 2,
                            np.sqrt(np.mean((sig[n0:n1] - sig[n0:n1].mean()) ** 2))))

    ms = np.arange(128)
    pos = np.array([meas[(m, +1)][a.channel] for m in ms])
    neg = np.array([meas[(m, -1)][a.channel] for m in ms])

    # byte layout: RISC OS (sign in bit 0) against the datasheet's VIDC1 drawing (sign in D7)
    def predicted(layout):
        p, n = np.zeros(128), np.zeros(128)
        for m in ms:
            for sgn, arr in ((+1, p), (-1, n)):
                c = (m << 1) | (1 if sgn < 0 else 0)
                mag = (c >> 1) if layout == "riscos" else (c & 0x7F)
                arr[m] = vidc.MAG[mag]
        return p, n

    fits = {}
    for layout in ("riscos", "vidc1-d7"):
        pp, pn = predicted(layout)
        y = np.r_[pp, pn]
        v = np.r_[pos, neg]
        k = np.sum(v * y) / np.sum(v * v)
        fits[layout] = (k, float(np.sqrt(np.mean((k * v - y) ** 2))))
    layout = min(fits, key=lambda l: fits[l][1])
    print(f"byte layout: {layout} (rms residual {fits['riscos'][1]:.2f} i for RISC OS order,"
          f" {fits['vidc1-d7'][1]:.2f} i for sign-in-D7)")

    # scale to units of i on chords 3-7, each half separately so a mismatch shows
    model = vidc.MAG
    fit = ms >= 48
    k_both = np.sum((pos[fit] + neg[fit]) * 2 * model[fit]) / np.sum((pos[fit] + neg[fit]) ** 2)
    P, N = pos * k_both, neg * k_both
    step = np.where(ms < 16, 1 / 16, 2.0 ** (ms >> 4) / 16)
    err_p, err_n = (P - model) / step, (N - model) / step
    fs_i = 247.0
    noise_lock = np.median([s[0] for s in silence]) * k_both
    noise_rms = np.median([s[1] for s in silence]) * k_both
    zero_neg = N[0]

    print("\nchord  steps    mean error (steps)   worst (steps)   -/+ level")
    chords = []
    for c in range(8):
        sel = (ms >> 4) == c
        mm = sel & (ms > 0)
        ratio = np.median(N[mm] / P[mm]) if mm.any() else np.nan
        row = dict(chord=c, err_pos=float(np.mean(err_p[sel])), err_neg=float(np.mean(err_n[sel])),
                   worst=float(np.max(np.abs(np.r_[err_p[sel], err_n[sel]]))),
                   neg_over_pos_db=float(20 * np.log10(ratio)))
        chords.append(row)
        print(f"  {c}    {step[sel][0]:6.3f} i  {row['err_pos']:+7.2f} / {row['err_neg']:+7.2f}"
              f"     {row['worst']:7.2f}      {row['neg_over_pos_db']:+6.2f} dB")
    mono_ok = bool(np.all(np.diff(P) > 0) and np.all(np.diff(N) > 0))
    print(f"\nmonotonic: {'yes' if mono_ok else 'NO'};  -0 against +0: {zero_neg:.3f} i"
          f" ({20 * np.log10(max(zero_neg, 1e-9) / fs_i):.1f} dB re full scale)")
    print(f"noise in the gaps: {noise_rms:.3f} i rms broadband"
          f" ({20 * np.log10(max(noise_rms, 1e-9) / fs_i):.1f} dBFS-of-DAC),"
          f" {noise_lock:.4f} i at 100 Hz")
    lr = np.median([meas[(m, s)]["left"] / meas[(m, s)]["right"] for m in range(64, 128) for s in (1, -1)])
    print(f"left/right balance at stereo centre: {20 * np.log10(lr):+.2f} dB")

    # linear-to-log table from the measured levels, OS scale of 2 i per input step
    table = np.zeros(256, dtype=np.uint8)
    for u in range(256):
        xv = u - 256 if u >= 128 else u
        lv = N if xv < 0 else P
        mcode = int(np.argmin(np.abs(lv - abs(xv) * 2.0)))
        table[u] = (mcode << 1) | (1 if xv < 0 and mcode else 0)
    out.parent.mkdir(parents=True, exist_ok=True)
    (out.parent / (out.name + "-linlog.bin")).write_bytes(table.tobytes())
    differs = int(np.sum(table != vidc.os_linlog().astype(np.uint8)))
    print(f"measured linear-to-log table differs from the OS table in {differs} of 256 entries")

    res = dict(wav=str(a.wav), sr=sr, fs_arc=fs_arc, fs_pitch=fs_pitch, layout=layout,
               fits={k: list(v) for k, v in fits.items()}, chords=chords, monotonic=mono_ok,
               zero_neg=float(zero_neg), noise_rms_i=float(noise_rms), lr_db=float(20 * np.log10(lr)),
               levels=[dict(m=int(m), pos=float(P[m]), neg=float(N[m]), model=float(model[m]))
                       for m in ms])
    (out.parent / (out.name + ".json")).write_text(json.dumps(res, indent=1))

    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    fig, ax = plt.subplots(2, 1, figsize=(9, 7), sharex=True)
    ax[0].plot(ms, model, color="#888", lw=3, label="datasheet")
    ax[0].plot(ms, P, color="#257de0", lw=1.5, label="measured +")
    ax[0].plot(ms, N, color="#f47230", lw=1.5, ls="--", label="measured −")
    ax[0].set_ylabel("level (i)")
    ax[0].legend()
    ax[1].axhline(0, color="#888", lw=1)
    ax[1].plot(ms, err_p, color="#257de0", lw=1.5, label="+ half")
    ax[1].plot(ms, err_n, color="#f47230", lw=1.5, ls="--", label="− half")
    ax[1].set_ylabel("error (steps of its chord)")
    ax[1].set_xlabel("magnitude code")
    for c in range(1, 8):
        for axx in ax:
            axx.axvline(16 * c, color="#ddd", lw=0.8, zorder=0)
    ax[1].legend()
    fig.suptitle(f"VIDC code sweep: {Path(a.wav).name}")
    fig.tight_layout()
    fig.savefig(out.parent / (out.name + ".png"), dpi=110)
    print(f"\nwrote {out}.json, {out}.png, {out}-linlog.bin")


if __name__ == "__main__":
    main()
