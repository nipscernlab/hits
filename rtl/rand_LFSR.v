`timescale 1ns/100ps

// Fibonacci LFSR implementing the primitive polynomial of the group's papers
// (SBCCI 2025 / Applied Sciences 2026):
//
//   x^42 + x^27 + x^24 + x^14 + x^8 + x + 1
//
// Combinational feedback (no extra register in the loop): with LFSR_BITS = 42
// and any non-zero seed the sequence has maximal length, period 2^42 - 1
// (~1.27 days at 40 MHz). Tap indices assume LFSR_BITS = 42.
module rand_LFSR
#(
	parameter seed = 64'd12345,
	parameter DATA_OUT_SIZE = 7,
	parameter LFSR_BITS = 64
)
(
	input clk, rst,
	output [DATA_OUT_SIZE-1:0] rand_out
);

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
