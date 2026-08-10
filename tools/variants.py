#!/usr/bin/env python3
"""The build variants, and the paths to each one's ground-truth artefacts.

The release build is the one shipped as QTMModule; the other three are built
from the same sources with different switches, and each has its own reference
binary captured from the original BASIC (there is no shipped binary for them).

The numbers below are what PROCinit computes, not free choices:

    IF qtmrast% THEN
     IF dmachoice=48 THEN uS=48:dma=416 ELSE uS=24:dma=832
    ELSE
     dmachoice=32:maxchans=8            -> uS=32, dma=208

and the shifts satisfy the driver's own assertion that
(1<<dmashift1)+(1<<dmashift2)+(1<<dmashift3) = dma.

BASIC's TRUE is -1 and FALSE is 0; those values are kept so that any arithmetic
on the flags behaves as it did in the original.
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

VARIANTS = {
    "release": dict(
        qtmrast=0, alphatest=0, dmachoice=32, uS=32, dma=208,
        dmashift1=4, dmashift2=6, dmashift3=7, maxchans=8,
        listing="listing.txt", module="QTMModule",
        note="the shipped build"),
    "rm24": dict(
        qtmrast=-1, alphatest=0, dmachoice=24, uS=24, dma=832,
        dmashift1=6, dmashift2=8, dmashift3=9, maxchans=4,
        listing="listing-rm24.txt", module="QTMModule-rm24",
        note="RasterMan, 24uS, 4-channel"),
    "rm48": dict(
        qtmrast=-1, alphatest=0, dmachoice=48, uS=48, dma=416,
        dmashift1=5, dmashift2=7, dmashift3=8, maxchans=8,
        listing="listing-rm48.txt", module="QTMModule-rm48",
        note="RasterMan, 48uS, 4/8-channel"),
    "alpha": dict(
        qtmrast=0, alphatest=-1, dmachoice=32, uS=32, dma=208,
        dmashift1=4, dmashift2=6, dmashift3=7, maxchans=8,
        listing="listing-alpha.txt", module="QTMModule-alpha",
        note="alpha test: DMA instrumentation counters, debug SWI"),
    # Experimental, and the first variant that is NOT a translation of the
    # original: the mixer is modified (see tools/gg/patch_dma.py) to drop the
    # per-byte loop wrap, which only works against samples prepared by
    # tools/prep.  It has no reference binary and never will, so it is built
    # and reported but not compared.  It derives from alpha so the DMA path
    # counters are available for a like-for-like measurement against it.
    "gg": dict(
        qtmrast=0, alphatest=-1, dmachoice=32, uS=32, dma=208,
        dmashift1=4, dmashift2=6, dmashift3=7, maxchans=8,
        listing=None, module=None, derives="alpha",
        patch="tools/gg/patch_dma.py",
        note="guard-gap mixer (experimental, no reference)"),
}

DEFAULT = "release"

# betatest%=TRUE in every variant; it is a source constant, not a switch.
BETATEST = -1


def get(name):
    if name not in VARIANTS:
        raise SystemExit("unknown variant %r (have: %s)"
                         % (name, ", ".join(VARIANTS)))
    return VARIANTS[name]


def base(name):
    """The variant whose ground-truth artefacts this one is generated against.

    An experimental variant has no listing or reference binary of its own, but
    generation still needs both -- bas2vasm reads the reference to derive the
    post-assembly patches, and the golden listing to resolve label addresses.
    It borrows them from the variant it derives from; only the *comparison* is
    skipped, via has_reference().
    """
    return get(name).get("derives") or name


def has_reference(name):
    """False for experimental variants, which are built but not compared."""
    return get(name).get("derives") is None


def listing_path(name):
    return ROOT / "ref" / get(base(name))["listing"]


def module_path(name):
    return ROOT / "ref" / get(base(name))["module"]


def src_dir(name):
    """Where a variant's own files go: the config header and version stamps."""
    return ROOT / "src" / name


def shared_dir():
    """The translated sources, which are identical for every variant."""
    return ROOT / "src" / "shared"


def constants(name):
    """The build switches, as (symbol, value, comment) for the .equ header."""
    v = get(name)
    order = ["qtmrast", "alphatest", "dmachoice", "uS", "dma",
             "dmashift1", "dmashift2", "dmashift3", "maxchans"]
    out = [("qtmrast", v["qtmrast"], v["note"])]
    out += [(k, v[k], "") for k in order if k != "qtmrast"]
    out += [("betatest", BETATEST, "TRUE in every variant"),
            ("accuracy", 12, ""), ("accdiff", 4, "16-accuracy%"),
            ("qtm_error", 0x809E00, "")]
    return out


def check():
    """The driver's own assertion on the DMA buffer size."""
    for name, v in VARIANTS.items():
        total = sum(1 << v["dmashift%d" % i] for i in (1, 2, 3))
        if total != v["dma"]:
            raise SystemExit("%s: dmashifts sum to %d, not dma=%d"
                             % (name, total, v["dma"]))


check()

if __name__ == "__main__":
    for name, v in VARIANTS.items():
        print("%-8s uS=%-3d dma=%-4d chans=%d  %s"
              % (name, v["uS"], v["dma"], v["maxchans"], v["note"]))
