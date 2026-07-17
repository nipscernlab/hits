`timescale 1ns/100ps

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





Hits_Bunch_train
#(
	.RAND_BITS(RAND_BITS_HITS),
	.BUNCH_MEM(BUNCH_MEM),
	.BUNCH_POS(3564),
	.BUNCH_TRAIN_ACTIVE(BUNCH_TRAIN_ACTIVE)
) hb_train
(
	.clk(clk), 
	.rst(rst),
	.occupancy(occupancy),
	.hits_out(hits_out), 
	.hits_orig(hits_orig), 
	.bt_mask_out(bt_mask_out)
);

energy_collisions
#(
	.RAND_BITS(RAND_BITS_ENG),
	.ENG_OUT_BITS(ENG_OUT_BITS),
	.MEM_ENG_SIZE(MEM_ENG_SIZE),
	.MEM_ENG0(MEM_ENG0),
	.MEM_ENG1(MEM_ENG1),
	.MEM_ENG2(MEM_ENG2),
	.MEM_ENG0_THRESH(MEM_ENG0_THRESH),
	.MEM_ENG1_THRESH(MEM_ENG1_THRESH)
)ec
(
	.clk(clk), 
	.rst(rst),
	.energy_out(energy_out)
);


shaper_fenics
#( 
	.BITS_IN(ENG_OUT_BITS),
	.G_ENTRADA(2**32),
	.G_SAIDA_LOG(10)
)sf
(
	.clock(clk), 
	.in(event_bt),
	.out(shaper_out)
);


assign event_bt = energy_out * hits_out;
assign event_all = energy_out * hits_orig;

wire signed [SHAPER_OUT_BITS-1:0] offset_extended = {{(SHAPER_OUT_BITS-ENG_OUT_BITS){offset[ENG_OUT_BITS-1]}},offset};

noise_collisions
#(
	.RAND_BITS(RAND_BITS_NOISE),
	.NOISE_OUT_BITS(NOISE_OUT_BITS),
	.MEM_NOISE_SIZE(MEM_NOISE_SIZE),
	.MEM_NOISE0(MEM_NOISE0),
	.MEM_NOISE1(MEM_NOISE1),
	.MEM_NOISE2(MEM_NOISE2),
	.MEM_NOISE0_THRESH(MEM_NOISE0_THRESH),
	.MEM_NOISE1_THRESH(MEM_NOISE1_THRESH)
) noise_sim
(
	.clk(clk),
	.rst(rst),
	.noise_out(noise_out)
	

);

assign shaper_corrupted = (shaper_out + {{(SHAPER_OUT_BITS-NOISE_OUT_BITS){noise_out[NOISE_OUT_BITS-1]}},noise_out});

clip_shaper
#( 
	.BITS_IN(SHAPER_OUT_BITS),
	.BITS_OUT(CLIP_OUT_BITS)
)clip
(
	.clk(clk),
	.rst(rst),
	.in(shaper_corrupted),
	.offset(offset_extended),
	.out(shaper_clip)
);



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