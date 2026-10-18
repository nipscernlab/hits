# Build options

Every choice of HITS is made when the design is built: a parameter of
`hits` or a macro. With nothing set you get the default simulator, which
is the configuration this manual describes unless it says otherwise: the xoshiro
generator, the segmented energy spectrum, the F34 pulse shape, Gaussian noise with σ = 4 ADC counts and a rounding ADC.

Table 1 lists the choices. [Parameters and macros](reference/parameters.md)
gives every parameter with its default.

Table 1: the build options.

| Choice | Options | How to choose | Default |
|---|---|---|---|
| Random generator | `"xoshiro"`, `"round_robin"`, `"leap"` | parameter `RNG_TYPE` | `"xoshiro"` |
| Pulse shape | F34, CSA + CR-4RC, legacy | macro `USE_SHAPER_CSA_CR4RC` or `USE_SHAPER_LEGACY` | F34 |
| Energy spectrum | segmented inverse CDF (any spectrum in its ROM), three tables | parameter `MEM_SEG`; macro `USE_ENERGY_TABLES` | segmented, `energy_seg_default.mif` |
| Noise | Gaussian σ = 4, tables σ = 4, tables σ = 8 | macro `USE_NOISE_TABLES` or `USE_NOISE_SIGMA8` | Gaussian σ = 4 |
| ADC quantization | round to nearest, truncate | macro `USE_ADC_FLOOR` | round |
| CSA + CR-4RC pipeline | on, off | macro `USE_SHAPER_NO_PIPE` | on |
| Occupancy bypass | a hit on every filled crossing | parameter `OCC_BYPASS` | no bypass |
| Bunch-train mask | on, off | parameter `BUNCH_TRAIN_ACTIVE` | on |

## Setting a macro or a parameter

A macro is passed to the tool, or set by removing the comment from its
`` `define `` line at the top of `rtl/hits.v` (the lines ship
commented, so a macro passed to the tool always wins):

```sh
iverilog -DUSE_SHAPER_CSA_CR4RC ...                                  # Icarus Verilog
```

```tcl
# Quartus, in the .qsf
set_global_assignment -name VERILOG_MACRO "USE_SHAPER_CSA_CR4RC=1"
# Vivado
synth_design -verilog_define USE_SHAPER_CSA_CR4RC
```

A parameter is set where `hits` is instantiated, or by the tool on the
top module:

```verilog
hits #(.OCC_BYPASS(1)) sim ( ... );
```

```text
# Quartus, in the .qsf
set_parameter -name OCC_BYPASS 1
# Vivado
synth_design -generic {OCC_BYPASS=1}
```

The example testbench turns some macros into parameters, so that a single
command line chooses everything: `-DUSE_RNG_ROUND_ROBIN`, `-DUSE_RNG_LEAP`,
and `-DUSE_ENERGY_LORENZETTI`.

## Random generator

`RNG_TYPE` selects the generator of every stage. Table 2 compares them; the
statistical test is PractRand on the 10-bit words the stages used when the
comparison was made (2026-09-29).

Table 2: the random generators.

| `RNG_TYPE` | What it is | PractRand |
|---|---|---|
| `"xoshiro"` | xoshiro128**: a 128-bit xor, shift and rotate engine with a non-linear output scrambler | passes to 64 GB |
| `"round_robin"` | a bank of 7 LFSRs read in turn, the generator of the SBCCI 2025 paper; two reads of one LFSR share 3 of 10 bits, which shows as a lag-7 autocorrelation of +0.009 in `energy_out` | fails at 1 MB |
| `"leap"` | one LFSR advanced W steps per clock; the cheapest, but linear | fails at 1 MB |

The three were checked in the simulator over 713 000 cycles: hit rates against
the occupancy, and the energy and noise distributions against the ones their
tables define. Only xoshiro passes a full test battery. The segmented energy
spectrum and the Gaussian noise need xoshiro; with the other generators those
stages use their tables.

The xoshiro seeds are the parameters `XO_SEED_HIT`, `XO_SEED_ENERGY` and
`XO_SEED_NOISE`. The defaults are one seed
and its jumps of 2^64 and 2 × 2^64 steps. Several channels in one design must not
share streams: `python rtl/random/xoshiro_jump.py channels C` prints the four
seeds of each of C channels, and checks the jump constants against the
transition matrix of the generator.

## Pulse shape

Each shaper reproduces the pulse of one front end, sampled at the rate of the
readout, with the
peak of a pulse equal to its energy. Table 3 describes the three.

Table 3: the pulse shapes.

| Shaper | Selected by | Pulse | Latency |
|---|---|---|---|
| `shaper_fenics_f34.v` | default | the FENICS front end of the Phase-II upgrade: its testbeam pulse, fitted with a 14-pole transfer function; FIR head of 13 taps and 5 IIR sections; shape error 0.026% of the peak; zero DC gain imposed | 7 cycles |
| `shaper_csa_cr4rc.v` | `USE_SHAPER_CSA_CR4RC` | the generic pulse of the papers of the group: bi-exponential detector pulse, charge-sensitive amplifier (CSA) with a 51 ns feedback pole, unbuffered CR-4RC shaper with a 500 µs CR and four 5 ns RC stages; peak at 60.1 ns, full width at half maximum 114 ns; shape error 1e-7 of the peak | 5 cycles (1 with `USE_SHAPER_NO_PIPE`) |
| `shaper_fenics.v` | `USE_SHAPER_LEGACY` | the shaper HITS was born with: parallel IIR sections at a 2^10 scale, an older approximation of the FENICS response; over a long run its baseline settles about 5 ADC counts below the pedestal | 2 cycles |

Latency is the delay from `event_bt` to `shaper_out`; it shifts the pulse train
and does not change it. Two shapers at once stop the compilation with an
`Unknown module type: ERROR_two_shapers_...` that names them.

## Energy spectrum

The energy ROM is the spectrum. `MEM_SEG` names the ROM of the segmented
inverse CDF; a ROM is generated for a spectrum, and two come with HITS:

- `energy_seg_default.mif`: a placeholder spectrum, mean 34 ADC counts, 99%
  below 156;
- `energy_seg_lorenzetti.mif`: the energy per bunch crossing of the hottest cell
  of the hadronic barrel in the public Lorenzetti simulator, 200 interactions per
  crossing, 3 ADC counts per MeV of visible energy; mean 9.5 ADC counts per
  crossing, with a deposit in 65530 of 65536 crossings.

The ROM holds the spectrum of the crossings that have a deposit; the occupancy
carries the probability of a deposit. The Lorenzetti spectrum is used with
`occupancy` = 65530, that probability (65530/65536, 99.991%).

`USE_ENERGY_TABLES` selects the three-table inverse CDF of the first paper
(`energy_icdf_paper_0..2.mif`): a staircase of about 3000 values that stops
resolving the tail below about 1e-6.

## Noise

The default noise is a Gaussian with σ = 4 ADC counts, from a segmented inverse
CDF (`noise_gauss.v`, ROM `noise_gauss_s4.mif`), correct out to 6.34 σ.
`USE_NOISE_TABLES` selects the three-table inverse CDF with σ = 4; its tail stops
at 6.48 σ with 120 times too much probability above 6 σ. `USE_NOISE_SIGMA8`
selects the tables with σ = 8, the noise of the first paper.

## ADC

The ADC adds `offset`, rounds to the nearest count and saturates to 0..4095.
`USE_ADC_FLOOR` truncates instead, as the first paper did; truncation reads half
a count low on average.

## Occupancy

`occupancy` is a 16-bit input: the hit probability is `occupancy`/65536 in each
filled bunch crossing. `OCC_BYPASS` = 1 makes every
filled bunch crossing a hit. `BUNCH_TRAIN_ACTIVE` = 0 turns the mask off, so
every bunch crossing is filled.
