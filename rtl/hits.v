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
// The full front-end signal chain of the calorimeter readout, one sample per
// 25 ns clock cycle: pseudo-random hit generation gated by the bunch-train
// mask, energy amplitudes from the measured distribution, analog pulse shaping
// (the selected shaper, F34 by default), electronic noise, and digitization (pedestal offset + clip to the
// ADC range). The digitized sample `shaper_clip` IS the simulator output.
//
// The pole-zero cancellation (PZC) is NOT part of the simulator: it is a
// downstream reconstruction stage under test. It lives in reconstrucao/pzc/ and
// is composed with this core by the hits_reco wrapper.
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

wire hits_orig;   // ungated hit (before the bunch-train mask), used by event_all

hit_generator
#(
	.RNG_TYPE(RNG_TYPE),
	.RAND_BITS(RAND_BITS_HITS),
	.OCC_BYPASS(OCC_BYPASS),
	.BUNCH_MEM(BUNCH_MEM),
	.BUNCH_POS(BUNCH_POS),
	.BUNCH_TRAIN_ACTIVE(BUNCH_TRAIN_ACTIVE),
	.XO_SEED(XO_SEED_HIT)
) hb_train
(
	.clk(clk),
	.rst(rst),
	.occupancy(occupancy),
	.hits_out(hits_out),
	.hits_orig(hits_orig),
	.bt_mask_out(bt_mask_out)
);

energy_generator
#(
	.RNG_TYPE(RNG_TYPE),
	.ENERGY_TYPE(ENERGY_TYPE),
	.MEM_SEG(MEM_SEG),
	.RAND_BITS(RAND_BITS_ENG),
	.ENG_OUT_BITS(ENG_OUT_BITS),
	.MEM_ENG_SIZE(MEM_ENG_SIZE),
	.MEM_ENG0(MEM_ENG0),
	.MEM_ENG1(MEM_ENG1),
	.MEM_ENG2(MEM_ENG2),
	.MEM_ENG0_THRESH(MEM_ENG0_THRESH),
	.MEM_ENG1_THRESH(MEM_ENG1_THRESH),
	.XO_SEED(XO_SEED_ENERGY)
)ec
(
	.clk(clk),
	.rst(rst),
	.energy_out(energy_out)
);


// ------------------------------------------------------------- phase of each hit ---
// The shaper reads the phase of the hit that enters it in the same cycle. With SIGMA_PS = 0
// the index is the constant 32 + PHASE0. With jitter, delta comes from its own xoshiro
// word through the segmented inverse CDF of noise_gauss.v (MEM_GAUSS_PHASE, g = 4096 z):
//   index = 32 + PHASE0 + round(z * SIGMA_PS / 390.625 ps), saturated to 0..63.
// The draw runs every cycle and is independent of the hits, so whichever hit enters
// takes a fresh delta.
localparam PHASE_ON = (PHASE0 != 0) || (SIGMA_PS != 0);
wire [5:0] ph_idx;
generate
if (PHASE0 < -32 || PHASE0 > 31) begin : erro_phase0
	ERROR_PHASE0_must_be_in_minus32_to_31 e ();
end
if (SIGMA_PS < 0 || SIGMA_PS > 12500) begin : erro_sigma
	ERROR_SIGMA_PS_must_be_in_0_to_12500 e ();
end
if (SIGMA_PS != 0) begin : jitter
	wire [31:0] w_ph;
	rng
	#(
		.RNG_TYPE("xoshiro"),          // the draw is xoshiro whatever RNG_TYPE says
		.RAND_OUT_SIZE(32),
		.SEED0({10'd0, XO_SEED_PHASE[31:0]}),
		.SEED1({10'd0, XO_SEED_PHASE[63:32]}),
		.SEED2({10'd0, XO_SEED_PHASE[95:64]}),
		.SEED3({10'd0, XO_SEED_PHASE[127:96]})
	) rng_ph
	(
		.clk(clk),
		.rst(rst),
		.rand_out(w_ph),
		.rand_next()
	);
	wire signed [16:0] g_ph;
	noise_gauss
	#(
		.NOISE_OUT_BITS(17),
		.MEM_GAUSS(MEM_GAUSS_PHASE)
	) gauss_ph
	(
		.clk(clk),
		.rst(rst),
		.rnd(w_ph),
		.noise_out(g_ph)
	);
	// z * SIGMA_PS / 390.625 = g * K_SIG / 2^20 with K_SIG = SIGMA_PS * 2^20 / (4096 * 390.625)
	localparam integer K_SIG = (SIGMA_PS * 4096 + 3125) / 6250;
	wire signed [40:0] d_ph = g_ph * K_SIG + (41'sd1 <<< 19);
	wire signed [20:0] d_idx = d_ph >>> 20;
	wire signed [21:0] i_ph = 32 + PHASE0 + d_idx;
	reg [5:0] idx = 32 + PHASE0;
	always @(posedge clk or posedge rst)
		if (rst) idx <= 32 + PHASE0;
		else idx <= (i_ph < 0) ? 6'd0 : (i_ph > 63) ? 6'd63 : i_ph[5:0];
	assign ph_idx = idx;
end else begin : fixa
	assign ph_idx = 32 + PHASE0;
end
endgenerate

// Two shapers at once is a mistake, not a choice: stop the compilation
// with a module name that says so.
`ifdef USE_SHAPER_CSA_CR4RC
  `ifdef USE_SHAPER_LEGACY
	ERROR_two_shapers_USE_SHAPER_CSA_CR4RC_and_USE_SHAPER_LEGACY_pick_one e_sh0 ();
  `endif
  `ifdef USE_SHAPER_F34
	ERROR_two_shapers_USE_SHAPER_CSA_CR4RC_and_USE_SHAPER_F34_pick_one e_sh1 ();
  `endif
`endif
`ifdef USE_SHAPER_LEGACY
  `ifdef USE_SHAPER_F34
	ERROR_two_shapers_USE_SHAPER_LEGACY_and_USE_SHAPER_F34_pick_one e_sh2 ();
  `endif
`endif

`ifdef USE_SHAPER_CSA_CR4RC
// CSA + CR-4RC shaper: the generic "paper simulator" pulse -- the exact
// readout chain of the group's papers (bi-exponential detector pulse, CSA
// with a 51 ns feedback pole, unbuffered CR-4RC with a 500 us CR and four
// 5 ns RC stages). Peak = 1 (at scale 2**G_OUT_LOG) on sample 2; 1 cycle of
// latency; needs a reset.
generate
if (PHASE_ON) begin : g_phase
`ifdef USE_SHAPER_NO_PIPE
	ERROR_the_phase_needs_the_pipelined_CSA_drop_USE_SHAPER_NO_PIPE e_ph ();
`endif
	shaper_csa_cr4rc_phase
	#(
		.BITS_IN(ENG_OUT_BITS),
		.G_OUT_LOG(10),
		.PIPE_IN(1),
		.MEM_PH(MEM_PH_CSA)
	)sf
	(
		.clock(clk),
		.rst(rst),
		.in(event_bt),
		.phase(ph_idx),
		.out(shaper_out)
	);
end else begin : g_base
	shaper_csa_cr4rc
	#(
		.BITS_IN(ENG_OUT_BITS),
		.G_OUT_LOG(10),
`ifdef USE_SHAPER_NO_PIPE
		.PIPE_IN(0)                // the paper build: latency 1, as until 2026-10-03
`else
		.PIPE_IN(1)                // pipelined: latency 5
`endif
	)sf
	(
		.clock(clk),
		.rst(rst),
		.in(event_bt),
		.out(shaper_out)
	);
end
endgenerate
`elsif USE_SHAPER_LEGACY
// Legacy shaper: the parallel IIR sections HITS was born with (the default
// until 2026-10-01). Selected by USE_SHAPER_LEGACY. It has no phase.
generate
if (PHASE_ON) begin : erro_phase_legacy
	ERROR_the_legacy_shaper_has_no_phase e_ph ();
end
endgenerate
shaper_fenics
#(
	.BITS_IN(ENG_OUT_BITS),
	.G_OUT_LOG(10)
)sf
(
	.clock(clk),
	.rst(rst),
	.in(event_bt),
	.out(shaper_out)
);
`else
// F34 shaper (DEFAULT): 13-tap FIR head + 5 IIR sections (3 leaky, 2 coupled), derived
// from a 14-pole transfer function of the FENICS front end. Zero DC gain is
// imposed rather than fitted, so it cannot produce a baseline sag the real
// front end does not have. Needs a reset, like the other two.
generate
if (PHASE_ON) begin : g_phase
	shaper_fenics_f34_phase
	#(
		.BITS_IN(ENG_OUT_BITS),
		.G_OUT_LOG(10),
		.MEM_PH(MEM_PH_F34)
	)sf
	(
		.clock(clk),
		.rst(rst),
		.in(event_bt),
		.phase(ph_idx),
		.out(shaper_out)
	);
end else begin : g_base
	shaper_fenics_f34
	#(
		.BITS_IN(ENG_OUT_BITS),
		.G_OUT_LOG(10)
	)sf
	(
		.clock(clk),
		.rst(rst),
		.in(event_bt),
		.out(shaper_out)
	);
end
endgenerate
`endif


// event_bt/event_all are unsigned but feed the signed shaper input of the same
// width (ENG_OUT_BITS). This is safe because the energy never reaches the top
// bit: the three tables hold 12-bit magnitudes and energy_seg.v limits its
// output to 2^(ENG_OUT_BITS-1) - 1 = 4095 (since 2026-10-14; it allowed 8191
// before, which no ROM reached). Widen the shaper input if that ever changes.
// The hit gates the energy with an AND: written as energy_out * hits_out, the
// Quartus put each 13 x 1 product in a DSP block (2 DSPs for two ANDs).
assign event_bt  = energy_out & {ENG_OUT_BITS{hits_out}};
assign event_all = energy_out & {ENG_OUT_BITS{hits_orig}};

wire signed [SHAPER_OUT_BITS-1:0] offset_extended = {{(SHAPER_OUT_BITS-ENG_OUT_BITS){offset[ENG_OUT_BITS-1]}},offset};

noise_generator
#(
	.RNG_TYPE(RNG_TYPE),
	.NOISE_TYPE(NOISE_TYPE),
	.MEM_GAUSS(MEM_GAUSS),
	.RAND_BITS(RAND_BITS_NOISE),
	.NOISE_OUT_BITS(NOISE_OUT_BITS),
	.MEM_NOISE_SIZE(MEM_NOISE_SIZE),
	.MEM_NOISE0(MEM_NOISE0),
	.MEM_NOISE1(MEM_NOISE1),
	.MEM_NOISE2(MEM_NOISE2),
	.MEM_NOISE_BITS(MEM_NOISE_BITS),
	.MEM_NOISE_FRAC(MEM_NOISE_FRAC),
	.MEM_NOISE0_THRESH(MEM_NOISE0_THRESH),
	.MEM_NOISE1_THRESH(MEM_NOISE1_THRESH),
	.XO_SEED(XO_SEED_NOISE)
) noise_sim
(
	.clk(clk),
	.rst(rst),
	.noise_out(noise_out)
);

assign shaper_corrupted = (shaper_out + {{(SHAPER_OUT_BITS-NOISE_OUT_BITS){noise_out[NOISE_OUT_BITS-1]}},noise_out});

adc
#(
	.BITS_IN(SHAPER_OUT_BITS),
	.BITS_OUT(CLIP_OUT_BITS),
`ifdef USE_ADC_FLOOR
	.ROUND(0)
`else
	.ROUND(1)
`endif
)clip
(
	.clk(clk),
	.rst(rst),
	.in(shaper_corrupted),
	.offset(offset_extended),
	.out(shaper_clip)
);

endmodule
