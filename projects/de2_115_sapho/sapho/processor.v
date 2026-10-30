// ****************************************************************************
// Helper circuits ************************************************************
// ****************************************************************************

// Simulation-visibility guard: the mem/PC taps used for waveform viewing are
// compiled for Icarus (predefines __ICARUS__) and for Verilator when the user
// passes +define+YANC_TRACE, but never for synthesis. Verilog `ifdef has no OR,
// so fold both triggers into a single YANC_SIM_VIS macro (the `ifndef avoids a
// redefinition warning when several .v files share the compilation unit).
`ifdef __ICARUS__
 `ifndef YANC_SIM_VIS
  `define YANC_SIM_VIS
 `endif
`endif
`ifdef YANC_TRACE
 `ifndef YANC_SIM_VIS
  `define YANC_SIM_VIS
 `endif
`endif

// instruction memory ---------------------------------------------------------

module mem_instr
#(
	parameter NADDRE =  8,
	parameter NBDATA = 12,
	parameter FNAME  = "instr.mif"
)
(
	input                           clk,
	input      [$clog2(NADDRE)-1:0] addr,
	output reg [NBDATA        -1:0] data = 0
);

reg [NBDATA-1:0] mem [0:NADDRE-1];

`ifdef YOSYS
	// Yosys ignores this
`else
	initial $readmemb(FNAME, mem);
`endif

wire wr = 0; // avoid unnecessary warnings

always @ (posedge clk) begin
	data <= mem[addr];
	if (wr) mem[addr] <= 0;
end

endmodule

// data memory ----------------------------------------------------------------

module mem_data
#(
	parameter NADDRE =  8,
	parameter NBDATA = 32,
	parameter FNAME  = "data.mif"
)(
	input                                  clk,
	input                                  wr,
	input             [$clog2(NADDRE)-1:0] addr_rd, addr_wr,
	input      signed [NBDATA        -1:0] data_in,
	output reg signed [NBDATA        -1:0] data_out
);

reg [NBDATA-1:0] mem [0:NADDRE-1];

`ifdef YOSYS
	// Yosys ignores this
`else
	initial $readmemb(FNAME, mem);
`endif

always @ (posedge clk) begin
	if (wr)     mem[addr_wr] <= data_in;
	data_out <= mem[addr_rd];
end

endmodule

// ****************************************************************************
// Main circuit ***************************************************************
// ****************************************************************************

// ONE default parameter set, shared by processor.v, core.v, ula.v, asmcomp,
// cmmcomp and cppcomp (audit 1.7). It is cppcomp's set, because that is the one
// actually exercised: all 81 C++ tests omit every #pragma and run on it, while
// every C+- fixture sets the directives explicitly. The defaults only apply to
// a hand instantiation or a directive nobody wrote -- the generated <proc>.v
// always passes all of them -- which is exactly why they used to drift apart
// unnoticed (this file said NUBITS 16 next to NBMANT 23 + NBEXPO 8, a format
// that does not add up).
//
//   NUBITS 32 = NBMANT 23 + NBEXPO 8 + 1     NUGAIN 128 (a power of two)
//   SDEPTH 128   DDEPTH 128   FFTSIZ 3       FROUND 0 (legacy datapath)
//
module processor
#(
	// -------------------------------------------------------------------------
	// Pre-fixed parameters ----------------------------------------------------
	// -------------------------------------------------------------------------

	parameter NBOPCO = 7,               // Number of opcode bits (update the assembler accordingly, in eval.c)

	// -------------------------------------------------------------------------
	// Dynamically configured parameters ---------------------------------------
	// -------------------------------------------------------------------------

	// data flow
	parameter ITRADD     = 0,           // Interrupt address (PC jumps here while itr=1)
	parameter TOAQUIADDR = 0,           // #TOAQUI marker address (cheguei pulses when pc_instr == TOAQUIADDR)

	// memories
	parameter IFILE  = "inst.mif",      // File containing the program to be run
	parameter DFILE  = "data.mif",      // File with the data-memory contents
	parameter MDATAS = 64,              // Data-memory size
	parameter MINSTS = 64,              // Instruction-memory size
	parameter MDATAW = $clog2(MDATAS),  // Number of address bits for data memory
	parameter MINSTW = $clog2(MINSTS),  // Number of address bits for instruction memory

	// links to partner processors (docs/design/toma-and-cade-links.md), set by asmcomp
	// from the program: link k is built only where its bit is set
	parameter NLINK  = 1,               // number of link slots (highest link number used + 1)
	parameter [NLINK-1:0] TOMS  = 0,    // bit k: the program has TOM k
	parameter [NLINK-1:0] CADS  = 0,    // bit k: the program has CAD k
	parameter [NLINK-1:0] LSYNC = 0,    // bit k: link k's partner runs on my clock (_sync forms)

	// -------------------------------------------------------------------------
	// User-configured parameters ----------------------------------------------
	// -------------------------------------------------------------------------

	// data flow
	parameter NUBITS = 32,              // Processor word width
	parameter NBMANT = 23,              // Mantissa width (bits)
	parameter NBEXPO =  8,              // Exponent width (bits)
	parameter NBOPER =  9,              // Operand width (bits)

	// memories
	parameter SDEPTH = 128,             // Instruction stack depth
	parameter DDEPTH = 128,             // Data stack depth

	// input and output
	parameter NBIOIN =  2,              // Number of input-port bits
	parameter NBIOOU =  2,              // Number of output-port bits

	// arithmetic constants
	parameter signed [NUBITS-1:0] NUGAIN = 128, // norm() divisor (NRM/NRM_M): a power of two, asmcomp enforces it
	parameter FFTSIZ =  3,              // ILI size for bit reversal
	parameter FROUND =  0,              // Float rounding level (#FROUND): 0 legacy, 1 truncation + saturation, 2 round to nearest even

	// -------------------------------------------------------------------------
	// Resource-allocation parameters ------------------------------------------
	// -------------------------------------------------------------------------

	// implements memory read/write
	parameter	 LOD   = 0,
	parameter  P_LOD   = 0,

	parameter    LDI   = 0,
	parameter    ILI   = 0,

	parameter    SET   = 0,
	parameter    SET_P = 0,

	parameter    STI   = 0,
	parameter    ISI   = 0,

	// implements the data-stack interface
	parameter    PSH   = 0,
	parameter    POP   = 0,

	// implements I/O ports
	parameter    INN   = 0,
	parameter  F_INN   = 0,
	parameter  P_INN   = 0,
	parameter PF_INN   = 0,
	parameter    OUT   = 0,
	
	// implements jumps
	parameter    JIZ   = 0,
	parameter    CAL   = 0,

	// the links to partner processors (docs/design/toma-and-cade-links.md)
	parameter    TOM   = 0,
	parameter    CAD   = 0,

	// two-parameter arithmetic operations
	parameter    ADD   = 0,
	parameter  S_ADD   = 0,
	parameter  F_ADD   = 0,
	parameter SF_ADD   = 0,

	parameter    MLT   = 0,
	parameter  S_MLT   = 0,
	parameter  F_MLT   = 0,
	parameter SF_MLT   = 0,

	parameter    DIV   = 0,
	parameter  S_DIV   = 0,
	parameter  F_DIV   = 0,
	parameter SF_DIV   = 0,

	parameter    MOD   = 0,
	parameter  S_MOD   = 0,

	parameter    SGN   = 0,
	parameter  S_SGN   = 0,
	parameter  F_SGN   = 0,
	parameter SF_SGN   = 0,

	// one-parameter arithmetic operations
	parameter    NEG   = 0,
	parameter    NEG_M = 0,
	parameter  P_NEG_M = 0,
	parameter  F_NEG   = 0,
	parameter  F_NEG_M = 0,
	parameter PF_NEG_M = 0,

	parameter    ABS   = 0,
	parameter    ABS_M = 0,
	parameter  P_ABS_M = 0,
	parameter  F_ABS   = 0,
	parameter  F_ABS_M = 0,
	parameter PF_ABS_M = 0,

	parameter    PST   = 0,
	parameter    PST_M = 0,
	parameter  P_PST_M = 0,
	parameter  F_PST   = 0,
	parameter  F_PST_M = 0,
	parameter PF_PST_M = 0,

	parameter    NRM   = 0,
	parameter    NRM_M = 0,
	parameter  P_NRM_M = 0,

	parameter    I2F   = 0,
	parameter    I2F_M = 0,
	parameter  P_I2F_M = 0,

	parameter    F2I   = 0,
	parameter    F2I_M = 0,
	parameter  P_F2I_M = 0,

	// two-parameter logical operations
	parameter    AND   = 0,
	parameter  S_AND   = 0,
	parameter    ORR   = 0,
	parameter  S_ORR   = 0,
	parameter    XOR   = 0,
	parameter  S_XOR   = 0,

	// one-parameter logical operations
	parameter    INV   = 0,
	parameter    INV_M = 0,
	parameter  P_INV_M = 0,

	// two-parameter conditional operations
	parameter    LAN   = 0,
	parameter  S_LAN   = 0,
	parameter    LOR   = 0,
	parameter  S_LOR   = 0,
	
	// one-parameter conditional operations
	parameter    LIN   = 0,
	parameter    LIN_M = 0,
	parameter  P_LIN_M = 0,

	// comparison operations
	parameter    LES   = 0,
	parameter  S_LES   = 0,
	parameter  F_LES   = 0,
	parameter SF_LES   = 0,

	parameter    GRE   = 0,
	parameter  S_GRE   = 0,
	parameter  F_GRE   = 0,
	parameter SF_GRE   = 0,

	parameter    EQU   = 0,
	parameter  S_EQU   = 0,

	// bit-shift operations
	parameter    SHL   = 0,
	parameter  S_SHL   = 0,

	parameter    SHR   = 0,
	parameter  S_SHR   = 0,
	
	parameter    SRS   = 0,
	parameter  S_SRS   = 0,

	// special operations
	parameter  F_ROT   = 0,    // nearest power-of-two square-root approximation (with ACC)
	parameter  F_SU1   = 0,    // floating-point subtraction at input 1
	parameter  F_SU2   = 0,    // floating-point subtraction at input 2
	parameter SF_SU1   = 0,    // floating-point subtraction at input 1 with stack
	parameter SF_SU2   = 0,    // floating-point subtraction at input 2 with stack
	parameter  F_SCL   = 0,    // scale float by 2^k, k from memory
	parameter SF_SCL   = 0,    // scale float by 2^k, k from stack
	parameter    XPO   = 0,    // base-2 exponent of float (acc) as int
	parameter  XPO_M   = 0     // base-2 exponent of float (memory) as int
)(
	input               clk     , rst,
	input  [NUBITS-1:0] io_in   ,
	output [NUBITS-1:0] io_out  ,
	output [NBIOIN-1:0] addr_in ,
	output [NBIOOU-1:0] addr_out,
	output              req_in  , out_en,
	input               itr,
	output              cheguei,
	output [NLINK       -1:0] toma, cade,   // the links to partner processors, one bit per link
	input  [NLINK       -1:0] valeu, taqui, // (docs/design/toma-and-cade-links.md)
	input  [NLINK*NUBITS-1:0] cade_dado,    // link k at bits k*NUBITS
	output [NUBITS      -1:0] toma_dado     // my offered value, the same for every link

`ifdef YANC_SIM_VIS // --------------------------------------------------------

	, output              mem_wr,
	  output [MDATAW-1:0] mem_addr_wr,
	  output [MINSTW-1:0] pc_sim_val);

`else

);

wire                     mem_wr;
wire        [MDATAW-1:0] mem_addr_wr;

`endif // ---------------------------------------------------------------------

wire        [MDATAW-1:0] mem_addr_rd;

// core -----------------------------------------------------------------------

wire        [MINSTW-1:0] instr_addr;
wire signed [NUBITS-1:0] mem_data_in;
wire signed [NUBITS-1:0] mem_data_out;
wire sw, mem_wrb;

assign io_out = mem_data_out;

wire [NBOPCO+NBOPER-1:0] instr;

core #(.NBOPCO ( NBOPCO ),
       .NBOPER ( NBOPER ),
       .ITRADD     ( ITRADD     ),
       .TOAQUIADDR ( TOAQUIADDR ),
       .MDATAW ( MDATAW ),
       .MINSTW ( MINSTW ),
       .NUBITS ( NUBITS ),
       .NBMANT ( NBMANT ),
       .NBEXPO ( NBEXPO ),
       .SDEPTH ( SDEPTH ),
       .DDEPTH ( DDEPTH ),
       .NBIOIN ( NBIOIN ),
       .NBIOOU ( NBIOOU ),
       .NUGAIN ( NUGAIN ),
       .FFTSIZ ( FFTSIZ ),
       .FROUND ( FROUND ),
       .NLINK  ( NLINK  ),
       .TOMS   ( TOMS   ),
       .CADS   ( CADS   ),
       .LSYNC  ( LSYNC  ),
	     .LOD  (   LOD  ),
	   .P_LOD  ( P_LOD  ),
         .LDI  (   LDI  ),
         .ILI  (   ILI  ),
		 .SET  (   SET  ),
		 .SET_P(   SET_P),
         .STI  (   STI  ),
         .ISI  (   ISI  ),
		 .PSH  (   PSH  ),
		 .POP  (   POP  ),
		 .INN  (   INN  ),
       .F_INN  ( F_INN  ),
	   .P_INN  ( P_INN  ),
	  .PF_INN  ( PF_INN ),
	     .OUT  (   OUT  ),
		 .JIZ  (   JIZ  ),
         .CAL  (   CAL  ),
         .TOM  (   TOM  ),
         .CAD  (   CAD  ),
         .ADD  (   ADD  ),
	   .S_ADD  ( S_ADD  ),
       .F_ADD  ( F_ADD  ),
	  .SF_ADD  (SF_ADD  ),
         .MLT  (   MLT  ),
	   .S_MLT  ( S_MLT  ),
       .F_MLT  ( F_MLT  ),
	  .SF_MLT  (SF_MLT  ),
         .DIV  (   DIV  ),
	   .S_DIV  ( S_DIV  ),
       .F_DIV  ( F_DIV  ),
	  .SF_DIV  (SF_DIV  ),
         .MOD  (   MOD  ),
	   .S_MOD  ( S_MOD  ),
         .SGN  (   SGN  ),
	   .S_SGN  ( S_SGN  ),
       .F_SGN  ( F_SGN  ),
	  .SF_SGN  (SF_SGN  ),
         .NEG  (   NEG  ),
         .NEG_M(   NEG_M),
	   .P_NEG_M( P_NEG_M),
       .F_NEG  ( F_NEG  ),
       .F_NEG_M( F_NEG_M),
	  .PF_NEG_M(PF_NEG_M),
         .ABS  (   ABS  ),
         .ABS_M(   ABS_M),
	   .P_ABS_M( P_ABS_M),
       .F_ABS  ( F_ABS  ),
       .F_ABS_M( F_ABS_M),
	  .PF_ABS_M(PF_ABS_M),
         .PST  (   PST  ),
         .PST_M(   PST_M),
	   .P_PST_M( P_PST_M),
       .F_PST  ( F_PST  ),
       .F_PST_M( F_PST_M),
	  .PF_PST_M(PF_PST_M),
         .NRM  (   NRM  ),
         .NRM_M(   NRM_M),
	   .P_NRM_M( P_NRM_M),
         .I2F  (   I2F  ),
         .I2F_M(   I2F_M),
	   .P_I2F_M( P_I2F_M),
         .F2I  (   F2I  ),
         .F2I_M(   F2I_M),
	   .P_F2I_M( P_F2I_M),
         .AND  (   AND  ),
	   .S_AND  ( S_AND  ),
         .ORR  (   ORR  ),
	   .S_ORR  ( S_ORR  ),
         .XOR  (   XOR  ),
	   .S_XOR  ( S_XOR  ),
         .INV  (   INV  ),
         .INV_M(   INV_M),
	   .P_INV_M( P_INV_M),
         .LAN  (   LAN  ),
	   .S_LAN  ( S_LAN  ),
         .LOR  (   LOR  ),
	   .S_LOR  ( S_LOR  ),
         .LIN  (   LIN  ),
         .LIN_M(   LIN_M),
	   .P_LIN_M( P_LIN_M),
         .LES  (   LES  ),
	   .S_LES  ( S_LES  ),
       .F_LES  ( F_LES  ),
	  .SF_LES  (SF_LES  ),
         .GRE  (   GRE  ),
	   .S_GRE  ( S_GRE  ),
       .F_GRE  ( F_GRE  ),
	  .SF_GRE  (SF_GRE  ),
         .EQU  (   EQU  ),
	   .S_EQU  ( S_EQU  ),
         .SHL  (   SHL  ),
	   .S_SHL  ( S_SHL  ),
         .SHR  (   SHR  ),
	   .S_SHR  ( S_SHR  ),
         .SRS  (   SRS  ),
	   .S_SRS  ( S_SRS  ),
	   .F_ROT  ( F_ROT  ),
	   .F_SU1  ( F_SU1  ),
	   .F_SU2  ( F_SU2  ),
	   .SF_SU1 (SF_SU1  ),
	   .SF_SU2 (SF_SU2  ),
	   .F_SCL  ( F_SCL  ),
	   .SF_SCL (SF_SCL  ),
	   .XPO    (   XPO  ),
	   .XPO_M  ( XPO_M  )) core(clk, rst,
                                instr, instr_addr,
                                mem_wr, mem_addr_rd, mem_addr_wr, mem_data_in, mem_data_out,
                                io_in, addr_in, addr_out, req_in, out_en, itr, cheguei,
                                toma, cade, valeu, taqui, cade_dado, toma_dado

`ifdef YANC_SIM_VIS // --------------------------------------------------------

                             , pc_sim_val

`endif // ---------------------------------------------------------------------
);

// instruction memory ---------------------------------------------------------

mem_instr # (.NADDRE(MINSTS       ),
             .NBDATA(NBOPCO+NBOPER),
             .FNAME (IFILE        )) minstr(clk, instr_addr, instr);

// data memory ----------------------------------------------------------------

mem_data # (.NADDRE(MDATAS),
            .NBDATA(NUBITS),
            .FNAME (DFILE )) mdata(clk, mem_wr, mem_addr_rd, mem_addr_wr, mem_data_out, mem_data_in);

endmodule