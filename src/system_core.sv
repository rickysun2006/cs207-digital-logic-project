/*=============================================================================
#
# Project Name   : CS207_Project_Matrix_Calculator
# File Name      : system_core.sv
# Module Name    : system_core
# University     : SUSTech
#
# Create Date    : 2025-11-23
#
# Description    :
#     Logical top module, handles data interaction between all modules, instantiates all modules and connects them via wires.
#
# Revision History:
# -----------------------------------------------------------------------------
# Ver   |   Date     |   Author       |   Description
# -----------------------------------------------------------------------------
# v1.0  | 2025-11-23 |   [Your Name]  |   Initial creation
#
#=============================================================================*/
`include "common/project_pkg.sv"
import project_pkg::*;

module system_core (
    // --- Global Control ---
    input wire clk,   // 系统时钟
    input wire rst_n, // 全局复位

    // --- UART Interface ---
    input  wire uart_rx,  // 输入
    output wire uart_tx,  // 输出

    // --- Logical Inputs ---
    input wire [7:0] sw_mode_sel,     // 模式选择
    input wire [7:0] sw_scalar_val,   // 标量输入
    input wire       btn_confirm,     // 确认
    input wire       btn_reset_logic, // 逻辑复位

    // --- Logical Outputs ---
    output wire [15:0] led_status,  // 16位 LED 状态指示
                                    // [0]: Error Flag

    // --- Display Driver Interface ---
    output wire [7:0] seg_an,      // 数码管位选
    output wire [7:0] seg_data_0,  // 数码管段选 Group 0 (Right)
    output wire [7:0] seg_data_1   // 数码管段选 Group 1 (Left)
);

  //==========================================================================
  // Signal Declarations
  //==========================================================================
  
  // FSM Signals
  sys_state_t current_state;
  op_code_t   operation_code;
  
  // Input Controller Signals
  logic input_done;
  logic gen_done;
  logic calc_input_done;
  logic matrix_valid_flag;
  logic [MAT_ID_W-1:0] selected_id_A;
  logic [MAT_ID_W-1:0] selected_id_B;
  logic [3:0] selected_scalar;
  
  logic ic_wr_en;
  logic ic_wr_cmd_set_dims;
  logic ic_wr_cmd_single;
  logic [ROW_IDX_W-1:0] ic_wr_dims_r;
  logic [COL_IDX_W-1:0] ic_wr_dims_c;
  logic [ROW_IDX_W-1:0] ic_wr_row_idx;
  logic [COL_IDX_W-1:0] ic_wr_col_idx;
  matrix_element_t ic_wr_data;

  // Matrix Storage Signals
  logic ms_wr_en;
  logic ms_wr_cmd_clear;
  logic ms_wr_cmd_set_dims;
  logic ms_wr_cmd_load_all;
  logic ms_wr_cmd_single;
  logic [ROW_IDX_W-1:0] ms_wr_dims_r;
  logic [COL_IDX_W-1:0] ms_wr_dims_c;
  logic [ROW_IDX_W-1:0] ms_wr_row_idx;
  logic [COL_IDX_W-1:0] ms_wr_col_idx;
  matrix_element_t ms_wr_val_scalar;
  logic [MAT_ID_W-1:0] ms_wr_target_id;
  matrix_t ms_wr_val_matrix;
  
  matrix_t ms_rd_data_A;
  logic ms_rd_valid_A;
  matrix_t ms_rd_data_B;
  logic ms_rd_valid_B;

  // ALU Signals
  logic alu_start;
  logic alu_done;
  matrix_t alu_result_matrix;
  logic alu_error_flag;

  // UART Signals
  logic [7:0] rx_byte;
  logic       rx_valid;
  logic       tx_busy;
  logic [7:0] tx_byte;
  logic       tx_en;

  // Display Signals
  code_t [7:0] display_data;
  logic [7:0] blink_mask;

  //==========================================================================
  // Module Instantiation
  //==========================================================================

  main_fsm u_fsm (
      .clk(clk),
      .rst_n(rst_n),
      .sw_mode_sel(sw_mode_sel),
      .btn_confirm(btn_confirm),
      .btn_reset_logic(btn_reset_logic),
      .input_done(input_done),
      .gen_done(gen_done),
      .display_done(1'b0), // Placeholder
      .calc_input_done(calc_input_done),
      .matrix_valid_flag(matrix_valid_flag),
      .alu_done(alu_done),
      .timer_done(1'b0), // Placeholder
      .current_state(current_state),
      .operation_code(operation_code)
  );

  input_controller u_input_ctrl (
      .clk(clk),
      .rst_n(rst_n),
      .start_manual_input(current_state == STATE_INPUT),
      .start_auto_gen(current_state == STATE_GEN),
      .start_select_op(current_state == STATE_CALC_INPUT),
      .op_code(operation_code),
      .uart_valid(rx_valid),
      .uart_data(rx_byte),
      .btn_confirm(btn_confirm),
      .sw_scalar(sw_scalar_val[3:0]),
      .wr_en(ic_wr_en),
      .wr_cmd_set_dims(ic_wr_cmd_set_dims),
      .wr_cmd_single(ic_wr_cmd_single),
      .wr_dims_r(ic_wr_dims_r),
      .wr_dims_c(ic_wr_dims_c),
      .wr_row_idx(ic_wr_row_idx),
      .wr_col_idx(ic_wr_col_idx),
      .wr_data(ic_wr_data),
      .done(input_done), 
      .selected_id_A(selected_id_A),
      .selected_id_B(selected_id_B),
      .selected_scalar(selected_scalar),
      .input_valid_flag(matrix_valid_flag),
      .cfg_rand_min(DEFAULT_VAL_MIN),
      .cfg_rand_max(DEFAULT_VAL_MAX)
  );
  
  // Route input_controller done signal
  assign gen_done = input_done; 
  assign calc_input_done = input_done;

  matrix_manage_sys u_mat_storage (
      .clk(clk),
      .rst_n(rst_n),
      .wr_en(ms_wr_en),
      .wr_id(3'b0), // Unused
      .wr_cmd_clear(ms_wr_cmd_clear),
      .wr_cmd_set_dims(ms_wr_cmd_set_dims),
      .wr_cmd_load_all(ms_wr_cmd_load_all),
      .wr_cmd_single(ms_wr_cmd_single),
      .wr_dims_r(ms_wr_dims_r),
      .wr_dims_c(ms_wr_dims_c),
      .wr_row_idx(ms_wr_row_idx),
      .wr_col_idx(ms_wr_col_idx),
      .wr_val_scalar(ms_wr_val_scalar),
      .wr_target_id(ms_wr_target_id),
      .wr_val_matrix(ms_wr_val_matrix),
      .rd_id_A(selected_id_A),
      .rd_data_A(ms_rd_data_A),
      .rd_valid_A(ms_rd_valid_A),
      .rd_id_B(selected_id_B),
      .rd_data_B(ms_rd_data_B),
      .rd_valid_B(ms_rd_valid_B)
  );

  matrix_alu u_alu (
      .clk(clk),
      .rst_n(rst_n),
      .start(current_state == STATE_CALC_EXEC),
      .op_code(operation_code),
      .matrix_A(ms_rd_data_A),
      .matrix_B(ms_rd_data_B),
      .scalar_val({4'b0, selected_scalar}),
      .done(alu_done),
      .result_matrix(alu_result_matrix),
      .error_flag(alu_error_flag)
  );

  uart_rx u_uart_rx (
      .clk(clk),
      .rst_n(rst_n),
      .uart_rxd(uart_rx),
      .uart_rx_done(rx_valid),
      .uart_rx_data(rx_byte)
  );

  uart_tx u_uart_tx (
      .clk(clk),
      .rst_n(rst_n),
      .uart_tx_en(tx_en),
      .uart_tx_data(tx_byte),
      .uart_txd(uart_tx),
      .uart_tx_busy(tx_busy)
  );
  
  // Placeholder for UART TX
  assign tx_en = 0;
  assign tx_byte = 0;

  seven_seg_display_driver u_seg_driver (
      .clk(clk),
      .rst_n(rst_n),
      .display_data(display_data),
      .blink_mask(blink_mask),
      .an(seg_an),
      .seg0(seg_data_0),
      .seg1(seg_data_1)
  );

  //==========================================================================
  // Logic Glue
  //==========================================================================

  // Write Mux
  always_comb begin
    // Default: Input Controller drives
    ms_wr_en = ic_wr_en;
    ms_wr_cmd_set_dims = ic_wr_cmd_set_dims;
    ms_wr_cmd_single = ic_wr_cmd_single;
    ms_wr_dims_r = ic_wr_dims_r;
    ms_wr_dims_c = ic_wr_dims_c;
    ms_wr_row_idx = ic_wr_row_idx;
    ms_wr_col_idx = ic_wr_col_idx;
    ms_wr_val_scalar = ic_wr_data;
    
    ms_wr_cmd_load_all = 0;
    ms_wr_cmd_clear = 0;
    ms_wr_target_id = 0;
    ms_wr_val_matrix = '0;

    // ALU Write Back
    if (alu_done) begin
        ms_wr_en = 1;
        ms_wr_cmd_load_all = 1;
        ms_wr_target_id = selected_id_A; // Overwrite A with result
        ms_wr_val_matrix = alu_result_matrix;
    end
  end

  // Display Logic (Simple)
  always_comb begin
    blink_mask = 8'hFF;
    case (current_state)
        STATE_IDLE: begin
            // H E L L O - - -
            display_data = {CHAR_H, CHAR_E, CHAR_1, CHAR_1, CHAR_0, CHAR_BLK, CHAR_BLK, CHAR_BLK}; 
        end
        STATE_INPUT: begin
            // In P U t
            display_data = {CHAR_1, CHAR_BLK, CHAR_BLK, CHAR_BLK, CHAR_BLK, CHAR_BLK, CHAR_BLK, CHAR_BLK};
        end
        STATE_CALC_RESULT: begin
            // End
             display_data = {CHAR_E, CHAR_BLK, CHAR_D, CHAR_BLK, CHAR_BLK, CHAR_BLK, CHAR_BLK, CHAR_BLK};
        end
        default: display_data = {CHAR_BLK, CHAR_BLK, CHAR_BLK, CHAR_BLK, CHAR_BLK, CHAR_BLK, CHAR_BLK, CHAR_BLK};
    endcase
  end
  
  assign led_status[0] = alu_error_flag;
  assign led_status[15:1] = '0;

endmodule
