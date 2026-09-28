`timescale 1ns/100ps

// Leap-forward pseudo-random word generator: ONE lfsr42 per rng, advanced
// RAND_OUT_SIZE steps per clock, so each word is a fresh block of the
// m-sequence and consecutive words never share a bit. Selected by
// RNG_TYPE = "leap" in rng.v.
//
// Validated 2026-09-28 against the round-robin bank (200 LHC orbits, 713k
// cycles): hit rates on filled slots within 1 sigma of occupancy/128, energy
// and noise distributions against the ones the tables define (chi2 52.9 and
// 47.8, df 49), and no autocorrelation above noise at lags 1..10, where the
// round-robin bank shows +0.009 at lag 7. Area: ~25 ALUTs and 42 + W registers
// per rng, against ~150 ALUTs and ~250 registers.
//
// Uses only SEED0 (the other seeds of rng.v are ignored): the rngs of the
// simulator have different SEED0, so they sit at unrelated phases of the
// m-sequence.
//
// Output registers as in rng_round_robin: rand_out is 0 in reset and takes
// rand_next at each clock, so the ICDF tables, which register rand_next
// themselves, see exactly what rand_out holds.
module rng_leap
#(
	parameter RAND_OUT_SIZE = 7,
	parameter [41:0] SEED0 = 42'd461934351
)
(
	input clk, rst,
	output reg [RAND_OUT_SIZE-1:0] rand_out = 0,
	output [RAND_OUT_SIZE-1:0] rand_next   // rand_out of the next cycle
);

reg  [41:0] state = SEED0;
wire [41:0] step [0:RAND_OUT_SIZE];      // step[k] = state advanced k steps
assign step[0] = state;

genvar k;
generate
	for (k = 0; k < RAND_OUT_SIZE; k = k + 1) begin : leap
		lfsr42 one (.state(step[k]), .next(step[k+1]));
	end
endgenerate

always @(posedge clk or posedge rst) begin
	if (rst) begin
		state    <= SEED0;
		rand_out <= 0;          // back to the power-up value: a reset replays the run
	end else begin
		state    <= step[RAND_OUT_SIZE];
		rand_out <= rand_next;
	end
end

// the word of this cycle: the lowest bits of the current state; the next
// RAND_OUT_SIZE steps shift all of them out, so no bit is ever reused
assign rand_next = state[RAND_OUT_SIZE-1:0];

// synthesis translate_off
initial begin
	if (SEED0 == 0) begin
		$display("ERROR: rng_leap %m has a zero SEED0: the LFSR would never leave 0");
		$finish;
	end
	if (RAND_OUT_SIZE > 42) begin
		$display("ERROR: rng_leap %m: RAND_OUT_SIZE %0d > 42 would reuse bits", RAND_OUT_SIZE);
		$finish;
	end
end
// synthesis translate_on

endmodule
