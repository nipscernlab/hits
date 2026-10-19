# Reproducing the papers

HITS changed after the papers that describe it. Each paper corresponds to a
build of the regression, whose golden waveform fixes its behavior, and the
submitted paper also to a tag of the repository.

## The submitted paper (IEEE Sensors Journal, 2026)

F. Luna et al., *Real-Time FPGA-Based Pulse Simulator for Calorimeter Readout
Electronics in Nuclear Instrumentation*, submitted to the IEEE Sensors Journal
(manuscript Sensors-114519-2026). It used the CSA + CR-4RC shaper without its
pipeline, the round-robin generator, the noise tables with σ = 8 ADC counts and
a truncating ADC.

Its behavior on the current code is the `paper` build: `RNG_TYPE` =
`"round_robin"` with the macros `USE_SHAPER_CSA_CR4RC`, `USE_NOISE_SIGMA8`,
`USE_ADC_FLOOR` and `USE_SHAPER_NO_PIPE`. Its testbench macro `USE_OCC_PAPER`
keeps the occupancies its golden was made with, 19.5% and then 62.5%.

```sh
python verification/regress.py paper
```

Its outputs are those of the code of the paper delayed by exactly one cycle,
because the testbench now releases the reset one clock edge later; this was
checked signal by signal. Its golden is frozen: the regression keeps the hash of
the file and fails if it changes.

The exact code of the paper, and its resource numbers (Vivado on a KCU116 board:
1987 LUTs, 2696 registers, 27 DSP, 0 block RAM), are the tag `paper-jsen-2026`.
The circuit changed since (the tables moved to block RAM, the round-robin bank
lost its multiplexer), so the same configuration gives another netlist today. To
work on the tag without touching `main`:

```sh
git worktree add ../hits-paper paper-jsen-2026
```

## The revised paper (in preparation)

The revision describes the current HITS and keeps only the pulse of the
submitted paper, the CSA + CR-4RC shaper. Its configuration is the `paper_r1`
build: `USE_SHAPER_CSA_CR4RC` and `USE_ENERGY_LORENZETTI` on top of the defaults
(xoshiro, segmented energy, Gaussian noise with σ = 4, rounding ADC, the
pipelined shaper).

```sh
python verification/regress.py paper_r1
```

Its golden is not frozen yet; it will be when the numbers of the revision are
final. The DE10-Nano example of [Examples](examples.md#synthesis-in-quartus-the-de10-nano)
is this build on the board.
