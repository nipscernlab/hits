`timescale 1ns/100ps

// Pseudo-random word generator of the group's papers (SBCCI 2025): a bank of
// 7 lfsr42 with different seeds, read in round robin (one of the 7 per clock
// cycle), which decorrelates consecutive words. Each stage of the simulator
// that draws something (hits, energy, noise) has its own rng with its own
// seeds.
module rng
#(
	parameter RAND_OUT_SIZE = 7,
	parameter [41:0] SEED0 = 42'd461934351,
	parameter [41:0] SEED1 = 42'd363409739,
	parameter [41:0] SEED2 = 42'd209805534,
	parameter [41:0] SEED3 = 42'd3049884771,
	parameter [41:0] SEED4 = 42'd2859598492,
	parameter [41:0] SEED5 = 42'd352859598492,
	parameter [41:0] SEED6 = 42'd42859998594
)
(
	input clk, rst,
	output [RAND_OUT_SIZE-1:0] rand_out,
	output [RAND_OUT_SIZE-1:0] rand_next   // rand_out of the next cycle (see round_robin)
);

localparam N_LFSR = 7;
localparam [N_LFSR*42-1:0] SEEDS = {SEED6, SEED5, SEED4, SEED3, SEED2, SEED1, SEED0};

wire [N_LFSR*RAND_OUT_SIZE-1:0] rand_in;   // word i = output of LFSR i

genvar i;
generate
	for (i = 0; i < N_LFSR; i = i + 1) begin : bank
		lfsr42
		#(
			.seed(SEEDS[i*42 +: 42]),
			.DATA_OUT_SIZE(RAND_OUT_SIZE)
		) lfsr
		(
			.clk(clk),
			.rst(rst),
			.rand_out(rand_in[i*RAND_OUT_SIZE +: RAND_OUT_SIZE])
		);
	end
endgenerate

round_robin
#(
	.num_rands(N_LFSR),
	.DATA_OUT_SIZE(RAND_OUT_SIZE)
) rand_final
(
	.clk(clk),
	.rst(rst),
	.in(rand_in),
	.out(rand_out),
	.out_next(rand_next)
);

endmodule
