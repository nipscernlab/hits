`timescale 1ns/100ps

// Fibonacci LFSR implementing the primitive polynomial of the group's papers
// (SBCCI 2025 / Applied Sciences 2026):
//
//   x^42 + x^27 + x^24 + x^14 + x^8 + x + 1
//
// Combinational feedback (no extra register in the loop). The width is FIXED at
// 42 bits: the tap indices below are specific to this polynomial, so the width
// is not a parameter. With any non-zero seed the sequence has maximal length,
// period 2^42 - 1 (~1.27 days at 40 MHz).
module rand_LFSR
#(
	parameter seed = 64'd12345,
	parameter DATA_OUT_SIZE = 7
)
(
	input clk, rst,
	output [DATA_OUT_SIZE-1:0] rand_out
);

localparam LFSR_BITS = 42;

reg [LFSR_BITS-1:0] lfsr = seed;  // shift register, seeded with a non-zero value

// recurrence a[n+42] = a[n+27] ^ a[n+24] ^ a[n+14] ^ a[n+8] ^ a[n+1] ^ a[n]
wire feedback = lfsr[27] ^ lfsr[24] ^ lfsr[14] ^ lfsr[8] ^ lfsr[1] ^ lfsr[0];

always @(posedge clk or posedge rst) begin
	if (rst) begin
		lfsr <= seed;
	end else begin
		lfsr <= {feedback, lfsr[LFSR_BITS-1:1]};
	end
end

assign rand_out = lfsr[DATA_OUT_SIZE-1:0];

endmodule
