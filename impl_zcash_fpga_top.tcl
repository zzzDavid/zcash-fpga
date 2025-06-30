#!/usr/bin/env vivado -mode tcl -source
#*****************************************************************************************
# Vivado TCL script for synthesis-only of zcash_fpga_top (no project mode)
#
# This script runs synthesis in non-project mode for faster turnaround
#*****************************************************************************************

# Parse command line arguments
if { $::argc > 0 } {
  for {set i 0} {$i < $::argc} {incr i} {
    set option [string trim [lindex $::argv $i]]
    switch -regexp -- $option {
      "--part"           { incr i; set target_part [lindex $::argv $i] }
      "--output_dir"     { incr i; set output_dir [lindex $::argv $i] }
      "--synth_only"     { set synth_only 1 }
      "--no_bitstream"   { set no_bitstream 1 }
      "--help"           { 
        puts "Usage: vivado -mode tcl -source impl_zcash_fpga_top.tcl -tclargs \[OPTIONS\]"
        puts "Options:"
        puts "  --part <part_name>      : Set the target FPGA part (default: xcv80-lsva4737-2MHP-e-S)"
        puts "  --output_dir <path>     : Set the output directory (default: ./synth_output)"
        puts "  --synth_only            : Run synthesis only, skip implementation"
        puts "  --no_bitstream          : Skip bitstream generation during implementation"
        puts "  --help                  : Show this help message"
        return 0
      }
      default {
        if { [regexp {^-} $option] } {
          puts "ERROR: Unknown option '$option' specified"
          return 1
        }
      }
    }
  }
}

# Set default values
if { ![info exists target_part] } {
  set target_part "xcv80-lsva4737-2MHP-e-S" 
}

if { ![info exists output_dir] } {
  set output_dir "./synth_output"
}

if { ![info exists synth_only] } {
  set synth_only 0
}

if { ![info exists no_bitstream] } {
  set no_bitstream 0
}

# Set ZCASH_DIR environment variable if not set
set script_path [file dirname [file normalize [info script]]]
if { ![info exists ::env(ZCASH_DIR)] } {
  set ::env(ZCASH_DIR) $script_path
  puts "Setting ZCASH_DIR to: $script_path"
} else {
  puts "Using existing ZCASH_DIR: $::env(ZCASH_DIR)"
}

puts "=========================================="
if { $synth_only } {
  puts "Zcash FPGA Top Level Synthesis (Synthesis Only)"
} else {
  puts "Zcash FPGA Top Level Synthesis & Implementation"
}
puts "=========================================="
puts "Target part: $target_part"
puts "Output directory: $output_dir"
puts "ZCASH_DIR: $::env(ZCASH_DIR)"
puts "Mode: [expr {$synth_only ? "Synthesis Only" : "Full Implementation"}]"
if { !$synth_only && $no_bitstream } {
  puts "Bitstream: Disabled"
}
puts "=========================================="

# Create output directory
file mkdir $output_dir

# Read source files from include.f
set include_file "$::env(ZCASH_DIR)/zcash_fpga/src/rtl/top/include.f"
if {![file exists $include_file]} {
  puts "ERROR: Include file not found: $include_file"
  return 1
}

set fp [open $include_file r]
set file_content [read $fp]
close $fp

# Process source files
set file_lines [split $file_content "\n"]
set source_files {}

foreach line $file_lines {
  set line [string trim $line]
  if {$line != "" && ![string match "#*" $line]} {
    # Replace ${ZCASH_DIR} with actual path
    set actual_path [string map [list "\${ZCASH_DIR}" $::env(ZCASH_DIR)] $line]
    set normalized_path [file normalize $actual_path]
    
    if {[file exists $normalized_path]} {
      lappend source_files $normalized_path
      puts "Adding: [file tail $normalized_path]"
    } else {
      puts "WARNING: File not found: $normalized_path"
    }
  }
}

if {[llength $source_files] == 0} {
  puts "ERROR: No valid source files found!"
  return 1
}

puts "Total source files: [llength $source_files]"

# Set part
set_part $target_part

# Read source files
puts "Reading source files..."
read_verilog -sv $source_files

# Look for constraint files
set constraint_files [list \
  "$::env(ZCASH_DIR)/zcash_fpga/src/constrs/zcash_fpga_top.xdc" \
  "$::env(ZCASH_DIR)/constrs/zcash_fpga_top.xdc" \
  "$output_dir/zcash_fpga_top_basic.xdc" \
]

foreach constr_file $constraint_files {
  if {[file exists $constr_file]} {
    puts "Reading constraint file: $constr_file"
    read_xdc $constr_file
    break
  }
}

# Set top module
puts "Setting top module to zcash_fpga_top..."

# Run synthesis
puts "Starting synthesis..."
synth_design -top zcash_fpga_top -part $target_part

# Generate reports
puts "Generating reports..."
report_utilization -file "$output_dir/utilization_post_synth.rpt"
report_timing -max_paths 10 -file "$output_dir/timing_post_synth.rpt"
report_timing_summary -file "$output_dir/timing_summary_post_synth.rpt"

# Write checkpoint
puts "Writing checkpoint..."
write_checkpoint -force "$output_dir/zcash_fpga_top_synth.dcp"

# Write netlist (optional)
write_verilog -force "$output_dir/zcash_fpga_top_netlist.v"
write_xdc -force "$output_dir/zcash_fpga_top_constraints.xdc"

puts "=========================================="
puts "Synthesis completed successfully!"
puts "Output files:"
puts "  - Checkpoint: $output_dir/zcash_fpga_top_synth.dcp"
puts "  - Netlist: $output_dir/zcash_fpga_top_netlist.v"
puts "  - Constraints: $output_dir/zcash_fpga_top_constraints.xdc"
puts "  - Utilization: $output_dir/utilization_post_synth.rpt"
puts "  - Timing: $output_dir/timing_post_synth.rpt"
puts "  - Timing Summary: $output_dir/timing_summary_post_synth.rpt"
puts "=========================================="

# Run implementation if not synthesis-only mode
if { !$synth_only } {
  puts "Starting implementation flow..."
  
  # Step 1: Optimization
  puts "Running optimization..."
  opt_design
  if { [catch {report_utilization -file "$output_dir/utilization_post_opt.rpt"}] } {
    puts "WARNING: Failed to generate post-opt utilization report"
  }
  
  # Step 2: Placement
  puts "Running placement..."
  place_design
  if { [catch {report_utilization -file "$output_dir/utilization_post_place.rpt"}] } {
    puts "WARNING: Failed to generate post-place utilization report"
  }
  if { [catch {report_timing -max_paths 10 -file "$output_dir/timing_post_place.rpt"}] } {
    puts "WARNING: Failed to generate post-place timing report"
  }
  
  # Step 3: Physical optimization (post-placement)
  puts "Running physical optimization..."
  phys_opt_design
  
  # Step 4: Routing
  puts "Running routing..."
  route_design
  
  # Step 5: Post-route physical optimization (optional, helps with timing closure)
  puts "Running post-route physical optimization..."
  if { [catch {phys_opt_design}] } {
    puts "WARNING: Post-route physical optimization failed, continuing..."
  }
  
  # Generate post-implementation reports
  puts "Generating post-implementation reports..."
  report_utilization -file "$output_dir/utilization_post_impl.rpt"
  report_timing -max_paths 10 -file "$output_dir/timing_post_impl.rpt"
  report_timing_summary -file "$output_dir/timing_summary_post_impl.rpt"
  report_route_status -file "$output_dir/route_status_post_impl.rpt"
  report_drc -file "$output_dir/drc_post_impl.rpt"
  report_power -file "$output_dir/power_post_impl.rpt"
  
  # Write post-implementation checkpoint
  puts "Writing post-implementation checkpoint..."
  write_checkpoint -force "$output_dir/zcash_fpga_top_impl.dcp"
  
  # Generate bitstream if not disabled
  if { !$no_bitstream } {
    puts "Generating bitstream..."
    if { [catch {write_bitstream -force "$output_dir/zcash_fpga_top.bit"}] } {
      puts "WARNING: Bitstream generation failed - check DRC violations"
    } else {
      puts "Bitstream generated successfully: $output_dir/zcash_fpga_top.bit"
    }
  } else {
    puts "Skipping bitstream generation (--no_bitstream specified)"
  }
  
  puts "=========================================="
  puts "Implementation completed successfully!"
  puts "Post-implementation output files:"
  puts "  - Implementation Checkpoint: $output_dir/zcash_fpga_top_impl.dcp"
  puts "  - Utilization (Post-Opt): $output_dir/utilization_post_opt.rpt"
  puts "  - Utilization (Post-Place): $output_dir/utilization_post_place.rpt"
  puts "  - Utilization (Post-Impl): $output_dir/utilization_post_impl.rpt"
  puts "  - Timing (Post-Place): $output_dir/timing_post_place.rpt"
  puts "  - Timing (Post-Impl): $output_dir/timing_post_impl.rpt"
  puts "  - Timing Summary: $output_dir/timing_summary_post_impl.rpt"
  puts "  - Route Status: $output_dir/route_status_post_impl.rpt"
  puts "  - DRC Report: $output_dir/drc_post_impl.rpt"
  puts "  - Power Report: $output_dir/power_post_impl.rpt"
  if { !$no_bitstream } {
    puts "  - Bitstream: $output_dir/zcash_fpga_top.bit"
  }
  puts "=========================================="
} else {
  puts "Synthesis-only mode enabled. Skipping implementation."
}

return 0 
