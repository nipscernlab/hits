// pll_de2_115.v -- the two clocks of the menu of HITS on the DE2-115 (Cyclone IV E),
// from the 50 MHz CLOCK_50: 40 MHz for SAPHO and hits, 25 MHz for the keyboard and
// the screen (the pixel clock of 640 x 480 at 60 Hz). The ALTPLL megafunction written
// by hand with the parameters the IP Catalog's wizard would set.
module pll_de2_115 (
    input  wire inclk0,     // 50 MHz
    output wire clk40,      // 50 * 4 / 5
    output wire clk25,      // 50 / 2
    output wire locked      // 1 = both clocks are steady
);
    wire [4:0] clk;
    altpll #(
        .intended_device_family ("Cyclone IV E"),
        .operation_mode         ("NORMAL"),
        .inclk0_input_frequency (20000),      // ps
        .clk0_multiply_by       (4),
        .clk0_divide_by         (5),
        .clk0_duty_cycle        (50),
        .clk0_phase_shift       ("0"),
        .clk1_multiply_by       (1),
        .clk1_divide_by         (2),
        .clk1_duty_cycle        (50),
        .clk1_phase_shift       ("0"),
        .port_clk0              ("PORT_USED"),
        .port_clk1              ("PORT_USED"),
        .port_locked            ("PORT_USED"),
        .width_clock            (5),
        .pll_type               ("AUTO"),
        .lpm_type               ("altpll")
    ) u (
        .inclk  ({1'b0, inclk0}),
        .clk    (clk),
        .locked (locked)
    );
    assign clk40 = clk[0];
    assign clk25 = clk[1];
endmodule
