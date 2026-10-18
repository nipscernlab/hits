// top_hits_de10.v -- the HITS SIMULATOR ALONE on the DE10-Nano (Cyclone V),
// with no HPS, no Qsys and no reconstruction technique: the chain ends at the
// ADC output, shaper_clip, which is what Signal Tap captures.
//
// The runtime inputs are FIXED here (no ARM): the 16-bit occupancy is
// 65530/65536 (127 in the top 7 bits and 506 in the low 9, the deposit
// probability of the Lorenzetti spectrum) and the pedestal 146 ADC, the values of projects/hits/aurora/hits_tb.v with
// USE_ENERGY_LORENZETTI. With the macros of hits_de10.qsf
// (USE_SHAPER_CSA_CR4RC + USE_ENERGY_LORENZETTI) this is the paper_r1 build,
// and the samples after the reset must equal the paper_r1 golden bit for bit.
//
// Reset: KEY0 (0 when pressed) or the PLL not locked. It is asserted at once
// and RELEASED SYNCHRONOUSLY, two clk40 edges later: every block leaves reset
// on the same edge, as in the testbench, so the run after the button repeats.
//
// LED0 blinks (clk40 alive), LED1 = PLL locked, LED2 = parity of shaper_clip
// (keeps the chain from being optimized away), LED3 = reset active.
module top_hits_de10 (
    input  wire       FPGA_CLK1_50,
    input  wire       KEY0,
    output wire [3:0] LED
);
    localparam RTL = "../../../rtl";

    wire clk40, locked;
    pll_40mhz_de10 u_pll (.refclk(FPGA_CLK1_50), .outclk_0(clk40), .locked(locked));

    // asynchronous assert, synchronous release
    wire rst_async = ~KEY0 | ~locked;
    reg  [1:0] rst_sync = 2'b11;
    always @(posedge clk40 or posedge rst_async)
        if (rst_async) rst_sync <= 2'b11;
        else           rst_sync <= {rst_sync[0], 1'b0};
    wire rst = rst_sync[1];

    wire        hits_out, bt_mask_out;
    wire [12:0] energy_out, event_bt, event_all;
    wire signed [29:0] shaper_out, shaper_corrupted;
    wire [11:0] shaper_clip;
    wire signed [16:0] noise_out;

    hits
    #(
        .BUNCH_MEM ({RTL, "/hits/bunch_train_mask.mif"}),
        .MEM_ENG0  ({RTL, "/energy/energy_icdf_paper_0.mif"}),
        .MEM_ENG1  ({RTL, "/energy/energy_icdf_paper_1.mif"}),
        .MEM_ENG2  ({RTL, "/energy/energy_icdf_paper_2.mif"}),
`ifdef USE_ENERGY_LORENZETTI
        .MEM_SEG   ({RTL, "/energy/energy_seg_lorenzetti.mif"}),
`else
        .MEM_SEG   ({RTL, "/energy/energy_seg_default.mif"}),
`endif
        .MEM_GAUSS ({RTL, "/noise/noise_gauss_s4.mif"}),
        .MEM_NOISE0({RTL, "/noise/noise_s4_icdf0.mif"}),
        .MEM_NOISE1({RTL, "/noise/noise_s4_icdf1.mif"}),
        .MEM_NOISE2({RTL, "/noise/noise_s4_icdf2.mif"})
    ) sim (
        .clk(clk40), .rst(rst),
        .occupancy(16'd65530),
        .offset(13'sd146),
        .hits_out(hits_out), .bt_mask_out(bt_mask_out),
        .energy_out(energy_out), .event_bt(event_bt), .event_all(event_all),
        .shaper_out(shaper_out), .shaper_corrupted(shaper_corrupted),
        .shaper_clip(shaper_clip), .noise_out(noise_out)
    );

    reg [24:0] blink = 0;
    always @(posedge clk40) blink <= blink + 1'b1;

    assign LED = {rst, ^shaper_clip, locked, blink[24]};
endmodule
