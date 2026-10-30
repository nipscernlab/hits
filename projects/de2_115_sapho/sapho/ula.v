// ****************************************************************************
// Main multiplexer ***********************************************************
// ****************************************************************************

// Simulation-visibility guard: the rounding-error block at the bottom of this
// file (real-valued ULA taps + delta_int/delta_float) is waveform-only. Compile
// it for Icarus (predefines __ICARUS__) and for Verilator with +define+YANC_TRACE,
// never for synthesis. Verilog `ifdef has no OR, so fold both into YANC_SIM_VIS.
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

// selects which operation goes to the output ---------------------------------

module ula_mux
#(
	 parameter NUBITS = 32,
	 // the operations the program has (the ula's parameters): an input is built
	 // into the mux only when its operation is there
	 parameter   ADD   = 0, F_ADD   = 0,   MLT   = 0, F_MLT   = 0,   DIV   = 0, F_DIV   = 0,   MOD   = 0,
	 parameter   SGN   = 0, F_SGN   = 0,   NEG   = 0,   NEG_M = 0, F_NEG   = 0, F_NEG_M = 0,
	 parameter   ABS   = 0,   ABS_M = 0, F_ABS   = 0, F_ABS_M = 0,   PST   = 0,   PST_M = 0, F_PST   = 0, F_PST_M = 0,
	 parameter   NRM   = 0,   NRM_M = 0,   I2F   = 0,   I2F_M = 0,   F2I   = 0,   F2I_M = 0,
	 parameter   AND   = 0,   ORR   = 0,   XOR   = 0,   INV   = 0,   INV_M = 0,
	 parameter   LAN   = 0,   LOR   = 0,   LIN   = 0,   LIN_M = 0,
	 parameter   LES   = 0, F_LES   = 0,   GRE   = 0, F_GRE   = 0,   EQU   = 0,
	 parameter   SHL   = 0,   SHR   = 0,   SRS   = 0,
	 parameter F_ROT   = 0, F_SU1   = 0, F_SU2   = 0, F_SCL   = 0,   XPO   = 0,   XPO_M = 0
 )(
	 // operation index
	 input     [       5:0] op  ,
	 // outputs one of the inputs (in1 -> from memory, in2 -> from accumulator)
	 input     [NUBITS-1:0] in1 , in2,
	 // two-parameter arithmetic operations
	 input     [NUBITS-1:0] add ,
	 input     [NUBITS-1:0] mlt ,
	 input     [NUBITS-1:0] div ,
	 input     [NUBITS-1:0] mod ,                    // int-only
	 input     [NUBITS-1:0] sgn , fsgn,
	 // one-parameter arithmetic operations
	 input     [NUBITS-1:0] neg , negm, fneg, fnegm,
	 input     [NUBITS-1:0] abs , absm, fabs, fabsm,
	 input     [NUBITS-1:0] pst , pstm, fpst, fpstm,
	 input     [NUBITS-1:0] nrm , nrmm,              // int-only
	 input     [NUBITS-1:0] f2i , f2im,
	 // two-parameter logical operations
	 input     [NUBITS-1:0] ann , orr , cor ,        // and, or, xor
	 // one-parameter logical operations
	 input     [NUBITS-1:0] inv , invm,              // not
	 // two-parameter conditional operations
	 input     [NUBITS-1:0] lan , lor ,              // int-only
	 // one-parameter conditional operations
	 input     [NUBITS-1:0] lin , linm,              // int-only
	 // comparison operations
	 input     [NUBITS-1:0] les , fles,
	 input     [NUBITS-1:0] gre , fgre,
	 input     [NUBITS-1:0] equ ,                    // works for int and float
	 // bit-shift operations
	 input     [NUBITS-1:0] shl , shr , srs ,        // <<, >> and >>>
	 // operations from the normalization circuit
	 input     [NUBITS-1:0] smx ,                    // float-only with denorm.
	 // special operations (exponent surgery)
	 input     [NUBITS-1:0] fscl, xpo , xpom,        // F_SCL/SF_SCL, XPO, XPO_M
	 // outputs: every operation, and the ones that do not go through the
	 // normaliser only (JIZ reads it: the normaliser stays out of the jump)
	output     [NUBITS-1:0] out,
	output     [NUBITS-1:0] out_fast
	);

// One term per operation, OR-ed: a term is its input when op selects it, 0
// otherwise, and an operation the program does not have builds no term (a
// constant 0). No input is ever a don't care (docs/design/README.md). The
// operations that go through the normaliser (smx) are not terms: a 2-input
// mux after the OR picks smx for them, so out_fast is the OR alone.

wire [NUBITS-1:0] t0 = (op == 6'd0) ? in2 : {NUBITS{1'b0}};   //   NOP (and every instruction that keeps the accumulator)
wire [NUBITS-1:0] t1 = (op == 6'd1) ? in1 : {NUBITS{1'b0}};   //   LOD

wire [NUBITS-1:0] t2 ; generate if ((ADD) != 0) begin : g2  assign t2  = (op == 6'd2 ) ? add   : {NUBITS{1'b0}}; end else begin : g2  assign t2  = {NUBITS{1'b0}}; end endgenerate   // ADD
wire [NUBITS-1:0] t4 ; generate if ((MLT) != 0) begin : g4  assign t4  = (op == 6'd4 ) ? mlt   : {NUBITS{1'b0}}; end else begin : g4  assign t4  = {NUBITS{1'b0}}; end endgenerate   // MLT
wire [NUBITS-1:0] t6 ; generate if ((DIV) != 0) begin : g6  assign t6  = (op == 6'd6 ) ? div   : {NUBITS{1'b0}}; end else begin : g6  assign t6  = {NUBITS{1'b0}}; end endgenerate   // DIV
wire [NUBITS-1:0] t8 ; generate if ((MOD) != 0) begin : g8  assign t8  = (op == 6'd8 ) ? mod   : {NUBITS{1'b0}}; end else begin : g8  assign t8  = {NUBITS{1'b0}}; end endgenerate   // MOD
wire [NUBITS-1:0] t9 ; generate if ((SGN) != 0) begin : g9  assign t9  = (op == 6'd9 ) ? sgn   : {NUBITS{1'b0}}; end else begin : g9  assign t9  = {NUBITS{1'b0}}; end endgenerate   // SGN
wire [NUBITS-1:0] t10; generate if ((F_SGN) != 0) begin : g10 assign t10 = (op == 6'd10) ? fsgn  : {NUBITS{1'b0}}; end else begin : g10 assign t10 = {NUBITS{1'b0}}; end endgenerate   // F_SGN
wire [NUBITS-1:0] t11; generate if ((NEG) != 0) begin : g11 assign t11 = (op == 6'd11) ? neg   : {NUBITS{1'b0}}; end else begin : g11 assign t11 = {NUBITS{1'b0}}; end endgenerate   // NEG
wire [NUBITS-1:0] t12; generate if ((NEG_M) != 0) begin : g12 assign t12 = (op == 6'd12) ? negm  : {NUBITS{1'b0}}; end else begin : g12 assign t12 = {NUBITS{1'b0}}; end endgenerate   // NEG_M
wire [NUBITS-1:0] t13; generate if ((F_NEG) != 0) begin : g13 assign t13 = (op == 6'd13) ? fneg  : {NUBITS{1'b0}}; end else begin : g13 assign t13 = {NUBITS{1'b0}}; end endgenerate   // F_NEG
wire [NUBITS-1:0] t14; generate if ((F_NEG_M) != 0) begin : g14 assign t14 = (op == 6'd14) ? fnegm : {NUBITS{1'b0}}; end else begin : g14 assign t14 = {NUBITS{1'b0}}; end endgenerate   // F_NEG_M
wire [NUBITS-1:0] t15; generate if ((ABS) != 0) begin : g15 assign t15 = (op == 6'd15) ? abs   : {NUBITS{1'b0}}; end else begin : g15 assign t15 = {NUBITS{1'b0}}; end endgenerate   // ABS
wire [NUBITS-1:0] t16; generate if ((ABS_M) != 0) begin : g16 assign t16 = (op == 6'd16) ? absm  : {NUBITS{1'b0}}; end else begin : g16 assign t16 = {NUBITS{1'b0}}; end endgenerate   // ABS_M
wire [NUBITS-1:0] t17; generate if ((F_ABS) != 0) begin : g17 assign t17 = (op == 6'd17) ? fabs  : {NUBITS{1'b0}}; end else begin : g17 assign t17 = {NUBITS{1'b0}}; end endgenerate   // F_ABS
wire [NUBITS-1:0] t18; generate if ((F_ABS_M) != 0) begin : g18 assign t18 = (op == 6'd18) ? fabsm : {NUBITS{1'b0}}; end else begin : g18 assign t18 = {NUBITS{1'b0}}; end endgenerate   // F_ABS_M
wire [NUBITS-1:0] t19; generate if ((PST) != 0) begin : g19 assign t19 = (op == 6'd19) ? pst   : {NUBITS{1'b0}}; end else begin : g19 assign t19 = {NUBITS{1'b0}}; end endgenerate   // PST
wire [NUBITS-1:0] t20; generate if ((PST_M) != 0) begin : g20 assign t20 = (op == 6'd20) ? pstm  : {NUBITS{1'b0}}; end else begin : g20 assign t20 = {NUBITS{1'b0}}; end endgenerate   // PST_M
wire [NUBITS-1:0] t21; generate if ((F_PST) != 0) begin : g21 assign t21 = (op == 6'd21) ? fpst  : {NUBITS{1'b0}}; end else begin : g21 assign t21 = {NUBITS{1'b0}}; end endgenerate   // F_PST
wire [NUBITS-1:0] t22; generate if ((F_PST_M) != 0) begin : g22 assign t22 = (op == 6'd22) ? fpstm : {NUBITS{1'b0}}; end else begin : g22 assign t22 = {NUBITS{1'b0}}; end endgenerate   // F_PST_M
wire [NUBITS-1:0] t23; generate if ((NRM) != 0) begin : g23 assign t23 = (op == 6'd23) ? nrm   : {NUBITS{1'b0}}; end else begin : g23 assign t23 = {NUBITS{1'b0}}; end endgenerate   // NRM
wire [NUBITS-1:0] t24; generate if ((NRM_M) != 0) begin : g24 assign t24 = (op == 6'd24) ? nrmm  : {NUBITS{1'b0}}; end else begin : g24 assign t24 = {NUBITS{1'b0}}; end endgenerate   // NRM_M
wire [NUBITS-1:0] t27; generate if ((F2I) != 0) begin : g27 assign t27 = (op == 6'd27) ? f2i   : {NUBITS{1'b0}}; end else begin : g27 assign t27 = {NUBITS{1'b0}}; end endgenerate   // F2I
wire [NUBITS-1:0] t28; generate if ((F2I_M) != 0) begin : g28 assign t28 = (op == 6'd28) ? f2im  : {NUBITS{1'b0}}; end else begin : g28 assign t28 = {NUBITS{1'b0}}; end endgenerate   // F2I_M
wire [NUBITS-1:0] t29; generate if ((AND) != 0) begin : g29 assign t29 = (op == 6'd29) ? ann   : {NUBITS{1'b0}}; end else begin : g29 assign t29 = {NUBITS{1'b0}}; end endgenerate   // AND
wire [NUBITS-1:0] t30; generate if ((ORR) != 0) begin : g30 assign t30 = (op == 6'd30) ? orr   : {NUBITS{1'b0}}; end else begin : g30 assign t30 = {NUBITS{1'b0}}; end endgenerate   // ORR
wire [NUBITS-1:0] t31; generate if ((XOR) != 0) begin : g31 assign t31 = (op == 6'd31) ? cor   : {NUBITS{1'b0}}; end else begin : g31 assign t31 = {NUBITS{1'b0}}; end endgenerate   // XOR
wire [NUBITS-1:0] t32; generate if ((INV) != 0) begin : g32 assign t32 = (op == 6'd32) ? inv   : {NUBITS{1'b0}}; end else begin : g32 assign t32 = {NUBITS{1'b0}}; end endgenerate   // INV
wire [NUBITS-1:0] t33; generate if ((INV_M) != 0) begin : g33 assign t33 = (op == 6'd33) ? invm  : {NUBITS{1'b0}}; end else begin : g33 assign t33 = {NUBITS{1'b0}}; end endgenerate   // INV_M
wire [NUBITS-1:0] t34; generate if ((LAN) != 0) begin : g34 assign t34 = (op == 6'd34) ? lan   : {NUBITS{1'b0}}; end else begin : g34 assign t34 = {NUBITS{1'b0}}; end endgenerate   // LAN
wire [NUBITS-1:0] t35; generate if ((LOR) != 0) begin : g35 assign t35 = (op == 6'd35) ? lor   : {NUBITS{1'b0}}; end else begin : g35 assign t35 = {NUBITS{1'b0}}; end endgenerate   // LOR
wire [NUBITS-1:0] t36; generate if ((LIN) != 0) begin : g36 assign t36 = (op == 6'd36) ? lin   : {NUBITS{1'b0}}; end else begin : g36 assign t36 = {NUBITS{1'b0}}; end endgenerate   // LIN
wire [NUBITS-1:0] t37; generate if ((LIN_M) != 0) begin : g37 assign t37 = (op == 6'd37) ? linm  : {NUBITS{1'b0}}; end else begin : g37 assign t37 = {NUBITS{1'b0}}; end endgenerate   // LIN_M
wire [NUBITS-1:0] t38; generate if ((LES) != 0) begin : g38 assign t38 = (op == 6'd38) ? les   : {NUBITS{1'b0}}; end else begin : g38 assign t38 = {NUBITS{1'b0}}; end endgenerate   // LES
wire [NUBITS-1:0] t39; generate if ((F_LES) != 0) begin : g39 assign t39 = (op == 6'd39) ? fles  : {NUBITS{1'b0}}; end else begin : g39 assign t39 = {NUBITS{1'b0}}; end endgenerate   // F_LES
wire [NUBITS-1:0] t40; generate if ((GRE) != 0) begin : g40 assign t40 = (op == 6'd40) ? gre   : {NUBITS{1'b0}}; end else begin : g40 assign t40 = {NUBITS{1'b0}}; end endgenerate   // GRE
wire [NUBITS-1:0] t41; generate if ((F_GRE) != 0) begin : g41 assign t41 = (op == 6'd41) ? fgre  : {NUBITS{1'b0}}; end else begin : g41 assign t41 = {NUBITS{1'b0}}; end endgenerate   // F_GRE
wire [NUBITS-1:0] t42; generate if ((EQU) != 0) begin : g42 assign t42 = (op == 6'd42) ? equ   : {NUBITS{1'b0}}; end else begin : g42 assign t42 = {NUBITS{1'b0}}; end endgenerate   // EQU
wire [NUBITS-1:0] t43; generate if ((SHL) != 0) begin : g43 assign t43 = (op == 6'd43) ? shl   : {NUBITS{1'b0}}; end else begin : g43 assign t43 = {NUBITS{1'b0}}; end endgenerate   // SHL
wire [NUBITS-1:0] t44; generate if ((SHR) != 0) begin : g44 assign t44 = (op == 6'd44) ? shr   : {NUBITS{1'b0}}; end else begin : g44 assign t44 = {NUBITS{1'b0}}; end endgenerate   // SHR
wire [NUBITS-1:0] t45; generate if ((SRS) != 0) begin : g45 assign t45 = (op == 6'd45) ? srs   : {NUBITS{1'b0}}; end else begin : g45 assign t45 = {NUBITS{1'b0}}; end endgenerate   // SRS
wire [NUBITS-1:0] t49; generate if ((F_SCL) != 0) begin : g49 assign t49 = (op == 6'd49) ? fscl  : {NUBITS{1'b0}}; end else begin : g49 assign t49 = {NUBITS{1'b0}}; end endgenerate   // F_SCL
wire [NUBITS-1:0] t50; generate if ((XPO) != 0) begin : g50 assign t50 = (op == 6'd50) ? xpo   : {NUBITS{1'b0}}; end else begin : g50 assign t50 = {NUBITS{1'b0}}; end endgenerate   // XPO
wire [NUBITS-1:0] t51; generate if ((XPO_M) != 0) begin : g51 assign t51 = (op == 6'd51) ? xpom  : {NUBITS{1'b0}}; end else begin : g51 assign t51 = {NUBITS{1'b0}}; end endgenerate   // XPO_M

assign out_fast = t0 | t1 | t2 | t4 | t6 | t8 | t9 | t10 | t11 | t12 | t13 | t14 | t15 |
                  t16 | t17 | t18 | t19 | t20 | t21 | t22 | t23 | t24 | t27 | t28 | t29 | t30 |
                  t31 | t32 | t33 | t34 | t35 | t36 | t37 | t38 | t39 | t40 | t41 | t42 | t43 |
                  t44 | t45 | t49 | t50 | t51;

// the 2-input mux, only when the program has a normalised operation
generate if ((F_ADD | F_MLT | F_DIV | I2F | I2F_M | F_ROT | F_SU1 | F_SU2) != 0) begin : norm_out
	wire is_norm = (((F_ADD) != 0) & (op == 6'd3)) |
	                 (((F_MLT) != 0) & (op == 6'd5)) |
	                 (((F_DIV) != 0) & (op == 6'd7)) |
	                 (((I2F) != 0) & (op == 6'd25)) |
	                 (((I2F_M) != 0) & (op == 6'd26)) |
	                 (((F_ROT) != 0) & (op == 6'd46)) |
	                 (((F_SU1) != 0) & (op == 6'd47)) |
	                 (((F_SU2) != 0) & (op == 6'd48));
	assign out = (is_norm) ? smx : out_fast;
end else begin : norm_out
	assign out = out_fast;
end endgenerate

endmodule

// ****************************************************************************
// Auxiliary circuits for floating-point operations ***************************
// ****************************************************************************

// equalizes the exponent of two numbers --------------------------------------
// for operations that require mantissas at the same order of magnitude. e.g., F_ADD

module ula_denorm
#(
	parameter MAN = 23,
	parameter EXP =  8,
	parameter G   =  0                                  // extra low bits kept below the mantissa (3 = guard/round/sticky, FROUND 2)
)(
	 input                    neg1, neg2,               // invert the sign
	 input        [MAN+EXP:0]  in1,  in2,
	output signed [EXP-1  :0] e_out,                    // the larger exponent
	output                    s_big, s_small,           // signs of the two operands, big/small order
	output        [MAN+G-1:0] m_big, m_small            // aligned magnitudes: m_big as is, m_small shifted right
);

localparam W = MAN+G;                                   // mantissa + extra bits

// unpack the registered inputs -----------------------------------------------

wire                  s1_in = (neg1) ? ~in1[MAN+EXP] : in1[MAN+EXP];
wire                  s2_in = (neg2) ? ~in2[MAN+EXP] : in2[MAN+EXP];
wire signed [EXP-1:0] e1_in = in1[MAN+EXP-1:MAN];
wire signed [EXP-1:0] e2_in = in2[MAN+EXP-1:MAN];
wire        [MAN-1:0] m1_in = in1[MAN    -1:0  ];
wire        [MAN-1:0] m2_in = in2[MAN    -1:0  ];

// order the operands by exponent ---------------------------------------------
// both differences are computed in parallel (no negation in series); the one
// that is non-negative is the shift of the smaller operand

wire signed [EXP:0] d12 = e1_in - e2_in;
wire signed [EXP:0] d21 = e2_in - e1_in;

wire         swap  = d12[EXP];                          // e1 < e2
wire [EXP:0] shift = (swap) ? d21 : d12;                // |e1 - e2|

assign e_out   = (swap) ? e2_in : e1_in;
assign s_big   = (swap) ? s2_in : s1_in;
assign s_small = (swap) ? s1_in : s2_in;
wire [MAN-1:0] mb_in = (swap) ? m2_in : m1_in;
wire [MAN-1:0] ms_in = (swap) ? m1_in : m2_in;

// right-shift the smaller mantissa (one shifter) -----------------------------

// the mantissas are widened by G zero bits, so what the shift pushes out lands
// in the extra bits instead of being lost (G = 0: plain shift)
wire [W-1:0] mb_ext, ms_ext;
wire [W-1:0] ms_sh = ms_ext >> shift;

generate if (G != 0) begin : sticky
	assign mb_ext = {mb_in, {G{1'b0}}};
	assign ms_ext = {ms_in, {G{1'b0}}};
	// the lowest extra bit also collects every bit shifted past it (sticky)
	// bits below `shift` are the ones shifted out: select them with a thermometer
	// mask (a decoder, not a second shifter) and OR them
	wire [W-1:0] lost = ~({W{1'b1}} << shift);                // all ones when shift >= W
	wire st = |(ms_ext & lost);
	assign m_small = {ms_sh[W-1:1], ms_sh[0] | st};
end else begin : plain
	assign mb_ext  = mb_in;
	assign ms_ext  = ms_in;
	assign m_small = ms_sh;
end endgenerate

assign m_big = mb_ext;

endmodule

// leading-zero count of a W-bit word, by a tree -------------------------------
// Pads W to a power of two with ones below (they never add zeros above a
// one), then merges pairs over log2(W) levels: a pair's count is the left
// count when the left half has a one, else the left half's width plus the
// right count. A zero word counts W (the normaliser handles it apart).

module ula_lzc
#(
	parameter W  = 26,
	parameter CW =  8                      // width of the count
)(
	input  [W -1:0] in,
	output [CW-1:0] out
);

localparam L = $clog2(W);                  // levels
localparam P = 1 << L;                     // padded width

wire [P-1:0] x;
generate if (P > W) begin : pad assign x = {in, {(P-W){1'b1}}}; end
         else       begin : pad assign x = in;                   end endgenerate

// level k holds P>>k nodes, each a count of L+1 bits plus "all zero"
genvar k, j;
generate
for (k = 0; k <= L; k = k+1) begin : lv
	wire [(P>>k)*(L+1)-1:0] cnt;
	wire [(P>>k)      -1:0] zer;
	if (k == 0) begin : leaf
		for (j = 0; j < P; j = j+1) begin : b
			assign zer[j]                = ~x[j];
			assign cnt[j*(L+1) +: (L+1)] = {{L{1'b0}}, ~x[j]};
		end
	end else begin : node
		for (j = 0; j < (P>>k); j = j+1) begin : n
			// left = the more significant child (index 2j+1)
			wire           zl = lv[k-1].zer[2*j+1];
			wire           zr = lv[k-1].zer[2*j  ];
			wire [L:0]     cl = lv[k-1].cnt[(2*j+1)*(L+1) +: (L+1)];
			wire [L:0]     cr = lv[k-1].cnt[(2*j  )*(L+1) +: (L+1)];
			assign zer[j]                = zl & zr;
			assign cnt[j*(L+1) +: (L+1)] = (zl) ? (({{L{1'b0}}, 1'b1} << (k-1)) + cr) : cl;   // the 1 at the count's width
		end
	end
end
endgenerate

wire [L:0] total = lv[L].cnt[L:0];
assign out = total;                        // zero-extended (or cut) to CW

endmodule

// normalization of a floating-point number -----------------------------------
// left-shift until the most significant bit of the mantissa is 1 -------------

// The operators hand in an exponent 2 bits wider than the format, so an
// overflow/underflow is still visible here. FROUND selects what to do with it:
//   0 - legacy: the exponent wraps modulo 2^EXP, zero keeps the operand sign
//   1 - saturate on overflow, flush to canonical zero on underflow (and on zero)
//   2 - as 1, plus round to nearest even on the G extra bits of the mantissa

module ula_norm
#(
	parameter MAN    = 23,
	parameter EXP    =  8,
	parameter FROUND =  0,
	parameter G      =  0,                 // extra low bits carried by the mantissa (3 when FROUND = 2)
	parameter LZC    =  1,                 // some instantiated operator needs the leading-zero count (F_ADD, I2F, F_ROT; F_MLT/F_DIV at level 0)
	parameter DIR    =  0                  // some instantiated operator takes the direct path (F_MLT/F_DIV at FROUND >= 1)
)(
	 input [MAN+EXP+G+2:0] in,             // {s, e[EXP+1:0], m[MAN+G-1:0]}: needs a leading-zero count
	 input [MAN+EXP+G+2:0] in_d,           // same format, already aligned to its top bit
	 input                 use_d,          // take in_d (skips the leading-zero count)
	output [MAN+EXP    :0] out
);

localparam W = MAN+G;

// Only the paths some opcode of the program needs are built: a processor
// that only multiplies at FROUND >= 1 carries no leading-zero counter, one
// that only adds carries no direct path.

wire                  sig;
wire        [W-1  :0] nrm;                                            // the LSB of the mantissa field keeps weight 2^e_nrm
wire signed [EXP+1:0] e_nrm;
wire                  zman;

generate if (LZC != 0) begin : lzc

	// leading-zero path ------------------------------------------------------

	wire                    sig_l = in[MAN+EXP+G+2  ];
	wire signed [EXP+1  :0] exp_l = in[MAN+EXP+G+1:W];
	wire        [W-1    :0] man_l = in[W        -1:0];

	// the shift is the leading-zero count, capped at W-1 (a zero mantissa
	// counts W; zman handles it)
	wire [EXP-1:0] lz;
	ula_lzc #(W, EXP) lzc (man_l, lz);

	wire        [EXP-1:0] sh    =  (lz > W-1) ? W-1 : lz;
	wire        [W-1  :0] nrm_l =  man_l << sh;
	wire signed [EXP+1:0] e_l   =  exp_l - {{2{1'b0}}, sh};

	if (DIR != 0) begin : both
		// direct path (no shift) beside it, selected per opcode
		assign sig   = (use_d) ? in_d[MAN+EXP+G+2  ] : sig_l;
		assign nrm   = (use_d) ? in_d[W        -1:0] : nrm_l;
		assign e_nrm = (use_d) ? $signed(in_d[MAN+EXP+G+1:W]) : e_l;
		assign zman  = (use_d) ? (in_d[W-1:0] == {W{1'b0}}) : (man_l == {W{1'b0}});
	end else begin : only
		assign sig   = sig_l;
		assign nrm   = nrm_l;
		assign e_nrm = e_l;
		assign zman  = (man_l == {W{1'b0}});
	end

end else begin : direct

	// direct path only: every normalized operator of this program arrives aligned
	assign sig   = in_d[MAN+EXP+G+2  ];
	assign nrm   = in_d[W        -1:0];
	assign e_nrm = $signed(in_d[MAN+EXP+G+1:W]);
	assign zman  = (in_d[W-1:0] == {W{1'b0}});

end endgenerate

// as bit patterns of their own width (a 32-bit integer expression made the
// synthesizers warn of truncation): 2^(EXP-1) - 1 and -2^(EXP-1)
localparam signed [EXP+1:0] EMAX  = {3'b000, {(EXP-1){1'b1}}};   // largest exponent
localparam signed [EXP+1:0] EZERO = {3'b111, {(EXP-1){1'b0}}};   // exponent of the zero encoding

wire                  out_s;
wire signed [EXP-1:0] out_e;
wire        [MAN-1:0] out_m;

generate if (FROUND == 0) begin : legacy
	// exponent wraps modulo 2^EXP, zero keeps the operand sign
	assign out_s = sig;
	assign out_e = (zman) ? EZERO[EXP-1:0] : e_nrm[EXP-1:0];
	assign out_m = nrm[W-1:G];
end else begin : ranged
	// round to nearest even on the extra bits (nothing to do when G = 0)
	wire        [MAN-1:0] mnt = nrm[W-1:G];
	wire                  inc;
	if (G != 0) begin : rne
		wire grd = nrm[G-1];                                          // first bit below the mantissa
		wire stk = |nrm[G-2:0];                                       // anything below it
		assign inc = grd & (stk | mnt[0]);
	end else begin : trunc
		assign inc = 1'b0;
	end
	wire        [MAN  :0] rnd   = {1'b0, mnt} + {{MAN{1'b0}}, inc};
	wire                  rc    = rnd[MAN];                           // carry out: mantissa was all ones
	wire        [MAN-1:0] m_rnd = (rc) ? {1'b1, {MAN-1{1'b0}}} : rnd[MAN-1:0];
	// exponent and range check for both outcomes of the rounding carry, in
	// parallel with the increment; the carry only picks at the end (carry-select)
	wire signed [EXP+1:0] e_r0  = e_nrm;
	wire signed [EXP+1:0] e_r1  = e_nrm + {{EXP+1{1'b0}}, 1'b1};
	wire                  zero0 = zman | (e_r0 < EZERO);
	wire                  zero1 = zman | (e_r1 < EZERO);
	wire                  ovf0  = (e_r0 > EMAX);
	wire                  ovf1  = (e_r1 > EMAX);
	wire signed [EXP+1:0] e_rnd = (rc) ? e_r1  : e_r0;
	wire                  zero  = (rc) ? zero1 : zero0;               // canonical zero on a zero or underflowed result
	wire                  ovf   = (rc) ? ovf1  : ovf0;                // saturate on overflow
	assign out_s = (zero) ? 1'b0 : sig;
	assign out_e = (zero) ? EZERO[EXP-1:0] : (ovf) ? EMAX[EXP-1:0] : e_rnd[EXP-1:0];
	assign out_m = (zero) ? {MAN{1'b0}}   : (ovf) ? {MAN{1'b1}}   : m_rnd;
end endgenerate

assign out = {out_s, out_e, out_m};

endmodule

// multiplexer of operations that require normalization -----------------------

module norm_mux
#(
	parameter NUBITS = 32,
	parameter NBMANT = 23,
	parameter NBEXPO =  8,
	parameter FROUND =  0,
	parameter G      =  0,
	parameter LZC    =  1,                // see ula_norm
	parameter DIR    =  0,
	// the normalised operations the program has: an input is built into the
	// muxes only when its operation is there
	parameter F_ADD  =  0, F_SU1 = 0, F_SU2 = 0, F_MLT = 0, F_DIV = 0,
	parameter I2F    =  0, I2F_M = 0, F_ROT = 0
)(
	 input [         5:0] op  ,
	 input [NUBITS+G+1:0] fadd,           // operator outputs carry a 2-bit-wider exponent and G extra mantissa bits
	 input [NUBITS+G+1:0] fmlt,
	 input [NUBITS+G+1:0] fdiv,
	 input [NUBITS+G+1:0] i2f , i2fm,
	 input [NUBITS+G+1:0] frot,
	output [NUBITS  -1:0] out
);

// Both muxes as in ula_mux: one term per operation, OR-ed, built only when
// the program has the operation (no don't-care input, docs/design/README.md).
localparam W2 = NUBITS+G+2;

// operands that need the leading-zero count (F_MLT/F_DIV too at level 0, where
// the legacy path is kept bit for bit)
wire [W2-1:0] l3 ; generate if ((F_ADD) != 0) begin : gl3  assign l3  = (op == 6'd3 ) ? fadd : {W2{1'b0}}; end else begin : gl3  assign l3  = {W2{1'b0}}; end endgenerate   // F_ADD
wire [W2-1:0] l5 ; generate if ((F_MLT) != 0) begin : gl5  assign l5  = (op == 6'd5 ) ? fmlt : {W2{1'b0}}; end else begin : gl5  assign l5  = {W2{1'b0}}; end endgenerate   // F_MLT
wire [W2-1:0] l7 ; generate if ((F_DIV) != 0) begin : gl7  assign l7  = (op == 6'd7 ) ? fdiv : {W2{1'b0}}; end else begin : gl7  assign l7  = {W2{1'b0}}; end endgenerate   // F_DIV
wire [W2-1:0] l25; generate if ((I2F  ) != 0) begin : gl25 assign l25 = (op == 6'd25) ? i2f  : {W2{1'b0}}; end else begin : gl25 assign l25 = {W2{1'b0}}; end endgenerate   //   I2F
wire [W2-1:0] l26; generate if ((I2F_M) != 0) begin : gl26 assign l26 = (op == 6'd26) ? i2fm : {W2{1'b0}}; end else begin : gl26 assign l26 = {W2{1'b0}}; end endgenerate   //   I2F_M
wire [W2-1:0] l46; generate if ((F_ROT) != 0) begin : gl46 assign l46 = (op == 6'd46) ? frot : {W2{1'b0}}; end else begin : gl46 assign l46 = {W2{1'b0}}; end endgenerate   // F_ROT
wire [W2-1:0] l47; generate if ((F_SU1) != 0) begin : gl47 assign l47 = (op == 6'd47) ? fadd : {W2{1'b0}}; end else begin : gl47 assign l47 = {W2{1'b0}}; end endgenerate   // F_SU1 (the same addition circuit)
wire [W2-1:0] l48; generate if ((F_SU2) != 0) begin : gl48 assign l48 = (op == 6'd48) ? fadd : {W2{1'b0}}; end else begin : gl48 assign l48 = {W2{1'b0}}; end endgenerate   // F_SU2 (the same addition circuit)

wire [W2-1:0] imux_l = l3 | l5 | l7 | l25 | l26 | l46 | l47 | l48;

// operands already aligned to their top bit by the operator (FROUND >= 1):
// they skip the leading-zero count and go straight to rounding/saturation
wire               use_d = (FROUND != 0) & ((op == 6'd5) | (op == 6'd7));

wire [W2-1:0] d5 ; generate if ((F_MLT) != 0) begin : gd5  assign d5  = (op == 6'd5 ) ? fmlt : {W2{1'b0}}; end else begin : gd5  assign d5  = {W2{1'b0}}; end endgenerate   // F_MLT
wire [W2-1:0] d7 ; generate if ((F_DIV) != 0) begin : gd7  assign d7  = (op == 6'd7 ) ? fdiv : {W2{1'b0}}; end else begin : gd7  assign d7  = {W2{1'b0}}; end endgenerate   // F_DIV

wire [W2-1:0] imux_d = d5 | d7;

// perform the normalization
ula_norm #(NBMANT,NBEXPO,FROUND,G,LZC,DIR) ula_norm (imux_l, imux_d, use_d, out);

endmodule

// ****************************************************************************
// Two-parameter arithmetic operations ****************************************
// ****************************************************************************

// ADD - fixed-point addition -------------------------------------------------

module ula_add
#(
	parameter NUBITS = 32
)(
	 input signed [NUBITS-1:0] in1, in2,
	output signed [NUBITS-1:0] out
);

assign out = in1 + in2;

endmodule

// F_ADD - floating-point addition --------------------------------------------

module ula_fadd
#(
	parameter MAN    = 23,
	parameter EXP    =  8,
	parameter FROUND =  0,
	parameter G      =  0
)(
	input  signed [EXP-1     :0] e_in,
	input                        s_big, s_small,          // operand signs (big = larger exponent)
	input         [MAN+G-1   :0] m_big, m_small,          // aligned magnitudes
	output        [MAN+EXP+G+2:0] out                     // exponent 2 bits wider (see ula_norm)
);

localparam W = MAN+G;

// sign-magnitude addition: equal signs add the magnitudes; different signs
// subtract both ways in parallel and keep the non-negative difference (the
// borrow of big-small says which). One adder delay instead of three (the
// two's-complement conversions of the operands and of the result).
wire        same  = (s_big == s_small);
wire [W:0]  sum   = {1'b0, m_big  } + {1'b0, m_small};
wire [W:0]  dbs   = {1'b0, m_big  } - {1'b0, m_small};
wire [W:0]  dsb   = {1'b0, m_small} - {1'b0, m_big  };
wire        bneg  = dbs[W];                            // m_big < m_small
wire [W:0]  m     = (same) ? sum : (bneg) ? dsb : dbs; // magnitude of the result (carry in bit W)
wire        nz    = |m;
wire        s_out = nz & ((same) ? s_big : (bneg) ? s_small : s_big); // an exact zero is +0
wire        carry = m[W];                              // the sum outgrew the mantissa

wire signed [EXP+1:0] e_wide = {{2{e_in[EXP-1]}}, e_in};
wire signed [EXP+1:0] e_out;
wire        [W-1  :0] m_out;

generate if (FROUND == 0) begin : legacy
	// always shift right by one: the LSB is lost even when there was no carry
	assign e_out = e_wide + {{EXP+1{1'b0}}, 1'b1};
	assign m_out = m[W:1];
end else if (G == 0) begin : keep_lsb
	// shift (and bump the exponent) only when the sum actually carried out
	assign e_out = e_wide + {{EXP+1{1'b0}}, carry};
	assign m_out = (carry) ? m[W:1] : m[W-1:0];
end else begin : keep_lsb_sticky
	// same, folding the bit that falls off the shift into the sticky bit
	assign e_out = e_wide + {{EXP+1{1'b0}}, carry};
	assign m_out = (carry) ? {m[W:2], m[1] | m[0]} : m[W-1:0];
end endgenerate

assign out = {s_out, e_out, m_out};

endmodule

// MLT - fixed-point multiplication -------------------------------------------

module ula_mlt
#(
	parameter NUBITS = 32
)(
	 input signed [NUBITS-1:0] in1, in2,
	output signed [NUBITS-1:0] out
);

assign out = in1 * in2;

endmodule

// F_MLT - floating-point multiplication --------------------------------------

module ula_fmlt
#(
	parameter MAN    = 23,
	parameter EXP    =  8,
	parameter FROUND =  0,
	parameter G      =  0
)(
	 input     [MAN+EXP :0] in1, in2,
	output     [MAN+EXP+G+2:0] out                            // exponent 2 bits wider (see ula_norm)
);

localparam W = MAN+G;
localparam signed [EXP+1:0] EZERO = {3'b111, {(EXP-1){1'b0}}};  // -2^(EXP-1), at its own width

// separate the parts of the input signals ------------------------------------

wire                  s1 = in1[MAN+EXP      ];
wire                  s2 = in2[MAN+EXP      ];
wire signed [EXP+1:0] e1 = {{2{in1[MAN+EXP-1]}}, in1[MAN+EXP-1:MAN]};
wire signed [EXP+1:0] e2 = {{2{in2[MAN+EXP-1]}}, in2[MAN+EXP-1:MAN]};
wire        [MAN-1:0] m1 = in1[MAN    -1:0  ];
wire        [MAN-1:0] m2 = in2[MAN    -1:0  ];

// compute the sign -----------------------------------------------------------

wire s_mlt = (s1 != s2);

// compute the mantissa value -------------------------------------------------

wire [2*MAN-1:0] mult  = m1 * m2;
wire             top   = mult[2*MAN-1];                       // does the product occupy the top bit?

// compute the exponent value (for a product that occupies the top bit) -------

wire signed [EXP+1:0] e_top = e1 + e2 + MAN[EXP+1:0];

// finalize -------------------------------------------------------------------

wire                  s_out;
wire signed [EXP+1:0] e_out;
wire        [W-1  :0] m_out;

generate if (FROUND == 0) begin : legacy
	// top MAN bits of the product; a zero product is encoded here directly
	wire [MAN-1:0] m_top = mult[2*MAN-1:MAN];
	wire           nz    = (m_top != {MAN{1'b0}});
	assign s_out = (nz) ? s_mlt : 1'b0;
	assign e_out = (nz) ? e_top : EZERO;
	assign m_out = m_top;
end else if (G == 0) begin : keep_lsb
	// when the top bit is 0 take the slice one bit lower (and the exponent one less)
	assign s_out = s_mlt;
	assign e_out = e_top - {{EXP+1{1'b0}}, ~top};
	assign m_out = (top) ? mult[2*MAN-1:MAN] : mult[2*MAN-2:MAN-1];
end else begin : keep_lsb_sticky
	// same, with two more product bits and the OR of the rest as sticky (G = 3)
	assign s_out = s_mlt;
	assign e_out = e_top - {{EXP+1{1'b0}}, ~top};
	assign m_out = (top) ? {mult[2*MAN-1:MAN-2], |mult[MAN-3:0]} : {mult[2*MAN-2:MAN-3], |mult[MAN-4:0]};
end endgenerate

assign out = {s_out, e_out, m_out};

endmodule

// dividers -------------------------------------------------------------------
// DIV, MOD and F_DIV are the longest paths of the processor (~5x the base's,
// docs/design/pipeln-and-division.md). Each divider is a restoring array cut by
// registers into STG parts of about the same delay (ula_idiv 5, ula_fdiv 4), so
// it takes STG cycles and every other path keeps its one: the compilers write
// each division as `<div> x`, STG-2 NOPs and `<read>` (Compilers/common
// asm_divseq, ASM_DIV_WORDS_*), and the last word, QUO / REM / F_QUO (an alias
// of the division's own opcode), finds the first one's result at the end of
// the array. Nothing waits: the
// cuts carry with the data everything the later parts need, so the inputs may
// change every cycle.

// restoring divider array ----------------------------------------------------
// One row per quotient bit: the partial remainder shifts left taking the next
// dividend bit, the divisor is subtracted, and the row keeps the difference
// when there is no borrow (quotient bit 1). The remainder entering the array
// (r0) and the one leaving it (rem) are below the divisor d.
//
// The rows split into STG groups with a register in front of each group but
// the first: the remainder, the quotient bits found so far, the divisor, the
// dividend bits and `side` (what the caller needs at the end, computed from
// the inputs of the first cycle) travel together, one group a cycle; q, rem
// and side_o are the inputs' of STG-1 cycles before. PRE10/POST10 are the
// logic in the same register-to-register path before the array (data memory
// read, operand select, magnitudes) and after it (slice, sign, normaliser,
// ALU output mux, jump decision, PC), in tenths of a row: the first and last
// groups are shorter, they share their cycle with it.

module div_array
#(
	parameter N      = 23,                                    // divisor bits
	parameter R      = 24,                                    // rows = quotient bits
	parameter S      =  1,                                    // side bits
	parameter STG    =  3,                                    // cycles it takes
	parameter PRE10  =  8,
	parameter POST10 = 36
)(
	 input [N  :0] r0,                                        // remainder entering row 0 (< d)
	 input [R-1:0] nb,                                        // dividend bit each row takes, nb[R-1] in row 0
	 input [N-1:0] d,                                         // divisor
	 input [S-1:0] side,                                      // carried along, untouched
	output [R-1:0] q,                                         // quotient, q[R-1] from row 0
	output [N  :0] rem,                                       // final remainder (< d)
	output [S-1:0] side_o,
	 input         clk
);

// the first row of group s (group 0 starts at row 0), chosen so that every
// cycle carries the same logic, the outside logic included: with PRE + R rows
// + POST in all, group s starts where s/STG of it is behind,
// round(s*(PRE+R+POST)/STG - PRE) rows into the array (kept within it and one
// row apart); and the group a row falls in
function integer first_row(input integer s);
	integer b10, b;
	begin
		b10 = (s * (PRE10 + 10*R + POST10)) / STG - PRE10;     // tenths of a row
		b   = (b10 + 5) / 10;
		if (b < s)         b = s;                              // at least one row a group
		if (b > R-(STG-s)) b = R-(STG-s);
		first_row = (s <= 0) ? 0 : b;
	end
endfunction

function integer group_of(input integer row);
	integer i;
	begin
		group_of = 0;
		for (i = 1; i < STG; i = i+1) if (row >= first_row(i)) group_of = i;
	end
endfunction

wire [N  :0] rp [0:R];                                    // partial remainders (< d after each row)
wire [N  :0] rin[0:R-1];                                  // the remainder each row starts from
wire [N-1:0] dv [0:R-1];                                  // the divisor each row subtracts
wire [R-1:0] nbv;                                         // the dividend bits the rows take
wire [R-1:0] qc;                                          // quotient bits as each row computes them

assign rp[0] = r0;

genvar r, s;
generate
	for (r = 0; r < R; r = r+1) begin : row
		wire [N+1:0] shr = {rin[r], nbv[R-1-r]};          // remainder << 1 | bit
		wire [N+1:0] dif = shr - {2'b00, dv[r]};

		assign qc[R-1-r] = ~dif[N+1];                     // no borrow: the divisor fits
		assign rp[r+1  ] = (qc[R-1-r]) ? dif[N:0] : shr[N:0];
	end

	for (s = 1; s < STG; s = s+1) begin : cut                 // the register in front of group s
		localparam integer B  = first_row(s  );               // its first row
		localparam integer BP = first_row(s-1);               // the previous group's first row
		reg  [N  :0] rreg  = 0;                               // the remainder entering row B
		reg  [R-1:0] qreg  = 0;                               // quotient bits of rows [0, B)
		reg  [N-1:0] dreg  = 0;                               // the divisor
		reg  [R-1:0] nbreg = 0;                               // the dividend bits
		reg  [S-1:0] sreg  = 0;                               // side
		wire [R-1:0] qprev;
		wire [N-1:0] dprev;
		wire [R-1:0] nbprev;
		wire [S-1:0] sprev;
		if (s == 1) begin : first
			assign qprev = {R{1'b0}}; assign dprev = d;           assign nbprev = nb;            assign sprev = side;
		end else begin : later
			assign qprev = cut[s-1].qreg; assign dprev = cut[s-1].dreg; assign nbprev = cut[s-1].nbreg; assign sprev = cut[s-1].sreg;
		end
		integer k;
		always @ (posedge clk) begin
			rreg  <= rp[B];
			dreg  <= dprev;
			nbreg <= nbprev;
			sreg  <= sprev;
			for (k = 0; k < R; k = k+1)                        // rows [BP, B) from this group, [0, BP) carried
				qreg[R-1-k] <= (k < BP) ? qprev[R-1-k] : (k < B) ? qc[R-1-k] : 1'b0;
		end
	end

	for (r = 0; r < R; r = r+1) begin : link
		localparam integer GR = group_of(r);
		if (GR > 0 && r == first_row(GR)) begin : starts
			assign rin[r] = cut[GR].rreg;
		end else begin : plain
			assign rin[r] = rp[r];
		end
		if (GR > 0) begin : late_op
			assign dv [r]     = cut[GR].dreg;
			assign nbv[R-1-r] = cut[GR].nbreg[R-1-r];
		end else begin : early_op
			assign dv [r]     = d;
			assign nbv[R-1-r] = nb[R-1-r];
		end
	end

	if (STG > 1) begin : out_late
		for (r = 0; r < R; r = r+1) begin : qsel
			if (r < first_row(STG-1)) begin : early assign q[R-1-r] = cut[STG-1].qreg[R-1-r]; end
			else                      begin : late  assign q[R-1-r] = qc[R-1-r];              end
		end
		assign side_o = cut[STG-1].sreg;
	end else begin : out_now
		assign q      = qc;
		assign side_o = side;
	end
endgenerate

assign rem = rp[R];

endmodule

// DIV / MOD - fixed-point division and remainder -----------------------------
// One array for both: the quotient comes out of the rows, the remainder is
// what the last one leaves; the ALU's operation (the last word: QUO or REM)
// picks which. Truncating signed division (C, Verilog) from the magnitudes:
// the quotient is negative when the signs differ, the remainder takes the
// dividend's sign. INT_MIN / -1, the one quotient that does not fit, wraps
// to INT_MIN by itself (|INT_MIN| / 1 negated in NUBITS bits), which is what
// Verilog defines and what both simulators now agree on (TODO 11a). A zero
// divisor gives the array's all-ones quotient (undefined, issue #34).

module ula_idiv
#(
	parameter NUBITS = 32,
	parameter PRE10  = 15,                                    // see div_array: the magnitudes count here
	parameter POST10 = 28,                                    //   and the sign correction there
	parameter STG    =  5                                     // cycles (Compilers/common ASM_DIV_WORDS_INT)
)(
	 input signed [NUBITS-1:0] in1, in2,                      // in1 / in2, in1 % in2
	output signed [NUBITS-1:0] quo, rem,
	 input                     clk
);

wire [NUBITS-1:0] a = in1[NUBITS-1] ? -in1 : in1;
wire [NUBITS-1:0] b = in2[NUBITS-1] ? -in2 : in2;
wire [NUBITS-1:0] q;
wire [NUBITS  :0] r;
wire        [1:0] sg;                                     // {quotient negative, remainder negative}

div_array #(NUBITS,NUBITS,2,STG,PRE10,POST10) arr({(NUBITS+1){1'b0}}, a, b,
                                                {in1[NUBITS-1] ^ in2[NUBITS-1], in1[NUBITS-1]},
                                                q, r, sg, clk);

assign quo = sg[1] ? -q              : q;
assign rem = sg[0] ? -r[NUBITS-1:0] : r[NUBITS-1:0];

endmodule

// F_DIV - floating-point division --------------------------------------------

module ula_fdiv
#(
	parameter MAN    = 23,
	parameter EXP    =  8,
	parameter FROUND =  0,
	parameter G      =  0,
	// the logic in the same register-to-register path outside the array, in
	// tenths of an array row: before it (data memory read, operand select) and
	// after it (slice, normaliser, ALU output mux, jump decision, PC). Measured
	// on the Cyclone V (2026-10-04): ~2.6 ns and ~11.3 ns against ~3.1 ns a row.
	parameter PRE10  =  8,
	parameter POST10 = 36,
	parameter STG    =  4                                     // cycles (Compilers/common ASM_DIV_WORDS_FLT)
)(
	 input [MAN+EXP    :0] in1, in2,
	output [MAN+EXP+G+2:0] out,                               // exponent 2 bits wider (see ula_norm)
	 input                 clk
);

localparam W = MAN+G;

wire                  s1 = in1[MAN+EXP      ];
wire                  s2 = in2[MAN+EXP      ];
wire signed [EXP+1:0] e1 = {{2{in1[MAN+EXP-1]}}, in1[MAN+EXP-1:MAN]};
wire signed [EXP+1:0] e2 = {{2{in2[MAN+EXP-1]}}, in2[MAN+EXP-1:MAN]};
wire        [MAN-1:0] m1 = in1[MAN    -1:0  ];
wire        [MAN-1:0] m2 = in2[MAN    -1:0  ];

// restoring divider array ----------------------------------------------------
// Quotient of the dividend m1 << K by m2, one row per quotient bit. The `/`
// operator would build a row per dividend bit (2*MAN of them); with a
// normalized divisor (m2 >= 2^(MAN-1)) the quotient has only K+1 bits, so the
// array keeps K+1 rows: the top MAN-1 dividend bits go straight into the
// first partial remainder (they are already below the divisor). The final
// partial remainder is the division's remainder: nonzero means the quotient
// was truncated, which is exactly the sticky bit level 2 needs.
//   level 0:  K = MAN-1    -> MAN   quotient bits (the legacy slice)
//   level 1:  K = MAN      -> MAN+1 bits, the top one says where the slice is
//   level 2:  K = MAN+G-1  -> MAN+G bits: mantissa, guard, round (+ sticky from the remainder)

localparam K = (FROUND == 0) ? MAN-1 : (G == 0) ? MAN : MAN+G-1;
localparam R = K+1;                                       // quotient bits = rows

// what the slice needs from the operands travels with the array: the sign,
// the exponent difference, and whether the divisor is zero
wire                  s_in  = (s1 != s2);
wire signed [EXP+1:0] e_in  = e1 - e2 - MAN[EXP+1:0];
wire                  dz_in = (m2 == {MAN{1'b0}});

wire [R-1:0] q;                                           // quotient bits
wire [MAN:0] rem;                                         // final remainder
wire [EXP+3:0] side;

// the top MAN-1 dividend bits enter as the first remainder, m1[0] in row 0,
// zeros below it
div_array #(MAN,R,EXP+4,STG,PRE10,POST10) arr({2'b00, m1[MAN-1:1]}, {m1[0], {(R-1){1'b0}}}, m2,
                                            {s_in, e_in, dz_in}, q, rem, side, clk);

wire                  s_out = side[EXP+3];
wire signed [EXP+1:0] e_dif = side[EXP+2:1];
wire                  dz    = side[0];
wire                  stk   = |rem;                       // remainder != 0

// pick the slice ---------------------------------------------------------------

wire signed [EXP+1:0] e_out;
wire        [W-1  :0] m_out;

generate if (FROUND == 0) begin : legacy
	// MAN quotient bits; when m1 < m2 the top one is 0 and the LSB is lost
	assign e_out = e_dif + {{EXP+1{1'b0}}, 1'b1};
	assign m_out = q[MAN-1:0];
end else begin : ranged
	wire top = q[R-1];                                     // quotient occupies its top bit
	wire signed [EXP+1:0] e_q = e_dif + {{EXP+1{1'b0}}, top};
	wire        [W-1  :0] m_q;
	if (G == 0) begin : keep_lsb
		assign m_q = (top) ? q[MAN:1] : q[MAN-1:0];
	end else begin : keep_lsb_sticky
		// guard and round are quotient bits; the sticky is the remainder (plus
		// the quotient bit that falls off the slice when the top bit is set)
		assign m_q = (top) ? {q[MAN+G-1:1], q[0] | stk} : {q[MAN+G-2:0], stk};
	end
	// division by zero: saturate (the ALU's +-infinity). The exponent is above
	// every valid one with room for the rounding carry: at level 2 the all-ones
	// mantissa rounds up, and the largest exponent of the field wrapped to a
	// negative one, so x / 0 came out 0 (found by Scripts/hw/tb_ula.v)
	assign e_out = (dz) ? {2'b00, {EXP{1'b1}}} : e_q;      // above every exponent -> ula_norm saturates
	assign m_out = (dz) ? {W{1'b1}}               : m_q;
end endgenerate

assign out = {s_out, e_out, m_out};

endmodule

// SGN - takes the sign of the first argument ---------------------------------

module ula_sgn
#(
	parameter NUBITS = 32
)(
	 input signed [NUBITS-1:0] in1, in2,
	output signed [NUBITS-1:0] out
);

assign out =  (in1[NUBITS-1] == in2[NUBITS-1]) ? in2 : -in2;

endmodule

// F_SGN - takes the sign of the first argument in float ----------------------

module ula_fsgn
#(
	parameter MAN    = 23,
	parameter EXP    =  8,
	parameter FROUND =  0
)(
	 input [MAN+EXP:0] in1, in2,
	output [MAN+EXP:0] out
);

wire signed [EXP-1:0] e_out = in2[EXP+MAN-1:MAN];
wire        [MAN-1:0] m_out = in2[MAN    -1:  0];
wire                  zero  = (FROUND != 0) & (m_out == {MAN{1'b0}}); // FROUND >= 1: zero stays canonical (+0)
wire                  s_out = (zero) ? 1'b0 : in1[EXP+MAN];

assign out = {s_out, e_out, m_out};

endmodule

// ****************************************************************************
// One-parameter arithmetic operations ****************************************
// ****************************************************************************

// NEG - negation of an integer -----------------------------------------------

module ula_neg
#(
	parameter NUBITS = 32
)(
	 input signed [NUBITS-1:0] in,
	output signed [NUBITS-1:0] out
);

assign out = -in;

endmodule

// F_NEG - negation of a floating-point number --------------------------------

module ula_fneg
#(
	parameter MAN    = 23,
	parameter EXP    =  8,
	parameter FROUND =  0
)(
	 input [MAN+EXP:0] in,
	output [MAN+EXP:0] out
);

wire                  s_in = in[MAN+EXP      ];
wire signed [EXP-1:0] e_in = in[MAN+EXP-1:MAN];
wire        [MAN-1:0] m_in = in[MAN    -1:0  ];

wire                  zero  = (FROUND != 0) & (m_in == {MAN{1'b0}}); // FROUND >= 1: zero stays canonical (+0)
wire                  s_out = (zero) ? 1'b0 : ~s_in;
wire signed [EXP-1:0] e_out =  e_in;
wire        [MAN-1:0] m_out =  m_in;

assign out = {s_out, e_out, m_out};

endmodule

// ABS - absolute value of an integer -----------------------------------------

module ula_abs
#(
	parameter NUBITS = 32
)(
	 input [NUBITS-1:0] in,
	output [NUBITS-1:0] out
);

assign out = (in[NUBITS-1]) ? -in : in;

endmodule

// F_ABS - absolute value of a floating-point number --------------------------

module ula_fabs
#(
	parameter MAN = 23,
	parameter EXP = 8
)(
	 input [MAN+EXP:0] in,
	output [MAN+EXP:0] out
);

wire                  s_out = 0;
wire signed [EXP-1:0] e_out = in[EXP+MAN-1:MAN];
wire        [MAN-1:0] m_out = in[MAN    -1:  0];

assign out = {s_out, e_out, m_out};

endmodule

// PST - zero if negative -----------------------------------------------------

module ula_pst
#(
	parameter NUBITS = 32
)(
	 input [NUBITS-1:0] in,
	output [NUBITS-1:0] out
);

assign out = (in[NUBITS-1]) ? {NUBITS{1'b0}} : in;

endmodule

// F_PST - zero if negative for float -----------------------------------------

module ula_fpst
#(
	parameter MAN = 23,
	parameter EXP = 8
)(
	 input [MAN+EXP:0] in,
	output [MAN+EXP:0] out
);

assign out = (in[MAN+EXP]) ? {1'b0, 1'b1, {MAN+EXP-1{1'b0}}} : in;

endmodule

// NRM - division by a constant -----------------------------------------------

// NUGAIN is a power of two: asmcomp refuses anything else, because `/` by a
// constant that is not one infers a divider (measured at 32 bits: 100 -> 406
// LUT4 / 70 levels, 3 -> 264 / 38) where a power of two is a shift plus the
// sign correction of a truncating division (64 -> 152 / 12).

module ula_nrm
#(
	parameter                     NUBITS = 32,
	parameter signed [NUBITS-1:0] NUGAIN =  1
)(
	 input    signed [NUBITS-1:0] in,
	output    signed [NUBITS-1:0] out
);

assign out = in/NUGAIN;

endmodule

// I2F - converts int to float ------------------------------------------------

// FROUND 0 converts only the low MAN bits of the word (an int beyond
// +-2^(MAN-1) wraps silently). FROUND >= 1 converts the whole word: the
// magnitude is pre-aligned here so that its top MAN bits (plus the G extra
// bits) go to ula_norm, which truncates (level 1) or rounds (level 2) them.

module ula_i2f
#(
	parameter NUBITS = 32,
	parameter MAN    = 23,
	parameter EXP    =  8,
	parameter FROUND =  0,
	parameter G      =  0
)(
	input  signed [NUBITS-1   :0] in,
	output        [MAN+EXP+G+2:0] out                         // exponent 2 bits wider, G extra mantissa bits (see ula_norm)
);

localparam W = MAN+G;
localparam T = NUBITS-MAN;                                   // magnitude bits above the mantissa (= EXP+1)

wire                  s_out;
wire signed [EXP+1:0] e_out;
wire        [W-1  :0] m_out;

generate if (FROUND == 0) begin : legacy
	wire [MAN-1:0] lo = in[MAN-1:0];
	wire [MAN-1:0] lm = (lo[MAN-1]) ? -lo : lo;
	assign s_out = lo[MAN-1];
	assign e_out = 0;
	assign m_out = lm;                                       // G is 0 at this level
end else begin : full
	localparam LZW = $clog2(T+1);
	wire [NUBITS-1:0] neg = -in;
	wire [NUBITS-1:0] mag = (in[NUBITS-1]) ? neg : in;      // unsigned magnitude (2^(NUBITS-1) for the most negative int)
	wire [T-1     :0] top = mag[NUBITS-1:MAN];
	// leading zeros of the top field, saturating at T (int fits the mantissa)
	integer k, lzi;
	always @ (*) begin lzi = T; for (k = 0; k < T; k = k+1) if (top[k]) lzi = T-1-k; end
	wire [LZW-1   :0] lz   = lzi[LZW-1:0];
	wire [NUBITS-1:0] magn = mag << lz;                      // leading one at bit NUBITS-1 (or int << T when it fits)
	wire [MAN-1   :0] mnt  = magn[NUBITS-1:T];
	wire [T-1     :0] xtr  = magn[T-1:0];                    // the bits below the mantissa
	assign s_out = in[NUBITS-1];
	assign e_out = T[EXP+1:0] - {{(EXP+2-LZW){1'b0}}, lz};  // weight of mnt's LSB
	if (G != 0) begin : rne
		assign m_out = {mnt, xtr[T-1], xtr[T-2], |xtr[T-3:0]}; // guard, round, sticky
	end else begin : trunc
		assign m_out = mnt;
	end
end endgenerate

assign out = {s_out, e_out, m_out};

endmodule

// F2I - converts float to int ------------------------------------------------

module ula_f2i
#(
	parameter MAN    = 23,
	parameter EXP    =  8,
	parameter FROUND =  0
)(
	input             [MAN+EXP :0] in,
	output reg signed [MAN+EXP :0] out
);

wire           s = in[MAN+EXP      ];
wire [EXP-1:0] e = in[MAN+EXP-1:MAN];
wire [MAN-1:0] m = in[MAN    -1:  0];

wire        [EXP-1:0] shift = (e[EXP-1]) ? -e : e;
// shift the magnitude (logical), then apply the sign — truncates toward zero,
// as C/IEEE float->int conversion requires (a signed >>> would floor instead).
// m_ext widens m (MAN bits) to the final mag width (MAN+EXP+1) so the shift
// operates at the destination width — Verilator otherwise warns WIDTHEXPAND.
wire        [MAN+EXP:0] m_ext = {{(EXP+1){1'b0}}, m};
// one shifter for both directions: the left shift (e >= 0) is a right shift
// of the bit-reversed word, reversed again on the way out (the reversal is
// wiring); the exponent sign selects
wire        [MAN+EXP:0] m_rev, sh_out, sh_rev;
genvar i;
generate for (i = 0; i <= MAN+EXP; i = i+1) begin : rev
	assign m_rev [i] = m_ext [MAN+EXP-i];
	assign sh_rev[i] = sh_out[MAN+EXP-i];
end endgenerate
wire        [MAN+EXP:0] sh_in = (e[EXP-1]) ? m_ext  : m_rev;
assign                  sh_out = sh_in >> shift;
wire        [MAN+EXP:0] mag   = (e[EXP-1]) ? sh_out : sh_rev;
wire        [MAN+EXP:0] val   = (s) ? -mag : mag;

// FROUND >= 1: saturate instead of wrapping. A normalized mantissa is at least
// 2^(MAN-1), so the value reaches 2^(MAN+EXP) as soon as e > EXP.
wire signed [EXP+1:0] ew  = {{2{e[EXP-1]}}, e};
wire                  ovf = (FROUND != 0) & (ew > EXP);   // ew sign-extended to compare with EXP

always @ (*) out = (ovf) ? ((s) ? {1'b1, {(MAN+EXP){1'b0}}} : {1'b0, {(MAN+EXP){1'b1}}}) : val;

endmodule

// ****************************************************************************
// Two-parameter logical operations *******************************************
// ****************************************************************************

// AND - bitwise AND (&) ------------------------------------------------------

module ula_and
#(
	parameter NUBITS = 32
)(
	 input [NUBITS-1:0] in1, in2,
	output [NUBITS-1:0] out
);

assign out = in1 & in2;

endmodule

// ORR - bitwise OR (|) -------------------------------------------------------

module ula_or
#(
	parameter NUBITS = 32
)(
	 input [NUBITS-1:0] in1, in2,
	output [NUBITS-1:0] out
);

assign out = in1 | in2;

endmodule

// XOR - bitwise XOR (^) ------------------------------------------------------

module ula_xor
#(
	parameter NUBITS = 32
)(
	 input [NUBITS-1:0] in1, in2,
	output [NUBITS-1:0] out
);

assign out = (in1 ^ in2);

endmodule

// ****************************************************************************
// One-parameter logical operations *******************************************
// ****************************************************************************

// INV - bitwise inversion (~) ------------------------------------------------

module ula_inv
#(
	parameter NUBITS = 32
)(
	 input signed [NUBITS-1:0] in,
	output signed [NUBITS-1:0] out
);

assign out = ~in;

endmodule

// ****************************************************************************
// Two-parameter conditional operations ***************************************
// ****************************************************************************

// LAN - if one of the conditions is zero -> outputs zero (&&) ----------------

module ula_lan
#(
	parameter  NUBITS = 32
)(
	 input    [NUBITS-1:0] in1, in2,
	output    [NUBITS-1:0] out
);

assign out = ((in1 == {NUBITS{1'b0}}) || (in2 == {NUBITS{1'b0}})) ? {NUBITS{1'b0}} : {{NUBITS-1{1'b0}}, 1'b1};

endmodule

// LOR - if one of the conditions is one -> outputs one (||) ------------------

module ula_lor
#(
	parameter  NUBITS = 32
)(
	 input    [NUBITS-1:0] in1, in2,
	output    [NUBITS-1:0] out
);

assign out = ((in1 == {NUBITS{1'b0}}) && (in2 == {NUBITS{1'b0}})) ? {NUBITS{1'b0}} : {{NUBITS-1{1'b0}}, 1'b1};

endmodule

// ****************************************************************************
// One-parameter conditional operations ***************************************
// ****************************************************************************

// LIN - inverts the condition ------------------------------------------------

module ula_lin
#(
	parameter NUBITS = 32
)(
	 input   [NUBITS-1:0] in,
	output   [NUBITS-1:0] out
);

assign out = (in  == {NUBITS{1'b0}}) ? {{NUBITS-1{1'b0}}, 1'b1} : {NUBITS{1'b0}};

endmodule

// ****************************************************************************
// Comparison operations ******************************************************
// ****************************************************************************

// LES - less than ------------------------------------------------------------

module ula_les
#(
	parameter NUBITS = 32
)(
	 input signed [NUBITS-1:0] in1, in2,
	output        [NUBITS-1:0] out
);

// zero-extend the 1-bit comparison result to NUBITS so Verilator does not
// warn WIDTHEXPAND on the ASSIGNW. Semantics are unchanged: false -> all
// zeros, true -> ...0001.
assign out = {{(NUBITS-1){1'b0}}, (in1 < in2)};

endmodule

// F_LES / F_GRE - floating-point comparisons (one unit, in1 < in2 and in1 > in2)

// Lexicographic compare of the raw words: no alignment, so a program that only
// compares floats builds no denormalizer (and the compare no longer waits for
// the shifter). The format has no hidden bit, so the mantissa of a normalized
// value always has its top bit set and the magnitude order is the plain
// unsigned order of {exponent, mantissa} - once the two's-complement exponent
// is biased into unsigned order by flipping its sign bit. A zero mantissa is
// the value zero whatever the exponent field carries (FROUND 0 does not
// canonicalize zeros), so zeros are forced to the bottom of that order and
// their sign bit is ignored: +0 == -0, as they were when the comparison
// subtracted the aligned two's-complement forms.
//
// This relies on a property of every word the machine holds: the mantissa is
// normalized, or the exponent is the minimum one. ula_norm normalizes every
// result, and the constant encoder (f2mf) clamps every denormal to the same
// minimum exponent - which is what keeps the order exact for denormals too
// (sharing the exponent, they are ordered by mantissa, and any normal number
// at that exponent is larger than all of them). An unnormalized mantissa at a
// larger exponent would be misordered, but only an input port writing raw bits
// can produce one; at FROUND >= 1 the same words already break F_MLT/F_DIV,
// which assume normalized operands. Scripts/hw/tb_alu.v checks the order
// against real-valued arithmetic over the words the machine can hold, and
// counts the out-of-format ones separately.

module ula_fcmp
#(
	parameter NUBITS = 32,
	parameter MAN    = 23,
	parameter EXP    =  8
)(
	 input  [NUBITS-1:0] in1, in2,
	output [NUBITS-1:0] les, gre                          // in1 < in2, in1 > in2
);

wire z1 = (in1[MAN-1:0] == {MAN{1'b0}});                  // the value is zero
wire z2 = (in2[MAN-1:0] == {MAN{1'b0}});

wire s1 = in1[MAN+EXP] & ~z1;                             // a zero is always +0
wire s2 = in2[MAN+EXP] & ~z2;

// magnitude key: exponent with its sign bit flipped, then the mantissa; a zero
// sorts below every non-zero magnitude (its key cannot be 0 - the mantissa is
// not zero)
wire [MAN+EXP-1:0] k1 = (z1) ? {MAN+EXP{1'b0}} : {~in1[MAN+EXP-1], in1[MAN+EXP-2:0]};
wire [MAN+EXP-1:0] k2 = (z2) ? {MAN+EXP{1'b0}} : {~in2[MAN+EXP-1], in2[MAN+EXP-2:0]};

wire ltk = (k1 < k2);
wire gtk = (k1 > k2);

assign les = {{(NUBITS-1){1'b0}}, (s1 != s2) ? s1 : (s1) ? gtk : ltk};
assign gre = {{(NUBITS-1){1'b0}}, (s1 != s2) ? s2 : (s1) ? ltk : gtk};

endmodule

// GRE - greater than ---------------------------------------------------------

module ula_gre
#(
	parameter NUBITS = 32
)(
	 input signed [NUBITS-1:0] in1, in2,
	output        [NUBITS-1:0] out
);

assign out = {{(NUBITS-1){1'b0}}, (in1 > in2)};

endmodule

// EQU - equal to -------------------------------------------------------------

module ula_equ
#(
	parameter NUBITS = 32
)(
	 input   [NUBITS-1:0] in1, in2,
	output   [NUBITS-1:0] out
);

assign out = {{(NUBITS-1){1'b0}}, (in1 == in2)};

endmodule

// ****************************************************************************
// Bit-shift operations *******************************************************
// ****************************************************************************

// SHL / SHR / SRS - one right shifter for the three shifts --------------------

// Only one shift ever executes per cycle, so the three barrel shifters are
// folded into one right shifter. A left shift is a right shift of the
// bit-reversed word, reversed again on the way out - the reversal is wiring,
// the two muxes it needs are one LUT level. SRS differs from SHR only in what
// enters from the top: the sign bit instead of zero, which the shift of the
// word widened by that one bit propagates as far as the amount asks - so an
// amount >= NUBITS still gives all zeros (SHL, SHR) or all sign bits (SRS),
// as `<<`, `>>` and `>>>` do. The muxes exist only for the opcodes the
// program has (a program with one shift builds the plain shifter it built
// before).

module ula_shift
#(
	parameter NUBITS = 32,
	parameter SHL    = 0,
	parameter SHR    = 0,
	parameter SRS    = 0
)(
	 input     [       5:0] op,
	 input     [NUBITS-1:0] in1, in2,                         // word, amount
	output     [NUBITS-1:0] out
);

// each select is a parameter constant when its shift is the only one the
// program has, so the muxes fold away and the plain shifter of that opcode
// remains (measured: a dynamic select on an SHL-only processor cost +19 %)
wire left  = (SHL != 0) & (((SHR | SRS) == 0) | (op == 6'd43));  // SHL: reverse in and out
wire arith = (SRS != 0) & (((SHL | SHR) == 0) | (op == 6'd45));  // SRS: fill with the sign

// bit reversal, both ways (wiring)
wire [NUBITS-1:0] in1_r, y, y_r;
genvar i;
generate for (i = 0; i < NUBITS; i = i+1) begin : rev
	assign in1_r[i] = in1[NUBITS-1-i];
	assign y_r  [i] = y  [NUBITS-1-i];
end endgenerate

wire        [NUBITS-1:0] x    = (left) ? in1_r : in1;
wire                     fill = arith & in1[NUBITS-1];
wire signed [NUBITS  :0] xe   = {fill, x};                    // one bit wider: the fill bit is its sign
wire signed [NUBITS  :0] ye   = xe >>> in2;
assign                   y    = ye[NUBITS-1:0];

assign out = (left) ? y_r : y;

endmodule

// ****************************************************************************
// Special operations *********************************************************
// ****************************************************************************

// F_ROT - nearest power of 2 to the square root ------------------------------

module ula_frot
#(
	parameter MAN = 23,
	parameter EXP =  8,
	parameter G   =  0
)(
	 input [MAN+EXP    :0] in,
	output [MAN+EXP+G+2:0] out                                // exponent 2 bits wider, G extra mantissa bits (see ula_norm)
);

wire                  s_in  = in[MAN+EXP      ];
wire signed [EXP-1:0] e_in  = in[MAN+EXP-1:MAN];
wire        [MAN-1:0] m_in  = in[MAN    -1:0  ];

wire                  s_out = s_in;
wire signed [EXP-1:0] e_hlf = (e_in+(MAN-1))/2;
wire signed [EXP+1:0] e_out = {{2{e_hlf[EXP-1]}}, e_hlf};
wire        [MAN-1:0] m_one = 1;
wire        [MAN+G-1:0] m_out;                               // exact: the G extra bits are zero

generate if (G != 0) begin : ext assign m_out = {m_one, {G{1'b0}}}; end
         else            begin : nox assign m_out = m_one;             end endgenerate

assign out = {s_out, e_out, m_out};

endmodule

// F_SCL - scale a float by a power of two: out = in2 * 2^in1 -----------------
// in1 is a signed integer k; the exponent field gets k added to it (value =
// mantissa*2^e), saturating to the EXP-bit range. The mantissa is unchanged, so
// a normalized input stays normalized (no re-normalization needed). The sum is
// one bit wider than the word: k near INT_MAX must saturate up, not wrap to a
// negative sum (exp() of a huge x, whose k F2I saturates). A zero stays the
// canonical zero at FROUND >= 1, as F_NEG/F_SGN keep it: the float == is a
// compare of the words.

module ula_scl
#(
	parameter MAN    = 23,
	parameter EXP    =  8,
	parameter FROUND =  0
)(
	 input  signed [MAN+EXP:0] in1,                 // k (signed integer)
	 input         [MAN+EXP:0] in2,                 // x (normalized float)
	output         [MAN+EXP:0] out
);

wire                  s = in2[MAN+EXP      ];
wire signed [EXP-1:0] e = in2[MAN+EXP-1:MAN];
wire        [MAN-1:0] m = in2[MAN    -1:0  ];

wire signed [MAN+EXP+1:0] esum = $signed(e) + in1;              // e + k (one bit wider than k)
localparam signed [MAN+EXP+1:0] EMAX =  (1 <<< (EXP-1)) - 1;    //  127 for EXP=8
localparam signed [MAN+EXP+1:0] EMIN = -(1 <<< (EXP-1));        // -128 for EXP=8
wire signed [EXP-1:0] e_out = (esum > EMAX) ? EMAX[EXP-1:0] :
                              (esum < EMIN) ? EMIN[EXP-1:0] : esum[EXP-1:0];
wire                  zero  = (FROUND != 0) & (m == {MAN{1'b0}}); // FROUND >= 1: zero stays canonical (+0)

assign out = (zero) ? {1'b0, EMIN[EXP-1:0], m} : {s, e_out, m};

endmodule

// XPO - base-2 exponent of a float as a signed int ---------------------------
// value = mantissa_int * 2^e with mantissa_int in [2^(MAN-1),2^MAN) when
// normalized, so floor(log2|x|) = e + (MAN-1). out is that integer, and 0 for
// the all-zero word only. The zero the machine holds (zero mantissa, minimum
// exponent) gives EMIN + MAN-1 (-106 at 32/23/8), the floor of the smallest
// normal: "very small", which suits log(). A denormal (FROUND 0 only) is read
// as if normalized: its leading zeros are not counted.

module ula_xpo
#(
	parameter MAN = 23,
	parameter EXP =  8
)(
	 input         [MAN+EXP:0] in,
	output signed [MAN+EXP:0] out
);

wire signed [EXP-1:0]   e    = in[MAN+EXP-1:MAN];
wire                    nz   = |in[MAN+EXP-1:0];            // nonzero magnitude
wire signed [MAN+EXP:0] bias = MAN-1;                       // 22, full-width signed

// compute the signed sum in its OWN signed wire first (like ula_scl's esum) so e
// is sign-extended; doing it inside the ?: would pick up the unsigned else branch.
wire signed [MAN+EXP:0] xval = $signed(e) + bias;          // e + (MAN-1)

assign out = nz ? xval : {(MAN+EXP+1){1'b0}};

endmodule

// ****************************************************************************
// Main Circuit ***************************************************************
// ****************************************************************************

module ula
#(
	// General
	parameter                     NUBITS = 32,
	parameter                     NBMANT = 23,
	parameter                     NBEXPO =  8,
	parameter signed [NUBITS-1:0] NUGAIN = 128,   // defaults: the one set named at the top of processor.v
	// float rounding level (#FROUND): 0 legacy (truncate, exponent wraps, bit-identical
	// to the original datapath), 1 keep the LSB before normalization + saturate/flush
	// + canonical zero, 2 as 1 + round to nearest even (guard/round/sticky bits)
	parameter                     FROUND =  0,

	// two-parameter arithmetic operations
	parameter   ADD   = 0,
	parameter F_ADD   = 0,
	parameter   MLT   = 0,
	parameter F_MLT   = 0,
	parameter   DIV   = 0,
	parameter F_DIV   = 0,
	parameter   MOD   = 0,
	parameter   SGN   = 0,
	parameter F_SGN   = 0,

	// one-parameter arithmetic operations
	parameter   NEG   = 0,
	parameter   NEG_M = 0,
	parameter F_NEG   = 0,
	parameter F_NEG_M = 0,
	parameter   ABS   = 0,
	parameter   ABS_M = 0,
	parameter F_ABS   = 0,
	parameter F_ABS_M = 0,
	parameter   PST   = 0,
	parameter   PST_M = 0,
	parameter F_PST   = 0,
	parameter F_PST_M = 0,
	parameter   NRM   = 0,
	parameter   NRM_M = 0,
	parameter   I2F   = 0,
	parameter   I2F_M = 0,
	parameter   F2I   = 0,
	parameter   F2I_M = 0,

	// two-parameter logical operations
	parameter   AND   = 0,
	parameter   ORR   = 0,
	parameter   XOR   = 0,

	// one-parameter logical operations
	parameter   INV   = 0,
	parameter   INV_M = 0,

	// two-parameter conditional operations
	parameter   LAN   = 0,
	parameter   LOR   = 0,

	// one-parameter conditional operations
	parameter   LIN   = 0,
	parameter   LIN_M = 0,

	// comparison operations
	parameter   LES   = 0,
	parameter F_LES   = 0,
	parameter   GRE   = 0,
	parameter F_GRE   = 0,
	parameter   EQU   = 0,

	// bit-shift operations
	parameter   SHL   = 0,
	parameter   SHR   = 0,
	parameter   SRS   = 0,

	// special operations
	parameter F_ROT   = 0,
	parameter F_SU1   = 0,
	parameter F_SU2   = 0,
	parameter F_SCL   = 0,
	parameter XPO     = 0,
	parameter XPO_M   = 0)
(
	input         [       5:0] op,
	input  signed [NUBITS-1:0] in1, in2,
	output signed [NUBITS-1:0] out,
	output        [NUBITS-1:0] out_fast,               // out without the normalised operations (JIZ)
	input                      clk                     // the dividers' register cuts
);

// floating-point rounding level ----------------------------------------------

// FROUND 2 carries G = 3 extra bits (guard, round, sticky) below the mantissa
// from the denormalizer / operators up to the normalizer, which rounds them off.
// The operators also hand the normalizer an exponent 2 bits wider than the
// format (NUBITS+G+2 wires), so overflow/underflow can be detected there.
localparam G = (FROUND == 2) ? 3 : 0;

// floating-point denormalization circuit -------------------------------------

wire signed [NBEXPO-1:0] e_out;                       // the larger exponent
wire                     dn_s_big, dn_s_small;        // operand signs, big/small order
wire      [NBMANT+G-1:0] dn_m_big, dn_m_small;        // aligned magnitudes (+ G extra bits)
// F_SU1/F_SU2 are 32-bit parameters; cast to 1 bit with `!= 0` so the AND
// with the 1-bit op-equality stays 1 bit and matches the 1-bit su{1,2} LHS.
wire					 su1 = (F_SU1 != 0) & (op == 6'd47); // invert sign of in1 for F_SU1
wire                     su2 = (F_SU2 != 0) & (op == 6'd48); // invert sign of in2 for F_SU2

generate if ((F_ADD | F_SU1 | F_SU2) != 0) begin : op_denorm ula_denorm #(NBMANT,NBEXPO,G) denorm(su1, su2, in1, in2, e_out, dn_s_big, dn_s_small, dn_m_big, dn_m_small); end endgenerate

// ADD ------------------------------------------------------------------------

wire signed [NUBITS-1:0] add;

generate if ((ADD) != 0) begin : op_add ula_add #(NUBITS) my_add(in1, in2, add); end else begin : op_add assign add = {NUBITS{1'b0}}; end endgenerate

// F_ADD ----------------------------------------------------------------------

wire signed [NUBITS+G+1:0] fadd;

generate if ((F_ADD | F_SU1 | F_SU2) != 0) begin : op_fadd ula_fadd #(NBMANT,NBEXPO,FROUND,G) my_fadd(e_out, dn_s_big, dn_s_small, dn_m_big, dn_m_small, fadd); end else begin : op_fadd assign fadd = {NUBITS+G+2{1'b0}}; end endgenerate

// MLT ------------------------------------------------------------------------

wire signed [NUBITS-1:0] mlt;

generate if ((MLT) != 0) begin : op_mlt ula_mlt #(NUBITS) my_mlt(in1, in2, mlt); end else begin : op_mlt assign mlt = {NUBITS{1'b0}}; end endgenerate

// F_MLT ----------------------------------------------------------------------

wire signed [NUBITS+G+1:0] fmlt;

generate if ((F_MLT) != 0) begin : op_fmlt ula_fmlt #(NBMANT,NBEXPO,FROUND,G) my_fmlt(in1 ,in2 , fmlt); end else begin : op_fmlt assign fmlt = {NUBITS+G+2{1'b0}}; end endgenerate

// DIV / MOD ------------------------------------------------------------------
// one divider for both, five cycles (see ula_idiv): DIV/MOD start it, QUO/REM
// read it four words later

wire signed [NUBITS-1:0] div, mod;

generate if ((DIV | MOD) != 0) begin : op_idiv ula_idiv #(NUBITS) my_idiv(in1, in2, div, mod, clk); end else begin : op_idiv assign div = {NUBITS{1'b0}}; assign mod = {NUBITS{1'b0}}; end endgenerate

// F_DIV ----------------------------------------------------------------------
// four cycles (see ula_fdiv): F_DIV starts it, F_QUO reads it three words later

wire signed [NUBITS+G+1:0] fdiv;

generate if ((F_DIV) != 0) begin : op_fdiv ula_fdiv #(NBMANT,NBEXPO,FROUND,G) my_fdiv(in1, in2, fdiv, clk); end else begin : op_fdiv assign fdiv = {NUBITS+G+2{1'b0}}; end endgenerate

// SGN ------------------------------------------------------------------------

wire signed [NUBITS-1:0] sgn;

generate if ((SGN) != 0) begin : op_sgn ula_sgn #(NUBITS) my_sgn(in1, in2, sgn); end else begin : op_sgn assign sgn = {NUBITS{1'b0}}; end endgenerate

// F_SGN ----------------------------------------------------------------------

wire signed [NUBITS-1:0] fsgn;

generate if ((F_SGN) != 0) begin : op_fsgn ula_fsgn #(NBMANT,NBEXPO,FROUND) my_fsgn(in1, in2, fsgn); end else begin : op_fsgn assign fsgn = {NUBITS{1'b0}}; end endgenerate

// NEG ------------------------------------------------------------------------

wire signed [NUBITS-1:0] neg;

generate if ((NEG) != 0) begin : op_neg ula_neg #(NUBITS) my_neg(in2, neg); end else begin : op_neg assign neg = {NUBITS{1'b0}}; end endgenerate

// NEG_M ----------------------------------------------------------------------

wire signed [NUBITS-1:0] negm;

generate if ((NEG_M) != 0) begin : op_negm ula_neg #(NUBITS) my_negm(in1, negm ); end else begin : op_negm assign negm = {NUBITS{1'b0}}; end endgenerate

// F_NEG ----------------------------------------------------------------------

wire signed [NUBITS-1:0] fneg;

generate if ((F_NEG) != 0) begin : op_fneg ula_fneg #(NBMANT,NBEXPO,FROUND) my_fneg(in2, fneg); end else begin : op_fneg assign fneg = {NUBITS{1'b0}}; end endgenerate

// F_NEG_M --------------------------------------------------------------------

wire signed [NUBITS-1:0] fnegm;

generate if ((F_NEG_M) != 0) begin : op_fnegm ula_fneg #(NBMANT,NBEXPO,FROUND) my_fnegm(in1, fnegm); end else begin : op_fnegm assign fnegm = {NUBITS{1'b0}}; end endgenerate

// ABS ------------------------------------------------------------------------

wire signed [NUBITS-1:0] abs;

generate if ((ABS) != 0) begin : op_abs ula_abs #(NUBITS) my_abs(in2, abs); end else begin : op_abs assign abs = {NUBITS{1'b0}}; end endgenerate

// ABS_M ----------------------------------------------------------------------

wire signed [NUBITS-1:0] absm;

generate if ((ABS_M) != 0) begin : op_absm ula_abs #(NUBITS) my_absm(in1, absm); end else begin : op_absm assign absm = {NUBITS{1'b0}}; end endgenerate

// F_ABS ----------------------------------------------------------------------

wire signed [NUBITS-1:0] fabs;

generate if ((F_ABS) != 0) begin : op_fabs ula_fabs #(NBMANT,NBEXPO) my_fabs(in2, fabs); end else begin : op_fabs assign fabs = {NUBITS{1'b0}}; end endgenerate

// F_ABS_M --------------------------------------------------------------------

wire signed [NUBITS-1:0] fabsm;

generate if ((F_ABS_M) != 0) begin : op_fabsm ula_fabs #(NBMANT,NBEXPO) my_fabsm(in1, fabsm); end else begin : op_fabsm assign fabsm = {NUBITS{1'b0}}; end endgenerate

// PST ------------------------------------------------------------------------

wire signed [NUBITS-1:0] pst;

generate if ((PST) != 0) begin : op_pst ula_pst #(NUBITS) my_pst(in2, pst); end else begin : op_pst assign pst = {NUBITS{1'b0}}; end endgenerate

// PST_M ----------------------------------------------------------------------

wire signed [NUBITS-1:0] pstm;

generate if ((PST_M) != 0) begin : op_pstm ula_pst #(NUBITS) my_pstm(in1, pstm); end else begin : op_pstm assign pstm = {NUBITS{1'b0}}; end endgenerate

// F_PST ----------------------------------------------------------------------

wire signed [NUBITS-1:0] fpst;

generate if ((F_PST) != 0) begin : op_fpst ula_fpst #(NBMANT,NBEXPO) my_fpst(in2, fpst); end else begin : op_fpst assign fpst = {NUBITS{1'b0}}; end endgenerate

// F_PST_M --------------------------------------------------------------------

wire signed [NUBITS-1:0] fpstm;

generate if ((F_PST_M) != 0) begin : op_fpstm ula_fpst #(NBMANT,NBEXPO) my_fpstm(in1, fpstm); end else begin : op_fpstm assign fpstm = {NUBITS{1'b0}}; end endgenerate

// NRM ------------------------------------------------------------------------

wire signed [NUBITS-1:0] nrm;

generate if ((NRM) != 0) begin : op_nrm ula_nrm #(NUBITS,NUGAIN) my_nrm(in2, nrm); end else begin : op_nrm assign nrm = {NUBITS{1'b0}}; end endgenerate

// NRM_M ----------------------------------------------------------------------

wire signed [NUBITS-1:0] nrmm;

generate if ((NRM_M) != 0) begin : op_nrmm ula_nrm #(NUBITS,NUGAIN) my_nrmm(in1, nrmm); end else begin : op_nrmm assign nrmm = {NUBITS{1'b0}}; end endgenerate

// I2F ------------------------------------------------------------------------

wire signed [NUBITS+G+1:0] i2f;

generate if ((I2F) != 0) begin : op_i2f ula_i2f #(NUBITS,NBMANT,NBEXPO,FROUND,G) my_i2f (in2, i2f); end else begin : op_i2f assign i2f = {NUBITS+G+2{1'b0}}; end endgenerate

// I2F_M ----------------------------------------------------------------------

wire signed [NUBITS+G+1:0] i2fm;

generate if ((I2F_M) != 0) begin : op_i2fm ula_i2f #(NUBITS,NBMANT,NBEXPO,FROUND,G) my_i2fm(in1, i2fm); end else begin : op_i2fm assign i2fm = {NUBITS+G+2{1'b0}}; end endgenerate

// F2I ------------------------------------------------------------------------

wire signed [NUBITS-1:0] f2i;

generate if ((F2I) != 0) begin : op_f2i ula_f2i #(NBMANT,NBEXPO,FROUND) my_f2i (in2, f2i); end else begin : op_f2i assign f2i = {NUBITS{1'b0}}; end endgenerate

// F2I_M ----------------------------------------------------------------------

wire signed [NUBITS-1:0] f2im;

generate if ((F2I_M) != 0) begin : op_f2im ula_f2i #(NBMANT,NBEXPO,FROUND) my_f2im (in1, f2im); end else begin : op_f2im assign f2im = {NUBITS{1'b0}}; end endgenerate

// AND ------------------------------------------------------------------------

wire signed [NUBITS-1:0] ann;

generate if ((AND) != 0) begin : op_ann ula_and #(NUBITS) my_and(in1, in2, ann); end else begin : op_ann assign ann = {NUBITS{1'b0}}; end endgenerate

// ORR ------------------------------------------------------------------------

wire signed [NUBITS-1:0] orr;

generate if ((ORR) != 0) begin : op_orr ula_or #(NUBITS) my_orr(in1, in2, orr); end else begin : op_orr assign orr = {NUBITS{1'b0}}; end endgenerate

// XOR ------------------------------------------------------------------------

wire signed [NUBITS-1:0] cor;

generate if ((XOR) != 0) begin : op_cor ula_xor #(NUBITS) my_xor(in1, in2, cor); end else begin : op_cor assign cor = {NUBITS{1'b0}}; end endgenerate

// INV ------------------------------------------------------------------------

wire signed [NUBITS-1:0] inv;

generate if ((INV) != 0) begin : op_inv ula_inv #(NUBITS) my_inv (in2, inv); end else begin : op_inv assign inv = {NUBITS{1'b0}}; end endgenerate

// INV_M ----------------------------------------------------------------------

wire signed [NUBITS-1:0] invm;

generate if ((INV_M) != 0) begin : op_invm ula_inv #(NUBITS) my_invm(in1, invm); end else begin : op_invm assign invm = {NUBITS{1'b0}}; end endgenerate

// LAN ------------------------------------------------------------------------

wire signed [NUBITS-1:0] lan;

generate if ((LAN) != 0) begin : op_lan ula_lan #(NUBITS) my_lan(in1, in2, lan); end else begin : op_lan assign lan = {NUBITS{1'b0}}; end endgenerate

// LOR ------------------------------------------------------------------------

wire signed [NUBITS-1:0] lor;

generate if ((LOR) != 0) begin : op_lor ula_lor #(NUBITS) my_lor(in1, in2, lor); end else begin : op_lor assign lor = {NUBITS{1'b0}}; end endgenerate

// LIN ------------------------------------------------------------------------

wire signed [NUBITS-1:0] lin;

generate if ((LIN) != 0) begin : op_lin ula_lin #(NUBITS) my_lin(in2, lin); end else begin : op_lin assign lin = {NUBITS{1'b0}}; end endgenerate

// LIN_M ----------------------------------------------------------------------

wire signed [NUBITS-1:0] linm;

generate if ((LIN_M) != 0) begin : op_linm ula_lin #(NUBITS) my_linm(in1, linm); end else begin : op_linm assign linm = {NUBITS{1'b0}}; end endgenerate

// LES ------------------------------------------------------------------------

wire signed [NUBITS-1:0] les;

generate if ((LES) != 0) begin : op_les ula_les #(NUBITS) my_les(in1, in2, les); end else begin : op_les assign les = {NUBITS{1'b0}}; end endgenerate

// F_LES ----------------------------------------------------------------------

wire signed [NUBITS-1:0] fles;

// one comparator serves F_LES and F_GRE (in1 < in2 and in1 > in2 on the raw words)
wire signed [NUBITS-1:0] fcmp_les, fcmp_gre;
generate if ((F_LES | F_GRE) != 0) begin : op_fcmp ula_fcmp #(NUBITS,NBMANT,NBEXPO) my_fcmp(in1, in2, fcmp_les, fcmp_gre); end else begin : op_fcmp assign fcmp_les = {NUBITS{1'b0}}; assign fcmp_gre = {NUBITS{1'b0}}; end endgenerate
generate if ((F_LES) != 0) begin : op_fles assign fles = fcmp_les; end else begin : op_fles assign fles = {NUBITS{1'b0}}; end endgenerate

// GRE ------------------------------------------------------------------------

wire signed [NUBITS-1:0] gre;

generate if ((GRE) != 0) begin : op_gre ula_gre #(NUBITS) my_gre(in1, in2, gre); end else begin : op_gre assign gre = {NUBITS{1'b0}}; end endgenerate

// F_GRE ----------------------------------------------------------------------

wire signed [NUBITS-1:0] fgre;

generate if ((F_GRE) != 0) begin : op_fgre assign fgre = fcmp_gre; end else begin : op_fgre assign fgre = {NUBITS{1'b0}}; end endgenerate

// EQU ------------------------------------------------------------------------

wire signed [NUBITS-1:0] equ;

generate if ((EQU) != 0) begin : op_equ ula_equ #(NUBITS) my_equ(in1, in2, equ); end else begin : op_equ assign equ = {NUBITS{1'b0}}; end endgenerate

// SHL / SHR / SRS ------------------------------------------------------------

// one right shifter serves the three shifts (see ula_shift); each opcode
// still keeps its own mux input so an absent one stays x
wire signed [NUBITS-1:0] shl, shr, srs, sh_out;

generate if ((SHL | SHR | SRS) != 0) begin : op_shift ula_shift #(NUBITS,SHL,SHR,SRS) my_shift(op, in1, in2, sh_out); end else begin : op_shift assign sh_out = {NUBITS{1'b0}}; end endgenerate
generate if ((SHL) != 0) begin : op_shl assign shl = sh_out; end else begin : op_shl assign shl = {NUBITS{1'b0}}; end endgenerate
generate if ((SHR) != 0) begin : op_shr assign shr = sh_out; end else begin : op_shr assign shr = {NUBITS{1'b0}}; end endgenerate
generate if ((SRS) != 0) begin : op_srs assign srs = sh_out; end else begin : op_srs assign srs = {NUBITS{1'b0}}; end endgenerate

// F_ROT ----------------------------------------------------------------------

wire signed [NUBITS+G+1:0] frot;

generate if ((F_ROT) != 0) begin : op_frot ula_frot #(NBMANT,NBEXPO,G) my_frot(in2, frot); end else begin : op_frot assign frot = {NUBITS+G+2{1'b0}}; end endgenerate

// F_SCL / XPO / XPO_M --------------------------------------------------------
// XPO reads in2 (acc), XPO_M reads in1 (memory) -- mirrors F2I/F2I_M.

wire signed [NUBITS-1:0] fscl;

generate if ((F_SCL) != 0) begin : op_fscl ula_scl #(NBMANT,NBEXPO,FROUND) my_scl(in1, in2, fscl); end else begin : op_fscl assign fscl = {NUBITS{1'b0}}; end endgenerate

wire signed [NUBITS-1:0] xpo;

generate if ((XPO) != 0) begin : op_xpo ula_xpo #(NBMANT,NBEXPO) my_xpo(in2, xpo); end else begin : op_xpo assign xpo = {NUBITS{1'b0}}; end endgenerate

wire signed [NUBITS-1:0] xpom;

generate if ((XPO_M) != 0) begin : op_xpom ula_xpo #(NBMANT,NBEXPO) my_xpom(in1, xpom); end else begin : op_xpom assign xpom = {NUBITS{1'b0}}; end endgenerate

// denormalization mux --------------------------------------------------------

wire signed [NUBITS-1:0] smx;

generate if ((I2F | I2F_M | F_ADD | F_SU1 | F_SU2 | F_MLT | F_DIV | F_ROT) != 0) begin : op_smx norm_mux #(NUBITS,NBMANT,NBEXPO,FROUND,G,
	((I2F | I2F_M | F_ADD | F_SU1 | F_SU2 | F_ROT) != 0) || (FROUND == 0 && (F_MLT | F_DIV) != 0),  // LZC: someone needs the leading-zero count
	(FROUND != 0) && ((F_MLT | F_DIV) != 0),                                                            // DIR: someone takes the direct path
	F_ADD, F_SU1, F_SU2, F_MLT, F_DIV, I2F, I2F_M, F_ROT)
	norm_mux(op, fadd, fmlt, fdiv, i2f, i2fm, frot, smx); end else begin : op_smx assign smx = {NUBITS{1'b0}}; end endgenerate

// main mux -------------------------------------------------------------------

ula_mux #(.NUBITS(NUBITS),
          .ADD(ADD), .F_ADD(F_ADD), .MLT(MLT), .F_MLT(F_MLT), .DIV(DIV), .F_DIV(F_DIV), .MOD(MOD),
          .SGN(SGN), .F_SGN(F_SGN), .NEG(NEG), .NEG_M(NEG_M), .F_NEG(F_NEG), .F_NEG_M(F_NEG_M),
          .ABS(ABS), .ABS_M(ABS_M), .F_ABS(F_ABS), .F_ABS_M(F_ABS_M), .PST(PST), .PST_M(PST_M), .F_PST(F_PST), .F_PST_M(F_PST_M),
          .NRM(NRM), .NRM_M(NRM_M), .I2F(I2F), .I2F_M(I2F_M), .F2I(F2I), .F2I_M(F2I_M),
          .AND(AND), .ORR(ORR), .XOR(XOR), .INV(INV), .INV_M(INV_M),
          .LAN(LAN), .LOR(LOR), .LIN(LIN), .LIN_M(LIN_M),
          .LES(LES), .F_LES(F_LES), .GRE(GRE), .F_GRE(F_GRE), .EQU(EQU),
          .SHL(SHL), .SHR(SHR), .SRS(SRS),
          .F_ROT(F_ROT), .F_SU1(F_SU1), .F_SU2(F_SU2), .F_SCL(F_SCL), .XPO(XPO), .XPO_M(XPO_M))
        ula_mux (.op (op ),
                           .in1(in1),.in2 (in2 ),
                           .add(add),
                           .mlt(mlt),
                           .div(div),
                           .mod(mod),
                           .sgn(sgn),.fsgn(fsgn),
                           .neg(neg),.negm(negm),.fneg(fneg),.fnegm(fnegm),
                           .abs(abs),.absm(absm),.fabs(fabs),.fabsm(fabsm),
                           .pst(pst),.pstm(pstm),.fpst(fpst),.fpstm(fpstm),
                           .nrm(nrm),.nrmm(nrmm),
                           .f2i(f2i),.f2im(f2im),
                           .ann(ann),
                           .orr(orr),
                           .cor(cor),
                           .inv(inv),.invm(invm),
                           .lan(lan),
                           .lor(lor),
                           .lin(lin),.linm(linm),
                           .les(les),.fles(fles),
                           .gre(gre),.fgre(fgre),
                           .equ(equ),
                           .shl(shl),
                           .shr(shr),
                           .srs(srs),
                           .smx(smx),
                           .fscl(fscl),.xpo(xpo),.xpom(xpom),
                           .out(out),.out_fast(out_fast));

// ----------------------------------------------------------------------------
// flags (simulation) ---------------------------------------------------------
// ----------------------------------------------------------------------------

`ifdef YANC_SIM_VIS // --------------------------------------------------------

// get the signed mantissa and the exponent of inputs and output --------------

// signed mantissa = +/- the NBMANT-bit magnitude. Width is NBMANT+1 (sign +
// magnitude) so the assign is symmetric -- a 32-bit integer here would make the
// RHS narrower than the LHS and Verilator flags WIDTHEXPAND.
reg signed [NBMANT:0] sm_in1;   // signed mantissa of in1
reg signed [NBMANT:0] sm_in2;   // signed mantissa of in2
reg signed [NBMANT:0] sm_out;   // signed mantissa of out

// exponent = NBEXPO-bit signed field; size the reg to match so the assign is
// symmetric (a 32-bit integer would be wider than the RHS -> WIDTHEXPAND).
reg signed [NBEXPO-1:0] e_in1;  // exponent of in1
reg signed [NBEXPO-1:0] e_in2;  // exponent of in2
reg signed [NBEXPO-1:0] e_ouu;  // exponent of out

// asmcomp checks the float format only when the program uses float, so a
// processor without float may carry an NBMANT/NBEXPO that does not fit the
// word (the defaults 23/8 under #NUBITS 16): the fields would be selected out
// of range. Then the float view stays at zero.
generate if (NBMANT + NBEXPO + 1 == NUBITS) begin : fview
always @ (*) sm_in1 = (in1[NBMANT+NBEXPO]) ? -$signed({1'b0, in1[NBMANT-1:0]}) : $signed({1'b0, in1[NBMANT-1:0]});
always @ (*) sm_in2 = (in2[NBMANT+NBEXPO]) ? -$signed({1'b0, in2[NBMANT-1:0]}) : $signed({1'b0, in2[NBMANT-1:0]});
always @ (*) sm_out = (out[NBMANT+NBEXPO]) ? -$signed({1'b0, out[NBMANT-1:0]}) : $signed({1'b0, out[NBMANT-1:0]});
always @ (*) e_in1  = $signed(in1[NBMANT+NBEXPO-1:NBMANT]);
always @ (*) e_in2  = $signed(in2[NBMANT+NBEXPO-1:NBMANT]);
always @ (*) e_ouu  = $signed(out[NBMANT+NBEXPO-1:NBMANT]);
end else begin : fview
initial begin sm_in1 = 0; sm_in2 = 0; sm_out = 0; e_in1 = 0; e_in2 = 0; e_ouu = 0; end
end endgenerate

// get the real values of inputs and output -----------------------------------

real r_in1; always @ (*) r_in1 = sm_in1*$pow(2.0,e_in1); // real value of in1
real r_in2; always @ (*) r_in2 = sm_in2*$pow(2.0,e_in2); // real value of in2
real r_out; always @ (*) r_out = sm_out*$pow(2.0,e_ouu); // real value of out

// compute rounding error for float -------------------------------------------

real delta_float;

always @ (*) begin
	case (op)
		3      : delta_float = (r_in1 + r_in2) - r_out; // addition
		5      : delta_float = (r_in1 * r_in2) - r_out; // multiplication
		7      : delta_float = (r_in1 / r_in2) - r_out; // division
		47	   : delta_float = (r_in2 - r_in1) - r_out; // subtraction
		48	   : delta_float = (r_in1 - r_in2) - r_out; // subtraction
		default: delta_float = 0;
	endcase
end

// compute rounding error for int ---------------------------------------------

real in1r; always @ (*) in1r = in1;
real in2r; always @ (*) in2r = in2;

real val_add; always @ (*) val_add = in1r + in2r;
real val_mlt; always @ (*) val_mlt = in1r * in2r;
real val_div; always @ (*) val_div = in1r / in2r;
// integer remainder: compute it on the integer inputs (same value as the real
// modulo for integer operands) -- a real `%` makes Verilator implicitly convert
// real->int (REALCVT) and is non-standard Verilog anyway.
real val_mod; always @ (*) val_mod = in1 % in2;

real delta_int;

always @ (*) begin
	case (op)
		2      : delta_int = val_add - out; // addition
		4      : delta_int = val_mlt - out; // multiplication
		6      : delta_int = val_div - out; // division
		8      : delta_int = val_mod - out; // remainder
		25     : delta_int = in2   - r_out; // int to float with acc
		26	   : delta_int = in1   - r_out; // int to float with mem
		27     : delta_int = r_in2   - out; // float to int with acc
		28     : delta_int = r_in1   - out; // float to int with mem
		default: delta_int = 0;
	endcase
end

`endif // ---------------------------------------------------------------------

endmodule
