"""Tests 2-5: sequences for the shared sound-test engine (arc/engine.asm).

python tools/audio/soundtests.py      writes arc/<test>.asm, arc/<test>_seq.asm, <test>.json

Each test is a list of phases. A phase sets the sound system up (channels, period, stereo
positions, screen mode, the code held in the slots that are not playing) and plays a list
of segments in one slot. Every phase starts and ends with a 1 s full-scale marker, so the
analyser can find each phase and measure its real sample rate, which follows the VIDC
clock and so the screen mode.

Segment types:
  square  - switch between codes A and B every `half` samples
  table   - loop a byte table (a sine with a whole number of cycles)

  test 2 freqresp  frequency response: sine tones, 1 channel, stereo centre, 24 and 48 us
  test 3 noise     noise floor: +0 and -0 silence in MODEs 12, 13, 27, 28, then DMA off
  test 4 slots     4 channels at 48..12 us: one slot playing, the others at 0 or full scale
  test 5 stereo    the 7 stereo positions, 1 channel
"""
import json
import math
from pathlib import Path

import numpy as np

import vidc

HERE = Path(__file__).resolve().parent
ARC = HERE / "arc"


def code(m, negative=False):
    return (m << 1) | (1 if negative and m else 0)


def lin_to_code(x):
    """Signed linear value in 8-bit units -> byte code at the datasheet-nearest level."""
    m = int(np.argmin(np.abs(vidc.MAG - abs(x) * 2.0)))
    return code(m, x < 0)


class Phase:
    def __init__(self, label, channels=1, period=48, slot=0, stereo=0, mode=-1, bg=0, **info):
        self.label, self.channels, self.period, self.slot = label, channels, period, slot
        self.stereo = stereo if isinstance(stereo, list) else [stereo] * 8
        self.mode, self.bg, self.info = mode, bg, info
        self.fs = 1e6 / period            # bytes per channel per second, nominal
        self.segs = []
        self.mark_half = max(1, round(self.fs / 2000))      # about 1 kHz
        self.add_silence(0.5)
        self.add_square("marker", 1.0, code(127), code(127, True), self.mark_half)
        self.add_silence(0.5)

    def count(self, seconds, unit):
        return max(unit, int(round(seconds * self.fs / unit)) * unit)

    def add_square(self, kind, seconds, a, b, half, **info):
        self.segs.append(dict(kind=kind, type="square", count=self.count(seconds, 2 * half),
                              a=a, b=b, half=half, cps=1 / (2 * half), **info))

    def add_silence(self, seconds, kind="silence", c=0, **info):
        self.segs.append(dict(kind=kind, type="square", count=self.count(seconds, 2), a=c, b=c,
                              half=1, cps=0.0, **info))

    def add_sine(self, seconds, f_target, amp, min_len=256, **info):
        k = max(1, math.ceil(f_target * min_len / self.fs))
        length = int(round(k * self.fs / f_target))
        t = np.arange(length)
        table = [lin_to_code(amp * math.sin(2 * math.pi * k * i / length)) for i in t]
        self.segs.append(dict(kind="tone", type="table", count=self.count(seconds, length),
                              table=table, cps=k / length, f_nominal=k * self.fs / length, **info))

    def finish(self):
        self.add_silence(0.5)
        self.add_square("marker", 1.0, code(127), code(127, True), self.mark_half)
        self.add_silence(1.0)
        start = 0
        for s in self.segs:
            s["start"] = start
            start += s["count"]


def square_half(ph, f=100.0):
    return max(1, round(ph.fs / (2 * f)))


def test_freqresp():
    phases = []
    freqs = np.geomspace(20, 20000, 31)
    for period, fmax in ((24, 20000), (48, 9500)):
        ph = Phase(f"{period} us", period=period)
        for f in freqs[freqs <= fmax * 1.001]:
            ph.add_sine(0.6, float(f), 40.0, f_target_req=float(f))
            ph.add_silence(0.1)
        phases.append(ph)
    return phases, dict(
        title="frequency response", banner="Sound test 2: frequency response, 1 channel, centre.",
        seconds_after=0)


def test_noise():
    phases = []
    for mode in (12, 13, 27, 28):
        ph = Phase(f"MODE {mode}", mode=mode)
        ph.add_silence(4.0, "zero", 0)
        ph.add_silence(4.0, "negzero", 1)
        phases.append(ph)
    return phases, dict(title="noise floor", banner="Sound test 3: noise floor in MODEs 12, 13, 27, 28.",
                        seconds_after=5, dma_off_after=True)


def test_slots():
    phases = []
    for period in (48, 32, 24, 16, 12):
        for bg in (0, code(127)):
            ph = Phase(f"4 ch {period} us, others {'full' if bg else 'zero'}", channels=4,
                       period=period, slot=1, bg=bg, period_us=period, background=bg)
            # let the coupling capacitors settle on the background level before the marker
            ph.segs.insert(0, dict(kind="silence", type="square", count=ph.count(2.0, 2), a=0, b=0,
                                   half=1, cps=0.0))
            h = square_half(ph)
            for m in (32, 64, 96, 127):
                ph.add_square("step", 1.0, code(m), 0, h, m=m, sign=1)
            ph.add_square("step", 1.0, code(127, True), 0, h, m=127, sign=-1)
            phases.append(ph)
    return phases, dict(title="slot settling", banner="Sound test 4: slot settling, 4 channels, 48 to 12 us.",
                        seconds_after=0)


def test_stereo():
    phases = []
    for v in (-127, -85, -42, 0, 42, 85, 127):
        ph = Phase(f"stereo {v:+d}", stereo=v, position=v)
        h = square_half(ph)
        ph.add_square("step", 2.0, code(96), 0, h, m=96, sign=1)
        ph.add_square("step", 2.0, code(96, True), 0, h, m=96, sign=-1)
        phases.append(ph)
    return phases, dict(title="stereo positions", banner="Sound test 5: the 7 stereo positions, 1 channel.",
                        seconds_after=0)


TESTS = dict(freqresp=test_freqresp, noise=test_noise, slots=test_slots, stereo=test_stereo)


def write_one(name):
    phases, meta = TESTS[name]()
    for ph in phases:
        ph.finish()
    asm = [f"; Generated by tools/audio/soundtests.py ({name}) -- do not hand-edit.",
           f"\t.equ\tN_PHASES, {len(phases)}",
           f"\t.equ\tDMA_OFF_AFTER, {1 if meta.get('dma_off_after') else 0}",
           "\t.p2align 2", "phase_table:"]
    data = []
    for i, ph in enumerate(phases):
        asm.append(f"\t.long\t{ph.channels}, {ph.period}, {ph.slot}, {ph.mode}, {ph.bg}, seq_{i} - blob_start")
        asm.append("\t.long\t" + ", ".join(str(int(v)) for v in ph.stereo))
    asm.append("\t.long\t0")
    for i, ph in enumerate(phases):
        asm.append("\t.p2align 2")
        asm.append(f"seq_{i}:")
        for j, s in enumerate(ph.segs):
            if s["type"] == "square":
                asm.append(f"\t.long\t{s['count']}\n\t.byte\t0, {s['a']}, {s['b']}, 0\n\t.long\t{s['half']}")
            else:
                asm.append(f"\t.long\t{s['count']}\n\t.byte\t1, 0, 0, 0\n\t.long\ttab_{i}_{j} - blob_start")
        asm.append("\t.long\t0")
        for j, s in enumerate(ph.segs):
            if s["type"] == "table":
                asm.append("\t.p2align 2")
                asm.append(f"tab_{i}_{j}:\n\t.long\t{len(s['table'])}")
                tb = s["table"]
                for k in range(0, len(tb), 32):
                    asm.append("\t.byte\t" + ", ".join(str(c) for c in tb[k:k + 32]))
    (ARC / f"{name}_seq.asm").write_text("\n".join(asm) + "\n", newline="\n")
    (ARC / f"{name}.asm").write_text(
        f"; Generated by tools/audio/soundtests.py -- do not hand-edit.\n"
        f"\t.include \"engine.asm\"\n"
        f"banner:\t.ascii \"{meta['banner']} Escape aborts.\"\n\t.byte 13, 10, 0\n\t.p2align 2\n"
        f"\t.include \"engine_blob.asm\"\n"
        f"\t.include \"{name}_seq.asm\"\n\t.p2align 2\nblob_end:\n", newline="\n")
    man = dict(test=name, **meta, phases=[dict(
        label=ph.label, channels=ph.channels, period_us=ph.period, slot=ph.slot, mode=ph.mode,
        bg=ph.bg, stereo=ph.stereo, fs_nominal=ph.fs, mark_half=ph.mark_half, info=ph.info,
        segments=[{k: v for k, v in s.items() if k != "table"} | (
            {"table": s["table"]} if s["type"] == "table" else {}) for s in ph.segs])
        for ph in phases])
    (HERE / f"{name}.json").write_text(json.dumps(man) + "\n", newline="\n")
    secs = sum(sum(s["count"] for s in ph.segs) / ph.fs for ph in phases) + meta.get("seconds_after", 0)
    print(f"{name}: {len(phases)} phases, about {secs:.0f} s")


def write():
    for name in TESTS:
        write_one(name)


if __name__ == "__main__":
    write()
