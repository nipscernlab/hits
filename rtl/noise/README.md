# Electronic noise of the simulator (`rtl/noise/`)

`noise_generator.v` draws one noise sample per 25 ns clock and the simulator
adds it to the shaper output, before the ADC (`shaper_corrupted`). The draw is
an inverse CDF over three tables (`noise_icdf.v` + `noise_icdf0..2.mif`, the
multi-memory approach): 10-bit uniform words pick a magnitude, one more bit
picks the sign.

## The level: sigma = 8 ADC counts at 12 bits

A design choice, not the value of any given channel:

- the TileCal pedestal runs are taken with a 10-bit ADC range, while the
  Phase-II demonstrator already uses 12 bits, which is the standard of HITS;
- the pedestal sigma of a typical channel, rounded to a generic value, is
  2 ADC counts at 10 bits; HITS does not use the exact value of each ATLAS
  channel;
- at 12 bits that is 2 x 4 = **8 ADC counts**.

When comparing with data, bring everything to 12 bits first: a 10-bit sigma
counts x4, and a readout that drops one most and one least significant bit of
a wider word doubles it.

### ⚠️ The x4 assumes the same charge per count, and Phase II doubles the range

Checked in public sources on 2026-09-29 (list below). Going from the legacy
10-bit readout to the Phase-II 12-bit one does **not** multiply the counts per
pC by 4, because the high-gain range doubles at the same time:

| | legacy (Run 1-3) | Phase II (FEB / FENICS design) |
|---|---|---|
| fast ADC | 10 bits | 12 bits |
| high / low gain ratio | 1:64 | 1:32 |
| high-gain range | saturates above ~10 pC (1023 counts) | 0-25 pC ("under tuning") |
| high-gain ADC counts per pC | **~81** (typical channel, CIS) | **~164** (25 pC over 4096 counts; our arithmetic) |
| electromagnetic scale | 1.050 pC/GeV | 1.050 pC/GeV |
| energy per high-gain count | 1/(81 x 1.050) = **~11.8 MeV** | 1/(164 x 1.050) = **~5.8 MeV** |

So a charge noise that gives 2 counts in the legacy 10-bit high gain (~25 fC)
gives **~4 counts** in the Phase-II 12-bit high gain, not 8, if the noise in
charge stays the same (the Phase-II demonstrator measured lower noise than a
legacy drawer). The sigma of HITS is still 8: changing it is a decision to be
taken, recorded here so that it is taken knowingly.

Caveats: the Phase-II range comes from the 2013 FEB design and a 2019 paper that
calls it "under tuning" (HV active dividers raise the PMT gain by up to 20%);
the final value was not found in open sources (the Phase-II TDR, CERN-LHCC-2017-019,
is on CDS). The 81 counts/pC is the typical channel read from a plot (CIS
systematic 0.7%, EM-scale RMS spread 2.4%). The arithmetic assumes the 25 pC
span fills the 4096 counts; the pedestal takes part of them. Whether the MeV
above are per channel (PMT) or per cell (two PMTs) is to be confirmed.

Sources:
- ATLAS Collaboration, *Operation and performance of the ATLAS tile calorimeter
  in LHC Run 2*, Eur. Phys. J. C 84 (2024) 1313, arXiv:2401.16034 (CIS ~81
  ADC/pC high gain, 1.050 pC/GeV, high gain saturated above 10 pC at 1023 ADC);
- F. Tang et al., *Design of the Front-End Readout Electronics for ATLAS Tile
  Calorimeter for the sLHC*, IEEE TNS 60 (2013) 1255 (gain ratio 32, two 12-bit
  ADCs, 0-25 pC high gain, 25-800 pC low gain, 17-bit dynamic range);
- *Upgraded Electronics of the ATLAS Hadronic Tile Calorimeter for the High
  Luminosity LHC*, arXiv:2002.06427, JINST CHEF2019 (32:1, "typically about
  0-25 pC for the high gain", under tuning);
- M. N. Agaras, arXiv:2105.09099 (FENICS fast readout from 200 fC to 1000 pC);
- arXiv:1709.00099 (24 12-bit ADCs, ratio 1:32);
- E. Valdes Santurio et al., arXiv:2010.14980 (demonstrator 12-bit 1:32, 17-bit
  dynamic range, against legacy 1:64, 16-bit; its high-gain values read at half
  in the legacy software because of the gain ratio).

## What the tables generate (measured 2026-09-28)

The exact distribution the three tables define with uniform words:

| | tables | Gaussian |
|---|---|---|
| sigma | 7.99 ADC | |
| kurtosis | 2.985 | 3 |
| P(\|x\| > 3 sigma) | 2.6e-3 | 2.7e-3 |
| P(\|x\| > 4 sigma) | 5.5e-5 | 6.3e-5 (-14%) |
| P(\|x\| > 5 sigma) | 7.2e-7 | 5.7e-7 (+25%) |
| P(\|x\| > 6 sigma) | 2.4e-7 | 2.0e-9 (**x120**) |

The core is Gaussian. The tail is not: everything above 6 sigma sits on a
single value, 6.48 sigma (the last entry of table 2, probability 2.4e-7), and
nothing goes beyond it. At 40 MHz that is about 10 samples per second at
6.5 sigma, where a Gaussian gives one every ~12 s. It matters only for studies
of noise at high thresholds, but it is there. The level is fixed by the table
contents: a different sigma needs new tables.

The noise is white: consecutive samples are independent.

## Why the real TileCal noise was a double Gaussian

From *Operation and performance of the ATLAS Tile Calorimeter in Run 1*, ATLAS
Collaboration, Eur. Phys. J. C 78 (2018) 987, arXiv:1806.02129, pages 13-15:

- "During Run 1 the electronic noise of a cell is best described by a double
  Gaussian function, with a narrow central single Gaussian core and a second
  central wider Gaussian function to describe the tails", fitted with three
  parameters (sigma1, sigma2 and the relative normalisation R, both means 0):

  f(x) = 1/(1+R) * [ N(x; 0, sigma1) + R * N(x; 0, sigma2) ]

- The cause: "The double Gaussian behaviour of the electronic noise is believed
  to originate from the LVPS used during Run 1, as the electronic noise in test
  beam data followed a single Gaussian distribution, and this configuration used
  temporary power supplies located far from the detector." (LVPS: the
  low-voltage power supply of each super-drawer, in a box just outside it.)
- New LVPS versions (five in December 2010, 40 more in the 2011-2012 winter
  shutdown, 16% of all) gave "lower and more single-Gaussian-like" channel noise:
  the RMS over the width of a single-Gaussian fit came closer to 1 (their
  Figure 9), and the average high-high gain cell noise went from about 23.5 MeV
  to 20.6 MeV. Cells in the highest |eta| are made of channels physically near
  the LVPS and are noisier (close to 40 MeV).
- There is also a coherent component: sizeable correlation only between
  channels on the same motherboard (12 consecutive channels), from (-40%, +70%)
  down to (-20%, +10%) after mitigation, which also reduced the tails.
- ATLAS Monte Carlo emulates it per cell, with the double Gaussian constants
  derived from data.

## Phase II: open

The Phase-II front end has new LVPS, redesigned for efficiency and radiation
hardness at the HL-LHC (S. Moayedi et al., *Upgrade of the ATLAS Tile
Calorimeter front-end power supply for the HL-LHC*, JINST 21 (2026) C05002; the
paper reports the design and radiation tests, not the noise shape). Pedestal
tests of the Phase-II demonstrator showed lower noise than a legacy drawer,
attributed to its larger dynamic range (E. Valdes Santurio et al.,
arXiv:2010.14980, IEEE RT 2020). **No publication found (2026-09-28) says
whether the Phase-II noise is single or double Gaussian.** It can be measured:
every Phase-II front-end board goes through the PROMETEO certification bench.

For HITS this means: a single Gaussian with a correct tail is the base; a
double Gaussian (sigma1, sigma2, R) is worth an option only if Phase-II
measurements show tails.
