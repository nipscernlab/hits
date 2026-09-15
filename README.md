<p align="center">
  <img src="https://raw.githubusercontent.com/nipscernlab/nipscernweb/main/assets/icons/hits-badge.svg"
       alt="HITS emblem"
       width="220">
</p>

# HITS: Hardware Impulse Train Synthesizer

Real-time FPGA simulator of calorimeter readout pulses, running at 40 MHz on a
Terasic DE10-Nano (Intel Cyclone V SoC). It emulates the front-end signal chain
of the ATLAS Tile Calorimeter readout: pseudo-random hit generation following
the LHC bunch-train structure, energy amplitudes drawn from measured
distributions, electronic noise, analog pulse shaping and an embedded pole-zero
cancellation (PZC) stage. Occupancy and pedestal are configurable at runtime
from the embedded ARM processor (HPS). It is used to validate online
energy-reconstruction techniques without access to the experiment.

Developed by [NIPS-CERN](https://nipscern.com) (Federal University of Juiz de
Fora, Brazil).

## Repository layout

```
rtl/                  Simulator source shared by all flows (.v modules + .mif memories)
rtl/filtros/          Shaper filters: three pulse shapes, selectable at synthesis time (see below)
rtl_test/             PZC and baseline estimator under test + the core+correction wrapper (not the simulator)
projects/quartus/     Quartus Prime project for the DE10-Nano SoC (FPGA + ARM/HPS)
projects/aurora/      Aurora (Icarus Verilog + GTKWave) simulation project + testbench
verification/         Regression baseline: golden VCD + comparison script
```

## How it works

The synthesizable simulator core (`rtl/`) chains four blocks, one sample per
25 ns clock cycle, ending at the digitized ADC sample:

| Block | Modules | Description |
|---|---|---|
| Random number generation | `rand_LFSR.v`, `select_rand.v`, `random_number_generator.v` | Bank of 7 LFSRs with a selector, producing uncorrelated pseudo-random streams |
| Hit generation | `Hits_Bunch_train.v`, `hits_positions.v`, `bunch_train_mask.v` | Bernoulli hit draw per bunch crossing, gated by the LHC bunch-train mask (`bunch_train_mask.mif`) and the programmable occupancy |
| Amplitude and noise | `energy_*.v` + `A13_PART*.mif`, `noise_*.v` + `NOISE_PART*.mif` | Inverse-CDF lookup split across multiple memories (multi-memory approach), drawing energy amplitudes from a measured minimum-bias distribution and Gaussian electronic noise |
| Shaping and digitization | one of the three `filtros/shaper_*.v` (see *Shaper filters* below), `clip_shaper.v` | IIR implementation of the selected pulse shape, then pedestal offset and clipping to the ADC range; the output `shaper_clip` is the simulated readout |

### Shaper filters (`rtl/filtros/`)

Which one is built is a **synthesis-time choice**, selected by the
`USE_SHAPER_F34` / `USE_SHAPER_CSA_CR4RC` macros (see *Selecting the shaper*
below):

| Filter | Selected by | Description |
|---|---|---|
| `shaper_fenics.v` + `iir_order1.v` + `iir_order2.v` | **default** | Parallel IIR sections, coefficients at a 2**10 scale. |
| `shaper_fenics_f34.v` | `USE_SHAPER_F34` | 13-tap FIR head plus 5 IIR sections (3 leaky, 2 coupled), derived from a 14-pole transfer function of the FENICS front end. Zero DC gain is **imposed** rather than fitted, so it cannot produce a baseline sag the real front end does not have. Shape error 0.026% of peak. Generated from the design study, not written by hand: see the header of the file. |
| `shaper_csa_cr4rc.v` | `USE_SHAPER_CSA_CR4RC` | The generic "paper" pulse: the exact readout chain of the group's papers (bi-exponential detector pulse, CSA with a 51 ns feedback pole, unbuffered CR-4RC with a 500 us CR and four 5 ns RC stages -- the Electronics 14:493 signal generator). 4-tap FIR head plus 3 first-order IIR sections; peak 60.1 ns on sample 2, FWHM 114 ns, shape error 1e-7 of peak. Generated, not written by hand: see the header of the file. |

All three share the same output scale (`2**G_OUT_LOG`), so nothing downstream
changes. The F34 and CSA+CR-4RC modules additionally take a reset, which the
top level wires for them.

### Selecting the shaper

Either uncomment the `` `define `` at the top of `rtl/FPGA_Simulator_v1.v`, or
define the macro externally and leave the file untouched (the `` `define ``
lines ship commented out, so an external define always wins):

```sh
iverilog -DUSE_SHAPER_F34 ...                                     # Icarus
```
```tcl
set_global_assignment -name VERILOG_MACRO "USE_SHAPER_F34=1"      # Quartus
```

⚠️ **Each choice has its own golden VCD** — the builds produce different
pulses, which is the whole point:

| Build | Golden |
|---|---|
| default | `verification/sim_pulsos_tb_golden.vcd` |
| `USE_SHAPER_F34` | `verification/sim_pulsos_tb_golden_f34.vcd` |
| `USE_SHAPER_CSA_CR4RC` | `verification/sim_pulsos_tb_golden_csa_cr4rc.vcd` |
| `USE_SHAPER_F34` + `USE_BASELINE_EST` | `verification/sim_pulsos_tb_golden_f34_est.vcd` |

The **pole-zero cancellation (PZC)** is not part of the simulator: it is a
downstream reconstruction stage validated with the synthesized pulse train.
It lives in `rtl_test/` (`pzc_ped_track.v`) and is composed with the core by the
`FPGA_Simulator_v1_PZC.v` test wrapper.

### Baseline correction under test

The `USE_BASELINE_EST` macro (same mechanism as the shaper macros) makes the
`FPGA_Simulator_v1_PZC.v` wrapper instantiate the adaptive baseline estimator
(`rtl_test/estimador_baseline.v` + `gerador_ancora.v` + the `recip.mem` ROM)
instead of the PZC. Both drive the same `pzc_out` port, but **not on the same
scale**: the PZC output carries a gain of (M+1) = 455, while the estimator
outputs plain ADC counts. ⚠️ The estimator's anchor parameters are calibrated
for the `USE_SHAPER_F34` build only — combining it with another shaper compiles
but is silently mis-anchored (see the SHAPER COMBINATIONS warning in the
wrapper header). Its golden is the fourth row of the table above.

Top-level modules: `rtl/FPGA_Simulator_v1.v` (the simulator core, no PZC),
`rtl_test/FPGA_Simulator_v1_PZC.v` (core plus PZC, the top used in simulation and
on the board), and `projects/quartus/FPGA_Simulator_v1_PZC_SOC.v` (board top,
connected to the HPS via Qsys).

## Simulating without hardware

The simulator core is plain Verilog (no ARM/PLL/Qsys) and runs in open-source
simulators. The testbench (`projects/aurora/sim_pulsos_tb.v`) drives 3 full LHC
orbits (3 × 3564 bunch crossings) with an occupancy step 25 → 80 halfway through.

All paths are relative, so the project works from any clone location. The one
requirement is that the simulation runs with cwd = `projects/aurora/`, because
the `.mif` memories are loaded via the relative `RTL_DIR` of the testbench.

With [Aurora](https://nipscern.com): open `projects/aurora/sim_pulsos.spf` and
press the wave button (Icarus Verilog → GTKWave). Requires an Aurora build from
2026-07-17 or newer (older builds ran the simulation from Aurora's temp dir and
cannot resolve the relative paths).

With Icarus Verilog directly:

```sh
cd projects/aurora
iverilog -s sim_pulsos_tb -o tb.vvp ../../rtl/*.v ../../rtl/filtros/*.v ../../rtl_test/*.v sim_pulsos_tb.v
vvp tb.vvp                      # writes sim_pulsos_tb.vcd here
```

## Regression check

Any change to the RTL must keep the testbench output bit-for-bit identical to
the frozen baseline (`verification/sim_pulsos_tb_golden.vcd`):

```sh
python ../../verification/compare_vcd.py sim_pulsos_tb.vcd   # exit 0 = identical
```
(paths as in the simulation recipe above, run from `projects/aurora/`)

For a build with `USE_SHAPER_F34`, compare against that build's own golden:

```sh
iverilog -DUSE_SHAPER_F34 -s sim_pulsos_tb -o tb.vvp \
    ../../rtl/*.v ../../rtl/filtros/*.v ../../rtl_test/*.v sim_pulsos_tb.v
vvp tb.vvp
python ../../verification/compare_vcd.py sim_pulsos_tb.vcd \
    ../../verification/sim_pulsos_tb_golden_f34.vcd
```

The comparator ignores only run metadata (`$date`, `$version` and the testbench
`RTL_DIR` path parameter). Intentional behavior changes require regenerating the
golden VCD in the same commit.

## Running on the DE10-Nano board

Requirements: Quartus Prime Lite (23.1std or newer), Intel EDS, a DE10-Nano and a
micro-SD card (2 GB minimum).

1. Download the Linux SD-card image from the
   [linux-image-v1 release](https://github.com/nipscernlab/hits/releases/tag/linux-image-v1)
   (7 files of a split zip; put them in the same folder and extract
   `de10_backup_image.zip`) and write it to the SD card.
2. Insert the SD card, set all MSEL switches to ON, connect Ethernet and power on.
   Linux boots and programs the FPGA automatically.
3. Find the board IP (IP scanner or serial console) and connect over SSH
   (login `root`, password `simhits`).
4. Run `./change_occupancy` and follow the menu to change the occupancy or the
   pedestal offset at runtime.
5. To observe the internal signals: open `projects/quartus/DE10_NANO_SoC_GHRD.qpf`
   in Quartus, connect the USB-Blaster II, open `stp1.stp` (SignalTap) and press
   *Autorun Analysis*. The effect of the SSH menu is visible live.

To rebuild the FPGA design instead of using the prebuilt bitstream: compile the
project in Quartus (ready-to-flash `.sof`/`.rbf` are kept in
`projects/quartus/output_files/`).

## Contributing (branch workflow)

Nobody commits directly to `main` (rule set 2026-09-14). Each contributor works
on their own branch (e.g. `fabio/shaper-tweaks`) and what enters `main` is
decided together, in review, before merging. `main` is the reference the
group's papers cite, so it must stay reproducible at all times: the regression
against the golden VCDs (see *Regression check*) must pass on every merge.

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
