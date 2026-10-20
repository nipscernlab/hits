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

1. The register core, beside `hits`, with the generic interface below. It holds
   the scalars, runs and stops the simulation, and writes the vectors into the
   memories of `hits`.
2. The protocol, the subject of this page: the register map and the rules for
   using it.
3. One adapter per kind of controller, outside the core: the ports of SAPHO,
   Avalon-MM for the ARM processor of the DE10-Nano, AXI4-Lite for Zynq. The
   core is the same for all of them.

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
  one word, so a write is atomic and there is no shadow copy.
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
| 6 | `ORBIT_LEN` | write | 12 | bunch crossings per orbit, up to `BUNCH_POS` |
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

Table 3: the bits of `CAPS` (proposed).

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
| 0 | bunch-train mask | 3564 | 1, sent 16 per write | 1 per 16 crossings (223 in all) | always |
| 1 | energy spectrum (segmented inverse CDF) | 512 | 70 | 5 | always |
| 2 | noise distribution (segmented inverse Gaussian) | 256 | 46 | 3 | always |
| 3 | distribution of the jitter | 256 | 46 | 3 | jitter |
| 4 | coefficients of the 64 phases | 64 | 192 (CSA) or 210 (F34) | 12 or 14 | jitter |
| 5 | coefficients of one phase | 1 | 192 (CSA) or 210 (F34) | 12 or 14 | fixed phase |

In the mask, bit 0 of a write is the first of its 16 crossings; the last write
carries 12 crossings in bits 11:0.

The `.mif` files given at synthesis are the initial contents of these memories:
what `hits` uses until a controller loads something else. Changing the σ of the
noise is loading another Gaussian table, with no multiplier.

The fixed phase has no table: the controller loads the coefficients of the
phase it wants (vector 5), computed off line by the generator of the phase
shapers, and the table of 64 phases exists only for the jitter. The taps stay
variable, so the fixed phase keeps the DSP blocks it costs today; the memory of
the table goes away.

Writing a wide word needs a register that assembles it, as wide as the widest
word synthesized; one register serves every vector, since one is loaded at a
time. Writing the pieces straight into memories with a narrower write port
would avoid it; which costs less is measured in the implementation.

## An example in C±

A SAPHO program that stops the simulation, loads a new bunch-train mask, sets
the occupancy to 25% and runs again:

```c
#define R_CONTROL   2
#define R_OCCUPANCY 3
#define R_MEM_SEL   9
#define R_MEM_ADDR  10
#define R_MEM_DATA  11

int mask[223] "mask.txt";        // the new mask, 16 crossings per line

void main()
{
    out(R_CONTROL, 0);           // stop: hits held in reset
    out(R_MEM_SEL, 0);           // the bunch-train mask
    out(R_MEM_ADDR, 0);
    for (int k = 0; k < 223; k++) out(R_MEM_DATA, mask[k]);
    out(R_OCCUPANCY, 16384);     // 25%
    out(R_CONTROL, 1);           // run, from the beginning
}
```

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
- Where the register core sits: a module beside `hits`, with `hits` getting
  the new inputs and the write ports of its memories.
- The assembling register against narrow write ports, by measurement.
- The maximum orbit (`BUNCH_POS`) is not in `CAPS`; the program has to know it.
- A controller on another clock.
