# The signal chain

`hits` produces one sample per clock cycle, and one cycle is one bunch crossing
of the collider: the sampling of a high-speed readout. Figure 1 shows the chain.
Each block is a folder of `rtl/`; above each block is the random generator it
draws from, and below it what sets it, at run time (an input) or at synthesis (a
parameter or a memory file).

```{figure} images/signal-chain.svg
:alt: The HITS chain: hit draw, energy draw, pulse shaper, and noise with ADC in a row, linked by hits_out, event_bt, shaper_out and shaper_clip; the random generators above, the inputs and synthesis choices below.
:width: 100%

Figure 1: the HITS chain, one sample per clock cycle.
```

`shaper_clip`, the 12-bit ADC sample, is the output of the core. The other
outputs expose the intermediate signals for inspection.

## Stages

`random/` holds the pseudo-random generators. Every stage that draws has its
own generator; by default each is a xoshiro128** (Blackman and Vigna), whose
32-bit result is cut into the words that stage needs. The three generators start
from one seed and its jumps of 2^64 and 2 × 2^64 steps, so their sequences never
overlap. Two older generators remain for reproducing earlier work: a round-robin
bank of linear-feedback shift registers (LFSR) and a leap-forward LFSR.

`hits/` decides, every bunch crossing, whether a hit happens. The draw is a
Bernoulli trial with probability `occupancy`/65536. A hit only passes where
the bunch-train mask has a filled slot: the mask holds 3564 slots, one orbit of
the collider, and is read from `bunch_train_mask.mif`.

`energy/` draws an energy every cycle, in whole ADC counts, used only when a
hit happens. By default it is a segmented inverse cumulative distribution
function (CDF) of one 32-bit word: the probability axis is cut into octaves from
both ends, 8 segments per octave, with a degree-2 polynomial in each segment,
held in a ROM of 512 words. It has no staircase and reaches a tail probability
of 2^-32. The spectrum is the ROM: `energy_seg_default.mif` is a placeholder
spectrum (mean 34 ADC counts, 99% below 156), and `energy_seg_lorenzetti.mif`
is the spectrum of the revised paper (see [Reproducing the papers](papers.md)).
The three-table inverse CDF of the first paper remains as an option.

`shaper/` turns the train of energies into the analog pulse train of the front
end. It is a linear filter at the sampling rate of the readout: a short finite impulse response (FIR) head
for the fast part of the pulse and infinite impulse response (IIR) sections for
the slow tail. Three pulse shapes exist, and the phase of the pulse can be moved
(see [Build options](options.md)). The output `shaper_out` is in fixed point,
with the peak of a pulse at 2^10 times its energy in ADC counts.

`noise/` adds the electronic noise of the channel: a Gaussian with σ = 4 ADC
counts, drawn by a segmented inverse CDF that is correct out to 6.34 σ. The
noise tables of the first paper, with σ = 4 and σ = 8, remain as options. Why σ
is 4 counts, and where the noise model came from, is in
[`rtl/noise/README.md`](https://github.com/nipscernlab/hits/blob/main/rtl/noise/README.md).

`adc/` adds the pedestal (`offset`), drops the fixed-point scale rounding to the
nearest count, and saturates the result to 0..4095.

## Ports

| Port | Direction | Width | Meaning |
|---|---|---|---|
| `clk` | in | 1 | the clock, one cycle per bunch crossing |
| `rst` | in | 1 | reset, active high, asynchronous; clears every state, so a run after a reset repeats exactly |
| `occupancy` | in | 16 | hit probability, `occupancy`/65536 per filled bunch crossing |
| `offset` | in | 13, signed | the pedestal, in ADC counts |
| `hits_out` | out | 1 | 1 when a hit happens in this bunch crossing, after the bunch-train mask |
| `bt_mask_out` | out | 1 | the bunch-train mask (1 = filled slot) |
| `energy_out` | out | 13 | the energy drawn this cycle, in ADC counts |
| `event_bt` | out | 13 | `energy_out` where a hit happens, with the mask: the input of the shaper |
| `event_all` | out | 13 | the same without the mask |
| `shaper_out` | out | 30, signed | the shaped pulse train, without noise, at the scale 2^10 |
| `noise_out` | out | 17, signed | the noise sample, at the scale 2^10 |
| `shaper_corrupted` | out | 30, signed | `shaper_out + noise_out` |
| `shaper_clip` | out | 12 | the ADC sample: the output of the simulator |

The widths in the table are those of the default parameters (`ENG_OUT_BITS` =
13). `occupancy` and `offset` may change at any time; they are sampled on the
clock like any input.
