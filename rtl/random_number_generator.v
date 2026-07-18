`timescale 1ns/100ps

module random_number_generator
#(
	parameter RAND_OUT_SIZE = 7,
	parameter SEED0 = 64'd461934351,
	parameter SEED1 = 64'd363409739,
	parameter SEED2 = 64'd209805534,
	parameter SEED3 = 64'd3049884771,
	parameter SEED4 = 64'd2859598492,
	parameter SEED5 = 64'd352859598492,
	parameter SEED6 = 64'd42859998594
)
(
	input clk, rst,
	output [RAND_OUT_SIZE-1:0] rand_out
);
	


wire [RAND_OUT_SIZE-1:0] rand0, rand1, rand2, rand3, rand4,rand5,rand6;


rand_LFSR
#(
	.seed(SEED0),
	.DATA_OUT_SIZE(RAND_OUT_SIZE)
)
mod_rand0
(
	.clk(clk),
	.rst(rst),
	.rand_out(rand0)
);

rand_LFSR
#(
	.seed(SEED1),
	.DATA_OUT_SIZE(RAND_OUT_SIZE)
)
mod_rand1
(
	.clk(clk),
	.rst(rst),
	.rand_out(rand1)
);


rand_LFSR
#(
	.seed(SEED2),
	.DATA_OUT_SIZE(RAND_OUT_SIZE)
)
mod_rand2
(
	.clk(clk),
	.rst(rst),
	.rand_out(rand2)
);

rand_LFSR
#(
	.seed(SEED3),
	.DATA_OUT_SIZE(RAND_OUT_SIZE)
)
mod_rand3
(
	.clk(clk),
	.rst(rst),
	.rand_out(rand3)
);


rand_LFSR
#(
	.seed(SEED4),
	.DATA_OUT_SIZE(RAND_OUT_SIZE)
)
mod_rand4
(
	.clk(clk),
	.rst(rst),
	.rand_out(rand4)
);

rand_LFSR
#(
	.seed(SEED5),
	.DATA_OUT_SIZE(RAND_OUT_SIZE)
)
mod_rand5
(
	.clk(clk),
	.rst(rst),
	.rand_out(rand5)
);

rand_LFSR
#(
	.seed(SEED6),
	.DATA_OUT_SIZE(RAND_OUT_SIZE)
)
mod_rand6
(
	.clk(clk),
	.rst(rst),
	.rand_out(rand6)
);


wire [7*RAND_OUT_SIZE-1:0] rand_in = {rand6,rand5,rand4,rand3,rand2,rand1,rand0};


select_rand
#(
	.num_rands(7),
	.DATA_OUT_SIZE(RAND_OUT_SIZE)
) rand_final
(
	.clk(clk), 
	.rst(rst),
	.in(rand_in),
	.out(rand_out)
);


endmodule