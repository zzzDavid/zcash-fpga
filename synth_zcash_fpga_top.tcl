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
      "--help"           { 
        puts "Usage: vivado -mode tcl -source synth_zcash_fpga_top.tcl -tclargs \[OPTIONS\]"
        puts "Options:"
        puts "  --part <part_name>      : Set the target FPGA part (default: xcvu9p-flga2104-2L-e)"
        puts "  --output_dir <path>     : Set the output directory (default: ./synth_output)"
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

# Set ZCASH_DIR environment variable if not set
set script_path [file dirname [file normalize [info script]]]
if { ![info exists ::env(ZCASH_DIR)] } {
  set ::env(ZCASH_DIR) $script_path
  puts "Setting ZCASH_DIR to: $script_path"
} else {
  puts "Using existing ZCASH_DIR: $::env(ZCASH_DIR)"
}

puts "=========================================="
puts "Zcash FPGA Top Level Synthesis"
puts "=========================================="
puts "Target part: $target_part"
puts "Output directory: $output_dir"
puts "ZCASH_DIR: $::env(ZCASH_DIR)"
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

return 0 