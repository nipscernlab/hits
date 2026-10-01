`timescale 1ns/100ps

module noise_generator
#(
	parameter RNG_TYPE = "xoshiro",       // rng kind, see rtl/random/rng.v
	parameter RAND_BITS = 10,
	parameter NOISE_OUT_BITS = 17,
	parameter MEM_NOISE_SIZE = 2**10,
	parameter MEM_NOISE0 = "noise_s4_icdf0.mif",
	parameter MEM_NOISE1 = "noise_s4_icdf1.mif",
	parameter MEM_NOISE2 = "noise_s4_icdf2.mif",
	parameter MEM_NOISE_BITS = 10,        // table format, see noise_icdf.v
	parameter MEM_NOISE_FRAC = 5,
	parameter MEM_NOISE0_THRESH = 1007,    // noise_s4 and noise_s8 alike (an earlier 2 ADC set used 1014/1018)
	parameter MEM_NOISE1_THRESH = 1007
)
(
	input clk, rst,
	output signed [NOISE_OUT_BITS-1:0] noise_out
);


// Seeds below are the EFFECTIVE 42-bit values. Until 2026-09-26 they were
// written as wider 64-bit literals that lfsr42 truncated to seed[41:0]; same
// values, same sequences (the originals are in the git history).
wire [RAND_BITS-1:0] rand0_next, rand1_next, rand2_next;   // next-cycle rng words: the table read addresses
wire rand3;

// One draw = three 10-bit words (table selection and indices) + 1 sign bit.
//   xoshiro: ONE generator per stage, its 31 top result bits cut into the three
//            words and the sign (checked with PractRand on the 31-bit words).
//            1 generator instead of 4.
//   others : one generator per word, as always, so their sequences do not change.
generate
if (RNG_TYPE == "xoshiro") begin : per_stage
	wire [3*RAND_BITS:0] w_next, w_out;
	rng
	#(
		.RNG_TYPE(RNG_TYPE),
		.RAND_OUT_SIZE(3*RAND_BITS+1),
		.SEED0(42'd3420406547570),
		.SEED1(42'd3123678789287),
		.SEED2(42'd2011482725666),
		.SEED3(42'd424074183325)
	) rng_all
	(
		.clk(clk),
		.rst(rst),
		.rand_out(w_out),
		.rand_next(w_next)
	);
	assign rand0_next = w_next[3*RAND_BITS -: RAND_BITS];
	assign rand1_next = w_next[2*RAND_BITS -: RAND_BITS];
	assign rand2_next = w_next[RAND_BITS:1];
	assign rand3      = w_out[0];          // sign: registered, as the rng3 output was
end else begin : per_word
	rng
	#(
		.RNG_TYPE(RNG_TYPE),
		.RAND_OUT_SIZE(RAND_BITS),
		.SEED0(42'd3420406547570),
		.SEED1(42'd3123678789287),
		.SEED2(42'd2011482725666),
		.SEED3(42'd424074183325),
		.SEED4(42'd4087597808639),
		.SEED5(42'd2634954855781),
		.SEED6(42'd917548411282)
	) rng0
	(
		.clk(clk), 
		.rst(rst),
		.rand_out(),
		.rand_next(rand0_next)
	);



	rng
	#(
		.RNG_TYPE(RNG_TYPE),
		.RAND_OUT_SIZE(RAND_BITS),
		.SEED0(42'd1356695292781),
		.SEED1(42'd451306440457),
		.SEED2(42'd2309528831485),
		.SEED3(42'd1972446175080),
		.SEED4(42'd3100480089016),
		.SEED5(42'd3209042329221),
		.SEED6(42'd170510850243)
	) rng1
	(
		.clk(clk), 
		.rst(rst),
		.rand_out(),
		.rand_next(rand1_next)
	);




	rng
	#(
		.RNG_TYPE(RNG_TYPE),
		.RAND_OUT_SIZE(RAND_BITS),
		.SEED0(42'd3401087663520),
		.SEED1(42'd4124465861473),
		.SEED2(42'd1206799105425),
		.SEED3(42'd1901025540204),
		.SEED4(42'd1433839788757),
		.SEED5(42'd3350884500605),
		.SEED6(42'd680017665480)
	) rng2
	(
		.clk(clk), 
		.rst(rst),
		.rand_out(),
		.rand_next(rand2_next)
	);

	rng
	#(
		.RNG_TYPE(RNG_TYPE),
		.RAND_OUT_SIZE(1),
		.SEED0(42'd2187609743142),
		.SEED1(42'd163682045230),
		.SEED2(42'd2064632132071),
		.SEED3(42'd3494141235156),
		.SEED4(42'd4303547160466),
		.SEED5(42'd3510361826964),
		.SEED6(42'd434890664507)
	) rng3
	(
		.clk(clk), 
		.rst(rst),
		.rand_out(rand3)
	);
end
endgenerate

noise_icdf
#(
	.RAND_IN_BITS(RAND_BITS),
	.NOISE_OUT_BITS(NOISE_OUT_BITS),
	.MEM_NOISE_SIZE(MEM_NOISE_SIZE),
	.MEM_NOISE0(MEM_NOISE0),
	.MEM_NOISE1(MEM_NOISE1),
	.MEM_NOISE2(MEM_NOISE2),
	.MEM_NOISE_BITS(MEM_NOISE_BITS),
	.MEM_NOISE_FRAC(MEM_NOISE_FRAC),
	.MEM_NOISE0_THRESH(MEM_NOISE0_THRESH),
	.MEM_NOISE1_THRESH(MEM_NOISE1_THRESH)
)noise_dist
(
	.clk(clk),
	.rst(rst),
	.rand0_next(rand0_next),
	.rand1_next(rand1_next),
	.rand2_next(rand2_next),
	.rand3(rand3),
	.noise_out(noise_out)
);

endmodule