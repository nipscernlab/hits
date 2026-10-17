# hits_vivado.tcl -- the HITS simulator core in Vivado (AMD/Xilinx), out of context.
#
# Synthesizes, places and routes rtl/hits_simulator.v for one part, with no board
# and no pins (out of context), against the 25 ns clock, and prints the resources
# and the worst-case Fmax. It is an example of using the core in a Vivado flow:
# to put HITS on a board, instantiate hits_simulator in your own top instead.
#
# Run it from an EMPTY folder (Vivado writes its reports there):
#   vivado -mode batch -source <hits>/projects/simulador_puro/vivado/hits_vivado.tcl \
#          -tclargs [part] [D:<MACRO>[:value] ...] [G:<PARAMETER>:<value> ...]
# Examples:
#   ... -tclargs                                    # xc7z010clg400-1, the default build
#   ... -tclargs xc7z010clg400-1 D:USE_SHAPER_CSA_CR4RC G:SIGMA_PS:1000
# (a colon, not "=": vivado.bat on Windows splits its arguments at "=")
#
# The .mif memories of rtl/ are copied to the run folder: hits_simulator names
# them by bare file name, and Vivado reads them from where it runs.

set here [file dirname [file normalize [info script]]]
set rtl  [file normalize [file join $here .. .. .. rtl]]
set part xc7z010clg400-1
set defines {}
set generics {}
foreach a $argv {
    if {[string match D:* $a]} {
        lappend defines [regsub {:} [string range $a 2 end] {=}]
    } elseif {[string match G:* $a]} {
        lappend generics [regsub {:} [string range $a 2 end] {=}]
    } else {
        set part $a
    }
}

foreach f [glob [file join $rtl * *.mif]] { file copy -force $f [pwd] }
set fd [open clk.xdc w]
puts $fd "create_clock -name clk -period 25.000 \[get_ports clk\]"
close $fd

read_verilog [concat [glob [file join $rtl *.v]] [glob [file join $rtl * *.v]]]
read_xdc -mode out_of_context clk.xdc
set opts [list -top hits_simulator -part $part -mode out_of_context]
if {[llength $defines]}  { lappend opts -verilog_define $defines }
if {[llength $generics]} { lappend opts -generic $generics }
synth_design {*}$opts
opt_design
place_design
route_design

report_utilization    -file utilization.rpt
report_timing_summary -file timing.rpt
set wns [get_property SLACK [get_timing_paths -max_paths 1 -setup]]
set fmax [expr {1000.0 / (25.0 - $wns)}]
set lut  [llength [get_cells -hier -filter {IS_PRIMITIVE && REF_NAME =~ LUT*}]]
set ff   [llength [get_cells -hier -filter {IS_PRIMITIVE && REF_NAME =~ FD*}]]
set dsp  [llength [get_cells -hier -filter {IS_PRIMITIVE && REF_NAME =~ DSP*}]]
set b36  [llength [get_cells -hier -filter {IS_PRIMITIVE && REF_NAME =~ RAMB36*}]]
set b18  [llength [get_cells -hier -filter {IS_PRIMITIVE && REF_NAME =~ RAMB18*}]]
set fh [open result.txt w]
set line [format "hits_simulator %s  defines {%s}  generics {%s}: %d LUT, %d FF, %d DSP, %d RAMB36 + %d RAMB18, WNS %.3f ns, Fmax %.1f MHz" \
    $part [join $defines " "] [join $generics " "] $lut $ff $dsp $b36 $b18 $wns $fmax]
puts $fh $line
close $fh
puts "RESULT $line"
