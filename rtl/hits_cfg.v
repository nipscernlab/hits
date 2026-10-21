`timescale 1ns/100ps

// hits_cfg: the register core of the configuration bus (docs/develop/config-bus.md).
//
// Generic interface, modelled on the ports of SAPHO: a write is one cycle with wr = 1
// and the data valid in that cycle; a read is one cycle with rd = 1 and rdata answered
// in that cycle (rdata does not depend on rd). One clock, the clock of the simulator.
//
// It holds the scalars, holds the simulator in reset while RUN = 0, and turns the
// writes to MEM_DATA into words written into the memories of hits_core: a word wider
// than 16 bits arrives in pieces of 16, the least significant first, and is written
// one cycle after its last piece; the address then moves to the next word.
//
// Only ID, CAPS and STATUS can be read; the configuration is write-only. Vectors and
// ORBIT_LEN are written only while RUN = 0 (a rule of the protocol, not enforced).
module hits_cfg
#(
	parameter BUNCH_POS = 3564,            // size of the mask memory, the longest orbit
	parameter [15:0] CAPS = 16'h1000,      // what was synthesized, see hits_bus.v
	// values at power-up and after rst
	parameter [15:0] OCCUPANCY_INIT = 16'd0,
	parameter [12:0] PEDESTAL_INIT = 13'd0,
	parameter OCC_BYPASS_INIT = 0,
	parameter BUNCH_TRAIN_ACTIVE_INIT = 1,
	parameter integer PHASE0_INIT = 0,
	parameter [15:0] SIGMA_K_INIT = 16'd0
)
(
	input clk, rst,
	// the bus
	input [3:0] addr,
	input [15:0] wdata,
	input wr,
	input rd,
	output reg [15:0] rdata,
	// to hits_core
	output core_rst,
	output reg [15:0] occupancy = OCCUPANCY_INIT,
	output reg [12:0] offset = PEDESTAL_INIT,
	output reg occ_bypass = OCC_BYPASS_INIT,
	output reg train_active = BUNCH_TRAIN_ACTIVE_INIT,
	output reg [$clog2(BUNCH_POS)-1:0] orbit_last = BUNCH_POS - 1,
	output reg signed [5:0] phase0 = PHASE0_INIT,
	output reg [15:0] sigma_k = SIGMA_K_INIT,
	output reg mem_we = 1'b0,
	output reg [2:0] mem_sel = 3'd0,
	output reg [11:0] mem_addr = 12'd0,
	output [69:0] mem_wdata
);

localparam [3:0] A_ID = 4'd0, A_CAPS = 4'd1, A_STATUS = 4'd2, A_OCCUPANCY = 4'd3,
                 A_PEDESTAL = 4'd4, A_MODE = 4'd5, A_ORBIT_LEN = 4'd6, A_PHASE0 = 4'd7,
                 A_SIGMA = 4'd8, A_MEM_SEL = 4'd9, A_MEM_ADDR = 4'd10, A_MEM_DATA = 4'd11;
localparam [15:0] ID = 16'h4854;        // "HT"

reg run = 1'b1;
assign core_rst = rst | ~run;

// pieces per word of each vector: 0 mask (1 bit), 1 energy (70), 2 noise (46), 3 jitter (46)
reg [2:0] chunk = 3'd0;
wire [2:0] last_chunk = (mem_sel == 3'd1) ? 3'd4 : (mem_sel == 3'd0) ? 3'd0 : 3'd2;
reg [79:0] word = 80'd0;                // the word being assembled (70 bits used)
reg [11:0] next_addr = 12'd0;           // where the word being assembled goes
assign mem_wdata = word[69:0];

wire wr_data = wr && addr == A_MEM_DATA;

always @(posedge clk or posedge rst)
	if (rst) begin
		run <= 1'b1;
		occupancy <= OCCUPANCY_INIT;
		offset <= PEDESTAL_INIT;
		occ_bypass <= OCC_BYPASS_INIT;
		train_active <= BUNCH_TRAIN_ACTIVE_INIT;
		orbit_last <= BUNCH_POS - 1;
		phase0 <= PHASE0_INIT;
		sigma_k <= SIGMA_K_INIT;
		mem_sel <= 3'd0;
		mem_we <= 1'b0;
		mem_addr <= 12'd0;
		next_addr <= 12'd0;
		chunk <= 3'd0;
	end else begin
		mem_we <= 1'b0;
		if (wr)
			case (addr)
				A_STATUS:    run <= wdata[0];                 // CONTROL
				A_OCCUPANCY: occupancy <= wdata;
				A_PEDESTAL:  offset <= wdata[12:0];
				A_MODE:      {train_active, occ_bypass} <= wdata[1:0];
				A_ORBIT_LEN: orbit_last <= wdata[$clog2(BUNCH_POS)-1:0] - 1'b1;
				A_PHASE0:    phase0 <= wdata[5:0];
				A_SIGMA:     sigma_k <= wdata;
				A_MEM_SEL:   begin mem_sel <= wdata[2:0]; chunk <= 3'd0; end
				A_MEM_ADDR:  begin next_addr <= wdata[11:0]; chunk <= 3'd0; end
				default: ;
			endcase
		if (wr_data) begin
			if (chunk == last_chunk) begin
				chunk <= 3'd0;
				mem_we <= 1'b1;               // the word is written next cycle,
				mem_addr <= next_addr;        // with its last piece already in place
				next_addr <= next_addr + 1'b1;
			end else
				chunk <= chunk + 1'b1;
		end
	end

// the pieces: not reset, a word is always written whole
always @(posedge clk)
	if (wr_data) word[16*chunk +: 16] <= wdata;

always @(*)
	case (addr)
		A_ID:     rdata = ID;
		A_CAPS:   rdata = CAPS;
		A_STATUS: rdata = {15'd0, run};
		default:  rdata = 16'd0;
	endcase

endmodule
