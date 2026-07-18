`timescale 1ns/100ps

// Test composition: HITS simulator core + PZC under test.
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
	parameter PZC_M_FACTOR = 454
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

endmodule
