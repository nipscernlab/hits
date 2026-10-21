# The configuration bus (draft)

Status: design under discussion
([issue #4](https://github.com/nipscernlab/hits/issues/4)), not implemented.
This page lives on the branch `lucianomaf/config-bus` until the release 1.0.0;
the points still open are listed at the end.

Today only the occupancy and the pedestal are inputs of `hits`; everything else
is fixed at synthesis. The configuration bus lets a processor next to `hits`
change at run time what can be changed without new hardware: a few scalars,
the bunch-train mask, the energy spectrum, the noise distribution and the
coefficients of the pulse phase. It is meant for any processor; the first one
is SAPHO, which is getting a keyboard and a VGA screen, for an interactive
HITS.

Three choices guide the design: the interface is as simple as a processor
port, there is a single clock, and among two ways of doing something the one
with less hardware wins.

## Three layers

1. The register core, with the generic interface below. It holds the scalars,
   runs and stops the simulation, and writes the vectors into the memories of
   the simulator.
2. The protocol, the subject of this page: the register map and the rules for
   using it.
3. One adapter per kind of controller, outside the core: the ports of SAPHO,
   Avalon-MM for the ARM processor of the DE10-Nano, AXI4-Lite for Zynq. The
   core is the same for all of them.

## Three modules

The simulator itself is `hits_core`: the circuit of `hits`, with what the bus
can change taken out of the parameters and into inputs (the hit options, the
length of the orbit, the phase of the jitter, and a write port into the
memories). Two modules use it:

- `hits` ties those inputs to its parameters. Its interface, its parameters
  and the circuit it builds are the ones of before, for a board with no
  processor or many channels in one chip.
- `hits_bus` drives them from the register core and has the interface below.

`hits_bus` is the recommended top (decided on 2026-10-21, once the cost was
measured: about 2% of the logic, Table 6); `hits` is the lean variant.

## The interface

The interface copies the input and output ports of SAPHO. A write is one clock
cycle with the data valid in that cycle; a read is one clock cycle with the
answer in that cycle. There is no handshake.

Table 1: the signals of the register core.

| Signal | Direction | Width | Meaning |
|---|---|---|---|
| `clk` | in | 1 | the clock of `hits`; the controller runs on it too |
| `addr` | in | 4 | the register |
| `wdata` | in | 16 | the word written |
| `wr` | in | 1 | 1 for one cycle: write `wdata` into `addr` |
| `rd` | in | 1 | 1 for one cycle: `rdata` must hold the word of `addr` |
| `rdata` | out | 16 | the word read, in the same cycle as `rd` |

The word of the protocol has 16 bits; wider values go in pieces of 16 bits.

With SAPHO, each register is a port: `out(p, x)` writes register `p` and
`in(p)` reads it. The adapter only turns the one-hot `out_en` and `req_in` of
the processor into the binary `addr`. SAPHO generates only the ports its program
uses, so a program that only sets the occupancy has one port.

## One clock

The controller and `hits` share the clock. Nothing crosses clock domains, and a
run, a stop or a write takes effect on the next edge. A controller on another
clock is left for later; the place for it is the `RUN` bit and the vector
writes, and the scalar writes would need a synchronizer as the one the ARM board
uses today for the occupancy and the pedestal.

## Running and stopping

The register `CONTROL` has one bit, `RUN`.

- `RUN` = 0 stops the simulation: the core holds the reset of `hits`, so every
  generator, the shaper and the position in the orbit are at their reset state.
- `RUN` = 1 releases the reset: the simulation starts from the beginning with the
  configuration in place. The same configuration gives the same samples, bit for
  bit, as the RTL simulation.
- At power-up `RUN` is 1: with no controller, `hits` runs with the contents and
  parameters given at synthesis, as it does today.
- The scalars take effect on the next cycle, running or stopped. Each one fits in
  one word, so a write is atomic and there is no shadow copy. The exception is
  `ORBIT_LEN`, written only while `RUN` is 0: changing it while running could
  leave the position past the new end, and checking for that would cost a
  comparator.
- The vectors are written only while `RUN` is 0. This is a rule of the protocol,
  with no hardware to enforce it: a vector written while running mixes old and
  new contents.

Restarting from the beginning costs one flip-flop and one OR gate on the reset
that `hits` already has. Continuing from where it stopped would need an enable
reaching every register of `hits`.

## The register map

Only `ID`, `CAPS` and `STATUS` can be read; the configuration is write-only, and
the program keeps its own copy of what it wrote. Reading back every register
would need a read multiplexer of about 12 inputs, and reading back the vectors a
second read port on each memory.

Table 2: the register map.

| Address | Name | Access | Bits | Meaning |
|---|---|---|---|---|
| 0 | `ID` | read | 16 | a fixed mark of HITS (proposed: `0x4854`, "HT") |
| 1 | `CAPS` | read | 16 | what was synthesized (Table 3) |
| 2 | `STATUS` | read | 16 | bit 0: `RUN`; the other bits are reserved |
| 2 | `CONTROL` | write | 1 | bit 0: `RUN` |
| 3 | `OCCUPANCY` | write | 16 | probability of a hit per filled bunch crossing, occupancy/65536 |
| 4 | `PEDESTAL` | write | 13 | the pedestal in ADC counts, two's complement |
| 5 | `MODE` | write | 2 | bit 0: a hit on every filled crossing (`OCC_BYPASS`); bit 1: the bunch-train mask is used (`BUNCH_TRAIN_ACTIVE`) |
| 6 | `ORBIT_LEN` | write | 12 | bunch crossings per orbit, up to `BUNCH_POS`; only while stopped |
| 7 | `PHASE0` | write | 6 | mean phase of the jitter, in steps of 1/64 of the period, two's complement |
| 8 | `SIGMA` | write | 16 | jitter: the constant `K` of `hits.v` (below) |
| 9 | `MEM_SEL` | write | 3 | which vector the next writes go to (Table 4) |
| 10 | `MEM_ADDR` | write | 12 | the address of the first word, in words of the vector |
| 11 | `MEM_DATA` | write | 16 | the next 16 bits of the vector |

`PHASE0` and `SIGMA` exist only when the jitter is synthesized; elsewhere a write
to them does nothing. `SIGMA` holds `K = floor((σ × 4096 + 3125) / 6250)`, σ in
ps, the constant `rtl/hits.v` computes today at synthesis (σ = 1 ns gives
`K` = 655). Asking the program for `K` instead of σ saves the hardware of the
division.

The reset value of each scalar is a synthesis parameter, with defaults that give
the behavior of today (the occupancy and the pedestal of the board, the mask on,
the full orbit).

Table 3: the bits of `CAPS`.

| Bits | Meaning |
|---|---|
| 1:0 | the shaper: 0 = F34, 1 = CSA + CR-4RC, 2 = legacy |
| 2 | fixed phase by a loaded set of coefficients |
| 3 | jitter per hit (the table of 64 phases) |
| 11:4 | reserved |
| 15:12 | version of the protocol, starting at 1 |

## Loading a vector

A vector is loaded in three steps, with `RUN` = 0: choose it in `MEM_SEL`, give
the first address in `MEM_ADDR`, then write its words to `MEM_DATA`. A word
wider than 16 bits goes in pieces of 16 bits, the least significant first; the
address moves to the next word after the last piece of a word.

Table 4: the vectors.

| `MEM_SEL` | Vector | Words | Bits per word | Writes per word | Exists when |
|---|---|---|---|---|---|
| 0 | bunch-train mask | 3564 | 1 (bit 0 of the write) | 1 | always |
| 1 | energy spectrum (segmented inverse CDF) | 512 | 70 | 5 | always |
| 2 | noise distribution (segmented inverse Gaussian) | 256 | 46 | 3 | always |
| 3 | distribution of the jitter | 256 | 46 | 3 | jitter |
| 4 | coefficients of the 64 phases | 64 | 192 (CSA) or 210 (F34) | 12 or 14 | jitter |
| 5 | coefficients of one phase | 1 | 192 (CSA) or 210 (F34) | 12 or 14 | fixed phase |

The mask takes one crossing per write, 3564 writes in all: the memory stays
one bit wide, as it is today. Sixteen crossings per write would need a memory
of 16-bit words with a multiplexer to pick the bit, or a memory with ports of
two widths, written differently for each tool.

The `.mif` files given at synthesis are the initial contents of these memories:
what `hits` uses until a controller loads something else. Changing the σ of the
noise is loading another Gaussian table, with no multiplier. What a controller
loads stays through a reset and a stop: only power-up brings back the `.mif`.

The fixed phase has no table: the shaper reads one set of coefficients from a
register (`COEF_SRC = "one"` in `shaper_*_phase.v`), which starts at power-up
with the set of the phase `PHASE0` and which the controller replaces with the
set of the phase it wants (vector 5). The sets of the 64 phases are the lines of
`shaper_csa_cr4rc_phase.mif` and `shaper_fenics_f34_phase.mif`, written by the
generator of the phase shapers; line 32 + n is the phase n × 25/64 ns. The table
of 64 phases (`COEF_SRC = "table"`, vector 4) exists only with the jitter, where
every hit takes its own phase. In `hits`, with nothing written, the register is
a constant. On the DE10-Nano board with the CSA shaper, the fixed phase went from
887 ALMs, 12 M10K and 28 DSP (with the table) to 866 ALMs, 7 M10K and 28 DSP:
the table is gone, and the products of the head stay in DSP blocks, where
Quartus puts them even with a constant factor (measured on 2026-10-21; the base
shapers avoid it because their generators write those products as shifts and
adds).

Writing a wide word needs a register that assembles it, as wide as the widest
word synthesized; one register serves every vector, since one is loaded at a
time. Writing the pieces straight into memories with a narrower write port
would avoid it; which costs less is measured in the implementation.

## An example

The writes a controller makes to stop the simulation, load a new bunch-train
mask, set the occupancy to 25% and run again. Each line is one write: `addr`
and `wdata` for one cycle with `wr` = 1. Any controller produces the same
sequence; how it does so is the business of its adapter.

Table 5: loading a mask and setting the occupancy.

| Step | `addr` | `wdata` | Effect |
|---|---|---|---|
| 1 | 2 (`CONTROL`) | 0 | stop: `hits` held in reset |
| 2 | 9 (`MEM_SEL`) | 0 | the next words go to the bunch-train mask |
| 3 | 10 (`MEM_ADDR`) | 0 | starting at crossing 0 |
| 4 to 3567 | 11 (`MEM_DATA`) | the mask, one crossing per write in bit 0 | 3564 writes, the address moving by itself |
| 3568 | 3 (`OCCUPANCY`) | 16384 | 25% |
| 3569 | 2 (`CONTROL`) | 1 | run, from the beginning |

A controller can first read `ID` (address 0) to check that it talks to HITS,
and `CAPS` (address 1) to learn which vectors exist.

## What it costs

Measured on 2026-10-21 by `projects/hits_bus/quartus/bus_cost.py`: `hits` and
`hits_bus` compiled the same way in Quartus for the Cyclone V of the DE10-Nano,
out of context with every port on a virtual pin, so the bus stays driven and
nothing of it is optimized away.

Table 6: `hits` against `hits_bus` (the fixed phase and the jitter not built).

| Configuration | Top | ALMs | Registers | M10K | DSP | Fmax |
|---|---|---|---|---|---|---|
| default (F34) | `hits` | 1762 | 1769 | 7 | 3 | 82.8 MHz |
| default (F34) | `hits_bus` | 1807 | 1947 | 7 | 3 | 82.3 MHz |
| revised paper (CSA + CR-4RC, Lorenzetti) | `hits` | 917 | 1172 | 7 | 23 | 75.7 MHz |
| revised paper (CSA + CR-4RC, Lorenzetti) | `hits_bus` | 935 | 1315 | 7 | 23 | 80.0 MHz |

The bus costs about 2% of the logic and 140 to 180 registers (the scalars, the
assembling register, the addresses and the piece counter), and no memory block
or DSP: the memories that became writable use the same M10K blocks. The maximum
frequency moves by less than the placement varies from one compilation to the
next; the critical path stays in the loop of the shaper.

## What stays at synthesis

- The structure: the random generator, the kind of energy and noise generator,
  the shaper and its pulse shape, every width and memory size.
- The seeds of the four xoshiro generators. They are chosen by jumps so the four
  sequences never overlap; configurable seeds would cost 512 flip-flops and lose
  that guarantee.
- The builds with the round-robin and leap generators, and the three-table
  energy and noise of the submitted paper: the bus serves only the default chain
  (xoshiro, segmented energy, Gaussian noise).

## Open points

- The exact bits of `ID`, `CAPS` and `STATUS`, and whether `STATUS` gets a
  counter of the words written to a vector, so a program can check a load.
- The assembling register against narrow write ports, by measurement.
- The maximum orbit (`BUNCH_POS`) is not in `CAPS`; the program has to know it.
- A controller on another clock.
