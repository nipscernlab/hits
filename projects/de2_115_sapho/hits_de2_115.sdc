# 50 MHz board clock; the PLL derives 40 MHz (SAPHO and hits) and 25 MHz (keyboard and screen).
create_clock -name clk50 -period 20.000 [get_ports CLOCK_50]
derive_pll_clocks
derive_clock_uncertainty
# The two PLL clocks meet only in the links between SAPHO and the keyboard and the screen,
# which synchronize the handshake and hold the data still while it crosses.
set_clock_groups -asynchronous -group [get_clocks {*pll1|clk[0]}] -group [get_clocks {*pll1|clk[1]}]
# KEY[0], the keyboard and the switches are asynchronous and synchronized inside; the LEDs
# and the displays are slow.
set_false_path -from [get_ports {KEY0 PS2_CLK PS2_DAT SW[*]}]
set_false_path -to [get_ports {LEDG[*] HEX*}]
# The screen: the outputs change on the rising edge of clk25 and the ADV7123 latches
# them on the rising edge of VGA_CLK = ~clk25, half a pixel (20 ns) later; the
# board timing of the converter is not modelled here.
set_false_path -to [get_ports {VGA_*}]
