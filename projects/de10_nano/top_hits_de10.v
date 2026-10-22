// top_hits_de10.v -- the HITS SIMULATOR ALONE on the DE10-Nano (Cyclone V),
// with no HPS, no Qsys and no reconstruction technique: the chain ends at the
// ADC output, shaper_clip, which is what Signal Tap captures.
//
// The configuration bus of hits is on the two GPIO headers (pins in hits_de10.qsf),
// for a controller outside the board, and SW0 enables it. With SW0 = 0 the bus is
// held idle and the values at power-up stay. The 16-bit occupancy at power-up is
// 65530/65536 (127 in the top 7 bits and 506 in the low 9, the deposit
// probability of the Lorenzetti spectrum) and the pedestal 146 ADC, the values of verification/testbenches/hits_tb.v with
// USE_ENERGY_LORENZETTI. With the macros of hits_de10.qsf
// (USE_SHAPER_CSA_CR4RC + USE_ENERGY_LORENZETTI) this is the paper_r1 build,
// and the samples after the reset must equal the paper_r1 golden bit for bit.
// The phase of the pulse is off; the macros USE_PHASE0 and USE_PHASE_SIGMA_PS
// (the same as in hits_tb.v) turn it on.
//
// Reset: KEY0 (0 when pressed) or the PLL not locked. It is asserted at once
// and RELEASED SYNCHRONOUSLY, two clk40 edges later: every block leaves reset
// on the same edge, as in the testbench, so the run after the button repeats.
//
// The bus on the headers (docs/guide/configuring.md for the protocol): the controller
// runs on BUS_CLK, the 40 MHz clock of hits, and drives BUS_ADDR, BUS_WDATA, BUS_WR and
// BUS_RD. The four are registered on the way in, so a write reaches hits one cycle
// after the edge that samples it; BUS_RDATA is registered on the way out, so the word
// of a read is on the pins two edges after the edge that samples BUS_RD. SW0 = 0 forces
// wr and rd to 0 (headers left open read as noise; the Cyclone V has no pull-downs).
//
// LED0 blinks (clk40 alive), LED1 = PLL locked, LED2 = parity of shaper_clip
// (keeps the chain from being optimized away), LED3 = reset active.
module top_hits_de10 (
    input  wire        FPGA_CLK1_50,
    input  wire        KEY0,
    input  wire        SW0,             // 1: the configuration bus on the headers is enabled
    output wire [3:0]  LED,
    // the configuration bus of hits, on GPIO_0 (inputs and clock) and GPIO_1 (read data)
    output wire        BUS_CLK,
    input  wire [3:0]  BUS_ADDR,
    input  wire [15:0] BUS_WDATA,
    input  wire        BUS_WR,
    input  wire        BUS_RD,
    output reg  [15:0] BUS_RDATA = 16'd0
);
    localparam RTL = "../../rtl";

    wire clk40, locked;
    pll_40mhz_de10 u_pll (.refclk(FPGA_CLK1_50), .outclk_0(clk40), .locked(locked));

    // asynchronous assert, synchronous release
    wire rst_async = ~KEY0 | ~locked;
    reg  [1:0] rst_sync = 2'b11;
    always @(posedge clk40 or posedge rst_async)
        if (rst_async) rst_sync <= 2'b11;
        else           rst_sync <= {rst_sync[0], 1'b0};
    wire rst = rst_sync[1];

    // the bus: registered in, gated by SW0 (synchronized), registered out
    assign BUS_CLK = clk40;
    reg  [1:0]  en_sync = 2'b00;
    reg  [3:0]  addr_r = 4'd0;
    reg  [15:0] wdata_r = 16'd0;
    reg         wr_r = 1'b0, rd_r = 1'b0;
    wire [15:0] rdata;
    always @(posedge clk40) begin
        en_sync <= {en_sync[0], SW0};
        addr_r  <= BUS_ADDR;
        wdata_r <= BUS_WDATA;
        wr_r    <= BUS_WR & en_sync[1];
        rd_r    <= BUS_RD & en_sync[1];
        BUS_RDATA <= rdata;
    end

    wire        hits_out, bt_mask_out;
    wire [12:0] energy_out, event_bt, event_all;
    wire signed [29:0] shaper_out, shaper_corrupted;
    wire [11:0] shaper_clip;
    wire signed [16:0] noise_out;

    hits
    #(
        .BUNCH_MEM ({RTL, "/components/hit_generation/bunch_train_mask.mif"}),
        .MEM_ENG0  ({RTL, "/components/energy/energy_icdf_paper_0.mif"}),
        .MEM_ENG1  ({RTL, "/components/energy/energy_icdf_paper_1.mif"}),
        .MEM_ENG2  ({RTL, "/components/energy/energy_icdf_paper_2.mif"}),
`ifdef USE_ENERGY_LORENZETTI
        .MEM_SEG   ({RTL, "/components/energy/energy_seg_lorenzetti.mif"}),
`else
        .MEM_SEG   ({RTL, "/components/energy/energy_seg_default.mif"}),
`endif
        .MEM_GAUSS ({RTL, "/components/noise/noise_gauss_s4.mif"}),
`ifdef USE_PHASE0                // fixed phase: VERILOG_MACRO "USE_PHASE0=<steps of 0.390625 ns>"
        .PHASE0    (`USE_PHASE0),
`endif
`ifdef USE_PHASE_SIGMA_PS        // jitter per hit: VERILOG_MACRO "USE_PHASE_SIGMA_PS=<ps>"
        .SIGMA_PS  (`USE_PHASE_SIGMA_PS),
`endif
        .MEM_GAUSS_PHASE({RTL, "/components/noise/noise_gauss_s4.mif"}),
        .MEM_PH_F34({RTL, "/components/shaper/shaper_fenics_f34_phase.mif"}),
        .MEM_PH_CSA({RTL, "/components/shaper/shaper_csa_cr4rc_phase.mif"}),
        .MEM_NOISE0({RTL, "/components/noise/noise_s4_icdf0.mif"}),
        .MEM_NOISE1({RTL, "/components/noise/noise_s4_icdf1.mif"}),
        .MEM_NOISE2({RTL, "/components/noise/noise_s4_icdf2.mif"}),
        .OCCUPANCY_INIT(16'd65530),
        .PEDESTAL_INIT(13'd146)
    ) sim (
        .clk(clk40), .rst(rst),
        // the configuration bus, from the headers
        .addr(addr_r), .wdata(wdata_r), .wr(wr_r), .rd(rd_r), .rdata(rdata),
        .hits_out(hits_out), .bt_mask_out(bt_mask_out),
        .energy_out(energy_out), .event_bt(event_bt), .event_all(event_all),
        .shaper_out(shaper_out), .shaper_corrupted(shaper_corrupted),
        .shaper_clip(shaper_clip), .noise_out(noise_out)
    );

    reg [24:0] blink = 0;
    always @(posedge clk40) blink <= blink + 1'b1;

    assign LED = {rst, ^shaper_clip, locked, blink[24]};
endmodule
