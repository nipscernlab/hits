# Generated files

Several files of `rtl/` are produced by a program from a design study. Their
header says so. Editing one by hand breaks the link to the study that justifies
its numbers; the change is made in the generator and the file is generated
again. Table 1 lists them.

Table 1: the generated files of `rtl/`.

| File | What it holds | Generator |
|---|---|---|
| `shaper/shaper_fenics_f34.v` | the F34 filter: FIR taps and IIR sections in fixed point | `gerar_verilog.py`, design study F34/F35 |
| `shaper/shaper_csa_cr4rc.v` | the CSA + CR-4RC filter | `emitir_verilog.py`, design study F03/F37 |
| `energy/energy_seg_default.mif`, `energy_seg_lorenzetti.mif` | the segmented inverse CDF of each energy spectrum | integer model of `energy_seg.v`, research on the channel (2026-10) |
| `noise/noise_gauss_s4.mif` | the segmented inverse CDF of the Gaussian noise | research on the electronic noise (2026-10) |
| `random/xoshiro_jump.py` (a script, not generated) | prints the xoshiro seeds of each channel and checks the jumps | in this repository |

The generators and the studies are kept in the research archive of the
laboratory, outside this repository, together with the measurements that
justify each number. The energy and noise tables of the first paper
(`energy_icdf_paper_*.mif`, `noise_s*_icdf*.mif`) come from that paper and are
not generated again.
