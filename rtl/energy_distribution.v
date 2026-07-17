`timescale 1ns/100ps

module energy_distribution
#(
	parameter RAND_IN_BITS = 10,
	parameter ENG_OUT_BITS = 12,
	parameter MEM_ENG_SIZE = 2**10,
	parameter MEM_ENG0 = "A13_PART1.mif",
	parameter MEM_ENG1 = "A13_PART2.mif",
	parameter MEM_ENG2 = "A13_PART3.mif",
	parameter MEM_ENG0_THRESH = 1001,
	parameter MEM_ENG1_THRESH = 985
)
(
	input clk, rst,
	input [RAND_IN_BITS-1:0] rand0, rand1,rand2,
	output reg [ENG_OUT_BITS-1:0] energy_out = 0
);


reg [ENG_OUT_BITS-1:0] mem_eng0 [0:MEM_ENG_SIZE-1];
reg [ENG_OUT_BITS-1:0] mem_eng1 [0:MEM_ENG_SIZE-1];
reg [ENG_OUT_BITS-1:0] mem_eng2 [0:MEM_ENG_SIZE-1];


initial begin
	$readmemb(MEM_ENG0, mem_eng0);
	$readmemb(MEM_ENG1, mem_eng1);
	$readmemb(MEM_ENG2, mem_eng2);
end

always @ (posedge clk or posedge rst) begin
	if (rst) begin
		energy_out <= 0;
	end
	else begin
		
		if (rand0 > MEM_ENG0_THRESH) begin
			
			if (rand1 > MEM_ENG1_THRESH) begin
				energy_out <= mem_eng2[rand2];
			end
			else begin
				energy_out <= mem_eng1[rand1];			
			end
			
		end
		else begin
			energy_out <= mem_eng0[rand0];
		end		
		
	end
	
end



endmodule