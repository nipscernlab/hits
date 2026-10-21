"""Writes the memory files of the hits_bus testbench (hits_bus_tb.v), next to this script.

  ones_mask.mif   3564 x 1 bit of 1: the mask hits_bus starts with
  ones_70.mif     512 x 70 bits of 1: the energy ROM it starts with
  ones_46.mif     256 x 46 bits of 1: the noise and jitter Gaussians it starts with
  ones_192.mif    64 x 192 bits of 1: the table of phases of the CSA shaper it starts with
  ones_210.mif    64 x 210 bits of 1: the table of phases of the F34 shaper it starts with
  mask_3000.mif   the mask of the reference: rtl/hits/bunch_train_mask.mif turned by 100
                  crossings and cut to an orbit of 3000

Every memory of hits_bus starts with every bit at 1, a content no real file has, so a word
the bus fails to load shows up (the real files end in words of 0, unused segments). Run: python make_testdata.py
"""
from pathlib import Path

here = Path(__file__).resolve().parent
rtl = here.parents[3] / "rtl"
w = lambda name, lines: (here / name).write_text("\n".join(lines) + "\n", newline="\n")
w("ones_mask.mif", ["1"] * 3564)
w("ones_70.mif", ["1" * 70] * 512)
w("ones_46.mif", ["1" * 46] * 256)
w("ones_192.mif", ["1" * 192] * 64)
w("ones_210.mif", ["1" * 210] * 64)
mask = [l.strip() for l in (rtl / "hits" / "bunch_train_mask.mif").read_text().splitlines() if l.strip()]
assert len(mask) == 3564
w("mask_3000.mif", (mask[100:] + mask[:100])[:3000])
