/*=============================================================================
#
# Project Name   : CS207_Project_Matrix_Calculator
# File Name      : matrix_storage_sys.sv
# Module Name    : matrix_storage_sys
# University     : SUSTech
#
# Create Date    : 2025-11-23
#
# Description    :
#     Other modules visit matrix storage through this module.
#
# Revision History:
# -----------------------------------------------------------------------------
# Ver   |   Date     |   Author       |   Description
# -----------------------------------------------------------------------------
# v1.0  | 2025-12-06 | DraTelligence  |   Initial creation
# v1.1  | 2025-12-09 | AI Assistant   |   Removed redundant wr_en/wr_id logic
#
#=============================================================================*/
`include "../common/project_pkg.sv"
import project_pkg::*;

module matrix_manage_sys (
    input wire clk,
    input wire rst_n,

    // --- 写入模式控制 ---
    input wire wr_cmd_clear,     // clear the matrix (valid bit to 0)
    input wire wr_cmd_new,       // create new matrix with given dims
    input wire wr_cmd_load_all,  // load entire matrix_t (from ALU)
    input wire wr_cmd_single,    // write single element

    // --- 数据输入 ---
    // set_dims
    input wire [ROW_IDX_W-1:0] wr_dims_r,
    input wire [COL_IDX_W-1:0] wr_dims_c,

    // single
    input wire             [ROW_IDX_W-1:0] wr_row_idx,
    input wire             [COL_IDX_W-1:0] wr_col_idx,
    input matrix_element_t                 wr_val_scalar,

    // load_all
    input wire     [MAT_ID_W-1:0] wr_target_id,
    input matrix_t                wr_val_matrix,

    // Read Interface
    // Port A and Default
    input  wire     [MAT_ID_W -1 : 0] rd_id_A,
    output matrix_t                   rd_data_A,
    output logic                      rd_valid_A,

    // Port B
    input  wire     [MAT_ID_W -1 : 0] rd_id_B,
    output matrix_t                   rd_data_B,
    output logic                      rd_valid_B

    // TODO: bonus features (dynamic resizing)
    // input wire [2:0] cfg_limit
);

  // Internal Storage Structure
  matrix_t storage[0:MAT_TOTAL_SLOTS-1];

  // dynamic storage limit (future use)
  logic [PTR_W-1:0] active_limit = DEFAULT_LIMIT;
  logic [PTR_W-1:0] ptr_table[0:MAT_SIZE_CNT-1];

  // 记录正在写入的矩阵 ID
  logic [MAT_ID_W-1:0] latched_wr_id;

  // 寻址逻辑 (Combinational)
  logic [4:0] calc_t_idx;
  logic [MAT_ID_W-1:0] calc_base;
  logic [PTR_W-1:0] calc_ptr;
  logic [MAT_ID_W-1:0] calc_target;

  assign calc_t_idx = (wr_dims_r - 1) * MAX_COLS + (wr_dims_c - 1);
  assign calc_base = calc_t_idx * PHYSICAL_MAX_PER_DIM;
  assign calc_ptr = ptr_table[calc_t_idx];
  assign calc_target = calc_base + calc_ptr;

  /*
  // Helper for reading current storage value (Combinational)
  matrix_t current_storage_val;
  always_comb begin
    current_storage_val = '0;
    for (int k = 0; k < MAT_TOTAL_SLOTS; k++) begin
      if (latched_wr_id == k) current_storage_val = storage[k];
    end
  end
  */

  // Write Logic
  integer i;
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      latched_wr_id <= '0;
      active_limit  <= DEFAULT_LIMIT;

      // clear all pointers and storage
      for (i = 0; i < MAT_SIZE_CNT; i++) ptr_table[i] <= 0;
      for (i = 0; i < MAT_TOTAL_SLOTS; i++) storage[i] <= '0;
    end else begin

      // 未来预留的配置接口
      // if (cfg_limit_valid) active_limit <= cfg_limit;

      // --- 清空矩阵 ---
      if (wr_cmd_clear) begin
        storage[wr_target_id] <= '0;
      end  // --- 新建对应维度矩阵 ---
      else if (wr_cmd_new) begin
        matrix_t new_mat;
        latched_wr_id <= calc_target;

        // Update Pointer
        if (calc_ptr + 1 >= active_limit) begin
          ptr_table[calc_t_idx] <= 0;
        end else begin
          ptr_table[calc_t_idx] <= calc_ptr + 1;
        end

        // Write Metadata
        new_mat = '0;
        new_mat.rows = wr_dims_r;
        new_mat.cols = wr_dims_c;
        new_mat.is_valid = 1'b1;
        storage[calc_target] <= new_mat;
      end  // --- 单点写入 ---
      else if (wr_cmd_single) begin
        if (storage[latched_wr_id].is_valid) begin
          storage[latched_wr_id].cells[wr_row_idx][wr_col_idx] <= wr_val_scalar;
        end
      end  // --- 全量写入 ---
      else if (wr_cmd_load_all) begin
        storage[wr_target_id] <= wr_val_matrix;
      end

    end
  end

  // Read Interface
  assign rd_data_A  = storage[rd_id_A];
  assign rd_valid_A = storage[rd_id_A].is_valid;

  assign rd_data_B  = storage[rd_id_B];
  assign rd_valid_B = storage[rd_id_B].is_valid;

endmodule
