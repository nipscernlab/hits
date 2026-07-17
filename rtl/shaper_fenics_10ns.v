`timescale 1ns/100ps

module shaper_fenics_10ns
#( 
	parameter BITS_IN = 34,
	parameter G_ENTRADA = 2**32,
	parameter G_SAIDA_LOG = 10
)
(
	input  clock, 
	input  signed [BITS_IN-1:0] in,
	output signed [BITS_IN+16:0] out
);


wire signed [BITS_IN+16:0] out1, out2, out3, out4, out5, out6, out7;

/////////////////////////////
iir_ordem1
#( 
	.BITS_IN(BITS_IN),
	.G_ENTRADA(G_ENTRADA),
	.G_SAIDA_LOG(10),
	.b0(-4),  
	.a1(-1022)
) iir1
(
	.clock(clock), 
	.in(in),
	.out(out1)
);

/////////////////////////////
iir_ordem2
#( 
	.BITS_IN(BITS_IN),
	.G_ENTRADA(G_ENTRADA),
	.G_SAIDA_LOG(10),
	.b0(-166),
	.b1(42),	
	.a1(1074),
	.a2(295)
) iir2
(
	.clock(clock), 
	.in(in),
	.out(out2)
);

/////////////////////////////
iir_ordem2
#( 
	.BITS_IN(BITS_IN),
	.G_ENTRADA(G_ENTRADA),
	.G_SAIDA_LOG(10),
	.b0(-3110),
	.b1(-1561),	
	.a1(-29),
	.a2(167)
) iir3
(
	.clock(clock), 
	.in(in),
	.out(out3)
);


/////////////////////////////
iir_ordem1
#( 
	.BITS_IN(BITS_IN),
	.G_ENTRADA(G_ENTRADA),
	.G_SAIDA_LOG(10),
	.b0(3958),  
	.a1(-374)
) iir4
(
	.clock(clock), 
	.in(in),
	.out(out4)
);

/////////////////////////////

iir_ordem2
#( 
	.BITS_IN(BITS_IN),
	.G_ENTRADA(G_ENTRADA),
	.G_SAIDA_LOG(10),
	.b0(-4),
	.b1(-1),	
	.a1(-1),
	.a2(0)
) iir5
(
	.clock(clock), 
	.in(in),
	.out(out5)
);


/////////////////////////////

iir_ordem2
#( 
	.BITS_IN(BITS_IN),
	.G_ENTRADA(G_ENTRADA),
	.G_SAIDA_LOG(10),
	.b0(-677),
	.b1(-1),	
	.a1(0),
	.a2(0)
) iir6
(
	.clock(clock), 
	.in(in),
	.out(out6)
);


/////////////////////////////

iir_ordem1
#( 
	.BITS_IN(BITS_IN),
	.G_ENTRADA(G_ENTRADA),
	.G_SAIDA_LOG(10),
	.b0(-1),  
	.a1(-1)
) iir7
(
	.clock(clock), 
	.in(in),
	.out(out7)
);

assign out = out1 + out2 + out3 + out4 + out5 + out6 + out7;


endmodule
