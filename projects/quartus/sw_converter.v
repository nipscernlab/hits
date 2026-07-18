`timescale 1ns/100ps

module sw_converter
#(
	parameter IN_SIZE = 4,
	parameter OUT_SIZE = 7
)
(
	input clk, rst,
	input [IN_SIZE-1:0] in,
	output reg [OUT_SIZE-1:0] occ_out = 0
);


always @(posedge clk or posedge rst)
begin
	if (rst) begin
		occ_out <= 1'd0;
	end else begin
		
		if (in[0] == 1) begin
			occ_out <= 1;
		end
		else begin
			if (in[1] == 1) begin
				occ_out <= 32;
			end
			else begin
			
				if (in[2] == 1) begin
					occ_out <= 32;
				end
				else begin
					if (in[3] == 1) begin
						occ_out <= 64;
					end
					else begin
						occ_out <= 121;
					end
				end
			
			end
		end
	end
	
end

endmodule

