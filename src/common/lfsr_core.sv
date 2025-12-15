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

  // Pipeline Stage 0: Calculate Range (Pre-calculate to break path from inputs)
  reg [8:0] range_len_reg;
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) range_len_reg <= 9'd1;
    else
      range_len_reg <= ($signed(
          cfg_max
      ) >= $signed(
          cfg_min
      )) ? ($signed(
          cfg_max
      ) - $signed(
          cfg_min
      ) + 9'sd1) : 9'd1;
  end

  // Pipeline Stage 1: Calculate Offset using Multiplication
  // Replaces modulo (%) with (val * range) >> 8 for speed
  reg [7:0] offset_reg;
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      offset_reg <= 0;
    end else if (en) begin
      // (lfsr_raw * range_len_reg) / 256
      // Explicitly extend width to 17 bits to prevent truncation before shift
      offset_reg <= (17'(lfsr_raw) * 17'(range_len_reg)) >> 8;
    end
  end

  // Pipeline Stage 2: Final Output
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      rand_val <= 8'd0;
    end else if (en) begin
      rand_val <= cfg_min + offset_reg;
    end
  end

endmodule
