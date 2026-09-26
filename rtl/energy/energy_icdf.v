`timescale 1ns/100ps

// Energy amplitude by inverse CDF, split across three tables (multi-memory
// approach): table 0 unless rand0 > MEM_ENG0_THRESH, then table 1 unless
// rand1 > MEM_ENG1_THRESH, then table 2.
//
// Block-RAM form: each table read is registered (d* <= table[word]), which is
// what synthesis maps to M10K. a0/a1 hold exactly what the rng output
// registers hold (they load rand*_next, and 0 in reset, as those registers
// do) and d* = table[that word], so energy_out comes out on the same cycle,
// with the same value, as when the tables were read straight from rand0..2.
// In reset d* read table[0]; only at power-up, before the first clock edge,
// they hold 0 (the M10K power-up value), which no sample shows as long as the
// design is reset for at least one clock.
module energy_icdf
#(
	parameter RAND_IN_BITS = 10,
	parameter ENG_OUT_BITS = 13,
	parameter MEM_ENG_SIZE = 2**10,
	parameter MEM_ENG0 = "energy_icdf_a13_0.mif",
	parameter MEM_ENG1 = "energy_icdf_a13_1.mif",
	parameter MEM_ENG2 = "energy_icdf_a13_2.mif",
	parameter MEM_ENG0_THRESH = 1001,
	parameter MEM_ENG1_THRESH = 985
)
(
	input clk, rst,
	input [RAND_IN_BITS-1:0] rand0_next, rand1_next, rand2_next,   // rng rand_next
	output reg [ENG_OUT_BITS-1:0] energy_out = 0
);

reg [ENG_OUT_BITS-1:0] mem_eng0 [0:MEM_ENG_SIZE-1];
reg [ENG_OUT_BITS-1:0] mem_eng1 [0:MEM_ENG_SIZE-1];
reg [ENG_OUT_BITS-1:0] mem_eng2 [0:MEM_ENG_SIZE-1];

// a0/a1 hold what the rng output registers hold, and d0..d2 hold the table
// entry of that same rng word (d2 needs no address register of its own):
// both follow them, including their reset to 0. Registering the READ
// (d* <= table[rand*_next]) instead of the address is the form Quartus maps
// to M10K; with only the address registered it keeps the tables in logic.
reg [RAND_IN_BITS-1:0] a0 = 0, a1 = 0;          // only a0/a1 meet the thresholds
reg [ENG_OUT_BITS-1:0] d0 = 0, d1 = 0, d2 = 0;   // power-up 0, as the M10K
initial begin
	$readmemb(MEM_ENG0, mem_eng0);
	$readmemb(MEM_ENG1, mem_eng1);
	$readmemb(MEM_ENG2, mem_eng2);
end

// In reset the rng output registers go to 0, so a* go to 0 and d* read
// table[0]: after any reset (at power-up or later) the tables replay the run.
wire [RAND_IN_BITS-1:0] r0 = rst ? {RAND_IN_BITS{1'b0}} : rand0_next;
wire [RAND_IN_BITS-1:0] r1 = rst ? {RAND_IN_BITS{1'b0}} : rand1_next;
wire [RAND_IN_BITS-1:0] r2 = rst ? {RAND_IN_BITS{1'b0}} : rand2_next;
always @(posedge clk) begin
	a0 <= r0;
	a1 <= r1;
	d0 <= mem_eng0[r0];
	d1 <= mem_eng1[r1];
	d2 <= mem_eng2[r2];
end

always @(posedge clk or posedge rst) begin
	if (rst)
		energy_out <= 0;
	else if (a0 > MEM_ENG0_THRESH)
		energy_out <= (a1 > MEM_ENG1_THRESH) ? d2 : d1;
	else
		energy_out <= d0;
end

endmodule
