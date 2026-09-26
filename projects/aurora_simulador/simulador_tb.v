// simulador_tb.v — testbench of the HITS SIMULATOR ALONE, for Aurora (Icarus
// Verilog + GTKWave/Surfer), with no ARM/PLL/Qsys.
//
// The DUT is hits_simulator (rtl/) and nothing else: the chain ends at the
// ADC quantization, `shaper_clip`. No reconstruction technique is compiled or
// instantiated here; those are tested by projects/aurora/ (sim_pulsos_tb.v).
// Aurora project: simulador.spf in this folder, which lists only rtl/ files.
//
// Shaper: chosen where the simulator chooses it, the `define lines at the top
// of rtl/hits_simulator.v (default: shaper_fenics). Commit rtl/ with them
// commented; the regression passes the macro with -D.
//
// - 40 MHz clock (25 ns period), like the LHC bunch clock;
// - short reset at the start;
// - occupancy starts at 25/127 and steps to 80/127 halfway through;
// - offset (pedestal) = 146 ADC;
// - 3 full bunch-train orbits (3 x 3564 slots) + margin;
// - the .mif files are loaded through RTL_DIR, RELATIVE to this folder: the
//   simulation must run with cwd = projects/aurora_simulador (Aurora runs it
//   in the .spf folder).

`timescale 1ns/100ps

module simulador_tb;

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
    wire [11:0] shaper_clip;                 // THE simulator output (ADC sample)
    wire signed [16:0] noise_out;

`ifdef USE_SHAPER_F34
  `ifdef USE_SHAPER_CSA_CR4RC
    ERROR_two_shapers_USE_SHAPER_F34_and_USE_SHAPER_CSA_CR4RC_pick_one e0();
  `endif
`endif

    hits_simulator
    #(
        .BUNCH_MEM ({RTL_DIR, "/hits/bunch_train_mask.mif"}),
        .MEM_ENG0  ({RTL_DIR, "/energy/energy_icdf_a13_0.mif"}),
        .MEM_ENG1  ({RTL_DIR, "/energy/energy_icdf_a13_1.mif"}),
        .MEM_ENG2  ({RTL_DIR, "/energy/energy_icdf_a13_2.mif"}),
        .MEM_NOISE0({RTL_DIR, "/noise/noise_icdf0.mif"}),
        .MEM_NOISE1({RTL_DIR, "/noise/noise_icdf1.mif"}),
        .MEM_NOISE2({RTL_DIR, "/noise/noise_icdf2.mif"})
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
        .noise_out(noise_out)
    );

    // 40 MHz clock
    always #12.5 clk = ~clk;

    initial begin
        $dumpfile("simulador_tb.vcd");
        // testbench scope only: clk/rst/occupancy/offset + every DUT output
        // (to dive into the hierarchy, use Aurora's Wave Configuration)
        $dumpvars(1, simulador_tb);

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
