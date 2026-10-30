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
 3 mode       2 (1: every filled crossing, 2: mask)
 4 orbit      3000 crossings
 7 run / stop
option?
```

The screen at the end of the simulation. Options 5 (`phase0`) and 6 (`sigma`)
show only when `CAPS` says the build has the phase of the pulse.

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
only, so SAPHO is built without a float unit, multiplier or divider.

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
`hits` and the text on the screen. It takes about a minute (9.7 ms of simulated
time; the bench runs the PS/2 clock at 250 kHz instead of the 10 to 17 kHz of a
keyboard). It is not in the regression of the repository: CI has no YANC.

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
4-2 (push-buttons), 4-3 (LEDs), 4-19 (PS/2) and 4-16 (the ADV7123 video DAC). KEY
and LEDG are 2.5 V, the default of JP7. The screen goes to the DAC as white on
black, with `VGA_CLK = ~clk25` so the DAC latches each pixel in its middle: the
mapping of `myVGAText`, checked on this board in YANC.

## Size and speed

Quartus Prime Lite 24.1, EP4CE115F29C7, this project, 2026-10-29:

| Block | Logic elements | Registers |
|---|---|---|
| `hits` | 4038 | 1727 |
| SAPHO `hits_menu` | 7668 | 5665 |
| of which the data stack of SAPHO | 4925 | 4103 |
| of which the call stack of SAPHO | 1757 | 1415 |
| `myVGAText` | 371 | 151 |
| `myKeyPS2` | 286 | 99 |
| `hits_sapho` | 6 | 0 |
| Total | 12 391 (11%) | 7671 |

Memory 121 732 bits (3%), 12 multipliers of 9 bits (2%), 1 PLL of 4. Fmax in
the worst corner (Slow 1200mV 85C): **51.6 MHz** for the 40 MHz clock (5.6 ns of
slack) and 79.2 MHz for the 25 MHz one. Most of SAPHO is its two stacks, kept in
flip-flops: 128 words of 32 bits of data and 128 return addresses.

## Still to do

The test on the board, with Signal Tap against the simulation: step 4 of issue #14.
