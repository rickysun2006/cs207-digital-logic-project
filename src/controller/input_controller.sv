/*=============================================================================
#
# Project Name   : CS207_Project_Matrix_Calculator
# File Name      : input_controller.sv
# Module Name    : input_controller
# University     : SUSTech
#
# Create Date    : 2025-12-02
#
# Description    :
#     Module to control input data flow from modules to memory system
#
# Revision History:
# -----------------------------------------------------------------------------
# Ver   |   Date     |   Author       |   Description
# -----------------------------------------------------------------------------
# v1.0  | 2025-12-06 | DraTelligence  |   Initial creation
# v1.1  | 2025-12-09 | DraTelligence  |   reconstructed for better modularity
#
#=============================================================================*/
`include "../common/project_pkg.sv"
import project_pkg::*;

module input_controller (
    input sys_state_t current_state,

    // --- Source 1: From Matrix Input Module ---
    input wire                             input_wr_cmd_new,
    input wire                             input_wr_cmd_single,
    input wire             [ROW_IDX_W-1:0] input_wr_dims_r,
    input wire             [COL_IDX_W-1:0] input_wr_dims_c,
    input wire             [ROW_IDX_W-1:0] input_wr_row_idx,
    input wire             [COL_IDX_W-1:0] input_wr_col_idx,
    input matrix_element_t                 input_wr_data,

    // --- Source 2: From Matrix Gen Module ---
    input wire                             gen_wr_cmd_new,
    input wire                             gen_wr_cmd_single,
    input wire             [ROW_IDX_W-1:0] gen_wr_dims_r,
    input wire             [COL_IDX_W-1:0] gen_wr_dims_c,
    input wire             [ROW_IDX_W-1:0] gen_wr_row_idx,
    input wire             [COL_IDX_W-1:0] gen_wr_col_idx,
    input matrix_element_t                 gen_wr_data,

    // --- Destination: To Matrix Manage Sys ---
    output reg                              sys_wr_cmd_new,
    output reg                              sys_wr_cmd_single,
    output reg              [ROW_IDX_W-1:0] sys_wr_dims_r,
    output reg              [COL_IDX_W-1:0] sys_wr_dims_c,
    output reg              [ROW_IDX_W-1:0] sys_wr_row_idx,
    output reg              [COL_IDX_W-1:0] sys_wr_col_idx,
    output matrix_element_t                 sys_wr_val_scalar
);

  always_comb begin
    sys_wr_cmd_new    = 1'b0;
    sys_wr_cmd_single = 1'b0;
    sys_wr_dims_r     = '0;
    sys_wr_dims_c     = '0;
    sys_wr_row_idx    = '0;
    sys_wr_col_idx    = '0;
    sys_wr_val_scalar = '0;

    case (current_state)
      STATE_INPUT: begin
        sys_wr_cmd_new    = input_wr_cmd_new;
        sys_wr_cmd_single = input_wr_cmd_single;
        sys_wr_dims_r     = input_wr_dims_r;
        sys_wr_dims_c     = input_wr_dims_c;
        sys_wr_row_idx    = input_wr_row_idx;
        sys_wr_col_idx    = input_wr_col_idx;
        sys_wr_val_scalar = input_wr_data;
      end

      STATE_GEN: begin
        sys_wr_cmd_new    = gen_wr_cmd_new;
        sys_wr_cmd_single = gen_wr_cmd_single;
        sys_wr_dims_r     = gen_wr_dims_r;
        sys_wr_dims_c     = gen_wr_dims_c;
        sys_wr_row_idx    = gen_wr_row_idx;
        sys_wr_col_idx    = gen_wr_col_idx;
        sys_wr_val_scalar = gen_wr_data;
      end

      default: ;
    endcase
  end

endmodule
