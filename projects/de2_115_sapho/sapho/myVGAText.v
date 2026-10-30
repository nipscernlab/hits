// ----------------------------------------------------------------------------
// VGA text screen written by the SAPHO with toma() ---------------------------
// ----------------------------------------------------------------------------
// One side is the partner of a SAPHO `toma` link, the other gives the four
// one-bit signals of a 640x480 60 Hz VGA picture, 80 x 30 characters of 8 x 16
// pixels, white on black (docs/design/vga-text.md, decisions of 2026-10-19).
//
// The program writes one word at a time, `toma_sync(k, w)` (the SAPHO on this
// block's clock) or `toma(k, w)` (another clock):
//   32-126       the character, at the cursor; the cursor advances (past
//                column 79, the next line)
//   10           column 0 of the next line
//   8            the cursor back one column and a space there (nothing at 0)
//   9            the next column that is a multiple of 8
//   -128         clear: 2,400 spaces, cursor at (0, 0)
//   -127, l, c   the cursor at screen line l and column c (out of range: 0)
//   anything else is ignored: -126 to -97 are kept for later screen
//   commands, -96 to -1 (the keyboard's special keys) are ignored for good
// The codes are an int of 8 bits, so a program of any #NUBITS writes them as
// the same numbers (at 8 bits, 128 does not fit an int: GitHub issue #14);
// the block compares the whole word, sign-extended.
// "The next line" from the last line scrolls: a top-line register goes up by
// one (mod 30) and the line it frees is cleared; nothing is copied. The block
// takes a word only when it is idle and flips its C bit (`valeu`) only when
// the word is carried out (1 cycle for a character, 80 for a scroll, 2,400
// for a clear, and one more for the register the word comes in through), so
// the SAPHO waits in `toma` meanwhile and nothing is lost.
// Reset clears the screen too, and the block's C takes the program's T, so a
// reset of this block alone does not take a stale word for a new one.
//
// The cursor is shown as an underline (the bottom two pixel rows of its
// cell), blinking about twice a second.
//
// The clock is the 25 MHz pixel clock. The outputs are logic, the same on
// every board; a board's top maps them to its converter. On the DE2-115:
//   assign VGA_R = {8{pixel & ativo}}; (and G, B)   assign VGA_BLANK_N = ativo;
//   assign VGA_SYNC_N = 1'b0;   assign VGA_CLK = ~clk;   (the converter latches
//                               mid-pixel; not checked on the board)
//   assign VGA_HS = hs;         assign VGA_VS = vs;
//
// The program's T comes from another clock unless LINK_SYNC says otherwise:
// with LINK_SYNC = 0 (the default) it goes through two flip-flops of this
// block's clock before anything uses it, and the word, which the SAPHO holds
// still from the cycle T flips (core.v, toma_reg), has settled by then. With
// LINK_SYNC = 1 (the SAPHO on this block's clock, toma_sync) the two
// flip-flops are left out: two cycles less a word (GitHub issue #64).
//
// Wiring, link k:
//   myVGAText vga (.clk(clk25), .rst(rst), .toma(toma_k), .dado(toma_dado),
//       .valeu(valeu_k), .hs(hs), .vs(vs), .ativo(ativo), .pixel(pixel));
//   with the SAPHO on clk25 too: myVGAText #(.LINK_SYNC(1)) vga (...);
// Checked by Scripts/hw/tb_vgatext.v.

module myVGAText
#(
	parameter NUBITS    = 32,               // width of the word toma() sends (at least 8)
	parameter LINK_SYNC = 0                 // 1: the SAPHO on this block's clock (toma_sync)
)
(
	input               clk,                // the 25 MHz pixel clock
	input               rst,
	input               toma,               // from the SAPHO's toma_k: its T bit
	input  [NUBITS-1:0] dado,               // from the SAPHO's toma_dado
	output              valeu,              // to the SAPHO's valeu_k: the block's C bit
	output reg          hs,                 // horizontal sync, active low
	output reg          vs,                 // vertical sync, active low
	output reg          ativo,              // 1 in the visible 640x480 window
	output reg          pixel               // 1 = lit
);

// ----------------------------------------------------------------------------
// the scan: 800 x 525 at 25 MHz -----------------------------------------------
// ----------------------------------------------------------------------------
// visible 0-639 / 0-479 first, then the front porch, the sync pulse and the
// back porch: 640+16+96+48 = 800 pixels, 480+10+2+33 = 525 lines

reg [9:0] hc, vc;

always @ (posedge clk) begin
	if (rst) begin
		hc <= 10'd0;
		vc <= 10'd0;
	end else if (hc == 10'd799) begin
		hc <= 10'd0;
		vc <= (vc == 10'd524) ? 10'd0 : vc + 10'd1;
	end else
		hc <= hc + 10'd1;
end

wire       vis0 = (hc < 10'd640) & (vc < 10'd480);
wire       hs0  = ~((hc >= 10'd656) & (hc < 10'd752));
wire       vs0  = ~((vc >= 10'd490) & (vc < 10'd492));
wire [6:0] cx   = hc[9:3];                  // the cell's column, 0-79 when visible
wire [4:0] cy   = vc[8:4];                  // the cell's screen line, 0-29 when visible

// ----------------------------------------------------------------------------
// the cursor, the top line, and the screen memory ------------------------------
// ----------------------------------------------------------------------------

reg [4:0] crow;                             // cursor, screen line 0-29
reg [6:0] ccol;                             // cursor, column 0-79
reg [4:0] top;                              // memory line shown at the top

// memory line of screen line r: (r + top) mod 30
function [4:0] mline; input [4:0] r; input [4:0] t; reg [5:0] s;
	begin s = r + t; mline = (s >= 6'd30) ? s[4:0] - 5'd30 : s[4:0]; end   // s - 30 < 30: its low 5 bits
endfunction

// address of (memory line, column): line*80 + column = line*64 + line*16 + column
function [11:0] maddr; input [4:0] l; input [6:0] c;
	begin maddr = {l, 6'd0} + {l, 4'd0} + c; end
endfunction

reg  [6:0] smem [0:2399];                   // 7-bit codes: only ASCII is written
reg        we;
reg [11:0] waddr;
reg  [6:0] wdata;
reg  [6:0] code;                            // stage 1: the code of the cell

// read address: in the blanking cx and cy go past 79 and 29 (to 99 and 32) and
// the address past 2399; it is held at 0 there, outside the memory never
wire [11:0] raddr = vis0 ? maddr(mline(cy, top), cx) : 12'd0;

always @ (posedge clk) begin                // no reset: a RAM block
	if (we) smem[waddr] <= wdata;
	code <= smem[raddr];
end

// ----------------------------------------------------------------------------
// the font: 128 x 16 rows of 8 pixels, read through a register ---------------
// ----------------------------------------------------------------------------

reg  [3:0] row1;                            // stage 1: the pixel row in the cell
wire [10:0] faddr = {code, row1};
reg  [7:0] fq;                              // stage 2: the row of the glyph
reg  [7:0] font [0:2047];
integer    fi;

initial begin
	// FONT BEGIN
	// generated by Scripts/gen_vga_font.py from Modern DOS 8x16 (CC0 1.0): do not edit
	for (fi = 0; fi < 2048; fi = fi + 1) font[fi] = 8'h00;
	// 33 !
	font[11'h212] = 8'h18; font[11'h213] = 8'h3C; font[11'h214] = 8'h3C; font[11'h215] = 8'h3C;
	font[11'h216] = 8'h18; font[11'h217] = 8'h18; font[11'h218] = 8'h18; font[11'h21A] = 8'h18;
	font[11'h21B] = 8'h18;
	// 34 "
	font[11'h221] = 8'h66; font[11'h222] = 8'h66; font[11'h223] = 8'h22; font[11'h224] = 8'h22;
	// 35 #
	font[11'h234] = 8'h6C; font[11'h235] = 8'h6C; font[11'h236] = 8'hFE; font[11'h237] = 8'h6C;
	font[11'h238] = 8'h6C; font[11'h239] = 8'hFE; font[11'h23A] = 8'h6C; font[11'h23B] = 8'h6C;
	// 36 $
	font[11'h241] = 8'h10; font[11'h242] = 8'h10; font[11'h243] = 8'h7C; font[11'h244] = 8'hD6;
	font[11'h245] = 8'hD6; font[11'h246] = 8'h70; font[11'h247] = 8'h38; font[11'h248] = 8'h1C;
	font[11'h249] = 8'hD6; font[11'h24A] = 8'hD6; font[11'h24B] = 8'h7C; font[11'h24C] = 8'h10;
	font[11'h24D] = 8'h10;
	// 37 %
	font[11'h252] = 8'h60; font[11'h253] = 8'h92; font[11'h254] = 8'h96; font[11'h255] = 8'h6C;
	font[11'h256] = 8'h18; font[11'h257] = 8'h30; font[11'h258] = 8'h6C; font[11'h259] = 8'hD2;
	font[11'h25A] = 8'h92; font[11'h25B] = 8'h0C;
	// 38 &
	font[11'h262] = 8'h38; font[11'h263] = 8'h6C; font[11'h264] = 8'h6C; font[11'h265] = 8'h38;
	font[11'h266] = 8'h30; font[11'h267] = 8'h76; font[11'h268] = 8'hDC; font[11'h269] = 8'hCC;
	font[11'h26A] = 8'hCC; font[11'h26B] = 8'h76;
	// 39 '
	font[11'h271] = 8'h18; font[11'h272] = 8'h18; font[11'h273] = 8'h08; font[11'h274] = 8'h10;
	// 40 (
	font[11'h282] = 8'h0C; font[11'h283] = 8'h18; font[11'h284] = 8'h30; font[11'h285] = 8'h30;
	font[11'h286] = 8'h30; font[11'h287] = 8'h30; font[11'h288] = 8'h30; font[11'h289] = 8'h30;
	font[11'h28A] = 8'h18; font[11'h28B] = 8'h0C;
	// 41 )
	font[11'h292] = 8'h30; font[11'h293] = 8'h18; font[11'h294] = 8'h0C; font[11'h295] = 8'h0C;
	font[11'h296] = 8'h0C; font[11'h297] = 8'h0C; font[11'h298] = 8'h0C; font[11'h299] = 8'h0C;
	font[11'h29A] = 8'h18; font[11'h29B] = 8'h30;
	// 42 *
	font[11'h2A5] = 8'h66; font[11'h2A6] = 8'h3C; font[11'h2A7] = 8'hFF; font[11'h2A8] = 8'h3C;
	font[11'h2A9] = 8'h66;
	// 43 +
	font[11'h2B5] = 8'h18; font[11'h2B6] = 8'h18; font[11'h2B7] = 8'h7E; font[11'h2B8] = 8'h18;
	font[11'h2B9] = 8'h18;
	// 44 ,
	font[11'h2CA] = 8'h30; font[11'h2CB] = 8'h30; font[11'h2CC] = 8'h10; font[11'h2CD] = 8'h20;
	// 45 -
	font[11'h2D7] = 8'hFE;
	// 46 .
	font[11'h2EA] = 8'h30; font[11'h2EB] = 8'h30;
	// 47 /
	font[11'h2F3] = 8'h02; font[11'h2F4] = 8'h06; font[11'h2F5] = 8'h0C; font[11'h2F6] = 8'h18;
	font[11'h2F7] = 8'h30; font[11'h2F8] = 8'h60; font[11'h2F9] = 8'hC0; font[11'h2FA] = 8'h80;
	// 48 0
	font[11'h302] = 8'h7C; font[11'h303] = 8'hC6; font[11'h304] = 8'hC6; font[11'h305] = 8'hCE;
	font[11'h306] = 8'hDE; font[11'h307] = 8'hF6; font[11'h308] = 8'hE6; font[11'h309] = 8'hC6;
	font[11'h30A] = 8'hC6; font[11'h30B] = 8'h7C;
	// 49 1
	font[11'h312] = 8'h18; font[11'h313] = 8'h38; font[11'h314] = 8'h78; font[11'h315] = 8'h18;
	font[11'h316] = 8'h18; font[11'h317] = 8'h18; font[11'h318] = 8'h18; font[11'h319] = 8'h18;
	font[11'h31A] = 8'h18; font[11'h31B] = 8'h7E;
	// 50 2
	font[11'h322] = 8'h7C; font[11'h323] = 8'hC6; font[11'h324] = 8'h06; font[11'h325] = 8'h0C;
	font[11'h326] = 8'h18; font[11'h327] = 8'h30; font[11'h328] = 8'h60; font[11'h329] = 8'hC0;
	font[11'h32A] = 8'hC6; font[11'h32B] = 8'hFE;
	// 51 3
	font[11'h332] = 8'h7C; font[11'h333] = 8'hC6; font[11'h334] = 8'h06; font[11'h335] = 8'h06;
	font[11'h336] = 8'h3C; font[11'h337] = 8'h06; font[11'h338] = 8'h06; font[11'h339] = 8'h06;
	font[11'h33A] = 8'hC6; font[11'h33B] = 8'h7C;
	// 52 4
	font[11'h342] = 8'h0C; font[11'h343] = 8'h1C; font[11'h344] = 8'h3C; font[11'h345] = 8'h6C;
	font[11'h346] = 8'hCC; font[11'h347] = 8'hCC; font[11'h348] = 8'hFE; font[11'h349] = 8'h0C;
	font[11'h34A] = 8'h0C; font[11'h34B] = 8'h1E;
	// 53 5
	font[11'h352] = 8'hFE; font[11'h353] = 8'hC0; font[11'h354] = 8'hC0; font[11'h355] = 8'hC0;
	font[11'h356] = 8'hFC; font[11'h357] = 8'h06; font[11'h358] = 8'h06; font[11'h359] = 8'h06;
	font[11'h35A] = 8'hC6; font[11'h35B] = 8'h7C;
	// 54 6
	font[11'h362] = 8'h7C; font[11'h363] = 8'hC6; font[11'h364] = 8'hC0; font[11'h365] = 8'hC0;
	font[11'h366] = 8'hFC; font[11'h367] = 8'hC6; font[11'h368] = 8'hC6; font[11'h369] = 8'hC6;
	font[11'h36A] = 8'hC6; font[11'h36B] = 8'h7C;
	// 55 7
	font[11'h372] = 8'hFE; font[11'h373] = 8'hC6; font[11'h374] = 8'h06; font[11'h375] = 8'h06;
	font[11'h376] = 8'h0C; font[11'h377] = 8'h18; font[11'h378] = 8'h30; font[11'h379] = 8'h30;
	font[11'h37A] = 8'h30; font[11'h37B] = 8'h30;
	// 56 8
	font[11'h382] = 8'h7C; font[11'h383] = 8'hC6; font[11'h384] = 8'hC6; font[11'h385] = 8'hC6;
	font[11'h386] = 8'h7C; font[11'h387] = 8'hC6; font[11'h388] = 8'hC6; font[11'h389] = 8'hC6;
	font[11'h38A] = 8'hC6; font[11'h38B] = 8'h7C;
	// 57 9
	font[11'h392] = 8'h7C; font[11'h393] = 8'hC6; font[11'h394] = 8'hC6; font[11'h395] = 8'hC6;
	font[11'h396] = 8'hC6; font[11'h397] = 8'h7E; font[11'h398] = 8'h06; font[11'h399] = 8'h06;
	font[11'h39A] = 8'hC6; font[11'h39B] = 8'h7C;
	// 58 :
	font[11'h3A4] = 8'h18; font[11'h3A5] = 8'h18; font[11'h3A9] = 8'h18; font[11'h3AA] = 8'h18;
	// 59 ;
	font[11'h3B4] = 8'h18; font[11'h3B5] = 8'h18; font[11'h3B9] = 8'h18; font[11'h3BA] = 8'h18;
	font[11'h3BB] = 8'h08; font[11'h3BC] = 8'h10;
	// 60 <
	font[11'h3C3] = 8'h06; font[11'h3C4] = 8'h0C; font[11'h3C5] = 8'h18; font[11'h3C6] = 8'h30;
	font[11'h3C7] = 8'h60; font[11'h3C8] = 8'h30; font[11'h3C9] = 8'h18; font[11'h3CA] = 8'h0C;
	font[11'h3CB] = 8'h06;
	// 61 =
	font[11'h3D5] = 8'h7E; font[11'h3D8] = 8'h7E;
	// 62 >
	font[11'h3E3] = 8'h60; font[11'h3E4] = 8'h30; font[11'h3E5] = 8'h18; font[11'h3E6] = 8'h0C;
	font[11'h3E7] = 8'h06; font[11'h3E8] = 8'h0C; font[11'h3E9] = 8'h18; font[11'h3EA] = 8'h30;
	font[11'h3EB] = 8'h60;
	// 63 ?
	font[11'h3F2] = 8'h7C; font[11'h3F3] = 8'hC6; font[11'h3F4] = 8'hC6; font[11'h3F5] = 8'h06;
	font[11'h3F6] = 8'h0C; font[11'h3F7] = 8'h18; font[11'h3F8] = 8'h18; font[11'h3FA] = 8'h18;
	font[11'h3FB] = 8'h18;
	// 64 @
	font[11'h403] = 8'h3C; font[11'h404] = 8'h42; font[11'h405] = 8'h9D; font[11'h406] = 8'hA5;
	font[11'h407] = 8'hA5; font[11'h408] = 8'hAD; font[11'h409] = 8'hB6; font[11'h40A] = 8'h40;
	font[11'h40B] = 8'h3C;
	// 65 A
	font[11'h412] = 8'h38; font[11'h413] = 8'h6C; font[11'h414] = 8'hC6; font[11'h415] = 8'hC6;
	font[11'h416] = 8'hC6; font[11'h417] = 8'hFE; font[11'h418] = 8'hC6; font[11'h419] = 8'hC6;
	font[11'h41A] = 8'hC6; font[11'h41B] = 8'hC6;
	// 66 B
	font[11'h422] = 8'hFC; font[11'h423] = 8'h66; font[11'h424] = 8'h66; font[11'h425] = 8'h66;
	font[11'h426] = 8'h7C; font[11'h427] = 8'h66; font[11'h428] = 8'h66; font[11'h429] = 8'h66;
	font[11'h42A] = 8'h66; font[11'h42B] = 8'hFC;
	// 67 C
	font[11'h432] = 8'h7C; font[11'h433] = 8'hC6; font[11'h434] = 8'hC6; font[11'h435] = 8'hC0;
	font[11'h436] = 8'hC0; font[11'h437] = 8'hC0; font[11'h438] = 8'hC0; font[11'h439] = 8'hC6;
	font[11'h43A] = 8'hC6; font[11'h43B] = 8'h7C;
	// 68 D
	font[11'h442] = 8'hFC; font[11'h443] = 8'h66; font[11'h444] = 8'h66; font[11'h445] = 8'h66;
	font[11'h446] = 8'h66; font[11'h447] = 8'h66; font[11'h448] = 8'h66; font[11'h449] = 8'h66;
	font[11'h44A] = 8'h66; font[11'h44B] = 8'hFC;
	// 69 E
	font[11'h452] = 8'hFE; font[11'h453] = 8'h66; font[11'h454] = 8'h62; font[11'h455] = 8'h68;
	font[11'h456] = 8'h78; font[11'h457] = 8'h78; font[11'h458] = 8'h68; font[11'h459] = 8'h62;
	font[11'h45A] = 8'h66; font[11'h45B] = 8'hFE;
	// 70 F
	font[11'h462] = 8'hFE; font[11'h463] = 8'h66; font[11'h464] = 8'h62; font[11'h465] = 8'h68;
	font[11'h466] = 8'h78; font[11'h467] = 8'h78; font[11'h468] = 8'h68; font[11'h469] = 8'h60;
	font[11'h46A] = 8'h60; font[11'h46B] = 8'hF0;
	// 71 G
	font[11'h472] = 8'h7C; font[11'h473] = 8'hC6; font[11'h474] = 8'hC6; font[11'h475] = 8'hC0;
	font[11'h476] = 8'hC0; font[11'h477] = 8'hCE; font[11'h478] = 8'hC6; font[11'h479] = 8'hC6;
	font[11'h47A] = 8'hC6; font[11'h47B] = 8'h7E;
	// 72 H
	font[11'h482] = 8'hC6; font[11'h483] = 8'hC6; font[11'h484] = 8'hC6; font[11'h485] = 8'hC6;
	font[11'h486] = 8'hFE; font[11'h487] = 8'hC6; font[11'h488] = 8'hC6; font[11'h489] = 8'hC6;
	font[11'h48A] = 8'hC6; font[11'h48B] = 8'hC6;
	// 73 I
	font[11'h492] = 8'h3C; font[11'h493] = 8'h18; font[11'h494] = 8'h18; font[11'h495] = 8'h18;
	font[11'h496] = 8'h18; font[11'h497] = 8'h18; font[11'h498] = 8'h18; font[11'h499] = 8'h18;
	font[11'h49A] = 8'h18; font[11'h49B] = 8'h3C;
	// 74 J
	font[11'h4A2] = 8'h1E; font[11'h4A3] = 8'h0C; font[11'h4A4] = 8'h0C; font[11'h4A5] = 8'h0C;
	font[11'h4A6] = 8'h0C; font[11'h4A7] = 8'h0C; font[11'h4A8] = 8'h0C; font[11'h4A9] = 8'hCC;
	font[11'h4AA] = 8'hCC; font[11'h4AB] = 8'h78;
	// 75 K
	font[11'h4B2] = 8'hE6; font[11'h4B3] = 8'h66; font[11'h4B4] = 8'h66; font[11'h4B5] = 8'h6C;
	font[11'h4B6] = 8'h78; font[11'h4B7] = 8'h78; font[11'h4B8] = 8'h6C; font[11'h4B9] = 8'h66;
	font[11'h4BA] = 8'h66; font[11'h4BB] = 8'hE6;
	// 76 L
	font[11'h4C2] = 8'hF0; font[11'h4C3] = 8'h60; font[11'h4C4] = 8'h60; font[11'h4C5] = 8'h60;
	font[11'h4C6] = 8'h60; font[11'h4C7] = 8'h60; font[11'h4C8] = 8'h60; font[11'h4C9] = 8'h62;
	font[11'h4CA] = 8'h66; font[11'h4CB] = 8'hFE;
	// 77 M
	font[11'h4D2] = 8'h82; font[11'h4D3] = 8'hC6; font[11'h4D4] = 8'hEE; font[11'h4D5] = 8'hFE;
	font[11'h4D6] = 8'hFE; font[11'h4D7] = 8'hD6; font[11'h4D8] = 8'hC6; font[11'h4D9] = 8'hC6;
	font[11'h4DA] = 8'hC6; font[11'h4DB] = 8'hC6;
	// 78 N
	font[11'h4E2] = 8'h86; font[11'h4E3] = 8'hC6; font[11'h4E4] = 8'hE6; font[11'h4E5] = 8'hF6;
	font[11'h4E6] = 8'hFE; font[11'h4E7] = 8'hDE; font[11'h4E8] = 8'hCE; font[11'h4E9] = 8'hC6;
	font[11'h4EA] = 8'hC6; font[11'h4EB] = 8'hC6;
	// 79 O
	font[11'h4F2] = 8'h7C; font[11'h4F3] = 8'hC6; font[11'h4F4] = 8'hC6; font[11'h4F5] = 8'hC6;
	font[11'h4F6] = 8'hC6; font[11'h4F7] = 8'hC6; font[11'h4F8] = 8'hC6; font[11'h4F9] = 8'hC6;
	font[11'h4FA] = 8'hC6; font[11'h4FB] = 8'h7C;
	// 80 P
	font[11'h502] = 8'hFC; font[11'h503] = 8'h66; font[11'h504] = 8'h66; font[11'h505] = 8'h66;
	font[11'h506] = 8'h66; font[11'h507] = 8'h7C; font[11'h508] = 8'h60; font[11'h509] = 8'h60;
	font[11'h50A] = 8'h60; font[11'h50B] = 8'hF0;
	// 81 Q
	font[11'h512] = 8'h7C; font[11'h513] = 8'hC6; font[11'h514] = 8'hC6; font[11'h515] = 8'hC6;
	font[11'h516] = 8'hC6; font[11'h517] = 8'hC6; font[11'h518] = 8'hC6; font[11'h519] = 8'hD6;
	font[11'h51A] = 8'hDE; font[11'h51B] = 8'h7C; font[11'h51C] = 8'h06;
	// 82 R
	font[11'h522] = 8'hFC; font[11'h523] = 8'h66; font[11'h524] = 8'h66; font[11'h525] = 8'h66;
	font[11'h526] = 8'h66; font[11'h527] = 8'h7C; font[11'h528] = 8'h6C; font[11'h529] = 8'h66;
	font[11'h52A] = 8'h66; font[11'h52B] = 8'hE6;
	// 83 S
	font[11'h532] = 8'h7C; font[11'h533] = 8'hC6; font[11'h534] = 8'hC6; font[11'h535] = 8'h60;
	font[11'h536] = 8'h38; font[11'h537] = 8'h0C; font[11'h538] = 8'h06; font[11'h539] = 8'hC6;
	font[11'h53A] = 8'hC6; font[11'h53B] = 8'h7C;
	// 84 T
	font[11'h542] = 8'h7E; font[11'h543] = 8'h7E; font[11'h544] = 8'h5A; font[11'h545] = 8'h18;
	font[11'h546] = 8'h18; font[11'h547] = 8'h18; font[11'h548] = 8'h18; font[11'h549] = 8'h18;
	font[11'h54A] = 8'h18; font[11'h54B] = 8'h3C;
	// 85 U
	font[11'h552] = 8'hC6; font[11'h553] = 8'hC6; font[11'h554] = 8'hC6; font[11'h555] = 8'hC6;
	font[11'h556] = 8'hC6; font[11'h557] = 8'hC6; font[11'h558] = 8'hC6; font[11'h559] = 8'hC6;
	font[11'h55A] = 8'hC6; font[11'h55B] = 8'h7C;
	// 86 V
	font[11'h562] = 8'hC6; font[11'h563] = 8'hC6; font[11'h564] = 8'hC6; font[11'h565] = 8'hC6;
	font[11'h566] = 8'hC6; font[11'h567] = 8'hC6; font[11'h568] = 8'hC6; font[11'h569] = 8'h6C;
	font[11'h56A] = 8'h38; font[11'h56B] = 8'h10;
	// 87 W
	font[11'h572] = 8'hC6; font[11'h573] = 8'hC6; font[11'h574] = 8'hC6; font[11'h575] = 8'hC6;
	font[11'h576] = 8'hC6; font[11'h577] = 8'hD6; font[11'h578] = 8'hFE; font[11'h579] = 8'hEE;
	font[11'h57A] = 8'hC6; font[11'h57B] = 8'h82;
	// 88 X
	font[11'h582] = 8'hC6; font[11'h583] = 8'hC6; font[11'h584] = 8'h6C; font[11'h585] = 8'h7C;
	font[11'h586] = 8'h38; font[11'h587] = 8'h38; font[11'h588] = 8'h7C; font[11'h589] = 8'h6C;
	font[11'h58A] = 8'hC6; font[11'h58B] = 8'hC6;
	// 89 Y
	font[11'h592] = 8'h66; font[11'h593] = 8'h66; font[11'h594] = 8'h66; font[11'h595] = 8'h66;
	font[11'h596] = 8'h3C; font[11'h597] = 8'h18; font[11'h598] = 8'h18; font[11'h599] = 8'h18;
	font[11'h59A] = 8'h18; font[11'h59B] = 8'h3C;
	// 90 Z
	font[11'h5A2] = 8'hFE; font[11'h5A3] = 8'hC6; font[11'h5A4] = 8'h86; font[11'h5A5] = 8'h0C;
	font[11'h5A6] = 8'h18; font[11'h5A7] = 8'h30; font[11'h5A8] = 8'h60; font[11'h5A9] = 8'hC2;
	font[11'h5AA] = 8'hC6; font[11'h5AB] = 8'hFE;
	// 91 [
	font[11'h5B2] = 8'h3C; font[11'h5B3] = 8'h30; font[11'h5B4] = 8'h30; font[11'h5B5] = 8'h30;
	font[11'h5B6] = 8'h30; font[11'h5B7] = 8'h30; font[11'h5B8] = 8'h30; font[11'h5B9] = 8'h30;
	font[11'h5BA] = 8'h30; font[11'h5BB] = 8'h3C;
	// 92 backslash
	font[11'h5C3] = 8'h80; font[11'h5C4] = 8'hC0; font[11'h5C5] = 8'h60; font[11'h5C6] = 8'h30;
	font[11'h5C7] = 8'h18; font[11'h5C8] = 8'h0C; font[11'h5C9] = 8'h06; font[11'h5CA] = 8'h02;
	// 93 ]
	font[11'h5D2] = 8'h3C; font[11'h5D3] = 8'h0C; font[11'h5D4] = 8'h0C; font[11'h5D5] = 8'h0C;
	font[11'h5D6] = 8'h0C; font[11'h5D7] = 8'h0C; font[11'h5D8] = 8'h0C; font[11'h5D9] = 8'h0C;
	font[11'h5DA] = 8'h0C; font[11'h5DB] = 8'h3C;
	// 94 ^
	font[11'h5E2] = 8'h10; font[11'h5E3] = 8'h38; font[11'h5E4] = 8'h6C; font[11'h5E5] = 8'hC6;
	// 95 _
	font[11'h5FD] = 8'hFF;
	// 96 `
	font[11'h601] = 8'h18; font[11'h602] = 8'h18; font[11'h603] = 8'h10; font[11'h604] = 8'h08;
	// 97 a
	font[11'h615] = 8'h78; font[11'h616] = 8'h0C; font[11'h617] = 8'h7C; font[11'h618] = 8'hCC;
	font[11'h619] = 8'hCC; font[11'h61A] = 8'hCC; font[11'h61B] = 8'h76;
	// 98 b
	font[11'h622] = 8'hE0; font[11'h623] = 8'h60; font[11'h624] = 8'h60; font[11'h625] = 8'h7C;
	font[11'h626] = 8'h66; font[11'h627] = 8'h66; font[11'h628] = 8'h66; font[11'h629] = 8'h66;
	font[11'h62A] = 8'h66; font[11'h62B] = 8'h7C;
	// 99 c
	font[11'h635] = 8'h7C; font[11'h636] = 8'hC6; font[11'h637] = 8'hC0; font[11'h638] = 8'hC0;
	font[11'h639] = 8'hC0; font[11'h63A] = 8'hC6; font[11'h63B] = 8'h7C;
	// 100 d
	font[11'h642] = 8'h1C; font[11'h643] = 8'h0C; font[11'h644] = 8'h0C; font[11'h645] = 8'h7C;
	font[11'h646] = 8'hCC; font[11'h647] = 8'hCC; font[11'h648] = 8'hCC; font[11'h649] = 8'hCC;
	font[11'h64A] = 8'hCC; font[11'h64B] = 8'h76;
	// 101 e
	font[11'h655] = 8'h7C; font[11'h656] = 8'hC6; font[11'h657] = 8'hC6; font[11'h658] = 8'hFE;
	font[11'h659] = 8'hC0; font[11'h65A] = 8'hC6; font[11'h65B] = 8'h7C;
	// 102 f
	font[11'h662] = 8'h1C; font[11'h663] = 8'h36; font[11'h664] = 8'h30; font[11'h665] = 8'h7C;
	font[11'h666] = 8'h30; font[11'h667] = 8'h30; font[11'h668] = 8'h30; font[11'h669] = 8'h30;
	font[11'h66A] = 8'h30; font[11'h66B] = 8'h78;
	// 103 g
	font[11'h675] = 8'h76; font[11'h676] = 8'hCC; font[11'h677] = 8'hCC; font[11'h678] = 8'hCC;
	font[11'h679] = 8'hCC; font[11'h67A] = 8'hCC; font[11'h67B] = 8'h7C; font[11'h67C] = 8'h0C;
	font[11'h67D] = 8'hCC; font[11'h67E] = 8'h78;
	// 104 h
	font[11'h682] = 8'hE0; font[11'h683] = 8'h60; font[11'h684] = 8'h60; font[11'h685] = 8'h6C;
	font[11'h686] = 8'h76; font[11'h687] = 8'h66; font[11'h688] = 8'h66; font[11'h689] = 8'h66;
	font[11'h68A] = 8'h66; font[11'h68B] = 8'hE6;
	// 105 i
	font[11'h692] = 8'h18; font[11'h693] = 8'h18; font[11'h695] = 8'h38; font[11'h696] = 8'h18;
	font[11'h697] = 8'h18; font[11'h698] = 8'h18; font[11'h699] = 8'h18; font[11'h69A] = 8'h18;
	font[11'h69B] = 8'h3C;
	// 106 j
	font[11'h6A2] = 8'h0C; font[11'h6A3] = 8'h0C; font[11'h6A5] = 8'h1C; font[11'h6A6] = 8'h0C;
	font[11'h6A7] = 8'h0C; font[11'h6A8] = 8'h0C; font[11'h6A9] = 8'h0C; font[11'h6AA] = 8'h0C;
	font[11'h6AB] = 8'h0C; font[11'h6AC] = 8'hCC; font[11'h6AD] = 8'hCC; font[11'h6AE] = 8'h78;
	// 107 k
	font[11'h6B2] = 8'hE0; font[11'h6B3] = 8'h60; font[11'h6B4] = 8'h60; font[11'h6B5] = 8'h66;
	font[11'h6B6] = 8'h6C; font[11'h6B7] = 8'h78; font[11'h6B8] = 8'h78; font[11'h6B9] = 8'h6C;
	font[11'h6BA] = 8'h66; font[11'h6BB] = 8'hE6;
	// 108 l
	font[11'h6C2] = 8'h38; font[11'h6C3] = 8'h18; font[11'h6C4] = 8'h18; font[11'h6C5] = 8'h18;
	font[11'h6C6] = 8'h18; font[11'h6C7] = 8'h18; font[11'h6C8] = 8'h18; font[11'h6C9] = 8'h18;
	font[11'h6CA] = 8'h18; font[11'h6CB] = 8'h3C;
	// 109 m
	font[11'h6D5] = 8'hEC; font[11'h6D6] = 8'hFE; font[11'h6D7] = 8'hD6; font[11'h6D8] = 8'hD6;
	font[11'h6D9] = 8'hD6; font[11'h6DA] = 8'hD6; font[11'h6DB] = 8'hC6;
	// 110 n
	font[11'h6E5] = 8'hDC; font[11'h6E6] = 8'h66; font[11'h6E7] = 8'h66; font[11'h6E8] = 8'h66;
	font[11'h6E9] = 8'h66; font[11'h6EA] = 8'h66; font[11'h6EB] = 8'h66;
	// 111 o
	font[11'h6F5] = 8'h7C; font[11'h6F6] = 8'hC6; font[11'h6F7] = 8'hC6; font[11'h6F8] = 8'hC6;
	font[11'h6F9] = 8'hC6; font[11'h6FA] = 8'hC6; font[11'h6FB] = 8'h7C;
	// 112 p
	font[11'h705] = 8'hDC; font[11'h706] = 8'h66; font[11'h707] = 8'h66; font[11'h708] = 8'h66;
	font[11'h709] = 8'h66; font[11'h70A] = 8'h66; font[11'h70B] = 8'h7C; font[11'h70C] = 8'h60;
	font[11'h70D] = 8'h60; font[11'h70E] = 8'hF0;
	// 113 q
	font[11'h715] = 8'h7C; font[11'h716] = 8'hCC; font[11'h717] = 8'hCC; font[11'h718] = 8'hCC;
	font[11'h719] = 8'hCC; font[11'h71A] = 8'hCC; font[11'h71B] = 8'h7C; font[11'h71C] = 8'h0C;
	font[11'h71D] = 8'h0C; font[11'h71E] = 8'h1E;
	// 114 r
	font[11'h725] = 8'hDE; font[11'h726] = 8'h76; font[11'h727] = 8'h60; font[11'h728] = 8'h60;
	font[11'h729] = 8'h60; font[11'h72A] = 8'h60; font[11'h72B] = 8'hF0;
	// 115 s
	font[11'h735] = 8'h7C; font[11'h736] = 8'hC6; font[11'h737] = 8'h60; font[11'h738] = 8'h38;
	font[11'h739] = 8'h0C; font[11'h73A] = 8'hC6; font[11'h73B] = 8'h7C;
	// 116 t
	font[11'h742] = 8'h10; font[11'h743] = 8'h30; font[11'h744] = 8'h30; font[11'h745] = 8'hFC;
	font[11'h746] = 8'h30; font[11'h747] = 8'h30; font[11'h748] = 8'h30; font[11'h749] = 8'h30;
	font[11'h74A] = 8'h34; font[11'h74B] = 8'h18;
	// 117 u
	font[11'h755] = 8'hCC; font[11'h756] = 8'hCC; font[11'h757] = 8'hCC; font[11'h758] = 8'hCC;
	font[11'h759] = 8'hCC; font[11'h75A] = 8'hCC; font[11'h75B] = 8'h76;
	// 118 v
	font[11'h765] = 8'hC6; font[11'h766] = 8'hC6; font[11'h767] = 8'hC6; font[11'h768] = 8'hC6;
	font[11'h769] = 8'h6C; font[11'h76A] = 8'h38; font[11'h76B] = 8'h10;
	// 119 w
	font[11'h775] = 8'hC6; font[11'h776] = 8'hD6; font[11'h777] = 8'hD6; font[11'h778] = 8'hD6;
	font[11'h779] = 8'hD6; font[11'h77A] = 8'hFE; font[11'h77B] = 8'h6C;
	// 120 x
	font[11'h785] = 8'hC6; font[11'h786] = 8'hC6; font[11'h787] = 8'h6C; font[11'h788] = 8'h38;
	font[11'h789] = 8'h6C; font[11'h78A] = 8'hC6; font[11'h78B] = 8'hC6;
	// 121 y
	font[11'h795] = 8'hC6; font[11'h796] = 8'hC6; font[11'h797] = 8'hC6; font[11'h798] = 8'hC6;
	font[11'h799] = 8'hC6; font[11'h79A] = 8'hC6; font[11'h79B] = 8'h7E; font[11'h79C] = 8'h06;
	font[11'h79D] = 8'h0C; font[11'h79E] = 8'hF8;
	// 122 z
	font[11'h7A5] = 8'hFE; font[11'h7A6] = 8'h8C; font[11'h7A7] = 8'h18; font[11'h7A8] = 8'h30;
	font[11'h7A9] = 8'h60; font[11'h7AA] = 8'hC2; font[11'h7AB] = 8'hFE;
	// 123 {
	font[11'h7B2] = 8'h0E; font[11'h7B3] = 8'h18; font[11'h7B4] = 8'h18; font[11'h7B5] = 8'h18;
	font[11'h7B6] = 8'h70; font[11'h7B7] = 8'h18; font[11'h7B8] = 8'h18; font[11'h7B9] = 8'h18;
	font[11'h7BA] = 8'h18; font[11'h7BB] = 8'h0E;
	// 124 |
	font[11'h7C2] = 8'h18; font[11'h7C3] = 8'h18; font[11'h7C4] = 8'h18; font[11'h7C5] = 8'h18;
	font[11'h7C8] = 8'h18; font[11'h7C9] = 8'h18; font[11'h7CA] = 8'h18; font[11'h7CB] = 8'h18;
	// 125 }
	font[11'h7D2] = 8'h70; font[11'h7D3] = 8'h18; font[11'h7D4] = 8'h18; font[11'h7D5] = 8'h18;
	font[11'h7D6] = 8'h0E; font[11'h7D7] = 8'h18; font[11'h7D8] = 8'h18; font[11'h7D9] = 8'h18;
	font[11'h7DA] = 8'h18; font[11'h7DB] = 8'h70;
	// 126 ~
	font[11'h7E2] = 8'h76; font[11'h7E3] = 8'hDC;
	// FONT END
end

always @ (posedge clk) fq <= font[faddr];

// ----------------------------------------------------------------------------
// the scan signals, two cycles late to meet the memories ---------------------
// ----------------------------------------------------------------------------

reg [2:0] px1, px2;                         // the pixel's column in its cell
reg [3:0] row2;
reg       vis1, vis2, hs1, hs2, vs1, vs2;
reg       cur1, cur2;                       // the cell is the cursor's

wire cur0 = (cy == crow) & (cx == ccol);

always @ (posedge clk) begin
	if (rst) begin                          // syncs inactive, the screen dark
		{px2, px1, row2, row1} <= 14'd0;
		{vis2, vis1, cur2, cur1} <= 4'd0;
		{hs2, hs1, vs2, vs1} <= 4'b1111;
	end else begin
		{px2, px1}   <= {px1, hc[2:0]};
		{row2, row1} <= {row1, vc[3:0]};
		{vis2, vis1} <= {vis1, vis0};
		{hs2, hs1}   <= {hs1, hs0};
		{vs2, vs1}   <= {vs1, vs0};
		{cur2, cur1} <= {cur1, cur0};
	end
end

// blink: a frame counter, its top bit turns every 16 frames (about 2 Hz)
reg [4:0] frames;
always @ (posedge clk)
	if (rst) frames <= 5'd0;
	else if (hc == 10'd0 && vc == 10'd0) frames <= frames + 5'd1;

wire under = cur2 & (row2 >= 4'd14) & frames[4];

always @ (posedge clk) begin
	if (rst) begin
		hs    <= 1'b1;
		vs    <= 1'b1;
		ativo <= 1'b0;
		pixel <= 1'b0;
	end else begin
		hs    <= hs2;
		vs    <= vs2;
		ativo <= vis2;
		pixel <= vis2 & (fq[3'd7 - px2] | under);
	end
end

// ----------------------------------------------------------------------------
// the link and the words --------------------------------------------------------
// ----------------------------------------------------------------------------

localparam IDLE = 2'd0, FILL = 2'd1;        // FILL: writing spaces (clear or scroll)

reg [1:0]  state;
reg        c;                               // the block's C bit
reg [1:0]  pend;                            // -127's arguments: 1 = the line next, 2 = the column next
reg [4:0]  arg_l;
reg [11:0] fpos, fend;                      // FILL: the next address, the last one
reg        fword;                           // FILL: a word asked for it (not the reset)

assign valeu = c;

// The link is read through a register: the SAPHO's word comes straight out
// of its ALU, so decoding it in the same cycle made the SAPHO's longest path
// (data memory, float adder, normaliser) and this block's 32-bit decode one
// path. A 32-bit C++ SAPHO on the DE2-115 went from 26.3 to 27.9 MHz (mean
// of three seeds, Quartus 24.1, Cyclone IV E; GitHub issue #6). T and the
// word are sampled together; the SAPHO holds its word while it waits, so a
// word costs one cycle more.
wire              t_in;                     // the program's T, on this block's clock
generate if (LINK_SYNC) begin : tsync
	assign t_in = toma;
end else begin : tsync
	reg s1 = 1'b0, s2 = 1'b0;
	always @ (posedge clk) begin s1 <= toma; s2 <= s1; end
	assign t_in = s2;
end endgenerate

reg               tq;                       // the program's T, one cycle late
reg  [NUBITS-1:0] wq;                       // its word, one cycle late
always @ (posedge clk) begin
	tq <= t_in;
	wq <= dado;
end

wire [NUBITS-1:0] w = wq;
localparam [NUBITS-1:0] CLEAR = -128,       // the commands, sign-extended to the word
                        CURSOR = -127;
wire              new_word = (tq != c);

// where the cursor goes after a character or a jump, scrolling on the last line
task next_line;
	begin
		ccol <= 7'd0;
		if (crow == 5'd29) begin                // scroll: the top memory line becomes the bottom one
			top   <= (top == 5'd29) ? 5'd0 : top + 5'd1;
			fpos  <= maddr(top, 7'd0);          // the line freed is the old top one
			fend  <= maddr(top, 7'd79);
			fword <= 1'b1;
			state <= FILL;
		end else begin
			crow <= crow + 5'd1;
			c    <= ~c;                         // done
		end
	end
endtask

always @ (posedge clk) begin
	we <= 1'b0;
	if (rst) begin
		crow <= 5'd0; ccol <= 7'd0; top <= 5'd0; pend <= 2'd0; c <= t_in;
		fpos <= 12'd0; fend <= 12'd2399; fword <= 1'b0; state <= FILL;   // reset clears the screen
	end else if (state == FILL) begin
		we    <= 1'b1;
		waddr <= fpos;
		wdata <= 7'd32;
		if (fpos == fend) begin
			state <= IDLE;
			if (fword) c <= ~c;                 // the word that asked for it is done; after reset
			                                    // a word offered meanwhile waits for IDLE
		end
		fpos <= fpos + 12'd1;
	end else if (new_word) begin                // IDLE, a word offered
		if (pend == 2'd1) begin                 // -127's line
			arg_l <= (w < 30) ? w[4:0] : 5'd0;
			pend  <= 2'd2;
			c     <= ~c;
		end else if (pend == 2'd2) begin        // -127's column
			crow  <= arg_l;
			ccol  <= (w < 80) ? w[6:0] : 7'd0;
			pend  <= 2'd0;
			c     <= ~c;
		end else if (w >= 32 && w <= 126) begin // a character
			we    <= 1'b1;
			waddr <= maddr(mline(crow, top), ccol);
			wdata <= w[6:0];
			if (ccol == 7'd79) next_line;
			else begin ccol <= ccol + 7'd1; c <= ~c; end
		end else if (w == 10) begin             // new line
			next_line;
		end else if (w == 8) begin              // backspace
			if (ccol != 7'd0) begin
				ccol  <= ccol - 7'd1;
				we    <= 1'b1;
				waddr <= maddr(mline(crow, top), ccol - 7'd1);
				wdata <= 7'd32;
			end
			c <= ~c;
		end else if (w == 9) begin              // tab
			if (ccol >= 7'd72) next_line;
			else begin ccol <= (ccol | 7'd7) + 7'd1; c <= ~c; end
		end else if (w == CLEAR) begin          // clear
			crow <= 5'd0; ccol <= 7'd0; top <= 5'd0;
			fpos <= 12'd0; fend <= 12'd2399; fword <= 1'b1; state <= FILL;
		end else if (w == CURSOR) begin         // cursor: the line and the column come next
			pend <= 2'd1;
			c    <= ~c;
		end else
			c <= ~c;                            // ignored
	end
end

endmodule
