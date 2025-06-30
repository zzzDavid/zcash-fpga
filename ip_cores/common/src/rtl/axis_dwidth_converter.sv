/*
  Custom AXI Stream width converter to replace Xilinx IP cores
  Converts from wider to narrower data widths
  
  Copyright (C) 2019  Benjamin Devlin and Zcash Foundation
*/

module axis_dwidth_converter_48_to_8 (
  input  logic        aclk,
  input  logic        aresetn,
  
  // Slave (input) interface - 48 bytes (384 bits)
  input  logic        s_axis_tvalid,
  output logic        s_axis_tready,
  input  logic [383:0] s_axis_tdata,
  input  logic        s_axis_tlast,
  
  // Master (output) interface - 8 bytes (64 bits)  
  output logic        m_axis_tvalid,
  input  logic        m_axis_tready,
  output logic [63:0] m_axis_tdata,
  output logic        m_axis_tlast
);

// Local parameters
localparam int RATIO = 48/8;  // = 6, number of output words per input word
localparam int CNT_BITS = $clog2(RATIO);

// Internal signals
logic [383:0] data_reg;
logic [CNT_BITS-1:0] word_cnt;
logic last_reg;
logic busy;

// Control logic
always_ff @(posedge aclk) begin
  if (!aresetn) begin
    data_reg <= '0;
    word_cnt <= '0;
    last_reg <= 1'b0;
    busy <= 1'b0;
  end else begin
    // Accept new data when not busy and slave is valid
    if (!busy && s_axis_tvalid) begin
      data_reg <= s_axis_tdata;
      last_reg <= s_axis_tlast;
      word_cnt <= '0;
      busy <= 1'b1;
    end
    // Output data when master is ready
    else if (busy && m_axis_tready) begin
      data_reg <= data_reg >> 64;  // Shift out 64 bits
      word_cnt <= word_cnt + 1;
      if (word_cnt == RATIO-1) begin
        busy <= 1'b0;
      end
    end
  end
end

// Output assignments
assign s_axis_tready = !busy;
assign m_axis_tvalid = busy;
assign m_axis_tdata = data_reg[63:0];
assign m_axis_tlast = last_reg && (word_cnt == RATIO-1);

endmodule 