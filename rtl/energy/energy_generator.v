`timescale 1ns/100ps

// Energy amplitude of each collision, one sample per clock, in whole ADC counts.
//   ENERGY_TYPE = "seg"   : energy_seg.v, a segmented inverse CDF (polynomial per
//                           segment) from one 32-bit xoshiro word; the spectrum
//                           is the ROM MEM_SEG. Needs RNG_TYPE = "xoshiro".
//   ENERGY_TYPE = "tables": energy_icdf.v, the three inverse-CDF tables used until
//                           2026-10-08; the round_robin and leap generators and
//                           the paper build use these.
module energy_generator
#(
	parameter RNG_TYPE = "xoshiro",       // rng kind, see rtl/random/rng.v
	parameter ENERGY_TYPE = "seg",        // "seg" or "tables", see above
	parameter MEM_SEG = "energy_seg_default.mif",
	parameter RAND_BITS = 10,
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
	output [ENG_OUT_BITS-1:0] energy_out
);

generate
if (ENERGY_TYPE == "seg") begin : seg
	if (RNG_TYPE != "xoshiro") begin : erro
		ERROR_energy_generator_ENERGY_TYPE_seg_needs_RNG_TYPE_xoshiro e ();
	end
	// the same generator and seeds as the xoshiro table path; the word is the
	// 32 top bits of its result (the tables used the top 30)
	wire [31:0] w_out;
	rng
	#(
		.RNG_TYPE(RNG_TYPE),
		.RAND_OUT_SIZE(32),
		.SEED0(42'd3890346747),
		.SEED1(42'd545404224),
		.SEED2(42'd3922919432),
		.SEED3(42'd2715962282)
	) rng_all
	(
		.clk(clk),
		.rst(rst),
		.rand_out(w_out),
		.rand_next()
	);
	energy_seg
	#(
		.ENG_OUT_BITS(ENG_OUT_BITS),
		.MEM_SEG(MEM_SEG)
	) eng_seg
	(
		.clk(clk),
		.rst(rst),
		.rnd(w_out),
		.energy_out(energy_out)
	);
end else begin : tables



wire [RAND_BITS-1:0] rand0_next, rand1_next, rand2_next;   // next-cycle rng words: the table read addresses

// One draw = three 10-bit words (table selection and indices).
//   xoshiro: ONE generator per stage, its 30 top result bits cut into the three
//            words (a good generator's bits are independent; checked with
//            PractRand on the 30-bit words). 1 generator instead of 3.
//   others : one generator per word, as always (a wider LFSR word would share
//            more bits between reads), so their sequences do not change.
if (RNG_TYPE == "xoshiro") begin : per_stage
	wire [3*RAND_BITS-1:0] w_next;
	rng
	#(
		.RNG_TYPE(RNG_TYPE),
		.RAND_OUT_SIZE(3*RAND_BITS),
		.SEED0(42'd3890346747),
		.SEED1(42'd545404224),
		.SEED2(42'd3922919432),
		.SEED3(42'd2715962282)
	) rng_all
	(
		.clk(clk),
		.rst(rst),
		.rand_out(),
		.rand_next(w_next)
	);
	assign rand0_next = w_next[3*RAND_BITS-1 -: RAND_BITS];
	assign rand1_next = w_next[2*RAND_BITS-1 -: RAND_BITS];
	assign rand2_next = w_next[RAND_BITS-1:0];
end else begin : per_word
	rng
	#(
		.RNG_TYPE(RNG_TYPE),
		.RAND_OUT_SIZE(RAND_BITS),
		.SEED0(42'd3890346747),
		.SEED1(42'd545404224),
		.SEED2(42'd3922919432),
		.SEED3(42'd2715962282),
		.SEED4(42'd418932850),
		.SEED5(42'd1196140743),
		.SEED6(42'd2348838240)
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
		.SEED0(42'd1674021279764),
		.SEED1(42'd454835899247),
		.SEED2(42'd61863771595),
		.SEED3(42'd2339978760085),
		.SEED4(42'd217475151474),
		.SEED5(42'd2384886375216),
		.SEED6(42'd2219331443444)
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
		.SEED0(42'd1639350413255),
		.SEED1(42'd2244364659078),
		.SEED2(42'd2025685893251),
		.SEED3(42'd2945626747716),
		.SEED4(42'd1449276989073),
		.SEED5(42'd1282470172806),
		.SEED6(42'd1954236685586)
	) rng2
	(
		.clk(clk), 
		.rst(rst),
		.rand_out(),
		.rand_next(rand2_next)
	);
end

energy_icdf
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
	.rand0_next(rand0_next),
	.rand1_next(rand1_next),
	.rand2_next(rand2_next),
	.energy_out(energy_out)
);
end
endgenerate

endmodule
