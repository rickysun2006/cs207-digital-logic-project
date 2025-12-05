/*=============================================================================
#
# Project Name   : CS207_Project_Matrix_Calculator
# File Name      : matrix_unit.sv
# Module Name    : matrix_unit
# University     : SUSTech
#
# Create Date    : 2025-11-23
#
# Description    :
#     Stores a single matrix (5x5 max).
#     Supports single element read/write and full matrix load/dump.
#
# Revision History:
# -----------------------------------------------------------------------------
# Ver   |   Date     |   Author       |   Description
# -----------------------------------------------------------------------------
# v1.0  | 2025-11-23 | DraTelligence  |   Initial creation
# v1.1  | 2025-12-03 | GitHub Copilot |   Implemented storage logic
# v1.2  | 2025-12-05 | DraTelligence  |   Adjusted to meet SystemVerilog style
#
#=============================================================================*/
`include "../common/project_pkg.sv"
import project_pkg::*;

module matrix_unit (
    input wire clk,
    input wire rst_n,

    // --- Control Signals ---
    input wire clear,     // Reset matrix data and valid flag
    input wire set_dims,  // Update dimensions and clear data
    input wire load_all,

    // --- set dims only ---
    input wire [ROW_IDX_W-1:0] dims_r,
    input wire [COL_IDX_W-1:0] dims_c,

    // --- Single Element Write ---
    input wire                             we,
    input wire             [ROW_IDX_W-1:0] w_row,
    input wire             [COL_IDX_W-1:0] w_col,
    input matrix_element_t                 w_data,

    // --- Full Matrix Load (from ALU) ---
    input matrix_t matrix_in,

    // --- Single Element Read ---
    input  wire             [ROW_IDX_W-1:0] r_row,
    input  wire             [COL_IDX_W-1:0] r_col,
    output matrix_element_t                 r_data,

    // --- Full Matrix Output ---
    output matrix_t matrix_out
);

  // Internal Storage
  matrix_t stored_matrix;
  assign matrix_out = stored_matrix;

  //==========================================================================
  // Read Logic
  //==========================================================================
  always_comb begin
    r_data = '0;
    if (stored_matrix.is_valid && r_row < stored_matrix.rows && r_col < stored_matrix.cols) begin
      r_data = stored_matrix.cells[r_row][r_col];
    end
  end

  //==========================================================================
  // Write Logic
  //==========================================================================
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      stored_matrix <= '0;
    end else begin
      if (clear) begin
        stored_matrix <= '0;
      end else if (load_all) begin
        stored_matrix <= matrix_in;
      end else begin
        // 1. Set Dimensions
        if (set_dims) begin
          stored_matrix.rows     <= dims_r;
          stored_matrix.cols     <= dims_c;
          stored_matrix.is_valid <= 1'b1;
          stored_matrix.cells    <= '0;
        end

        // 2. Write Single Element
        if (we) begin
          if (stored_matrix.is_valid && w_row < stored_matrix.rows && w_col < stored_matrix.cols) begin
            stored_matrix.cells[w_row][w_col] <= w_data;
          end
        end
      end
    end
  end

endmodule
