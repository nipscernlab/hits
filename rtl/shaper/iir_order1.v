`timescale 1ns/100ps

module iir_order1

#(
	parameter BITS_IN = 13,
	parameter G_OUT_LOG = 10,
	parameter signed [15:0] b0 =   785,
	parameter signed [15:0] a1 =  -1366
)

(

	

	input  clock, rst,
	input  signed [BITS_IN-1:0] in,
	output signed [BITS_IN+16:0] out
	);
	// Coefficients are 16-bit signed (the largest, 3362, needs 13): as 32-bit
	// integers they made every product a 32-bit expression truncated into the
	// 30-bit wires. The low 30 bits are the same either way.
	
	reg signed  [BITS_IN+16:0] ry = 0;
	wire signed [BITS_IN+16:0] yz;
	wire signed [BITS_IN+G_OUT_LOG+16:0] yp;
		
	
	
	assign yz =   b0*in;
	assign yp = - a1*ry;
	// yp >>> G_OUT_LOG kept to the width of out: yp[top:G_OUT_LOG]
	assign out =   yz + $signed(yp[BITS_IN+G_OUT_LOG+16:G_OUT_LOG]);
	
	// reset clears the state: the tail of earlier pulses does not cross a reset
	always @(posedge clock or posedge rst)
	begin
		if (rst)
			ry <= 0;
		else
			ry <= out;
	end
	
	
endmodule