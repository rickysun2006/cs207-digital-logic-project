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
`include "../common/project_pkg.sv"
import project_pkg::*;

module lfsr_core (
    input wire clk,
    input wire rst_n,
    input wire en,

    // --- 随机数范围 ---
    input wire [7:0] cfg_min,
    input wire [7:0] cfg_max,

    // --- 输出 ---
    output reg [7:0] rand_val  // 映射后的随机数
);
  reg [7:0] lfsr_raw;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      lfsr_raw <= 8'hFF;
    end else if (en) begin
      lfsr_raw <= {lfsr_raw[6:0], lfsr_raw[7] ^ lfsr_raw[5] ^ lfsr_raw[4] ^ lfsr_raw[3]};
    end
  end

  // rand_val = cfg_min + (lfsr_raw % (cfg_max - cfg_min + 1))

  wire signed [8:0] range_len;
  assign range_len = $signed(cfg_max) - $signed(cfg_min) + 9'sd1;

  wire [7:0] offset;

  assign offset = (range_len > 0) ? (lfsr_raw % unsigned'(range_len)) : 8'd0;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      rand_val <= 8'd0;
    end else if (en) begin
      rand_val <= cfg_min + offset;
    end
  end

endmodule
