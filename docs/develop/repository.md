# The repository

The repository holds two kinds of thing. The product is the simulator, `rtl/`,
with the examples that show how to use it; that is what a release ships and what
the first part of this manual describes. Everything else is development: the
tools that keep the product correct and the projects for the boards of the
laboratory. Table 1 shows where each part lives.

Table 1: what is product and what is development.

| Path | Kind | What it is |
|---|---|---|
| `rtl/` | product | the simulator: `hits.v` (its top, a wrapper with the configuration tied to its parameters), `hits_core.v` (the circuit) and one folder per stage, with the memory files next to the modules that read them |
| `projects/hits/aurora/` | product, example | testbench and AURORA project of the simulator alone |
| `projects/hits/quartus/` | product, example | the simulator alone on the DE10-Nano |
| `projects/hits/vivado/` | product, example | out-of-context synthesis in Vivado |
| `docs/`, `VERSION` | product | this manual and the version it describes |
| `verification/` | development | the regression: golden waveforms and the scripts that compare them |
| `.githooks/`, `.github/` | development | the pre-commit hook and the CI workflows |
| `projects/hits_reco/quartus/` | development | the DE10-Nano with the ARM processor and the reconstruction techniques it builds, see [The board with the ARM processor](board-with-arm.md) |

The examples are not tied to the product: the core does not depend on any board,
and a change to an example does not change the simulator. The regression
compiles only `rtl/` and the testbenches, so it is the guard of the product.

Some files of `rtl/` are generated, and must not be edited by hand:
[Generated files](generated-files.md) lists them.

## Working on the repository

The regression runs before each commit when the hook is enabled once per clone:

```sh
git config core.hooksPath .githooks
```

The same regression runs in CI on every push to `main` and on every pull
request. Commit messages are in Portuguese, as the history of the repository is;
comments in the code and this manual are in English.
