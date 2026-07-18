// sim_pulsos_tb.v — testbench of the core+PZC test wrapper (FPGA_Simulator_v1_PZC)
// for Aurora (Icarus Verilog + GTKWave), with no ARM/PLL/Qsys.
// Aurora project: sim_pulsos.spf in this folder — the simulated RTL is the
// ORIGINAL source: the simulator core in rtl/ plus the PZC-under-test in
// rtl_test/ (both shared by the Quartus and Aurora projects, no copies):
// edit the .v -> simulate -> commit.
//
// - 40 MHz clock (25 ns period), like the LHC bunch clock;
// - short reset at the start;
// - occupancy starts at 25/127 and steps to 80/127 halfway through
//   (reproduces the SignalTap test of the ENEMC 2025 paper, now in GTKWave);
// - offset (pedestal) = 146 ADC;
// - 3 full bunch-train orbits (3 x 3564 slots) + margin;
// - the .mif files are loaded by $readmemb through RTL_DIR, RELATIVE to this
//   folder: the simulation must run with cwd = projects/aurora (Aurora does
//   that since 2026-07-17; on the command line, cd here first — see README).

`timescale 1ns/100ps

module sim_pulsos_tb;

    localparam RTL_DIR = "../../rtl";

    localparam ORBITA    = 3564;             // 25 ns slots per orbit
    localparam N_ORBITAS = 3;
    localparam N_CICLOS  = ORBITA*N_ORBITAS + 200;

    reg clk = 1'b0;
    reg rst = 1'b1;
    reg [6:0] occupancy = 7'd25;             // 25/127 ~ 20%
    reg signed [12:0] offset = 13'sd146;     // pedestal in ADC counts

    wire hits_out, bt_mask_out;
    wire [12:0] energy_out, event_bt, event_all;
    wire signed [29:0] shaper_out, shaper_corrupted;
    wire [11:0] shaper_clip;
    wire signed [16:0] noise_out;
    wire signed [12:0] pedestal_out;
    wire signed [28:0] pzc_out;

    FPGA_Simulator_v1_PZC
    #(
        .BUNCH_MEM ({RTL_DIR, "/bunch_train_mask.mif"}),
        .MEM_ENG0  ({RTL_DIR, "/A13_PART1.mif"}),
        .MEM_ENG1  ({RTL_DIR, "/A13_PART2.mif"}),
        .MEM_ENG2  ({RTL_DIR, "/A13_PART3.mif"}),
        .MEM_NOISE0({RTL_DIR, "/NOISE_PART1.mif"}),
        .MEM_NOISE1({RTL_DIR, "/NOISE_PART2.mif"}),
        .MEM_NOISE2({RTL_DIR, "/NOISE_PART3.mif"})
    ) dut
    (
        .clk(clk),
        .rst(rst),
        .occupancy(occupancy),
        .offset(offset),
        .hits_out(hits_out),
        .bt_mask_out(bt_mask_out),
        .energy_out(energy_out),
        .event_bt(event_bt),
        .event_all(event_all),
        .shaper_out(shaper_out),
        .shaper_corrupted(shaper_corrupted),
        .shaper_clip(shaper_clip),
        .noise_out(noise_out),
        .pedestal_out(pedestal_out),
        .pzc_out(pzc_out)
    );

    // 40 MHz clock
    always #12.5 clk = ~clk;

    initial begin
        $dumpfile("sim_pulsos_tb.vcd");
        // testbench scope only: clk/rst/occupancy/offset + every DUT output
        // (to dive into the hierarchy, use Aurora's Wave Configuration,
        // which overrides this dumpvars)
        $dumpvars(1, sim_pulsos_tb);

        // reset for 4 cycles
        repeat (4) @(posedge clk);
        rst = 1'b0;

        // 1st half: low occupancy (25/127)
        repeat (N_CICLOS/2) @(posedge clk);

        // 2nd half: high occupancy (80/127) — watch the hit density change
        occupancy = 7'd80;
        $display("t=%0t ns: occupancy 25 -> 80", $time);

        repeat (N_CICLOS/2) @(posedge clk);

        $display("end: %0d cycles (%0d orbits)", N_CICLOS, N_ORBITAS);
        $finish;
    end

endmodule
