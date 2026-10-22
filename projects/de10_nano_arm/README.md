# DE10-Nano with the ARM processor

The DE10-Nano with its hard processor system (HPS, a dual-core ARM), built on the
reference design (GHRD) of Terasic. HITS and a reconstruction technique run in
the FPGA; a program on the ARM sets the occupancy and the pedestal while it runs.
How to run it on the board, and how the top brings the values of the ARM into
the clock of HITS, is in
[`docs/develop/board-with-arm.md`](../../docs/develop/board-with-arm.md).

To use the board without compiling anything, the SD-card image of the release
`linux-image-v1` holds the whole system, including a bitstream from 2026-07-17,
older than the HITS of today. Shipping a current bitstream with each release is
[issue #10](https://github.com/nipscernlab/hits/issues/10).

## What is here

```
hardware/                        the Quartus project: open hardware/DE10_NANO_SoC_GHRD.qpf
  DE10_NANO_SoC_GHRD.qpf .qsf    the project
  DE10_NANO_SOC_GHRD.sdc         timing constraints
  de10_nano_soc_ghrd.v           the top: the HPS system, the PLL, the synchronizer, HITS and the technique
  soc_system.qsys                the HPS system, source of Platform Designer
  *_board_info.xml               board data for the device tree
  ip/pll_40mhz/                  the 40 MHz PLL
  ip/debounce/, edge_detect/, altsource_probe/   IP of the GHRD (buttons, reset source)
  reconstruction/                the techniques the board builds, see its README
  signaltap/stp1.stp             the SignalTap configuration
  output_files/                  the prebuilt .sof and .rbf (2026-07-17), the programmer chain .cdf, sof_to_rbf.bat
software/                        the ARM side
  generate_hps_qsys_header.sh    writes software/hps_0.h, the addresses the ARM program uses
  change_occupancy/              the program that sets the occupancy and the pedestal (main.c, Makefile, prebuilt binary)
  linux/fpga_load                the boot script of the image: it programs the FPGA from /home/root/soc_system.rbf
tools/plot_signaltap.m           plots a SignalTap capture
```

## What is generated, and how

These files are not in git (`.gitignore`); each tool writes them.

1. **The HPS system**: `hardware/soc_system/` and `hardware/soc_system.sopcinfo`.
   Before the first compilation, and after any change to `soc_system.qsys`, run in
   `hardware/`:

   ```sh
   qsys-generate soc_system.qsys --synthesis=VERILOG
   ```

   `qsys-generate` is in `quartus/sopc_builder/bin/` of the Quartus installation.
   Checked with Quartus Prime Lite 24.1 on 2026-10-21, from a clean copy of this
   folder: the files it writes differ from those Quartus 23.1 wrote (kept in git
   until commit 9664745) in the internals of some IP, the top-level instances are
   the same, and the full compilation took 5085 ALMs, 9145 registers, 51 RAM
   blocks and 7 DSP, against 5083, 9191, 51 and 7 with the files of 23.1. After
   the move to `hardware/` the same check gave 5097 ALMs and 9135 registers, with
   the synthesis unchanged (8866 registers): the fitter duplicates registers for
   routing, and the placement moves with the paths.

2. **The bitstream**: compile `hardware/DE10_NANO_SoC_GHRD.qpf` in Quartus (or
   `quartus_sh --flow compile DE10_NANO_SoC_GHRD` in `hardware/`). The compilation
   also writes `hardware/hps_isw_handoff/`, `hps_sdram_p0_*` and
   `*_assignment_defaults.qdf`. Then, in `hardware/output_files/`,
   `sof_to_rbf.bat` turns the `.sof` into the `soc_system.rbf` that the image
   loads at boot.

3. **`hps_0.h` and the ARM program**: with the Intel SoC EDS (its embedded command
   shell), run `./generate_hps_qsys_header.sh` in `software/`, then `make` in
   `software/change_occupancy/`. The Makefile reads `hps_0.h` from `software/`.

4. **The preloader, u-boot and the device tree** (`software/spl_bsp/`,
   `hardware/soc_system.dts`, `hardware/soc_system.dtb`): the files that were in
   git were those of the Terasic GHRD, generated in 2016 and 2017, and the image
   of the SD card carries them. They are needed only to build a new image. To
   get them back (they come back at the paths of that commit, at the root of this
   folder):

   ```sh
   git checkout 9664745 -- projects/de10_nano_arm/software/spl_bsp projects/de10_nano_arm/soc_system.dts projects/de10_nano_arm/soc_system.dtb
   ```

   Regenerating them takes the SoC EDS (`bsp-editor` on
   `hardware/hps_isw_handoff/soc_system_hps_0`, and `sopc2dts` with the two
   `*_board_info.xml`); it has not been done in this repository.

5. **A SignalTap capture**: export it from SignalTap as
   `hardware/output_files/stp1.csv`, the file `tools/plot_signaltap.m` reads.

The PLL was made with the IP wizard of Quartus 23.1 in the root of this folder
and moved to `hardware/ip/pll_40mhz/` on 2026-10-21. Its `.qip` names its files
relative to itself, so the compilation finds them; opening it again in the
wizard has not been tried since the move.
