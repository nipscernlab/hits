// hits_tb.v — testbench of the HITS SIMULATOR ALONE, for Aurora (Icarus
// Verilog + GTKWave/Surfer), with no ARM/PLL/Qsys.
//
// The DUT is hits_core (rtl/hits/hits_core.v), the circuit of hits without the
// configuration bus, with its configuration inputs tied to constants: what can change
// at run time is fixed here, and the occupancy and the offset are driven by the
// testbench. The chain ends at the ADC quantization, `shaper_clip`. No reconstruction
// technique is compiled or instantiated here.
// Aurora project: hits.spf in this folder, which lists only rtl/ files.
//
// Shaper: chosen by the macros described at the top of rtl/hits.v (default:
// shaper_fenics_f34, the FENICS Phase-II pulse). Commit rtl/ with the `define
// lines there commented; the regression passes the macro with -D. Two shapers at
// once stop the compilation in hits_core.v.
//
// Random generator: the RNG_TYPE parameter of hits_core
// ("xoshiro" by default, "round_robin" or "leap"). The regression builds the
// others with -DUSE_RNG_ROUND_ROBIN / -DUSE_RNG_LEAP, which this testbench turns
// into the parameter: a macro, not a parameter of the testbench, so it stays
// out of the VCD.
//
// Noise: sigma = 4 ADC; with xoshiro the Gaussian of noise_gauss.v (ROM
// noise_gauss_s4.mif), with the other generators the tables noise_s4_*.
// -DUSE_NOISE_TABLES forces the tables; -DUSE_NOISE_SIGMA8 loads the sigma = 8
// tables (noise_s8_*), as the paper build does.
//
// Energy: with xoshiro the segmented inverse CDF of energy_seg.v (ROM
// energy_seg_default.mif), with the other generators the three tables
// energy_icdf_paper_*. -DUSE_ENERGY_TABLES forces the tables.
// -DUSE_ENERGY_LORENZETTI loads energy_seg_lorenzetti.mif (the spectrum of the
// revised paper, from Lorenzetti) with its occupancy: 127 in the top 7 bits and
// 506 in the low 9, P(deposit) = 65530/65536 (regression build paper_r1).
//
// Phase (F34 and CSA): -DUSE_PHASE0=<n> sets the fixed phase PHASE0 (n steps of
// 0.390625 ns) and -DUSE_PHASE_SIGMA_PS=<ps> the jitter per hit SIGMA_PS of
// hits_core, and the inputs phase0 and sigma_k with them (regression builds *_phase
// and *_jitter). Without them: no phase,
// the shaper of before.
//
// - 40 MHz clock (25 ns period), like a collider bunch clock;
// - short reset at the start;
// - occupancy starts at 25% and steps to 75% halfway through (25/128 and
//   80/128 with USE_OCC_PAPER, the frozen paper build; held at 65530/65536
//   with USE_ENERGY_LORENZETTI);
// - offset (pedestal) = 146 ADC;
// - 3 full bunch-train orbits (3 x 3564 slots) + margin;
// - the .mif files are loaded through RTL_DIR, RELATIVE to this folder: the
//   simulation must run with cwd = projects/hits/aurora (Aurora runs it
//   in the .spf folder).

`timescale 1ns/100ps

module hits_tb;

    localparam RTL_DIR = "../../../rtl";

    localparam ORBIT    = 3564;             // 25 ns slots per orbit
    localparam N_ORBITS = 3;
    localparam N_CYCLES  = ORBIT*N_ORBITS + 200;

    reg clk = 1'b0;
    reg rst = 1'b1;
// macros, not localparams: a parameter of the testbench would land in the VCD
// The occupancy of hits is 16 bits (probability occupancy/65536). The testbench keeps
// a 7-bit variable for the top bits and adds the 9 low bits at the port: the variable
// lands in the VCD, and a 7-bit one keeps the goldens (the frozen paper one among them)
// as they were when the input had 7 bits.
`ifdef USE_ENERGY_LORENZETTI
  `define OCC_A 7'd127   // with OCC_LOW 506: 65530/65536, P(deposit) of the Lorenzetti spectrum
  `define OCC_B 7'd127
  `define OCC_LOW 9'd506
`elsif USE_OCC_PAPER      // regression build paper: the occupancies its frozen golden was made with
  `define OCC_LOW 9'd0
  `define OCC_A 7'd25    // 25/128 (19.5%), then 80/128 (62.5%)
  `define OCC_B 7'd80
`else
  `define OCC_LOW 9'd0
  `define OCC_A 7'd32    // 32/128 (25%), then 96/128 (75%)
  `define OCC_B 7'd96
`endif
    reg [6:0] occupancy = `OCC_A;
    reg signed [12:0] offset = 13'sd146;     // pedestal in ADC counts

    wire hits_out, bt_mask_out;
    wire [12:0] energy_out, event_bt, event_all;
    wire signed [29:0] shaper_out, shaper_corrupted;
    wire [11:0] shaper_clip;                 // THE simulator output (ADC sample)
    wire signed [16:0] noise_out;

    hits_core
    #(
`ifdef USE_RNG_LEAP
  `ifdef USE_RNG_ROUND_ROBIN
        .ERROR_USE_RNG_LEAP_and_USE_RNG_ROUND_ROBIN_together_pick_one(1),
  `endif
        .RNG_TYPE("leap"),        // regression builds sim_leap*; see rtl/components/random/rng.v
`elsif USE_RNG_ROUND_ROBIN
        .RNG_TYPE("round_robin"), // regression builds sim_round_robin*
`endif
        .BUNCH_MEM ({RTL_DIR, "/components/hit_generation/bunch_train_mask.mif"}),
        .MEM_ENG0  ({RTL_DIR, "/components/energy/energy_icdf_paper_0.mif"}),
        .MEM_ENG1  ({RTL_DIR, "/components/energy/energy_icdf_paper_1.mif"}),
        .MEM_ENG2  ({RTL_DIR, "/components/energy/energy_icdf_paper_2.mif"}),
`ifdef USE_ENERGY_LORENZETTI
        .MEM_SEG   ({RTL_DIR, "/components/energy/energy_seg_lorenzetti.mif"}),
`else
        .MEM_SEG   ({RTL_DIR, "/components/energy/energy_seg_default.mif"}),
`endif
        .MEM_GAUSS ({RTL_DIR, "/components/noise/noise_gauss_s4.mif"}),
`ifdef USE_PHASE0                // regression builds *_phase: -DUSE_PHASE0=<steps of 0.390625 ns>
        .PHASE0    (`USE_PHASE0),
`endif
`ifdef USE_PHASE_SIGMA_PS        // regression builds *_jitter: -DUSE_PHASE_SIGMA_PS=<ps>
        .SIGMA_PS  (`USE_PHASE_SIGMA_PS),
`endif
        .MEM_GAUSS_PHASE({RTL_DIR, "/components/noise/noise_gauss_s4.mif"}),
        .MEM_PH_F34({RTL_DIR, "/components/shaper/shaper_fenics_f34_phase.mif"}),
        .MEM_PH_CSA({RTL_DIR, "/components/shaper/shaper_csa_cr4rc_phase.mif"}),
`ifdef USE_NOISE_SIGMA8          // regression build paper
        .MEM_NOISE0({RTL_DIR, "/components/noise/noise_s8_icdf0.mif"}),
        .MEM_NOISE1({RTL_DIR, "/components/noise/noise_s8_icdf1.mif"}),
        .MEM_NOISE2({RTL_DIR, "/components/noise/noise_s8_icdf2.mif"})
`else
        .MEM_NOISE0({RTL_DIR, "/components/noise/noise_s4_icdf0.mif"}),
        .MEM_NOISE1({RTL_DIR, "/components/noise/noise_s4_icdf1.mif"}),
        .MEM_NOISE2({RTL_DIR, "/components/noise/noise_s4_icdf2.mif"})
`endif
    ) dut
    (
        .clk(clk),
        .rst(rst),
        .occupancy({occupancy, `OCC_LOW}),
        .offset(offset),
        // the configuration, fixed: what hits takes from its parameters at power-up.
        // Expressions, not localparams of the testbench, so they stay out of the VCD.
        .occ_bypass(1'b0),
        .train_active(1'b1),
        .orbit_last(12'd3563),                  // an orbit of 3564 positions
`ifdef USE_PHASE0
        .phase0(`USE_PHASE0),
`else
        .phase0(6'sd0),
`endif
`ifdef USE_PHASE_SIGMA_PS                       // K = (SIGMA_PS*4096 + 3125)/6250, as hits computes it
        .sigma_k((`USE_PHASE_SIGMA_PS * 4096 + 3125) / 6250),
`else
        .sigma_k(16'd0),
`endif
        .mem_we(1'b0),
        .mem_sel(3'd0),
        .mem_addr(12'd0),
        .mem_wdata(210'd0),
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
        $dumpfile("hits_tb.vcd");
        // testbench scope only: clk/rst/occupancy/offset + every DUT output
        // (to dive into the hierarchy, use Aurora's Wave Configuration)
        $dumpvars(1, hits_tb);

        // reset for 4 cycles
        // Stimulus changes on a clock edge use NONBLOCKING assignments: with
        // `rst = 0` every always block saw rst as 0 or as 1 at that edge
        // depending on Icarus's process order, so part of the design left
        // reset one edge before the rest -- a state the hardware never
        // produces, and one that any restructuring of the RTL could flip.
        repeat (4) @(posedge clk);
        rst <= 1'b0;

        // 1st half: low occupancy (OCC_A)
        repeat (N_CYCLES/2) @(posedge clk);

        // 2nd half: high occupancy (OCC_B) — watch the hit density change
        occupancy <= `OCC_B;
        $display("t=%0t ns: occupancy %0d -> %0d", $time, `OCC_A, `OCC_B);

        repeat (N_CYCLES/2) @(posedge clk);

        $display("end: %0d cycles (%0d orbits)", N_CYCLES, N_ORBITS);
        $finish;
    end

endmodule
