# Reconstruction techniques of the board with the ARM

**Nothing in this folder is part of the HITS simulator.** The simulator is
`rtl/` and ends at the digitized ADC sample `shaper_clip`. These are the
energy-reconstruction techniques that the board with the ARM
(`projects/de10_nano_arm/`) builds after the simulator, plus the wrapper
that joins the two. They live inside the board project because that project is
their only user; until 2026-10-21 they were `reconstruction/` at the root of the
repository.

```
hits_reco.v    wrapper: simulator core (rtl/) + ONE technique, chosen by macro
pzc/                       pole-zero cancellation + pedestal tracking (built when no macro is set)
  pzc_ped_track.v
baseline_estimator/        adaptive baseline estimator (USE_BASELINE_EST)
  baseline_estimator.v
  anchor_generator.v         anchors derived from the bunch-train mask
  recip.mem                reciprocal ROM (depends on the mask)
```

⚠️ **They are no longer simulated.** The testbench (`projects/hits_reco/aurora/`)
and the four builds of the regression that checked them (`pzc`, `pzc_legacy`,
`pzc_csa_cr4rc`, `est`) left the repository on 2026-10-21. To recover them:

```
git checkout last-with-reconstruction -- projects/hits_reco/aurora verification/hits_reco_tb_golden_*.vcd
```

The testbench there compiles `../../../reconstruction/`; point it at this folder.

## The wrapper

`hits_reco.v` instantiates the simulator core and exactly one technique,
selected at synthesis time by a macro (see its header). Whatever the technique,
its result goes out on `pzc_out` and its baseline estimate on `pedestal_out`,
so the board top does not change between techniques.

The module keeps the name `hits_reco` even though it no longer holds only the
PZC: the board top (`de10_nano_soc_ghrd.v`) instantiates it by that name, and
the SignalTap assignments in the `.qsf` and in `stp1.stp` refer to its
hierarchy (`hits_reco:sim|...`).

⚠️ The techniques do not share an output scale. The PZC delivers a gain of
`PZC_M_FACTOR+1` = 455, the estimator delivers ADC counts. Divide before
comparing them.

## Quartus

`DE10_NANO_SoC_GHRD.qsf` lists the files of this folder one by one, with their
paths (`reconstruction/hits_reco.v` and `reconstruction/<technique>/<file>`, as
`VERILOG_FILE`; the estimator's `recip.mem` also as `MIF_FILE`), and has one
`SEARCH_PATH` per technique (`reconstruction/<technique>`): a memory read by a
bare name, as the estimator's `$readmemh("recip.mem")`, is resolved through it
(checked with Quartus Prime Lite 24.1, 2026-09-25). A new technique gets its own
folder here, its files and its `SEARCH_PATH` in the `.qsf`, and a branch of its own in the wrapper's
`` `ifdef USE_BASELINE_EST `` / `` `else `` chain, under a macro of its own.
