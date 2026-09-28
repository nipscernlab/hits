`timescale 1ns/100ps

module hit_generator
#(
	parameter RNG_TYPE = "round_robin",   // rng kind, see rtl/random/rng.v
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

rng
#(
	.RNG_TYPE(RNG_TYPE),
	.RAND_OUT_SIZE(RAND_BITS),
	.SEED0(42'd461934351),
	.SEED1(42'd363409739),
	.SEED2(42'd209805534),
	.SEED3(42'd3049884771),
	.SEED4(42'd2859598492),
	.SEED5(42'd352859598492),
	.SEED6(42'd42859998594)
) rng_hits
(
	.clk(clk), 
	.rst(rst),
	.rand_out(rand_hits)
);

wire hits;

hit_draw
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
