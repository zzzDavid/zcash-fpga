source /opt/xilinx/Vitis/2024.2/settings64.sh

# Full synthesis and implementation with bitstream
# vivado -mode tcl -source impl_zcash_fpga_top.tcl

# Synthesis only (faster for iterative development)
# vivado -mode tcl -source impl_zcash_fpga_top.tcl -tclargs --synth_only

# Implementation without bitstream generation
vivado -mode tcl -source impl_zcash_fpga_top.tcl -tclargs --no_bitstream

# Custom part and output directory
# vivado -mode tcl -source impl_zcash_fpga_top.tcl -tclargs --part xc7z020clg484-1 --output_dir ./my_output