#!/bin/bash
set -e
cd "$(dirname "$0")/../projects/aurora"
iverilog -s sim_pulsos_tb -o tb.vvp simulacao.v ../../rtl/*.v ../../rtl/*/*.v \
    ../../reconstrucao/*.v ../../reconstrucao/*/*.v sim_pulsos_tb.v
vvp tb.vvp "$@"
