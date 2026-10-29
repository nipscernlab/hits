# The board with the ARM processor

`projects/de10_nano_arm/` is the project HITS started from: the
DE10-Nano with its hard processor system (HPS), a dual-core ARM processor, built
on the reference design of Terasic. The simulator and a reconstruction technique
run in the FPGA, and a program on the ARM sets the occupancy and the pedestal
while it runs. It is development, not product: it ties the simulator to one
board, to the Platform Designer (Qsys) system of that board and to an operating
system image.

The reconstruction techniques live inside the project, in `hardware/reconstruction/`:
`pzc/` (pole-zero cancellation with pedestal tracking, built when no macro is
set) and `baseline_estimator/` (adaptive baseline estimator, macro
`USE_BASELINE_EST`), joined to the simulator by the wrapper `hits_reco.v`. Both
drive `pzc_out`, on different scales: the pole-zero cancellation carries a gain
of 455, the estimator gives ADC counts. The estimator is calibrated for the F34
shaper only. The wrapper does not pass `PHASE0` and `SIGMA_PS` on, so the
simulator runs here without a phase. The techniques are not simulated by the
regression since 2026-10-21; their testbench and goldens are at the tag
`last-with-reconstruction` (see `hardware/reconstruction/README.md`).

The project is split in `hardware/` (the Quartus project) and `software/` (the
ARM side). The top is `hardware/de10_nano_soc_ghrd.v`. It takes the occupancy and the offset from
bits [6:0] and [19:7] of a register that the HPS writes, and brings them into
the clock domain of the simulator through a two-flop synchronizer, accepting a value only
when two consecutive samples agree. The register has room for 7 bits of
occupancy: they are the top bits of the 16-bit occupancy of `hits`, and the top
module adds the 9 low bits (506 with `USE_ENERGY_LORENZETTI`, 0 otherwise). The
older round-robin and leap generators also draw only 7 bits and compare them with
the top 7 bits of `occupancy`, so with them the occupancy moves in steps of 1/128.

The README of the project folder,
[`projects/de10_nano_arm/README.md`](https://github.com/nipscernlab/hits/blob/main/projects/de10_nano_arm/README.md),
is a step-by-step guide to compile the design of today, load it on the board and
check, sample by sample, that it equals the simulation. What it rests on, read
from the image of the card on 2026-10-28:

- U-Boot programs the FPGA from `soc_system.rbf` on the FAT partition of the card,
  before Linux starts; a new design goes there. The boot script `fpga_load` of the
  image writes `/home/root/soc_system.rbf` to `/dev/fpga0`, which on its kernel
  (4.5.0) is a plain file: it never programs the FPGA.
- The `.rbf` is written without compression (7,007,204 bytes), with every MSEL
  switch ON.
- The bitstream on the card was compiled by Quartus Prime Lite 23.1std.1; the guide
  asks for that version.
- The ARM program is built statically (Arm GNU Toolchain), so it does not depend on
  the libraries of the image (Angstrom v2014.12, glibc 2.20).

The bitstream on the card and the prebuilt `.sof` and `.rbf` in
`hardware/output_files/` are those of 2025-06-12 and predate the synchronizer;
compiling the project gives the current design. A compiled bitstream of a recent
commit is in the pre-releases `board-bitstream-v<n>` ([Releases](releases.md)).

The files that Platform Designer, Quartus and the SoC EDS generate are not in git, except the prebuilt
bitstreams in `hardware/output_files/` and the ARM program binary.
Before the first compilation, generate the HPS system with
`qsys-generate soc_system.qsys --synthesis=VERILOG` in `hardware/`; the README of the folder,
[`projects/de10_nano_arm/README.md`](https://github.com/nipscernlab/hits/blob/main/projects/de10_nano_arm/README.md),
lists every generated file and how to make it.
