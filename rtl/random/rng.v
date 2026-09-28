`timescale 1ns/100ps

// Pseudo-random word generator of the simulator: picks one implementation by
// the RNG_TYPE parameter, the way the shaper is picked among rtl/shaper/.
//
//   "round_robin" (default) : rng_round_robin.v - 7 LFSRs read in round robin,
//                             the generator of the SBCCI 2025 paper
//   "leap"                  : rng_leap.v - one LFSR advanced RAND_OUT_SIZE
//                             steps per clock; ~6x less logic and no lag-7
//                             overlap between words (see both headers)
//   "xoshiro"               : rng_xoshiro.v - xoshiro128** (Blackman & Vigna),
//                             non-linear output scrambler
//
// RNG_TYPE comes down from hits_simulator, so the whole simulator uses one
// kind. WARNING: each kind has its OWN goldens in verification/ (README).
//
// Both kinds have the same ports and the same output timing: rand_out is 0 in
// reset and takes rand_next at each clock.
module rng
#(
	parameter RNG_TYPE = "round_robin",
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
	output [RAND_OUT_SIZE-1:0] rand_next   // rand_out of the next cycle
);

generate
	if (RNG_TYPE == "leap") begin : kind
		rng_leap
		#(
			.RAND_OUT_SIZE(RAND_OUT_SIZE),
			.SEED0(SEED0)
		) gen
		(
			.clk(clk),
			.rst(rst),
			.rand_out(rand_out),
			.rand_next(rand_next)
		);
	end else if (RNG_TYPE == "xoshiro") begin : kind
		rng_xoshiro
		#(
			.RAND_OUT_SIZE(RAND_OUT_SIZE),
			.SEED0(SEED0), .SEED1(SEED1), .SEED2(SEED2), .SEED3(SEED3)
		) gen
		(
			.clk(clk),
			.rst(rst),
			.rand_out(rand_out),
			.rand_next(rand_next)
		);
	end else if (RNG_TYPE == "round_robin") begin : kind
		rng_round_robin
		#(
			.RAND_OUT_SIZE(RAND_OUT_SIZE),
			.SEED0(SEED0), .SEED1(SEED1), .SEED2(SEED2), .SEED3(SEED3),
			.SEED4(SEED4), .SEED5(SEED5), .SEED6(SEED6)
		) gen
		(
			.clk(clk),
			.rst(rst),
			.rand_out(rand_out),
			.rand_next(rand_next)
		);
	end else begin : kind
		// unknown kind: stops the elaboration with a name that says why
		ERROR_rng_RNG_TYPE_must_be_round_robin_leap_or_xoshiro gen ();
	end
endgenerate

endmodule
