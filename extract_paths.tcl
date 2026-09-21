# extract_paths.tcl
# Dump timing data from a loaded OpenROAD / OpenSTA session for offline triage.
#
# Writes three files into $PT_OUT_DIR:
#   summary.csv     one row: WNS, TNS, violating endpoints (setup and hold)
#   paths_max.csv   worst N setup paths, one row per path end
#   paths_max.json  same paths with every pin and arrival (report_checks json)
#
# STATUS: work in progress, not yet validated against a run.
#
# Usage: source it at the end of cts.tcl or final.tcl, after the design,
# SDC and parasitics are loaded, e.g.
#   PT_RUN_TAG=final PT_OUT_DIR=out/final $OPENROAD_EXE -no_init -exit final.tcl
#
# Settings come from environment variables so a Makefile can drive runs.

proc pt_env { name default } {
  if { [info exists ::env($name)] } { return $::env($name) }
  return $default
}

set pt_run_tag [pt_env PT_RUN_TAG "untagged"]
set pt_out_dir [pt_env PT_OUT_DIR "timing_dump"]
set pt_npaths  [pt_env PT_NPATHS 200]
file mkdir $pt_out_dir

# CSV-safe field: quote it, double any embedded quotes.
proc pt_csv { fields } {
  set out {}
  foreach f $fields {
    lappend out "\"[string map {\" \"\"} $f]\""
  }
  return [join $out ","]
}

# Path and PathEnd accessors return seconds. Convert to the UI unit (ns for sky130).
proc pt_t { seconds } {
  return [format "%.4f" [sta::time_sta_ui $seconds]]
}

# ---------------------------------------------------------------- summary
proc pt_write_summary { file run_tag } {
  set fh [open $file w]
  puts $fh "run_tag,setup_wns,setup_tns,setup_violations,hold_wns,hold_tns,hold_violations"
  # worst_slack / total_negative_slack already return UI units.
  puts $fh [pt_csv [list $run_tag \
    [sta::worst_slack -max] [sta::total_negative_slack -max] \
    [sta::endpoint_violation_count max] \
    [sta::worst_slack -min] [sta::total_negative_slack -min] \
    [sta::endpoint_violation_count min]]]
  close $fh
}

# ---------------------------------------------------------------- per path
proc pt_write_paths { file run_tag delay_type npaths } {
  set fh [open $file w]
  puts $fh "run_tag,rank,slack,startpoint,endpoint,start_clock_pin_inst,end_inst,target_clock,arrival,required,clock_skew,check"

  # Older OpenSTA builds call the flag -group_count instead of -group_path_count.
  set ends [find_timing_paths -path_delay $delay_type \
              -group_path_count $npaths -sort_by_slack]

  set rank 0
  foreach path_end $ends {
    if { [$path_end is_unconstrained] } { continue }
    incr rank

    set end_pin   [$path_end pin]
    set start_pin [[[$path_end path] start_path] pin]
    set start     [get_full_name $start_pin]
    set end       [get_full_name $end_pin]

    # Instance name = pin name minus the last /PIN. Ports have no slash.
    set start_inst [expr { [string last / $start] < 0 ? "PORT" \
                     : [string range $start 0 [expr {[string last / $start] - 1}]] }]
    set end_inst   [expr { [string last / $end] < 0 ? "PORT" \
                     : [string range $end 0 [expr {[string last / $end] - 1}]] }]

    set clk [$path_end target_clk]
    set clk_name [expr { $clk eq "NULL" ? "" : [get_name $clk] }]

    # check_role comes back as a plain string (setup, hold, recovery, ...).
    set role_name [$path_end check_role]

    puts $fh [pt_csv [list $run_tag $rank \
      [pt_t [$path_end slack]] $start $end $start_inst $end_inst $clk_name \
      [pt_t [$path_end data_arrival_time]] \
      [pt_t [$path_end data_required_time]] \
      [pt_t [$path_end clk_skew]] $role_name]]
  }
  close $fh
  return $rank
}

# ---------------------------------------------------------------- run
pt_write_summary [file join $pt_out_dir summary.csv] $pt_run_tag
set n [pt_write_paths [file join $pt_out_dir paths_max.csv] $pt_run_tag max $pt_npaths]

# Full pin-by-pin detail for the Python side (logic depth, cell vs net delay).
report_checks -path_delay max -group_path_count $pt_npaths -sort_by_slack \
  -format json \
  > [file join $pt_out_dir paths_max.json]

puts "path-triage: wrote $n setup paths for '$pt_run_tag' to $pt_out_dir"
