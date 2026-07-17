`timescale 1ns/100ps

module noise_distribution
#(
	parameter RAND_IN_BITS = 10,
	parameter NOISE_OUT_BITS = 15,
	parameter MEM_NOISE_SIZE = 2**10,
	parameter MEM_NOISE0 = "NOISE_PART1.mif",
	parameter MEM_NOISE1 = "NOISE_PART2.mif",
	parameter MEM_NOISE2 = "NOISE_PART3.mif",
	parameter MEM_NOISE0_THRESH = 1014,
	parameter MEM_NOISE1_THRESH = 1018
)
(
	input clk, rst,
	input [RAND_IN_BITS-1:0] rand0, rand1,rand2,
	input rand3,
	output reg [NOISE_OUT_BITS-1:0] noise_out = 0
);


reg [NOISE_OUT_BITS-1-1:0] mem_noise0 [0:MEM_NOISE_SIZE-1];
reg [NOISE_OUT_BITS-1-1:0] mem_noise1 [0:MEM_NOISE_SIZE-1];
reg [NOISE_OUT_BITS-1-1:0] mem_noise2 [0:MEM_NOISE_SIZE-1];


initial begin
	$readmemb(MEM_NOISE0, mem_noise0);
	$readmemb(MEM_NOISE1, mem_noise1);
	$readmemb(MEM_NOISE2, mem_noise2);
end

always @ (posedge clk or posedge rst) begin
	if (rst) begin
		noise_out <= 0;
	end
	else begin
		
		if (rand0 > MEM_NOISE0_THRESH) begin
			
			if (rand1 > MEM_NOISE1_THRESH) begin
				if (rand3)
					noise_out <= -{1'd0,mem_noise2[rand2]};
				else
					noise_out <= {1'd0,mem_noise2[rand2]};
			end
			else begin
				if (rand3)
					noise_out <= -{1'd0,mem_noise1[rand1]};
				else
					noise_out <= {1'd0,mem_noise1[rand1]};			
			end
			
		end
		else begin
			if (rand3)
				noise_out <= -{1'd0,mem_noise0[rand0]};
			else
				noise_out <= {1'd0,mem_noise0[rand0]};
		end

	end
	
end



endmodule