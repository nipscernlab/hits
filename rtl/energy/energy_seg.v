`timescale 1ns/100ps
// Energy amplitude by a segmented inverse CDF (ENERGY_TYPE = "seg", the default
// with the xoshiro generator since 2026-10-08).
//
// One sample per clock from one 32-bit uniform word: bit 31 picks the half of
// the CDF (0: p < 1/2, 1: p >= 1/2), bits 30:0 are u. The distance to that end
// of the CDF is v = (u + 1/2) / 2^31, so small u is the far end (the lowest or
// the highest energies). The segment is chosen by k, the number of leading
// zeros of u (octaves of probability, narrow at both ends), and by the 3 bits
// after the leading one (8 sub-segments per octave); the next 16 bits are t in
// [0, 1). Inside each segment the energy is a degree-2 polynomial,
//   E = c0 + c1 t + c2 t^2, evaluated by Horner in integers (coefficients in
// 1/16 ADC with 10 fraction bits), then rounded to the nearest whole ADC count
// and limited to [0, 2^ENG_OUT_BITS - 1].
//
// The coefficients (energy_seg_default.mif, 512 words of {c0[26:0], c1[19:0],
// c2[18:0]}, 464 used) are GENERATED from a spectrum by an integer model that
// this module reproduces bit for bit. The default ROM is a placeholder
// spectrum (mean 34 ADC, 99% below 156 ADC); other spectra are other .mif files
// of the same format, passed through MEM_SEG.
//
// Pipeline (no latency constraint in HITS, so every large block is registered):
//   1 leading-zero count   2 normalize + ROM read   3 c2*t   4 (+c1)*t
//   5 +c0, rounding to whole ADC, limits  -> energy_out, 5 cycles after the word.
module energy_seg
#(
	parameter ENG_OUT_BITS = 13,
	parameter MEM_SEG = "energy_seg_default.mif"
)
(
	input clk, rst,
	input [31:0] rnd,                              // registered uniform word
	output reg [ENG_OUT_BITS-1:0] energy_out = 0
);
localparam W0 = 27, W1 = 20, W2 = 19;          // coefficient fields (signed)
localparam FT = 16, FC = 10, LSB_LOG = 4;      // fraction bits of t, of the coefficients; coefficients in 2^-4 ADC

reg [W0+W1+W2-1:0] rom [0:511];
initial $readmemb(MEM_SEG, rom);

// ---- stage 1: leading zeros of u ------------------------------------------
function [5:0] lzc31;                          // 0..31 (31: u = 0)
	input [30:0] x;
	integer b;
	begin
		lzc31 = 31;
		for (b = 0; b <= 30; b = b + 1)
			if (x[b]) lzc31 = 30 - b;
	end
endfunction

reg [30:0] u1 = 0;
reg [5:0]  k1 = 0;
reg        h1 = 0;                             // half of the CDF
always @(posedge clk or posedge rst)
	if (rst) begin u1 <= 0; k1 <= 0; h1 <= 0; end
	else     begin u1 <= rnd[30:0]; k1 <= lzc31(rnd[30:0]); h1 <= rnd[31]; end

// ---- stage 2: drop the leading one, address the ROM ------------------------
// w = u << (k+1) in 31 bits: the bits below the leading one, left-aligned.
wire [30:0] w2 = (k1 == 31) ? 31'd0 : (u1 << (k1 + 1));
wire [8:0]  a2 = {h1, k1[4:0], w2[30:28]};
reg  [W0+W1+W2-1:0] c2r = 0;                   // ROM word (registered read: M10K)
reg  [FT-1:0] t2 = 0;
always @(posedge clk) c2r <= rom[rst ? 9'd0 : a2];
always @(posedge clk or posedge rst)
	if (rst) t2 <= 0;
	else     t2 <= w2[27:12];

wire signed [W0-1:0] c0_2 = c2r[W0+W1+W2-1 -: W0];
wire signed [W1-1:0] c1_2 = c2r[W1+W2-1 -: W1];
wire signed [W2-1:0] cq_2 = c2r[W2-1:0];

// ---- stage 3: c2 * t --------------------------------------------------------
wire signed [FT:0] tt2 = {1'b0, t2};
reg  signed [W2+FT:0] p3 = 0;
reg  signed [W1-1:0]  c1_3 = 0;
reg  signed [W0-1:0]  c0_3 = 0;
reg  signed [FT:0]    t3 = 0;
always @(posedge clk or posedge rst)
	if (rst) begin p3 <= 0; c1_3 <= 0; c0_3 <= 0; t3 <= 0; end
	else     begin p3 <= cq_2 * tt2; c1_3 <= c1_2; c0_3 <= c0_2; t3 <= tt2; end

// ---- stage 4: (c2 t + c1) * t ----------------------------------------------
wire signed [W1+1:0] h4 = (p3 >>> FT) + c1_3;   // |c2 t| < 2^(W2-1) <= 2^(W1-1), so W1+2 bits hold it
reg  signed [W1+FT+2:0] p4 = 0;
reg  signed [W0-1:0]    c0_4 = 0;
always @(posedge clk or posedge rst)
	if (rst) begin p4 <= 0; c0_4 <= 0; end
	else     begin p4 <= h4 * t3; c0_4 <= c0_3; end

// ---- stage 5: + c0, round to whole ADC, limits ------------------------------
wire signed [W0+1:0] h5 = (p4 >>> FT) + c0_4;
wire signed [W0+1:0] e5 = (h5 + (1 <<< (FC+LSB_LOG-1))) >>> (FC+LSB_LOG);
localparam signed [W0+1:0] EMAX = (1 <<< ENG_OUT_BITS) - 1;
always @(posedge clk or posedge rst)
	if (rst)            energy_out <= 0;
	else if (e5 < 0)    energy_out <= 0;
	else if (e5 > EMAX) energy_out <= EMAX[ENG_OUT_BITS-1:0];
	else                energy_out <= e5[ENG_OUT_BITS-1:0];

endmodule
