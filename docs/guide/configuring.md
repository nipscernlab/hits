# Configuring HITS at run time

`hits` has a configuration bus: a processor, or any controller, next to it can
change at run time the occupancy, the pedestal, the hit options, the length of
the orbit, the jitter, and the contents of the memories (bunch-train mask,
energy spectrum, noise distribution, coefficients of the pulse phase). Nothing
needs the bus: at power-up `hits` runs with the values and the `.mif` files given
at synthesis, and a design with no controller ties the bus off (see
[Using the core in your design](integrating.md)).

The register core is `hits_cfg` (`rtl/hits/hits_cfg.v`). The reasons behind the
design are in [The configuration bus](../develop/config-bus.md).

## The interface

The bus copies the input and output ports of SAPHO, the processor of the
laboratory: a write is one clock cycle with the data valid in that cycle, a read
is one clock cycle with the answer in that cycle, and there is no handshake.
The controller runs on the clock of `hits`; nothing crosses clock domains.

Table 1: the ports of the bus.

| Port | Direction | Width | Meaning |
|---|---|---|---|
| `addr` | in | 4 | the register |
| `wdata` | in | 16 | the word written |
| `wr` | in | 1 | 1 for one cycle: write `wdata` into `addr` |
| `rd` | in | 1 | 1 for one cycle: a read of `addr` |
| `rdata` | out | 16 | the word of `addr`, in the same cycle (it does not depend on `rd`) |

A bus left idle (`wr` = `rd` = 0, `addr` and `wdata` constant) keeps the values
of power-up, and in a synthesis with the bus tied off this way the tools remove
it. The DE10-Nano example, `projects/de10_nano/`, has the bus on its GPIO headers
instead, for a controller outside the board ([Examples](examples.md)).

### With SAPHO

The adapter `hits_sapho` (`rtl/hits/hits_sapho.v`) connects the ports of a
SAPHO processor to the bus. Each register is a port: `out(p, x)` writes
register `p` and `in(p)` reads it, so a program sets the occupancy with
`out(3, x)` and checks that it talks to HITS with `in(0)`, which gives
`0x4854`. The adapter is combinational and only turns the one-hot `out_en`
and `req_in` of SAPHO into `addr`; SAPHO and `hits` run on the same clock.

```verilog
hits_sapho #(.NUBITS(32), .N_OUT(12), .N_IN(3)) adapter (
    .out(out), .out_en(out_en), .req_in(req_in), .in(in),
    .addr(addr), .wdata(wdata), .wr(wr), .rd(rd), .rdata(rdata));
```

`NUBITS` is the word of the program; `N_OUT` and `N_IN` are the widths of the
`out_en` and `req_in` that YANC generated for it, at most 16. A program that
writes registers up to `MEM_DATA` (11) needs 12 output ports, and one that
reads `STATUS` (2) needs 3 input ports. Above 16 bits, the high bits of the
word written are dropped and those of the word read are 0.

## Running and stopping

The register `CONTROL` has one bit, `RUN`.

- `RUN` = 0 holds the simulator in reset: every generator, the shaper and the
  position in the orbit go to their reset state.
- `RUN` = 1 releases it: the simulation starts from the beginning with the
  configuration in place, and the same configuration gives the same samples,
  bit for bit, as the RTL simulation.
- At power-up, and after `rst`, `RUN` is 1 and every scalar is back to its
  value of synthesis.

A scalar takes effect on the next cycle, running or stopped. `ORBIT_LEN` and the
vectors are written only while `RUN` is 0. This is a rule for the program, not
enforced by the hardware: a vector written while running mixes old and new
contents.

## The registers

Only `ID`, `CAPS` and `STATUS` can be read. The configuration is write-only; the
program keeps its own copy of what it wrote.

Table 2: the registers.

| Address | Name | Access | Bits | Meaning |
|---|---|---|---|---|
| 0 | `ID` | read | 16 | `0x4854` ("HT"), to check that the controller talks to HITS |
| 1 | `CAPS` | read | 16 | what was synthesized (Table 3) |
| 2 | `STATUS` | read | 16 | bit 0: `RUN` |
| 2 | `CONTROL` | write | 1 | bit 0: `RUN` |
| 3 | `OCCUPANCY` | write | 16 | hit probability, `OCCUPANCY`/65536 per filled bunch crossing |
| 4 | `PEDESTAL` | write | 13 | the pedestal in ADC counts, two's complement |
| 5 | `MODE` | write | 2 | bit 0: a hit on every filled crossing; bit 1: the bunch-train mask is used |
| 6 | `ORBIT_LEN` | write | 12 | bunch crossings per orbit, up to `BUNCH_POS`; only while stopped |
| 7 | `PHASE0` | write | 6 | mean phase of the jitter, in steps of 1/64 of the period, two's complement |
| 8 | `SIGMA` | write | 16 | the jitter, as the constant `K` below |
| 9 | `MEM_SEL` | write | 3 | which vector the next writes to `MEM_DATA` go to (Table 4) |
| 10 | `MEM_ADDR` | write | 12 | the word where the next writes start |
| 11 | `MEM_DATA` | write | 16 | the next 16 bits of the vector |

`PHASE0` and `SIGMA` act only when the jitter is synthesized. `SIGMA` holds
`K = floor((σ × 4096 + 3125) / 6250)`, with σ in ps: σ = 1 ns is `K` = 655.

Table 3: the bits of `CAPS`.

| Bits | Meaning |
|---|---|
| 1:0 | the shaper: 0 = F34, 1 = CSA + CR-4RC, 2 = legacy |
| 2 | fixed phase by a loaded set of coefficients |
| 3 | jitter per hit (the table of 64 phases) |
| 11:4 | reserved, 0 |
| 15:12 | version of the protocol: 1 |

## The values at power-up

The parameters of `hits` give the value of each scalar at power-up and after
`rst` (Tables 1 and 3 of [Parameters and macros](../reference/parameters.md)):
`OCCUPANCY_INIT`, `PEDESTAL_INIT`, `OCC_BYPASS`, `BUNCH_TRAIN_ACTIVE`, the full
orbit `BUNCH_POS`, `PHASE0` and `SIGMA_PS`. What is built is fixed at synthesis:
a fixed phase or a jitter that the bus will set needs `PHASE_SHAPER` = 1 or
`JITTER` = 1, even when `PHASE0` and `SIGMA_PS` start at 0.

## Loading a vector

With `RUN` = 0: choose the vector in `MEM_SEL`, give the first word in
`MEM_ADDR`, then write the words to `MEM_DATA`. A word wider than 16 bits goes
in pieces of 16 bits, the least significant first; after the last piece of a
word, the address moves to the next word by itself. Writing `MEM_SEL` or
`MEM_ADDR` starts a new word.

Table 4: the vectors.

| `MEM_SEL` | Vector | Words | Bits per word | Writes per word | Exists when |
|---|---|---|---|---|---|
| 0 | bunch-train mask | 3564 | 1 (bit 0 of the write) | 1 | always |
| 1 | energy spectrum (segmented inverse CDF) | 512 | 70 | 5 | segmented energy |
| 2 | noise distribution (segmented inverse Gaussian) | 256 | 46 | 3 | Gaussian noise |
| 3 | distribution of the jitter | 256 | 46 | 3 | jitter |
| 4 | coefficients of the 64 phases | 64 | 192 (CSA) or 210 (F34) | 12 or 14 | jitter |
| 5 | coefficients of one phase | 1 | 192 (CSA) or 210 (F34) | 12 or 14 | fixed phase |

The words have the format of the `.mif` files of `rtl/`, one line of the file
per word: `energy_seg_*.mif` for vector 1, `noise_gauss_s4.mif` for vectors 2
and 3, and the lines of `shaper_fenics_f34_phase.mif` or
`shaper_csa_cr4rc_phase.mif` for vectors 4 and 5, where line 32 + n is the
phase of n × 25/64 ns. Changing the σ of the noise is loading another Gaussian.

What a controller loads stays through a stop and a reset; only power-up brings
back the `.mif` files of synthesis. The bus serves the default chain (xoshiro,
segmented energy, Gaussian noise): the energy and noise tables of the older
generators are not writable.

## An example

To stop the simulation, load a new bunch-train mask, set the occupancy to 25%
and run again, a controller makes the writes of Table 5. Each line is one
write: `addr` and `wdata` for one cycle with `wr` = 1.

Table 5: loading a mask and setting the occupancy.

| Step | `addr` | `wdata` | Effect |
|---|---|---|---|
| 1 | 2 (`CONTROL`) | 0 | stop: the simulator held in reset |
| 2 | 9 (`MEM_SEL`) | 0 | the next words go to the bunch-train mask |
| 3 | 10 (`MEM_ADDR`) | 0 | starting at crossing 0 |
| 4 to 3567 | 11 (`MEM_DATA`) | the mask, one crossing per write in bit 0 | 3564 writes |
| 3568 | 3 (`OCCUPANCY`) | 16384 | 25% |
| 3569 | 2 (`CONTROL`) | 1 | run, from the beginning |

The testbench of the bus, `verification/testbenches/hits_config_tb.v`, loads
every vector this way and checks the result against a simulator built with the
same contents.
