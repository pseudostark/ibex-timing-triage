# final.tcl - timing of the ibex design at the signed-off checkpoint.
# Run inside the ORFS `make ... bash` shell:  $OPENROAD_EXE -no_init -exit final.tcl
# Parasitics come from the extracted SPEF of the routed design.

source $::env(SCRIPTS_DIR)/load.tcl
load_design 6_final.odb 6_final.sdc
set_propagated_clock [all_clocks]
read_spef $::env(RESULTS_DIR)/6_final.spef

report_worst_slack -max -digits 4
report_tns -digits 4
report_worst_slack -min -digits 4
puts "violating endpoints: [sta::endpoint_violation_count max]"
