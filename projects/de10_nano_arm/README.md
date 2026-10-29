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

### Before you start: what was checked, and what was not

On 2026-10-28 the steps that do not need the board were run here, from a clean
clone, with Quartus 23.1std.1: the HPS system generated, the trigger of Signal
Tap set in its window, the project compiled, the `.rbf` written; the ARM program
was built and run in an emulator, and the image of the card opened and read. The
steps on the board were not run since the reorganization of 2026-10-21. The
last design that ran on the board is the bitstream on the card of the image,
written there on 2025-06-12 (the same file is the prebuilt `.rbf` of
`hardware/output_files/`). What reading the image showed, and why some steps are
the way they are:

- **The board loads the FPGA in U-Boot, from the FAT partition of the card**
  (`soc_system.rbf` next to `zImage`), before Linux starts. The image also has a
  boot script, `fpga_load`, that writes `/home/root/soc_system.rbf` to
  `/dev/fpga0`; on this kernel (4.5.0) `/dev/fpga0` is not a device, and the
  script only makes a copy of the file in `/dev`. It never programs the FPGA.
  So the new design goes on the FAT partition (Step 7), and nowhere else.
- **The `.rbf` is written without compression.** The one on the card is exactly
  the output of `quartus_cpf -c` without compression (7,007,204 bytes). The
  compressed one (about 2.3 MB) is not what the board has ever loaded.
- **The Quartus version.** That bitstream was compiled by Quartus
  Prime Lite **23.1std.1** (Build 993), and the project was last saved by it. Use
  that version. Quartus 24.1std also compiles the project (checked 2026-10-28),
  but no 24.1 bitstream has run on the board yet. The installer of 23.1std.1
  needs administrator rights: run it as administrator.
- The preloader of the card is U-Boot SPL 2013.01.01 of 2016, the Linux is
  Angstrom v2014.12 with kernel 4.5.0. None of them is rebuilt here.

If a step does not give what it says, **stop there** and report it (see
*Reporting* at the end): from Step 8 on, the cause may be in this guide.

### What you need

- the DE10-Nano kit: the board, its 5 V power supply and the USB cable of its
  USB-Blaster II port (mini-USB);
- a micro-SD card of at least 2 GB, and a card reader for the PC;
- an Ethernet cable, and a router or switch with DHCP on the same network as the
  PC (or a direct cable to the PC, see *Troubleshooting*);
- a Windows PC with:
  - Quartus Prime Lite **23.1std.1** with Cyclone V support (Signal Tap comes
    with it);
  - Git, and Python 3 (for the comparison of Step 12);
  - 7-Zip, to extract the split image;
  - a tool to write a disk image to the card: balenaEtcher or Win32 Disk Imager;
  - an SSH client. Windows 10 and 11 already have `ssh` and `scp` in the
    terminal (PowerShell).

Below, `C:\intelFPGA_lite\23.1std` is where Quartus 23.1 is installed; change it
if yours is elsewhere.

### Step 1: get the code

In PowerShell, in a folder **outside OneDrive** (Quartus cannot write inside a
synchronized folder):

```powershell
git clone https://github.com/nipscernlab/hits.git C:\hits
cd C:\hits
git log --oneline -1
```

**What you should see:** a commit equal to or later than the one that brought
this guide (2026-10-28).

**Shortcut: the ready bitstream.** The pre-release
[`board-bitstream-v1`](https://github.com/nipscernlab/hits/releases/tag/board-bitstream-v1)
has the `.rbf` and the `.sof` compiled with Quartus 23.1std.1 from commit
`ef32eec`. With them, skip Steps 2 to 5: download its four files into
`C:\hits\projects\de10_nano_arm\hardware\output_files\` (replacing the two that
are there), and in PowerShell:

```powershell
cd C:\hits\projects\de10_nano_arm\hardware
Get-Content output_files\SHA256SUMS
Get-FileHash output_files\soc_system.rbf, output_files\DE10_NANO_SoC_GHRD.sof, signaltap\stp1.stp
```

**What you should see:** each hash equal to its line of `SHA256SUMS` (one in
lowercase, the other in uppercase), including `signaltap\stp1.stp`: the window of
Signal Tap needs the `.stp` of the same compilation as the `.sof`. If the `.stp`
differs, the design changed after the release: go through Steps 2 to 5. Then go
to Step 6. You still need Quartus 23.1 installed, for Signal Tap in Step 11.

### Step 2: generate the HPS system

The files that Platform Designer generates are not in git. Generate them once,
before the first compilation, in the folder `hardware/`:

```powershell
cd C:\hits\projects\de10_nano_arm\hardware
& "C:\intelFPGA_lite\23.1std\quartus\sopc_builder\bin\qsys-generate.exe" soc_system.qsys --synthesis=VERILOG
```

It takes about two minutes.

**What you should see:** the last lines say `qsys-generate succeeded.` and
`Finished: Create HDL design files for synthesis`, and a folder
`hardware/soc_system/` appears, with `synthesis/` inside.

### Step 3: check the trigger of Signal Tap

The capture of Step 11 has to start when the simulator leaves reset, so it can be
compared with the simulation sample by sample. The Signal Tap of the repository
already has it: `rst_sync[1]` (the reset of `hits_reco`) is among its signals,
with the trigger on its falling edge and the trigger position *pre*. Signal Tap
is compiled from the `.qsf`, not from `stp1.stp`, so check the `.qsf`:

```powershell
cd C:\hits\projects\de10_nano_arm\hardware
Select-String rst_sync DE10_NANO_SoC_GHRD.qsf
Select-String SLD_DATA_BITS DE10_NANO_SoC_GHRD.qsf
```

**What you should see:** two lines with `rst_sync[1]` (`acq_trigger_in[162]` and
`acq_data_in[162]`), and `SLD_DATA_BITS=195`.

When you open the project in Quartus, a yellow bar *IP upgrade recommended*
appears: close it with its X and do not upgrade. It is about `hps_reset`, made
with Quartus 20.1, and the bitstream that works on the board was built with it
as it is.

To change the signals of Signal Tap one day: in a fresh copy, run *Processing >
Start > Start Analysis & Elaboration* first (before it, the Node Finder shows
*No nodes available*); then *Tools > Signal Tap Logic Analyzer*, tab *Setup*,
*Add Nodes* with *Filter* = *Signal Tap: pre-synthesis*; *File > Save*, and close
Quartus, which writes the `.qsf` when it closes. Commit the `.stp` and the `.qsf`
together: the `.qsf` carries a CRC of the setting, and the window of Signal Tap
compares it with the `.stp` it opens. Do not edit either file by hand.

### Step 4: compile

In Quartus, *Processing > Start Compilation*. It takes from 15 to 35 minutes,
depending on the PC.

**What you should see:** `Full Compilation was successful. 0 errors` (several
hundred warnings are normal) and no critical warning *Timing requirements not met*.
Two critical warnings *No exact pin location assignment(s)* are normal: they are
about the memory pins of the HPS, in the design of Terasic. In *Fitter > Summary*:
about 5100 ALMs, about 9200 registers, 51 RAM blocks, 7 DSP blocks, 1 PLL,
172 pins (Quartus 23.1std.1 gave 5101 ALMs and 9194 registers on 2026-10-28; a
few dozen of difference are normal). The file
`hardware/output_files/DE10_NANO_SoC_GHRD.sof` has the date and time of now.

### Step 5: turn the `.sof` into the `.rbf` the board loads

In PowerShell:

```powershell
cd C:\hits\projects\de10_nano_arm\hardware\output_files
& "C:\intelFPGA_lite\23.1std\quartus\bin64\quartus_cpf.exe" -c DE10_NANO_SoC_GHRD.sof soc_system.rbf
(Get-Item soc_system.rbf).Length
```

No compression option: see *Before you start*. (`sof_to_rbf.bat`, in the same
folder, runs the same command.)

**What you should see:** `7007204`, the size of every `.rbf` of this FPGA without
compression, and the file with the date and time of now.

### Step 6: write the Linux image to the card

Download the seven files of the release
[`linux-image-v1`](https://github.com/nipscernlab/hits/releases/tag/linux-image-v1)
(`de10_backup_image.z01` to `.z06` and `de10_backup_image.zip`) into one folder.
Open the `.zip` with 7-Zip and extract it (7-Zip picks up the other six parts by
itself). Write the extracted image to the micro-SD card with balenaEtcher or Win32
Disk Imager.

**What you should see:** the tool reports the write as finished and verified.
Windows may then say that a drive needs formatting: answer **no**, that is the
Linux partition, which Windows cannot read.

### Step 7: put the new design on the card

Take the card out and put it back in the PC. One drive of the card opens in
Windows (the FAT partition): it has `zImage`, `socfpga.dtb`, `u-boot.scr` and
`soc_system.rbf`. In PowerShell, with `E:` replaced by the letter of that drive:

```powershell
copy E:\soc_system.rbf C:\hits\soc_system_2025-06-12.rbf
copy C:\hits\projects\de10_nano_arm\hardware\output_files\soc_system.rbf E:\soc_system.rbf
(Get-FileHash E:\soc_system.rbf).Hash
(Get-FileHash C:\hits\projects\de10_nano_arm\hardware\output_files\soc_system.rbf).Hash
```

Then eject the card in Windows before taking it out.

**What you should see:** the two hashes equal (with the ready bitstream, also
equal to the line of `soc_system.rbf` in `SHA256SUMS`). The copy of the old one
(`soc_system_2025-06-12.rbf`) is how you go back (*Troubleshooting*).

### Step 8: boot the board

With the board off: insert the card, set **all six** switches of SW10 (the MSEL
DIP switch, which selects how the FPGA is configured) to ON, connect the Ethernet
cable and the USB-Blaster II cable, then the power supply. All ON is the setting
of the group for this image, with the `.rbf` without compression; the user manual
of the board gives another one (01010) for the images of Terasic, which this is
not.

**What you should see:** after about a minute Linux has booted with the new
design. LED0 blinks once per second; LED1 to LED7 are off.

### Step 9: find the board on the network, log in, and copy the ARM program

Find the IP address the router gave the board (the list of DHCP clients of the
router, or an IP scanner such as Advanced IP Scanner). From the PC:

```powershell
scp C:\hits\projects\de10_nano_arm\software\change_occupancy\build\change_occupancy root@<IP of the board>:/home/root/change_occupancy_new
ssh root@<IP of the board>
```

The login and the password of the image are in the README at the root of the
repository, in *Running on the DE10-Nano board*. On the board:

```sh
cd /home/root
mv change_occupancy change_occupancy_2025-06-05
mv change_occupancy_new change_occupancy
chmod +x change_occupancy
ls -l change_occupancy*
```

The program in the image (2025-06-05) has the bug of
[issue #7](https://github.com/nipscernlab/hits/issues/7): setting the occupancy
cleared the lowest bit of the pedestal. The new one is corrected, and statically
linked, so it does not depend on the libraries of the image.

**What you should see:** a Linux prompt on the board, in `/home/root`, and the two
programs listed: `change_occupancy` with 373,848 bytes, `change_occupancy_2025-06-05`
with 9365 bytes.

### Step 10: set the occupancy and the pedestal from the ARM

On the board:

```sh
./change_occupancy
```

The program shows a menu: `1` sets the occupancy (0 to 127), `2` sets the
pedestal, which the menu calls offset (-4096 to 4095), `0` exits. **Set both in
the same run of the program**: each run starts from 0 in both, so a value set in
an earlier run is lost when you set the other one.

Do option `1` with `64`, then option `2` with `146`, and leave the program open.

The 7-bit occupancy of the menu is the top of the 16-bit occupancy of HITS: the hit
probability in each filled bunch crossing is occupancy/128, so 64 is 50%. The
board shows the occupancy on the LEDs: LED7 is its highest bit and LED1 its lowest.

**What you should see:** after `64`, LED7 lights up and LED1 to LED6 stay off
(64 = 1000000 in binary).

### Step 11: capture the restart of the simulator with Signal Tap

On the PC, with the USB-Blaster II cable connected, open
`hardware/signaltap/stp1.stp` in Quartus (*Tools > Signal Tap Logic Analyzer*). In
*Hardware* choose *DE-SoC*, in *Device* the FPGA (5CSEBA6), and under *SOF
Manager* make sure the file is `hardware/output_files/DE10_NANO_SoC_GHRD.sof` of
Step 4. **Do not press the button that programs the device**: the FPGA already
has the design, from the card.

Press *Run Analysis* once (not the loop). Signal Tap waits for the trigger. **Press
and release KEY0** on the board: it restarts the simulator, with the occupancy and
the pedestal of Step 10 kept by the ARM.

Then *File > Export*, format *Comma Separated Values File (.csv)*, and save as
`C:\hits\capture_64.csv`.

**What you should see:** the *Data* tab with `rst_sync[1]` at 1 at the start and
falling to 0 at the trigger; after it, `shaper_clip` with a baseline around 146
and pulses where `event_bt` has energy. `occupancy` = 64 and `offset` = 146.

### Step 12: compare the capture with the simulation

In PowerShell:

```powershell
cd C:\hits\projects\de10_nano_arm\tools
python compare_capture.py C:\hits\capture_64.csv
```

`board_reference.csv`, next to the script, is the simulation of the same circuit
with occupancy 64 and pedestal 146, from the moment the reset is released.

**What you should see:** `EQUAL to the simulation, sample by sample.`, with about
2000 samples compared in `shaper_clip`, `event_bt` and `bt_mask_out`. If it says
`DIFFERENT`, keep the `.csv` and send it with the output.

### Step 13: occupancy 0 and 127

In the program of Step 10, set the occupancy to `0` (keep the pedestal 146: set it
again if you restarted the program) and capture again (*Run Analysis*, KEY0): no
more pulses, only the baseline with noise around 146. Set it to `127` and
capture: pulses in almost every filled crossing, piling up.

### Reporting

Send to Luciano, by e-mail:

1. the commit of Step 1, the version of Quartus, and the *Fitter > Summary* of
   Step 4 (a screenshot);
2. the size of Step 5 and the two hashes of Step 7;
3. a photo of the LEDs with occupancy 64 (Step 10);
4. `capture_64.csv` and the output of Step 12;
5. screenshots of Signal Tap with occupancy 0 and 127 (Step 13);
6. for each step, "as expected" or what was different, with the exact message of
   the error if there was one.

### Troubleshooting

- **No IP on the router:** connect a mini-USB cable to the UART port of the board
  and open a serial terminal (PuTTY, 115200 baud) on the COM port that appears;
  you get the Linux console there, and `ip addr` shows the address.
- **No router:** connect the cable straight to the PC; then the board has no DHCP
  server and an address has to be set by hand on both sides (ask before doing it).
- **LED0 does not blink after Step 8:** first check that all six switches of SW10
  are ON. Then go back to the old design: put the card in the PC, copy
  `C:\hits\soc_system_2025-06-12.rbf` over `E:\soc_system.rbf`, boot again, and
  report. If the old one does not blink either, the problem is not the new design.
- **The serial console stops in U-Boot with an error about `fpga load`:** the
  `.rbf` on the card is not the one of Step 5 (check the size: 7007204). Report the
  exact message.
- **Signal Tap says the design does not match:** the `.sof` in the *SOF Manager*
  is not the one of the `.rbf` on the card. Both must come from the same
  compilation (Steps 4 and 5).
- **Signal Tap never triggers:** check that the trigger is the falling edge of
  `rst_sync[1]` (Step 3) and press KEY0 after *Run Analysis*, not before.
- **`./change_occupancy` says it cannot open `/dev/mem`:** you are not logged in as
  `root`.
- **`/home/root/soc_system.rbf`:** do not put a bitstream there. The boot script
  `fpga_load` of the image would copy it to `/dev/fpga0`, which on this kernel is a
  plain file, and the FPGA would not change.

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
  output_files/                  the prebuilt .sof and .rbf (the bitstream of the card), the programmer chain .cdf, sof_to_rbf.bat
software/                        the ARM side
  generate_hps_qsys_header.sh    writes software/hps_0.h, the addresses the ARM program uses
  change_occupancy/              the program that sets the occupancy and the pedestal (main.c, Makefile, prebuilt binary)
  linux/fpga_load                a boot script of the image; on its kernel it does not program the FPGA (Running it on the board)
tools/
  board_reference.v, .csv        the simulation that a capture of Step 12 is compared with
  compare_capture.py             the comparison of Step 12
  plot_signaltap.m               plots a SignalTap capture
```

The SD-card image of the release `linux-image-v1` holds a bitstream of
2025-06-12, older than the HITS of today, and so do the `.sof` and `.rbf` in
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

3. **`hps_0.h` and the ARM program**: `software/generate_hps_qsys_header.sh` runs
   `sopc-create-header-files` (it comes with Quartus, in `quartus/sopc_builder/bin/`)
   on `hardware/soc_system.sopcinfo` and writes `software/hps_0.h`; `LED_PIO_BASE`
   is 0x3000, the same since 2025. The binary in `software/change_occupancy/build/`
   (2026-10-28, with the correction of issue #7) was built in WSL with the Arm GNU
   Toolchain 13.3.rel1 (`arm-none-linux-gnueabihf`) and the headers of
   `github.com/altera-opensource/intel-socfpga-hwlib` (`armv7a/hwlib/include`),
   statically linked, so that it does not depend on the glibc 2.20 of the image:

   ```sh
   arm-none-linux-gnueabihf-gcc -std=gnu99 -Wall -O2 -static -I../ -I$HWLIB -I$HWLIB/soc_cv_av \n       -Dsoc_cv_av -o build/change_occupancy main.c && arm-none-linux-gnueabihf-strip build/change_occupancy
   ```

   It was run in `qemu-arm` with a file in place of `/dev/mem`: pedestal 147 and
   occupancy 64, in either order, give the word 0x049c0 at the PIO (the binary of
   before gave a pedestal of 146 when the occupancy came second). The `Makefile` is
   the one of the Intel SoC EDS 17.0, which built the binary of before.

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
