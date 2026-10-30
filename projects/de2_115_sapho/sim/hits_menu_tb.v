// hits_menu_tb.v -- the menu of HITS on SAPHO, simulated as on the DE2-115 (issue #14).
//
// SAPHO (hits_menu, from software/hits_menu.cpp) and hits run at 40 MHz and talk through
// the adapter rtl/hits/hits_sapho.v; the PS/2 keyboard (myKeyPS2, ABNT2) and the VGA text
// screen (myVGAText) of YANC run at 25 MHz, the pixel clock. A simulated keyboard types
// the options, and the bench checks the registers of hits (cfg, inside hits) and the
// text of the screen, read from its memory as the VGATEXT pass of YANC does. Any check
// that fails prints ERROR; the last line says ok or FAIL.
//
// Run with cwd = projects/de2_115_sapho (the memories of SAPHO are read from there):
// sim/run.sh.

`timescale 1ns/1ps

module hits_menu_tb;

localparam RTL = "../../rtl";

reg clk40 = 0, clk25 = 0, rst = 1;
always #12.5 clk40 = ~clk40;
always #20   clk25 = ~clk25;

// ---------------------------------------------------------------- SAPHO and hits
wire signed [15:0] s_in, s_out, kdado, tdado;
wire [2:0] s_req_in;
wire [8:0] s_out_en;
wire cade, taqui, toma, valeu;

hits_menu cpu (.clk(clk40), .rst(rst), .in(s_in), .out(s_out), .req_in(s_req_in), .out_en(s_out_en),
               .cade_0(cade), .taqui_0(taqui), .cade_dado_0(kdado),
               .toma_1(toma), .valeu_1(valeu), .toma_dado(tdado));

wire [3:0] addr;
wire [15:0] wdata, rdata;
wire wr, rd;
hits_sapho #(.NUBITS(16), .N_OUT(9), .N_IN(3)) adapter (
    .out(s_out), .out_en(s_out_en), .req_in(s_req_in), .in(s_in),
    .addr(addr), .wdata(wdata), .wr(wr), .rd(rd), .rdata(rdata));

wire hits_out, bt_mask_out;
wire [12:0] energy_out, event_bt, event_all;
wire signed [29:0] shaper_out, shaper_corrupted;
wire [11:0] shaper_clip;
wire signed [16:0] noise_out;
hits #(
    .BUNCH_MEM ({RTL, "/components/hit_generation/bunch_train_mask.mif"}),
    .MEM_ENG0  ({RTL, "/components/energy/energy_icdf_paper_0.mif"}),
    .MEM_ENG1  ({RTL, "/components/energy/energy_icdf_paper_1.mif"}),
    .MEM_ENG2  ({RTL, "/components/energy/energy_icdf_paper_2.mif"}),
    .MEM_SEG   ({RTL, "/components/energy/energy_seg_default.mif"}),
    .MEM_GAUSS ({RTL, "/components/noise/noise_gauss_s4.mif"}),
    .MEM_GAUSS_PHASE({RTL, "/components/noise/noise_gauss_s4.mif"}),
    .MEM_PH_F34({RTL, "/components/shaper/shaper_fenics_f34_phase.mif"}),
    .MEM_PH_CSA({RTL, "/components/shaper/shaper_csa_cr4rc_phase.mif"}),
    .MEM_NOISE0({RTL, "/components/noise/noise_s4_icdf0.mif"}),
    .MEM_NOISE1({RTL, "/components/noise/noise_s4_icdf1.mif"}),
    .MEM_NOISE2({RTL, "/components/noise/noise_s4_icdf2.mif"})
) sim (
    .clk(clk40), .rst(rst),
    .addr(addr), .wdata(wdata), .wr(wr), .rd(rd), .rdata(rdata),
    .hits_out(hits_out), .bt_mask_out(bt_mask_out),
    .energy_out(energy_out), .event_bt(event_bt), .event_all(event_all),
    .shaper_out(shaper_out), .shaper_corrupted(shaper_corrupted),
    .shaper_clip(shaper_clip), .noise_out(noise_out));

// ---------------------------------------------------------------- keyboard and screen, 25 MHz
reg ps2_clk = 1, ps2_dat = 1;
myKeyPS2 #(.LAYOUT("ABNT2"), .NUBITS(16), .CLK_KHZ(25000)) kbd (.clk(clk25), .rst(rst),
    .ps2_clk(ps2_clk), .ps2_dat(ps2_dat), .taqui(taqui), .dado(kdado), .cade(cade));
wire hs, vs, ativo, pixel;
myVGAText #(.NUBITS(16)) screen (.clk(clk25), .rst(rst), .toma(toma), .dado(tdado), .valeu(valeu),
    .hs(hs), .vs(vs), .ativo(ativo), .pixel(pixel));

// ---------------------------------------------------------------- the displays of the board
// hex_debug as on the board, with a gate of 4000 cycles instead of 1 s
localparam GATE = 4000;
reg [3:0] sel = 0;
reg rate_mode = 0;
wire [6:0] hx [0:7];
hex_debug #(.GATE(GATE)) debug (.clk(clk40), .rst(rst), .addr(addr), .wdata(wdata), .wr(wr),
    .hits_out(hits_out), .sel(sel), .rate_mode(rate_mode),
    .hex0(hx[0]), .hex1(hx[1]), .hex2(hx[2]), .hex3(hx[3]),
    .hex4(hx[4]), .hex5(hx[5]), .hex6(hx[6]), .hex7(hx[7]));

// the hits of each gate, counted here to compare with the displays
integer bench_count = 0, bench_rate = 0;
always @(posedge clk40)
	if (debug.gate == GATE - 1) begin bench_rate <= bench_count + hits_out; bench_count <= 0; end
	else if (hits_out) bench_count <= bench_count + 1;

// ---------------------------------------------------------------- the keyboard
localparam HALF = 2000;                     // ns: a 250 kHz PS/2 clock, faster than a real keyboard so
                                            // the bench runs faster; myKeyPS2 filters 8 cycles of 25 MHz
task frame; input [7:0] b; reg [10:0] w; integer j; begin
	w = {1'b1, ~^b, b, 1'b0};
	for (j = 0; j < 11; j = j + 1) begin ps2_dat = w[j]; #(HALF) ps2_clk = 0; #(HALF) ps2_clk = 1; end
	ps2_dat = 1; #(2 * HALF);
end endtask
task tap; input [7:0] sc; begin frame(sc); frame(8'hF0); frame(sc); end endtask

// the program is waiting for a key when the screen has had no word for 300 us
realtime last_word = 0;
always @(toma or tdado) last_word = $realtime;
task idle; begin
	#1000;
	while ($realtime - last_word < 300000) #10000;
end endtask

// a line typed: digits, '-', then Enter (the same keys on ABNT2 and US)
task type_line; input [8*8-1:0] s; input integer n; integer k; reg [7:0] c; begin
	for (k = 0; k < n; k = k + 1) begin
		c = s[8*(n-1-k) +: 8];
		case (c)
			"0": tap(8'h45); "1": tap(8'h16); "2": tap(8'h1E); "3": tap(8'h26); "4": tap(8'h25);
			"5": tap(8'h2E); "6": tap(8'h36); "7": tap(8'h3D); "8": tap(8'h3E); "9": tap(8'h46);
			"-": tap(8'h4E); "x": tap(8'h22);
			default: $display("ERROR: the bench cannot type '%c'", c);
		endcase
	end
	tap(8'h5A);                              // Enter
	idle;
end endtask

// ---------------------------------------------------------------- the checks
integer errors = 0;

function [6:0] at; input integer r, c; integer m; begin
	m = r + screen.top; if (m >= 30) m = m - 30; at = screen.smem[m*80 + c];
end endfunction

// the text s (n characters) on some line of the screen
task on_screen; input [8*48-1:0] s; input integer n; integer r, c, k, hit; begin
	hit = 0;
	for (r = 0; r < 30 && !hit; r = r + 1)
		for (c = 0; c + n <= 80 && !hit; c = c + 1) begin
			hit = 1;
			for (k = 0; k < n && hit; k = k + 1)
				if (at(r, c + k) !== s[8*(n-1-k) +: 8]) hit = 0;
		end
	if (!hit) begin
		errors = errors + 1;
		$display("ERROR: not on the screen: \"%0s\"", s);
	end
end endtask

task dump_screen; integer r, c, last; reg [8*80-1:0] line; begin
	for (r = 0; r < 30; r = r + 1) begin
		last = -1;
		for (c = 0; c < 80; c = c + 1) if (at(r, c) > 32) last = c;
		line = "";
		for (c = 0; c <= last; c = c + 1) line = {line[8*79-1:0], (at(r, c) < 32) ? 8'd32 : {1'b0, at(r, c)}};
		$display("| %0s", line);
	end
end endtask

// the eight displays as text, HEX7 first: a digit, '-', ' ', or '?' for a pattern
// that is none of them
function [7:0] glyph; input [6:0] g; begin
	case (g)
		7'h40: glyph = "0"; 7'h79: glyph = "1"; 7'h24: glyph = "2"; 7'h30: glyph = "3";
		7'h19: glyph = "4"; 7'h12: glyph = "5"; 7'h02: glyph = "6"; 7'h78: glyph = "7";
		7'h00: glyph = "8"; 7'h10: glyph = "9"; 7'h3F: glyph = "-"; 7'h7F: glyph = " ";
		default: glyph = "?";
	endcase
end endfunction

task want_hex; input [3:0] r; input [8*8-1:0] expected; reg [8*8-1:0] got; integer k; begin
	sel = r;
	#2000;                                   // 80 cycles: the conversion takes 17
	for (k = 0; k < 8; k = k + 1) got[8*k +: 8] = glyph(hx[k]);
	if (got !== expected) begin
		errors = errors + 1;
		$display("ERROR: displays with SW = %0d: \"%s\", want \"%s\"", r, got, expected);
	end
end endtask

task want; input [8*16-1:0] what; input [31:0] got, expected; begin
	if (got !== expected) begin
		errors = errors + 1;
		$display("ERROR: %0s = %0d, want %0d", what, got, expected);
	end
end endtask

// ---------------------------------------------------------------- the session
initial begin
	#200 rst = 0;
	#200000;                                 // the screen clears (2,400 cycles of 25 MHz)
	idle;                                    // the program writes the registers and the menu
	on_screen("HITS on SAPHO  ID 4854  CAPS 1000  running", 42);
	on_screen("1 occupancy  65530 / 65536", 26);
	on_screen("2 pedestal   146 ADC", 20);
	want("occupancy", sim.cfg.occupancy, 65530);
	want("run", sim.cfg.run, 1);

	type_line("1", 1); type_line("20000", 5);
	want("occupancy", sim.cfg.occupancy, 20000);
	on_screen("1 occupancy  20000 / 65536", 26);

	type_line("2", 1); type_line("-5", 2);
	want("pedestal", sim.cfg.offset, 13'h1FFB);
	on_screen("2 pedestal   -5 ADC", 19);

	type_line("4", 1); type_line("9999", 4);     // out of range: asked again
	on_screen("out of range", 12);
	type_line("3000", 4);
	want("orbit_last", sim.cfg.orbit_last, 2999);
	want("run", sim.cfg.run, 1);                 // stopped to write ORBIT_LEN, then run again

	type_line("7", 1);
	want("run", sim.cfg.run, 0);
	on_screen("CAPS 1000  stopped", 18);
	type_line("x", 1);                           // not a number
	on_screen("options 1 to 7", 14);
	type_line("7", 1);
	want("run", sim.cfg.run, 1);

	// the displays: what reached hits (pedestal -5 and phase0 0 are signed)
	want_hex(2, "2      1");
	want_hex(3, "3  20000");
	want_hex(4, "4 -    5");
	want_hex(5, "5      2");
	want_hex(6, "6   3000");
	want_hex(7, "7      0");
	want_hex(8, "8      0");
	want_hex(0, "0  -----");
	// the hits per second (here per gate), against the count of the bench
	rate_mode = 1;
	@(posedge clk40); while (debug.gate != 0) @(posedge clk40);
	@(posedge clk40); while (debug.gate != 0) @(posedge clk40);
	#100;
	begin : rate_check
		reg [8*8-1:0] got, expected; integer k;
		for (k = 0; k < 8; k = k + 1) got[8*k +: 8] = glyph(hx[k]);
		$sformat(expected, "%8d", bench_rate);
		if (got !== expected || bench_rate == 0) begin
			errors = errors + 1;
			$display("ERROR: hits per gate on the displays \"%s\", the bench counted %0d", got, bench_rate);
		end else $display("hits per gate of %0d cycles: %0d", GATE, bench_rate);
	end
	rate_mode = 0;

	// the top of an unsigned register, 65535 in a 16-bit word
	type_line("1", 1); type_line("65535", 5);
	want("occupancy", sim.cfg.occupancy, 65535);
	want_hex(3, "3  65535");

	// options 5 and 6 are not listed in this build (CAPS 1000), so they are no option:
	// the values after them are read as options and nothing is written
	type_line("5", 1); type_line("-3", 2);
	want("phase0", sim.cfg.phase0, 0);
	type_line("6", 1); type_line("100", 3);
	want("sigma", sim.cfg.sigma_k, 0);

	// KEY0 resets the whole system: the program writes again the values it starts with
	rst = 1;
	#200 rst = 0;
	#200000;
	idle;
	on_screen("1 occupancy  65530 / 65536", 26);
	on_screen("4 orbit      3564 crossings", 27);
	want("occupancy", sim.cfg.occupancy, 65530);
	want("pedestal", sim.cfg.offset, 146);
	want("orbit_last", sim.cfg.orbit_last, 3563);
	want("run", sim.cfg.run, 1);
	want_hex(3, "3  65530");
	want_hex(4, "4    146");
	want_hex(6, "6   3564");

	// the stacks of SAPHO never overflowed (YANC sizes them from the program)
	want("data stack full", cpu.p_hits_menu.core.sp.fl_full, 0);
	want("call stack full", cpu.p_hits_menu.core.instr_fetch.isp_blk.isp.fl_full, 0);

	if ($test$plusargs("screen")) dump_screen;  // vvp ... +screen: the screen at the end
	if (errors == 0) $display("hits_menu: ok");
	else             $display("hits_menu: FAIL, %0d errors", errors);
	$finish;
end

endmodule
