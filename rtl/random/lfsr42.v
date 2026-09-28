`timescale 1ns/100ps

// ONE STEP of the Fibonacci LFSR of the group's papers (SBCCI 2025 / Applied
// Sciences 2026), primitive polynomial
//
//   x^42 + x^27 + x^24 + x^14 + x^8 + x + 1
//
// Combinational: `next` is the state that follows `state`. The registers live
// in rng.v, which keeps a bank of 7 of these LFSRs. The width is FIXED at 42
// bits: the tap indices below are specific to this polynomial. With any
// non-zero seed the sequence has maximal length, period 2^42 - 1 (~1.27 days
// at 40 MHz).
module lfsr42
(
	input  [41:0] state,
	output [41:0] next
);

// recurrence a[n+42] = a[n+27] ^ a[n+24] ^ a[n+14] ^ a[n+8] ^ a[n+1] ^ a[n]
wire feedback = state[27] ^ state[24] ^ state[14] ^ state[8] ^ state[1] ^ state[0];

assign next = {feedback, state[41:1]};

endmodule
