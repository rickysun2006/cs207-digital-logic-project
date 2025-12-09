/*=============================================================================
#
# Project Name   : CS207_Project_Matrix_Calculator
# File Name      : lfsr_core.sv
# Module Name    : lfsr_8bit
# University     : SUSTech
#
# Create Date    : 2025-12-09
#
# Description    :
#     8-bit Linear Feedback Shift Register (LFSR) for pseudo-random number generation.
#
# Revision History:
# -----------------------------------------------------------------------------
# Ver   |   Date     |   Author       |   Description
# -----------------------------------------------------------------------------
# v1.0  | 2025-12-09 | DraTelligence  |   Initial creation
#
#=============================================================================*/

module lfsr_8bit (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       en,     // 使能信号
    output reg  [7:0] dout    // 随机数输出
);

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      dout <= 8'hFF;
    end else if (en) begin
      dout <= {dout[6:0], dout[7] ^ dout[5] ^ dout[4] ^ dout[3]};
    end
  end

endmodule
