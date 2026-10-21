`timescale 1ns/100ps

// ---------------------------------------------------------------------------
// SHAPER SELECTION (synthesis-time)
//
// The default is the F34 shaper, the FENICS Phase-II front end. Uncomment ONE
// of the lines below to select another one, or define the macro externally
// without touching this file:
//
//   Icarus / Verilator : iverilog -DUSE_SHAPER_LEGACY ...
//   Quartus            : set_global_assignment -name VERILOG_MACRO "USE_SHAPER_LEGACY=1"
//
// The `define lines below ship commented out, so an external define always wins.
//
//   default (undefined)  : shaper_fenics_f34   - the FENICS Phase-II pulse: the
//                                                40 MHz filter of the H(s) fitted
//                                                to the FENICS testbeam pulse
//                                                (13-tap FIR head + 5 IIR
//                                                sections, zero DC gain imposed)
//   USE_SHAPER_LEGACY    : shaper_fenics       - the shaper HITS was born with
//                                                (parallel IIR sections), the
//                                                default until 2026-10-01
//   USE_SHAPER_CSA_CR4RC : shaper_csa_cr4rc    - the generic "paper" pulse
//                                                (CSA + CR-4RC readout chain,
//                                                peak 60.1 ns on sample 2)
//
// USE_SHAPER_F34 is still accepted and selects the default, so older commands
// keep building the same circuit; combining it with another shaper is an error.
//
// All live in rtl/shaper/ and share the same output scale (2**G_OUT_LOG), so
// nothing downstream changes. They differ in the pulse they produce, which is
// the point: WARNING, each build has its OWN golden VCD in verification/ (see
// the README); comparing against the wrong golden reports differences.
// ---------------------------------------------------------------------------
//`define USE_SHAPER_LEGACY
//`define USE_SHAPER_CSA_CR4RC

// NOISE: sigma = 4 ADC counts at 12 bits by default (the Phase-II scale,
// rtl/noise/README.md). With the xoshiro generator the default is a Gaussian
// by segmented inverse CDF (noise_gauss.v, correct tail up to 6.34 sigma);
// the round_robin and leap generators keep the three inverse-CDF tables.
//   USE_NOISE_TABLES : the sigma = 4 tables also with xoshiro (the default
//                      until 2026-10-02)
//   USE_NOISE_SIGMA8 : the sigma = 8 tables used until 2026-09-29, which the
//                      paper build needs (implies tables)
// Same rule as the shaper macros.
//`define USE_NOISE_TABLES
//`define USE_NOISE_SIGMA8

// ENERGY: with the xoshiro generator the default is a segmented inverse CDF
// (energy_seg.v, since 2026-10-08): the spectrum is a ROM (MEM_SEG), a
// polynomial per segment, no staircase and a tail down to 2^-32 of probability;
// the round_robin and leap generators keep the three inverse-CDF tables.
//   USE_ENERGY_TABLES : the three tables also with xoshiro (the default until
//                       2026-10-08)
// Same rule as the shaper macros.
//`define USE_ENERGY_TABLES

// ADC: rounds to the nearest count by default (since 2026-10-03).
// USE_ADC_FLOOR truncates instead (0.5 count low on average), as until then;
// the paper build needs it. Same rule as the shaper macros.
//`define USE_ADC_FLOOR

// CSA + CR-4RC SHAPER: pipelined by default (input registered since 2026-10-03,
// everything outside the section loops since 2026-10-14: latency 5).
// USE_SHAPER_NO_PIPE keeps the original single-cycle datapath (latency 1); the
// paper build needs it. No effect on the other shapers.
//`define USE_SHAPER_NO_PIPE

// HITS simulator core (no PZC).
//
// Since 2026-10-20 the circuit lives in hits_core.v, which takes as inputs what a
// configuration bus can change at run time; this module ties those inputs to its
// parameters, so its interface, its parameters and the circuit it builds are the
// ones of before. hits_bus.v drives them from the bus instead.
//
// The full front-end signal chain of the calorimeter readout, one sample per
// 25 ns clock cycle: pseudo-random hit generation gated by the bunch-train
// mask, energy amplitudes from the measured distribution, analog pulse shaping
// (the selected shaper, F34 by default), electronic noise, and digitization (pedestal offset + clip to the
// ADC range). The digitized sample `shaper_clip` IS the simulator output.
//
// The pole-zero cancellation (PZC) is NOT part of the simulator: it is a
// downstream reconstruction stage. Only the board with the ARM builds it, in
// projects/hits_reco/quartus/reconstruction/, through the hits_reco wrapper.
module hits
#(
	// pseudo-random generator: "xoshiro" (xoshiro128**, default since
	// 2026-09-28), "round_robin" (the SBCCI 2025 bank) or "leap" (one
	// leap-forward LFSR per rng); see rtl/random/rng.v. Each has its own goldens.
	parameter RNG_TYPE = "xoshiro",
	parameter RAND_BITS_HITS = 7,          // draw width of the round_robin and leap hit generators (1/128 resolution)
	parameter OCC_BYPASS = 0,              // 1: hit on every filled bunch crossing (cells with occupancy 1)
	// xoshiro states {s3, s2, s1, s0} of the hit, energy and noise generators (RNG_TYPE "xoshiro" only). The defaults
	// are one seed and its 2^64 and 2 x 2^64 jumps; another channel takes the next jumps (rtl/random/xoshiro_jump.py),
	// so no two streams overlap.
	parameter [127:0] XO_SEED_HIT    = {32'd3049884771, 32'd209805534, 32'd363409739, 32'd461934351},
	parameter [127:0] XO_SEED_ENERGY = {32'd4067956920, 32'd127929272, 32'd1539352703, 32'd1284247703},
	parameter [127:0] XO_SEED_NOISE  = {32'd373898742, 32'd3231469901, 32'd777179928, 32'd1405228594},
	parameter BUNCH_MEM = "bunch_train_mask.mif",
	parameter BUNCH_POS = 3564,
	parameter BUNCH_TRAIN_ACTIVE = 1,
	parameter RAND_BITS_ENG = 10,
	parameter ENG_OUT_BITS = 13,
	parameter CLIP_OUT_BITS = ENG_OUT_BITS-1,
	parameter SHAPER_OUT_BITS = ENG_OUT_BITS+16+1,
	parameter MEM_ENG_SIZE = 2**10,
	parameter MEM_ENG0 = "energy_icdf_paper_0.mif",
	parameter MEM_ENG1 = "energy_icdf_paper_1.mif",
	parameter MEM_ENG2 = "energy_icdf_paper_2.mif",
	parameter MEM_ENG0_THRESH = 1001,
	parameter MEM_ENG1_THRESH = 985,
`ifdef USE_ENERGY_TABLES
	parameter ENERGY_TYPE = "tables",
`else
	parameter ENERGY_TYPE = (RNG_TYPE == "xoshiro") ? "seg" : "tables",
`endif
	parameter MEM_SEG = "energy_seg_default.mif",
	parameter RAND_BITS_NOISE = 10,
	parameter NOISE_OUT_BITS = 17,
	parameter MEM_NOISE_SIZE = 2**10,
`ifdef USE_NOISE_SIGMA8
	parameter MEM_NOISE0 = "noise_s8_icdf0.mif",
	parameter MEM_NOISE1 = "noise_s8_icdf1.mif",
	parameter MEM_NOISE2 = "noise_s8_icdf2.mif",
	parameter MEM_NOISE_BITS = 16,      // 16-bit entries, 2^-10 ADC
	parameter MEM_NOISE_FRAC = 10,
`else
	parameter MEM_NOISE0 = "noise_s4_icdf0.mif",
	parameter MEM_NOISE1 = "noise_s4_icdf1.mif",
	parameter MEM_NOISE2 = "noise_s4_icdf2.mif",
	parameter MEM_NOISE_BITS = 10,      // 10-bit entries, 2^-5 ADC (one M10K each)
	parameter MEM_NOISE_FRAC = 5,
`endif
	parameter MEM_NOISE0_THRESH = 1007,
	parameter MEM_NOISE1_THRESH = 1007,
`ifdef USE_NOISE_SIGMA8
	parameter NOISE_TYPE = "tables",
`elsif USE_NOISE_TABLES
	parameter NOISE_TYPE = "tables",
`else
	parameter NOISE_TYPE = (RNG_TYPE == "xoshiro") ? "gauss" : "tables",
`endif
	parameter MEM_GAUSS = "noise_gauss_s4.mif",
	// PHASE of the pulse (2026-10-17), F34 and CSA + CR-4RC only. phi > 0 = the hit arrives later.
	// The phase is an index of 64 steps of 25/64 = 0.390625 ns: index 32 + PHASE0 + delta.
	// PHASE0 = 0 and SIGMA_PS = 0 (the defaults) build the shaper of before, bit for bit and
	// at the same cost; anything else builds the *_phase shaper (taps per hit from a ROM).
	parameter integer PHASE0 = 0,          // fixed phase, in steps of 0.390625 ns, -32..31
	parameter integer SIGMA_PS = 0,        // jitter per hit: delta ~ N(0, SIGMA_PS ps), no cut
	                                       // (Gaussian tail to 6.34 sigma), saturated at -32..31
	// xoshiro state of the phase draw: the LONG jump (2^96) of XO_SEED_HIT (rtl/random/xoshiro_jump.py)
	parameter [127:0] XO_SEED_PHASE  = {32'd3324829296, 32'd1325001476, 32'd2724274168, 32'd176110054},
	// the Gaussian source of the draw: the sigma = 4 ADC noise ROM, read as 4096 z (2^-10 ADC)
	parameter MEM_GAUSS_PHASE = "noise_gauss_s4.mif",
	parameter MEM_PH_F34 = "shaper_fenics_f34_phase.mif",
	parameter MEM_PH_CSA = "shaper_csa_cr4rc_phase.mif"
)
(
	input clk, rst,
	input [15:0] occupancy,                // hit probability occupancy/65536 per filled bunch crossing
	input signed [ENG_OUT_BITS-1:0] offset,
	output hits_out, bt_mask_out,
	output [ENG_OUT_BITS-1:0] energy_out, event_bt, event_all,
	output signed [SHAPER_OUT_BITS-1:0] shaper_out,
	output signed [SHAPER_OUT_BITS-1:0] shaper_corrupted,
	output [CLIP_OUT_BITS-1:0] shaper_clip,
	output signed [NOISE_OUT_BITS-1:0] noise_out
);

// the jitter constant hits_core multiplies by: z * SIGMA_PS / 390.625 ps = g * K_SIG / 2^20
localparam integer K_SIG = (SIGMA_PS * 4096 + 3125) / 6250;
localparam integer ORBIT_LAST = BUNCH_POS - 1;

hits_core
#(
	.RNG_TYPE(RNG_TYPE),
	.RAND_BITS_HITS(RAND_BITS_HITS),
	.XO_SEED_HIT(XO_SEED_HIT),
	.XO_SEED_ENERGY(XO_SEED_ENERGY),
	.XO_SEED_NOISE(XO_SEED_NOISE),
	.BUNCH_MEM(BUNCH_MEM),
	.BUNCH_POS(BUNCH_POS),
	.RAND_BITS_ENG(RAND_BITS_ENG),
	.ENG_OUT_BITS(ENG_OUT_BITS),
	.CLIP_OUT_BITS(CLIP_OUT_BITS),
	.SHAPER_OUT_BITS(SHAPER_OUT_BITS),
	.MEM_ENG_SIZE(MEM_ENG_SIZE),
	.MEM_ENG0(MEM_ENG0),
	.MEM_ENG1(MEM_ENG1),
	.MEM_ENG2(MEM_ENG2),
	.MEM_ENG0_THRESH(MEM_ENG0_THRESH),
	.MEM_ENG1_THRESH(MEM_ENG1_THRESH),
	.ENERGY_TYPE(ENERGY_TYPE),
	.MEM_SEG(MEM_SEG),
	.RAND_BITS_NOISE(RAND_BITS_NOISE),
	.NOISE_OUT_BITS(NOISE_OUT_BITS),
	.MEM_NOISE_SIZE(MEM_NOISE_SIZE),
	.MEM_NOISE0(MEM_NOISE0),
	.MEM_NOISE1(MEM_NOISE1),
	.MEM_NOISE2(MEM_NOISE2),
	.MEM_NOISE_BITS(MEM_NOISE_BITS),
	.MEM_NOISE_FRAC(MEM_NOISE_FRAC),
	.MEM_NOISE0_THRESH(MEM_NOISE0_THRESH),
	.MEM_NOISE1_THRESH(MEM_NOISE1_THRESH),
	.NOISE_TYPE(NOISE_TYPE),
	.MEM_GAUSS(MEM_GAUSS),
	.PHASE0(PHASE0),
	.SIGMA_PS(SIGMA_PS),
	.XO_SEED_PHASE(XO_SEED_PHASE),
	.MEM_GAUSS_PHASE(MEM_GAUSS_PHASE),
	.MEM_PH_F34(MEM_PH_F34),
	.MEM_PH_CSA(MEM_PH_CSA)
) core
(
	.clk(clk),
	.rst(rst),
	.occupancy(occupancy),
	.offset(offset),
	.occ_bypass(OCC_BYPASS != 0),
	.train_active(BUNCH_TRAIN_ACTIVE != 0),
	.orbit_last(ORBIT_LAST[$clog2(BUNCH_POS)-1:0]),
	.phase0(PHASE0[5:0]),
	.sigma_k(K_SIG[15:0]),
	.mem_we(1'b0),
	.mem_sel(3'd0),
	.mem_addr(12'd0),
	.mem_wdata(210'd0),
	.hits_out(hits_out),
	.bt_mask_out(bt_mask_out),
	.energy_out(energy_out),
	.event_bt(event_bt),
	.event_all(event_all),
	.shaper_out(shaper_out),
	.shaper_corrupted(shaper_corrupted),
	.shaper_clip(shaper_clip),
	.noise_out(noise_out)
);

endmodule
