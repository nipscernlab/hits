# 50 MHz board clock; the PLL derives the 40 MHz simulator clock.
create_clock -name clk50 -period 20.000 [get_ports FPGA_CLK1_50]
derive_pll_clocks
derive_clock_uncertainty
