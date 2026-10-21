# The regression

Every change to the RTL must keep the output of the testbenches identical, bit
for bit, to a stored waveform: the golden of each build. A build is a testbench
and a set of macros. One command runs every build from the root of the
repository:

```sh
python verification/regress.py            # exit 0: every build identical to its golden
python verification/regress.py sim est    # a subset
```

It needs Python 3 and Icarus Verilog (tested with Python 3.13 and Icarus Verilog
13.0). It also fails on any error of Icarus Verilog or `vvp`, including a memory file
that `$readmemb` could not open, even when the waveform matches: a golden taken
from a broken run would otherwise bless it.

## The builds

The builds come in three groups. The `core` builds compile only `rtl/` and the
testbench of the simulator alone, and stop at the ADC sample; the
`reconstruction` builds add a reconstruction technique. When only `reconstruction`
builds fail, the technique changed and the simulator is intact. The `bus` builds
test the configuration bus ([The configuration bus](config-bus.md)): the
testbench loads through the bus, into a `hits_bus` whose memories start with
every bit at 1, the configuration a `hits` next to it gets from its parameters,
checks every memory word and register, and compares the outputs of the two on
every cycle; any difference prints an error. Table 1 lists the builds.

Table 1: the builds of the regression and their goldens (in `verification/`).

| Build | Group | Macros | Golden |
|---|---|---|---|
| `sim` | core | none (xoshiro, F34, segmented energy, Gaussian σ = 4) | `hits_tb_golden.vcd` |
| `sim_legacy` | core | `USE_SHAPER_LEGACY` | `hits_tb_golden_legacy.vcd` |
| `sim_csa_cr4rc` | core | `USE_SHAPER_CSA_CR4RC` | `hits_tb_golden_csa_cr4rc.vcd` |
| `sim_noise_tables` | core | `USE_NOISE_TABLES` | `hits_tb_golden_noise_tables.vcd` |
| `sim_energy_tables` | core | `USE_ENERGY_TABLES` | `hits_tb_golden_energy_tables.vcd` |
| `sim_round_robin` | core | `USE_RNG_ROUND_ROBIN` | `hits_tb_golden_round_robin.vcd` |
| `sim_round_robin_legacy` | core | `USE_RNG_ROUND_ROBIN USE_SHAPER_LEGACY` | `hits_tb_golden_round_robin_legacy.vcd` |
| `paper` | core | `USE_RNG_ROUND_ROBIN USE_SHAPER_CSA_CR4RC USE_NOISE_SIGMA8 USE_ADC_FLOOR USE_SHAPER_NO_PIPE USE_OCC_PAPER` | `hits_tb_golden_paper.vcd` (frozen) |
| `paper_r1` | core | `USE_SHAPER_CSA_CR4RC USE_ENERGY_LORENZETTI` | `hits_tb_golden_paper_r1.vcd` |
| `sim_leap` | core | `USE_RNG_LEAP` | `hits_tb_golden_leap.vcd` |
| `sim_leap_legacy` | core | `USE_RNG_LEAP USE_SHAPER_LEGACY` | `hits_tb_golden_leap_legacy.vcd` |
| `sim_leap_csa_cr4rc` | core | `USE_RNG_LEAP USE_SHAPER_CSA_CR4RC` | `hits_tb_golden_leap_csa_cr4rc.vcd` |
| `sim_phase` | core | `USE_PHASE0=8` | `hits_tb_golden_phase.vcd` |
| `sim_jitter` | core | `USE_PHASE_SIGMA_PS=1000` | `hits_tb_golden_jitter.vcd` |
| `sim_phase_csa_cr4rc` | core | `USE_SHAPER_CSA_CR4RC USE_PHASE0=8` | `hits_tb_golden_phase_csa_cr4rc.vcd` |
| `sim_jitter_csa_cr4rc` | core | `USE_SHAPER_CSA_CR4RC USE_PHASE_SIGMA_PS=1000` | `hits_tb_golden_jitter_csa_cr4rc.vcd` |
| `pzc` | reconstruction | none (PZC, F34) | `hits_reco_tb_golden_pzc.vcd` |
| `pzc_legacy` | reconstruction | `USE_SHAPER_LEGACY` | `hits_reco_tb_golden_pzc_legacy.vcd` |
| `pzc_csa_cr4rc` | reconstruction | `USE_SHAPER_CSA_CR4RC` | `hits_reco_tb_golden_pzc_csa_cr4rc.vcd` |
| `est` | reconstruction | `USE_BASELINE_EST` | `hits_reco_tb_golden_est.vcd` |
| `bus` | bus | none (F34) | `hits_bus_tb_golden.vcd` |
| `bus_jitter` | bus | `TB_JITTER USE_SHAPER_CSA_CR4RC` | `hits_bus_tb_golden_jitter.vcd` |

The comparison ignores only what is not behavior: the `$date` and `$version`
blocks, the `RTL_DIR` path of the testbench, and the order of value changes
within one time step.

The golden of `paper` is frozen: `regress.py` keeps its SHA-256 and fails if the
file changes, even if someone regenerated it. Changing that hash is a decision
about the paper, not a fix.

## When it runs

- Before each commit, on your machine, once the hook is enabled
  (`git config core.hooksPath .githooks`). A commit that touches `rtl/`,
  `reconstruction/`, the AURORA projects or `verification/` runs the regression
  first and is refused if it fails. It tests the working tree.
- On every push to `main` and every pull request, in CI
  (`.github/workflows/regression.yml`, check `regression`).

A `vvp` that dies without a message, which happens when the machine runs out of
memory, is run again up to twice and listed at the end.

## Changing a golden, adding a build

A change that is meant to alter the output regenerates the goldens it alters, by
hand, in the same commit, and the commit says why the waveform changed. A golden
is evidence only of what it was compared with, so a new or changed golden needs a
check of its own before it is stored: a model that predicts the new output, or a
statistic of it. The goldens of the phase builds, for instance, were checked
against the exact shifted pulse before they were stored.

A new build gets an entry in `BUILDS` of `verification/regress.py` and its
golden from a clean run:

```sh
python verification/regress.py --create <build>
```

`--create` refuses to overwrite a golden that exists.
