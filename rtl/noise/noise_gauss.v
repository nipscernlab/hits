`timescale 1ns/100ps

// Gaussian noise by a segmented inverse CDF (NOISE_TYPE = "gauss", the default
// with the xoshiro generator since 2026-10-02).
//
// One sample per clock from one 32-bit uniform word: bit 31 is the sign, bits
// 30:0 are u. The tail probability of the magnitude is v = (u + 1/2) / 2^31, so
// small u is the far tail. The segment is chosen by k, the number of leading
// zeros of u (octaves of probability, narrow in the tail), and by the 3 bits
// after the leading one (8 sub-segments per octave); the next 16 bits are t in
// [0, 1). Inside each segment the magnitude is a degree-2 polynomial,
//   |x| = c0 + c1 t + c2 t^2, evaluated by Horner in integers.
//
// The coefficients (noise_gauss_s4.mif, 256 words of {c0[20:0], c1[14:0],
// c2[9:0]}, 232 used) are GENERATED, with sigma = 4 ADC built in: research vault
// Simulador_Pulsos_FPGA/05_Ruido_Eletronico/gerar_rom_gauss.py, from the integer
// model in icdf_segmentado.py, which this module reproduces bit for bit.
// Measured on that model (exact counts over the 2^31 values of u): magnitude
// error below half an output LSB (2^-5 ADC), Gaussian tail up to the largest
// value, 6.34 sigma; the old tables stop at 6.48 sigma with 120x too much
// probability above 6 sigma (rtl/noise/README.md).
//
// Pipeline (no latency constraint in HITS, so every large block is registered):
//   1 leading-zero count   2 normalize + ROM read   3 c2*t   4 (+c1)*t
//   5 +c0, rounding, sign  -> noise_out, 5 cycles after the uniform word.
module noise_gauss
#(
	parameter NOISE_OUT_BITS = 17,                 // noise_out in 2^-10 ADC
	parameter MEM_GAUSS = "noise_gauss_s4.mif"
)
(
	input clk, rst,
	input [31:0] rnd,                              // registered uniform word
	output reg signed [NOISE_OUT_BITS-1:0] noise_out = 0
);

localparam W0 = 21, W1 = 15, W2 = 10;          // coefficient fields (signed)
localparam FT = 16, FC = 10;                   // fraction bits of t and of the coefficients

reg [W0+W1+W2-1:0] rom [0:255];
initial $readmemb(MEM_GAUSS, rom);

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
reg        s1 = 0;
always @(posedge clk or posedge rst)
	if (rst) begin u1 <= 0; k1 <= 0; s1 <= 0; end
	else     begin u1 <= rnd[30:0]; k1 <= lzc31(rnd[30:0]); s1 <= rnd[31]; end

// ---- stage 2: drop the leading one, address the ROM ------------------------
// w = u << (k+1) in 31 bits: the bits below the leading one, left-aligned.
wire [30:0] w2   = (k1 == 31) ? 31'd0 : (u1 << (k1 + 1));
wire [7:0]  a2   = {k1[4:0], w2[30:28]};
reg  [W0+W1+W2-1:0] c2r = 0;                   // ROM word (registered read: M10K)
reg  [FT-1:0] t2 = 0;
reg           s2 = 0;
always @(posedge clk) c2r <= rom[rst ? 8'd0 : a2];
always @(posedge clk or posedge rst)
	if (rst) begin t2 <= 0; s2 <= 0; end
	else     begin t2 <= w2[27:12]; s2 <= s1; end

wire signed [W0-1:0] c0_2 = c2r[W0+W1+W2-1 -: W0];
wire signed [W1-1:0] c1_2 = c2r[W1+W2-1 -: W1];
wire signed [W2-1:0] cq_2 = c2r[W2-1:0];

// ---- stage 3: c2 * t --------------------------------------------------------
wire signed [FT:0] tt2 = {1'b0, t2};
reg  signed [W2+FT:0] p3 = 0;
reg  signed [W1-1:0]  c1_3 = 0;
reg  signed [W0-1:0]  c0_3 = 0;
reg  signed [FT:0]    t3 = 0;
reg                   s3 = 0;
always @(posedge clk or posedge rst)
	if (rst) begin p3 <= 0; c1_3 <= 0; c0_3 <= 0; t3 <= 0; s3 <= 0; end
	else     begin p3 <= cq_2 * tt2; c1_3 <= c1_2; c0_3 <= c0_2; t3 <= tt2; s3 <= s2; end

// ---- stage 4: (c2 t + c1) * t ----------------------------------------------
wire signed [W1+1:0] h4 = (p3 >>> FT) + c1_3;   // |c2 t| < 2^(W2-1), so W1+2 bits hold it
reg  signed [W1+FT+2:0] p4 = 0;
reg  signed [W0-1:0]    c0_4 = 0;
reg                     s4 = 0;
always @(posedge clk or posedge rst)
	if (rst) begin p4 <= 0; c0_4 <= 0; s4 <= 0; end
	else     begin p4 <= h4 * t3; c0_4 <= c0_3; s4 <= s3; end

// ---- stage 5: + c0, round to 2^-5 ADC, sign, to 2^-10 ADC --------------------
wire signed [W0+1:0] h5  = (p4 >>> FT) + c0_4;
wire signed [W0+1:0] mag = (h5 + (1 <<< (FC-1))) >>> FC;   // magnitude in 2^-5 ADC
wire signed [NOISE_OUT_BITS-1:0] m10 = mag <<< 5;            // in 2^-10 ADC
always @(posedge clk or posedge rst)
	if (rst)     noise_out <= 0;
	else if (s4) noise_out <= -m10;
	else         noise_out <= m10;

endmodule
