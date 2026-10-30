// top_hits_de2_115.v -- HITS configured from a menu on the DE2-115 (Cyclone IV E,
// issue #14): SAPHO runs software/hits_menu.cpp, reads a PS/2 keyboard and writes
// a VGA text screen, and configures hits through its configuration bus.
//
// The same system as sim/hits_menu_tb.v, with the board around it: SAPHO, the
// adapter and hits on the 40 MHz clock, the keyboard (myKeyPS2, ABNT2) and the
// screen (myVGAText) on the 25 MHz pixel clock, both clocks from one PLL. The
// program reaches the keyboard and the screen through links that cross clocks
// (YANC_LINK_SYNC 0), and the bus through the adapter, with no synchronizer.
// hits is the default build (F34 pulse, no phase), as in the simulation.
//
// Reset: KEY[0] (0 when pressed) or the PLL not locked. Asserted at once and
// released synchronously, two edges later, in each clock domain.
//
// The screen on the ADV7123 converter: white on black, the converter latching the
// colour mid-pixel on VGA_CLK = ~clk25 (the mapping of myVGAText, checked on this
// board in YANC).
//
// LEDG[0] blinks (clk40 alive), LEDG[1] = PLL locked, LEDG[2] = parity of
// shaper_clip (keeps the chain from being optimized away), LEDG[3] = reset active.
//
// The displays HEX7..HEX0 show what reached hits (hex_debug.v): the last word
// written to the register chosen on SW[3:0], or, with SW17 up, the hits per second.
// Signal Tap (signaltap/stp1.stp) captures the outputs of hits as waveforms.
module top_hits_de2_115 (
    input  wire       CLOCK_50,
    input  wire       KEY0,             // KEY[0] of the board
    output wire [3:0] LEDG,
    input  wire       PS2_CLK,
    input  wire       PS2_DAT,
    input  wire [17:0] SW,
    output wire [6:0] HEX0, HEX1, HEX2, HEX3, HEX4, HEX5, HEX6, HEX7,
    output wire [7:0] VGA_R,
    output wire [7:0] VGA_G,
    output wire [7:0] VGA_B,
    output wire       VGA_CLK,
    output wire       VGA_BLANK_N,
    output wire       VGA_SYNC_N,
    output wire       VGA_HS,
    output wire       VGA_VS
);
    localparam RTL = "../../rtl";

    wire clk40, clk25, locked;
    pll_de2_115 u_pll (.inclk0(CLOCK_50), .clk40(clk40), .clk25(clk25), .locked(locked));

    // asynchronous assert, synchronous release, one per clock
    wire rst_async = ~KEY0 | ~locked;
    reg  [1:0] rst40_sync = 2'b11, rst25_sync = 2'b11;
    always @(posedge clk40 or posedge rst_async)
        if (rst_async) rst40_sync <= 2'b11;
        else           rst40_sync <= {rst40_sync[0], 1'b0};
    always @(posedge clk25 or posedge rst_async)
        if (rst_async) rst25_sync <= 2'b11;
        else           rst25_sync <= {rst25_sync[0], 1'b0};
    wire rst40 = rst40_sync[1];
    wire rst25 = rst25_sync[1];

    // ------------------------------------------------------------ SAPHO and hits, 40 MHz
    wire signed [15:0] s_in, s_out, kdado, tdado;
    wire [2:0] s_req_in;
    wire [8:0] s_out_en;
    wire cade, taqui, toma, valeu;

    hits_menu cpu (.clk(clk40), .rst(rst40), .in(s_in), .out(s_out), .req_in(s_req_in), .out_en(s_out_en),
                   .cade_0(cade), .taqui_0(taqui), .cade_dado_0(kdado),
                   .toma_1(toma), .valeu_1(valeu), .toma_dado(tdado));

    wire [3:0]  addr;
    wire [15:0] wdata, rdata;
    wire        wr, rd;
    hits_sapho #(.NUBITS(16), .N_OUT(9), .N_IN(3)) adapter (
        .out(s_out), .out_en(s_out_en), .req_in(s_req_in), .in(s_in),
        .addr(addr), .wdata(wdata), .wr(wr), .rd(rd), .rdata(rdata));

    wire        hits_out, bt_mask_out;
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
        .clk(clk40), .rst(rst40),
        .addr(addr), .wdata(wdata), .wr(wr), .rd(rd), .rdata(rdata),
        .hits_out(hits_out), .bt_mask_out(bt_mask_out),
        .energy_out(energy_out), .event_bt(event_bt), .event_all(event_all),
        .shaper_out(shaper_out), .shaper_corrupted(shaper_corrupted),
        .shaper_clip(shaper_clip), .noise_out(noise_out));

    // ------------------------------------------------------------ keyboard and screen, 25 MHz
    myKeyPS2 #(.LAYOUT("ABNT2"), .NUBITS(16), .CLK_KHZ(25000)) kbd (.clk(clk25), .rst(rst25),
        .ps2_clk(PS2_CLK), .ps2_dat(PS2_DAT), .taqui(taqui), .dado(kdado), .cade(cade), .tem_tecla());

    wire hs, vs, ativo, pixel;
    myVGAText #(.NUBITS(16)) screen (.clk(clk25), .rst(rst25), .toma(toma), .dado(tdado), .valeu(valeu),
        .hs(hs), .vs(vs), .ativo(ativo), .pixel(pixel));

    assign VGA_R = {8{pixel & ativo}};
    assign VGA_G = {8{pixel & ativo}};
    assign VGA_B = {8{pixel & ativo}};
    assign VGA_BLANK_N = ativo;
    assign VGA_SYNC_N  = 1'b0;
    assign VGA_CLK     = ~clk25;
    assign VGA_HS = hs;
    assign VGA_VS = vs;

    // ------------------------------------------------------------ the displays
    // SW is asynchronous: two flip-flops before it chooses anything
    reg [4:0] sw_m, sw_s;
    always @(posedge clk40) begin
        sw_m <= {SW[17], SW[3:0]};
        sw_s <= sw_m;
    end

    hex_debug debug (.clk(clk40), .rst(rst40), .addr(addr), .wdata(wdata), .wr(wr),
        .hits_out(hits_out), .sel(sw_s[3:0]), .rate_mode(sw_s[4]),
        .hex0(HEX0), .hex1(HEX1), .hex2(HEX2), .hex3(HEX3),
        .hex4(HEX4), .hex5(HEX5), .hex6(HEX6), .hex7(HEX7));

    // ------------------------------------------------------------ LEDs
    reg [24:0] blink = 0;
    always @(posedge clk40) blink <= blink + 1'b1;

    assign LEDG = {rst40, ^shaper_clip, locked, blink[24]};
endmodule
