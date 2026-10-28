// Reference for the Signal Tap capture of the board with the ARM (README of this
// project, Step 10): the same hits_reco as the top de10_nano_soc_ghrd.v, with the
// occupancy and the pedestal the guide sets from the ARM (7-bit occupancy 64, so
// 64 * 512 = 32768 of 65536, and pedestal 146). The reset is released on a falling
// edge, away from the rising one, as the synchronizer of the top does; from then
// on, at each rising edge, it writes the signals the capture compares:
// index, shaper_clip, event_bt, bt_mask_out.
//
// Run from the root of the repository (writes board_reference.csv in the folder
// where vvp runs):
//   iverilog -g2012 -s board_reference -o ref.vvp projects/de10_nano_arm/tools/board_reference.v rtl/*.v rtl/hits/*.v rtl/components/*/*.v projects/de10_nano_arm/hardware/reconstruction/hits_reco.v projects/de10_nano_arm/hardware/reconstruction/pzc/*.v
//   vvp ref.vvp
`timescale 1ns/100ps
`ifndef RTL
  `define RTL "rtl"
`endif
module board_reference;
    localparam N = 70000;
    reg clk = 1'b0, rst = 1'b1;
    wire bt_mask_out;
    wire [12:0] event_bt;
    wire signed [11:0] shaper_clip;
    wire signed [29:0] shaper_out, shaper_corrupted;
    wire signed [28:0] pzc_out;
    wire signed [12:0] pedestal_out;
    wire signed [16:0] noise_out;

    hits_reco #(
        .PZC_M_FACTOR(454),
        .RNG_TYPE("xoshiro"),
        .BUNCH_MEM ({`RTL, "/components/hit_generation/bunch_train_mask.mif"}),
        .MEM_ENG0  ({`RTL, "/components/energy/energy_icdf_paper_0.mif"}),
        .MEM_ENG1  ({`RTL, "/components/energy/energy_icdf_paper_1.mif"}),
        .MEM_ENG2  ({`RTL, "/components/energy/energy_icdf_paper_2.mif"}),
        .MEM_SEG   ({`RTL, "/components/energy/energy_seg_default.mif"}),
        .MEM_GAUSS ({`RTL, "/components/noise/noise_gauss_s4.mif"}),
        .MEM_NOISE0({`RTL, "/components/noise/noise_s4_icdf0.mif"}),
        .MEM_NOISE1({`RTL, "/components/noise/noise_s4_icdf1.mif"}),
        .MEM_NOISE2({`RTL, "/components/noise/noise_s4_icdf2.mif"})
    ) sim (
        .clk(clk), .rst(rst),
        .occupancy({7'd64, 9'd0}), .offset(13'sd146),
        .hits_out(), .bt_mask_out(bt_mask_out), .energy_out(), .event_bt(event_bt), .event_all(),
        .shaper_corrupted(shaper_corrupted), .shaper_clip(shaper_clip), .shaper_out(shaper_out),
        .noise_out(noise_out), .pedestal_out(pedestal_out), .pzc_out(pzc_out)
    );

    always #12.5 clk = ~clk;
    integer i, fo;
    initial begin
        fo = $fopen("board_reference.csv", "w");
        $fdisplay(fo, "index,shaper_clip,event_bt,bt_mask_out");
        repeat (4) @(posedge clk);
        @(negedge clk) rst = 1'b0;
        for (i = 0; i < N; i = i + 1) begin
            @(posedge clk); #1;
            $fdisplay(fo, "%0d,%0d,%0d,%0d", i, $unsigned(shaper_clip), event_bt, bt_mask_out);
        end
        $fclose(fo);
        $finish;
    end
endmodule
