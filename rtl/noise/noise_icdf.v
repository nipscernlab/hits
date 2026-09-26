`timescale 1ns/100ps

// Noise magnitude by inverse CDF, split across three tables (same scheme as
// energy_icdf: table 0 unless rand0 > MEM_NOISE0_THRESH, then table 1 unless
// rand1 > MEM_NOISE1_THRESH, then table 2), with a random sign from rand3.
//
// Block-RAM form, as in energy_icdf: registered table reads d* = table[a*],
// where a0..a2 load rand*_next under the same condition as the rng output
// registers, so noise_out keeps its value and its cycle.
module noise_icdf
#(
	parameter RAND_IN_BITS = 10,
	parameter NOISE_OUT_BITS = 15,
	parameter MEM_NOISE_SIZE = 2**10,
	parameter MEM_NOISE0 = "noise_icdf0.mif",
	parameter MEM_NOISE1 = "noise_icdf1.mif",
	parameter MEM_NOISE2 = "noise_icdf2.mif",
	parameter MEM_NOISE0_THRESH = 1007,    // 8 ADC (the earlier 2 ADC setting used 1014/1018)
	parameter MEM_NOISE1_THRESH = 1007     // 8 ADC
)
(
	input clk, rst,
	input [RAND_IN_BITS-1:0] rand0_next, rand1_next, rand2_next,   // rng rand_next
	input rand3,                                                   // sign (1 = negative)
	output reg [NOISE_OUT_BITS-1:0] noise_out = 0
);

reg [NOISE_OUT_BITS-1-1:0] mem_noise0 [0:MEM_NOISE_SIZE-1];
reg [NOISE_OUT_BITS-1-1:0] mem_noise1 [0:MEM_NOISE_SIZE-1];
reg [NOISE_OUT_BITS-1-1:0] mem_noise2 [0:MEM_NOISE_SIZE-1];

// a0..a2 hold what the rng output registers hold, and d0..d2 = table[a*]:
// both load under the same condition, outside reset. Registering the READ
// (d* <= table[rand*_next]) instead of the address is the form Quartus maps
// to M10K; with only the address registered it keeps the tables in logic.
reg [RAND_IN_BITS-1:0] a0 = 0, a1 = 0, a2 = 0;
reg [NOISE_OUT_BITS-1-1:0] d0 = 0, d1 = 0, d2 = 0;   // power-up 0, as the M10K
initial begin
	$readmemb(MEM_NOISE0, mem_noise0);
	$readmemb(MEM_NOISE1, mem_noise1);
	$readmemb(MEM_NOISE2, mem_noise2);
end

always @(posedge clk) begin
	if (!rst) begin
		a0 <= rand0_next;
		a1 <= rand1_next;
		a2 <= rand2_next;
		d0 <= mem_noise0[rand0_next];
		d1 <= mem_noise1[rand1_next];
		d2 <= mem_noise2[rand2_next];
	end
end

wire [NOISE_OUT_BITS-1-1:0] magnitude =
	(a0 > MEM_NOISE0_THRESH) ? ((a1 > MEM_NOISE1_THRESH) ? d2 : d1) : d0;

always @(posedge clk or posedge rst) begin
	if (rst)
		noise_out <= 0;
	else if (rand3)
		noise_out <= -{1'd0, magnitude};
	else
		noise_out <= {1'd0, magnitude};
end

endmodule
