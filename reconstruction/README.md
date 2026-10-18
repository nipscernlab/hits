# Reconstruction techniques under test

**Nothing in this folder is part of the HITS simulator.** The simulator is
`rtl/` and ends at the digitized ADC sample `shaper_clip`. What lives here are
the energy-reconstruction techniques that use that sample train to be tested,
one subfolder per technique, plus the wrapper that joins the simulator to the
technique under test.

```
hits_reco.v    wrapper: simulator core (rtl/) + ONE technique, chosen by macro
pzc/                       pole-zero cancellation + pedestal tracking (built when no macro is set)
  pzc_ped_track.v
baseline_estimator/        adaptive baseline estimator (USE_BASELINE_EST)
  baseline_estimator.v
  anchor_generator.v         anchors derived from the bunch-train mask
  recip.mem                reciprocal ROM (depends on the mask)
```

## The wrapper

`hits_reco.v` instantiates the simulator core and exactly one
technique, selected at synthesis time by a macro (see its header). Whatever the
technique, its result goes out on `pzc_out` and its baseline estimate on
`pedestal_out`, so the testbench and the board top do not change between
techniques.

The module keeps the name `hits_reco` even though it no longer
holds only the PZC: the board top (`projects/hits_reco/quartus/de10_nano_soc_ghrd.v`)
instantiates it by that name, and the SignalTap assignments in the `.qsf` refer
to its hierarchy (`hits_reco:sim|...`).

⚠️ The techniques do not share an output scale. The PZC delivers a gain of
`PZC_M_FACTOR+1` = 455, the estimator delivers ADC counts. Divide before
comparing them.

## Adding a technique

1. **Own folder, no changes to `rtl/`.** Create `reconstruction/<technique>/` with
   its `.v` files and any memory files it loads. If the technique needs
   something from the simulator that is not on the core ports, stop and discuss
   it: the simulator changes only by its own review and with its golden intact.
   Module names must be unique across all subfolders, because every flow
   compiles them together.

2. **Wire it into the wrapper under a macro of its own**, as one more branch of
   the `` `ifdef USE_BASELINE_EST `` / `` `else `` chain (`` `elsif USE_<TECHNIQUE> ``).
   Drive `pzc_out` (sign-extend to `PZC_OUT_BITS` if narrower) and
   `pedestal_out`, add its parameters with a prefix of their own (as `EST_*`
   for the estimator), and state its output scale in the header. The build
   with no macro must stay the PZC (its golden is `pzc`); which technique, if
   any, becomes the default is still to be decided.

3. **Icarus** needs nothing: the README commands compile
   `../../../reconstruction/*.v ../../../reconstruction/*/*.v`.

4. **AURORA** (`projects/hits_reco/aurora/hits_reco.spf`) compiles only the files it
   lists in `synthesizableFiles`: add the new `.v` files there.

5. **Quartus** (`projects/hits_reco/quartus/DE10_NANO_SoC_GHRD.qsf`): add
   `set_global_assignment -name SEARCH_PATH ../../../reconstruction/<technique>`.
   Quartus then finds both the modules and the memory files by name in that
   folder; this is how the estimator and its `recip.mem` are found (checked
   with Quartus Prime Lite 24.1, 2026-09-25).

6. **Memory files.** Icarus resolves a relative `$readmemh` name against the
   cwd of the simulation (`projects/hits_reco/aurora/`), not against the folder of the
   `.v`. The testbench must therefore pass the full relative path as a
   parameter, as it does for the estimator
   (`` .EST_RECIP_MEM({`EST_DIR, "/recip.mem"}) ``); otherwise the read fails and
   the simulation goes on with X. Pass it through a `` `define ``, not a new
   `localparam`: a localparam of the testbench enters the VCD and would break
   every existing golden.

7. **Choice and regression.** Add the macro to `projects/hits_reco/aurora/choices.v`
   (commented), add the build to `BUILDS` in `verification/regress.py`, group
   `reconstruction`, and create its golden from a clean run with
   `python verification/regress.py --gera <build>`, which refuses to overwrite
   an existing golden. Add the row to the golden table of the main README. The
   goldens of the other builds, above all the `core` ones, must stay
   bit-identical: if one of those changes, the new technique touched the
   simulator.
