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
distributions, electronic noise, analog pulse shaping and digitization.
Occupancy and pedestal are configurable at runtime from the embedded ARM
processor (HPS). It is used to validate online energy-reconstruction techniques
without access to the experiment; those techniques are not part of the
simulator and live in `reconstrucao/`.

Developed by [NIPS-CERN](https://nipscern.com) (Federal University of Juiz de
Fora, Brazil).

## Repository layout

```
rtl/                  THE SIMULATOR, one subfolder per stage (top: FPGA_Simulator_v1.v)
rtl/random/           Pseudo-random generator (LFSR bank), used by every stage that draws
rtl/hits/             Hit draw + LHC bunch-train mask
rtl/energy/           Energy amplitude (inverse CDF, 3 tables)
rtl/shaper/           Pulse shapers: three shapes, selectable at synthesis time (see below)
rtl/noise/            Electronic noise (inverse CDF, 3 tables)
rtl/adc/              Pedestal, quantization and saturation: the simulator output
reconstrucao/         Reconstruction techniques under test and the core+technique wrapper (not the simulator)
reconstrucao/pzc/                 Pole-zero cancellation + pedestal tracking
reconstrucao/estimador_baseline/  Adaptive baseline estimator (+ its recip.mem ROM)
projects/quartus/     Quartus Prime project for the DE10-Nano SoC (FPGA + ARM/HPS)
projects/aurora_simulador/  Aurora project: the simulator alone, up to the ADC
projects/aurora/      Aurora project: simulator + reconstruction technique
verification/         Regression baseline: golden VCD + comparison script
```

## How it works

The synthesizable simulator core (`rtl/FPGA_Simulator_v1.v`) chains the stages
below, one sample per 25 ns clock cycle, ending at the digitized ADC sample.
Each `.mif` memory lives next to the module that reads it.

| Folder | Files | Description |
|---|---|---|
| `random/` | `lfsr42.v`, `rng.v`, `round_robin.v` | 42-bit LFSR (the papers' primitive polynomial); `rng` is a bank of 7 of them read in round robin, producing uncorrelated pseudo-random streams |
| `hits/` | `hit_generator.v`, `hit_draw.v`, `bunch_train_mask.v` + `.mif` | Bernoulli hit draw per bunch crossing (`rand < occupancy`), gated by the LHC bunch-train mask (3564 slots) |
| `energy/` | `energy_generator.v`, `energy_icdf.v` + `energy_icdf_a13_0..2.mif` | Inverse-CDF lookup split across three memories (multi-memory approach), drawing energy amplitudes from a measured minimum-bias distribution |
| `shaper/` | one of the three `shaper_*.v` (see *Shaper filters* below) | the analog pulse shape of the front end |
| `noise/` | `noise_generator.v`, `noise_icdf.v` + `noise_icdf0..2.mif` | Gaussian electronic noise, same three-memory inverse CDF plus a random sign |
| `adc/` | `adc.v` | pedestal offset, quantization to integer ADC counts and saturation to the 12-bit range; its output `shaper_clip` is the simulated readout |

### Shaper filters (`rtl/shaper/`)

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

⚠️ **Each choice has its own golden VCD** (table in *Regression check*): the
builds produce different pulses, which is the whole point.

### Reconstruction techniques (`reconstrucao/`)

The reconstruction techniques are **not part of the simulator**: they are
downstream stages validated with the synthesized pulse train, one subfolder
each. Today there are two, `pzc/` (pole-zero cancellation, `pzc_ped_track.v`,
the default) and `estimador_baseline/` (adaptive baseline estimator, selected by
the `USE_BASELINE_EST` macro). The `reconstrucao/FPGA_Simulator_v1_PZC.v` wrapper
composes the core with the technique under test. How to add a new technique:
[`reconstrucao/README.md`](reconstrucao/README.md).

The two techniques drive the same `pzc_out` port, but **not on the same
scale**: the PZC output carries a gain of (M+1) = 455, while the estimator
outputs plain ADC counts. ⚠️ The estimator's anchor parameters are calibrated
for the `USE_SHAPER_F34` build only: combining it with another shaper compiles
but is silently mis-anchored (see the SHAPER COMBINATIONS warning in the
wrapper header). Its golden is `f34_est` in the table of *Regression check*.

Top-level modules: `rtl/FPGA_Simulator_v1.v` (the simulator core, no
reconstruction), `reconstrucao/FPGA_Simulator_v1_PZC.v` (core plus the technique
under test, the top used in simulation and on the board), and
`projects/quartus/FPGA_Simulator_v1_PZC_SOC.v` (board top, connected to the HPS
via Qsys).

## Simulating without hardware

The simulator core is plain Verilog (no ARM/PLL/Qsys) and runs in open-source
simulators. The testbench (`projects/aurora/sim_pulsos_tb.v`) drives 3 full LHC
orbits (3 × 3564 bunch crossings) with an occupancy step 25 → 80 halfway through.

All paths are relative, so the project works from any clone location. The one
requirement is that the simulation runs with cwd = `projects/aurora/`, because
the `.mif` memories are loaded via the relative `RTL_DIR` of the testbench.

### Two Aurora projects

| Project | Testbench | What runs | Compiles |
|---|---|---|---|
| `projects/aurora_simulador/simulador.spf` | `simulador_tb.v` | the simulator ALONE, up to the ADC quantization (`shaper_clip`) | `rtl/` only |
| `projects/aurora/sim_pulsos.spf` | `sim_pulsos_tb.v` | simulator + the reconstruction technique under test | `rtl/` + `reconstrucao/` |

With [Aurora](https://nipscern.com): open the `.spf` and press the wave button
(Icarus Verilog, then GTKWave or Surfer, chosen in the toolbar). Requires an
Aurora build from 2026-07-17 or newer (older builds ran the simulation from
Aurora's temp dir and cannot resolve the relative paths).

**Shaper** (both projects): the `` `define `` lines at the top of
`rtl/FPGA_Simulator_v1.v`, see *Selecting the shaper*.

**Technique** (`projects/aurora/` only): `projects/aurora/simulacao.v` is the
menu, PZC by default or `USE_BASELINE_EST`; it can also pick the shaper for
that project. It is a file of its own, the first entry of the `.spf`, because
Icarus applies a `` `define `` only to the files compiled after it and Aurora
compiles the testbench last. Two shapers at once stop the compilation with an
`Unknown module type: ERROR_...` that names the problem.

Commit every one of these files with the choice lines commented: the
regression passes its own macros with `-D` and refuses to run otherwise.

With Icarus Verilog directly (`-D` to choose):

```sh
cd projects/aurora_simulador        # the simulator alone
iverilog -s simulador_tb -o tb.vvp ../../rtl/*.v ../../rtl/*/*.v simulador_tb.v
vvp tb.vvp                          # writes simulador_tb.vcd here

cd projects/aurora                  # simulator + technique
iverilog -s sim_pulsos_tb -o tb.vvp simulacao.v ../../rtl/*.v ../../rtl/*/*.v \
    ../../reconstrucao/*.v ../../reconstrucao/*/*.v sim_pulsos_tb.v
vvp tb.vvp                          # writes sim_pulsos_tb.vcd here
```

## Regression check

Any change to the RTL must keep the testbench output bit-for-bit identical to
the frozen baselines. One command runs every build, from the repo root, and also
fails on any `$readmem` error (a golden taken from a broken run would otherwise
bless it forever):

```sh
python verification/regress.py            # exit 0 = every build bit-identical
python verification/regress.py sim f34    # a subset
```

The builds come in two groups, one per Aurora project, so a failure says what
broke: if a `simulador` build fails, the simulator changed (these compile only
`rtl/` and stop at the ADC quantization); if only `reconstrucao` builds fail,
the technique changed and the simulator is intact.

| Build | Group | Macros | Golden (`verification/`) |
|---|---|---|---|
| `sim` | simulador | (none) | `simulador_tb_golden.vcd` |
| `sim_f34` | simulador | `USE_SHAPER_F34` | `simulador_tb_golden_f34.vcd` |
| `sim_csa_cr4rc` | simulador | `USE_SHAPER_CSA_CR4RC` | `simulador_tb_golden_csa_cr4rc.vcd` |
| `default` | reconstrucao | (none: PZC) | `sim_pulsos_tb_golden.vcd` |
| `f34` | reconstrucao | `USE_SHAPER_F34` | `sim_pulsos_tb_golden_f34.vcd` |
| `csa_cr4rc` | reconstrucao | `USE_SHAPER_CSA_CR4RC` | `sim_pulsos_tb_golden_csa_cr4rc.vcd` |
| `f34_est` | reconstrucao | `USE_SHAPER_F34 USE_BASELINE_EST` | `sim_pulsos_tb_golden_f34_est.vcd` |

The comparator ignores only run metadata (`$date`, `$version` and the testbench
`RTL_DIR` path parameter). Intentional behavior changes require regenerating the
golden VCD, by hand, in the same commit. A NEW build (a new technique) gets its
golden with `python verification/regress.py --gera <build>`, which only creates
goldens that do not exist yet.

**When it runs by itself:**

- **before each commit**, on your machine, if you enable the hook once per
  clone: `git config core.hooksPath .githooks`. A commit that touches `rtl/`,
  `reconstrucao/`, either Aurora project or `verification/` runs the regression
  first and is blocked if it fails. It tests the working tree.
- **on every pull request and every push to `main`**, in CI
  (`.github/workflows/regressao.yml`). Its `regressao-golden` check is required
  to merge: this is the real gate, the hook only catches the error earlier.

A `vvp` that dies with no message (the machine short of memory) is re-run up to
twice and listed at the end of the run; a complete but wrong waveform fails at
once.

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
against the golden VCDs (see *Regression check*) must pass on every merge --
the `regressao-golden` CI check runs `verification/regress.py` on every pull
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
