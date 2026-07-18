`timescale 1ns/100ps

// Clips the shaper output to the ADC range [0, 2**BITS_OUT-1] after adding
// the programmable pedestal offset and dropping the fixed-point scale
// (>>> G_OUT_LOG).
module clip_shaper
#(
	parameter BITS_IN = 34,
	parameter BITS_OUT = 12,
	parameter G_OUT_LOG = 10
)
(
	input  clk, rst,
	input  signed [BITS_IN-1:0] in,
	input  signed [BITS_IN-1:0] offset,
	output reg [BITS_OUT-1:0] out = 0
);

localparam integer ADC_MAX = 2**BITS_OUT - 1;

wire signed [BITS_IN-1:0] in_offset = (in + (offset <<< G_OUT_LOG)) >>> G_OUT_LOG;

always @(posedge clk or posedge rst) begin
	if (rst) begin
		out <= 0;
	end
	else begin
		if (in_offset < 0)
			out <= 0;
		else if (in_offset > ADC_MAX)
			out <= ADC_MAX;
		else
			out <= in_offset;
	end
end

endmodule
