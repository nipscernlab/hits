`timescale 1ns/100ps

module bunch_train_mask
#(
	parameter BUNCH_MEM = "bunch_train_mask.mif",
	parameter BUNCH_POS = 3564
)
(
	input clk,rst,
	output reg out = 0
);

reg mask [0:BUNCH_POS-1];

reg [$clog2(BUNCH_POS)-1:0] position = 0;


initial begin
	$readmemb(BUNCH_MEM, mask);
end


always@(posedge clk or posedge rst) begin

	if (rst) begin
		position <= 0;
		out <= 0;
	end
	else begin
	
		out <= mask[position];
	
		position <= position + 1'd1;
		
		if (position == BUNCH_POS-1) begin
			position <= 0;
		end
		
	end
	

end

endmodule

