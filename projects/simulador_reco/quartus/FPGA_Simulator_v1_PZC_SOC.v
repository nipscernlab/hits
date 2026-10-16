module FPGA_Simulator_v1_PZC_SOC(
	//////////// CLOCK //////////
	input 		          		FPGA_CLK1_50,
	input 		          		FPGA_CLK2_50,
	input 		          		FPGA_CLK3_50,

	//////////// KEY //////////
	input 		     [1:0]		KEY,

	//////////// LED //////////
	output		     [7:0]		LED,

	//////////// SW //////////
	input 		     [3:0]		SW,

	//////////// GPIO_0, GPIO connect to GPIO Default //////////
	output 		    [35:0]		GPIO_0,

	//////////// GPIO_1, GPIO connect to GPIO Default //////////
	output 		    [35:0]		GPIO_1
);



//=======================================================
//  REG/WIRE declarations
//=======================================================

wire bt_mask_out;
wire [12:0] event_bt;
wire signed [29:0] shaper_out;
wire signed [45:0] pzc_out;

parameter PZC_M_FACTOR = 454;


//=======================================================
//  Structural coding
//=======================================================

wire clk_40;

pll_40mhz pll_40mhz_inst (
		.refclk(FPGA_CLK1_50),   //  refclk.clk
		.rst(~KEY[0]),      //   reset.reset
		.outclk_0(clk_40)  // outclk0.clk
	);
	

///////////////////////////////////////

wire [6:0] occupancy;


sw_converter swc
(
	.clk(clk_40), 
	.rst(~KEY[0]),
	.in(SW),
	.occ_out(occupancy)
);




///////////////////////////////////////







FPGA_Simulator_v1_PZC 
#(
	.PZC_M_FACTOR(PZC_M_FACTOR)
	)
sim
(
	.clk(clk_40), 
	.rst(~KEY[0]),
	.occupancy(occupancy),
	.hits_out(),
	.bt_mask_out(bt_mask_out),
	.energy_out(), 
	.event_bt(event_bt),
	.event_all(),
	.shaper_out(shaper_out),
	.pzc_out(pzc_out)
);

wire signed [45:0] pzc_out_div1 = (pzc_out)/(PZC_M_FACTOR);
wire signed [45:0] pzc_out_div2 = (pzc_out_div1 >>> 10);


assign GPIO_0[12:0] = event_bt;
assign GPIO_0[26:14] = (shaper_out >>> 10);
//assign GPIO_1[31:0] = pzc_out[31:0];
assign GPIO_1[12:0] = pzc_out_div2;


endmodule