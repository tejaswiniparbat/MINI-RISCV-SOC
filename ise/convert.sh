#!/bin/sh
# Convert the SystemVerilog design to plain Verilog-2005 for Xilinx ISE (its synthesizer, XST,
# does not understand SystemVerilog).  Needs sv2v (https://github.com/zachjs/sv2v) and python3.
#   SV2V=./tools/sv2v-Windows/sv2v.exe sh ise/convert.sh       (or put sv2v on your PATH)
# Output: build/soc_xst.v   (top module for the board: fpga_top)
set -e
cd "$(dirname "$0")/.."
SV2V=${SV2V:-sv2v}
mkdir -p build
"$SV2V" -w build/soc_v2001.v rtl/*.sv
python3 ise/postproc.py build/soc_v2001.v build/soc_xst.v
echo "wrote build/soc_xst.v ($(wc -l < build/soc_xst.v) lines)"
