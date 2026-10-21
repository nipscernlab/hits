# Using the core in your design

`hits` is a self-contained core: one clock, one reset, a configuration bus,
and the outputs listed in [The signal chain](signal-chain.md#ports). It needs no
processor: with the bus tied off it runs with the values given at synthesis, and
a controller on the bus can change them at run time
([Configuring HITS at run time](configuring.md)).

## Instantiating it

```verilog
hits #(
    .OCCUPANCY_INIT   (16'd16384),// 25% of the filled bunch crossings
    .PEDESTAL_INIT    (13'd146),  // pedestal, ADC counts
    .SIGMA_PS         (1000)      // optional: 1 ns of jitter per hit
) sim (
    .clk              (clk_40),   // one cycle per bunch crossing
    .rst              (rst),
    .addr             (4'd0),     // the configuration bus, idle
    .wdata            (16'd0),
    .wr               (1'b0),
    .rd               (1'b0),
    .rdata            (),
    .hits_out         (),
    .bt_mask_out      (),
    .energy_out       (),
    .event_bt         (),
    .event_all        (),
    .shaper_out       (),
    .shaper_corrupted (),
    .shaper_clip      (adc_sample),
    .noise_out        ()
);
```

Compile every `.v` of `rtl/` and of its subfolders (`rtl/hits.v`, `rtl/hits/`
and `rtl/components/*/`); the modules that a build does not use are left out by
the tools. A design that never changes the configuration can also instantiate
`hits_core` with its configuration inputs tied to constants, as the testbench
`verification/testbenches/hits_tb.v` does.

## Clock and reset

The core runs on one clock, and every cycle is one bunch crossing. The pulse
shapes are discrete filters, defined in samples of the readout; nothing in the
core depends on the actual frequency, which sets the time scale of the pulse.
Table 2 gives the Fmax of each build.

`rst` is active high and asynchronous. It clears the state of every generator
and filter, so a run that starts after a reset repeats exactly. Release it in
step with the clock: a reset released close to a clock edge can leave part of
the core out of reset one cycle before the rest. The DE10-Nano example
(`projects/de10_nano/top_hits_de10.v`) shows a reset released
synchronously.

## Latency

From an energy in `event_bt` to its pulse in `shaper_out` there is a fixed
latency that depends on the shaper: 7 cycles for F34, 5 for CSA + CR-4RC (1 with
`USE_SHAPER_NO_PIPE`), 2 for the legacy shaper. The ADC adds one register.
Latency only delays the pulse train.

## Memory files

Every memory of the core is initialized with `$readmemb` from a `.mif` text
file in `rtl/` (one binary word per line, despite the extension). The parameters
of `hits` name the files by their bare name, such as
`noise_gauss_s4.mif`, and each tool looks for them in its own way:

- Icarus Verilog reads them relative to the folder it runs in. The testbench
  passes every file name with the path `RTL_DIR` in front, so it has to run two
  levels below the root of the repository (`verification/testbenches/`, or
  `projects/aurora/` for AURORA).
- Quartus reads a relative name from the project folder and from the folders
  listed as `SEARCH_PATH` in the `.qsf`. The DE10-Nano example instead passes
  every file name with `../../rtl` in front, relative to its project folder.
- Vivado reads them from the folder it runs in; the Vivado example copies them
  there.

A memory file that is not found does not always stop the build. Vivado, for
instance, warns and leaves the memory empty, which removes the hits or the pulse
without an error. After a synthesis, check that the log reports each file as
read: in Vivado, `[Synth 8-3876] $readmem data file '...' is read successfully`.
The files a build reads are those of Table 1.

Table 1: the memory files each part of the core reads.

| File | Read by | When |
|---|---|---|
| `bunch_train_mask.mif` | `hit_generation/bunch_train_mask.v` | always |
| `energy_seg_default.mif` (or the ROM in `MEM_SEG`) | `energy/energy_seg.v` | xoshiro, without `USE_ENERGY_TABLES` |
| `energy_icdf_paper_0..2.mif` | `energy/energy_icdf.v` | the energy tables |
| `noise_gauss_s4.mif` | `noise/noise_gauss.v` | Gaussian noise; also the jitter draw when `SIGMA_PS` > 0 |
| `noise_s4_icdf0..2.mif`, `noise_s8_icdf0..2.mif` | `noise/noise_icdf.v` | the noise tables |
| `shaper_fenics_f34_phase.mif` | `shaper/shaper_fenics_f34_phase.v` | F34 with a phase |
| `shaper_csa_cr4rc_phase.mif` | `shaper/shaper_csa_cr4rc_phase.v` | CSA + CR-4RC with a phase |

The paths are relative to `rtl/components/`. The memories that the bus can
write start with these contents; what a controller loads replaces them until
the next power-up.

## Resources

Table 2 gives the resources of the whole core without the configuration bus,
measured on 2026-10-17 on the code of commits `71d5536` (Quartus) and `c182636`
(Vivado), before the bus existed. Quartus Prime Lite 24.1std ran on the Cyclone V
of the DE10-Nano (5CSEBA6U23I7), Vivado 2025.2 on a Zynq-7010 (xc7z010clg400-1,
speed grade -1). In both the core was the top, with its ports on virtual pins (no
input or output buffers) and a clock constraint at the sampling rate of the
readout. Fmax is the worst-case corner after
placement and routing.

Table 2: resources of the core without the bus (today, `hits_core`).

| Build | Quartus, Cyclone V | Vivado, Zynq-7010 |
|---|---|---|
| default (F34) | 1751 ALMs, 1785 registers, 3 DSP, 7 M10K, 84.7 MHz | 3144 LUTs, 1733 FFs, 28 DSP, 1 RAMB36 + 2 RAMB18, 64.5 MHz |
| F34, jitter σ = 1 ns | 1913 ALMs, 2287 registers, 20 DSP, 15 M10K, 86.3 MHz | |
| F34, fixed phase only | 1707 ALMs, 1972 registers, 18 DSP, 13 M10K, 84.6 MHz | |
| CSA + CR-4RC | 883 ALMs, 1155 registers, 23 DSP, 7 M10K, 83.5 MHz | |
| CSA + CR-4RC, jitter σ = 1 ns | 1186 ALMs, 1612 registers, 30 DSP, 14 M10K, 71.7 MHz | 2352 LUTs, 1620 FFs, 35 DSP, 3 RAMB36 + 5 RAMB18, 69.4 MHz |

The bus adds about 2% of the logic and 140 to 180 registers when it is driven
from outside, and no memory block or DSP (Table 6 of
[The configuration bus](../develop/config-bus.md)). Tied off, it is removed: the
DE10-Nano example (CSA + CR-4RC and the Lorenzetti spectrum) takes 804 ALMs,
1191 registers, 7 M10K and 23 DSP with the bus idle, measured on 2026-10-21, the
same as before the bus existed (measured at commit `741d8f5`).

The F34 shaper is built from shifts and adds: its constant multiplications are
forced into logic (`multstyle = "logic"`), which keeps the default build at 3 DSP
blocks in Quartus. Vivado has its own attribute for this (`use_dsp`) and does
not act on `multstyle`, which is why the default build takes 28 DSP slices there
(an inference from the attributes, not checked cell by cell). The phase versions put the multiplications by the table coefficients
in DSP blocks, because the coefficients are no longer constants. A fixed phase
costs almost as much as the jitter: the table stays a ROM even when its address
is a constant.
