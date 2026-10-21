`timescale 1ns/100ps

// hits_bus: the HITS simulator configured at run time through the configuration bus
// (docs/develop/config-bus.md). It is hits_core with the register core hits_cfg: the
// parameters below are the same as in hits.v and give what is built and the values at
// power-up; a controller on the bus changes the values while the circuit runs.
//
// At power-up RUN = 1 and the simulator runs with these values and the .mif files, as
// hits does. The occupancy and the pedestal are registers here, not inputs: their
// values at power-up are OCCUPANCY_INIT and PEDESTAL_INIT.
//
// PHASE_SHAPER and JITTER say what is built, whatever PHASE0 and SIGMA_PS are: a bus
// that sets the jitter needs JITTER = 1 at synthesis.
module hits_bus
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
	parameter MEM_PH_CSA = "shaper_csa_cr4rc_phase.mif",
	parameter PHASE_SHAPER = (PHASE0 != 0) || (SIGMA_PS != 0),
	parameter JITTER = (SIGMA_PS != 0),
	parameter [15:0] OCCUPANCY_INIT = 16'd0,
	parameter [12:0] PEDESTAL_INIT = 13'd0
)
(
	input clk, rst,
	// the configuration bus
	input [3:0] addr,
	input [15:0] wdata,
	input wr,
	input rd,
	output [15:0] rdata,
	output hits_out, bt_mask_out,
	output [ENG_OUT_BITS-1:0] energy_out, event_bt, event_all,
	output signed [SHAPER_OUT_BITS-1:0] shaper_out,
	output signed [SHAPER_OUT_BITS-1:0] shaper_corrupted,
	output [CLIP_OUT_BITS-1:0] shaper_clip,
	output signed [NOISE_OUT_BITS-1:0] noise_out
);

localparam integer K_SIG = (SIGMA_PS * 4096 + 3125) / 6250;
`ifdef USE_SHAPER_CSA_CR4RC
localparam [1:0] CAPS_SHAPER = 2'd1;
localparam integer PH_PIECES = 12;      // a phase word: 192 bits
`elsif USE_SHAPER_LEGACY
localparam [1:0] CAPS_SHAPER = 2'd2;
localparam integer PH_PIECES = 12;      // (no phase)
`else
localparam [1:0] CAPS_SHAPER = 2'd0;
localparam integer PH_PIECES = 14;      // a phase word: 210 bits
`endif
// CAPS: 15:12 protocol version 1; 3 jitter (the table of 64 phases); 2 fixed phase by one
// loaded set of coefficients; 1:0 the shaper (0 F34, 1 CSA + CR-4RC, 2 legacy)
localparam [15:0] CAPS = {4'd1, 8'd0, (JITTER != 0), (PHASE_SHAPER != 0 && JITTER == 0), CAPS_SHAPER};

wire core_rst;
wire [15:0] occupancy;
wire [12:0] offset;
wire occ_bypass, train_active;
wire [$clog2(BUNCH_POS)-1:0] orbit_last;
wire signed [5:0] phase0;
wire [15:0] sigma_k;
wire mem_we;
wire [2:0] mem_sel;
wire [11:0] mem_addr;
wire [16*PH_PIECES-1:0] mem_wdata;

hits_cfg
#(
	.BUNCH_POS(BUNCH_POS),
	.CAPS(CAPS),
	.PH_PIECES(PH_PIECES),
	.OCCUPANCY_INIT(OCCUPANCY_INIT),
	.PEDESTAL_INIT(PEDESTAL_INIT),
	.OCC_BYPASS_INIT(OCC_BYPASS),
	.BUNCH_TRAIN_ACTIVE_INIT(BUNCH_TRAIN_ACTIVE),
	.PHASE0_INIT(PHASE0),
	.SIGMA_K_INIT(K_SIG[15:0])
) cfg
(
	.clk(clk),
	.rst(rst),
	.addr(addr),
	.wdata(wdata),
	.wr(wr),
	.rd(rd),
	.rdata(rdata),
	.core_rst(core_rst),
	.occupancy(occupancy),
	.offset(offset),
	.occ_bypass(occ_bypass),
	.train_active(train_active),
	.orbit_last(orbit_last),
	.phase0(phase0),
	.sigma_k(sigma_k),
	.mem_we(mem_we),
	.mem_sel(mem_sel),
	.mem_addr(mem_addr),
	.mem_wdata(mem_wdata)
);

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
	.MEM_PH_CSA(MEM_PH_CSA),
	.PHASE_SHAPER(PHASE_SHAPER),
	.JITTER(JITTER)
) core
(
	.clk(clk),
	.rst(core_rst),
	.occupancy(occupancy),
	.offset(offset),
	.occ_bypass(occ_bypass),
	.train_active(train_active),
	.orbit_last(orbit_last),
	.phase0(phase0),
	.sigma_k(sigma_k),
	.mem_we(mem_we),
	.mem_sel(mem_sel),
	.mem_addr(mem_addr),
	.mem_wdata(mem_wdata),
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
