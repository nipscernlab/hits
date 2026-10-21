// hits_config_tb.v -- testbench of the configuration bus (rtl/hits.v, rtl/hits/hits_cfg.v).
//
// Two simulators run side by side, released from reset on the same edge:
//   ref  hits_core with its configuration inputs tied to constants, built with a configuration of its own: the mask testdata/mask_3000.mif and an
//        orbit of 3000, the Lorenzetti energy ROM, the sigma = 4 Gaussian, occupancy 40000
//        and pedestal 100; with TB_JITTER, SIGMA_PS = 3000 ps and PHASE0 = +5 (the table of 64
//        phases is loaded too); with TB_PHASE, the fixed phase PHASE0 = +8 (the dut starts with
//        the set of phase 0 and gets the set of phase +8 through the bus);
//   dut  hits, whose memories all start with every bit at 1 (testdata/ones_*.mif). The testbench
//        stops it (RUN = 0), loads the same configuration through the bus, and runs it.
// Every output is compared on every cycle; any difference prints ERROR (which fails the
// regression). Halfway through, the occupancy changes in both on the same edge, to check
// that a scalar takes effect on the next cycle. At the end it reads ID, CAPS and STATUS.
//
// The .mif files are loaded through RTL_DIR and testdata/, RELATIVE to this folder: run
// with cwd = verification/testbenches. Builds of the regression: bus (F34), bus_phase (F34,
// TB_PHASE), bus_phase_csa and bus_jitter (-DUSE_SHAPER_CSA_CR4RC with TB_PHASE, TB_JITTER).

`timescale 1ns/100ps

module hits_config_tb;

    localparam RTL_DIR = "../../rtl";
    localparam N_RUN = 2 * 3000 + 400;          // cycles compared: two short orbits

    reg clk = 1'b0;
    reg rst = 1'b1;
    always #12.5 clk = ~clk;

    // a word of the phase table: 192 bits in 12 pieces (CSA), 210 in 14 (F34)
`ifdef USE_SHAPER_CSA_CR4RC
    localparam PH_W = 192, PH_PIECES = 12;
    `define PH_MIF "/components/shaper/shaper_csa_cr4rc_phase.mif"
`else
    localparam PH_W = 210, PH_PIECES = 14;
    `define PH_MIF "/components/shaper/shaper_fenics_f34_phase.mif"
`endif

`ifdef TB_JITTER
  `define SIGMA_REF 3000
  `define PHASE_REF 5
  `define K_REF     1966                       // floor((3000*4096 + 3125)/6250)
  `define PHASE0_REG 5
`elsif TB_PHASE
  `define SIGMA_REF 0
  `define PHASE_REF 8
  `define K_REF     0
  `define PHASE0_REG 0                         // the fixed phase comes from the set, not from PHASE0
`else
  `define SIGMA_REF 0
  `define PHASE_REF 0
  `define K_REF     0
  `define PHASE0_REG 0
`endif

    // ---------------------------------------------------------------- the bus
    reg  [3:0]  addr = 4'd0;
    reg  [15:0] wdata = 16'd0;
    reg         wr = 1'b0, rd = 1'b0;
    wire [15:0] rdata;

    task bus_write(input [3:0] a, input [15:0] d);
        begin
            @(negedge clk); addr = a; wdata = d; wr = 1'b1;
            @(negedge clk); wr = 1'b0;
        end
    endtask

    task bus_read(input [3:0] a, output [15:0] d);
        begin
            @(negedge clk); addr = a; rd = 1'b1;
            #1 d = rdata;
            @(negedge clk); rd = 1'b0;
        end
    endtask

    // ---------------------------------------------------------------- dut
    wire d_hits, d_mask;
    wire [12:0] d_energy, d_ebt, d_eall;
    wire signed [29:0] d_shaper, d_corr;
    wire [11:0] d_clip;
    wire signed [16:0] d_noise;

    hits #(
        .BUNCH_MEM ("testdata/ones_mask.mif"),
        .MEM_ENG0  ({RTL_DIR, "/components/energy/energy_icdf_paper_0.mif"}),
        .MEM_ENG1  ({RTL_DIR, "/components/energy/energy_icdf_paper_1.mif"}),
        .MEM_ENG2  ({RTL_DIR, "/components/energy/energy_icdf_paper_2.mif"}),
        .MEM_SEG   ("testdata/ones_70.mif"),
        .MEM_GAUSS ("testdata/ones_46.mif"),
        .MEM_GAUSS_PHASE("testdata/ones_46.mif"),
        .MEM_PH_F34("testdata/ones_210.mif"),
        .MEM_PH_CSA("testdata/ones_192.mif"),
        .MEM_NOISE0({RTL_DIR, "/components/noise/noise_s4_icdf0.mif"}),
        .MEM_NOISE1({RTL_DIR, "/components/noise/noise_s4_icdf1.mif"}),
        .MEM_NOISE2({RTL_DIR, "/components/noise/noise_s4_icdf2.mif"})
`ifdef TB_JITTER
        , .PHASE_SHAPER(1), .JITTER(1)
`elsif TB_PHASE
        , .PHASE_SHAPER(1), .JITTER(0)              // PHASE0 = 0: it starts with the set of phase 0
`endif
    ) dut (
        .clk(clk), .rst(rst),
        .addr(addr), .wdata(wdata), .wr(wr), .rd(rd), .rdata(rdata),
        .hits_out(d_hits), .bt_mask_out(d_mask),
        .energy_out(d_energy), .event_bt(d_ebt), .event_all(d_eall),
        .shaper_out(d_shaper), .shaper_corrupted(d_corr),
        .shaper_clip(d_clip), .noise_out(d_noise)
    );

    // ---------------------------------------------------------------- reference
    reg [15:0] r_occupancy = 16'd40000;
    wire r_hits, r_mask;
    wire [12:0] r_energy, r_ebt, r_eall;
    wire signed [29:0] r_shaper, r_corr;
    wire [11:0] r_clip;
    wire signed [16:0] r_noise;

    hits_core #(
        .BUNCH_MEM ("testdata/mask_3000.mif"),
        .BUNCH_POS (3000),
        .MEM_ENG0  ({RTL_DIR, "/components/energy/energy_icdf_paper_0.mif"}),
        .MEM_ENG1  ({RTL_DIR, "/components/energy/energy_icdf_paper_1.mif"}),
        .MEM_ENG2  ({RTL_DIR, "/components/energy/energy_icdf_paper_2.mif"}),
        .MEM_SEG   ({RTL_DIR, "/components/energy/energy_seg_lorenzetti.mif"}),
        .MEM_GAUSS ({RTL_DIR, "/components/noise/noise_gauss_s4.mif"}),
        .MEM_GAUSS_PHASE({RTL_DIR, "/components/noise/noise_gauss_s4.mif"}),
        .MEM_PH_F34({RTL_DIR, "/components/shaper/shaper_fenics_f34_phase.mif"}),
        .MEM_PH_CSA({RTL_DIR, "/components/shaper/shaper_csa_cr4rc_phase.mif"}),
        .MEM_NOISE0({RTL_DIR, "/components/noise/noise_s4_icdf0.mif"}),
        .MEM_NOISE1({RTL_DIR, "/components/noise/noise_s4_icdf1.mif"}),
        .MEM_NOISE2({RTL_DIR, "/components/noise/noise_s4_icdf2.mif"}),
        .PHASE0    (`PHASE_REF),
        .SIGMA_PS  (`SIGMA_REF)
    ) reference (
        .clk(clk), .rst(rst | dut.core_rst),     // released on the same edge as the dut
        .occupancy(r_occupancy), .offset(13'sd100),
        .occ_bypass(1'b0), .train_active(1'b1), .orbit_last(12'd2999),
        .phase0(`PHASE_REF), .sigma_k(`K_REF),
        .mem_we(1'b0), .mem_sel(3'd0), .mem_addr(12'd0), .mem_wdata(210'd0),
        .hits_out(r_hits), .bt_mask_out(r_mask),
        .energy_out(r_energy), .event_bt(r_ebt), .event_all(r_eall),
        .shaper_out(r_shaper), .shaper_corrupted(r_corr),
        .shaper_clip(r_clip), .noise_out(r_noise)
    );

    // ---------------------------------------------------------------- the data loaded
    reg [0:0]  mask [0:2999];
    reg [69:0] eng  [0:511];
    reg [45:0] gss  [0:255];
    reg [PH_W-1:0] ph [0:63];
    initial begin
        $readmemb({RTL_DIR, `PH_MIF}, ph);
        $readmemb("testdata/mask_3000.mif", mask);
        $readmemb({RTL_DIR, "/components/energy/energy_seg_lorenzetti.mif"}, eng);
        $readmemb({RTL_DIR, "/components/noise/noise_gauss_s4.mif"}, gss);
    end

    // ---------------------------------------------------------------- comparison
    reg comparing = 1'b0;
    integer errors = 0, cycles = 0, loaded_errors = 0;
    always @(posedge clk) if (comparing) begin
        #1;
        cycles = cycles + 1;
        if ({d_hits, d_mask, d_energy, d_ebt, d_eall, d_shaper, d_corr, d_clip, d_noise} !==
            {r_hits, r_mask, r_energy, r_ebt, r_eall, r_shaper, r_corr, r_clip, r_noise}) begin
            if (errors < 5)
                $display("ERROR t=%0t: dut clip %0d hits %b energy %0d noise %0d | ref clip %0d hits %b energy %0d noise %0d",
                         $time, d_clip, d_hits, d_energy, d_noise, r_clip, r_hits, r_energy, r_noise);
            errors = errors + 1;
        end
    end

    integer n, k;
    reg [15:0] v;
    initial begin
        $dumpfile("hits_config_tb.vcd");
        $dumpvars(1, hits_config_tb);

        repeat (4) @(posedge clk);
        rst <= 1'b0;
        repeat (10) @(posedge clk);

        bus_write(4'd2, 16'd0);                         // CONTROL: RUN = 0
        bus_write(4'd9, 16'd0);                         // the mask
        bus_write(4'd10, 16'd0);
        for (n = 0; n < 3000; n = n + 1) bus_write(4'd11, {15'd0, mask[n]});
        bus_write(4'd9, 16'd1);                         // the energy ROM, 5 pieces per word
        bus_write(4'd10, 16'd0);
        for (n = 0; n < 512; n = n + 1)
            for (k = 0; k < 5; k = k + 1) bus_write(4'd11, ({10'd0, eng[n]} >> (16 * k)));
        bus_write(4'd9, 16'd2);                         // the noise Gaussian, 3 pieces per word
        bus_write(4'd10, 16'd0);
        for (n = 0; n < 256; n = n + 1)
            for (k = 0; k < 3; k = k + 1) bus_write(4'd11, ({2'd0, gss[n]} >> (16 * k)));
`ifdef TB_JITTER
        bus_write(4'd9, 16'd3);                         // the jitter Gaussian
        bus_write(4'd10, 16'd0);
        for (n = 0; n < 256; n = n + 1)
            for (k = 0; k < 3; k = k + 1) bus_write(4'd11, ({2'd0, gss[n]} >> (16 * k)));
        bus_write(4'd7, `PHASE_REF);                    // PHASE0
        bus_write(4'd8, `K_REF);                        // SIGMA
        bus_write(4'd9, 16'd4);                         // the table of the 64 phases
        bus_write(4'd10, 16'd0);
        for (n = 0; n < 64; n = n + 1)
            for (k = 0; k < PH_PIECES; k = k + 1) bus_write(4'd11, ({{(16*PH_PIECES-PH_W){1'b0}}, ph[n]} >> (16 * k)));
`elsif TB_PHASE
        bus_write(4'd9, 16'd5);                         // the one set of the fixed phase
        bus_write(4'd10, 16'd0);
        for (k = 0; k < PH_PIECES; k = k + 1) bus_write(4'd11, ({{(16*PH_PIECES-PH_W){1'b0}}, ph[32 + `PHASE_REF]} >> (16 * k)));
`endif
        bus_write(4'd6, 16'd3000);                      // ORBIT_LEN
        bus_write(4'd3, 16'd40000);                     // OCCUPANCY
        bus_write(4'd4, 16'd100);                       // PEDESTAL
        bus_write(4'd5, 16'd2);                         // MODE: mask on, no bypass
        @(negedge clk);

        // what was loaded, word by word and register by register: the comparison of the
        // outputs alone misses words of the deep tails (probability ~2^-32) and small
        // changes of a scalar (an occupancy off by 1/65536)
        for (n = 0; n < 3000; n = n + 1)
            if (dut.core.hb_train.bt_mask.mask[n] !== mask[n]) begin
                if (loaded_errors < 5) $display("ERROR: mask word %0d", n);
                loaded_errors = loaded_errors + 1;
            end
        for (n = 0; n < 512; n = n + 1)
            if (dut.core.ec.seg.eng_seg.rom[n] !== eng[n]) begin
                if (loaded_errors < 5) $display("ERROR: energy word %0d", n);
                loaded_errors = loaded_errors + 1;
            end
        for (n = 0; n < 256; n = n + 1)
            if (dut.core.noise_sim.gauss.noise_dist.rom[n] !== gss[n]) begin
                if (loaded_errors < 5) $display("ERROR: noise word %0d", n);
                loaded_errors = loaded_errors + 1;
            end
`ifdef TB_JITTER
        for (n = 0; n < 256; n = n + 1)
            if (dut.core.jitter.gauss_ph.rom[n] !== gss[n]) begin
                if (loaded_errors < 5) $display("ERROR: jitter word %0d", n);
                loaded_errors = loaded_errors + 1;
            end
        for (n = 0; n < 64; n = n + 1)
  `ifdef USE_SHAPER_CSA_CR4RC
            if (dut.core.g_phase.sf.pipe.tbl.rom_ph[n] !== ph[n]) begin
  `else
            if (dut.core.g_phase.sf.tbl.rom_ph[n] !== ph[n]) begin
  `endif
                if (loaded_errors < 5) $display("ERROR: phase table word %0d", n);
                loaded_errors = loaded_errors + 1;
            end
`elsif TB_PHASE
  `ifdef USE_SHAPER_CSA_CR4RC
        if (dut.core.g_phase.sf.pipe.one.coef !== ph[32 + `PHASE_REF]) begin
  `else
        if (dut.core.g_phase.sf.one.coef !== ph[32 + `PHASE_REF]) begin
  `endif
            $display("ERROR: the set of coefficients of the fixed phase");
            loaded_errors = loaded_errors + 1;
        end
`endif
        if ({dut.occupancy, dut.offset, dut.occ_bypass, dut.train_active, dut.orbit_last,
             dut.phase0, dut.sigma_k} !== {16'd40000, 13'd100, 1'b0, 1'b1, 12'd2999,
             6'd`PHASE0_REG, 16'd`K_REF}) begin
            $display("ERROR: scalars occupancy %0d pedestal %0d bypass %b mask %b orbit_last %0d phase0 %0d sigma_k %0d",
                     dut.occupancy, dut.offset, dut.occ_bypass, dut.train_active, dut.orbit_last,
                     dut.phase0, dut.sigma_k);
            loaded_errors = loaded_errors + 1;
        end
        $display("loaded: %0d mask, 512 energy, 256 noise words and the scalars: %0d wrong",
                 3000, loaded_errors);
        errors = errors + loaded_errors;

        comparing <= 1'b1;
        bus_write(4'd2, 16'd1);                         // RUN = 1: both leave reset

        repeat (N_RUN / 2) @(posedge clk);
        // a scalar while running: the occupancy, in both on the same edge
        @(negedge clk); addr = 4'd3; wdata = 16'd12000; wr = 1'b1;
        @(posedge clk); r_occupancy <= 16'd12000;
        @(negedge clk); wr = 1'b0;
        repeat (N_RUN / 2) @(posedge clk);
        comparing <= 1'b0;

        bus_read(4'd0, v); if (v !== 16'h4854) begin $display("ERROR: ID %h", v); errors = errors + 1; end
        bus_read(4'd1, v); $display("CAPS %h", v);
        bus_read(4'd2, v); if (v !== 16'd1) begin $display("ERROR: STATUS %h", v); errors = errors + 1; end

        $display("compared %0d cycles: %0d differences", cycles, errors);
        if (errors == 0) $display("hits through the bus = hits_core with constants, bit for bit");
        $finish;
    end

endmodule
