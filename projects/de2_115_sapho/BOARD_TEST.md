# Testing HITS on SAPHO on the DE2-115

This guide is for the student who has the DE2-115 board, and for the AI assistant
(Claude or another) helping them. It takes you from nothing installed to a
finished test with a report. Follow it in order and do not skip the checks: each
one tells you whether the step before it worked.

**This design has never run on a board.** Everything in it was checked in
simulation and by the Quartus compiler, not on hardware. You are the first. So
when something does not match this guide, that is a result, not your mistake:
write down what you saw, take a photo, and report it (section 11) instead of
working around it.

## 0. For the assistant helping the student

- The facts about HITS, SAPHO, YANC and AURORA are in their repositories, not in
  general knowledge: none of them exists outside the NIPS-CERN group. Read the
  file before you answer. The main ones: this guide, the
  [README of this folder](README.md), `software/hits_menu.cpp`, and the
  register map in [docs/guide/configuring.md](../../docs/guide/configuring.md).
- When you deduce something instead of reading it, say so.
- Do not edit the generated files (`hits_menu.v`, the `.mif`, `pc_hits_menu_mem.txt`,
  `sapho/`), the pins of `hits_de2_115.qsf` or `signaltap/stp1.stp`. If one seems
  wrong, report it.
- If a step fails, stop there and help the student describe it (section 11). Do
  not change the design to make the test pass.
- No password, token or key goes into a file, a commit or a report.

## 1. What you are testing

```
          50 MHz crystal
               |
              PLL ------------------- 25 MHz ------------------+
               | 40 MHz                                        |
   +-----------+------------------+                +-----------+-----------+
   | SAPHO (processor, 16 bits)   | <-- link 0 --- | myKeyPS2   <- PS/2 keyboard
   | runs software/hits_menu.cpp  | --- link 1 --> | myVGAText  -> VGA monitor
   +-----------+------------------+                +-----------------------+
               | configuration bus (hits_sapho.v)
   +-----------+------------------+
   | hits: the simulator of the   | --> Signal Tap (waveforms over JTAG)
   | TileCal readout chain        | --> hex_debug -> 7-segment displays
   +------------------------------+
```

SAPHO is a soft-core processor whose hardware is generated for the program it
runs. The program, `software/hits_menu.cpp`, shows a menu on the monitor, reads
numbers from the keyboard and writes them to the registers of `hits`: the
occupancy (how often a hit happens), the pedestal (the baseline of the ADC), the
mode, the length of the orbit, and run or stop. The 7-segment displays show what
reached `hits`, and Signal Tap shows the waveforms `hits` produces.

## 2. What you need

Hardware:

- the Terasic DE2-115, its 12 V power adapter and its USB cable (the USB Blaster
  port);
- a VGA monitor that takes 640 x 480 at 60 Hz, and a VGA cable;
- a PS/2 keyboard. A USB keyboard on a passive PS/2 adapter works only if the
  keyboard itself still speaks PS/2, and many do not: use a real PS/2 keyboard if
  you can. The layout can be ABNT2 or US; the menu only needs the digits, `-`,
  Enter and Backspace, which are in the same place on both.

Software, on Windows 10 or 11:

| What | Version | Needed for |
|---|---|---|
| Quartus Prime Lite, with the Cyclone IV device support and Signal Tap | **24.1std.0** | programming the board, Signal Tap; compiling (path B) |
| The USB Blaster driver | comes with Quartus, in `<quartus folder>\drivers` | programming the board |
| Git for Windows (gives Git Bash) | any recent | everything |
| MSYS2, with `gcc`, `make`, `bison`, `flex` | any recent | path B: building YANC |
| Node.js and the AURORA setup | what `setup.bat` installs | path B: AURORA |

Two ways through this guide:

- **Path A, the ready bitstream:** you download the compiled design and test it.
  Fast, and enough for the test. Sections 3, then 5 to 11.
- **Path B, from the sources:** you build YANC, run AURORA from its sources with
  YANC's latest version, generate the processor, simulate and compile it
  yourself. Do it after path A, or when the group asks for it. Section 4, then 5
  to 11.

## 3. Path A: the ready bitstream

1. Get the repository at the commit of the bitstream (in Git Bash; keep the path
   short, with no spaces, and outside OneDrive):

       mkdir -p /c/Dev && cd /c/Dev
       git clone https://github.com/nipscernlab/hits.git
       cd hits
       git checkout de2-115-bitstream-v2

   Git says you are in "detached HEAD": that is expected, you are on the exact
   commit the bitstream was compiled from.

2. Download the three files of the pre-release
   [de2-115-bitstream-v2](https://github.com/nipscernlab/hits/releases/tag/de2-115-bitstream-v2):
   `hits_de2_115.sof`, `stp1.stp` and `SHA256SUMS`.

3. Check that the download is intact. In PowerShell, in the download folder:

       Get-FileHash hits_de2_115.sof

   The hash must be the one `SHA256SUMS` lists for it (it starts with
   `B04B0296`). If it differs, download again.

4. Put the `.sof` where the project expects it:
   `C:\Dev\hits\projects\de2_115_sapho\output_files\hits_de2_115.sof` (create
   `output_files` if it does not exist). The `stp1.stp` of the release is the same
   file as `projects\de2_115_sapho\signaltap\stp1.stp` in the repository at that
   commit, so you do not need to copy it.

Go to section 5.

## 4. Path B: from the sources

### 4.1 The folders

YANC and AURORA must sit side by side in the same folder, because the script that
gives AURORA the latest YANC looks for `..\Aurora` next to `yanc`. Use a short
local path, never OneDrive, Dropbox or a network drive (AURORA refuses them):

```
C:\Dev\
   hits\     the simulator and this project
   yanc\     the compiler of SAPHO
   aurora\   the IDE of SAPHO
```

In Git Bash:

    mkdir -p /c/Dev && cd /c/Dev
    git clone https://github.com/nipscernlab/hits.git
    git clone https://github.com/nipscernlab/yanc.git
    git clone https://github.com/nipscernlab/aurora.git

### 4.2 Build YANC

YANC is built with MSYS2. Install it from <https://www.msys2.org/>, open the
*MSYS2 MINGW64* terminal and install the tools:

    pacman -S mingw-w64-x86_64-gcc make bison flex

Then build, in the same terminal:

    cd /c/Dev/yanc
    make

`make` leaves the compilers in `yanc/bin/` (`cppcomp.exe`, `asmcomp.exe` and the
others). The details are in `yanc/docs/develop/building.md`. After every
`git pull` of YANC, run `make` again: the compilers must come from the same
commit as the rest of YANC.

### 4.3 AURORA from its sources, with the latest YANC

AURORA normally downloads a released YANC (it is pinned, and the release does not
yet have the fix of the keyboard and the screen of 2026-10-30, yanc#64). To make
it use the YANC you just cloned:

1. Install AURORA from its sources, in PowerShell:

       cd C:\Dev\aurora
       .\setup.bat

   It installs Git, Node.js and the dependencies, downloads the toolchain
   (Icarus Verilog, GTKWave and the released YANC) and offers to start AURORA. Let
   it finish, then close AURORA. The details are in the README of `aurora`,
   "Building from source".

2. Deploy the latest YANC into AURORA. In a Windows command prompt (`cmd`), with
   MSYS2 on the `PATH` (adjust `C:\msys64` if MSYS2 is elsewhere):

       set PATH=C:\msys64\mingw64\bin;C:\msys64\usr\bin;%PATH%
       cd C:\Dev\aurora
       ..\yanc\Scripts\aurora.bat

   The script builds YANC with the same recipe as a release and replaces
   `components\bin`, `SAPHO`, `Macros` and `Header` of AURORA together. It
   writes nothing that git tracks. To go back to the released YANC one day:
   `node components/Scripts/download-yanc.cts --force` in `C:\Dev\aurora`.

3. Start AURORA from its sources: `npm start` in `C:\Dev\aurora`. The next
   `npm start` keeps the YANC of step 2.

### 4.4 The program

The program is `projects/de2_115_sapho/software/hits_menu.cpp`, in C++. SAPHO
runs it directly; there is no operating system. Read it whole: it is short. The
parts that matter:

```cpp
#pragma yanc nuioou 9          // 9 output ports: port p is register p of hits
#pragma yanc nuioin 3          // 3 input ports: ID, CAPS, STATUS
#pragma yanc nubits 16         // a 16-bit processor, the width of the bus
#define YANC_LINK_SYNC 0       // keyboard and screen on another clock (25 MHz)
#include <iostream>
```

- `out(p, x)` writes register `p` of `hits`; `in(p)` reads it. Only `ID` (0),
  `CAPS` (1) and `STATUS` (2) can be read, so the program keeps a copy of every
  value it wrote, and `write_all()` writes them all when it starts.
- `cout <<` writes on the VGA screen and `cin >>` reads a line from the keyboard,
  with echo and Backspace.
- `show()` draws the menu; `main()` loops: show, read an option, ask for the
  value with `read_int` or `read_uint`, write it.
- The orbit length (register 6) can only be written with the simulation stopped,
  so option 4 stops, writes and runs again.

### 4.5 Generate the processor (the `.v` of SAPHO)

YANC turns the program into the Verilog of a processor made for it. In Git Bash:

    cd /c/Dev/hits/projects/de2_115_sapho
    YANC=/c/Dev/yanc sh software/build.sh

It prints `stack depths from the program: SDEPTH 8, NDSTAC 8` and
`built: hits_menu.v, its memories and sapho/, with yanc <commit>`, and writes:

| File | What |
|---|---|
| `hits_menu.v` | the processor, the top module `hits_menu` |
| `hits_menu_inst.mif`, `hits_menu_data.mif` | its instruction and data memories |
| `pc_hits_menu_mem.txt` | the map from instruction to source line, for simulation |
| `sapho/*.v` | the blocks of SAPHO, copied from YANC (processor core, ALU, keyboard, screen) |
| `hits_menu.yanc` | the YANC commit that generated them |

Then `git status`. If you did not change the program and your YANC is at the
commit `hits_menu.yanc` names, nothing changed: the files of the repository are
exactly what YANC generates. If YANC is newer, `hits_menu.yanc` and maybe
`sapho/` change: write that down for the report.

`build.sh` refuses a YANC with uncommitted changes, and stops when YANC did not
size the stacks from the program.

**In AURORA (optional, to look at it):** the same program can be opened in
AURORA. Create a project (*Novo Projeto*), open the *Hub de Processadores*,
create a processor named `hits_menu` with the language C++, replace its source
with the contents of `hits_menu.cpp`, and compile. The TCMM terminal shows the
compilation of the C++, TASM the generation of the Verilog, and the processor's
output folder `hits_menu/hits_menu/` gets `hits_menu.v` and the memories. The
AURORA manual (chapters 4, 6 and 12) has the details. The files the board uses
are the ones `build.sh` writes; AURORA is for reading, compiling and simulating
the program on its own. Whether AURORA's `hits_menu.v` is identical to the
repository's was not checked.

### 4.6 Simulate the whole system

The simulation runs the processor, `hits`, the keyboard, the screen and the
displays together, with a simulated keyboard that types the options. It needs
Icarus Verilog on the `PATH` (AURORA brings one in
`C:\Dev\aurora\components\Packages\msys\mingw64\bin`). In Git Bash:

    cd /c/Dev/hits/projects/de2_115_sapho
    sh sim/run.sh +screen

It takes about a minute and must end with `hits_menu: ok`. `+screen` prints the
screen at the end; it is the screen you will see on the monitor (section 6).

### 4.7 Compile with Quartus

Open `C:\Dev\hits\projects\de2_115_sapho\hits_de2_115.qpf` in Quartus 24.1 and
run *Processing > Start Compilation*, or in a terminal in that folder:

    quartus_sh --flow compile hits_de2_115

It takes a few minutes. Check in the *Compilation Report*: no errors, no
critical warnings, and in *Timing Analyzer* every slack positive. The *Fitter >
Summary* should say about 7656 logic elements (7%). The bitstream is
`output_files\hits_de2_115.sof`.

## 5. Preparing the board

1. With the board off: the VGA cable to the monitor, the PS/2 keyboard to the PS/2
   port, the USB cable to the *USB Blaster* port and to the computer, the 12 V
   adapter.
2. The switch SW19 (RUN/PROG) on **RUN** (DE2-115 User Manual, section 4.1).
3. All the slide switches SW0 to SW17 down.
4. Turn the board on with its power button. The board's own demo may start: that
   is fine, the next step replaces it.
5. Program the FPGA: in Quartus, *Tools > Programmer*. *Hardware Setup* =
   *USB-Blaster*, *Mode* = *JTAG*, *Add File* = the `.sof` of section 3 or 4.7,
   tick *Program/Configure*, *Start*. The bar must reach 100% (Successful). If
   *Hardware Setup* shows no USB-Blaster, install the driver from
   `<quartus folder>\drivers\usb-blaster` in the Windows Device Manager.

Programming over JTAG does not survive a power cycle: after turning the board off,
program it again.

## 6. What must appear

**The LEDs (green, LEDG0 to LEDG3):** LEDG0 blinks about once a second (the 40 MHz
clock is running), LEDG1 is on (the PLL locked), LEDG3 is off (no reset). LEDG2
flickers or stays on or off: it only keeps a signal from being optimized away.

**The monitor:** a black screen with white text. After a moment (the screen
clears first), exactly this:

```
HITS on SAPHO  ID 4854  CAPS 1000  running
 1 occupancy  65530 / 65536
 2 pedestal   146 ADC
 3 mode       2 (bit 0: a hit on every crossing, bit 1: the mask)
 4 orbit      3564 crossings
 7 run / stop
option?
```

with a blinking underline cursor after `option?`. Options 5 and 6 are missing on
purpose: they exist only in a build with jitter, and `CAPS 1000` says this build
has none.

**The displays (HEX7 to HEX0):** with all switches down, `0` on HEX7 and dashes on
HEX4 to HEX0 (switch value 0 is not a register: see section 8).

If any of this differs, stop and report (section 11).

## 7. Using the menu

Type the number of an option and press Enter; then type the value and press Enter.
What you type shows on the screen, and Backspace erases. After each change, the
menu is drawn again with the new value.

| Option | Asks | Range | What it does in `hits` |
|---|---|---|---|
| 1 occupancy | the hit probability, in 1/65536 | 0 to 65535 | per filled crossing |
| 2 pedestal | the baseline of the ADC, in ADC counts | -4096 to 4095 | shifts every sample |
| 3 mode | bit 0: a hit on every crossing (no draw); bit 1: the bunch-train mask | 0 to 3 | |
| 4 orbit | crossings per orbit | 1 to 3564 | stops, writes, runs again |
| 7 run / stop | nothing | | toggles RUN; stopped holds `hits` in reset |

A value out of range gives `out of range` and asks again. A letter where a value
goes counts as out of range; a letter where an option goes gives `options 1 to 7`.
Two known limits of the 16-bit word: a number above 65535 wraps (70000 becomes
4464), and a negative number for the occupancy wraps too (-5 becomes 65531).

KEY0 (push-button KEY[0]) resets everything: the menu starts again with
the values of section 6.

## 8. The displays

The registers of `hits` cannot be read back, so the displays show the last value
that reached `hits` for each one, in decimal, read on the bus itself.

| SW17 | SW3 to SW0 (binary) | HEX7 | HEX5 | HEX4 to HEX0 |
|---|---|---|---|---|
| down | 2 to 8 | the register number | `-` if negative | the value |
| down | anything else | the number | | dashes |
| up | anything | the hits per second, on all eight digits, updated every second | | |

SW3 to SW0 is binary: 2 = SW1 up; 3 = SW1 and SW0; 4 = SW2; 5 = SW2 and SW0; 6 =
SW2 and SW1; 7 = SW2, SW1 and SW0; 8 = SW3. The registers: 2 RUN (1 running, 0
stopped), 3 occupancy, 4 pedestal, 5 mode, 6 orbit, 7 phase0, 8 sigma.

## 9. The test

Write down what you see at each step, with a photo of the screen and of the
displays where the step says so.

The expected hit rates come from the bunch-train mask: 2340 filled crossings in
the 3564 of an orbit (2016 in the first 3000). A second holds 11 223 orbits and a
third, so the rate moves by up to about a thousand from one second to the next,
and by a few thousand when there is a draw.

| Mode | Occupancy | Orbit | Hits per second |
|---|---|---|---|
| 2 (mask) | 65530 | 3564 | about 26 260 000 |
| 2 (mask) | 20000 | 3564 | about 8 015 000 |
| 1 (every crossing, no mask) | any | any | exactly 40 000 000 |
| 3 (every filled crossing) | any | 3564 | about 26 263 000 |
| 0 (draw, no mask) | 20000 | any | about 12 207 000 |
| 2 (mask) | 655 | 3000 | about 269 000 |
| stopped, or occupancy 0 | | | 0 |

1. **Start.** Program the board (section 5). Check the LEDs and the screen of
   section 6. *Photo of the screen.*
2. **The registers.** SW17 down. SW3 to SW0 = 3, 4, 5, 6 and 2 in turn: the
   displays show `3  65530`, `4    146`, `5      2`, `6   3564`, `2      1`.
   *Photo of one of them.*
3. **The rate.** SW17 up: about 26 260 000. *Photo.*
4. **Occupancy.** Option 1, value 20000. The menu shows `1 occupancy  20000 / 65536`.
   SW17 down with SW = 3: `3  20000`. SW17 up: about 8 015 000.
5. **Mode.** Option 3 with 1: 40 000 000 exactly. Then option 3 with 3: about
   26 263 000. Then option 3 with 0: about 12 207 000. Then option 3 with 2 again.
6. **Negative pedestal.** Option 2, value -5. The menu shows `2 pedestal   -5 ADC`;
   SW17 down, SW = 4: `4 -    5`.
7. **Out of range.** Option 4, value 9999: `out of range`, asked again; SW = 6 still
   shows 3564. Then 3000: the menu shows `4 orbit      3000 crossings`, SW = 6
   shows `6   3000`, and the screen still says `running`.
8. **Stop and run.** Option 7: `stopped` on the first line, SW = 2 shows
   `2      0`, SW17 up shows 0. Option 7 again: `running`, SW = 2 shows 1.
9. **Signal Tap.** Option 2 with 146 and option 1 with 655, then section 10. With
   SW17 up, about 269 000.
10. **Pedestal on the waveform.** Option 2 with 500 and capture again (section 10):
    the whole ADC trace moves up by 354.
11. **Reset.** Press KEY0: the screen clears and shows the menu of section 6
    again, and SW = 3, 4, 6 show 65530, 146, 3564.

## 10. Signal Tap: the waveforms

Signal Tap is a logic analyzer inside the FPGA: it records signals of the design
while it runs and sends them to Quartus over the same USB cable. This design
records the outputs of `hits` on the 40 MHz clock, 8192 samples (about 200 us,
more than two orbits), starting just before the first hit after you press Run.

| Signal | What it is | Shown as |
|---|---|---|
| `hits_out` | 1 on a crossing with a hit (the trigger) | a wire |
| `bt_mask_out` | 1 on a filled crossing of the bunch-train mask | a wire |
| `energy_out[12..0]` | the energy drawn for the hit | line chart, unsigned |
| `shaper_clip[11..0]` | **the ADC samples**: pedestal + pulse + noise, 0 to 4095 | line chart, unsigned |
| `noise_out[16..0]` | the noise added | line chart, signed |
| `shaper_out[29..0]` | the shaped pulse before the ADC | line chart, signed |

1. With the board programmed (section 5) and the Quartus project open
   (`hits_de2_115.qpf` in `C:\Dev\hits\projects\de2_115_sapho`), *Tools > Signal
   Tap Logic Analyzer*. It opens `signaltap/stp1.stp` of the project.
2. In the *JTAG Chain Configuration* panel (top right): *Hardware* = *USB-Blaster*,
   *Device* = the EP4CE115. In *SOF Manager*, the `...` button: choose the `.sof`
   you programmed. The status must say the instance is ready, not that the design
   differs. Do **not** program again from here unless the status asks for it.
3. *Processing > Run Analysis* (the single run, not *Autorun*). Since the menu is
   running, a hit comes at once and the capture fills: the status goes from
   *Waiting for trigger* to *Acquiring* to done in a fraction of a second.
4. The *Data* tab shows the waveforms. Click on the waveform area to zoom in,
   right-click to zoom out; to see all 8192 samples, zoom out until they fit. If a
   bus shows numbers instead of a curve, right-click on its name, *Bus Display
   Format*, *Unsigned Line Chart* (or *Signed Line Chart* for `noise_out` and
   `shaper_out`).
5. What to look for with pedestal 146 and occupancy 655:
   - `shaper_clip` sits near 146 with a small noise (a few ADC counts) and, after
     each hit, a pulse up and back down to the pedestal;
   - `hits_out` pulses only where `bt_mask_out` is 1 (the gaps of the mask have
     no hits);
   - `energy_out` changes at each hit.
   *Screenshot of the whole capture and of one pulse zoomed in.*
6. Save the capture: *File > Export*, format `.csv`, name it
   `capture_ped146_occ655.csv`. For step 10 of section 9, the same with
   `capture_ped500_occ655.csv`.

If the status says the design does not match, the `.sof` in the *SOF Manager* is
not the one programmed, or the repository is not at the commit of the `.sof`
(section 3, step 1).

## 11. The report

Send to whoever asked you for the test, and post it on the issue
[#14](https://github.com/nipscernlab/hits/issues/14) of `hits`:

1. the path (A or B), the commit (`git log -1 --oneline` in `C:\Dev\hits`), the
   version of Quartus, and for path B the commit of YANC (`hits_menu.yanc`) and
   the output of `git status` after `build.sh`;
2. for each step of section 9: what you saw, and whether it matched; the photos
   the steps ask for;
3. the screenshots and the two `.csv` of section 10;
4. anything that did not match, with what you did just before.

## 12. When something goes wrong

- **The monitor says "no signal" or "out of range":** check the VGA cable and that
  the monitor takes 640 x 480 at 60 Hz. LEDG0 must be blinking; if it is not, the
  FPGA is not programmed (section 5).
- **The screen shows the menu, but typing does nothing:** the keyboard may not
  speak PS/2 (a USB keyboard on an adapter); try another. Unplugging and plugging
  a PS/2 keyboard with the board on can confuse it: plug it, then press KEY0.
- **Wrong characters on the screen, or a key typed twice or lost:** this is
  exactly what the fix yanc#64 is about. Report it with a photo, and the commit of
  YANC in `hits_menu.yanc`.
- **The displays show dashes:** SW3 to SW0 is not between 2 and 8 (section 8).
- **The rate is 0:** the simulation is stopped (`stopped` on the screen, option 7),
  or the occupancy is 0.
- **Programmer: "No hardware":** the USB Blaster driver (section 5, step 5), or the
  cable on the wrong USB port of the board (it must be the one marked *USB
  Blaster*).
- **`build.sh` says "no compilers":** run `make` in the YANC folder (section 4.2).
- **`build.sh` says YANC "has uncommitted changes":** something changed in your
  YANC clone; `git status` there. Do not commit or reset anything in it without
  asking the group.
- **`sim/run.sh` says `iverilog: command not found`:** put Icarus on the `PATH`
  (section 4.6).
