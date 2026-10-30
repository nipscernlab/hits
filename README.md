<p align="center">
  <img src="https://raw.githubusercontent.com/nipscernlab/nipscernweb/main/assets/icons/hits-badge.svg"
       alt="HITS emblem"
       width="220">
</p>

# HITS: Hardware Impulse Train Synthesizer

Real-time FPGA simulator of calorimeter readout pulses, running at 40 MHz on a
Terasic DE10-Nano (Intel Cyclone V SoC). It emulates the front-end signal chain
of a hadronic calorimeter readout: pseudo-random hit generation following a
periodic bunch-train structure, energy amplitudes drawn from a spectrum held
in ROM, electronic noise, analog pulse shaping and digitization.
Occupancy and pedestal are configurable at runtime from the embedded ARM
processor (HPS). It is used to validate online energy-reconstruction techniques
without access to the experiment; those techniques are not part of the
simulator.

Developed by [NIPS-CERN](https://nipscern.com) (Federal University of Juiz de
Fora, Brazil).

## The signal chain

One sample per 25 ns clock. Every box is a folder of `rtl/`; the top that wires
them is `rtl/hits.v`.

```
             OCCUPANCY (register of the configuration bus)
                   |
 random/ --> hit_generation/ (Bernoulli draw x bunch-train mask) --- hit ---+
                                                                  |
 random/ --> energy/ (segmented inverse CDF) -------- energy ---> [x] event_bt
                                                                  |
                                                     shaper/ (one of three pulse shapes)
                                                                  |  shaper_out
 random/ --> noise/ (Gaussian, segmented inverse CDF) - noise --> [+] shaper_corrupted
                                                                  |
             PEDESTAL (register of the configuration bus) ---> adc/ (offset, round, clip 0..4095)
                                                                  |
                                                             shaper_clip  = THE SIMULATOR OUTPUT
```

Outputs of `hits`, all on the same clock:

| Signal | What it is |
|---|---|
| `hits_out` | 1 when a hit happens in this bunch crossing (after the bunch-train mask) |
| `bt_mask_out` | the bunch-train mask itself (1 = filled slot) |
| `energy_out` | the energy amplitude drawn this cycle (drawn every cycle, used only on a hit) |
| `event_bt` / `event_all` | `energy_out` times the hit, with / without the bunch-train mask |
| `shaper_out` | the shaped pulse train, noiseless, at the fixed-point scale 2**10 |
| `noise_out` | the electronic noise sample |
| `shaper_corrupted` | `shaper_out + noise_out` |
| `shaper_clip` | the 12-bit ADC sample: what the readout electronics would see |

## Quick start

**Simulate, no hardware.** From the repo root, with Icarus Verilog:

```sh
cd verification/testbenches
iverilog -s hits_tb -o tb.vvp ../../rtl/*.v ../../rtl/hits/*.v ../../rtl/components/*/*.v hits_tb.v
vvp tb.vvp                  # writes hits_tb.vcd: open it in GTKWave or Surfer
```

Or open `projects/aurora/hits.spf` in Aurora and press the wave
button (see *Simulating without hardware*).

**Check that nothing broke** after any change to the RTL:

```sh
python verification/regress.py      # exit 0 = every build bit-identical to its golden
```

**Run on the board:** see *Running on the DE10-Nano board*.

## Build options at a glance

Everything that changes what is built. With nothing set you get the default
simulator: xoshiro generator, F34 shaper (the FENICS Phase-II pulse), Gaussian
noise with sigma = 4 ADC.

| Choice | Options | How to choose | Default |
|---|---|---|---|
| Random generator | `"xoshiro"`, `"round_robin"`, `"leap"` | `RNG_TYPE` parameter of `hits` (on the board: `de10_nano_soc_ghrd.v`); in `hits_tb.v`, `-DUSE_RNG_ROUND_ROBIN` or `-DUSE_RNG_LEAP` | `"xoshiro"` |
| Pulse shape | F34 (FENICS Phase II), legacy, CSA + CR-4RC | macro `USE_SHAPER_LEGACY` or `USE_SHAPER_CSA_CR4RC` | F34 (since 2026-10-01) |
| Energy spectrum | segmented inverse CDF (ROM `MEM_SEG`), the three tables | macro `USE_ENERGY_TABLES`; the round_robin and leap generators always use the tables; in `hits_tb.v`, `-DUSE_ENERGY_LORENZETTI` loads `energy_seg_lorenzetti.mif` with its occupancy (65530/65536) | segmented, ROM `energy_seg_default.mif` (since 2026-10-08) |
| Noise | Gaussian (segmented inverse CDF), the sigma = 4 tables, the sigma = 8 tables | macro `USE_NOISE_TABLES` or `USE_NOISE_SIGMA8`; the round_robin and leap generators always use the tables | Gaussian, sigma = 4 (since 2026-10-02) |
| ADC quantization | round to nearest, truncate | macro `USE_ADC_FLOOR` (truncate) | round (since 2026-10-03) |
| CSA + CR-4RC pipeline | on, off | macro `USE_SHAPER_NO_PIPE` (off) | on (input register since 2026-10-03; full pipeline, latency 5, since 2026-10-14) |
| Occupancy, pedestal | 16-bit occupancy (hit probability occupancy/65536; the round_robin and leap generators use its top 7 bits), 13-bit offset | registers `OCCUPANCY`, `PEDESTAL` of the configuration bus, starting at the parameters `OCCUPANCY_INIT`, `PEDESTAL_INIT` (docs/guide/configuring.md); on the board with the ARM, the top 7 bits from the HPS (`./change_occupancy`) | 0, 0 (the testbench and the boards set their own) |
| Occupancy bypass | `OCC_BYPASS` = 1: a hit on every filled bunch crossing | synthesis parameter of `hits` | no bypass |
| Pulse phase (F34, CSA + CR-4RC) | fixed phase `PHASE0` (−32..31 steps of 0.390625 ns); Gaussian jitter per hit `SIGMA_PS` (ps, no cut) | synthesis parameters of `hits`; in `hits_tb.v`, `-DUSE_PHASE0=<n>` and `-DUSE_PHASE_SIGMA_PS=<ps>` | none (`PHASE0` = 0, `SIGMA_PS` = 0: the shaper of before, bit for bit; since 2026-10-17) |

A macro is passed with `-D` (Icarus) or `VERILOG_MACRO` (Quartus `.qsf`), or by
uncommenting its `` `define `` line; details in the sections below. Each
combination that the regression knows has its own golden VCD.

## Coming from the paper version (before 2026-09-14)

The code of Fabio's Sensors Journal paper is the tag `paper-jsen-2026`. Since
then the files were reorganized, and a few things changed behaviour. If you
knew the repo then, this is where things went:

| At `paper-jsen-2026` | Now |
|---|---|
| `rtl/FPGA_Simulator_v1.v` | `rtl/hits.v` (module `hits`) |
| `rtl/Hits_Bunch_train.v`, `rtl/hits_positions.v` | `rtl/components/hit_generation/hit_generator.v`, `rtl/components/hit_generation/hit_draw.v` |
| `rtl/bunch_train_mask.v` + `.mif` | `rtl/components/hit_generation/` |
| `rtl/energy_collisions.v`, `rtl/energy_distribution.v` | `rtl/components/energy/energy_generator.v`, `rtl/components/energy/energy_icdf.v` |
| `rtl/<cell>_PART1..3.mif` (at the paper tag) | `rtl/components/energy/energy_icdf_paper_0..2.mif` (same content) |
| `rtl/noise_collisions.v`, `rtl/noise_distribution.v` | `rtl/components/noise/noise_generator.v`, `rtl/components/noise/noise_icdf.v` |
| `rtl/NOISE_PART1..3.mif` | `rtl/components/noise/noise_s8_icdf0..2.mif` (same content; no longer the default) |
| `rtl/random_number_generator.v`, `rtl/select_rand.v`, `rtl/rand_LFSR.v` | `rtl/components/random/rng_round_robin.v` + `lfsr42.v`, chosen through `rtl/components/random/rng.v` |
| `rtl/filtros/` | `rtl/components/shaper/` |
| `rtl/clip_shaper.v` | `rtl/components/adc/adc.v` |
| `rtl_test/` | `projects/de10_nano_arm/hardware/reconstruction/` (PZC, baseline estimator and the wrapper `hits_reco.v`) |
| `projects/aurora/` (simulator + PZC) | the PZC project was removed on 2026-10-21 (tag `last-with-reconstruction`); `projects/aurora/` now holds `hits.spf`, the simulator alone, with `verification/testbenches/hits_tb.v` |
| `projects/quartus/` (board with the ARM) | `projects/de10_nano_arm/`; the simulator alone on the board is `projects/de10_nano/` |
| comparing VCDs by hand | `python verification/regress.py`, also run by CI and by the pre-commit hook |

What changed behaviour (the rest is renaming and cheaper circuits with the same
outputs):

- **Default shaper is now F34** (2026-10-01), the 40 MHz filter of the FENICS
  testbeam pulse, not the legacy `shaper_fenics.v`; the legacy one is
  `USE_SHAPER_LEGACY`. Its pipeline (2026-10-01) gives it a latency of 7
  clocks (4 before); since 2026-10-03 the legacy and CSA shapers have their
  input registered too (output 2 and 1 samples later); `USE_SHAPER_NO_PIPE`
  removes that register for the paper build. Since 2026-10-14 the CSA shaper is
  pipelined outside its section loops (latency 5, the same values 3 samples
  later): with it the simulator goes 53.7 -> 79.2 MHz on the Cyclone V.

- **Default generator is now xoshiro128\*\*** (2026-09-28), not the round robin
  of the paper: the round robin fails the PractRand battery. Same statistics,
  different sequences.
- **Default noise is now sigma = 4 ADC** (2026-09-29), not 8: the Phase-II ADC
  scale doubles the full range. Why, in [`rtl/components/noise/README.md`](rtl/components/noise/README.md).
- **Default noise is now a true Gaussian** (2026-10-02, `noise_gauss.v`): the three
  tables stopped at 6.48 sigma with 120x too much probability above 6 sigma; the
  Gaussian is correct up to 6.34 sigma. The tables remain (`USE_NOISE_TABLES`).
- **xoshiro seeds by jump** (2026-10-14): the energy and noise generators start from
  the hit generator's seed jumped 2^64 and 2 x 2^64 steps, so the three streams
  provably never overlap (`rtl/components/random/xoshiro_jump.py` prints and checks them). Same
  statistics, other sequences; the round-robin and leap builds, and `paper`, are unchanged.
- **Fine occupancy and bypass** (2026-10-09): with xoshiro the hit draw is 16 bits,
  threshold {occupancy, `OCC_LSB`}; the 7 bits from the HPS keep their meaning
  (occupancy/128) and, with `OCC_LSB` = 0, the hits are bit for bit the old ones.
  Since 2026-10-18 the occupancy input itself is 16 bits and `OCC_LSB` is gone: the
  same threshold, given whole.
  `OCC_BYPASS` = 1 hits every filled bunch crossing. The energy ROM is the
  spectrum of bunch crossings WITH a deposit; the occupancy carries P(deposit).
- **Default energy is now a segmented inverse CDF** (2026-10-08, `energy_seg.v`):
  the three tables give a staircase of about 3000 values and stop resolving the
  tail below ~1e-6; the segmented form is smooth and reaches 2^-32. The spectrum
  is a ROM; the default is a placeholder (mean 34 ADC per bunch crossing), not
  the tables' spectrum. The tables remain (`USE_ENERGY_TABLES`).
- **Energy ROMs continuous and monotone** (2026-10-15): each segment's polynomial
  now passes through the target spectrum at both ends and only its curvature is
  fitted, kept small enough for the integer evaluation to stay monotone. With
  the free fit used before, a spectrum with structure put the end of a segment
  up to 6 ADC away from the start of the next one (the Lorenzetti ROM: 15 places
  where the energy stepped back, and values such as 177 and 178 ADC that never
  came out; the default ROM: 3 steps back of 1 ADC and 389 ADC never drawn).
  Checked over all 2^32 words: no step back, and no value missing except in the
  far tail, where two neighbouring words already differ by more than 1 ADC. Both
  ROMs were regenerated; the goldens of every build with segmented energy changed.
- **The ADC rounds to the nearest count** (2026-10-03); it used to truncate, which
  read 0.5 count low on average. `USE_ADC_FLOOR` keeps the truncation.
  Since 2026-10-01 its tables have 10-bit entries (3 M10K instead of 6), with
  the same statistics; one ADC sample in ~160 moves by one count.
- **The testbenches release reset one clock later** (2026-09-26), so every
  waveform is the old one delayed by one cycle; all goldens were regenerated.
- **The legacy shaper and the round-robin generator are now cleared by reset**
  (2026-09-26), so a reset in the middle of a run repeats the run.
- Energy and noise tables are now in block RAM (M10K) and the round robin is a
  rotating bank without a multiplexer: same outputs, less logic, so the resource
  numbers of the paper come only from the tag.

To get the paper's behaviour on today's code, use the `paper` build (see
*Reproducing the HITS of the Sensors Journal paper*).

## Repository layout

```
rtl/hits.v                       THE SIMULATOR, its top: hits_core + the configuration bus
rtl/hits/                        hits_core.v (the circuit), hits_cfg.v (the registers of the bus) and hits_sapho.v (the SAPHO adapter)
rtl/components/random/           Pseudo-random generators (three kinds, chosen by RNG_TYPE), used by every stage that draws
rtl/components/hit_generation/   Hit draw + bunch-train mask
rtl/components/energy/           Energy amplitude (segmented inverse CDF; the 3 tables remain)
rtl/components/shaper/           Pulse shapers: three shapes, selectable at synthesis time (see below)
rtl/components/noise/            Electronic noise (Gaussian by segmented inverse CDF, or 3 inverse-CDF tables)
rtl/components/adc/              Pedestal, quantization and saturation: the simulator output
projects/aurora/                 Aurora project of the simulator alone (simulation; the testbench is verification/testbenches/hits_tb.v)
projects/de10_nano/              Quartus project for the DE10-Nano: no HPS, no Qsys, the configuration bus on the GPIO headers (enabled by SW0), occupancy and pedestal set at power-up
projects/zybo/                   Vivado: hits_vivado.tcl synthesizes the core out of context for any part (default xc7z010clg400-1); not yet a board project
projects/de10_nano_arm/          The DE10-Nano SoC (FPGA + ARM/HPS): simulator + reconstruction technique; its README says what is generated and how
projects/de10_nano_arm/hardware/ The Quartus project (Qsys, SignalTap, PLL, reconstruction/, output_files/)
projects/de10_nano_arm/software/ The ARM side: change_occupancy (sets occupancy and pedestal), the boot script, the hps_0.h generator
projects/de10_nano_arm/tools/    compare_capture.py (a SignalTap capture against the simulation, board_reference.v), plot_signaltap.m (plots a capture)
projects/de2_115_sapho/          The DE2-115: HITS configured from a menu on SAPHO (PS/2 keyboard, VGA screen), displays and Signal Tap
verification/regress.py          The regression (and compare_vcd.py, the comparison)
verification/testbenches/        hits_tb.v (the simulator alone), hits_config_tb.v (the configuration bus), testdata/
verification/goldens/            The golden VCD of every build
```

## How it works

The simulator (`rtl/hits.v`, the top with the configuration bus, around the core `rtl/hits/hits_core.v`) chains the stages
below, one sample per 25 ns clock cycle, ending at the digitized ADC sample.
Each `.mif` memory lives next to the module that reads it.

| Folder | Files | Description |
|---|---|---|
| `random/` | `lfsr42.v`, `rng.v`, `rng_round_robin.v`, `rng_leap.v`, `rng_xoshiro.v` | 42-bit LFSR step (the papers' primitive polynomial); `rng` picks the generator by `RNG_TYPE` (see *Random generators* below) |
| `hit_generation/` | `hit_generator.v`, `hit_draw.v`, `bunch_train_mask.v` + `.mif` | Bernoulli hit draw per bunch crossing (`rand < occupancy`), gated by the bunch-train mask (3564 slots) |
| `energy/` | `energy_generator.v`, `energy_seg.v` + `energy_seg_default.mif` (default); `energy_icdf.v` + `energy_icdf_paper_0..2.mif` (the tables) | Energy amplitude per bunch crossing, in whole ADC counts. By default a segmented inverse CDF of one 32-bit xoshiro word: octaves of probability from both ends of the CDF, 8 segments per octave, a degree-2 polynomial per segment (512-word ROM, 464 used), no staircase and a tail down to 2^-32 of probability. The spectrum is the ROM (`MEM_SEG`); the default one is a placeholder (mean 34 ADC, 99% below 156 ADC) until a documented spectrum replaces it. The three-table inverse CDF of the paper (multi-memory approach) stays for the other generators and the paper build (`USE_ENERGY_TABLES` forces it). |
| `shaper/` | one of the three `shaper_*.v` (see *Shaper filters* below), or the `*_phase.v` version of F34 / CSA + CR-4RC with its `*_phase.mif` (see *Pulse phase*) | the analog pulse shape of the front end |
| `noise/` | `noise_generator.v`, `noise_gauss.v` + `noise_gauss_s4.mif` (default); `noise_icdf.v` + `noise_s4_icdf0..2.mif` / `noise_s8_*` (the tables) | Gaussian electronic noise, sigma = 4 ADC at 12 bits (the Phase-II scale; 8 before 2026-09-29). By default a segmented inverse CDF of one 32-bit xoshiro word (polynomial per segment, correct tail up to 6.34 sigma); the three-table inverse CDF stays for the other generators and the paper build. Why that level, how the tables deviate in the tail, and where the double-Gaussian noise model came from: [`rtl/components/noise/README.md`](rtl/components/noise/README.md) |
| `adc/` | `adc.v` | pedestal offset, quantization to integer ADC counts (rounded to the nearest count since 2026-10-03; truncated before, 0.5 count low on average) and saturation to the 12-bit range; its output `shaper_clip` is the simulated readout |

### Random generators (`rtl/components/random/`)

Which one is built is chosen by the **`RNG_TYPE` parameter** of
`rtl/hits.v`, which comes down to every generator of the simulator:

| Generator | `RNG_TYPE` | Simulator (ALMs) | PractRand, 10-bit words | Description |
|---|---|---|---|---|
| `rng_round_robin.v` | `"round_robin"` (default until 2026-09-28) | 1184 | FAILS at 1 MB (BCFN, DC6) | The generator of the SBCCI 2025 paper: a bank of 7 LFSRs read in round robin (implemented as a rotating bank, without a multiplexer). Each LFSR is read every 7 cycles, so two reads of it share 3 of the 10 bits: `energy_out` shows a lag-7 autocorrelation of +0.009 (7 sigma over 713k samples). |
| `rng_leap.v` | `"leap"` | 403 | FAILS at 1 MB (BRank) | One LFSR advanced W steps per clock (leap-forward): no bit is shared between words, and no correlation shows in the simulator outputs, but it is a linear generator (every bit is the XOR of 6 earlier ones), which the binary-rank test catches at once. The cheapest. |
| `rng_xoshiro.v` | `"xoshiro"` (**default**) | 534 | **passes to 64 GB** | xoshiro128** (Blackman & Vigna, ACM TOMS 2021): 128-bit xor/shift/rotate engine plus a non-linear output scrambler; the words are the top bits of the result. The only one of the three that passes a full test battery. One generator per stage (hits, energy, noise: 3 instead of 8), its 32-bit result cut into the words of the stage (30 bits for energy, 31 for noise); the 30- and 31-bit words pass PractRand to 16 GB. |

The ALM column is the whole simulator as it stood on 2026-09-29 (legacy
shaper, 16-bit noise tables): it compares the generators, not today's total.

All three were validated in the simulator itself over 200 orbits (713k
cycles): hit rates on filled slots against occupancy/128 and energy and noise
distributions against the ones the tables define (chi2 within the expected
range for the three). xoshiro is the default since 2026-09-28: the only one
that passes the battery, and the second cheapest. The PractRand runs use bit-exact C models of the Verilog
(checked word by word against the simulation). The 1-bit xoshiro stream (the
noise sign) also passes to 16 GB: PractRand flagged "unusual" (its mildest
level, p ~ 1e-5) at 2, 4 and 8 GB and nothing at 16 GB, the pattern of chance
rather than of a defect, which grows with the sample.

Change the default in `rtl/hits.v`, or pass `.RNG_TYPE("leap")` where
it is instantiated. ⚠️ **Each generator has its own goldens**: the sequences
differ, only the statistics agree. The regression builds the other generators with
`-DUSE_RNG_ROUND_ROBIN` or `-DUSE_RNG_LEAP`, which `hits_tb.v` turns into the parameter.

### Shaper filters (`rtl/components/shaper/`)

Which one is built is a **synthesis-time choice**: F34 unless the
`USE_SHAPER_LEGACY` or `USE_SHAPER_CSA_CR4RC` macro is set (see *Selecting the
shaper* below):

| Filter | Selected by | Description |
|---|---|---|
| `shaper_fenics_f34.v` | **default** (since 2026-10-01) | The FENICS Phase-II pulse. The FENICS testbeam pulse was fitted with a 14-pole transfer function, and this is its 40 MHz digital filter: a 13-tap FIR head plus 5 IIR sections (3 leaky, 2 coupled), derived from a 14-pole transfer function of the FENICS front end. Zero DC gain is **imposed** rather than fitted, so it cannot produce a baseline sag the real front end does not have. Shape error 0.026% of peak. Generated from the design study, not written by hand: see the header of the file. Latency 7 samples: four pipeline stages (the long product of the closing section split in two, the input of every component, its output, and the final sum; all but the output stage added on 2026-10-01), which keep the shape bit for bit and only delay it. |
| `shaper_fenics.v` + `iir_order1.v` + `iir_order2.v` | `USE_SHAPER_LEGACY` | The shaper HITS was born with (the default until 2026-10-01): parallel IIR sections, coefficients at a 2**10 scale. An older approximation of the FENICS response; over a long run with the bunch-train mask its baseline settles about 5 ADC below the pedestal, where F34 converges to it (research phase F36). Input and final sum registered since 2026-10-03 (latency 2; HITS closed at 33.9 MHz with it before). |
| `shaper_csa_cr4rc.v` | `USE_SHAPER_CSA_CR4RC` | The generic "paper" pulse: the exact readout chain of the group's papers (bi-exponential detector pulse, CSA with a 51 ns feedback pole, unbuffered CR-4RC with a 500 us CR and four 5 ns RC stages -- the Electronics 14:493 signal generator). 4-tap FIR head plus 3 first-order IIR sections; peak 60.1 ns on sample 2, FWHM 114 ns, shape error 1e-7 of peak. Generated, not written by hand: see the header of the file. Input registered since 2026-10-03 and fully pipelined since 2026-10-14 (latency 5); `USE_SHAPER_NO_PIPE` removes the pipeline (latency 1), as the paper build does. |

All three share the same output scale (`2**G_OUT_LOG`), so nothing downstream
changes. All three take a reset that clears their state, so the tail of
earlier pulses does not cross a reset (the legacy one gained it on 2026-09-26).

### Selecting the shaper

Either uncomment the `` `define `` at the top of `rtl/hits.v`, or
define the macro externally and leave the file untouched (the `` `define ``
lines ship commented out, so an external define always wins):

```sh
iverilog -DUSE_SHAPER_LEGACY ...                                  # Icarus
```
```tcl
set_global_assignment -name VERILOG_MACRO "USE_SHAPER_LEGACY=1"   # Quartus
```

`USE_SHAPER_F34` is still accepted and builds the default, so older commands
keep working. Two shapers at once stop the compilation with an
`Unknown module type: ERROR_two_shapers_...` that names them.

⚠️ **Each choice has its own golden VCD** (table in *Regression check*): the
builds produce different pulses, which is the whole point.

### Pulse phase (since 2026-10-17)

Each shaper reproduces the pulse sampled at one phase (F34: 1.4128 ns after the
bunch crossing; CSA + CR-4RC: 10.1 ns). Two synthesis parameters of
`hits` move it, for the F34 and the CSA + CR-4RC shapers:

- `PHASE0`: a fixed phase for the whole channel, in steps of 25/64 = 0.390625 ns
  (−32..31, so −12.5 to +12.1 ns); positive = the pulse arrives later;
- `SIGMA_PS`: a jitter per hit, delta ~ N(0, `SIGMA_PS` ps) added to `PHASE0`, zero
  mean and symmetric, with no cut (the Gaussian tail of `noise_gauss.v`, to
  6.34 sigma); a draw past the table edge saturates there.

With both at 0 (the default) nothing changes: the base shaper is built, bit for
bit and at the same cost. Otherwise `shaper_fenics_f34_phase.v` or
`shaper_csa_cr4rc_phase.v` is built: the same shaper with a `phase` port, its
FIR head (and, in the CSA, the input gains of the 51 ns and 41.5 ns sections)
read hit by hit from a ROM of 64 phases (`*_phase.mif`). The head is in transposed
form, so each hit keeps its own phase; the IIR sections are unchanged. At
phase 0 both give the base shaper output bit for bit. The jitter draw is its own
xoshiro word (`XO_SEED_PHASE`, the long jump of `XO_SEED_HIT`, from
`rtl/components/random/xoshiro_jump.py`) through the Gaussian of `noise_gauss.v`; the phase
step makes sigma about 0.6% larger at sigma = 1 ns. `USE_SHAPER_LEGACY` and
`USE_SHAPER_NO_PIPE` have no phase and stop the compilation if one is set.

The `*_phase` files are generated, not written by hand: the generator (research
phase F07) copies the base shaper, swaps the head and checks phase 0 bit for bit
against it; rerun it after regenerating a base shaper. Cost on the DE10-Nano
(simulator alone, Quartus 24.1, worst-corner Fmax): F34 with jitter 1913 ALMs,
20 DSP, 15 M10K, 86.3 MHz; F34 with a fixed phase only 1707 ALMs, 18 DSP, 13 M10K,
84.6 MHz (measured on 2026-10-17, when the fixed phase still read the table; since
2026-10-21 it takes one set of coefficients in a register, with no table); F34 without phase 1751 ALMs, 3 DSP, 7 M10K,
84.7 MHz. CSA + CR-4RC with jitter 1186 ALMs, 30 DSP, 14 M10K, 71.7 MHz; without
phase 883 ALMs, 23 DSP, 7 M10K, 83.5 MHz.

### Reconstruction techniques (board with the ARM only)

The reconstruction techniques are **not part of the simulator**. The board with
the ARM builds one after the simulator: they live in
`projects/de10_nano_arm/hardware/reconstruction/` (PZC and adaptive baseline
estimator, joined to the core by the wrapper `hits_reco.v`), and the regression
no longer simulates them. Their testbench and goldens are at the tag
`last-with-reconstruction`; see
[`projects/de10_nano_arm/hardware/reconstruction/README.md`](projects/de10_nano_arm/hardware/reconstruction/README.md).

Top-level modules: `rtl/hits.v` (the simulator with its configuration bus, no
reconstruction; the board with the ARM uses its circuit, `rtl/hits/hits_core.v`,
with the configuration tied to constants) and
`projects/de10_nano_arm/hardware/de10_nano_soc_ghrd.v` (board top, entity `DE10_NANO_SoC_GHRD`:
connected to the HPS via Qsys, it takes `occupancy` and `offset` from bits [6:0]
and [19:7] of the HPS-to-FPGA register).

## Simulating without hardware

The simulator core is plain Verilog (no ARM/PLL/Qsys) and runs in open-source
simulators. The testbench (`verification/testbenches/hits_tb.v`) drives 3 full
orbits (3 × 3564 bunch crossings) with an occupancy step from 25% to 75% halfway through
(25/128 to 80/128 in the `paper` build).

All paths are relative, so the project works from any clone location. The one
requirement is that the simulation runs with cwd two levels below the root
(`verification/testbenches/`, or `projects/aurora/` for Aurora), because
the `.mif` memories are loaded via the relative `RTL_DIR` of the testbench.

### The Aurora project

| Project | Testbench | What runs | Compiles |
|---|---|---|---|
| `projects/aurora/hits.spf` | `verification/testbenches/hits_tb.v` | the simulator ALONE, up to the ADC quantization (`shaper_clip`) | `rtl/` only |

With [Aurora](https://nipscern.com): open the `.spf` and press the wave button
(Icarus Verilog, then GTKWave or Surfer, chosen in the toolbar). Requires an
Aurora build from 2026-07-17 or newer (older builds ran the simulation from
Aurora's temp dir and cannot resolve the relative paths).

**Shaper**: the `` `define `` lines at the top of `rtl/hits.v`, see *Selecting
the shaper*. Commit it with the choice lines commented: the regression passes
its own macros with `-D` and refuses to run otherwise.

With Icarus Verilog directly (`-D` to choose):

```sh
cd verification/testbenches   # the simulator alone
iverilog -s hits_tb -o tb.vvp ../../rtl/*.v ../../rtl/hits/*.v ../../rtl/components/*/*.v hits_tb.v
vvp tb.vvp                          # writes hits_tb.vcd here
```

## Regression check

Any change to the RTL must keep the testbench output bit-for-bit identical to
the frozen baselines. One command runs every build, from the repo root, and also
fails on any `$readmem` error (a golden taken from a broken run would otherwise
bless it forever):

```sh
python verification/regress.py            # exit 0 = every build bit-identical
python verification/regress.py sim paper  # a subset
```

The `core` builds compile only `rtl/` and stop at the ADC quantization: if one
fails, the core changed. The `bus` builds test the configuration bus (see
`docs/develop/regression.md`).

| Build | Group | Macros | Golden (`verification/goldens/`) |
|---|---|---|---|
| `sim` | core | (none: xoshiro, F34, segmented energy, Gaussian sigma = 4) | `hits_tb_golden.vcd` |
| `sim_legacy` | core | `USE_SHAPER_LEGACY` | `hits_tb_golden_legacy.vcd` |
| `sim_csa_cr4rc` | core | `USE_SHAPER_CSA_CR4RC` | `hits_tb_golden_csa_cr4rc.vcd` |
| `sim_noise_tables` | core | `USE_NOISE_TABLES` | `hits_tb_golden_noise_tables.vcd` |
| `sim_energy_tables` | core | `USE_ENERGY_TABLES` | `hits_tb_golden_energy_tables.vcd` |
| `sim_round_robin` | core | `USE_RNG_ROUND_ROBIN` | `hits_tb_golden_round_robin.vcd` |
| `sim_round_robin_legacy` | core | `USE_RNG_ROUND_ROBIN USE_SHAPER_LEGACY` | `hits_tb_golden_round_robin_legacy.vcd` |
| **`paper`** | core | `USE_RNG_ROUND_ROBIN USE_SHAPER_CSA_CR4RC USE_NOISE_SIGMA8 USE_ADC_FLOOR USE_SHAPER_NO_PIPE USE_OCC_PAPER` | `hits_tb_golden_paper.vcd` (**frozen**, see below) |
| `paper_r1` | core | `USE_SHAPER_CSA_CR4RC USE_ENERGY_LORENZETTI` | `hits_tb_golden_paper_r1.vcd` (to be frozen with the tag `paper-jsen-2026-r1`) |
| `sim_leap` | core | `USE_RNG_LEAP` | `hits_tb_golden_leap.vcd` |
| `sim_leap_legacy` | core | `USE_RNG_LEAP USE_SHAPER_LEGACY` | `hits_tb_golden_leap_legacy.vcd` |
| `sim_leap_csa_cr4rc` | core | `USE_RNG_LEAP USE_SHAPER_CSA_CR4RC` | `hits_tb_golden_leap_csa_cr4rc.vcd` |
| `sim_phase` | core | `USE_PHASE0=8` (+3.125 ns) | `hits_tb_golden_phase.vcd` |
| `sim_jitter` | core | `USE_PHASE_SIGMA_PS=1000` (sigma = 1 ns) | `hits_tb_golden_jitter.vcd` |
| `sim_phase_csa_cr4rc` | core | `USE_SHAPER_CSA_CR4RC USE_PHASE0=8` | `hits_tb_golden_phase_csa_cr4rc.vcd` |
| `sim_jitter_csa_cr4rc` | core | `USE_SHAPER_CSA_CR4RC USE_PHASE_SIGMA_PS=1000` | `hits_tb_golden_jitter_csa_cr4rc.vcd` |
| `bus` | bus | (none: F34) | `hits_config_tb_golden.vcd` |
| `bus_phase` | bus | `TB_PHASE` (fixed phase +8, F34) | `hits_config_tb_golden_phase.vcd` |
| `bus_phase_csa` | bus | `TB_PHASE USE_SHAPER_CSA_CR4RC` | `hits_config_tb_golden_phase_csa.vcd` |
| `bus_jitter` | bus | `TB_JITTER USE_SHAPER_CSA_CR4RC` | `hits_config_tb_golden_jitter.vcd` |
| `bus_sapho` | bus | `TB_SAPHO` (through the SAPHO adapter, F34) | `hits_config_tb_golden_sapho.vcd` |

The comparator ignores only run metadata (`$date`, `$version` and the testbench
`RTL_DIR` path parameter). Intentional behavior changes require regenerating the
golden VCD, by hand, in the same commit. A NEW build gets its
golden with `python verification/regress.py --create <build>`, which only creates
goldens that do not exist yet.

**When it runs by itself:**

- **before each commit**, on your machine, if you enable the hook once per
  clone: `git config core.hooksPath .githooks`. A commit that touches `rtl/`,
  `projects/aurora/` or `verification/` runs the regression
  first and is blocked if it fails. It tests the working tree.
- **on every pull request and every push to `main`**, in CI
  (`.github/workflows/regression.yml`). Its `regression` check, and the
  `manual` check of the documentation workflow, are required to merge: this is the real gate, the hook only catches the error earlier.

A `vvp` that dies with no message (the machine short of memory) is re-run up to
twice and listed at the end of the run; a complete but wrong waveform fails at
once.

## Reproducing the HITS of the Sensors Journal paper

Fabio's paper (*Real-Time FPGA-Based Pulse Simulator for Calorimeter Readout
Electronics in Nuclear Instrumentation*, IEEE Sensors Journal,
Sensors-114519-2026) used the CSA + CR-4RC shaper, the round-robin generator,
the sigma = 8 ADC noise tables, a truncating ADC and no input register in the
shaper.

- **Its behaviour, on the current code:** `RNG_TYPE = "round_robin"` plus the
  `USE_SHAPER_CSA_CR4RC`, `USE_NOISE_SIGMA8`, `USE_ADC_FLOOR` and `USE_SHAPER_NO_PIPE` macros (and, in the
  testbench, `USE_OCC_PAPER` for the occupancies of the paper), in simulation (`regress.py paper`) or on the
  board (`de10_nano_soc_ghrd.v` and the `.qsf`). The `paper` build is the
  simulator outputs of the paper's code delayed exactly one cycle (the
  testbench releases reset one edge later since 9dc32b2), checked signal by
  signal. Its golden is **frozen**: `regress.py` keeps its hash and fails if the
  file changes, so no later change can alter this configuration.
- **Its exact code, and its resource numbers** (section V: Vivado, KCU116,
  1987 LUTs, 2696 registers, 27 DSPs, 0 BRAM): the tag `paper-jsen-2026`. The
  circuit changed since (tables in block RAM, rotating LFSR bank), so the same
  parameters give another netlist. To work on it without touching `main`:
  `git worktree add ../hits-paper paper-jsen-2026`.


### The revised version (in preparation)

The revision of the paper describes the current HITS, keeping only its pulse,
the CSA + CR-4RC shaper. Its configuration is the `paper_r1` build:
`USE_SHAPER_CSA_CR4RC` plus `USE_ENERGY_LORENZETTI`, on top of the defaults
(xoshiro, segmented energy, Gaussian noise with sigma = 4, rounding ADC, the
pipelined CSA shaper). Its golden is not frozen yet; it will be once the
numbers of the paper close.

`energy_seg_lorenzetti.mif` is the energy per bunch crossing of the hottest
cell of the hadronic barrel in the public Lorenzetti simulator
([fork](https://github.com/lucianomaf/lorenzetti), commit `9164136`): a
minimum-bias library of 10 000 Pythia events, the 256 channels of that cell
pooled (same eta, so the same distribution), 200 interactions per crossing,
visible energy at 3 ADC counts per MeV. Mean 9.5 ADC per crossing, deposit in
65530/65536 of them. The research scripts that produce it are kept outside
this repository.

On the board, `projects/de10_nano/` is the simulator alone on the
DE10-Nano: no HPS, no Qsys, no reconstruction technique, the 16-bit occupancy
(65530/65536) and pedestal 146 as the values at power-up, the configuration bus on
the GPIO headers (enabled by SW0), reset released synchronously, and the
`paper_r1` macros already set in `hits_de10.qsf`. It compiles with Quartus
Prime Lite 24.1 (on 2026-10-22: 839 ALMs, 1386 registers, 7 M10K, 23 DSP, 1 PLL,
46 pins, 82.8 MHz worst corner for the 40 MHz clock; with the bus idle instead of on
the pins it was 804 ALMs, 1191 registers and 79.0 MHz). After the reset its `shaper_clip`
must equal the simulation bit for bit; Signal Tap captures it.

## Running on the DE10-Nano board

Requirements: Quartus Prime Lite 23.1std.1 (the version that compiled the
bitstream on the card), a DE10-Nano and a micro-SD card (2 GB minimum). The
Platform Designer system of this board was made with Quartus 23.1: generate it
with `qsys-generate` from a clean copy, as
`projects/de10_nano_arm/README.md` explains, and do not open it in the
Platform Designer window of 24.1, which upgrades the IP.

1. Download the Linux SD-card image from the
   [linux-image-v1 release](https://github.com/nipscernlab/hits/releases/tag/linux-image-v1)
   (7 files of a split zip; put them in the same folder and extract
   `de10_backup_image.zip`) and write it to the SD card.
2. Insert the SD card, set all MSEL switches to ON, connect Ethernet and power on.
   U-Boot programs the FPGA from `soc_system.rbf` on the FAT partition of the
   card, then Linux boots.
3. Find the board IP (IP scanner or serial console) and connect over SSH
   (login `root`, password `simhits`).
4. Run `./change_occupancy` and follow the menu to change the occupancy or the
   pedestal offset at runtime. Its source and a
   statically linked binary are in `projects/de10_nano_arm/software/change_occupancy/`;
   the binary in the image (2025) has the bug of issue #7, and the guide of the
   project replaces it.
5. To observe the internal signals: open `projects/de10_nano_arm/hardware/DE10_NANO_SoC_GHRD.qpf`
   in Quartus, connect the USB-Blaster II, open `stp1.stp` (SignalTap) and press
   *Autorun Analysis*. The effect of the SSH menu is visible live.

To rebuild the FPGA design instead of using the prebuilt bitstream: generate the
HPS system and compile, as `projects/de10_nano_arm/README.md` explains (the
prebuilt `.sof`/`.rbf` in `projects/de10_nano_arm/hardware/output_files/` are the
ones on the card, of 2025-06-12; the pre-releases `board-bitstream-v<n>` hold
compiled ones of a recent commit).
The new `.rbf`, written without compression, replaces `soc_system.rbf` on the FAT
partition of the card; that guide checks the capture against the simulation
sample by sample.

## Contributing (branch workflow)

Each contributor works on their own branch (e.g. `fabio/shaper-tweaks`) and
opens a pull request; what enters `main` is decided together, in review, before
merging. Since 2026-10-27 this holds for the maintainer too: `main` takes no direct
push, and a pull request merges only with its checks green. `main` is the reference the
group's papers cite, so it must stay reproducible at all times: the regression
against the golden VCDs (see *Regression check*) must pass on every merge --
the `regression` CI check runs `verification/regress.py` on every pull
request and is required.

## Publications

Selected publications by the group about this simulator (full list at
[nipscern.com/publications](https://www.nipscern.com/publications)):

- T. Paschoalin, T. Quirino, L. Andrade Filho, *Multi-Memory Approach for Random
  Number Generators in FPGA*, Applied Sciences 16(5) 2537, 2026.
- F. Luna, T. Paschoalin, T. Quirino, L. Andrade Filho, *Digital Implementation of
  a Signal Conditioning Stage on FPGA for Pulse Simulation in Nuclear
  Instrumentation*, 10th INSCIT, 2026.
- T. Paschoalin, U. Dias, M. Aguiar, D. Santos, T. Quirino, L. Andrade Filho,
  *Uncorrelated Pseudo-Random Generator for FPGA*, 38th SBCCI, 2025.
- F. Luna, U. Dias, P. Lisboa, T. Paschoalin, T. Quirino, L. Andrade Filho,
  *Real-time FPGA-based simulator for the Tile Calorimeter readout system in the
  ATLAS experiment*, XXVII ENMC, 2024.

## License

[NIPS-CERN License](LICENSE): free to read, use, modify and redistribute;
commercial exploitation requires prior written authorization from the laboratory.
