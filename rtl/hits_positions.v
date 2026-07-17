`timescale 1ns/100ps

module hits_positions
#(
	parameter IN_SIZE = 7
)
(
	input clk, rst,
	input [IN_SIZE-1:0] in,
	input [IN_SIZE-1:0] occupancy,	
	output reg hit = 0
);

always @(posedge clk or posedge rst)
begin
	if (rst) begin
		hit <= 1'd0;
	end else begin
		
		if (in < occupancy) begin
			hit <= 1'd1;
		end
		else begin
			hit <= 1'd0;
		end
	end
	
end

endmodule


