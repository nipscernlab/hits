`timescale 1ns/100ps

// PZC variant: corrects the accumulator with a fixed running mean of the
// negative samples (no bunch-train gating, no pedestal tracking).
module pzc_media_fixa
#(
	parameter NBITS_IN  = 12,          // input data width
	parameter NBITS_OUT = 28,          // output data width
	parameter M_FACTOR  = 454,         // PZC M factor
	parameter K_CORR = 2**4            // negative samples before a correction
)
(
	input                              clk, rst,
	input   signed    [NBITS_IN  -1:0] in,
	output signed    [NBITS_OUT -1:0] io_out
);

reg signed [NBITS_OUT -1:0] out_delay = 0;

reg [$clog2(K_CORR):0] cont1 = 0;      // negative-sample counter


reg signed [NBITS_OUT - 1:0] soma = 0; // sum of negative samples
reg signed [NBITS_OUT -1:0] m_out = 0; // accumulator correction


always @(posedge clk or posedge rst) 
begin
	if(rst) begin
		out_delay <= 0;
		cont1 <= 0;
	end
	else
	begin		
		out_delay <= in + out_delay - m_out;
		
		if (io_out < 0) begin
			cont1 = cont1 + 1'd1;
			soma <= soma + io_out;
		end
		
		if (cont1 == K_CORR) begin
			m_out <= soma >>> $clog2(K_CORR);
			cont1 <= 0;
			soma <= 0;
		end
		else begin
			m_out <= 0;
		end
		
	end
end


assign io_out = in + out_delay + M_FACTOR * in - m_out;


endmodule