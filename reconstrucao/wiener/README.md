# Wiener filter (`reconstrucao/wiener/`)

`wiener_filter.v` is a 9-tap FIR that estimates the energy deposited in each
bunch crossing from the digitized ADC sample `shaper_clip`. Unlike the other
techniques in `reconstrucao/`, it does not replace the one chosen in the
wrapper: it runs **in parallel** with it and drives a port of its own,
`wiener_out`. `pzc_out` and `pedestal_out` keep the PZC (or the estimator).

```
shaper_clip ──┬── pzc_ped_track / estimador_baseline ── pzc_out, pedestal_out
              └── wiener_filter ─────────────────────── wiener_out
```

The input is the raw `shaper_clip`: no pedestal is subtracted (see
[Baseline](#baseline)).

## Coefficients

| tap | real | Q12 (`round(c * 2^12)`) |
|---|---|---|
| C0, x(n) | +0.05254051 | 215 |
| C1 | -0.14766654 | -605 |
| C2 | +0.38728372 | 1586 |
| C3 | -0.91251163 | -3738 |
| C4 | +1.68667686 | 6909 |
| C5 | -0.77512366 | -3175 |
| C6 | +0.35378128 | 1449 |
| C7 | -0.16148019 | -661 |
| C8, x(n-8) | +0.07330114 | 300 |

C0 multiplies the newest sample, as `c(1)` in MATLAB's `filter(c, 1, x)`. The
sum of the coefficients, the DC gain, is 0.557.

**The coefficients belong to the F34 shaper: build with `USE_SHAPER_F34`.**
How they were derived is not recorded here. They were identified by solving the
Wiener-Hopf equations (9 taps, target `event_bt`) on a simulation of each
shaper: for F34 the optimum comes out as
`[0.068 -0.154 0.374 -0.778 1.683 -0.862 0.356 -0.107 0.051]`, close to the set
above, while for the legacy and the CSA + CR-4RC shapers it has a different
shape. With another shaper the filter compiles and runs, and the output is
meaningless.

## The module

| signal | width |
|---|---|
| `in` | 13 bits signed (`{1'd0, shaper_clip}`) |
| products `p0..p8` | 29 bits |
| accumulator `acc` | 33 bits (29 + 4 of growth for a sum of 9) |
| `out` | 21 bits (33 - Q, Q = 12) |

Three register stages: input delay line, products, output. **Latency: 3
cycles**, `out(n+3) = y(n)`. Registering the products before the sum leaves
timing margin at 40 MHz. The coefficients are not symmetric, so the pre-add of
a linear-phase FIR does not apply: 9 multipliers.

The output is `acc >>> 12`, which truncates toward minus infinity. The
bit-exact model is therefore `floor(filter(round(c * 2^12), 1, x) / 2^12)`.

## Wiring

1. **Macro** `USE_WIENER`, together with `USE_SHAPER_F34`: in
   `projects/aurora/simulacao.v`, or `-DUSE_WIENER -DUSE_SHAPER_F34` on the
   command line. Commit `simulacao.v` with both lines commented.

2. **Wrapper** (`reconstrucao/FPGA_Simulator_v1_PZC.v`): port `wiener_out`
   (`WIENER_OUT_BITS` = 21), instance under its own `` `ifdef USE_WIENER ``,
   outside the technique-selection chain. Without the macro, `wiener_out` is 0.

3. **Testbench** (`projects/aurora/sim_pulsos_tb.v`): the `wiener_out` wire, its
   connection and its column in `sim_pulsos_tb2.txt` exist only under
   `USE_WIENER`. A new wire in the testbench scope enters the VCD and would break
   the goldens of every other build.

To compare `wiener_out` with `event_bt`, delay `event_bt` by **14 samples**: 11
between the shaper input and the filter output (measured for F34), plus the 3
of latency.

## Baseline

The filter sees the raw `shaper_clip`, so its output carries 0.557 times the
baseline of the ADC sample, and that baseline **moves with occupancy**. In the
default run (F34, occupancy 25 -> 80, 10 orbits):

| occupancy | `shaper_clip` in the gaps (median) | samples clipped at 0 |
|---|---|---|
| 25 | 97 | 0% |
| 80 | 0 | 34% |

At occupancy 80 the baseline goes below zero and the ADC clips a third of the
samples. What is clipped is lost, and no linear filter brings it back.

A fixed pedestal (92, the median over the whole run) was subtracted at the input
in an earlier version and was removed: no constant fits both occupancies. A
tracked baseline, feeding the filter with the output of `estimador_baseline`
(calibrated for F34), is the natural next step and has not been tried.

<!-- ## Verification

- **Impulse:** with `Q = 0`, a one-sample impulse of height 1 returns the nine integer
  coefficients in order.
- **Bit-exact:** `analysis/wiener/wiener_test.m` compares `wiener_out`, shifted
  by 3 samples, with the integer model above. It prints
  `diferencas FPGA x modelo inteiro: 0`.
- **Regression:** with the macros commented and the committed testbench,
  `verification/regress.py` passes all 13 builds bit-identical (checked
  2026-09-30). There is no golden for the `USE_WIENER` build. -->

<!-- ## Running

```sh
./run_project/run.sh                            # or Run in run_project/launcher.py
./run_project/run.sh +OCC_INIT=25 +OCC_STEP=80
```

Output in `projects/aurora/`: `sim_pulsos_tb2.txt` (column `wiener_out`) and
`sim_pulsos_tb.vcd`. -->

## Open

- **AURORA:** add `wiener_filter.v` to `synthesizableFiles` in
  `projects/aurora/sim_pulsos.spf`.
- **Quartus:** `set_global_assignment -name SEARCH_PATH ../../reconstrucao/wiener`
  in the `.qsf`; connect `wiener_out` in `de10_nano_soc_ghrd.v` (unconnected
  today); check that the multipliers map to DSP blocks and that timing closes at
  40 MHz.
- **Regression:** a `USE_WIENER` build in `BUILDS` of `regress.py`, with its own
  golden.
- **Baseline:** see above.
