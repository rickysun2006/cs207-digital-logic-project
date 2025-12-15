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

    // --- Global Control ---
    input wire wr_cmd_clear,

    // --- Port 1: User Input / Generator Write ---
    input wire             wr_cmd_new,
    input wire             wr_cmd_single,
    input wire             [ROW_IDX_W-1:0] wr_dims_r,
    input wire             [COL_IDX_W-1:0] wr_dims_c,
    input wire             [ROW_IDX_W-1:0] wr_row_idx,
    input wire             [COL_IDX_W-1:0] wr_col_idx,
    input matrix_element_t                 wr_val_scalar,

    // --- Port 2: ALU Write ---
    input wire             alu_wr_en,
    input wire             alu_wr_new,     // Start a new result matrix
    input wire             [ROW_IDX_W-1:0] alu_wr_dims_r,
    input wire             [COL_IDX_W-1:0] alu_wr_dims_c,
    input wire             [ROW_IDX_W-1:0] alu_wr_row_idx,
    input wire             [COL_IDX_W-1:0] alu_wr_col_idx,
    input matrix_element_t                 alu_wr_val,
    output logic           [MAT_ID_W-1:0]  alu_dst_id, // Tell ALU where we are writing

    // --- Read Port A (ALU / Display) ---
    input  wire     [MAT_ID_W -1 : 0] rd_id_A,
    input  wire     [ROW_IDX_W-1 : 0] rd_row_A,
    input  wire     [COL_IDX_W-1 : 0] rd_col_A,
    output matrix_element_t           rd_val_A,
    output logic    [ROW_IDX_W-1 : 0] rd_dims_r_A,
    output logic    [COL_IDX_W-1 : 0] rd_dims_c_A,
    output logic                      rd_valid_A,

    // --- Read Port B (ALU) ---
    input  wire     [MAT_ID_W -1 : 0] rd_id_B,
    input  wire     [ROW_IDX_W-1 : 0] rd_row_B,
    input  wire     [COL_IDX_W-1 : 0] rd_col_B,
    output matrix_element_t           rd_val_B,
    output logic    [ROW_IDX_W-1 : 0] rd_dims_r_B,
    output logic    [COL_IDX_W-1 : 0] rd_dims_c_B,
    output logic                      rd_valid_B,

    // --- Statistics ---
    output reg [MAT_ID_W -1 : 0] total_matrix_cnt,
    output logic [MAT_ID_W -1 : 0] last_wr_id,
    output reg [3 : 0] type_valid_cnt[0:MAT_SIZE_CNT-1]
);

  // =================================================================================
  // 1. Storage Definition (BRAM + Distributed RAM)
  // =================================================================================
  
  // Main Data Storage: 12800 x 8-bit (Inferred as Block RAM)
  (* ram_style = "block" *)
  logic [DATA_WIDTH-1:0] ram [0:MAT_RAM_DEPTH-1];

  // Metadata Storage: Dimensions & Validity (Distributed RAM / Registers)
  logic [ROW_IDX_W-1:0] meta_rows [0:MAT_TOTAL_SLOTS-1];
  logic [COL_IDX_W-1:0] meta_cols [0:MAT_TOTAL_SLOTS-1];
  logic                 meta_valid[0:MAT_TOTAL_SLOTS-1];

  // Allocation Pointers
  logic [PTR_W-1:0] ptr_table[0:MAT_SIZE_CNT-1]; // Points to next free slot for each size
  
  // =================================================================================
  // 2. Address Calculation Helper
  // =================================================================================
  function automatic logic [MAT_RAM_ADDR_W-1:0] get_addr(
      input logic [MAT_ID_W-1:0] id,
      input logic [ROW_IDX_W-1:0] r,
      input logic [COL_IDX_W-1:0] c
  );
      // Addr = ID * 80 + Row * 10 + Col
      return (id * MAT_MAX_ELEMENTS) + (r * MAX_COLS) + c;
  endfunction

  // =================================================================================
  // 3. Write Logic (Arbitration: Input > ALU)
  // =================================================================================
  
  // Internal Write Signals
  logic we;
  logic [MAT_RAM_ADDR_W-1:0] waddr;
  logic [DATA_WIDTH-1:0] wdata;
  
  // Allocation Logic
  logic [4:0] alloc_type_idx;
  logic [MAT_ID_W-1:0] alloc_base_id;
  logic [MAT_ID_W-1:0] alloc_target_id;
  
  // Determine who is writing
  logic src_is_input;
  assign src_is_input = wr_cmd_new || wr_cmd_single;

  // Mux for Allocation Inputs
  logic [ROW_IDX_W-1:0] alloc_dims_r;
  logic [COL_IDX_W-1:0] alloc_dims_c;
  assign alloc_dims_r = src_is_input ? wr_dims_r : alu_wr_dims_r;
  assign alloc_dims_c = src_is_input ? wr_dims_c : alu_wr_dims_c;

  // Calculate Target ID for NEW matrix
  assign alloc_type_idx = (alloc_dims_r - 1) * MAX_COLS + (alloc_dims_c - 1);
  assign alloc_base_id = alloc_type_idx * PHYSICAL_MAX_PER_DIM;
  assign alloc_target_id = alloc_base_id + ptr_table[alloc_type_idx];

  // Current Write ID State
  logic [MAT_ID_W-1:0] current_wr_id;
  assign last_wr_id = current_wr_id;
  assign alu_dst_id = current_wr_id; // Feedback to ALU

  always_ff @(posedge clk or negedge rst_n) begin
      if (!rst_n) begin
          current_wr_id <= '0;
          total_matrix_cnt <= 0;
          for (int i = 0; i < MAT_SIZE_CNT; i++) begin
              ptr_table[i] <= 0;
              type_valid_cnt[i] <= 0;
          end
          // Reset Metadata (Optional, but good for sim)
          for (int i = 0; i < MAT_TOTAL_SLOTS; i++) meta_valid[i] <= 0;
      end else begin
          if (wr_cmd_clear) begin
              total_matrix_cnt <= 0;
              for (int i = 0; i < MAT_SIZE_CNT; i++) begin
                  ptr_table[i] <= 0;
                  type_valid_cnt[i] <= 0;
              end
              for (int i = 0; i < MAT_TOTAL_SLOTS; i++) meta_valid[i] <= 0;
          end else begin
              // --- Handle "New Matrix" Command ---
              if ((src_is_input && wr_cmd_new) || (!src_is_input && alu_wr_new)) begin
                  // Update ID
                  current_wr_id <= alloc_target_id;
                  
                  // Update Metadata
                  meta_rows[alloc_target_id] <= alloc_dims_r;
                  meta_cols[alloc_target_id] <= alloc_dims_c;
                  meta_valid[alloc_target_id] <= 1'b1;

                  // Update Counters
                  if (ptr_table[alloc_type_idx] < PHYSICAL_MAX_PER_DIM - 1) begin
                      ptr_table[alloc_type_idx] <= ptr_table[alloc_type_idx] + 1;
                  end else begin
                      ptr_table[alloc_type_idx] <= 0; // Wrap around (Ring buffer)
                  end
                  
                  // Global stats
                  if (!meta_valid[alloc_target_id]) begin
                      total_matrix_cnt <= total_matrix_cnt + 1;
                      type_valid_cnt[alloc_type_idx] <= type_valid_cnt[alloc_type_idx] + 1;
                  end
              end
          end
      end
  end

  // --- RAM Write Signal Generation ---
  always_comb begin
      we = 0;
      waddr = '0;
      wdata = '0;

      if (src_is_input) begin
          // Input Controller Writing
          if (wr_cmd_single || wr_cmd_new) begin
              we = 1;
              // If new, we write the first element (if provided?) 
              // Usually 'new' comes with data, or just setup. 
              // Assuming 'wr_cmd_single' is used for data.
              // But 'wr_cmd_new' might also carry the first scalar.
              // Let's assume 'wr_cmd_single' is the data carrier.
              // If 'wr_cmd_new' is high, we use the NEW ID.
              // If 'wr_cmd_single' is high (and not new), we use current_wr_id.
              // Actually, input_controller asserts 'new' for the first element.
              waddr = get_addr(wr_cmd_new ? alloc_target_id : current_wr_id, wr_row_idx, wr_col_idx);
              wdata = wr_val_scalar;
          end
      end else if (alu_wr_en) begin
          // ALU Writing
          we = 1;
          waddr = get_addr(alu_wr_new ? alloc_target_id : current_wr_id, alu_wr_row_idx, alu_wr_col_idx);
          wdata = alu_wr_val;
      end
  end

  // --- RAM Write Process ---
  always_ff @(posedge clk) begin
      if (we) begin
          ram[waddr] <= wdata;
      end
  end

  // =================================================================================
  // 4. Read Logic
  // =================================================================================
  
  // Port A
  assign rd_dims_r_A = meta_rows[rd_id_A];
  assign rd_dims_c_A = meta_cols[rd_id_A];
  assign rd_valid_A  = meta_valid[rd_id_A];
  
  logic [MAT_RAM_ADDR_W-1:0] raddr_A;
  assign raddr_A = get_addr(rd_id_A, rd_row_A, rd_col_A);

  always_ff @(posedge clk) begin
      rd_val_A <= ram[raddr_A];
  end

  // Port B
  assign rd_dims_r_B = meta_rows[rd_id_B];
  assign rd_dims_c_B = meta_cols[rd_id_B];
  assign rd_valid_B  = meta_valid[rd_id_B];

  logic [MAT_RAM_ADDR_W-1:0] raddr_B;
  assign raddr_B = get_addr(rd_id_B, rd_row_B, rd_col_B);

  always_ff @(posedge clk) begin
      rd_val_B <= ram[raddr_B];
  end

endmodule

  // Internal Storage
  // Removed (* ram_style = "distributed" *) to allow Block RAM inference
  // and avoid massive LUT usage which slows down synthesis.
  matrix_t storage[0:MAT_TOTAL_SLOTS-1];

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
  // Changed to synchronous read to allow Block RAM inference.
  // This adds 1 cycle latency, but significantly improves synthesis speed and timing.
  always_ff @(posedge clk) begin
    rd_data_A <= storage[rd_id_A];
    rd_data_B <= storage[rd_id_B];
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
