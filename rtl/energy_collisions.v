`timescale 1ns/100ps

module energy_collisions
#(
	parameter RAND_BITS = 10,
	parameter ENG_OUT_BITS = 12,
	parameter MEM_ENG_SIZE = 2**10,
	parameter MEM_ENG0 = "A13_PART1.mif",
	parameter MEM_ENG1 = "A13_PART2.mif",
	parameter MEM_ENG2 = "A13_PART3.mif",
	parameter MEM_ENG0_THRESH = 1001,
	parameter MEM_ENG1_THRESH = 985
)
(
	input clk, rst,
	output [ENG_OUT_BITS-1:0] energy_out
);


wire [RAND_BITS-1:0] rand0, rand1,rand2;

random_number_generator
#(
	.RAND_OUT_SIZE(RAND_BITS),
	.LFSR_B(42),
	.SEED0(64'd3890346747),
	.SEED1(64'd545404224),
	.SEED2(64'd3922919432),
	.SEED3(64'd2715962282),
	.SEED4(64'd418932850),
	.SEED5(64'd1196140743),
	.SEED6(64'd2348838240)
) rng0
(
	.clk(clk), 
	.rst(rst),
	.rand_out(rand0)
);



random_number_generator
#(
	.RAND_OUT_SIZE(RAND_BITS),
	.LFSR_B(42),
	.SEED0(64'd1674021279764),
	.SEED1(64'd454835899247),
	.SEED2(64'd61863771595),
	.SEED3(64'd2339978760085),
	.SEED4(64'd217475151474),
	.SEED5(64'd2384886375216),
	.SEED6(64'd2219331443444)
) rng1
(
	.clk(clk), 
	.rst(rst),
	.rand_out(rand1)
);




random_number_generator
#(
	.RAND_OUT_SIZE(RAND_BITS),
	.LFSR_B(42),
	.SEED0(64'd1639350413255),
	.SEED1(64'd2244364659078),
	.SEED2(64'd2025685893251),
	.SEED3(64'd2945626747716),
	.SEED4(64'd1449276989073),
	.SEED5(64'd1282470172806),
	.SEED6(64'd1954236685586)
) rng2
(
	.clk(clk), 
	.rst(rst),
	.rand_out(rand2)
);

energy_distribution
#(
	.RAND_IN_BITS(RAND_BITS),
	.ENG_OUT_BITS(ENG_OUT_BITS),
	.MEM_ENG_SIZE(MEM_ENG_SIZE),
	.MEM_ENG0(MEM_ENG0),
	.MEM_ENG1(MEM_ENG1),
	.MEM_ENG2(MEM_ENG2),
	.MEM_ENG0_THRESH(MEM_ENG0_THRESH),
	.MEM_ENG1_THRESH(MEM_ENG1_THRESH)
)eng_dist
(
	.clk(clk),
	.rst(rst),
	.rand0(rand0),
	.rand1(rand1),
	.rand2(rand2),
	.energy_out(energy_out)
);

endmodule