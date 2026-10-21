# The HITS manual

HITS (Hardware Impulse Train Synthesizer) is a real-time simulator of
calorimeter readout pulses, written in synthesizable Verilog. At every clock
cycle of a high-speed sampled readout it produces the sample that the
analog-to-digital converter (ADC) of a calorimeter channel would deliver, built
from:

- hits drawn at random within the bunch-train structure of the collider;
- energies drawn from a spectrum held in memory;
- the analog pulse shape of the front end;
- electronic noise;
- the pedestal and the 12-bit quantization.

It is used to test energy-reconstruction techniques without access to the
experiment.

This manual describes HITS {{ release }}. Its first part is for those who use
the simulator: the RTL core and the examples that show how to simulate it and
how to synthesize it in Quartus and in Vivado. Its second part is for those who
change HITS: how the repository is organized, the regression, the generated
files and the release process.

## Using HITS

- [Getting started](guide/getting-started.md): what you need, and a first
  simulation in a minute.
- [The signal chain](guide/signal-chain.md): the stages of the simulator, its ports
  and its outputs.
- [Configuring HITS at run time](guide/configuring.md): the configuration bus,
  its registers and how to load a memory.
- [Build options](guide/options.md): the random generator, the energy spectrum, the
  pulse shape and its phase, the noise and the ADC, and how to choose each one.
- [Using the core in your design](guide/integrating.md): clock, reset, latency, the
  memory files and the resources it takes.
- [Examples](guide/examples.md): simulation with Icarus Verilog and AURORA,
  synthesis with Quartus and with Vivado.
- [Reproducing the papers](guide/papers.md): the configurations behind the published
  results.

## Reference

- [Parameters and macros](reference/parameters.md): every parameter of
  `hits` and every macro, with its default.

## Developing HITS

- [The repository](develop/repository.md): what is product and what is
  development, and where each part lives.
- [The regression](develop/regression.md): the golden waveforms, the builds,
  the pre-commit hook and the CI check, and how to add a build.
- [Generated files](develop/generated-files.md): the files that are produced
  by a generator and must not be edited by hand.
- [The board with the ARM processor](develop/board-with-arm.md): the DE10-Nano
  project with the hard processor system.
- [Releases](develop/releases.md): versions, what goes into a release and the
  checks a release has to pass.
- [The configuration bus](develop/config-bus.md): why the bus is the way it
  is, what it costs and what is still open.

```{toctree}
:hidden:
:caption: Using HITS

guide/getting-started
guide/signal-chain
guide/configuring
guide/options
guide/integrating
guide/examples
guide/papers
```

```{toctree}
:hidden:
:caption: Reference

reference/parameters
```

```{toctree}
:hidden:
:caption: Developing HITS

develop/repository
develop/regression
develop/generated-files
develop/board-with-arm
develop/releases
develop/config-bus
```
