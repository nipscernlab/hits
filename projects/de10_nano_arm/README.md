# DE10-Nano with the ARM processor

The DE10-Nano with its hard processor system (HPS, a dual-core ARM), built on the
reference design (GHRD) of Terasic. HITS and a reconstruction technique
(`reconstruction/`) run in the FPGA; a program on the ARM sets the occupancy and
the pedestal while it runs. How to run it on the board, and how the top brings
the values of the ARM into the clock of HITS, is in
[`docs/develop/board-with-arm.md`](../../docs/develop/board-with-arm.md).

To use the board without compiling anything, the SD-card image of the release
`linux-image-v1` holds the whole system, including a bitstream from 2026-07-17,
older than the HITS of today. Shipping a current bitstream with each release is
[issue #10](https://github.com/nipscernlab/hits/issues/10).

## What is here

| Path | What it is |
|---|---|
| `DE10_NANO_SoC_GHRD.qpf`, `.qsf`, `DE10_NANO_SOC_GHRD.sdc` | the Quartus project |
| `de10_nano_soc_ghrd.v` | the top: the HPS system, the PLL, the synchronizer and HITS with the technique |
| `soc_system.qsys` | the HPS system, source of Platform Designer |
| `hps_common_board_info.xml`, `soc_system_board_info.xml` | board data for the device tree |
| `pll_40mhz.v`, `.qip`, `.cmp`, `pll_40mhz/` | the 40 MHz PLL |
| `ip/` | debounce, edge detector and the reset source of the GHRD |
| `reconstruction/` | the techniques the board builds, see its README |
| `stp1.stp` | the SignalTap configuration |
| `output_files/` | the prebuilt `.sof` and `.rbf` (2026-07-17), the programmer chain `.cdf` and `sof_to_rbf.bat` |
| `software/change_occupancy/` | the ARM program that sets the occupancy and the pedestal, with a prebuilt binary |
| `software/linux/fpga_load` | the boot script of the image: it programs the FPGA from `/home/root/soc_system.rbf` |
| `generate_hps_qsys_header.sh` | writes `hps_0.h`, the addresses the ARM program uses |
| `tools/plot_signaltap.m` | plots a SignalTap capture |

## What is generated, and how

These files are not in git (`.gitignore`); each tool writes them.

1. **The HPS system**: `soc_system/` and `soc_system.sopcinfo`. Before the first
   compilation, and after any change to `soc_system.qsys`, run in this folder:

   ```sh
   qsys-generate soc_system.qsys --synthesis=VERILOG
   ```

   `qsys-generate` is in `quartus/sopc_builder/bin/` of the Quartus installation.
   Checked with Quartus Prime Lite 24.1 on 2026-10-21, from a clean copy of this
   folder: the files it writes differ from those Quartus 23.1 wrote (kept in git
   until commit 9664745) in the internals of some IP, the top-level instances are
   the same, and the full compilation took 5085 ALMs, 9145 registers, 51 RAM
   blocks and 7 DSP, against 5083, 9191, 51 and 7 with the files of 23.1.

2. **The bitstream**: compile the project in Quartus (or
   `quartus_sh --flow compile DE10_NANO_SoC_GHRD`). The compilation also writes
   `hps_isw_handoff/`, `hps_sdram_p0_*` and `*_assignment_defaults.qdf`. Then, in
   `output_files/`, `sof_to_rbf.bat` turns the `.sof` into the `soc_system.rbf`
   that the image loads at boot.

3. **`hps_0.h` and the ARM program**: with the Intel SoC EDS (its embedded command
   shell), run `./generate_hps_qsys_header.sh` here, then `make` in
   `software/change_occupancy/`. The Makefile reads `hps_0.h` from this folder.

4. **The preloader, u-boot and the device tree** (`software/spl_bsp/`,
   `soc_system.dts`, `soc_system.dtb`): the files that were in git were those of
   the Terasic GHRD, generated in 2016 and 2017, and the image of the SD card
   carries them. They are needed only to build a new image. To get them back:

   ```sh
   git checkout 9664745 -- projects/de10_nano_arm/software/spl_bsp projects/de10_nano_arm/soc_system.dts projects/de10_nano_arm/soc_system.dtb
   ```

   Regenerating them takes the SoC EDS (`bsp-editor` on
   `hps_isw_handoff/soc_system_hps_0`, and `sopc2dts` with the two
   `*_board_info.xml`); it has not been done in this repository.

5. **A SignalTap capture**: export it from SignalTap as
   `output_files/stp1.csv`, the file `tools/plot_signaltap.m` reads.
