`timescale 1ns/100ps

// Round-robin selector over the LFSR bank: each clock cycle outputs the next
// of the num_rands input words, cycling 1, 2, ..., num_rands-1, 0, 1, ...
module select_rand
#(
	parameter num_rands = 5,
	parameter DATA_OUT_SIZE = 7
)
(
	input clk, rst,
	input [num_rands*DATA_OUT_SIZE-1:0] in,
	output reg [DATA_OUT_SIZE-1:0] out = 0
);

localparam SEL_BITS = $clog2(num_rands);

reg [SEL_BITS-1:0] selector = 0;
wire [SEL_BITS-1:0] selector_next =
	(selector + 1'd1 == num_rands) ? {SEL_BITS{1'b0}} : selector + 1'd1;

always @(posedge clk or posedge rst)
begin
	if (rst) begin
		selector <= 0;
	end
	else begin
		selector <= selector_next;
		out <= in[selector_next*DATA_OUT_SIZE +: DATA_OUT_SIZE];
	end
end

endmodule
