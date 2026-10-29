`timescale 1ns/100ps

// hits_sapho: the adapter between the ports of a SAPHO processor and the configuration
// bus of hits (docs/develop/config-bus.md, issue #14).
//
// Each register of the bus is a port of SAPHO: out(p, x) writes register p and in(p)
// reads it. SAPHO marks the port of a write with the one-hot out_en and the port of a
// read with the one-hot req_in; the adapter only turns them into the binary addr. A
// SAPHO port p is bus register p, so a program writes OCCUPANCY with out(3, x) and reads
// ID with in(0).
//
// Combinational, so the timing is that of the bus: a write takes effect on the next
// edge, and in() reads rdata in the cycle req_in is 1, which is when SAPHO samples its
// in. Nothing is decoded from the word on out (it comes straight from the ALU of SAPHO):
// its low 16 bits go to registers of hits_cfg. SAPHO reads or writes one port per cycle,
// so out_en and req_in are never both set; their OR gives addr.
//
// SAPHO builds only the ports its program uses: N_OUT and N_IN are the widths of its
// out_en and req_in (its nuioou and nuioin), at most 16. With NUBITS wider than 16, the
// high bits of out are dropped and in reads rdata with zeros above.
module hits_sapho
#(
	parameter integer NUBITS = 32,     // the word of the SAPHO program, at least 16
	parameter integer N_OUT = 12,      // output ports of SAPHO (out_en)
	parameter integer N_IN = 3         // input ports of SAPHO (req_in)
)
(
	// SAPHO
	input [NUBITS-1:0] out,
	input [N_OUT-1:0] out_en,
	input [N_IN-1:0] req_in,
	output [NUBITS-1:0] in,
	// the bus of hits
	output reg [3:0] addr,
	output [15:0] wdata,
	output wr,
	output rd,
	input [15:0] rdata
);

integer p;
always @* begin
	addr = 4'd0;
	for (p = 0; p < N_OUT; p = p + 1) if (out_en[p]) addr = addr | p[3:0];
	for (p = 0; p < N_IN; p = p + 1) if (req_in[p]) addr = addr | p[3:0];
end

assign wdata = out[15:0];
assign wr = |out_en;
assign rd = |req_in;
assign in = rdata;                 // zero-extended to NUBITS

endmodule
