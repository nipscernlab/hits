`timescale 1ns/100ps

// Hit draw per bunch crossing, gated by the LHC bunch-train mask.
//
// Occupancy (since 2026-10-09): the runtime input `occupancy` keeps its
// RAND_BITS (7) bits from the HPS, hit probability occupancy/128 as before.
// With the xoshiro generator the draw is 16 bits wide: the threshold is
// {occupancy, OCC_LSB}, where OCC_LSB (9 bits, a synthesis parameter, default
// 0) refines it to 1/65536, for cells whose occupancy goes with an energy ROM
// (P(E > 0) of the cell, e.g. 0.99954). With OCC_LSB = 0 the hits are bit for
// bit the 7-bit ones: the 7-bit word is the top of the 16-bit one, and the
// threshold ends in 9 zeros. OCC_BYPASS = 1 makes every filled bunch crossing a
// hit (cells with occupancy 1), whatever `occupancy` says. The other generators
// keep the 7-bit draw and ignore OCC_LSB.
module hit_generator
#(
	parameter RNG_TYPE = "xoshiro",       // rng kind, see rtl/random/rng.v
	parameter RAND_BITS = 7,
	parameter OCC_LSB = 0,                // 9 low bits of the 16-bit occupancy (xoshiro only)
	parameter OCC_BYPASS = 0,             // 1: hit on every bunch crossing (occupancy 1)
	parameter BUNCH_MEM = "bunch_train_mask.mif",
	parameter BUNCH_POS = 3564,
	parameter BUNCH_TRAIN_ACTIVE = 1,
	// xoshiro state {s3, s2, s1, s0} (the other generators keep their own seeds); one channel's three generators are
	// jumped 2^64 apart, see rtl/random/xoshiro_jump.py
	parameter [127:0] XO_SEED = {32'd3049884771, 32'd209805534, 32'd363409739, 32'd461934351}
)
(
	input clk, rst,
	input [RAND_BITS-1:0] occupancy,
	output hits_out, hits_orig, bt_mask_out
);

localparam FINE = (RNG_TYPE == "xoshiro");
localparam DRAW_BITS = FINE ? 16 : RAND_BITS;

wire [DRAW_BITS-1:0] rand_hits;

rng
#(
	.RNG_TYPE(RNG_TYPE),
	.RAND_OUT_SIZE(DRAW_BITS),
	.SEED0(FINE ? {10'd0, XO_SEED[31:0]}   : 42'd461934351),
	.SEED1(FINE ? {10'd0, XO_SEED[63:32]}  : 42'd363409739),
	.SEED2(FINE ? {10'd0, XO_SEED[95:64]}  : 42'd209805534),
	.SEED3(FINE ? {10'd0, XO_SEED[127:96]} : 42'd3049884771),
	.SEED4(42'd2859598492),
	.SEED5(42'd352859598492),
	.SEED6(42'd42859998594)
) rng_hits
(
	.clk(clk),
	.rst(rst),
	.rand_out(rand_hits)
);

wire [DRAW_BITS-1:0] threshold;
generate
if (FINE) begin : fine
	wire [8:0] lsb = OCC_LSB;
	assign threshold = {occupancy, lsb};
end else begin : coarse
	assign threshold = occupancy;
end
endgenerate

wire hits_drawn, hits;

hit_draw
#(
	.IN_SIZE(DRAW_BITS)
) hits_pos
(
	.clk(clk),
	.rst(rst),
	.in(rand_hits),
	.occupancy(threshold),
	.hit(hits_drawn)
);

// bypass: 1 from the first clock after reset, like the drawn hit register
reg hit_one = 1'b0;
always @(posedge clk or posedge rst)
	if (rst) hit_one <= 1'b0;
	else     hit_one <= 1'b1;
assign hits = OCC_BYPASS ? hit_one : hits_drawn;

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
