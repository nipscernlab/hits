# The configuration bus

The bus through which a processor configures `hits` at run time
([issue #4](https://github.com/nipscernlab/hits/issues/4)). How to use it, the
registers and the vectors are in [Configuring HITS at run time](../guide/configuring.md);
this page gives the reasons behind the design, what it costs and what is still
open.

The bus changes at run time what can be changed without new hardware: a few
scalars, the bunch-train mask, the energy spectrum, the noise distribution and
the coefficients of the pulse phase. It is meant for any processor; the first
one is SAPHO, which is getting a keyboard and a VGA screen, for an interactive
HITS. Three choices guide the design: the interface is as simple as a processor
port, there is a single clock, and among two ways of doing something the one
with less hardware wins.

## Three layers

1. The register core `hits_cfg` (`rtl/hits/hits_cfg.v`), with the generic
   interface of the guide. It holds the scalars, runs and stops the simulation,
   and writes the vectors into the memories of the simulator.
2. The protocol: the register map and the rules for using it.
3. One adapter per kind of controller, outside the core: the ports of SAPHO,
   Avalon-MM for the ARM processor of the DE10-Nano, AXI4-Lite for Zynq. The
   core is the same for all of them.

## The modules

The circuit is `hits_core` (`rtl/hits/hits_core.v`), with what the bus can
change taken out of the parameters and into inputs (the hit options, the length
of the orbit, the phase of the jitter, and a write port into the memories). The
top `hits` (`rtl/hits.v`) drives those inputs from `hits_cfg`.

Until 2026-10-21 that top was `hits_bus`, and `hits` was a lean variant that
tied the inputs to its parameters. Once the cost was measured (Table 1) the bus
became the only top and the lean variant was removed. A design that wants every
value fixed leaves the bus idle, or instantiates `hits_core` with the inputs tied
to constants, as the testbench of the simulator does.

## The interface

The interface copies the input and output ports of SAPHO: with SAPHO, each
register is a port, `out(p, x)` writes register `p` and `in(p)` reads it. The
adapter only turns the one-hot `out_en` and `req_in` of the processor into the
binary `addr`. SAPHO generates only the ports its program uses, so a program
that only sets the occupancy has one port. The word of the protocol has 16 bits;
wider values go in pieces of 16 bits.

## One clock

The controller and `hits` share the clock. Nothing crosses clock domains, and a
run, a stop or a write takes effect on the next edge. A controller on another
clock is left for later; the place for it is the `RUN` bit and the vector
writes, and the scalar writes would need a synchronizer such as the one the ARM
board uses for the occupancy and the pedestal.

## Running and stopping

`RUN` = 0 holds the reset of `hits_core`, and `RUN` = 1 restarts the simulation
from the beginning. Restarting costs one flip-flop and one OR gate on the reset
that the core already has; continuing from where it stopped would need an enable
reaching every register of the core.

Each scalar fits in one word, so a write is atomic and there is no shadow copy.
`ORBIT_LEN` is written only while stopped: changing it while running could leave
the position past the new end, and checking for that would cost a comparator.
The vectors are written only while stopped, a rule with no hardware to enforce
it.

## What can be read

Only `ID`, `CAPS` and `STATUS` can be read; the configuration is write-only, and
the program keeps its own copy of what it wrote. Reading back every register
would need a read multiplexer of about 12 inputs, and reading back the vectors a
second read port on each memory.

`SIGMA` holds the constant `K` that `rtl/hits.v` computes from `SIGMA_PS` at
synthesis, not σ: asking the program for `K` saves the hardware of the division.

## The vectors

The mask takes one crossing per write, 3564 writes in all: the memory stays one
bit wide. Sixteen crossings per write would need a memory of 16-bit words with a
multiplexer to pick the bit, or a memory with ports of two widths, written
differently for each tool.

The `.mif` files given at synthesis are the initial contents of the memories.
Changing the σ of the noise is loading another Gaussian table, with no
multiplier.

The fixed phase has no table: the shaper reads one set of coefficients from a
register (`COEF_SRC = "one"` in `shaper_*_phase.v`), which starts at power-up
with the set of the phase `PHASE0` and which the controller replaces with the
set of the phase it wants (vector 5). The table of 64 phases
(`COEF_SRC = "table"`, vector 4) exists only with the jitter, where every hit
takes its own phase. With nothing written, the register is a constant. On the
DE10-Nano board with the CSA shaper, the fixed phase went from 887 ALMs, 12 M10K
and 28 DSP (with the table) to 866 ALMs, 7 M10K and 28 DSP: the table is gone,
and the products of the head stay in DSP blocks, where Quartus puts them even
with a constant factor (measured on 2026-10-21; the base shapers avoid it because
their generators write those products as shifts and adds).

Writing a wide word needs a register that assembles it, as wide as the widest
word synthesized; one register serves every vector, since one is loaded at a
time. Writing the pieces straight into memories with a narrower write port would
avoid it; which costs less is still to be measured.

## What it costs

Measured on 2026-10-21, before the renaming, by a script of the time
(`projects/hits_bus/quartus/bus_cost.py`, at commit `4f70075`): the lean `hits`
and `hits_bus` (today's `hits`) compiled the same way in Quartus for the Cyclone V
of the DE10-Nano, out of context with every port on a virtual pin, so the bus
stays driven and nothing of it is optimized away.

Table 1: the lean `hits` against `hits_bus` (the fixed phase and the jitter not built).

| Configuration | Top | ALMs | Registers | M10K | DSP | Fmax |
|---|---|---|---|---|---|---|
| default (F34) | lean `hits` | 1762 | 1769 | 7 | 3 | 82.8 MHz |
| default (F34) | `hits_bus` | 1807 | 1947 | 7 | 3 | 82.3 MHz |
| revised paper (CSA + CR-4RC, Lorenzetti) | lean `hits` | 917 | 1172 | 7 | 23 | 75.7 MHz |
| revised paper (CSA + CR-4RC, Lorenzetti) | `hits_bus` | 935 | 1315 | 7 | 23 | 80.0 MHz |

The bus costs about 2% of the logic and 140 to 180 registers (the scalars, the
assembling register, the addresses and the piece counter), and no memory block
or DSP: the memories that became writable use the same M10K blocks. The maximum
frequency moves by less than the placement varies from one compilation to the
next; the critical path stays in the loop of the shaper. With the bus tied off,
the tools remove it: the DE10-Nano example takes 804 ALMs, 1191 registers, 7 M10K
and 23 DSP with the bus idle (measured on 2026-10-21), the same as before the bus
existed (measured at commit `741d8f5`).

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

- Whether `STATUS` gets a counter of the words written to a vector, so a program
  can check a load.
- The assembling register against narrow write ports, by measurement.
- The maximum orbit (`BUNCH_POS`) is not in `CAPS`; the program has to know it.
- A controller on another clock.
- The adapters (SAPHO, Avalon-MM, AXI4-Lite) are not written yet.
