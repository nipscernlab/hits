`timescale 1ns/100ps

module Hits_Bunch_train
#(
	parameter RAND_BITS = 7,
	parameter BUNCH_MEM = "bunch_train_mask.mif",
	parameter BUNCH_POS = 3564,
	parameter BUNCH_TRAIN_ACTIVE = 1
)
(
	input clk, rst,
	input [RAND_BITS-1:0] occupancy,
	output hits_out, hits_orig, bt_mask_out
);


wire [RAND_BITS-1:0] rand_hits;

random_number_generator
#(
	.RAND_OUT_SIZE(RAND_BITS),
	.SEED0(64'd461934351),
	.SEED1(64'd363409739),
	.SEED2(64'd209805534),
	.SEED3(64'd3049884771),
	.SEED4(64'd2859598492),
	.SEED5(64'd352859598492),
	.SEED6(64'd42859998594)
) rng_hits
(
	.clk(clk), 
	.rst(rst),
	.rand_out(rand_hits)
);

wire hits;

hits_positions
#(
	.IN_SIZE(RAND_BITS)
) hits_pos
(
	.clk(clk), 
	.rst(rst),
	.in(rand_hits),
	.occupancy(occupancy),	
	.hit(hits)
);

wire bt_out;

bunch_train_mask
#(
	.BUNCH_MEM(BUNCH_MEM),
	.BUNCH_POS(BUNCH_POS)
)bt_mask
(
	.clk(clk),
	.rst(rst),
	.out(bt_out)
);

assign hits_orig = hits;
assign bt_mask_out = bt_out | ~BUNCH_TRAIN_ACTIVE[0];
assign hits_out = hits & bt_mask_out;

endmodule
