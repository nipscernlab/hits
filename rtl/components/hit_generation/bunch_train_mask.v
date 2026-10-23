`timescale 1ns/100ps

// The mask is a RAM initialized from BUNCH_MEM. The write port (wr_en, one bit per
// write) and orbit_last, the last position of the orbit (its length minus 1, at
// most BUNCH_POS-1), come from the configuration bus (docs/develop/config-bus.md);
// with the bus idle they stay at 0 and BUNCH_POS-1, which gives the ROM and the orbit of before.
// orbit_last is changed only while the simulation is stopped (in reset).
module bunch_train_mask
#(
	parameter BUNCH_MEM = "bunch_train_mask.mif",
	parameter BUNCH_POS = 3564
)
(
	input clk,rst,
	input [$clog2(BUNCH_POS)-1:0] orbit_last,
	input wr_en,
	input [$clog2(BUNCH_POS)-1:0] wr_addr,
	input wr_data,
	output reg out = 0
);

// [0:0], not a bare `reg mask [...]`: Vivado ignores $readmemb into a memory of
// scalar elements ("[Synth 8-2898] ignoring malformed $readmem task: invalid memory
// name") and leaves the mask empty, so no hit would ever pass (2026-10-17).
// Icarus and Quartus read either form; the contents are the same.
reg [0:0] mask [0:BUNCH_POS-1];

reg [$clog2(BUNCH_POS)-1:0] position = 0;


initial begin
	$readmemb(BUNCH_MEM, mask);
end

always @(posedge clk)
	if (wr_en) mask[wr_addr] <= wr_data;


always@(posedge clk or posedge rst) begin

	if (rst) begin
		position <= 0;
		out <= 0;
	end
	else begin
	
		out <= mask[position];
	
		position <= position + 1'd1;
		
		if (position == orbit_last) begin
			position <= 0;
		end
		
	end
	

end

endmodule

