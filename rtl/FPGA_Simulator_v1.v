`timescale 1ns/100ps

module FPGA_Simulator_v1
#(
	parameter RAND_BITS_HITS = 7,
	parameter BUNCH_MEM = "bunch_train_mask.mif",
	parameter BUNCH_POS = 3564,
	parameter BUNCH_TRAIN_ACTIVE = 1,
	parameter RAND_BITS_ENG = 10,
	parameter ENG_OUT_BITS = 13,
	parameter SHAPER_OUT_BITS = ENG_OUT_BITS+16+1,
	parameter MEM_ENG_SIZE = 2**10,
	parameter MEM_ENG0 = "A13_PART1.mif",
	parameter MEM_ENG1 = "A13_PART2.mif",
	parameter MEM_ENG2 = "A13_PART3.mif",
	parameter MEM_ENG0_THRESH = 1001,
	parameter MEM_ENG1_THRESH = 985
	
)
(
	input clk, rst,
	output hits_out,
	output [ENG_OUT_BITS-1:0] energy_out, event_bt, event_all,
	output signed [SHAPER_OUT_BITS-1:0] shaper_out
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

endmodule