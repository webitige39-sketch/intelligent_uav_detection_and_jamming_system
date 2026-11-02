# Run with Vivado 2021.1 from any directory. Original source remains unchanged.
set root [file normalize [file join [file dirname [info script]] ..]]
set dest [file join $root build output]
file mkdir $dest
cd $root
open_project [file join $root mult_freq_jam_dma_0711.xpr]
reset_run synth_1
set bd [get_files -quiet *.bd]
if {[llength $bd]} { generate_target all $bd }
set ips [get_ips -quiet]
if {[llength $ips]} { generate_target all $ips }
launch_runs synth_1 -jobs 4
wait_on_run synth_1
if {![string match "*Complete*" [get_property STATUS [get_runs synth_1]]]} { error "Synthesis did not complete" }
launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1
if {![string match "*Complete*" [get_property STATUS [get_runs impl_1]]]} { error "Implementation did not complete" }
open_run impl_1
report_utilization -file [file join $dest impl_utilization.rpt]
report_timing_summary -file [file join $dest impl_timing_summary.rpt]
report_drc -file [file join $dest impl_drc.rpt]
write_hw_platform -fixed -include_bit -force -file [file join $dest system_wrapper_dma.xsa]
close_project
