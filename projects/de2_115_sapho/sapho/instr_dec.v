// ----------------------------------------------------------------------------
// instruction decoder -- opcode -> ALU operation and control lines ------------
// ----------------------------------------------------------------------------
//
// The decode table below is the whole decoder: one row per opcode, numbered as
// in Compilers/common/isa.tsv (Scripts/check_isa.py holds the two in step).
// Every row is a term inside a generate on the parameter of its mnemonic,
// which asmcomp sets to 1 only for the opcodes the program uses: an unused
// row builds nothing, so the decoder grows with the program, like the rest
// of the ALU, in the same form as the ALU's output mux (an OR of guarded
// terms, 2026-10-17; it was a case inside a function, the form measured at
// 76 -> 31 ALUTs against the hand-expanded one before it). Everything is a
// continuous assignment, never an always @ (*): Icarus runs an always @ (*)
// only when a signal it reads changes, and the opcode is already 0 at t=0
// and stays 0 through the reset, so such a block never ran and every control
// line (req_in, push, mem_wr, ...) was X until the first instruction other
// than NOP. The register after the table keeps it out of a ROM: constant
// outputs inside a clocked block are the pattern tools map to one.

module instr_dec
#(
    parameter  NBOPCO  = 7,   // number of opcode bits
    parameter  MDATAW  = 8,   // number of address bits for data memory

    // one per mnemonic, set to 1 by asmcomp when the program uses it

    // memory and stack
    parameter LOD      = 0,
    parameter P_LOD    = 0,
    parameter LDI      = 0,
    parameter ILI      = 0,
    parameter SET      = 0,
    parameter SET_P    = 0,
    parameter STI      = 0,
    parameter ISI      = 0,
    parameter PSH      = 0,
    parameter POP      = 0,

    // I/O
    parameter INN      = 0,
    parameter F_INN    = 0,
    parameter P_INN    = 0,
    parameter PF_INN   = 0,
    parameter OUT      = 0,

    // int arithmetic
    parameter ADD      = 0,
    parameter S_ADD    = 0,
    parameter MLT      = 0,
    parameter S_MLT    = 0,
    parameter DIV      = 0,
    parameter S_DIV    = 0,
    parameter MOD      = 0,
    parameter S_MOD    = 0,
    parameter SGN      = 0,
    parameter S_SGN    = 0,

    // float arithmetic
    parameter F_ADD    = 0,
    parameter SF_ADD   = 0,
    parameter F_SU1    = 0,
    parameter F_SU2    = 0,
    parameter SF_SU1   = 0,
    parameter SF_SU2   = 0,
    parameter F_MLT    = 0,
    parameter SF_MLT   = 0,
    parameter F_DIV    = 0,
    parameter SF_DIV   = 0,
    parameter F_SGN    = 0,
    parameter SF_SGN   = 0,
    parameter F_SCL    = 0,
    parameter SF_SCL   = 0,

    // int unary
    parameter NEG      = 0,
    parameter NEG_M    = 0,
    parameter P_NEG_M  = 0,
    parameter ABS      = 0,
    parameter ABS_M    = 0,
    parameter P_ABS_M  = 0,
    parameter PST      = 0,
    parameter PST_M    = 0,
    parameter P_PST_M  = 0,
    parameter NRM      = 0,
    parameter NRM_M    = 0,
    parameter P_NRM_M  = 0,
    parameter INV      = 0,
    parameter INV_M    = 0,
    parameter P_INV_M  = 0,
    parameter LIN      = 0,
    parameter LIN_M    = 0,
    parameter P_LIN_M  = 0,

    // float unary
    parameter F_NEG    = 0,
    parameter F_NEG_M  = 0,
    parameter PF_NEG_M = 0,
    parameter F_ABS    = 0,
    parameter F_ABS_M  = 0,
    parameter PF_ABS_M = 0,
    parameter F_PST    = 0,
    parameter F_PST_M  = 0,
    parameter PF_PST_M = 0,
    parameter F_ROT    = 0,
    parameter XPO      = 0,
    parameter XPO_M    = 0,

    // conversions
    parameter I2F      = 0,
    parameter I2F_M    = 0,
    parameter P_I2F_M  = 0,
    parameter F2I      = 0,
    parameter F2I_M    = 0,
    parameter P_F2I_M  = 0,

    // logic
    parameter AND      = 0,
    parameter S_AND    = 0,
    parameter ORR      = 0,
    parameter S_ORR    = 0,
    parameter XOR      = 0,
    parameter S_XOR    = 0,
    parameter LAN      = 0,
    parameter S_LAN    = 0,
    parameter LOR      = 0,
    parameter S_LOR    = 0,

    // comparisons
    parameter LES      = 0,
    parameter S_LES    = 0,
    parameter GRE      = 0,
    parameter S_GRE    = 0,
    parameter EQU      = 0,
    parameter S_EQU    = 0,
    parameter F_LES    = 0,
    parameter SF_LES   = 0,
    parameter F_GRE    = 0,
    parameter SF_GRE   = 0,

    // shifts
    parameter SHL      = 0,
    parameter S_SHL    = 0,
    parameter SHR      = 0,
    parameter S_SHR    = 0,
    parameter SRS      = 0,
    parameter S_SRS    = 0
)(
    input                   clk, rst,
    input      [NBOPCO-1:0] opcode,

    output                  push, pop,

    output reg [       5:0] ula_op,

    output                  mem_wr,
    output                  req_in, out_en,
    output                  ldi, sti, fft
);

// {ula_op, push, pop, mem_wr, req_in, out_en, ldi, sti, fft}: one term per
// opcode, OR-ed. A term is its row when the opcode matches, 0 otherwise, and
// an opcode the program does not use builds no term (a constant 0): the ULA's
// form (ula_mux), so the decoder grows with the program and no input is a
// don't care (docs/design/README.md). All 0 = pass-acc, no push, no pop, no
// write.
// memory and stack
wire [13:0] d1  ; generate if ((LOD     ) != 0) begin : g1   assign d1   = (opcode == 7'd1  ) ? {6'd1 , 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0} : 14'd0; end else begin : g1   assign d1   = 14'd0; end endgenerate
wire [13:0] d2  ; generate if ((P_LOD   ) != 0) begin : g2   assign d2   = (opcode == 7'd2  ) ? {6'd1 , 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0} : 14'd0; end else begin : g2   assign d2   = 14'd0; end endgenerate
wire [13:0] d3  ; generate if ((LDI     ) != 0) begin : g3   assign d3   = (opcode == 7'd3  ) ? {6'd1 , 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0} : 14'd0; end else begin : g3   assign d3   = 14'd0; end endgenerate
wire [13:0] d4  ; generate if ((ILI     ) != 0) begin : g4   assign d4   = (opcode == 7'd4  ) ? {6'd1 , 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b1} : 14'd0; end else begin : g4   assign d4   = 14'd0; end endgenerate
wire [13:0] d5  ; generate if ((SET     ) != 0) begin : g5   assign d5   = (opcode == 7'd5  ) ? {6'd0 , 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0} : 14'd0; end else begin : g5   assign d5   = 14'd0; end endgenerate
wire [13:0] d6  ; generate if ((SET_P   ) != 0) begin : g6   assign d6   = (opcode == 7'd6  ) ? {6'd1 , 1'b0, 1'b1, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0} : 14'd0; end else begin : g6   assign d6   = 14'd0; end endgenerate
wire [13:0] d7  ; generate if ((STI     ) != 0) begin : g7   assign d7   = (opcode == 7'd7  ) ? {6'd0 , 1'b0, 1'b1, 1'b1, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0} : 14'd0; end else begin : g7   assign d7   = 14'd0; end endgenerate
wire [13:0] d8  ; generate if ((ISI     ) != 0) begin : g8   assign d8   = (opcode == 7'd8  ) ? {6'd0 , 1'b0, 1'b1, 1'b1, 1'b0, 1'b0, 1'b0, 1'b1, 1'b1} : 14'd0; end else begin : g8   assign d8   = 14'd0; end endgenerate
wire [13:0] d9  ; generate if ((PSH     ) != 0) begin : g9   assign d9   = (opcode == 7'd9  ) ? {6'd0 , 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0} : 14'd0; end else begin : g9   assign d9   = 14'd0; end endgenerate
wire [13:0] d10 ; generate if ((POP     ) != 0) begin : g10  assign d10  = (opcode == 7'd10 ) ? {6'd1 , 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0} : 14'd0; end else begin : g10  assign d10  = 14'd0; end endgenerate
// I/O
wire [13:0] d11 ; generate if ((INN     ) != 0) begin : g11  assign d11  = (opcode == 7'd11 ) ? {6'd0 , 1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0} : 14'd0; end else begin : g11  assign d11  = 14'd0; end endgenerate
wire [13:0] d12 ; generate if ((F_INN   ) != 0) begin : g12  assign d12  = (opcode == 7'd12 ) ? {6'd25, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0} : 14'd0; end else begin : g12  assign d12  = 14'd0; end endgenerate
wire [13:0] d13 ; generate if ((P_INN   ) != 0) begin : g13  assign d13  = (opcode == 7'd13 ) ? {6'd0 , 1'b1, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0} : 14'd0; end else begin : g13  assign d13  = 14'd0; end endgenerate
wire [13:0] d14 ; generate if ((PF_INN  ) != 0) begin : g14  assign d14  = (opcode == 7'd14 ) ? {6'd25, 1'b1, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0} : 14'd0; end else begin : g14  assign d14  = 14'd0; end endgenerate
wire [13:0] d15 ; generate if ((OUT     ) != 0) begin : g15  assign d15  = (opcode == 7'd15 ) ? {6'd0 , 1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0} : 14'd0; end else begin : g15  assign d15  = 14'd0; end endgenerate
// int arithmetic
wire [13:0] d22 ; generate if ((ADD     ) != 0) begin : g22  assign d22  = (opcode == 7'd22 ) ? {6'd2 , 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0} : 14'd0; end else begin : g22  assign d22  = 14'd0; end endgenerate
wire [13:0] d23 ; generate if ((S_ADD   ) != 0) begin : g23  assign d23  = (opcode == 7'd23 ) ? {6'd2 , 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0} : 14'd0; end else begin : g23  assign d23  = 14'd0; end endgenerate
wire [13:0] d24 ; generate if ((MLT     ) != 0) begin : g24  assign d24  = (opcode == 7'd24 ) ? {6'd4 , 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0} : 14'd0; end else begin : g24  assign d24  = 14'd0; end endgenerate
wire [13:0] d25 ; generate if ((S_MLT   ) != 0) begin : g25  assign d25  = (opcode == 7'd25 ) ? {6'd4 , 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0} : 14'd0; end else begin : g25  assign d25  = 14'd0; end endgenerate
wire [13:0] d26 ; generate if ((DIV     ) != 0) begin : g26  assign d26  = (opcode == 7'd26 ) ? {6'd6 , 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0} : 14'd0; end else begin : g26  assign d26  = 14'd0; end endgenerate
wire [13:0] d27 ; generate if ((S_DIV   ) != 0) begin : g27  assign d27  = (opcode == 7'd27 ) ? {6'd6 , 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0} : 14'd0; end else begin : g27  assign d27  = 14'd0; end endgenerate
wire [13:0] d28 ; generate if ((MOD     ) != 0) begin : g28  assign d28  = (opcode == 7'd28 ) ? {6'd8 , 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0} : 14'd0; end else begin : g28  assign d28  = 14'd0; end endgenerate
wire [13:0] d29 ; generate if ((S_MOD   ) != 0) begin : g29  assign d29  = (opcode == 7'd29 ) ? {6'd8 , 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0} : 14'd0; end else begin : g29  assign d29  = 14'd0; end endgenerate
wire [13:0] d30 ; generate if ((SGN     ) != 0) begin : g30  assign d30  = (opcode == 7'd30 ) ? {6'd9 , 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0} : 14'd0; end else begin : g30  assign d30  = 14'd0; end endgenerate
wire [13:0] d31 ; generate if ((S_SGN   ) != 0) begin : g31  assign d31  = (opcode == 7'd31 ) ? {6'd9 , 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0} : 14'd0; end else begin : g31  assign d31  = 14'd0; end endgenerate
// float arithmetic
wire [13:0] d32 ; generate if ((F_ADD   ) != 0) begin : g32  assign d32  = (opcode == 7'd32 ) ? {6'd3 , 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0} : 14'd0; end else begin : g32  assign d32  = 14'd0; end endgenerate
wire [13:0] d33 ; generate if ((SF_ADD  ) != 0) begin : g33  assign d33  = (opcode == 7'd33 ) ? {6'd3 , 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0} : 14'd0; end else begin : g33  assign d33  = 14'd0; end endgenerate
wire [13:0] d34 ; generate if ((F_SU1   ) != 0) begin : g34  assign d34  = (opcode == 7'd34 ) ? {6'd47, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0} : 14'd0; end else begin : g34  assign d34  = 14'd0; end endgenerate
wire [13:0] d35 ; generate if ((F_SU2   ) != 0) begin : g35  assign d35  = (opcode == 7'd35 ) ? {6'd48, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0} : 14'd0; end else begin : g35  assign d35  = 14'd0; end endgenerate
wire [13:0] d36 ; generate if ((SF_SU1  ) != 0) begin : g36  assign d36  = (opcode == 7'd36 ) ? {6'd47, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0} : 14'd0; end else begin : g36  assign d36  = 14'd0; end endgenerate
wire [13:0] d37 ; generate if ((SF_SU2  ) != 0) begin : g37  assign d37  = (opcode == 7'd37 ) ? {6'd48, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0} : 14'd0; end else begin : g37  assign d37  = 14'd0; end endgenerate
wire [13:0] d38 ; generate if ((F_MLT   ) != 0) begin : g38  assign d38  = (opcode == 7'd38 ) ? {6'd5 , 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0} : 14'd0; end else begin : g38  assign d38  = 14'd0; end endgenerate
wire [13:0] d39 ; generate if ((SF_MLT  ) != 0) begin : g39  assign d39  = (opcode == 7'd39 ) ? {6'd5 , 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0} : 14'd0; end else begin : g39  assign d39  = 14'd0; end endgenerate
wire [13:0] d40 ; generate if ((F_DIV   ) != 0) begin : g40  assign d40  = (opcode == 7'd40 ) ? {6'd7 , 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0} : 14'd0; end else begin : g40  assign d40  = 14'd0; end endgenerate
wire [13:0] d41 ; generate if ((SF_DIV  ) != 0) begin : g41  assign d41  = (opcode == 7'd41 ) ? {6'd7 , 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0} : 14'd0; end else begin : g41  assign d41  = 14'd0; end endgenerate
wire [13:0] d42 ; generate if ((F_SGN   ) != 0) begin : g42  assign d42  = (opcode == 7'd42 ) ? {6'd10, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0} : 14'd0; end else begin : g42  assign d42  = 14'd0; end endgenerate
wire [13:0] d43 ; generate if ((SF_SGN  ) != 0) begin : g43  assign d43  = (opcode == 7'd43 ) ? {6'd10, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0} : 14'd0; end else begin : g43  assign d43  = 14'd0; end endgenerate
wire [13:0] d44 ; generate if ((F_SCL   ) != 0) begin : g44  assign d44  = (opcode == 7'd44 ) ? {6'd49, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0} : 14'd0; end else begin : g44  assign d44  = 14'd0; end endgenerate
wire [13:0] d45 ; generate if ((SF_SCL  ) != 0) begin : g45  assign d45  = (opcode == 7'd45 ) ? {6'd49, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0} : 14'd0; end else begin : g45  assign d45  = 14'd0; end endgenerate
// int unary
wire [13:0] d46 ; generate if ((NEG     ) != 0) begin : g46  assign d46  = (opcode == 7'd46 ) ? {6'd11, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0} : 14'd0; end else begin : g46  assign d46  = 14'd0; end endgenerate
wire [13:0] d47 ; generate if ((NEG_M   ) != 0) begin : g47  assign d47  = (opcode == 7'd47 ) ? {6'd12, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0} : 14'd0; end else begin : g47  assign d47  = 14'd0; end endgenerate
wire [13:0] d48 ; generate if ((P_NEG_M ) != 0) begin : g48  assign d48  = (opcode == 7'd48 ) ? {6'd12, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0} : 14'd0; end else begin : g48  assign d48  = 14'd0; end endgenerate
wire [13:0] d49 ; generate if ((ABS     ) != 0) begin : g49  assign d49  = (opcode == 7'd49 ) ? {6'd15, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0} : 14'd0; end else begin : g49  assign d49  = 14'd0; end endgenerate
wire [13:0] d50 ; generate if ((ABS_M   ) != 0) begin : g50  assign d50  = (opcode == 7'd50 ) ? {6'd16, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0} : 14'd0; end else begin : g50  assign d50  = 14'd0; end endgenerate
wire [13:0] d51 ; generate if ((P_ABS_M ) != 0) begin : g51  assign d51  = (opcode == 7'd51 ) ? {6'd16, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0} : 14'd0; end else begin : g51  assign d51  = 14'd0; end endgenerate
wire [13:0] d52 ; generate if ((PST     ) != 0) begin : g52  assign d52  = (opcode == 7'd52 ) ? {6'd19, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0} : 14'd0; end else begin : g52  assign d52  = 14'd0; end endgenerate
wire [13:0] d53 ; generate if ((PST_M   ) != 0) begin : g53  assign d53  = (opcode == 7'd53 ) ? {6'd20, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0} : 14'd0; end else begin : g53  assign d53  = 14'd0; end endgenerate
wire [13:0] d54 ; generate if ((P_PST_M ) != 0) begin : g54  assign d54  = (opcode == 7'd54 ) ? {6'd20, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0} : 14'd0; end else begin : g54  assign d54  = 14'd0; end endgenerate
wire [13:0] d55 ; generate if ((NRM     ) != 0) begin : g55  assign d55  = (opcode == 7'd55 ) ? {6'd23, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0} : 14'd0; end else begin : g55  assign d55  = 14'd0; end endgenerate
wire [13:0] d56 ; generate if ((NRM_M   ) != 0) begin : g56  assign d56  = (opcode == 7'd56 ) ? {6'd24, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0} : 14'd0; end else begin : g56  assign d56  = 14'd0; end endgenerate
wire [13:0] d57 ; generate if ((P_NRM_M ) != 0) begin : g57  assign d57  = (opcode == 7'd57 ) ? {6'd24, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0} : 14'd0; end else begin : g57  assign d57  = 14'd0; end endgenerate
wire [13:0] d58 ; generate if ((INV     ) != 0) begin : g58  assign d58  = (opcode == 7'd58 ) ? {6'd32, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0} : 14'd0; end else begin : g58  assign d58  = 14'd0; end endgenerate
wire [13:0] d59 ; generate if ((INV_M   ) != 0) begin : g59  assign d59  = (opcode == 7'd59 ) ? {6'd33, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0} : 14'd0; end else begin : g59  assign d59  = 14'd0; end endgenerate
wire [13:0] d60 ; generate if ((P_INV_M ) != 0) begin : g60  assign d60  = (opcode == 7'd60 ) ? {6'd33, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0} : 14'd0; end else begin : g60  assign d60  = 14'd0; end endgenerate
wire [13:0] d61 ; generate if ((LIN     ) != 0) begin : g61  assign d61  = (opcode == 7'd61 ) ? {6'd36, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0} : 14'd0; end else begin : g61  assign d61  = 14'd0; end endgenerate
wire [13:0] d62 ; generate if ((LIN_M   ) != 0) begin : g62  assign d62  = (opcode == 7'd62 ) ? {6'd37, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0} : 14'd0; end else begin : g62  assign d62  = 14'd0; end endgenerate
wire [13:0] d63 ; generate if ((P_LIN_M ) != 0) begin : g63  assign d63  = (opcode == 7'd63 ) ? {6'd37, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0} : 14'd0; end else begin : g63  assign d63  = 14'd0; end endgenerate
// float unary
wire [13:0] d64 ; generate if ((F_NEG   ) != 0) begin : g64  assign d64  = (opcode == 7'd64 ) ? {6'd13, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0} : 14'd0; end else begin : g64  assign d64  = 14'd0; end endgenerate
wire [13:0] d65 ; generate if ((F_NEG_M ) != 0) begin : g65  assign d65  = (opcode == 7'd65 ) ? {6'd14, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0} : 14'd0; end else begin : g65  assign d65  = 14'd0; end endgenerate
wire [13:0] d66 ; generate if ((PF_NEG_M) != 0) begin : g66  assign d66  = (opcode == 7'd66 ) ? {6'd14, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0} : 14'd0; end else begin : g66  assign d66  = 14'd0; end endgenerate
wire [13:0] d67 ; generate if ((F_ABS   ) != 0) begin : g67  assign d67  = (opcode == 7'd67 ) ? {6'd17, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0} : 14'd0; end else begin : g67  assign d67  = 14'd0; end endgenerate
wire [13:0] d68 ; generate if ((F_ABS_M ) != 0) begin : g68  assign d68  = (opcode == 7'd68 ) ? {6'd18, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0} : 14'd0; end else begin : g68  assign d68  = 14'd0; end endgenerate
wire [13:0] d69 ; generate if ((PF_ABS_M) != 0) begin : g69  assign d69  = (opcode == 7'd69 ) ? {6'd18, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0} : 14'd0; end else begin : g69  assign d69  = 14'd0; end endgenerate
wire [13:0] d70 ; generate if ((F_PST   ) != 0) begin : g70  assign d70  = (opcode == 7'd70 ) ? {6'd21, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0} : 14'd0; end else begin : g70  assign d70  = 14'd0; end endgenerate
wire [13:0] d71 ; generate if ((F_PST_M ) != 0) begin : g71  assign d71  = (opcode == 7'd71 ) ? {6'd22, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0} : 14'd0; end else begin : g71  assign d71  = 14'd0; end endgenerate
wire [13:0] d72 ; generate if ((PF_PST_M) != 0) begin : g72  assign d72  = (opcode == 7'd72 ) ? {6'd22, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0} : 14'd0; end else begin : g72  assign d72  = 14'd0; end endgenerate
wire [13:0] d73 ; generate if ((F_ROT   ) != 0) begin : g73  assign d73  = (opcode == 7'd73 ) ? {6'd46, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0} : 14'd0; end else begin : g73  assign d73  = 14'd0; end endgenerate
wire [13:0] d74 ; generate if ((XPO     ) != 0) begin : g74  assign d74  = (opcode == 7'd74 ) ? {6'd50, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0} : 14'd0; end else begin : g74  assign d74  = 14'd0; end endgenerate
wire [13:0] d75 ; generate if ((XPO_M   ) != 0) begin : g75  assign d75  = (opcode == 7'd75 ) ? {6'd51, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0} : 14'd0; end else begin : g75  assign d75  = 14'd0; end endgenerate
// conversions
wire [13:0] d76 ; generate if ((I2F     ) != 0) begin : g76  assign d76  = (opcode == 7'd76 ) ? {6'd25, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0} : 14'd0; end else begin : g76  assign d76  = 14'd0; end endgenerate
wire [13:0] d77 ; generate if ((I2F_M   ) != 0) begin : g77  assign d77  = (opcode == 7'd77 ) ? {6'd26, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0} : 14'd0; end else begin : g77  assign d77  = 14'd0; end endgenerate
wire [13:0] d78 ; generate if ((P_I2F_M ) != 0) begin : g78  assign d78  = (opcode == 7'd78 ) ? {6'd26, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0} : 14'd0; end else begin : g78  assign d78  = 14'd0; end endgenerate
wire [13:0] d79 ; generate if ((F2I     ) != 0) begin : g79  assign d79  = (opcode == 7'd79 ) ? {6'd27, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0} : 14'd0; end else begin : g79  assign d79  = 14'd0; end endgenerate
wire [13:0] d80 ; generate if ((F2I_M   ) != 0) begin : g80  assign d80  = (opcode == 7'd80 ) ? {6'd28, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0} : 14'd0; end else begin : g80  assign d80  = 14'd0; end endgenerate
wire [13:0] d81 ; generate if ((P_F2I_M ) != 0) begin : g81  assign d81  = (opcode == 7'd81 ) ? {6'd28, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0} : 14'd0; end else begin : g81  assign d81  = 14'd0; end endgenerate
// logic
wire [13:0] d82 ; generate if ((AND     ) != 0) begin : g82  assign d82  = (opcode == 7'd82 ) ? {6'd29, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0} : 14'd0; end else begin : g82  assign d82  = 14'd0; end endgenerate
wire [13:0] d83 ; generate if ((S_AND   ) != 0) begin : g83  assign d83  = (opcode == 7'd83 ) ? {6'd29, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0} : 14'd0; end else begin : g83  assign d83  = 14'd0; end endgenerate
wire [13:0] d84 ; generate if ((ORR     ) != 0) begin : g84  assign d84  = (opcode == 7'd84 ) ? {6'd30, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0} : 14'd0; end else begin : g84  assign d84  = 14'd0; end endgenerate
wire [13:0] d85 ; generate if ((S_ORR   ) != 0) begin : g85  assign d85  = (opcode == 7'd85 ) ? {6'd30, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0} : 14'd0; end else begin : g85  assign d85  = 14'd0; end endgenerate
wire [13:0] d86 ; generate if ((XOR     ) != 0) begin : g86  assign d86  = (opcode == 7'd86 ) ? {6'd31, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0} : 14'd0; end else begin : g86  assign d86  = 14'd0; end endgenerate
wire [13:0] d87 ; generate if ((S_XOR   ) != 0) begin : g87  assign d87  = (opcode == 7'd87 ) ? {6'd31, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0} : 14'd0; end else begin : g87  assign d87  = 14'd0; end endgenerate
wire [13:0] d88 ; generate if ((LAN     ) != 0) begin : g88  assign d88  = (opcode == 7'd88 ) ? {6'd34, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0} : 14'd0; end else begin : g88  assign d88  = 14'd0; end endgenerate
wire [13:0] d89 ; generate if ((S_LAN   ) != 0) begin : g89  assign d89  = (opcode == 7'd89 ) ? {6'd34, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0} : 14'd0; end else begin : g89  assign d89  = 14'd0; end endgenerate
wire [13:0] d90 ; generate if ((LOR     ) != 0) begin : g90  assign d90  = (opcode == 7'd90 ) ? {6'd35, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0} : 14'd0; end else begin : g90  assign d90  = 14'd0; end endgenerate
wire [13:0] d91 ; generate if ((S_LOR   ) != 0) begin : g91  assign d91  = (opcode == 7'd91 ) ? {6'd35, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0} : 14'd0; end else begin : g91  assign d91  = 14'd0; end endgenerate
// comparisons
wire [13:0] d92 ; generate if ((LES     ) != 0) begin : g92  assign d92  = (opcode == 7'd92 ) ? {6'd38, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0} : 14'd0; end else begin : g92  assign d92  = 14'd0; end endgenerate
wire [13:0] d93 ; generate if ((S_LES   ) != 0) begin : g93  assign d93  = (opcode == 7'd93 ) ? {6'd38, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0} : 14'd0; end else begin : g93  assign d93  = 14'd0; end endgenerate
wire [13:0] d94 ; generate if ((GRE     ) != 0) begin : g94  assign d94  = (opcode == 7'd94 ) ? {6'd40, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0} : 14'd0; end else begin : g94  assign d94  = 14'd0; end endgenerate
wire [13:0] d95 ; generate if ((S_GRE   ) != 0) begin : g95  assign d95  = (opcode == 7'd95 ) ? {6'd40, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0} : 14'd0; end else begin : g95  assign d95  = 14'd0; end endgenerate
wire [13:0] d96 ; generate if ((EQU     ) != 0) begin : g96  assign d96  = (opcode == 7'd96 ) ? {6'd42, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0} : 14'd0; end else begin : g96  assign d96  = 14'd0; end endgenerate
wire [13:0] d97 ; generate if ((S_EQU   ) != 0) begin : g97  assign d97  = (opcode == 7'd97 ) ? {6'd42, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0} : 14'd0; end else begin : g97  assign d97  = 14'd0; end endgenerate
wire [13:0] d98 ; generate if ((F_LES   ) != 0) begin : g98  assign d98  = (opcode == 7'd98 ) ? {6'd39, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0} : 14'd0; end else begin : g98  assign d98  = 14'd0; end endgenerate
wire [13:0] d99 ; generate if ((SF_LES  ) != 0) begin : g99  assign d99  = (opcode == 7'd99 ) ? {6'd39, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0} : 14'd0; end else begin : g99  assign d99  = 14'd0; end endgenerate
wire [13:0] d100; generate if ((F_GRE   ) != 0) begin : g100 assign d100 = (opcode == 7'd100) ? {6'd41, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0} : 14'd0; end else begin : g100 assign d100 = 14'd0; end endgenerate
wire [13:0] d101; generate if ((SF_GRE  ) != 0) begin : g101 assign d101 = (opcode == 7'd101) ? {6'd41, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0} : 14'd0; end else begin : g101 assign d101 = 14'd0; end endgenerate
// shifts
wire [13:0] d102; generate if ((SHL     ) != 0) begin : g102 assign d102 = (opcode == 7'd102) ? {6'd43, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0} : 14'd0; end else begin : g102 assign d102 = 14'd0; end endgenerate
wire [13:0] d103; generate if ((S_SHL   ) != 0) begin : g103 assign d103 = (opcode == 7'd103) ? {6'd43, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0} : 14'd0; end else begin : g103 assign d103 = 14'd0; end endgenerate
wire [13:0] d104; generate if ((SHR     ) != 0) begin : g104 assign d104 = (opcode == 7'd104) ? {6'd44, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0} : 14'd0; end else begin : g104 assign d104 = 14'd0; end endgenerate
wire [13:0] d105; generate if ((S_SHR   ) != 0) begin : g105 assign d105 = (opcode == 7'd105) ? {6'd44, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0} : 14'd0; end else begin : g105 assign d105 = 14'd0; end endgenerate
wire [13:0] d106; generate if ((SRS     ) != 0) begin : g106 assign d106 = (opcode == 7'd106) ? {6'd45, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0} : 14'd0; end else begin : g106 assign d106 = 14'd0; end endgenerate
wire [13:0] d107; generate if ((S_SRS   ) != 0) begin : g107 assign d107 = (opcode == 7'd107) ? {6'd45, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0} : 14'd0; end else begin : g107 assign d107 = 14'd0; end endgenerate

wire [13:0] ctl = d1 | d2 | d3 | d4 | d5 | d6 | d7 | d8 | d9 | d10 | d11 | d12 |
                  d13 | d14 | d15 | d22 | d23 | d24 | d25 | d26 | d27 | d28 | d29 | d30 |
                  d31 | d32 | d33 | d34 | d35 | d36 | d37 | d38 | d39 | d40 | d41 | d42 |
                  d43 | d44 | d45 | d46 | d47 | d48 | d49 | d50 | d51 | d52 | d53 | d54 |
                  d55 | d56 | d57 | d58 | d59 | d60 | d61 | d62 | d63 | d64 | d65 | d66 |
                  d67 | d68 | d69 | d70 | d71 | d72 | d73 | d74 | d75 | d76 | d77 | d78 |
                  d79 | d80 | d81 | d82 | d83 | d84 | d85 | d86 | d87 | d88 | d89 | d90 |
                  d91 | d92 | d93 | d94 | d95 | d96 | d97 | d98 | d99 | d100 | d101 | d102 |
                  d103 | d104 | d105 | d106 | d107;


assign {push, pop, mem_wr, req_in, out_en, ldi, sti, fft} = ctl[7:0];

// the ALU operation is registered; a synchronous reset to 0 = pass-acc is a
// harmless NOP for the ALU while the rest of the pipeline is being reset
always @ (posedge clk) if (rst) ula_op <= 6'd0; else ula_op <= ctl[13:8];

endmodule
