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
    input wire wr_cmd_clear,     // 建议作为 Global Clear
    input wire wr_cmd_new,
    input wire wr_cmd_load_all,  // TODO: ALU计算完成后写回
    input wire wr_cmd_single,

    // --- 数据输入 ---
    input wire             [ROW_IDX_W-1:0] wr_dims_r,
    input wire             [COL_IDX_W-1:0] wr_dims_c,
    input wire             [ROW_IDX_W-1:0] wr_row_idx,
    input wire             [COL_IDX_W-1:0] wr_col_idx,
    input matrix_element_t                 wr_val_scalar,
    input wire             [ MAT_ID_W-1:0] wr_target_id,
    input matrix_t                         wr_val_matrix,

    // --- 读接口 ---
    input  wire     [MAT_ID_W -1 : 0] rd_id_A,
    output matrix_t                   rd_data_A,

    input  wire     [MAT_ID_W -1 : 0] rd_id_B,
    output matrix_t                   rd_data_B,

    // --- 统计信息输出 ---
    output reg [MAT_ID_W -1 : 0] total_matrix_cnt,
    output logic [MAT_ID_W -1 : 0] last_wr_id,  // 新增：输出最后写入的 ID
    output reg [3 : 0] type_valid_cnt[0:MAT_SIZE_CNT-1]
);

  // Internal Storage
  (* ram_style = "block" *) matrix_t storage[0:MAT_TOTAL_SLOTS-1];

  // Pointers & Limits
  logic [PTR_W-1:0] active_limit = DEFAULT_LIMIT;
  logic [PTR_W-1:0] ptr_table[0:MAT_SIZE_CNT-1];

  // 书签寄存器
  logic [MAT_ID_W-1:0] latched_wr_id;
  assign last_wr_id = latched_wr_id;

  // 寻址逻辑
  logic [4:0] calc_t_idx;
  logic [MAT_ID_W-1:0] calc_base;
  logic [PTR_W-1:0] calc_ptr;
  logic [MAT_ID_W-1:0] calc_target;

  assign calc_t_idx = (wr_dims_r - 1) * MAX_COLS + (wr_dims_c - 1);
  assign calc_base = calc_t_idx * PHYSICAL_MAX_PER_DIM;
  assign calc_ptr = ptr_table[calc_t_idx];
  assign calc_target = calc_base + calc_ptr;

  // --- Read Logic ---
  always_ff @(posedge clk) begin
    if (!rst_n) begin
      rd_data_A <= '0;
      rd_data_B <= '0;
    end else begin
      // 这里不要加 valid 判断，直接读地址，让综合器更容易识别 BRAM
      rd_data_A <= storage[rd_id_A];
      rd_data_B <= storage[rd_id_B];
    end
  end

  // --- Write Logic ---
  integer i;
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      latched_wr_id <= '0;
      active_limit <= DEFAULT_LIMIT;

      total_matrix_cnt <= 0;
      for (i = 0; i < MAT_SIZE_CNT; i++) begin
        ptr_table[i] <= 0;
        type_valid_cnt[i] <= 0;
      end

    end else begin

      // --- 清空矩阵 (Global Clear) ---
      if (wr_cmd_clear) begin
        total_matrix_cnt <= 0;
        for (i = 0; i < MAT_SIZE_CNT; i++) begin
          ptr_table[i] <= 0;
          type_valid_cnt[i] <= 0;
        end
      end  // --- 新建矩阵 ---
      else if (wr_cmd_new) begin
        matrix_t new_mat;
        latched_wr_id <= calc_target;

        // Update Pointer
        if (calc_ptr + 1 >= active_limit) ptr_table[calc_t_idx] <= 0;
        else ptr_table[calc_t_idx] <= calc_ptr + 1;

        // Write Metadata
        new_mat = '0;
        new_mat.rows = wr_dims_r;
        new_mat.cols = wr_dims_c;
        storage[calc_target] <= new_mat;

        // Update Counters
        if (type_valid_cnt[calc_t_idx] < active_limit) begin
          type_valid_cnt[calc_t_idx] <= type_valid_cnt[calc_t_idx] + 1;
          total_matrix_cnt <= total_matrix_cnt + 1;
        end
      end  // --- 单点写入 ---
      else if (wr_cmd_single) begin
        storage[latched_wr_id].cells[wr_row_idx][wr_col_idx] <= wr_val_scalar;
      end  // --- 全量写入 (Load All) ---
      else if (wr_cmd_load_all) begin
        storage[wr_target_id] <= wr_val_matrix;
      end

    end
  end

endmodule
