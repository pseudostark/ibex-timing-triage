# cts.tcl - timing of the ibex design at the post-CTS checkpoint.
# Run inside the ORFS `make ... bash` shell:  $OPENROAD_EXE -no_init -exit cts.tcl
# Wires do not exist yet, so parasitics are estimated from placement.

source $::env(SCRIPTS_DIR)/load.tcl
load_design 4_1_cts.odb 4_cts.sdc
set_propagated_clock [all_clocks]
estimate_parasitics -placement

report_worst_slack -max -digits 4
report_tns -digits 4
report_worst_slack -min -digits 4
puts "violating endpoints: [sta::endpoint_violation_count max]"
