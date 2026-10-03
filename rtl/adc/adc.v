`timescale 1ns/100ps

// Clips the shaper output to the ADC range [0, 2**BITS_OUT-1] after adding
// the programmable pedestal offset and dropping the fixed-point scale
// (>>> G_OUT_LOG).
//
// ROUND = 1 (default since 2026-10-03): the fraction is rounded to the nearest
// count (half up), as a real ADC does. ROUND = 0: it is truncated toward minus
// infinity, which reads on average 0.5 count low; that was the behaviour until
// 2026-10-03 and the paper build keeps it (macro USE_ADC_FLOOR).
module adc
#(
	parameter BITS_IN = 30,
	parameter BITS_OUT = 12,
	parameter G_OUT_LOG = 10,
	parameter ROUND = 1
)
(
	input  clk, rst,
	input  signed [BITS_IN-1:0] in,
	input  signed [BITS_IN-1:0] offset,
	output reg [BITS_OUT-1:0] out = 0
);

localparam integer ADC_MAX = 2**BITS_OUT - 1;

wire signed [BITS_IN-1:0] half      = ROUND ? (1 <<< (G_OUT_LOG-1)) : 0;
wire signed [BITS_IN-1:0] in_offset = (in + (offset <<< G_OUT_LOG) + half) >>> G_OUT_LOG;

always @(posedge clk or posedge rst) begin
	if (rst) begin
		out <= 0;
	end
	else begin
		if (in_offset < 0)
			out <= 0;
		else if (in_offset > ADC_MAX)
			out <= {BITS_OUT{1'b1}};       // ADC_MAX
		else
			out <= in_offset[BITS_OUT-1:0]; // 0..ADC_MAX here, fits
	end
end

endmodule
