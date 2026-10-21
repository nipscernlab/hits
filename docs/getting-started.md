# Getting started

HITS is plain Verilog with its memories in `.mif` text files. To simulate and
synthesize it, this manual uses:

- [AURORA](https://nipscern.com), the IDE of the laboratory, to simulate;
- Quartus Prime Lite, to synthesize for Intel FPGAs (tested with 24.1std);
- Vivado, to synthesize for AMD FPGAs (tested with 2025.2).

HITS has no proprietary code: it simulates in any Verilog simulator and
synthesizes for any FPGA. The tools above are the ones it was tested with.

## Get the source

A release of HITS is a zip with the `rtl/` folder, the examples and this manual.
The same files are in the repository:

```sh
git clone https://github.com/nipscernlab/hits.git
```

The HITS core is the folder `rtl/`. Its top module is `hits`, in `rtl/hits.v`;
one subfolder holds each stage, and each memory file sits next to the module
that reads it.

## A first simulation

In AURORA, open `projects/aurora/hits.spf` and press the
wave button. AURORA compiles HITS with its testbench, runs it and opens the
waveform.

The testbench runs three full bunch-train orbits (3 × 3564 bunch crossings). It
changes the occupancy, the probability of a hit in each filled bunch crossing
([The signal chain](signal-chain.md#stages) explains it), from 25% to 75%
halfway through, so the change in hit density shows in the
waveform.

Look at `shaper_clip`, the ADC sample, as an analog trace: a baseline around 146
counts (the pedestal) with a few counts of noise, and the pulses on top of it.
`event_bt` shows the energy of each hit that made a pulse.

[Build options](options.md) lists every choice and how to make it,
[Examples](examples.md) shows the same simulation from the command line, and
[Using the core in your design](integrating.md) explains how to instantiate
`hits` in a design of your own.
