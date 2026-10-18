# Reconstruction techniques

The reconstruction techniques are not part of the simulator. They are the
circuits that HITS exists to test: each one takes the ADC samples and estimates
the energy. They live in `reconstruction/`, one folder each, and the wrapper
`reconstruction/hits_reco.v` puts the simulator and a technique
together.

Two techniques exist. `pzc/` is a pole-zero cancellation with pedestal tracking;
`baseline_estimator/` is an adaptive baseline estimator, selected by the macro
`USE_BASELINE_EST`. There is no default technique yet: with no macro the wrapper
builds the pole-zero cancellation.

Both drive the same output, `pzc_out`, on different scales: the pole-zero
cancellation carries a gain of 455, the estimator gives ADC counts. The
parameters of the estimator are calibrated for the F34 shaper only; with another
shaper it compiles and gives wrong results without warning.

In simulation, `projects/hits_reco/aurora/` runs the simulator followed by
a technique. Its file `choices.v` holds the choices (the technique and, for
that project, the shaper) as `` `define `` lines, compiled before every other
file, because Icarus applies a `` `define `` only to the files after it. The
builds `pzc`, `pzc_legacy`, `pzc_csa_cr4rc` and `est` of the regression run this
project. How to add a technique is in
[`reconstruction/README.md`](https://github.com/nipscernlab/hits/blob/main/reconstruction/README.md).

The wrapper does not pass `PHASE0` and `SIGMA_PS` on, so in these builds the
simulator runs without a phase.
