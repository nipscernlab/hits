`timescale 1ns/100ps

// Round-robin selector over the LFSR bank: each clock cycle outputs the next
// of the num_rands input words, cycling 1, 2, ..., num_rands-1, 0, 1, ...
//
// `out_next` is the word `out` takes at the next clock edge (outside reset).
// A consumer that needs the value one register earlier uses it: the ICDF
// tables register it as their own read address, which is what lets synthesis
// place them in block RAM without adding a cycle of latency.
module round_robin
#(
	parameter num_rands = 5,
	parameter DATA_OUT_SIZE = 7
)
(
	input clk, rst,
	input [num_rands*DATA_OUT_SIZE-1:0] in,
	output reg [DATA_OUT_SIZE-1:0] out = 0,
	output [DATA_OUT_SIZE-1:0] out_next
);

localparam SEL_BITS = $clog2(num_rands);

reg [SEL_BITS-1:0] selector = 0;
wire [SEL_BITS-1:0] selector_next =
	(selector + 1'd1 == num_rands) ? {SEL_BITS{1'b0}} : selector + 1'd1;

assign out_next = in[selector_next*DATA_OUT_SIZE +: DATA_OUT_SIZE];

always @(posedge clk or posedge rst)
begin
	if (rst) begin
		selector <= 0;
	end
	else begin
		selector <= selector_next;
		out <= out_next;
	end
end

endmodule
