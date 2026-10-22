# 50 MHz board clock; the PLL derives the 40 MHz simulator clock.
create_clock -name clk50 -period 20.000 [get_ports FPGA_CLK1_50]
derive_pll_clocks
derive_clock_uncertainty
# The configuration bus and SW0 come from outside the board; they are registered at the
# pins (top_hits_de10.v) and their board timing is not modelled here.
set_false_path -from [get_ports {SW0 BUS_ADDR[*] BUS_WDATA[*] BUS_WR BUS_RD}]
set_false_path -to [get_ports {BUS_RDATA[*] BUS_CLK}]
