"""Prepare a ProTracker MOD for "best possible" QTM playback on one measured machine.

python tools/playback/prep_best.py song.mod out.mod --machine a3020 [--report]

The output is an ordinary MOD whose sample data are already VIDC log codes. It is meant
for a QTM whose load-time linear-to-log table has been replaced with an identity table
(the player does that), so QTM's conversion leaves the bytes alone. That lets the
conversion happen here, at full precision, against the machine's *measured* DAC levels,
instead of through an 8-bit linear stage and RISC OS's table.

Per sample:
  1. Filter (linear phase FIR, 63 taps) to undo
       - the board's analogue response, as measured on this machine by test 2 (the
         integrator on a bypassed A30x0, integrator and filter on a filtered one), aimed
         at the note this sample is most often played at in the patterns, and
       - the high-frequency loss of QTM's nearest-sample stepping (a hold at the sample's
         own rate, |sinc|), which is exact at every pitch.
     The boost is capped (default +12 dB). A looping sample's loop is filtered
     circularly, so the loop point stays seamless.
  2. Scale: one fixed gain for the whole song (default -3 dB), so the samples keep their
     relative levels; then each sample gets as much of its boost as fits under full scale
     (y = raw + a * (filtered - raw), a as large as possible up to 1). Most samples get all
     of it; a bright sample that was already at full scale gets part.
  3. Convert each value to the code whose measured level (+ or - half) is nearest.

The volume table for the same machine comes from voltable(): for each MOD volume, the
code subtract whose measured gain is closest to v/64.
"""
import argparse
import json
import math
from pathlib import Path

import numpy as np
from scipy.signal import firwin2

HERE = Path(__file__).resolve().parent
PAL_CLOCK = 3546894.6           # Paula: sample rate = clock / period


# ---------------------------------------------------------------------------- machine

def load_machine(name):
    prof = json.loads((HERE / "machines" / f"{name}.json").read_text())
    rec = json.loads((HERE.parent.parent / prof["codesweep"]).read_text())
    P = np.array([l["pos"] for l in rec["levels"]])
    N = np.array([l["neg"] for l in rec["levels"]])
    resp = json.loads((HERE.parent.parent / prof["freqresp"]).read_text())["result"][0]["rows"]
    f = np.array([r["f"] for r in resp])
    db = np.array([r["analogue_db"] for r in resp])
    db -= np.median(db[(f > 100) & (f < 500)])      # 0 dB in the flat region
    return dict(name=name, P=P, N=N, label=prof["label"], short=prof["short"],
                resp_f=f, resp_db=db, cap_db=prof.get("cap_db", 12.0), fade_hz=prof.get("fade_hz"))


def response_db(m, hz):
    """The machine's measured analogue response, interpolated in log frequency and held
    flat beyond the last measured point (20 kHz)."""
    lf = np.log10(np.clip(hz, m["resp_f"][0], m["resp_f"][-1]))
    return np.interp(lf, np.log10(m["resp_f"]), m["resp_db"])


def to_codes(x, m):
    """Float samples in [-1, 1] (1 = the largest level both halves can reach) -> codes."""
    lmax = min(m["P"].max(), m["N"].max())
    t = np.abs(x) * lmax
    out = np.zeros(len(x), dtype=np.uint8)
    pos = x >= 0
    for half, sel, sign in ((m["P"], pos, 0), (m["N"], ~pos, 1)):
        if sel.any():
            idx = np.argmin(np.abs(half[None, :] - t[sel][:, None]), axis=1)
            out[sel] = (idx << 1) | np.where(idx > 0, sign, 0)
    return out


def voltable(m):
    """65 bytes: QTM's base volume table (subtract from the code byte; 0xFE = silent).

    For each MOD volume v, the subtract whose gain, measured as the fundamental of sines
    at 0, -6 and -12 dBFS played through the machine's measured DAC, is nearest v/64."""
    n = 2048
    t = np.arange(n)
    sines = [np.sin(2 * np.pi * 16 * t / n) * 10 ** (db / 20) for db in (0, -6, -12)]
    codes = [to_codes(x, m).astype(np.int64) for x in sines]

    def level(c):
        v = np.where(c & 1, -m["N"][c >> 1], m["P"][c >> 1])
        return 2 * abs(np.fft.rfft(v)[16]) / n

    full = [level(c) for c in codes]
    gains = np.zeros(128)                           # mean dB gain of subtracting 2k
    for k in range(128):
        g = [20 * math.log10(max(level(np.maximum(c - 2 * k, 0)), 1e-9) / f) for c, f in zip(codes, full)]
        gains[k] = np.mean(g)
    tab = [0xFE]
    for v in range(1, 65):
        k = int(np.argmin(np.abs(gains - 20 * math.log10(v / 64))))
        tab.append(min(0xFC, 2 * k))
    for v in range(63, 0, -1):                    # never louder at a lower volume
        tab[v] = max(tab[v], tab[v + 1])
    return bytes(tab)


# ---------------------------------------------------------------------------- MOD

def parse(d):
    tag = d[1080:1084]
    if tag in (b"M.K.", b"M!K!", b"FLT4", b"4CHN"):
        ch = 4
    elif tag[1:] == b"CHN":
        ch = int(tag[:1])
    elif tag[2:] == b"CH":
        ch = int(tag[:2])
    elif tag == b"FLT8":
        ch = 8
    else:
        raise SystemExit(f"not a 31-sample MOD (tag {tag!r})")
    songlen = d[950]
    orders = list(d[952:1080])
    npat = max(orders) + 1
    pat_off = 1084
    smp_off = pat_off + npat * 64 * ch * 4
    samples = []
    off = smp_off
    for i in range(31):
        h = d[20 + i * 30:50 + i * 30]
        length = int.from_bytes(h[22:24], "big") * 2
        rep_off = int.from_bytes(h[26:28], "big") * 2
        rep_len = int.from_bytes(h[28:30], "big") * 2
        samples.append(dict(i=i + 1, name=h[:22].rstrip(b"\0").decode("latin-1"), off=off, length=length,
                            finetune=h[24], volume=h[25], rep_off=rep_off, rep_len=rep_len))
        off += length
    return dict(ch=ch, songlen=songlen, orders=orders, npat=npat, pat_off=pat_off, samples=samples)


def played_periods(d, mod):
    """Periods each sample is triggered or retriggered at, from the patterns in the song."""
    ch = mod["ch"]
    seen = {}
    for p in sorted(set(mod["orders"][:mod["songlen"]])):
        last = [0] * ch
        base = mod["pat_off"] + p * 64 * ch * 4
        for row in range(64):
            for c in range(ch):
                b = d[base + (row * ch + c) * 4: base + (row * ch + c) * 4 + 4]
                smp = (b[0] & 0xF0) | (b[2] >> 4)
                per = ((b[0] & 0x0F) << 8) | b[1]
                if smp:
                    last[c] = smp
                if per and last[c]:
                    seen.setdefault(last[c], []).append(per)
    return seen


# ---------------------------------------------------------------------------- filter

def emphasis_fir(fs, m, cap_db, taps=63):
    """Inverse of the machine's measured response at the output frequencies this sample
    rate maps to, times the inverse of QTM's hold, capped."""
    f = np.linspace(0, 1, 257)                      # 1 = the sample's Nyquist
    hz = f * fs / 2
    board = 10 ** (-response_db(m, np.maximum(hz, 1.0)) / 20)
    hold = 1 / np.maximum(np.abs(np.sinc(f / 2)), 1e-3)
    g = np.minimum(board * hold, 10 ** (cap_db / 20))
    fade = m.get("fade_hz")
    if fade:                                        # boost only where it can flatten:
        lo, hi = fade                               # fade it out between lo and hi Hz
        t = np.clip((hz - lo) / (hi - lo), 0, 1)
        g = np.exp(np.log(g) * (1 - t))
    return firwin2(taps, f, g)


def filt(x, h, rep_off, rep_len):
    n = len(h) // 2
    looping = rep_len > 2 and rep_off + rep_len <= len(x)
    if looping:
        tail = np.resize(x[rep_off:rep_off + rep_len], n)
        y = np.convolve(np.r_[np.zeros(n), x, tail], h, mode="same")[n:n + len(x)]
        # the loop itself as a circular convolution, the kernel wrapped round its length
        loop = x[rep_off:rep_off + rep_len]
        L = len(loop)
        kern = np.zeros(L)
        for k, v in enumerate(h):
            kern[(k - n) % L] += v
        y[rep_off:rep_off + L] = np.real(np.fft.ifft(np.fft.fft(loop) * np.fft.fft(kern)))
        return y
    return np.convolve(np.r_[np.zeros(n), x, np.zeros(n)], h, mode="same")[n:n + len(x)]


# ---------------------------------------------------------------------------- main

def prepare(src, dst, machine, cap_db=12.0, gain_db=-3.0, report=False):
    d = bytearray(Path(src).read_bytes())
    mod = parse(d)
    m = load_machine(machine)
    periods = played_periods(d, mod)
    work = []
    for s in mod["samples"]:
        if s["length"] < 4:
            continue
        raw = np.frombuffer(bytes(d[s["off"]:s["off"] + s["length"]]), dtype=np.int8).astype(float) / 128
        pers = periods.get(s["i"])
        if pers:
            per = float(np.median(pers))
            h = emphasis_fir(PAL_CLOCK / per, m, cap_db)
            y = filt(raw, h, s["rep_off"], s["rep_len"])
        else:
            per, y = None, raw
        work.append((s, raw, y, per))
    g = 10 ** (gain_db / 20)
    done = []
    for s, raw, y, per in work:
        a = 1.0
        if np.abs(y).max() * g > 0.999:
            lo, hi = 0.0, 1.0                     # the largest blend that fits
            for _ in range(20):
                mid = (lo + hi) / 2
                if np.abs(raw + mid * (y - raw)).max() * g <= 0.999:
                    lo = mid
                else:
                    hi = mid
            a = lo
        out = np.clip((raw + a * (y - raw)) * g, -1, 1)
        d[s["off"]:s["off"] + s["length"]] = to_codes(out, m).tobytes()
        done.append((s, raw, out / g, per, a))
    Path(dst).write_bytes(bytes(d))
    info = dict(src=str(src), channels=mod["ch"], gain_db=gain_db, machine=machine,
                samples=[dict(n=s["i"], name=s["name"], length=s["length"],
                              note_rate=(PAL_CLOCK / per if per else None), boost_share=a)
                         for s, r, y, per, a in done])
    if report:
        part = [x for x in info["samples"] if x["boost_share"] < 0.999]
        print(f"{Path(src).name}: {mod['ch']} channels, {len(work)} samples, song gain {gain_db:+.1f} dB, "
              f"{len(work) - len(part)} with the full boost")
        for x in part:
            print(f"  {x['n']:2d} {x['name'][:22]:22s} played at {x['note_rate'] or 0:6.0f} Hz: {100 * x['boost_share']:3.0f}% of the boost")
    return info


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("src")
    ap.add_argument("dst")
    ap.add_argument("--machine", default="a3020")
    ap.add_argument("--cap", type=float, default=12.0)
    ap.add_argument("--gain", type=float, default=-3.0)
    ap.add_argument("--report", action="store_true")
    a = ap.parse_args()
    prepare(a.src, a.dst, a.machine, a.cap, a.gain, a.report)


if __name__ == "__main__":
    main()
