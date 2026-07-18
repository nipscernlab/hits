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
projects/quartus/     Quartus Prime project for the DE10-Nano SoC (FPGA + ARM/HPS)
projects/aurora/      Aurora (Icarus Verilog + GTKWave) simulation project + testbench
verificacao/          Regression baseline: golden VCD + comparison script
```

## How it works

The synthesizable core (`rtl/`) chains four blocks, one sample per 25 ns clock cycle:

| Block | Modules | Description |
|---|---|---|
| Random number generation | `rand_LFSR.v`, `select_rand.v`, `random_number_generator.v` | Bank of 7 LFSRs with a selector, producing uncorrelated pseudo-random streams |
| Hit generation | `Hits_Bunch_train.v`, `hits_positions.v`, `bunch_train_mask.v` | Bernoulli hit draw per bunch crossing, gated by the LHC bunch-train mask (`bunch_train_mask.mif`) and the programmable occupancy |
| Amplitude and noise | `energy_*.v` + `A13_PART*.mif`, `noise_*.v` + `NOISE_PART*.mif` | Inverse-CDF lookup split across multiple memories (multi-memory approach), drawing energy amplitudes from a measured minimum-bias distribution and Gaussian electronic noise |
| Shaping and PZC | `shaper_fenics.v`, `iir_ordem1/2.v`, `clip_shaper.v`, `pzc_ped_track.v` | IIR implementation of the front-end shaper, output clipping to ADC range, and an embedded PZC filter with pedestal tracking |

Top-level wrappers: `FPGA_Simulator_v1.v` (core), `FPGA_Simulator_v1_PZC.v`
(core plus PZC, the top used in simulation), and
`projects/quartus/FPGA_Simulator_v1_PZC_SOC.v` (board top, connected to the HPS
via Qsys).

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
iverilog -s sim_pulsos_tb -o tb.vvp ../../rtl/*.v sim_pulsos_tb.v
vvp tb.vvp                      # writes sim_pulsos_tb.vcd here
```

## Regression check

Any change to the RTL must keep the testbench output bit-for-bit identical to
the frozen baseline (`verificacao/sim_pulsos_tb_golden.vcd`):

```sh
python ../../verificacao/comparar_vcd.py sim_pulsos_tb.vcd   # exit 0 = identical
```
(paths as in the simulation recipe above, run from `projects/aurora/`)

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

## Publications

Selected publications by the group about this simulator (full list at
[nipscern.com/publications](https://www.nipscern.com/publications)):

- T. Paschoalin, L. Quirino, L. Andrade Filho, *Multi-Memory Approach for Random
  Number Generators in FPGA*, Applied Sciences 16(5) 2537, 2026.
- F. Luna, T. Paschoalin, L. Quirino, L. Andrade Filho, *Digital Implementation of
  a Signal Conditioning Stage on FPGA for Pulse Simulation in Nuclear
  Instrumentation*, 10th INSCIT, 2026.
- T. Paschoalin, A. Dias, M. Aguiar, V. Santos, L. Quirino, L. Andrade Filho,
  *Uncorrelated Pseudo-Random Generator for FPGA*, 38th SBCCI, 2025.
- F. Luna, A. Dias, G. Lisboa, T. Paschoalin, L. Quirino, L. Andrade Filho,
  *Real-time FPGA-based simulator for the Tile Calorimeter readout system in the
  ATLAS experiment*, XXVII ENEMC, 2024.

## License

[NIPS-CERN License](LICENSE): free to read, use, modify and redistribute;
commercial exploitation requires prior written authorization from the laboratory.
