# HITS on SAPHO, with a keyboard and a screen (DE2-115)

HITS configured from a menu: a SAPHO processor runs a C++ program that shows the
configuration of the simulator on a VGA text screen and changes it from a PS/2
keyboard, through the configuration bus ([issue #14](https://github.com/nipscernlab/hits/issues/14)).
The board is the Terasic DE2-115 (Cyclone IV E), which has the VGA output and the
PS/2 input; the DE10-Nano has neither.

```
HITS on SAPHO  ID 4854  CAPS 1000  running
 1 occupancy  20000 / 65536
 2 pedestal   -5 ADC
 3 mode       2 (bit 0: a hit on every crossing, bit 1: the mask)
 4 orbit      3000 crossings
 7 run / stop
option?
```

The screen in the simulation, after the first options. Options 5 (`phase0`) and 6 (`sigma`)
show, and are taken, only when `CAPS` says the build has the jitter (bit 3), the only
case where `PHASE0` and `SIGMA` act.

## How it is put together

| Block | Clock | Where |
|---|---|---|
| `hits`, the simulator with its configuration bus | 40 MHz | `rtl/hits.v` |
| `hits_sapho`, the adapter: port `p` of SAPHO is register `p` | 40 MHz | `rtl/hits/hits_sapho.v` |
| SAPHO with the program `hits_menu` | 40 MHz | `hits_menu.v`, generated from `software/hits_menu.cpp` |
| `myKeyPS2`, the PS/2 keyboard (ABNT2 layout), link 0 | 25 MHz | `sapho/`, from [YANC](https://github.com/nipscernlab/yanc) |
| `myVGAText`, the 80 x 30 VGA text screen, link 1 | 25 MHz | `sapho/`, from YANC |

Both clocks come from one PLL fed by the 50 MHz of the board. SAPHO and `hits`
share the 40 MHz clock, so the bus needs no synchronizer. The keyboard
and the screen run on the 25 MHz pixel clock; the program reaches them through the
links that cross clocks (`#define YANC_LINK_SYNC 0`). The program uses integers
only, so SAPHO is built without a float unit, multiplier or divider, and its word
is 16 bits, the width of the bus: occupancy and sigma (0 to 65535) are `unsigned`,
the other values `int`.

A known limit of the 16-bit word: `cin >>` of YANC does not catch a number too
big for the word, it wraps. A value typed above 65535 is taken modulo 65536
(70000 gives 4464), and one out of the `int` range (-32768 to 32767) may wrap
into the accepted range instead of giving "out of range".

The registers of the bus are write-only except `ID`, `CAPS` and `STATUS`
([Configuring HITS at run time](../../docs/guide/configuring.md)). The program
keeps a copy of each scalar, writes them all when it starts, so the screen and
`hits` agree whatever the values at power-up, and writes `ORBIT_LEN` with the
simulation stopped, as the protocol asks. Loading the vectors (mask, spectrum,
noise) from the menu is not there yet.

## Files

| File | What |
|---|---|
| `software/hits_menu.cpp` | the program |
| `software/build.sh` | builds it with YANC and writes the four files below |
| `hits_menu.v`, `hits_menu_data.mif`, `hits_menu_inst.mif`, `pc_hits_menu_mem.txt` | the processor and its memories: **generated**, never edited by hand |
| `sapho/` | the blocks of SAPHO the processor and the board use (`processor.v`, `core.v`, `ula.v`, `addr_dec.v`, `instr_dec.v`, `myKeyPS2.v`, `myVGAText.v`), copied from YANC by `build.sh`: never edited here |
| `hits_menu.yanc` | the YANC commit that generated them |
| `sim/hits_menu_tb.v`, `sim/run.sh` | the simulation of the whole system |
| `top_hits_de2_115.v`, `pll_de2_115.v` | the top of the board and its PLL (50 MHz to 40 and 25 MHz) |
| `hex_debug.v` | what reached `hits`, on the 7-segment displays |
| `signaltap/make_stp.py`, `signaltap/stp1.stp` | the Signal Tap: the script writes the `.stp` |
| `hits_de2_115.qpf`, `.qsf`, `.sdc` | the Quartus project: sources, pins, timing |

## Building and simulating

Changing the program needs a clone of YANC with its compilers built
(`Scripts/regress.sh` leaves them in `.smoke/bin`), given by `YANC` (default
`c:/nipscern/yanc`). The simulation needs only Icarus Verilog. From this folder:

    sh software/build.sh          # after changing hits_menu.cpp
    sh sim/run.sh                 # ends with "hits_menu: ok"
    sh sim/run.sh +screen         # also prints the screen at the end

The simulation types on the keyboard the options and values of the menu (the
occupancy, a negative pedestal, an orbit out of range and then a valid one, stop,
a letter where a number goes, run) and checks, after each, the registers inside
`hits` and the text on the screen; then what the 7-segment displays show for each
register and for the hit count (over 4000 cycles instead of 1 s), the occupancy at
65535, options 5 and 6 refused (this build has no phase), and the reset, after which
the program writes its starting values again. It takes about a minute (15 ms of
simulated time; the bench runs the PS/2 clock at 250 kHz instead of the 10 to 17 kHz
of a keyboard). It needs only Icarus, since the generated files are in git, and CI
runs it on every pull request; `run.sh` exits with 1 when the bench fails.

`build.sh` refuses a clone of YANC with uncommitted changes, so `hits_menu.yanc`
names exactly what built the files, and fails, writing nothing, when the log of the
assembler does not say "stack depths from the program" (below).

## On the board

Compile with Quartus Prime Lite 24.1, from this folder (or open `hits_de2_115.qpf`):

    quartus_sh --flow compile hits_de2_115

The bitstream is `output_files/hits_de2_115.sof`, kept out of git. To load it
(DE2-115 User Manual, section 4.1): the RUN/PROG switch (SW19) on RUN, the USB
cable on the USB Blaster port, and the Quartus Programmer with the `.sof`:

    quartus_pgm -m jtag -o "p;output_files/hits_de2_115.sof"

The keyboard goes on the PS/2 port (alone, so on `PS2_CLK`/`PS2_DAT`) and the
monitor on the VGA port. The menu shows after the screen clears. KEY0 resets
the whole system, and the program writes the registers again when it starts.

| LED | Meaning |
|---|---|
| LEDG0 | blinks: the 40 MHz clock is running |
| LEDG1 | the PLL is locked |
| LEDG2 | parity of the ADC output (keeps the chain from being optimized away) |
| LEDG3 | reset active |

The pins are those of the DE2-115 User Manual (Terasic, v2.3): Table 4-5 (clock),
4-1 (slide switches), 4-2 (push-buttons), 4-3 (LEDs), 4-4 (7-segment displays),
4-19 (PS/2) and 4-16 (the ADV7123 video DAC). KEY, SW, LEDG and HEX0 to HEX3[1]
are 2.5 V, the default of JP7; HEX3[2] to HEX7 are 3.3 V, the default of JP6
(Table 4-11), except HEX7[6], always 3.3 V. The screen goes to the DAC as white on
black, with `VGA_CLK = ~clk25` so the DAC latches each pixel in its middle: the
mapping of `myVGAText`, checked on this board in YANC.

### The 7-segment displays

The registers of the bus are write-only, and the screen shows the copy the program
keeps. The displays show what reached `hits` (`hex_debug.v`, watching the bus at
the ports of `hits`), in decimal, chosen by the slide switches:

| SW17 | SW3..SW0 | HEX7 | HEX5 | HEX4..HEX0 |
|---|---|---|---|---|
| down | 2 to 8 | the register | the sign | the last value written to it |
| down | other | the number | | dashes |
| up | | the hits per second, on all eight digits, once a second | | |

`PEDESTAL` (4) and `PHASE0` (7) show with their sign; the others are unsigned.

### Signal Tap

`signaltap/stp1.stp` captures the outputs of `hits` on the 40 MHz clock: the ADC
samples (`shaper_clip`), the shaped pulse (`shaper_out`), the noise
(`noise_out`), the energy (`energy_out`), `hits_out` and `bt_mask_out`, 8192
samples (two orbits and a bit) from the first hit, with the buses as line charts.
Open it from Quartus (Tools, Signal Tap Logic Analyzer, with this project open),
choose the USB Blaster and the `.sof`, and run.

The `.stp` is written by `signaltap/make_stp.py`, not by the Signal Tap window, so
a change of signals or depth is a change of the script, reviewed like the rest.
Quartus compiles Signal Tap from assignments in the `.qsf`; after changing the
script:

    python signaltap/make_stp.py
    quartus_stp hits_de2_115 --stp_file signaltap/stp1.stp --enable

and compile again. Saving the `.stp` from the window rewrites it with the layout
of the window; commit that only if the script is changed to match.

### The test

The menu starts with occupancy 65530, pedestal 146, mode 2 (the mask), orbit 3564,
running. The mask has 2340 filled crossings in the 3564 of an orbit, so the
expected hit rates are, with the orbit of 3564:

| Mode | Occupancy | Hits per second |
|---|---|---|
| 2 (mask) | 65530 | about 26 260 000 |
| 2 (mask) | 20000 | about 8 015 000 (± a few thousand) |
| 0 (no mask) | 20000 | about 12 207 000 (± a few thousand) |
| 3 (every filled crossing) | any | about 26 262 000 |
| 1 (every crossing) | any | 40 000 000 |
| any, stopped or occupancy 0 | | 0 |

A gate of 1 s holds 11 223 orbits and a third, so even the modes with no draw move
by up to about a thousand from one second to the next.

1. Load the `.sof`. LEDG0 blinks, LEDG1 is on, LEDG3 is off; the menu shows
   `ID 4854  CAPS 1000  running`.
2. SW17 down, SW3..SW0 = 3, 4, 5, 6 and 2 in turn: the displays show 65530, 146,
   2, 3564 and 1, the values of the menu.
3. SW17 up: about 26 260 000 hits per second.
4. Option 1, 20000: SW = 3 shows 20000, and SW17 up about 8 015 000.
5. Option 3 (mode) with 1, then with 3, then with 0: 40 000 000, about
   26 262 000, about 12 207 000. Then mode 2 again.
6. Option 2, -5: SW = 4 shows `-5`.
7. Option 4, 9999: "out of range", the display of 6 unchanged; then 3000: SW = 6
   shows 3000.
8. Option 7: `stopped`, SW = 2 shows 0, the rate 0. Option 7 again: back to 1.
9. Signal Tap, with the menu back at pedestal 146: the ADC samples sit at the
   pedestal with pulses on top of it after each hit; with pedestal 500 the whole
   trace moves up by 354.
10. KEY0: the menu and the displays back at the values of step 2.

## Size and speed

Quartus Prime Lite 24.1, EP4CE115F29C7, this project, 2026-10-30:

| Block | Logic elements | Registers |
|---|---|---|
| `hits` | 4049 | 1732 |
| SAPHO `hits_menu`, 16 bits | 862 | 321 |
| of which the data stack of SAPHO (8 words) | 159 | 131 |
| of which the call stack of SAPHO (8 addresses) | 103 | 91 |
| `myVGAText` | 345 | 135 |
| `myKeyPS2` | 289 | 99 |
| `hits_sapho` | 5 | 0 |
| `hex_debug`, the displays | 541 | 267 |
| Signal Tap (with its JTAG hub) | 1569 | 1367 |
| Total | 7683 (7%) | 3960 |

Memory 721 678 bits (18%), of which 606 208 are Signal Tap (74 signals of 8192
samples); 12 multipliers of 9 bits (2%), 1 PLL of 4. Fmax in the worst corner
(Slow 1200mV 85C): **56.7 MHz** for the 40 MHz clock (7.3 ns of slack) and
80.8 MHz for the 25 MHz one; hold met everywhere. The only ports left
unconstrained are the JTAG pins of Signal Tap (`altera_reserved_*`). Without
Signal Tap and the displays, the system was 5552 logic elements.

YANC sizes the two stacks of SAPHO from the program (8 and 8 here). With 7 or
more labels on one line of the `.asm`, as a long `else if` chain gives, its
analysis gives up and leaves 128 each, which made SAPHO 7668 logic elements
([yanc#54](https://github.com/nipscernlab/yanc/issues/54)); the menu uses a
`switch`, which does not. `build.sh` stops when the log of the assembler does not
say "stack depths from the program", and the simulation fails if a stack overflows.

## Still to do

The test on the board (above): step 4 of issue #14. Then the captures of Signal Tap
against the simulation, sample by sample.
