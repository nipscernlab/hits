# The board with the ARM processor

`projects/hits_reco/quartus/` is the project HITS started from: the
DE10-Nano with its hard processor system (HPS), a dual-core ARM processor, built
on the reference design of Terasic. The simulator and a reconstruction technique
run in the FPGA, and a program on the ARM sets the occupancy and the pedestal
while it runs. It is development, not product: it ties the simulator to one
board, to the Platform Designer (Qsys) system of that board and to an operating
system image.

The top is `de10_nano_soc_ghrd.v`. It takes the occupancy and the offset from
bits [6:0] and [19:7] of a register that the HPS writes, and brings them into
the clock domain of the simulator through a two-flop synchronizer, accepting a value only
when two consecutive samples agree. The register has room for 7 bits of
occupancy: they are the top bits of the 16-bit occupancy of `hits`, and the top
module adds the 9 low bits (506 with `USE_ENERGY_LORENZETTI`, 0 otherwise). The
older round-robin and leap generators also draw only 7 bits and compare them with
the top 7 bits of `occupancy`, so with them the occupancy moves in steps of 1/128.

To run it:

1. Write the Linux image of the release `linux-image-v1` to a micro-SD card of
   at least 2 GB (seven files of a split zip; extract `de10_backup_image.zip`).
2. Set every MSEL switch to ON, connect Ethernet and power the board. Linux boots
   and programs the FPGA.
3. Connect over SSH to the address of the board. The login of the image is in
   the README of the repository.
4. Run `./change_occupancy` and use its menu to change the occupancy or the
   pedestal. Its source, with a Makefile for the Intel SoC EDS, is in
   `software/change_occupancy/`.
5. To watch the signals, open `DE10_NANO_SoC_GHRD.qpf` in Quartus, connect the
   USB-Blaster II, open `stp1.stp` in Signal Tap and start the analysis.

The prebuilt `.sof` and `.rbf` in `output_files/` date from 2026-07-17 and
predate the synchronizer; compiling the project gives the current design. The
project uses Platform Designer files of Quartus 23.1.
