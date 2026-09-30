`timescale 1ns/100ps

// Filtro de Wiener FIR de 9 taps sobre a amostra do ADC (shaper_clip).
// Coeficientes calculados para o shaper F34, em Q12: coeficiente real = C/2^12.
// Latencia: 3 ciclos (entrada, produtos e saida registrados).
module wiener_filter
#(
	parameter BITS_IN  = 13,
	parameter Q        = 12,
	parameter BITS_OUT = BITS_IN+16+4-Q,          // acumulador sem os bits fracionarios
	parameter signed [15:0] C0 =   215,           // multiplica x(n)
	parameter signed [15:0] C1 =  -605,
	parameter signed [15:0] C2 =  1586,
	parameter signed [15:0] C3 = -3738,
	parameter signed [15:0] C4 =  6909,
	parameter signed [15:0] C5 = -3175,
	parameter signed [15:0] C6 =  1449,
	parameter signed [15:0] C7 =  -661,
	parameter signed [15:0] C8 =   300            // multiplica x(n-8)
)
(
	input  clk, rst,
	input  signed [BITS_IN-1:0] in,
	output reg signed [BITS_OUT-1:0] out
);

localparam BITS_ACC = BITS_IN+16+4;               // produto de 29 bits + 4 de crescimento da soma

// linha de atraso: x0 = x(n), ..., x8 = x(n-8)
reg signed [BITS_IN-1:0] x0, x1, x2, x3, x4, x5, x6, x7, x8;

// produtos registrados (um estagio de pipeline antes da soma)
reg signed [BITS_IN+16-1:0] p0, p1, p2, p3, p4, p5, p6, p7, p8;

wire signed [BITS_ACC-1:0] acc = p0 + p1 + p2 + p3 + p4 + p5 + p6 + p7 + p8;

always @(posedge clk or posedge rst)
begin
	if (rst) begin
		x0 <= 0; x1 <= 0; x2 <= 0; x3 <= 0; x4 <= 0; x5 <= 0; x6 <= 0; x7 <= 0; x8 <= 0;
		p0 <= 0; p1 <= 0; p2 <= 0; p3 <= 0; p4 <= 0; p5 <= 0; p6 <= 0; p7 <= 0; p8 <= 0;
		out <= 0;
	end
	else begin
		x0 <= in;
		x1 <= x0; x2 <= x1; x3 <= x2; x4 <= x3; x5 <= x4; x6 <= x5; x7 <= x6; x8 <= x7;

		p0 <= C0*x0; p1 <= C1*x1; p2 <= C2*x2; p3 <= C3*x3; p4 <= C4*x4;
		p5 <= C5*x5; p6 <= C6*x6; p7 <= C7*x7; p8 <= C8*x8;

		out <= acc >>> Q;                         // volta para contagens de ADC
	end
end

endmodule
