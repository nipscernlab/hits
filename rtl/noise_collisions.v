`timescale 1ns/100ps

module noise_collisions
#(
	parameter RAND_BITS = 10,
	parameter NOISE_OUT_BITS = 15,
	parameter MEM_NOISE_SIZE = 2**10,
	parameter MEM_NOISE0 = "NOISE_PART1.mif",
	parameter MEM_NOISE1 = "NOISE_PART2.mif",
	parameter MEM_NOISE2 = "NOISE_PART3.mif",
	parameter MEM_NOISE0_THRESH = 1007,    // 8 ADC (the earlier 2 ADC setting used 1014/1018)
	parameter MEM_NOISE1_THRESH = 1007     // 8 ADC
)
(
	input clk, rst,
	output signed [NOISE_OUT_BITS-1:0] noise_out
);


wire [RAND_BITS-1:0] rand0, rand1,rand2;
wire rand3;

random_number_generator
#(
	.RAND_OUT_SIZE(RAND_BITS),
	.LFSR_B(42),
	.SEED0(64'd3385518173586546),
	.SEED1(64'd3257678097006247),
	.SEED2(64'd1664473063922978),
	.SEED3(64'd2714018771534493),
	.SEED4(64'd4331765364734975),
	.SEED5(64'd3402324907939173),
	.SEED6(64'd1799718571452818)
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
	.SEED0(64'd551112509180781),
	.SEED1(64'd233547771528969),
	.SEED2(64'd2861039761049085),
	.SEED3(64'd3889845561991016),
	.SEED4(64'd2087774526352312),
	.SEED5(64'd1129108949171845),
	.SEED6(64'd4160722510354627)
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
	.SEED0(64'd267283878329760),
	.SEED1(64'd1459877861036897),
	.SEED2(64'd2178239822101905),
	.SEED3(64'd2324069583403116),
	.SEED4(64'd181753746744021),
	.SEED5(64'd416767256544381),
	.SEED6(64'd1416850994240968)
) rng2
(
	.clk(clk), 
	.rst(rst),
	.rand_out(rand2)
);

random_number_generator
#(
	.RAND_OUT_SIZE(1),
	.LFSR_B(42),
	.SEED0(64'd2007696818806566),
	.SEED1(64'd1332771774909742),
	.SEED2(64'd2539737469039079),
	.SEED3(64'd3429572373385172),
	.SEED4(64'd3852594244376466),
	.SEED5(64'd3530743663732372),
	.SEED6(64'd2041128471816763)
) rng3
(
	.clk(clk), 
	.rst(rst),
	.rand_out(rand3)
);

noise_distribution
#(
	.RAND_IN_BITS(RAND_BITS),
	.NOISE_OUT_BITS(NOISE_OUT_BITS),
	.MEM_NOISE_SIZE(MEM_NOISE_SIZE),
	.MEM_NOISE0(MEM_NOISE0),
	.MEM_NOISE1(MEM_NOISE1),
	.MEM_NOISE2(MEM_NOISE2),
	.MEM_NOISE0_THRESH(MEM_NOISE0_THRESH),
	.MEM_NOISE1_THRESH(MEM_NOISE1_THRESH)
)noise_dist
(
	.clk(clk),
	.rst(rst),
	.rand0(rand0),
	.rand1(rand1),
	.rand2(rand2),
	.rand3(rand3),
	.noise_out(noise_out)
);

endmodule