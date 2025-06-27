#!/usr/bin/env vivado -mode tcl -source
#*****************************************************************************************
# Vivado TCL script for creating and synthesizing zcash_fpga_top project
#
# This script creates a Vivado project for the Zcash FPGA top-level design and runs synthesis
#*****************************************************************************************

# Set the reference directory for source file relative paths (by default the value is script directory path)
set script_path [file dirname [file normalize [info script]]]
puts "Script path: $script_path"
set origin_dir $script_path

# Set the project name
set _xil_proj_name_ "zcash_fpga_top"

# Use project name variable, if specified in the tcl shell
if { [info exists ::user_project_name] } {
  set _xil_proj_name_ $::user_project_name
}

# Set the directory path for the project
set proj_dir "$origin_dir/vivado_project"

# Parse command line arguments
variable script_file
set script_file "create_zcash_fpga_top_project.tcl"

if { $::argc > 0 } {
  for {set i 0} {$i < $::argc} {incr i} {
    set option [string trim [lindex $::argv $i]]
    switch -regexp -- $option {
      "--origin_dir"     { incr i; set origin_dir [lindex $::argv $i] }
      "--project_name"   { incr i; set _xil_proj_name_ [lindex $::argv $i] }
      "--project_dir"    { incr i; set proj_dir [lindex $::argv $i] }
      "--part"           { incr i; set target_part [lindex $::argv $i] }
      "--run_synth"      { set run_synthesis 1 }
      "--help"           { 
        puts "Usage: vivado -mode tcl -source $script_file -tclargs \[OPTIONS\]"
        puts "Options:"
        puts "  --origin_dir <path>     : Set the origin directory"
        puts "  --project_name <name>   : Set the project name" 
        puts "  --project_dir <path>    : Set the project directory"
        puts "  --part <part_name>      : Set the target FPGA part"
        puts "  --run_synth             : Run synthesis after project creation"
        puts "  --help                  : Show this help message"
        return 0
      }
      default {
        if { [regexp {^-} $option] } {
          puts "ERROR: Unknown option '$option' specified, please type '$script_file -tclargs --help' for usage info.\n"
          return 1
        }
      }
    }
  }
}

# Set default values
if { ![info exists target_part] } {
  set target_part "xcvu9p-flga2104-2L-e"  # AWS F1 part, change as needed
}

if { ![info exists run_synthesis] } {
  set run_synthesis 0
}

# Set ZCASH_DIR environment variable if not set
if { ![info exists ::env(ZCASH_DIR)] } {
  set ::env(ZCASH_DIR) $origin_dir
  puts "Setting ZCASH_DIR to: $origin_dir"
} else {
  puts "Using existing ZCASH_DIR: $::env(ZCASH_DIR)"
}

puts "=========================================="
puts "Creating Zcash FPGA Top Level Project"
puts "=========================================="
puts "Project name: $_xil_proj_name_"
puts "Project directory: $proj_dir"
puts "Target part: $target_part"
puts "Run synthesis: $run_synthesis"
puts "ZCASH_DIR: $::env(ZCASH_DIR)"
puts "=========================================="

# Create project directory if it doesn't exist
file mkdir $proj_dir

# Create project
create_project $_xil_proj_name_ $proj_dir -part $target_part -force

# Set the directory path for the new project
set proj_dir [get_property directory [current_project]]

# Set project properties
set obj [current_project]
set_property -name "default_lib" -value "xil_defaultlib" -objects $obj
set_property -name "enable_vhdl_2008" -value "1" -objects $obj
set_property -name "ip_cache_permissions" -value "read write" -objects $obj
set_property -name "ip_output_repo" -value "$proj_dir/$_xil_proj_name_.cache/ip" -objects $obj
set_property -name "mem.enable_memory_map_generation" -value "1" -objects $obj
set_property -name "part" -value $target_part -objects $obj
set_property -name "sim.central_dir" -value "$proj_dir/$_xil_proj_name_.ip_user_files" -objects $obj
set_property -name "sim.ip.auto_export_scripts" -value "1" -objects $obj
set_property -name "simulator_language" -value "Mixed" -objects $obj
set_property -name "target_language" -value "Verilog" -objects $obj

# Create 'sources_1' fileset (if not found)
if {[string equal [get_filesets -quiet sources_1] ""]} {
  create_fileset -srcset sources_1
}

# Function to add files with environment variable substitution
proc add_zcash_files {file_list} {
  set processed_files {}
  foreach file_path $file_list {
    # Replace ${ZCASH_DIR} with actual path
    set actual_path [string map [list "\${ZCASH_DIR}" $::env(ZCASH_DIR)] $file_path]
    set normalized_path [file normalize $actual_path]
    
    if {[file exists $normalized_path]} {
      lappend processed_files $normalized_path
      puts "Adding file: $normalized_path"
    } else {
      puts "WARNING: File not found: $normalized_path"
    }
  }
  return $processed_files
}

# Read the include.f file and process the source files
set include_file "$::env(ZCASH_DIR)/zcash_fpga/src/rtl/top/include.f"
if {[file exists $include_file]} {
  set fp [open $include_file r]
  set file_content [read $fp]
  close $fp
  
  # Split into lines and filter out empty lines
  set file_lines [split $file_content "\n"]
  set source_files {}
  
  foreach line $file_lines {
    set line [string trim $line]
    if {$line != "" && ![string match "#*" $line]} {
      lappend source_files $line
    }
  }
  
  # Process and add the files
  set processed_files [add_zcash_files $source_files]
  
  if {[llength $processed_files] > 0} {
    # Set 'sources_1' fileset object
    set obj [get_filesets sources_1]
    add_files -norecurse -fileset $obj $processed_files
    
    # Set file properties for SystemVerilog files
    foreach file_path $processed_files {
      if {[string match "*.sv" $file_path]} {
        set file_obj [get_files -of_objects [get_filesets sources_1] [list "*[file tail $file_path]"]]
        if {$file_obj != ""} {
          set_property -name "file_type" -value "SystemVerilog" -objects $file_obj
        }
      }
    }
    
    # Set the top level module
    set_property -name "top" -value "zcash_fpga_top" -objects $obj
    puts "Set top level to: zcash_fpga_top"
  } else {
    puts "ERROR: No valid source files found!"
    return 1
  }
} else {
  puts "ERROR: Include file not found: $include_file"
  return 1
}

# Create 'constrs_1' fileset (if not found)
if {[string equal [get_filesets -quiet constrs_1] ""]} {
  create_fileset -constrset constrs_1
}

# Set 'constrs_1' fileset object
set obj [get_filesets constrs_1]

# Look for constraint files (optional)
set constraint_files [list \
  "$::env(ZCASH_DIR)/zcash_fpga/src/constrs/zcash_fpga_top.xdc" \
  "$::env(ZCASH_DIR)/constrs/zcash_fpga_top.xdc" \
]

foreach constr_file $constraint_files {
  if {[file exists $constr_file]} {
    set file_added [add_files -norecurse -fileset $obj [list $constr_file]]
    set file_obj [get_files -of_objects [get_filesets constrs_1] [list "*[file tail $constr_file]"]]
    if {$file_obj != ""} {
      set_property -name "file_type" -value "XDC" -objects $file_obj
      puts "Added constraint file: $constr_file"
    }
    break
  }
}

# Set 'constrs_1' fileset properties
set_property -name "target_part" -value $target_part -objects $obj

# Create 'sim_1' fileset (if not found)
if {[string equal [get_filesets -quiet sim_1] ""]} {
  create_fileset -simset sim_1
}

# Set 'sim_1' fileset object
set obj [get_filesets sim_1]

# Look for testbench files (optional)
set tb_files [list \
  "$::env(ZCASH_DIR)/zcash_fpga/src/tb/zcash_fpga_top_tb.sv" \
]

foreach tb_file $tb_files {
  if {[file exists $tb_file]} {
    add_files -norecurse -fileset $obj [list $tb_file]
    set file_obj [get_files -of_objects [get_filesets sim_1] [list "*[file tail $tb_file]"]]
    if {$file_obj != ""} {
      set_property -name "file_type" -value "SystemVerilog" -objects $file_obj
      set_property -name "top" -value "zcash_fpga_top_tb" -objects $obj
      set_property -name "top_lib" -value "xil_defaultlib" -objects $obj
      puts "Added testbench: $tb_file"
    }
    break
  }
}

# Create synthesis run
if {[string equal [get_runs -quiet synth_1] ""]} {
    create_run -name synth_1 -part $target_part -flow {Vivado Synthesis 2019} -strategy "Vivado Synthesis Defaults" -report_strategy {No Reports} -constrset constrs_1
} else {
  set_property strategy "Vivado Synthesis Defaults" [get_runs synth_1]
  set_property flow "Vivado Synthesis 2019" [get_runs synth_1]
}

set obj [get_runs synth_1]
set_property set_report_strategy_name 1 $obj
set_property report_strategy {Vivado Synthesis Default Reports} $obj
set_property set_report_strategy_name 0 $obj

# Set synthesis options for better performance
set_property -name {STEPS.SYNTH_DESIGN.ARGS.MORE OPTIONS} -value {-mode out_of_context} -objects [get_runs synth_1]

# Create implementation run  
if {[string equal [get_runs -quiet impl_1] ""]} {
    create_run -name impl_1 -part $target_part -parent_run synth_1 -flow {Vivado Implementation 2019} -strategy "Vivado Implementation Defaults" -report_strategy {No Reports} -constrset constrs_1
} else {
  set_property strategy "Vivado Implementation Defaults" [get_runs impl_1]
  set_property flow "Vivado Implementation 2019" [get_runs impl_1]
}

puts "=========================================="
puts "Project created successfully!"
puts "Project location: $proj_dir"
puts "=========================================="

# Run synthesis if requested
if {$run_synthesis} {
  puts "Starting synthesis..."
  launch_runs synth_1 -jobs 8
  wait_on_run synth_1
  
  if {[get_property PROGRESS [get_runs synth_1]] != "100%"} {
    puts "ERROR: Synthesis failed!"
    return 1
  } else {
    puts "Synthesis completed successfully!"
    
    # Open synthesized design
    open_run synth_1 -name synth_1
    
    # Generate reports
    report_utilization -file "$proj_dir/utilization_synth.rpt"
    report_timing -max_paths 10 -file "$proj_dir/timing_synth.rpt"
    
    puts "Reports generated:"
    puts "  - Utilization: $proj_dir/utilization_synth.rpt" 
    puts "  - Timing: $proj_dir/timing_synth.rpt"
  }
}

puts "=========================================="
puts "Script completed successfully!"
puts "To open the project in Vivado GUI:"
puts "  vivado $proj_dir/$_xil_proj_name_.xpr"
puts "=========================================="

return 0 