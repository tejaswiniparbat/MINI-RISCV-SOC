if {![info exists argv]} { set argv {} }
# Build the FPGA bitstream.  Run from the PROJECT ROOT so firmware/board_demo.hex is found:
#   vivado -mode batch -source vivado/build.tcl                 (full build)
#   vivado -mode batch -source vivado/build.tcl -tclargs synth  (synthesis only: resources + timing estimate)
# Or in the Vivado Tcl console:  cd C:/MINI-RISKV-SOC ; source vivado/build.tcl

set PART    xc7a35tcpg236-1     ;# Basys 3 (Artix-7 35T).  CHANGE for other boards.
set XDC     vivado/basys3.xdc
set TOP     fpga_top
set CLK_DIV 4                   ;# 100 MHz / 4 = 25 MHz CPU clock.  Try 2 (50 MHz) once timing passes.
set OUT     vivado/out

file mkdir $OUT

read_verilog -sv [glob rtl/*.sv]
read_xdc $XDC

synth_design -top $TOP -part $PART -generic CLK_DIV=$CLK_DIV
write_checkpoint -force $OUT/post_synth.dcp
report_utilization -file $OUT/utilization_synth.rpt

if {[llength $argv] > 0 && [lindex $argv 0] eq "synth"} {
    puts "Synthesis only: see $OUT/utilization_synth.rpt"
    return
}

opt_design
place_design
route_design
write_checkpoint -force $OUT/post_route.dcp
report_timing_summary -file $OUT/timing.rpt
report_utilization    -file $OUT/utilization.rpt

set wns [get_property SLACK [get_timing_paths -max_paths 1 -setup]]
puts "Worst setup slack: $wns ns"
if {$wns < 0} {
    puts "WARNING: timing NOT met. Increase CLK_DIV (for example 4 -> 6) and run again."
}

write_bitstream -force $OUT/$TOP.bit
puts "Bitstream written: $OUT/$TOP.bit"
