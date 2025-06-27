# Zcash FPGA Top Level Synthesis Guide

This directory contains TCL scripts to synthesize the `zcash_fpga_top` design with Vivado.

## Files

- `create_zcash_fpga_top_project.tcl` - Full project creation and synthesis
- `synth_zcash_fpga_top.tcl` - Non-project mode synthesis (faster)
- `zcash_fpga_top_basic.xdc` - Basic timing constraints template

## Prerequisites

1. Vivado 2018.3 or later installed
2. All source files from the zcash-fpga repository
3. Set up environment (optional - scripts can auto-detect)

## Usage

### Option 1: Full Project Mode (Recommended for development)

Creates a complete Vivado project with all source files, constraints, and testbenches.

```bash
# Basic usage (creates project only)
vivado -mode tcl -source create_zcash_fpga_top_project.tcl

# Create project and run synthesis
vivado -mode tcl -source create_zcash_fpga_top_project.tcl -tclargs --run_synth

# Specify custom FPGA part
vivado -mode tcl -source create_zcash_fpga_top_project.tcl -tclargs --part xcvu37p-fsvh2892-2L-e

# Custom project location
vivado -mode tcl -source create_zcash_fpga_top_project.tcl -tclargs --project_dir /path/to/project

# All options
vivado -mode tcl -source create_zcash_fpga_top_project.tcl -tclargs \
  --project_name my_zcash_project \
  --project_dir /path/to/project \
  --part xcvu9p-flga2104-2L-e \
  --run_synth
```

### Option 2: Non-Project Mode (Faster for synthesis-only)

Runs synthesis directly without creating a project. Faster turnaround for synthesis experiments.

```bash
# Basic synthesis
vivado -mode tcl -source synth_zcash_fpga_top.tcl

# Specify FPGA part and output directory
vivado -mode tcl -source synth_zcash_fpga_top.tcl -tclargs \
  --part xcvu37p-fsvh2892-2L-e \
  --output_dir ./my_synth_results
```

### Option 3: GUI Mode

After creating the project, you can open it in Vivado GUI:

```bash
# After running create_zcash_fpga_top_project.tcl
vivado vivado_project/zcash_fpga_top.xpr
```

## FPGA Part Numbers

Common FPGA parts you might use:

- **AWS F1**: `xcvu9p-flga2104-2L-e` (default)
- **Bittware VVH**: `xcvu37p-fsvh2892-2L-e`
- **Xilinx VCU118**: `xcvu9p-flga2104-2L-e`
- **Xilinx VCU128**: `xcvu37p-fsvh2892-2L-e`

## Output Files

### Project Mode
- `vivado_project/` - Complete Vivado project
- `vivado_project/zcash_fpga_top.xpr` - Project file
- `vivado_project/*.rpt` - Synthesis reports (if synthesis was run)

### Non-Project Mode
- `synth_output/zcash_fpga_top_synth.dcp` - Synthesis checkpoint
- `synth_output/zcash_fpga_top_netlist.v` - Synthesized netlist
- `synth_output/zcash_fpga_top_constraints.xdc` - Applied constraints
- `synth_output/*.rpt` - Synthesis reports

## Design Configuration

The design includes these configurable components (via `zcash_fpga_pkg.sv`):

- **secp256k1 Signature Verification** (enabled by default)
- **Equihash Verification** (disabled by default)  
- **BLS12-381 Coprocessor** (disabled by default)

To enable/disable components, edit `zcash_fpga/src/rtl/top/zcash_fpga_pkg.sv`:

```systemverilog
parameter bit ENB_VERIFY_SECP256K1_SIG = 1;  // Enable secp256k1
parameter bit ENB_VERIFY_EQUIHASH = 0;       // Disable Equihash
parameter bit ENB_BLS12_381 = 0;             // Disable BLS12-381
```

## Timing Constraints

The script looks for constraint files in this order:
1. `zcash_fpga/src/constrs/zcash_fpga_top.xdc`
2. `constrs/zcash_fpga_top.xdc`
3. `zcash_fpga_top_basic.xdc` (provided template)

Edit `zcash_fpga_top_basic.xdc` to adjust clock frequencies and timing constraints for your target system.

## Synthesis Settings

The scripts use these synthesis settings for better QoR:
- Out-of-context synthesis mode
- 8 parallel jobs (when using project mode)
- SystemVerilog file type recognition
- Proper clock domain crossing handling

## Troubleshooting

### Common Issues

1. **File not found errors**: Ensure you're running from the zcash-fpga root directory
2. **Part not found**: Check that your Vivado version supports the target FPGA part
3. **Synthesis failures**: Check the `.log` files in the output directory
4. **Memory issues**: Large designs may need more RAM - close other applications

### Environment Variables

- `ZCASH_DIR`: Points to zcash-fpga root (auto-detected if not set)

### Debug Options

Add these lines to the TCL scripts for more verbose output:
```tcl
set_msg_config -id {*} -limit 0
set_msg_config -suppress false
```

## Next Steps

After successful synthesis:

1. **Analyze Reports**: Check utilization and timing reports
2. **Implementation**: Run place & route (implementation)
3. **Bitstream Generation**: Generate programming files
4. **Hardware Testing**: Test on actual FPGA hardware

For implementation, you can use Vivado GUI or create additional TCL scripts following the same pattern. 