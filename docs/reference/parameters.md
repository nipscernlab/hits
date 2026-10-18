# Parameters and macros

The parameters of `hits` and the macros it reads, with their defaults.
The source is `rtl/hits.v`; when the two disagree, the source is right
and this page is a defect.

## Parameters

Table 1 lists the parameters a user sets. Table 2 lists those that size the
datapath or name the memory files; they rarely change.

Table 1: the parameters that choose the simulator.

| Parameter | Default | Meaning |
|---|---|---|
| `RNG_TYPE` | `"xoshiro"` | random generator: `"xoshiro"`, `"round_robin"` or `"leap"` |
| `OCC_BYPASS` | 0 | 1: a hit on every filled bunch crossing |
| `BUNCH_TRAIN_ACTIVE` | 1 | 0: no bunch-train mask, every crossing filled |
| `MEM_SEG` | `"energy_seg_default.mif"` | ROM of the energy spectrum (segmented inverse CDF) |
| `XO_SEED_HIT` | one fixed seed | xoshiro state of the hit draw, `{s3, s2, s1, s0}` |
| `XO_SEED_ENERGY` | the jump of 2^64 of `XO_SEED_HIT` | xoshiro state of the energy draw |
| `XO_SEED_NOISE` | the jump of 2 × 2^64 of `XO_SEED_HIT` | xoshiro state of the noise draw |

Table 2: the parameters that size the datapath or name files.

| Parameter | Default | Meaning |
|---|---|---|
| `RAND_BITS_HITS` | 7 | draw width of the hits with the round-robin and leap generators |
| `RAND_BITS_ENG` | 10 | address width of the energy tables |
| `RAND_BITS_NOISE` | 10 | address width of the noise tables |
| `ENG_OUT_BITS` | 13 | width of the energy and of `offset` |
| `CLIP_OUT_BITS` | `ENG_OUT_BITS` − 1 | width of the ADC sample (12) |
| `SHAPER_OUT_BITS` | `ENG_OUT_BITS` + 17 | width of `shaper_out` (30) |
| `NOISE_OUT_BITS` | 17 | width of `noise_out` |
| `BUNCH_MEM` | `"bunch_train_mask.mif"` | the bunch-train mask |
| `BUNCH_POS` | 3564 | slots in one orbit |
| `ENERGY_TYPE` | `"seg"` with xoshiro, else `"tables"` | energy draw; `USE_ENERGY_TABLES` forces `"tables"` |
| `MEM_ENG_SIZE`, `MEM_ENG0..2`, `MEM_ENG0_THRESH`, `MEM_ENG1_THRESH` | 1024, `energy_icdf_paper_0..2.mif`, 1001, 985 | the three energy tables |
| `NOISE_TYPE` | `"gauss"` with xoshiro, else `"tables"` | noise draw; `USE_NOISE_TABLES` or `USE_NOISE_SIGMA8` force `"tables"` |
| `MEM_GAUSS` | `"noise_gauss_s4.mif"` | ROM of the Gaussian noise (σ = 4 ADC counts) |
| `MEM_NOISE_SIZE`, `MEM_NOISE0..2`, `MEM_NOISE_BITS`, `MEM_NOISE_FRAC`, `MEM_NOISE0_THRESH`, `MEM_NOISE1_THRESH` | 1024, `noise_s4_icdf0..2.mif` (σ = 8 files with `USE_NOISE_SIGMA8`), 10, 5, 1007, 1007 | the three noise tables |

## Macros

Table 3 lists the macros of the core. The example testbench reads a few more,
listed after the table.

Table 3: the macros read by `rtl/`.

| Macro | Effect |
|---|---|
| `USE_SHAPER_CSA_CR4RC` | the CSA + CR-4RC shaper |
| `USE_SHAPER_LEGACY` | the legacy shaper |
| `USE_SHAPER_F34` | the default shaper, accepted for older command lines |
| `USE_SHAPER_NO_PIPE` | the CSA + CR-4RC shaper without its pipeline, latency 1 |
| `USE_ENERGY_TABLES` | the three energy tables instead of the segmented spectrum |
| `USE_NOISE_TABLES` | the noise tables with σ = 4 instead of the Gaussian |
| `USE_NOISE_SIGMA8` | the noise tables with σ = 8 |
| `USE_ADC_FLOOR` | an ADC that truncates instead of rounding |

The example testbench `hits_tb.v` also reads `USE_RNG_ROUND_ROBIN` and
`USE_RNG_LEAP` (they set `RNG_TYPE`), and `USE_ENERGY_LORENZETTI` (it sets `MEM_SEG`
to the Lorenzetti spectrum and the occupancy to 65530).
