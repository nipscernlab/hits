`timescale 1ns/100ps

// Energy amplitude by inverse CDF, split across three tables (multi-memory
// approach): table 0 unless rand0 > MEM_ENG0_THRESH, then table 1 unless
// rand1 > MEM_ENG1_THRESH, then table 2.
//
// Block-RAM form: each table read is registered (d* <= table[rand*_next]),
// which is what synthesis maps to M10K. a0..a2 hold exactly what the rng
// output registers hold (they load rand*_next under the same condition,
// outside reset) and d* = table[a*], so energy_out comes out on the same
// cycle, with the same value, as when the tables were read straight from
// rand0..rand2.
//
// One accepted exception (2026-09-26): before their first load d0..d2 are 0,
// the M10K power-up value, where table[0] was read before. It shows only in
// the first energy_out sample after power-up (table 0 entry 0 is 1, so that
// sample is 0 instead of 1); a reset later in the run holds a*/d* like the
// rng registers and changes nothing.
module energy_icdf
#(
	parameter RAND_IN_BITS = 10,
	parameter ENG_OUT_BITS = 12,
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

// a0..a2 hold what the rng output registers hold, and d0..d2 = table[a*]:
// both load under the same condition, outside reset. Registering the READ
// (d* <= table[rand*_next]) instead of the address is the form Quartus maps
// to M10K; with only the address registered it keeps the tables in logic.
reg [RAND_IN_BITS-1:0] a0 = 0, a1 = 0, a2 = 0;
reg [ENG_OUT_BITS-1:0] d0 = 0, d1 = 0, d2 = 0;   // power-up 0, as the M10K
initial begin
	$readmemb(MEM_ENG0, mem_eng0);
	$readmemb(MEM_ENG1, mem_eng1);
	$readmemb(MEM_ENG2, mem_eng2);
end

always @(posedge clk) begin
	if (!rst) begin
		a0 <= rand0_next;
		a1 <= rand1_next;
		a2 <= rand2_next;
		d0 <= mem_eng0[rand0_next];
		d1 <= mem_eng1[rand1_next];
		d2 <= mem_eng2[rand2_next];
	end
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
