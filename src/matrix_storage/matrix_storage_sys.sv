/*=============================================================================
#
# Project Name   : CS207_Project_Matrix_Calculator
# File Name      : matrix_storage_sys.sv
# Module Name    : matrix_manage_sys
# University     : SUSTech
#
# Create Date    : 2025-11-23
#
# Description    :
#     Scalar RAM based Matrix Storage System.
#     Replaces the register-based storage to fix synthesis resource explosion.
#
# Revision History:
# -----------------------------------------------------------------------------
# Ver   |   Date     |   Author       |   Description
# -----------------------------------------------------------------------------
# v2.0  | 2025-12-15 | GitHub Copilot |   Refactored to Scalar RAM Architecture
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
    input  wire [MAT_ID_W-1:0] rd_id_A,
    input  wire [ROW_IDX_W-1:0] rd_row_A,
    input  wire [COL_IDX_W-1:0] rd_col_A,
    output matrix_element_t     rd_val_A,
    output logic [ROW_IDX_W-1:0] rd_dims_r_A,
    output logic [COL_IDX_W-1:0] rd_dims_c_A,
    output logic                 rd_valid_A,

    // --- Read Port B (ALU) ---
    input  wire [MAT_ID_W-1:0] rd_id_B,
    input  wire [ROW_IDX_W-1:0] rd_row_B,
    input  wire [COL_IDX_W-1:0] rd_col_B,
    output matrix_element_t     rd_val_B,
    output logic [ROW_IDX_W-1:0] rd_dims_r_B,
    output logic [COL_IDX_W-1:0] rd_dims_c_B,
    output logic                 rd_valid_B,

    // --- Metadata Output ---
    output logic [MAT_ID_W-1:0] total_matrix_cnt,
    output logic [MAT_ID_W-1:0] last_wr_id,
    output logic [3:0]          type_valid_cnt[0:MAT_SIZE_CNT-1]
);

  //==========================================================================
  // 1. Storage Definition
  //==========================================================================
  
  // Main RAM: Stores all elements linearly
  // Size: MAT_MAX_ELEMENTS (e.g. 64) * MAT_TOTAL_SLOTS (e.g. 32)
  // We use a flat address space: Address = (ID * MAX_ELEMENTS) + (Row * MAX_COLS) + Col
  (* ram_style = "block" *)
  logic [7:0] ram [0 : MAT_TOTAL_SLOTS * MAT_MAX_ELEMENTS - 1];

  // Metadata Storage (Small, can be registers)
  typedef struct packed {
    logic valid;
    logic [ROW_IDX_W-1:0] dims_r;
    logic [COL_IDX_W-1:0] dims_c;
  } mat_meta_t;

  mat_meta_t meta [0:MAT_TOTAL_SLOTS-1];

  //==========================================================================
  // 2. Internal Signals & Helper Functions
  //==========================================================================

  // Head ID Pointer
  logic [MAT_ID_W-1:0] head_id;

  // Address Calculation Function
  function automatic logic [15:0] get_addr(
    input logic [MAT_ID_W-1:0] id,
    input logic [ROW_IDX_W-1:0] r,
    input logic [COL_IDX_W-1:0] c
  );
    // Addr = ID * 64 + Row * 8 + Col
    // Assuming MAX_ELEMENTS = 64 (6 bits), MAX_COLS = 8 (3 bits)
    return {id, r[2:0], c[2:0]}; 
  endfunction

  //==========================================================================
  // 3. Write Logic
  //==========================================================================

  // --- Head ID Management ---
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      head_id <= 0;
      last_wr_id <= 0;
    end else if (wr_cmd_clear) begin
      head_id <= 0;
      last_wr_id <= 0;
    end else if (wr_cmd_new) begin
      head_id <= head_id + 1;
      last_wr_id <= head_id + 1;
    end else if (alu_wr_new) begin
      head_id <= head_id + 1;
      // ALU writes don't necessarily update last_wr_id for Input module, 
      // but for consistency we can update it or leave it.
      // Let's update it so Display knows there's a new matrix.
      last_wr_id <= head_id + 1; 
    end
  end
  
  assign alu_dst_id = head_id; 

  // --- Metadata Write ---
  always_ff @(posedge clk) begin
    if (wr_cmd_new) begin
       meta[head_id + 1].valid <= 1'b1;
       meta[head_id + 1].dims_r <= wr_dims_r;
       meta[head_id + 1].dims_c <= wr_dims_c;
    end else if (alu_wr_new) begin
       meta[head_id + 1].valid <= 1'b1;
       meta[head_id + 1].dims_r <= alu_wr_dims_r;
       meta[head_id + 1].dims_c <= alu_wr_dims_c;
    end
  end

  // --- RAM Write MUX ---
  logic ram_wr_en;
  logic [15:0] ram_addr;
  logic [7:0] ram_wdata;
  
  logic [15:0] waddr_p1, waddr_p2;
  assign waddr_p1 = get_addr(head_id, wr_row_idx, wr_col_idx);
  assign waddr_p2 = get_addr(head_id, alu_wr_row_idx, alu_wr_col_idx);

  assign ram_wr_en = wr_cmd_single | alu_wr_en;
  assign ram_addr  = (alu_wr_en) ? waddr_p2 : waddr_p1;
  assign ram_wdata = (alu_wr_en) ? alu_wr_val : wr_val_scalar;
  
  always_ff @(posedge clk) begin
    if (ram_wr_en) begin
      ram[ram_addr] <= ram_wdata;
    end
  end

  //==========================================================================
  // 4. Read Logic
  //==========================================================================

  // --- Port A ---
  assign rd_dims_r_A = meta[rd_id_A].dims_r;
  assign rd_dims_c_A = meta[rd_id_A].dims_c;
  assign rd_valid_A  = meta[rd_id_A].valid;

  logic [15:0] raddr_A;
  assign raddr_A = get_addr(rd_id_A, rd_row_A, rd_col_A);

  always_ff @(posedge clk) begin
      rd_val_A <= ram[raddr_A];
  end

  // --- Port B ---
  assign rd_dims_r_B = meta[rd_id_B].dims_r;
  assign rd_dims_c_B = meta[rd_id_B].dims_c;
  assign rd_valid_B  = meta[rd_id_B].valid;

  logic [15:0] raddr_B;
  assign raddr_B = get_addr(rd_id_B, rd_row_B, rd_col_B);

  always_ff @(posedge clk) begin
      rd_val_B <= ram[raddr_B];
  end
  
  // --- Misc Outputs ---
  assign total_matrix_cnt = head_id; 
  
  always_comb begin
    for(int i=0; i<MAT_SIZE_CNT; i++) type_valid_cnt[i] = 0;
  end

endmodule
