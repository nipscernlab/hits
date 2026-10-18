// ============================================================================
// Transforma o relogio de 50 MHz da DE10-Nano no de 40 MHz do HITS.
// E o mesmo PLL do projeto do HITS para a DE10-Nano
// (projects/hits_reco/quartus/pll_40mhz/pll_40mhz_0002.v), so com as saidas que usamos.
// Copy of the PLL used by the IC roadmaps of the group.
// ============================================================================
`timescale 1ns/10ps
module pll_40mhz_de10 (
    input  wire refclk,    // 50 MHz da placa
    output wire outclk_0,  // 40 MHz
    output wire locked     // 1 = o relogio de 40 MHz ja esta firme
);

    altera_pll #(
        .fractional_vco_multiplier ("false"),
        .reference_clock_frequency ("50.0 MHz"),
        .operation_mode            ("direct"),
        .number_of_clocks          (1),
        .output_clock_frequency0   ("40.000000 MHz"),
        .phase_shift0              ("0 ps"),
        .duty_cycle0               (50),
        .pll_type                  ("General"),
        .pll_subtype               ("General")
    ) altera_pll_i (
        .rst      (1'b0),
        .outclk   ({outclk_0}),
        .locked   (locked),
        .fboutclk (),
        .fbclk    (1'b0),
        .refclk   (refclk)
    );

endmodule
