#!/bin/sh
# run.sh -- simulates the menu of HITS on SAPHO (hits_menu_tb.v) with Icarus Verilog.
#
#   sh sim/run.sh [+screen]    (+screen prints the screen at the end)
#
# Needs only Icarus Verilog: the processor and the blocks of SAPHO (sapho/) are the ones
# software/build.sh wrote. Runs from projects/de2_115_sapho, where SAPHO reads its
# memories. Ends with "hits_menu: ok", and exits with 1 when the bench fails, so CI can
# run it.
set -e
HERE="$(cd "$(dirname "$0")/.." && pwd)"
RTL="$HERE/../../rtl"
S=sapho
cd "$HERE"
iverilog -g2012 -s hits_menu_tb -o sim/hits_menu.vvp \
    "$S/addr_dec.v" "$S/instr_dec.v" "$S/processor.v" "$S/core.v" "$S/ula.v" \
    "$S/myKeyPS2.v" "$S/myVGAText.v" hits_menu.v hex_debug.v\
    "$RTL/hits.v" "$RTL/hits/hits_core.v" "$RTL/hits/hits_cfg.v" "$RTL/hits/hits_sapho.v" \
    "$RTL"/components/*/*.v \
    sim/hits_menu_tb.v
LOG="$(mktemp)"
vvp -n sim/hits_menu.vvp "$@" | tee "$LOG"
rm -f sim/hits_menu.vvp
status=0
grep -q "^hits_menu: ok" "$LOG" || status=1
rm -f "$LOG"
exit $status
