# DE10-Nano with the ARM processor

The DE10-Nano with its hard processor system (HPS, a dual-core ARM), built on the
reference design (GHRD) of Terasic. HITS and a reconstruction technique run in
the FPGA; a program on the ARM sets the occupancy and the pedestal while it runs.
How the top brings the values of the ARM into the clock of HITS is in
[`docs/develop/board-with-arm.md`](../../docs/develop/board-with-arm.md).

The first part of this README is a step-by-step guide: compile the design of
today, put it on the board and check that it works. Each step ends with **What you
should see**; if what you see is different, stop there and report it (see
*Reporting* at the end). The second part says what each file is and how the files
that are not in git are generated.

The build in this folder is the default HITS (xoshiro generators, F34 pulse, the
default energy spectrum, Gaussian noise of σ = 4 ADC counts) followed by the
pole-zero cancellation (PZC). No macro is set in the `.qsf`.

## Running it on the board

### What you need

- the DE10-Nano kit: the board, its 5 V power supply and the USB cable of its
  USB-Blaster II port (mini-USB);
- a micro-SD card of at least 2 GB, and a card reader for the PC;
- an Ethernet cable, and a router or switch with DHCP on the same network as the
  PC (or a direct cable to the PC, see *Troubleshooting*);
- a Windows PC with:
  - Quartus Prime Lite 24.1std with Cyclone V support (Signal Tap comes with it);
  - Git;
  - 7-Zip, to extract the split image;
  - a tool to write a disk image to the card: balenaEtcher or Win32 Disk Imager;
  - an SSH client. Windows 10 and 11 already have `ssh` and `scp` in the
    terminal (PowerShell).

Everything below was written from the code of the commit `fd920ed` (2026-10-22).
The compilation was checked here; the steps on the board were not run after the
reorganization of 2026-10-21: that is what this guide is for.

### Step 1: get the code

In PowerShell, in a folder **outside OneDrive** (Quartus cannot write inside a
synchronized folder):

```powershell
git clone https://github.com/nipscernlab/hits.git C:\hits
cd C:\hits
git log --oneline -1
```

**What you should see:** a commit equal to or later than `fd920ed`.

### Step 2: generate the HPS system

The files that Platform Designer generates are not in git. Generate them once,
before the first compilation, in the folder `hardware/`:

```powershell
cd C:\hits\projects\de10_nano_arm\hardware
& "C:\intelFPGA_lite\24.1std\quartus\sopc_builder\bin\qsys-generate.exe" soc_system.qsys --synthesis=VERILOG
```

(If Quartus is installed elsewhere, change the path.) It takes about one minute.

**What you should see:** the last lines say `qsys-generate succeeded.` and
`Finished: Create HDL design files for synthesis`, and a folder
`hardware/soc_system/` appears, with `synthesis/` inside.

### Step 3: compile

Open `C:\hits\projects\de10_nano_arm\hardware\DE10_NANO_SoC_GHRD.qpf` in Quartus
and run *Processing > Start Compilation*. It takes about 30 minutes.

**What you should see:** `Full Compilation was successful. 0 errors` (several
hundred warnings are normal). In *Fitter > Summary*: about 5100 ALMs, about
9100 registers, 51 RAM blocks, 7 DSP blocks, 1 PLL, 172 pins (on 2026-10-22 it
gave 5097 ALMs and 9135 registers; a few dozen ALMs of difference from one
compilation to the next are normal). The file
`hardware/output_files/DE10_NANO_SoC_GHRD.sof` has the date and time of now.

### Step 4: turn the `.sof` into the `.rbf` the board loads

The Linux of the board programs the FPGA at boot from a `.rbf` file. In
PowerShell:

```powershell
cd C:\hits\projects\de10_nano_arm\hardware\output_files
& "C:\intelFPGA_lite\24.1std\quartus\bin64\quartus_cpf.exe" -c -o bitstream_compression=on DE10_NANO_SoC_GHRD.sof soc_system.rbf
```

(It is the command of `sof_to_rbf.bat`, in the same folder, with the full path of
Quartus.)

**What you should see:** `soc_system.rbf` in `output_files/`, a few MB, with the
date and time of now. The `soc_system.rbf` that was there before (2026-07-17) is
overwritten; that is intended.

### Step 5: write the Linux image to the card

Download the seven files of the release
[`linux-image-v1`](https://github.com/nipscernlab/hits/releases/tag/linux-image-v1)
(`de10_backup_image.z01` to `.z06` and `de10_backup_image.zip`) into one folder.
Open the `.zip` with 7-Zip and extract it (7-Zip picks up the other six parts by
itself). Write the extracted image to the micro-SD card with balenaEtcher or Win32
Disk Imager.

**What you should see:** the tool reports the write as finished and verified.
Windows may then say the card needs formatting: answer **no**, the card has Linux
partitions that Windows cannot read.

### Step 6: boot the board

With the board off: insert the card, set **all six** switches of SW10 (the MSEL
DIP switch, which selects how the FPGA is configured) to ON, connect the Ethernet
cable and the USB-Blaster II cable, then the power supply. All ON is the setting of
the group for this image (README at the root of the repository); the user manual of
the board gives another one (01010) for the images of Terasic, which this is not.

**What you should see:** after about a minute Linux has booted and the FPGA was
programmed with the old bitstream of the card. LED0 blinks once per second;
LED1 to LED7 are off.

### Step 7: find the board on the network and log in

Find the IP address the router gave the board (the list of DHCP clients of the
router, or an IP scanner such as Advanced IP Scanner). Then:

```powershell
ssh root@<IP of the board>
```

The login and the password of the image are in the README at the root of the
repository, in *Running on the DE10-Nano board*.

**What you should see:** a Linux prompt on the board, in `/home/root`. `ls` shows
at least `change_occupancy` and `soc_system.rbf`.

### Step 8: put the new design on the card

Still logged in on the board, keep a copy of the old bitstream, so you can go
back to it:

```sh
cp /home/root/soc_system.rbf /home/root/soc_system_2026-07-17.rbf
exit
```

Then, from the PC (PowerShell), copy the new one over it and reboot the board:

```powershell
scp C:\hits\projects\de10_nano_arm\hardware\output_files\soc_system.rbf root@<IP of the board>:/home/root/soc_system.rbf
ssh root@<IP of the board> reboot
```

At boot, the script `fpga_load` of the image (a copy is in `software/linux/`)
writes `/home/root/soc_system.rbf` into the FPGA.

**What you should see:** after the reboot, LED0 blinks again once per second and
LED1 to LED7 are off. Log in again (Step 7) and check with `ls -l` that
`soc_system.rbf` has the date of today.

### Step 9: set the occupancy and the pedestal from the ARM

On the board:

```sh
cd /home/root
./change_occupancy
```

The program shows a menu: `1` sets the occupancy (0 to 127), `2` sets the
pedestal, which the menu calls offset (-4096 to 4095), `0` exits. **Set the
occupancy first and the pedestal after it**: the program has a bug
([issue #7](https://github.com/nipscernlab/hits/issues/7)) and setting the occupancy
clears the lowest bit of the pedestal (an odd pedestal set before the occupancy
loses 1).

Do, in this order: option `1` with `64`, then option `2` with `146`.

The 7-bit occupancy of the menu is the top of the 16-bit occupancy of HITS: the hit
probability in each filled bunch crossing is occupancy/128, so 64 is 50%. The
board shows the occupancy on the LEDs: LED7 is its highest bit and LED1 its lowest.

**What you should see:** after `64`, LED7 lights up and LED1 to LED6 stay off
(64 = 1000000 in binary). Try `127` (LED1 to LED7 all on) and `0` (all off); finish
with `64` again, then the pedestal `146`.

### Step 10: watch the signals with Signal Tap

Leave the program of Step 9 running (or exit it: the values stay in the FPGA). On
the PC, with the USB-Blaster II cable connected, open
`hardware/signaltap/stp1.stp` in Quartus (*Tools > Signal Tap Logic Analyzer*,
*File > Open*). In *Hardware* choose *DE-SoC*, in *Device* the FPGA (5CSEBA6), and
under *SOF Manager* make sure the file is
`hardware/output_files/DE10_NANO_SoC_GHRD.sof` of Step 3. **Do not press the
button that programs the device**: the FPGA already has the design. Press *Run
Analysis* (one capture of 2048 samples; there is no trigger condition, it captures
at once).

The signals are under `hits_reco:sim`. Show `shaper_clip` and `shaper_out` as
analog (right click, *Bus Display Format*, *Unsigned Line Chart* for
`shaper_clip`, *Signed Line Chart* for `shaper_out`).

**What you should see**, with occupancy 64 and pedestal 146:

- `occupancy` = 64 and `offset` = 146;
- `bt_mask_out` alternating between trains of filled bunch crossings (1) and gaps
  (0); `event_bt`, the energy of each hit, with values in about half of the filled
  crossings and always 0 in the gaps;
- `shaper_clip`, the ADC sample: a baseline around 146 with a few counts of noise,
  and pulses on top of it where `event_bt` had energy;
- `shaper_out`, the pulse without noise and pedestal, at 1024 times the scale of
  `shaper_clip`.

Then change the occupancy on the board to `0` and capture again: no more pulses,
only the baseline with noise around 146. Set it to `127` and capture: pulses in
almost every filled crossing, piling up.

### Step 11: the reset button

Press KEY0 on the board and capture again.

**What you should see:** the capture looks like the one before (the occupancy and
the pedestal are kept by the ARM), and the board goes on running. KEY0 restarts
the simulation from the beginning.

### Reporting

Send to Luciano, by e-mail:

1. the commit of Step 1 and the *Fitter > Summary* of Step 3 (a screenshot);
2. a photo of the LEDs with occupancy 64 (Step 9);
3. screenshots of Signal Tap with occupancy 64, 0 and 127 (Step 10);
4. for each step, "as expected" or what was different, with the exact message of
   the error if there was one.

### Troubleshooting

- **No IP on the router:** connect a mini-USB cable to the UART port of the board
  and open a serial terminal (PuTTY, 115200 baud) on the COM port that appears;
  you get the Linux console there, and `ip addr` shows the address.
- **No router:** connect the cable straight to the PC; then the board has no DHCP
  server and an address has to be set by hand on both sides (ask before doing it).
- **LED0 does not blink after Step 6 or Step 8:** first check that all six
  switches of SW10 are ON.
- **The LEDs do not blink after Step 8 (they did after Step 6):** the new `.rbf` did not load. Log in
  through the serial console, put the old one back
  (`cp /home/root/soc_system_2026-07-17.rbf /home/root/soc_system.rbf`), reboot,
  and report.
- **Signal Tap says the design does not match:** the `.sof` in the *SOF Manager*
  is not the one of the `.rbf` on the card. Both must come from the same
  compilation (Steps 3 and 4).
- **`./change_occupancy` says it cannot open `/dev/mem`:** you are not logged in as
  `root`.

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

The SD-card image of the release `linux-image-v1` holds a bitstream from
2026-07-17, older than the HITS of today, and so do the `.sof` and `.rbf` in
`hardware/output_files/` until someone compiles. Shipping a current bitstream with
each release is [issue #10](https://github.com/nipscernlab/hits/issues/10).

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
   The prebuilt binary in `software/change_occupancy/build/` and the one in the
   image work with this design: the addresses of the HPS system did not change.

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
