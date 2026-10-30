// ----------------------------------------------------------------------------
// PS/2 keyboard read by the SAPHO with cade() --------------------------------
// ----------------------------------------------------------------------------
// One side takes the keyboard's two wires, the other is the partner of a
// SAPHO `cade` link: the program reads a key with `c = cade_sync(k);` and gets
// the character ready (docs/design/ps2-keyboard.md, decisions of 2026-10-19).
//
//   - Only presses: a release never reaches the program; holding a key
//     repeats it (the keyboard's own repeat).
//   - LAYOUT = "ABNT2" (default) or "US": each key gives the ASCII symbol of its
//     position on that layout, Shift included (ABNT2's accent keys give the
//     symbol itself, ~ ^ `, no composition). Enter = 10, Backspace = 8,
//     Tab = 9, Esc = 27. Keys without an ASCII character give nothing: arrows,
//     F1-F12, the keypad, Caps Lock, and on ABNT2 the c-cedilla, acute and
//     diaeresis.
//   - Shift and Ctrl are the only states: Ctrl+A..Z give 1..26, Ctrl with any
//     other key gives nothing. Nothing is sent back to the keyboard: both
//     wires are inputs.
//   - Codes, an int of 8 bits: 0-127 ASCII; -96 to -1 are kept for special
//     keys (none delivered yet); -128 to -97 never come from the keyboard
//     (screen commands, myVGAText).
//
// Chain: two flip-flops on each wire, ps2_clk filtered -> 11-bit frame (start, 8 data bits LSB
// first, odd parity, stop), a bad frame dropped, the bit count restarted when
// ps2_clk stays still for 1 ms in mid-frame -> scancode decoder (F0 = the
// next code is a release, E0 = the next code is an extended key) -> table ->
// a queue of DEPTH characters, read through a register (a character arriving
// with the queue full is dropped) -> link: while the queue is not empty and
// the last character was taken (T == C), the oldest goes on `dado` and T
// flips; when the program flips C back to T it leaves the queue.
// `tem_tecla` is 1 while the queue holds a character: wired to an in() port,
// the program asks "is there a key?" without blocking in cade_sync.
//
// Wiring, with the SAPHO on the same clock (link k):
//   myKeyPS2 #(.LAYOUT("ABNT2"), .CLK_KHZ(25000)) kbd (.clk(clk), .rst(rst),
//       .ps2_clk(PS2_CLK), .ps2_dat(PS2_DAT),
//       .taqui(taqui_k), .dado(cade_dado_k), .cade(cade_k),
//       .tem_tecla(tem));                         // optional, to an in() port
// The program's C comes from another clock unless LINK_SYNC says otherwise:
// with LINK_SYNC = 0 (the default) it goes through two flip-flops of this
// block's clock before the queue sees it; with LINK_SYNC = 1 (the SAPHO on
// this block's clock, cade_sync) they are left out (GitHub issue #64). The
// wiring above is the SAPHO on the same clock: add .LINK_SYNC(1) to save two
// cycles a key; without it the block works too.
// Checked by Scripts/hw/tb_keyps2.v.

module myKeyPS2
#(
	parameter LAYOUT    = "ABNT2", // "ABNT2" (the default) or "US"
	parameter NUBITS    = 32,      // width of the word cade() returns
	parameter DEPTH     = 4,       // characters the queue holds
	parameter CLK_KHZ   = 25000,   // the clock, to count the 1 ms frame timeout
	parameter LINK_SYNC = 0        // 1: the SAPHO on this block's clock (cade_sync)
)
(
	input               clk,
	input               rst,
	input               ps2_clk,
	input               ps2_dat,
	output              taqui,       // to the SAPHO's taqui_k: the block's T bit
	output [NUBITS-1:0] dado,        // to the SAPHO's cade_dado_k
	input               cade,        // from the SAPHO's cade_k: the program's C bit
	output              tem_tecla    // a character is waiting (the queue is not empty)
);

// the two wires, brought to clk, and ps2_clk filtered --------------------------
// The PS/2 lines are open drain with pull-ups: a slow rise or a ringing edge
// can cross the threshold more than once, and each crossing would count as
// an edge (one bit too many, the frame lost). The filtered clock `pc` takes a
// new level only after the synchronized wire has held it for FILT cycles
// (320 ns at 25 MHz; the keyboard holds each level 30 us at least), so a
// glitch shorter than that never makes an edge. The data is read on the
// filtered falling edge, well inside the 5 us it is held.

localparam FILT = 8;                               // cycles a new level must hold

reg [1:0] clk_s, dat_s;
always @ (posedge clk) begin
	clk_s <= {clk_s[0], ps2_clk};
	dat_s <= {dat_s[0], ps2_dat};
end

reg       pc = 1'b1;                               // the filtered ps2_clk
reg [3:0] hold;                                    // cycles clk_s[1] has differed from pc
reg       fall;                                    // pc fell this cycle

always @ (posedge clk) begin
	fall <= 1'b0;
	if (rst) begin
		pc   <= 1'b1;
		hold <= 4'd0;
	end else if (clk_s[1] == pc)
		hold <= 4'd0;
	else if (hold == FILT - 1) begin
		pc   <= clk_s[1];
		hold <= 4'd0;
		fall <= pc;                                // 1 -> 0
	end else
		hold <= hold + 4'd1;
end

wire bit_in = dat_s[1];

// frame: 11 bits, LSB first, read on the falling edge --------------------------

localparam TW = $clog2(CLK_KHZ + 1);

reg [10:0]   frame;                                // shifted in from the top
reg [ 3:0]   nbits;
reg [TW-1:0] idle;                                 // cycles since the last edge
reg          got;                                  // the 11th bit came in

always @ (posedge clk) begin
	got <= 1'b0;
	if (rst) begin
		nbits <= 4'd0;
		idle  <= {TW{1'b0}};
	end else if (fall) begin
		frame <= {bit_in, frame[10:1]};
		idle  <= {TW{1'b0}};
		if (nbits == 4'd10) begin
			nbits <= 4'd0;
			got   <= 1'b1;
		end else
			nbits <= nbits + 4'd1;
	end else if (nbits != 4'd0) begin
		if (idle == CLK_KHZ[TW-1:0])               // 1 ms in mid-frame: a bit was lost
			nbits <= 4'd0;
		else
			idle  <= idle + 1'b1;
	end
end

// after 11 shifts: frame[0] start, frame[8:1] data, frame[9] parity, frame[10] stop
wire       ok   = ~frame[0] & frame[10] & ^frame[9:1];   // start 0, stop 1, odd parity
wire [7:0] code = frame[8:1];

// table: scancode (set 2) -> character, character with Shift; 0 = none ---------
// The keys whose symbol depends on the layout come first (docs/design/
// ps2-keyboard.md, decision 3); the rest is the same on US and ABNT2.
// 8'h22 is the double quote and 8'h5C the backslash: a string escape is not
// read alike by every tool (Quartus refuses "\\").

localparam ABNT2 = (LAYOUT == "ABNT2");

function [15:0] key;                               // {with Shift, without}
	input [7:0] sc;
	case (sc)
		8'h0E: key = ABNT2 ? {8'h22, "'"}  : {"~", "`"};
		8'h36: key = ABNT2 ? {8'd0, "6"}   : {"^", "6"};      // ABNT2 Shift+6 is a diaeresis
		8'h54: key = ABNT2 ? {"`", 8'd0}   : {"{", "["};      // ABNT2: acute (not ASCII), grave
		8'h5B: key = ABNT2 ? {"{", "["}    : {"}", "]"};
		8'h4C: key = ABNT2 ? 16'd0         : {":", ";"};      // ABNT2: c-cedilla (not ASCII)
		8'h52: key = ABNT2 ? {"^", "~"}    : {8'h22, "'"};
		8'h5D: key = ABNT2 ? {"}", "]"}    : {"|", 8'h5C};
		8'h4A: key = ABNT2 ? {":", ";"}    : {"?", "/"};
		8'h61: key =         {"|", 8'h5C};                    // the ISO key beside Z
		8'h51: key = ABNT2 ? {"?", "/"}    : 16'd0;           // ABNT2 only, beside right Shift
		8'h1C: key = {"A", "a"};  8'h32: key = {"B", "b"};  8'h21: key = {"C", "c"};
		8'h23: key = {"D", "d"};  8'h24: key = {"E", "e"};  8'h2B: key = {"F", "f"};
		8'h34: key = {"G", "g"};  8'h33: key = {"H", "h"};  8'h43: key = {"I", "i"};
		8'h3B: key = {"J", "j"};  8'h42: key = {"K", "k"};  8'h4B: key = {"L", "l"};
		8'h3A: key = {"M", "m"};  8'h31: key = {"N", "n"};  8'h44: key = {"O", "o"};
		8'h4D: key = {"P", "p"};  8'h15: key = {"Q", "q"};  8'h2D: key = {"R", "r"};
		8'h1B: key = {"S", "s"};  8'h2C: key = {"T", "t"};  8'h3C: key = {"U", "u"};
		8'h2A: key = {"V", "v"};  8'h1D: key = {"W", "w"};  8'h22: key = {"X", "x"};
		8'h35: key = {"Y", "y"};  8'h1A: key = {"Z", "z"};
		8'h16: key = {"!", "1"};  8'h1E: key = {"@", "2"};  8'h26: key = {"#", "3"};
		8'h25: key = {"$", "4"};  8'h2E: key = {"%", "5"};
		8'h3D: key = {"&", "7"};  8'h3E: key = {"*", "8"};  8'h46: key = {"(", "9"};
		8'h45: key = {")", "0"};
		8'h4E: key = {"_", "-"};  8'h55: key = {"+", "="};
		8'h41: key = {"<", ","};  8'h49: key = {">", "."};
		8'h29: key = {" ", " "};                                                      // space
		8'h5A: key = {8'd10, 8'd10};                                                  // Enter
		8'h66: key = {8'd8 , 8'd8 };                                                  // Backspace
		8'h0D: key = {8'd9 , 8'd9 };                                                  // Tab
		8'h76: key = {8'd27, 8'd27};                                                  // Esc
		default: key = 16'd0;
	endcase
endfunction

// decoder: F0, E0, the two Shift keys and the two Ctrl keys -----------------------
// With Ctrl held, a letter gives its ASCII control code, as on a terminal:
// Ctrl+A = 1 ... Ctrl+Z = 26 (Shift does not matter; Ctrl+H, I, J are 8, 9, 10,
// backspace, tab and new line). Ctrl with any other key gives nothing.

reg       brk, ext;                                // F0 seen, E0 seen
reg       lsh, rsh;                                // Shift keys held
reg       lct, rct;                                // Ctrl keys held (left 14, right E0 14)
reg       put;                                     // a character for the queue
reg [7:0] ch;

wire [15:0] k      = key(code);
wire        letter = (k[7:0] >= "a") & (k[7:0] <= "z");
wire [ 7:0] chr    = (lct | rct) ? (letter ? {3'd0, k[4:0]} : 8'd0)   // "a" = 0x61: its low 5 bits are 1
                   : (lsh | rsh) ? k[15:8] : k[7:0];

always @ (posedge clk) begin
	put <= 1'b0;
	if (rst) begin
		brk <= 1'b0; ext <= 1'b0; lsh <= 1'b0; rsh <= 1'b0; lct <= 1'b0; rct <= 1'b0;
	end else if (got & ok) begin
		if (code == 8'hE0)
			ext <= 1'b1;
		else if (code == 8'hF0)
			brk <= 1'b1;
		else begin
			// a code ends the sequence: E0 and F0 stay set until here, so a
			// release of an extended key (E0 F0 xx) is a release
			if (!ext && code == 8'h12) lsh <= ~brk;
			if (!ext && code == 8'h59) rsh <= ~brk;
			if (code == 8'h14) begin
				if (ext) rct <= ~brk; else lct <= ~brk;
			end
			if (!ext && !brk && chr != 8'd0) begin
				ch  <= chr;
				put <= 1'b1;
			end
			brk <= 1'b0;
			ext <= 1'b0;
		end
	end
end

// queue of DEPTH characters, read through a register ------------------------------
// The read is synchronous so the synthesizer may put the queue in a memory
// block (an unregistered read forces flip-flops: 16 characters took 128 of
// them). Whether it does is the synthesizer's rule on size, not on spare
// memory: Quartus 24.1 on Cyclone IV E keeps DEPTH 4 and 16 in logic ("RAM
// logic ... uninferred due to inappropriate RAM size", as the SAPHO's own
// small memories), measured 2026-10-19. `rdq` holds mem[head] one cycle after the
// read address settles. A read in the cycle that writes the same address
// gives the old word, and needs no guard: the program reads `dado` only after
// T flips, T flips one cycle after the queue changes at the earliest, and by
// then `rdq` has the new word (a stale `rdq` exists only in a cycle nobody
// reads it; Scripts/hw/tb_keyps2.v, with a guard removed, 2026-10-19).

localparam AW = (DEPTH > 1) ? $clog2(DEPTH) : 1;

reg [7:0]    mem [0:DEPTH-1];
reg [7:0]    rdq;
reg [AW-1:0] head, tail;
reg [AW  :0] count;

wire push = put & (count != DEPTH);                // full: the new character is dropped
wire pop;

function [AW-1:0] next; input [AW-1:0] a;          // the address after a, wrapping
	next = (a == DEPTH-1) ? {AW{1'b0}} : a + 1'b1;
endfunction

wire [AW-1:0] rd_addr = pop ? next(head) : head;   // the head of the next cycle

always @ (posedge clk) begin                       // the memory: no reset, as a RAM block
	if (push) mem[tail] <= ch;
	rdq <= mem[rd_addr];
end

always @ (posedge clk) begin
	if (rst) begin
		head  <= {AW{1'b0}};
		tail  <= {AW{1'b0}};
		count <= {(AW+1){1'b0}};
	end else begin
		if (push) tail <= next(tail);
		if (pop)  head <= next(head);
		count <= count + push - pop;
	end
end

// link: the writer's side of the cade protocol -------------------------------------

reg t, offered;                                    // T bit; a character is on dado

wire c_in;                                         // the program's C, on this block's clock
generate if (LINK_SYNC) begin : csync
	assign c_in = cade;
end else begin : csync
	reg s1 = 1'b0, s2 = 1'b0;
	always @ (posedge clk) begin s1 <= cade; s2 <= s1; end
	assign c_in = s2;
end endgenerate

assign pop   = offered & (c_in == t);              // the program took it
assign taqui = t;
assign tem_tecla = (count != 0);
assign dado  = $signed(rdq);                       // sign-extended to NUBITS (a {0{..}} pad is not Verilog at NUBITS 8);
                                                   // still while offered: the head is not read anew

// On reset T takes the program's C: T == C means "nothing on offer", so a
// reset of this block alone, with C at 1, does not hand the program a
// phantom character.

always @ (posedge clk) begin
	if (rst) begin
		t       <= c_in;
		offered <= 1'b0;
	end else if (offered) begin
		if (c_in == t) offered <= 1'b0;
	end else if (count != 0) begin
		t       <= ~t;
		offered <= 1'b1;
	end
end

endmodule
