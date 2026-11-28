"""Model of the VIDC1 sound output and QTM's sample path, from the VIDC datasheet.

Sources:
  VIDC Datasheet (Acorn, 1986) section 6.10, pages 32-33:
    - 7-bit exponential DAC plus a sign bit that steers the current to a "+" or "-" pin pair
    - 8 chords of 16 steps; each chord's step is twice the previous; i = Iref/8
    - chord boundaries at 0, i, 3i, 7i, 15i, 31i, 63i, 127i; last step ends at 247i
    - stereo by time division between left and right pins; first quarter of each slot muted
    - SFR in 1 us units per byte, minimum 3 us
  QTM v1.49b: linear-to-log table = Sound_SoundLog of each signed byte (qtm_mod.asm
  setlinlogtab), dumped in tools/prep/linlog.bin; volume = byte SUB, clamp at 0
  (qtm_dma.asm a3_anyvolume); volume table from setvoltabs.

Byte format as RISC OS stores it (and linlog.bin shows): bit 0 = sign (1 = negative),
bits 7-1 = magnitude m, chord = m >> 4, point = m & 15. The datasheet draws VIDC1 with the
sign in D7; the board must route the bits, which the code-sweep recording will confirm.
"""
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parent
LINLOG = HERE.parent / "prep" / "linlog.bin"


def magnitude(m):
    """DAC current for magnitude code m (0-127), in units of i (datasheet Fig. p33)."""
    m = np.asarray(m)
    c, p = m >> 4, m & 15
    return (2.0 ** c) * (1 + p / 16.0) - 1


MAG = magnitude(np.arange(128))          # 0 .. 247
FULL = MAG[-1]


def decode(code, pos_gain=1.0, neg_gain=1.0):
    """Byte code(s) -> signed DAC value in units of i. Gains model + / - pin mismatch."""
    code = np.asarray(code, dtype=np.int64)
    v = MAG[code >> 1]
    return np.where(code & 1, -v * neg_gain, v * pos_gain)


def os_linlog():
    """QTM's linear-to-log table: index = signed 8-bit sample as unsigned byte."""
    return np.frombuffer(LINLOG.read_bytes(), dtype=np.uint8).astype(np.int64)


def nearest_linlog(scale=None):
    """Table choosing the DAC level nearest to scale * x, with the same full-scale as the OS."""
    if scale is None:
        scale = 2.0                       # the OS maps linear x to about 2x i (see analysis)
    tab = np.zeros(256, dtype=np.int64)
    for u in range(256):
        x = u - 256 if u >= 128 else u
        target = abs(x) * scale
        m = int(np.argmin(np.abs(MAG - target)))
        tab[u] = (m << 1) | (1 if x < 0 and m else 0)
    return tab


def qtm_volume_sub(v, linlog=None):
    """Value QTM subtracts from the byte for linear volume v (0-64), from setvoltabs:
    (0xFF - SoundLog(v << 25)) AND 0xFE. SoundLog(v<<25) = linlog[2v] (2v=128 -> -128)."""
    if linlog is None:
        linlog = os_linlog()
    return (0xFF - int(linlog[(2 * v) & 0xFF])) & 0xFE


def apply_volume(codes, sub):
    """QTM a3_anyvolume: SUBS r6,r6,r3 / MOVMI r6,#0."""
    out = np.asarray(codes, dtype=np.int64) - sub
    return np.where(out < 0, 0, out)


def to_unsigned(x):
    return np.asarray(x, dtype=np.int64) & 0xFF


# ---------------------------------------------------------------------------- measures

def sine_8bit(n, cycles, amp=127.0, phase=0.3):
    t = np.arange(n)
    return np.round(amp * np.sin(2 * np.pi * cycles * t / n + phase)).astype(np.int64)


def snr_thd(y, cycles, harmonics=9):
    """For a coherent sine of `cycles` periods in y: (SINAD dB, THD dB, gain)."""
    Y = np.fft.rfft(y - y.mean())
    P = np.abs(Y) ** 2
    sig = P[cycles]
    harm = sum(P[k * cycles] for k in range(2, harmonics + 1) if k * cycles < len(P))
    noise = P[1:].sum() - sig
    amp = 2 * np.abs(Y[cycles]) / len(y)
    return 10 * np.log10(sig / max(noise, 1e-30)), 10 * np.log10(max(harm, 1e-30) / sig), amp


# ---------------------------------------------------------------------------- TDM output

def tdm_output(slot_values, slot_us, stereo, oversample=96, mute=0.25):
    """Render the left and right pin currents for interleaved slots.

    slot_values: array (frames, N) of signed DAC values, one per channel slot.
    stereo: per-channel fraction of the slot's active time sent left (1=left, 0=right),
            datasheet positions 1, 5/6, 2/3, 1/2, 1/3, 1/6, 0.
    Returns (left, right, fs_render) where each slot is `oversample` points long.
    The first `mute` of every slot is silent (datasheet: DAC settling and deglitching).
    The datasheet's figure shows the left part of the active time going to one side; the
    order within the slot only changes the phase of content at the slot rate.
    """
    frames, n = slot_values.shape
    k = np.arange(oversample) / oversample
    active = k >= mute
    act_frac = (k - mute) / (1 - mute)
    L = np.zeros((frames, n, oversample))
    R = np.zeros_like(L)
    for ch in range(n):
        left_part = active & (act_frac < stereo[ch])
        right_part = active & ~left_part
        L[:, ch, :] = slot_values[:, ch, None] * left_part
        R[:, ch, :] = slot_values[:, ch, None] * right_part
    fs_render = oversample / (slot_us * 1e-6)
    return L.reshape(-1), R.reshape(-1), fs_render
