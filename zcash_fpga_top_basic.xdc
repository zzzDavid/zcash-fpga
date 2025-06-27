# Basic XDC constraints for zcash_fpga_top synthesis
# This file provides basic timing constraints for the design

# Clock constraints
# Note: Adjust these frequencies based on your target requirements

# Interface clock (100 MHz example)
create_clock -period 10.000 -name clk_if [get_ports i_clk_if]

# 100 MHz clock
create_clock -period 10.000 -name clk_100 [get_ports i_clk_100]

# 200 MHz clock  
create_clock -period 5.000 -name clk_200 [get_ports i_clk_200]

# 300 MHz clock
create_clock -period 3.333 -name clk_300 [get_ports i_clk_300]

# Clock domain crossing constraints
# These tell Vivado that clocks are asynchronous to each other
set_clock_groups -asynchronous \
  -group [get_clocks clk_if] \
  -group [get_clocks clk_100] \
  -group [get_clocks clk_200] \
  -group [get_clocks clk_300]

# Input/Output delays (adjust based on your interface requirements)
# Example: If signals come from external devices, set appropriate delays
set_input_delay -clock clk_if 2.0 [get_ports {rx_if_*}]
set_output_delay -clock clk_if 2.0 [get_ports {tx_if_*}]

# Reset synchronization
set_false_path -from [get_ports i_rst_*]

# AXI Lite interface constraints (if used)
# Uncomment and adjust if you have AXI lite timing requirements
# set_input_delay -clock clk_if 2.0 [get_ports {axi_lite_if_*}]
# set_output_delay -clock clk_if 2.0 [get_ports {axi_lite_if_*}]

# Multicycle paths (if any long combinational paths exist)
# Example: If there are known multicycle paths in the design
# set_multicycle_path -setup 2 -from [get_cells some_source] -to [get_cells some_dest]

# Physical constraints (placement/routing guidance)
# These can help with timing closure for large designs

# Keep related logic together
# set_property LOC SLICE_X0Y0 [get_cells some_important_cell]

# Pipeline constraints for better timing
# If you have deep pipeline stages, these can help
# set_max_delay 5.0 -from [get_cells pipeline_stage1/*] -to [get_cells pipeline_stage2/*]

# Clock uncertainty (pessimism for safety margin)
set_clock_uncertainty 0.100 [all_clocks]

# Configuration settings for better QoR
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design] 