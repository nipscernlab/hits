# Examples

Three examples come with HITS, in `projects/hits/`: a simulation, a
Quartus project and a Vivado script. None of them is part of the simulator. They
show one way of using the core, and each can be copied and changed.

## Simulation: Icarus Verilog and AURORA

`projects/hits/aurora/` holds the testbench `hits_tb.v` and the
AURORA project `hits.spf`. The testbench instantiates `hits`
alone, so the simulation ends at the ADC sample `shaper_clip`. It runs three
orbits (10 892 cycles) with the pedestal at 146 ADC counts and the occupancy at
19.5%, then 62.5% from the middle of the run. With
`-DUSE_ENERGY_LORENZETTI` the occupancy stays at 99.991%,
as the Lorenzetti spectrum requires.

```sh
cd projects/hits/aurora
iverilog -s hits_tb -o tb.vvp ../../../rtl/*.v ../../../rtl/*/*.v hits_tb.v
vvp tb.vvp                  # writes hits_tb.vcd
```

The testbench turns these macros into choices of the core: the shaper and
noise macros of [Build options](options.md), `USE_RNG_ROUND_ROBIN`,
`USE_RNG_LEAP` and `USE_ENERGY_LORENZETTI`. It records the signals of its own scope (the inputs
and every output of the core) in `hits_tb.vcd`.

In AURORA, open `hits.spf` and press the wave button. AURORA runs the
simulation in the folder of the `.spf`, which the relative paths of the
testbench require; builds of AURORA older than 2026-07-17 ran it elsewhere and do
not find the memory files.

## Synthesis in Quartus: the DE10-Nano

`projects/hits/quartus/` puts the core alone on a Terasic DE10-Nano
(Cyclone V 5CSEBA6U23I7), with no processor. The top
`top_hits_de10.v` makes the sampling clock from the oscillator of the
board with a phase-locked loop (PLL), holds the occupancy at 99.991% and the pedestal at 146, and resets the core from the push
button KEY0, releasing the reset in step with the clock. Its `.qsf` sets the
macros `USE_SHAPER_CSA_CR4RC` and `USE_ENERGY_LORENZETTI`: this is the
configuration of the revised paper, and after the reset the ADC samples must
equal the simulation of that build bit for bit. Four LEDs show that the clock
runs, that the PLL locked, the parity of `shaper_clip` (which keeps the chain
from being removed by synthesis) and the reset.

Open `hits_de10.qpf` in Quartus Prime Lite 24.1 or newer and compile. To
see the samples on the board, add a Signal Tap instance on `shaper_clip`,
triggered by the release of the reset.

To use another board, keep `hits` and write a new top: the sampling clock,
a reset released in step with it, and the occupancy and pedestal from wherever
your design takes them.

## Synthesis in Vivado

`projects/hits/vivado/hits_vivado.tcl` synthesizes, places and routes
`hits` alone, out of context (no pins, no board), against a clock
constraint at the sampling rate, and prints the resources and the Fmax. Run it from an empty folder:

```sh
vivado -mode batch -source <hits>/projects/hits/vivado/hits_vivado.tcl
vivado -mode batch -source <hits>/projects/hits/vivado/hits_vivado.tcl \
    -tclargs xc7z010clg400-1 D:USE_SHAPER_CSA_CR4RC
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
