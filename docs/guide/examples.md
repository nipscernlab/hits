# Examples

Three examples come with HITS: a simulation (`projects/aurora/`, with the testbench
`verification/testbenches/hits_tb.v`), a Quartus project (`projects/de10_nano/`) and a
Vivado script (`projects/zybo/`). None of them is part of the simulator. They
show one way of using the core, and each can be copied and changed.

## Simulation: Icarus Verilog and AURORA

`verification/testbenches/` holds the testbench `hits_tb.v` and `projects/aurora/`
the AURORA project `hits.spf`. The testbench instantiates `hits_core`, the circuit of
`hits`, alone and with its configuration fixed, so the simulation ends at the ADC sample `shaper_clip`. It runs three
orbits (10 892 cycles) with the pedestal at 146 ADC counts and the occupancy at
25%, then 75% from the middle of the run. With
`-DUSE_ENERGY_LORENZETTI` the occupancy stays at 99.991%,
as the Lorenzetti spectrum requires.

```sh
cd verification/testbenches
iverilog -s hits_tb -o tb.vvp ../../rtl/*.v ../../rtl/hits/*.v ../../rtl/components/*/*.v hits_tb.v
vvp tb.vvp                  # writes hits_tb.vcd
```

The testbench turns these macros into choices of the core: the shaper and
noise macros of [Build options](options.md), `USE_RNG_ROUND_ROBIN`,
`USE_RNG_LEAP`, `USE_ENERGY_LORENZETTI`, `USE_PHASE0=<n>` and
`USE_PHASE_SIGMA_PS=<ps>`. It records the signals of its own scope (the inputs
and every output of the core) in `hits_tb.vcd`.

In AURORA, open `hits.spf` and press the wave button. AURORA runs the
simulation in the folder of the `.spf`, which the relative paths of the
testbench require; builds of AURORA older than 2026-07-17 ran it elsewhere and do
not find the memory files. To check a simulation by the Verilator of AURORA against the golden of the regression, from the root of the repository: `fst2vcd projects/aurora/hits_tb.vcd > aurora.vcd && python verification/compare_vcd.py --by-signal aurora.vcd` (the Verilator writes FST under the name `.vcd`, and `fst2vcd` comes with AURORA in its GTKWave package; the comparison is by signal, because the text of a Verilator VCD never equals that of the Icarus golden).

## Synthesis in Quartus: the DE10-Nano

`projects/de10_nano/` puts the core alone on a Terasic DE10-Nano
(Cyclone V 5CSEBA6U23I7), with no processor. The top
`top_hits_de10.v` makes the sampling clock from the oscillator of the
board with a phase-locked loop (PLL), starts with the occupancy at 99.991% and the pedestal at 146, and resets the core from the push
button KEY0, releasing the reset in step with the clock. The configuration bus of
`hits` is on the two GPIO headers, for a controller outside the board: `addr`,
`wdata`, `wr` and `rd` on GPIO_0[0..21], the 40 MHz clock of `hits` out on
GPIO_0[22], and `rdata` on GPIO_1[0..15] (the pins are in `hits_de10.qsf`, from
the user manual of the board). The signals are registered at the pins: a write
reaches `hits` one clock cycle after it is sampled, and a read answers on the pins
two cycles after. The switch SW0 enables the bus; with SW0 at 0 the headers are
ignored and the board runs with the values of power-up. Its `.qsf` sets the
macros `USE_SHAPER_CSA_CR4RC` and `USE_ENERGY_LORENZETTI`: this is the
configuration of the revised paper, and after the reset the ADC samples must
equal the simulation of that build bit for bit. The phase of the pulse is off;
adding the macro `USE_PHASE0=<n>` or `USE_PHASE_SIGMA_PS=<ps>` to the `.qsf`
turns on a fixed phase or a jitter per hit, as in the testbench. Four LEDs show that the clock
runs, that the PLL locked, the parity of `shaper_clip` (which keeps the chain
from being removed by synthesis) and the reset.

Open `hits_de10.qpf` in Quartus Prime Lite 24.1 or newer and compile. To
see the samples on the board, add a Signal Tap instance on `shaper_clip`,
triggered by the release of the reset.

To use another board, keep `hits` and write a new top: the sampling clock,
a reset released in step with it, and the configuration bus tied off or driven by
your controller.

## Synthesis in Vivado

`projects/zybo/hits_vivado.tcl` synthesizes, places and routes
`hits` alone, out of context (no pins, no board), against a clock
constraint at the sampling rate, and prints the resources and the Fmax. Run it from an empty folder:

```sh
vivado -mode batch -source <hits>/projects/zybo/hits_vivado.tcl
vivado -mode batch -source <hits>/projects/zybo/hits_vivado.tcl \
    -tclargs xc7z010clg400-1 D:USE_SHAPER_CSA_CR4RC G:SIGMA_PS:1000
```

The arguments are, in any order, the part (default `xc7z010clg400-1`), macros as
`D:<NAME>` or `D:<NAME>:<value>`, and parameters as `G:<NAME>:<value>`. They use a
colon because `vivado.bat` on Windows splits its arguments at `=`. The script
copies the `.mif` files of `rtl/` into the folder, where Vivado reads them, and
writes `utilization.rpt`, `timing.rpt` and a one-line `result.txt`. It ran with
Vivado 2025.2 on the two builds above; their results are in
[Table 2 of Using the core](integrating.md#resources).

To put the core on an AMD board, add the RTL files to a Vivado project, write a
top as for Quartus, and check in the synthesis log that every memory file was
read.
