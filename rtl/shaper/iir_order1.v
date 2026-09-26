`timescale 1ns/100ps

module iir_order1

#(
	parameter BITS_IN = 33,
	parameter G_OUT_LOG = 10,
	parameter signed b0 =   785,
	parameter signed a1 =  -1366
)

(

	

	input  clock, 
	input  signed [BITS_IN-1:0] in,
	output signed [BITS_IN+16:0] out
	);
	
	reg signed  [BITS_IN+16:0] ry = 0;
	wire signed [BITS_IN+16:0] yz;
	wire signed [BITS_IN+G_OUT_LOG+16:0] yp;
		
	
	
	assign yz =   b0*in;
	assign yp = - a1*ry;
	assign out =   yz + (yp >>> G_OUT_LOG);
	
	always @(posedge clock)
	begin
		ry <= out;
	end
	
	
endmodule