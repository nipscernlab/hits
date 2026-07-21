`timescale 1ns/100ps

// ---------------------------------------------------------------------------
// BASELINE-CORRECTION SELECTION (synthesis-time)
//
// Uncomment the line below to build with the adaptive baseline estimator
// instead of the PZC, or define USE_BASELINE_EST externally without touching
// this file:
//
//   Icarus / Verilator : iverilog -DUSE_BASELINE_EST ...
//   Quartus            : set_global_assignment -name VERILOG_MACRO "USE_BASELINE_EST=1"
//
// The `ifndef guard means an external define wins and this line stays inert.
//
//   default (undefined) : pzc_ped_track       - pole-zero cancellation + pedestal
//                                               tracking (the FPGA firmware port)
//   USE_BASELINE_EST    : estimador_baseline  - fast level tracker + slow
//                                               per-BCID shape, anchored on the
//                                               bunch-train mask (F14)
//
// Only ONE of them is instantiated; both drive `pzc_out`.
//
// ⚠️⚠️ THE TWO OUTPUTS ARE NOT ON THE SAME SCALE. The PZC output carries a gain
// of (M_FACTOR+1) = 455: io_out = (M+1)*(in-ped) + accumulator. The estimator
// output is in ADC counts (gain 1). Divide pzc_out by (PZC_M_FACTOR+1) before
// comparing the two. Plotting them together without this makes the PZC look
// 455x noisier, which is an artifact.
//
// ⚠️ The golden VCD in verification/ covers the DEFAULT build. Selecting the
// estimator changes pzc_out and the regression will report differences — there
// is a separate golden for it, exactly as for USE_SHAPER_F34.
// ---------------------------------------------------------------------------
//`define USE_BASELINE_EST

// Test composition: HITS simulator core + baseline correction under test.
//
// The PZC (pole-zero cancellation) is NOT part of the simulator; it is a
// downstream reconstruction stage being validated with the synthesized pulse
// train. This thin wrapper feeds the digitized simulator output (shaper_clip)
// into the PZC and exposes both the simulator probes and the PZC outputs.
//
// It keeps the exact port interface of the standalone top it replaced, so the
// board top (FPGA_Simulator_v1_PZC_SOC) and the testbench are unchanged.
module FPGA_Simulator_v1_PZC
#(
	parameter RAND_BITS_HITS = 7,
	parameter BUNCH_MEM = "bunch_train_mask.mif",
	parameter BUNCH_POS = 3564,
	parameter BUNCH_TRAIN_ACTIVE = 1,
	parameter RAND_BITS_ENG = 10,
	parameter ENG_OUT_BITS = 13,
	parameter CLIP_OUT_BITS = ENG_OUT_BITS-1,
	parameter SHAPER_OUT_BITS = ENG_OUT_BITS+16+1,
	parameter PZC_OUT_BITS = CLIP_OUT_BITS+1+16,
	parameter MEM_ENG_SIZE = 2**10,
	parameter MEM_ENG0 = "A13_PART1.mif",
	parameter MEM_ENG1 = "A13_PART2.mif",
	parameter MEM_ENG2 = "A13_PART3.mif",
	parameter MEM_ENG0_THRESH = 1001,
	parameter MEM_ENG1_THRESH = 985,
	parameter RAND_BITS_NOISE = 10,
	parameter NOISE_OUT_BITS = 17,
	parameter MEM_NOISE_SIZE = 2**10,
	parameter MEM_NOISE0 = "NOISE_PART1.mif",
	parameter MEM_NOISE1 = "NOISE_PART2.mif",
	parameter MEM_NOISE2 = "NOISE_PART3.mif",
	parameter MEM_NOISE0_THRESH = 1007,
	parameter MEM_NOISE1_THRESH = 1007,
	parameter PZC_M_FACTOR = 454,
	// --- adaptive baseline estimator (USE_BASELINE_EST) ---
	parameter EST_FRAC       = 6,             // fractional bits of level and shape
	parameter EST_FRAC_I     = 6,             // fractional bits of the interp accumulator
	parameter EST_K_NIVEL    = 4,             // level memory: 2^K anchors (~2.2 us)
	parameter EST_K_FORMA    = 8,             // shape memory: 2^K orbits  (~22.8 ms)
	parameter EST_N_ANC      = 654,           // anchors per orbit (from the MASK)
	parameter EST_WS         = 14,            // shape word width
	parameter EST_K_VAZIO    = 13,            // empty slots before a sample is an anchor
	// ⚠️ Tracks the SHAPER latency: it was 2, and became 3 when the F34 shaper
	// gained an output pipeline stage (01_Timing_40MHz, 2026-07-21). Re-measure
	// if the shaper latency changes again (F15 recipe: correlate event_bt with
	// shaper_out, and check the ADC mean vs distance-since-last-filled-slot).
	parameter EST_LATENCIA   = 3,             // shaper pipeline delay, in samples
	parameter EST_RECIP_MEM  = "recip.mem",   // reciprocal ROM (depends on the MASK)
	parameter EST_S_INIT_MEM = "",            // preloaded shape ("" = start from zero)
	parameter signed [31:0] EST_L_INIT = 0,   // preloaded level, in the FRAC grid
	// ⚠️⚠️ MEASURED, not chosen. `ia` free-runs on anchors and assumes exactly
	// EST_N_ANC of them per orbit, which holds in steady state — but NOT in the
	// FIRST orbit: reset truncates the anchor block that straddles the orbit
	// boundary, so that orbit yields 640 anchors instead of 654 and `ia` is left
	// permanently out of phase.
	// With the wrong phase recip[ia] is another anchor's gap, and since 631 of
	// the 654 gaps have N = 1, the ramp blows up in the 23 LONG gaps: measured
	// with EST_IA_INIT = 0, recip matched the real gap in 93% of anchors but in
	// 0 of 230 long gaps (read 65536, the N=1 reciprocal, where 712 was due).
	// ⚠️ The error is INVISIBLE AT THE ANCHORS — `acc` is reloaded there — so a
	// metric that only samples anchors cannot see it. Do not sweep this
	// parameter against such a metric; check recip[ia] against the measured gap
	// instead (diagnostico8.py in the F15 vault, 100% match at +12).
	parameter integer EST_IA_INIT = 12        // anchor-index phase (MEASURED)
)
(
	input clk, rst,
	input [RAND_BITS_HITS-1:0] occupancy,
	input signed [ENG_OUT_BITS-1:0] offset,
	output hits_out, bt_mask_out,
	output [ENG_OUT_BITS-1:0] energy_out, event_bt, event_all,
	output signed [SHAPER_OUT_BITS-1:0] shaper_out,
	output signed [SHAPER_OUT_BITS-1:0] shaper_corrupted,
	output [CLIP_OUT_BITS-1:0] shaper_clip,
	output signed [NOISE_OUT_BITS-1:0] noise_out,
	output signed [CLIP_OUT_BITS+1-1:0] pedestal_out,
	output signed [PZC_OUT_BITS-1:0] pzc_out
);


// HITS simulator core (rtl/) — everything up to the digitized ADC sample.
FPGA_Simulator_v1
#(
	.RAND_BITS_HITS(RAND_BITS_HITS),
	.BUNCH_MEM(BUNCH_MEM),
	.BUNCH_POS(BUNCH_POS),
	.BUNCH_TRAIN_ACTIVE(BUNCH_TRAIN_ACTIVE),
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
	.RAND_BITS_NOISE(RAND_BITS_NOISE),
	.NOISE_OUT_BITS(NOISE_OUT_BITS),
	.MEM_NOISE_SIZE(MEM_NOISE_SIZE),
	.MEM_NOISE0(MEM_NOISE0),
	.MEM_NOISE1(MEM_NOISE1),
	.MEM_NOISE2(MEM_NOISE2),
	.MEM_NOISE0_THRESH(MEM_NOISE0_THRESH),
	.MEM_NOISE1_THRESH(MEM_NOISE1_THRESH)
) core
(
	.clk(clk),
	.rst(rst),
	.occupancy(occupancy),
	.offset(offset),
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


`ifdef USE_BASELINE_EST
// Adaptive baseline estimator under test (rtl_test/) — F14 of the
// Reconstrucao_Energia vault. Fast level tracker on the anchors plus a slow
// per-BCID shape, interpolated between anchors by a slope accumulator.
// Both forgetting factors ARE the shifts: lambda = 1 - 2^-K.
//
// ⚠️ Scale: output is in ADC counts (gain 1), unlike the PZC (gain M+1).
// ⚠️ EST_RECIP_MEM depends on the bunch-train MASK: change the fill pattern
// and the ROM must be regenerated (modelo_etapa2.py in the vault).
wire ancora;

gerador_ancora
#(
	.K_VAZIO(EST_K_VAZIO),
	.LATENCIA(EST_LATENCIA)
)ga
(
	.clk(clk),
	.rst(rst),
	.bt_mask(bt_mask_out),
	.ancora(ancora)
);

wire signed [CLIP_OUT_BITS+1-1:0] est_y;

estimador_baseline
#(
	.BITS_IN(CLIP_OUT_BITS+1),
	.FRAC(EST_FRAC),
	.FRAC_I(EST_FRAC_I),
	.K_NIVEL(EST_K_NIVEL),
	.K_FORMA(EST_K_FORMA),
	.N_ANC(EST_N_ANC),
	.WS(EST_WS),
	.RECIP_MEM(EST_RECIP_MEM),
	.S_INIT_MEM(EST_S_INIT_MEM),
	.L_INIT(EST_L_INIT),
	.IA_INIT(EST_IA_INIT)
)est
(
	.clk(clk),
	.rst(rst),
	.valid(1'b1),
	.x({1'd0,shaper_clip}),
	.ancora(ancora),
	.y(est_y),
	.correcao(pedestal_out)             // the tracked baseline, same role as `pedestal`
);

// sign-extend into the shared correction-output port
assign pzc_out = {{(PZC_OUT_BITS-(CLIP_OUT_BITS+1)){est_y[CLIP_OUT_BITS]}}, est_y};

`else
// PZC under test (rtl_test/) — consumes the digitized ADC sample.
pzc_ped_track
#(
	.NBITS_IN(CLIP_OUT_BITS+1),        // input data width
	.NBITS_OUT(PZC_OUT_BITS),          // output data width
	.M_FACTOR(PZC_M_FACTOR)            // PZC M factor
)pzc_zero
(
	.clk(clk),
	.rst(rst),
	.bt_mask_out(bt_mask_out),
	.in({1'd0,shaper_clip}),
	.pedestal(pedestal_out),
	.io_out(pzc_out)
);
`endif

endmodule
