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
# v1.0  | 2025-11-23 |  DraTelligence |   Initial creation
# v1.1  | 2025-12-02 |  Ruqi Sun      |   Basicly completed system core with all modules connected
# v1.2  | 2025-12-12 |  DraTelligence |   Reconstructed controllers for better modularity
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

    // --- User I/O ---
    input wire [7:0] sw_mode_sel,     // 模式选择
    input wire [7:0] sw_scalar_val,   // 标量输入
    input wire       btn_confirm,     // 确认
    input wire       btn_reset_logic, // 逻辑复位

    // --- Logical Outputs ---
    output wire [15:0] led_status,  // 16位 LED 状态指示
    
    // --- Display Driver Interface ---
    output wire [7:0] seg_an,      // 数码管位选
    output wire [7:0] seg_data_0,  // 数码管段选 Group 0 (Right)
    output wire [7:0] seg_data_1   // 数码管段选 Group 1 (Left)
);

  //==========================================================================
  // 1. Internal Signals Definition
  //==========================================================================

  // --- FSM Signals ---
  sys_state_t current_state;
  op_code_t   operation_code;
  
  // --- Handshake Signals (Done flags) ---
  logic input_done;
  logic gen_done;
  logic display_done;
  logic alu_done;
  logic res_printer_done; // 结果打印完成
  logic calc_input_done;  // 运算数选择完成 (暂留)
  logic timer_done;       // 错误倒计时完成 (暂留)

  // --- UART Signals ---
  logic [7:0] rx_byte;
  logic       rx_valid;
  logic [7:0] tx_byte;
  logic       tx_start;
  logic       tx_busy;
  logic       sender_done;

  // --- Storage Signals ---
  // Read Ports
  logic [MAT_ID_W-1:0] ms_rd_id_A;
  matrix_t             ms_rd_data_A;
  logic                ms_rd_valid_A;
  logic [MAT_ID_W-1:0] ms_rd_id_B;
  matrix_t             ms_rd_data_B;
  logic                ms_rd_valid_B;
  // Write Ports (From Input Controller)
  logic                ms_wr_new, ms_wr_single;
  logic [ROW_IDX_W-1:0] ms_wr_dim_r, ms_wr_row;
  logic [COL_IDX_W-1:0] ms_wr_dim_c, ms_wr_col;
  matrix_element_t     ms_wr_data;
  // Metadata
  logic [7:0]          total_matrix_cnt;
  logic [3:0]          type_valid_cnt [0:MAT_SIZE_CNT-1];

  // --- Module Interface Signals ---
  
  // 1. Matrix Input
  logic inp_err;
  logic inp_wr_new, inp_wr_single;
  logic [ROW_IDX_W-1:0] inp_wr_dim_r, inp_wr_row;
  logic [COL_IDX_W-1:0] inp_wr_dim_c, inp_wr_col;
  matrix_element_t inp_wr_data;

  // 2. Matrix Gen
  logic gen_wr_new, gen_wr_single;
  logic [ROW_IDX_W-1:0] gen_wr_dim_r, gen_wr_row;
  logic [COL_IDX_W-1:0] gen_wr_dim_c, gen_wr_col;
  matrix_element_t gen_wr_data;
  // Gen Sender
  logic gen_snd_start, gen_snd_last, gen_snd_nl;
  matrix_element_t gen_snd_data;

  // 3. Matrix Display
  logic [MAT_ID_W-1:0] disp_rd_id;
  // Disp Sender
  logic disp_snd_start, disp_snd_last, disp_snd_nl, disp_snd_id;
  logic disp_snd_head, disp_snd_elem;
  matrix_element_t disp_snd_data;

  // 4. Matrix Result Printer (ALU Output)
  logic res_snd_start, res_snd_last, res_snd_nl;
  matrix_element_t res_snd_data;

  // 5. ALU Signals
  matrix_t alu_result;
  logic alu_err;
  logic [MAT_ID_W-1:0] alu_op_id_A = 0; // 暂定: ALU操作数选择逻辑待实现
  logic [MAT_ID_W-1:0] alu_op_id_B = 0;

  // --- MUX Outputs (To Sender) ---
  logic mux_snd_start, mux_snd_last, mux_snd_nl, mux_snd_id;
  logic mux_snd_head, mux_snd_elem;
  matrix_element_t mux_snd_data;

  // --- Random Number ---
  logic [7:0] rand_val_8bit;

  // --- Display / Seg Signals ---
  code_t [7:0] seg_display_data;
  logic  [7:0] blink_mask;


  //==========================================================================
  // 2. Control & Infrastructure Modules
  //==========================================================================

  main_fsm u_fsm (
      .clk(clk),
      .rst_n(rst_n),
      .sw_mode_sel(sw_mode_sel),
      .btn_confirm(btn_confirm),
      .btn_reset_logic(btn_reset_logic),
      .input_done(input_done),
      .gen_done(gen_done),
      .display_done(display_done),
      .calc_input_done(calc_input_done), // 暂未连接
      .matrix_valid_flag(1'b1),          // 暂未连接
      .alu_done(res_printer_done),       // 注意：这里接打印完成信号
      .timer_done(timer_done),           // 暂未连接
      .current_state(current_state),
      .operation_code(operation_code)
  );

  lfsr_core u_lfsr (
      .clk(clk), .rst_n(rst_n), .en(1'b1),
      .cfg_min(DEFAULT_VAL_MIN), .cfg_max(DEFAULT_VAL_MAX),
      .rand_val(rand_val_8bit)
  );

  uart_rx u_uart_rx (
      .clk(clk), .rst_n(rst_n),
      .uart_rxd(uart_rx),
      .uart_rx_done(rx_valid), .uart_rx_data(rx_byte)
  );

  uart_tx u_uart_tx (
      .clk(clk), .rst_n(rst_n),
      .uart_tx_en(tx_start), .uart_tx_data(tx_byte),
      .uart_txd(uart_tx), .uart_tx_busy(tx_busy)
  );

  //==========================================================================
  // 3. Functional Modules
  //==========================================================================

  // --- Matrix Input Module ---
  matrix_input u_input (
      .clk(clk), .rst_n(rst_n),
      .start_en(current_state == STATE_INPUT),
      .rx_data(rx_byte), .rx_done(rx_valid),
      .btn_input_done(btn_confirm), // 复用确认键作为“结束/补零”
      .err(inp_err),
      .wr_cmd_new(inp_wr_new), .wr_cmd_single(inp_wr_single),
      .wr_dims_r(inp_wr_dim_r), .wr_dims_c(inp_wr_dim_c),
      .wr_row_idx(inp_wr_row), .wr_col_idx(inp_wr_col),
      .wr_data(inp_wr_data),
      .input_done(input_done)
  );

  // --- Matrix Gen Module ---
  matrix_gen u_gen (
      .clk(clk), .rst_n(rst_n),
      .start_en(current_state == STATE_GEN),
      .rand_val(rand_val_8bit),
      .rx_data(rx_byte), .rx_done(rx_valid),
      .sender_data(gen_snd_data), .sender_start(gen_snd_start),
      .sender_is_last_col(gen_snd_last), .sender_newline_only(gen_snd_nl),
      .sender_done(sender_done),
      .wr_cmd_new(gen_wr_new), .wr_cmd_single(gen_wr_single),
      .wr_dims_r(gen_wr_dim_r), .wr_dims_c(gen_wr_dim_c),
      .wr_row_idx(gen_wr_row), .wr_col_idx(gen_wr_col),
      .wr_data(gen_wr_data),
      .gen_done(gen_done)
  );

  // --- Matrix Display Module ---
  matrix_display u_display (
      .clk(clk), .rst_n(rst_n),
      .start_en(current_state == STATE_DISPLAY),
      .btn_quit(btn_reset_logic), // 复用复位键退出
      .rx_data(rx_byte), .rx_done(rx_valid),
      .rd_id(disp_rd_id), .rd_data(ms_rd_data_A),
      .total_matrix_cnt(total_matrix_cnt),
      .type_valid_cnt(type_valid_cnt),
      .sender_data(disp_snd_data), .sender_start(disp_snd_start),
      .sender_is_last_col(disp_snd_last), .sender_newline_only(disp_snd_nl),
      .sender_id(disp_snd_id),
      .sender_sum_head(disp_snd_head), .sender_sum_elem(disp_snd_elem),
      .sender_done(sender_done),
      .display_done(display_done)
  );

  // --- Matrix ALU ---
  matrix_alu u_alu (
      .clk(clk), .rst_n(rst_n),
      .start(current_state == STATE_CALC_EXEC),
      .op_code(operation_code),
      .matrix_A(ms_rd_data_A),
      .matrix_B(ms_rd_data_B),
      .scalar_val({4'b0, sw_scalar_val[3:0]}), // 临时取开关低4位
      .done(alu_done),
      .result_matrix(alu_result),
      .error_flag(alu_err)
  );

  // --- Result Printer (ALU Output) ---
  matrix_result_printer u_res_printer (
      .clk(clk), .rst_n(rst_n),
      .start(alu_done), // ALU 计算完自动开始打印
      .result_matrix(alu_result),
      .sender_data(res_snd_data), .sender_start(res_snd_start),
      .sender_is_last_col(res_snd_last), .sender_newline_only(res_snd_nl),
      .sender_done(sender_done),
      .printer_done(res_printer_done)
  );

  //==========================================================================
  // 4. Controllers & Storage
  //==========================================================================

  // --- Input Controller (Write MUX) ---
  input_controller u_input_ctrl (
      .current_state(current_state),
      // Input
      .input_wr_cmd_new(inp_wr_new), .input_wr_cmd_single(inp_wr_single),
      .input_wr_dims_r(inp_wr_dim_r), .input_wr_dims_c(inp_wr_dim_c),
      .input_wr_row_idx(inp_wr_row), .input_wr_col_idx(inp_wr_col),
      .input_wr_data(inp_wr_data),
      // Gen
      .gen_wr_cmd_new(gen_wr_new), .gen_wr_cmd_single(gen_wr_single),
      .gen_wr_dims_r(gen_wr_dim_r), .gen_wr_dims_c(gen_wr_dim_c),
      .gen_wr_row_idx(gen_wr_row), .gen_wr_col_idx(gen_wr_col),
      .gen_wr_data(gen_wr_data),
      // Output to Sys
      .sys_wr_cmd_new(ms_wr_cmd_new), .sys_wr_cmd_single(ms_wr_cmd_single),
      .sys_wr_dims_r(ms_wr_dims_r), .sys_wr_dims_c(ms_wr_dims_c),
      .sys_wr_row_idx(ms_wr_row_idx), .sys_wr_col_idx(ms_wr_col_idx),
      .sys_wr_val_scalar(ms_wr_val_scalar)
  );

  // --- Output Controller (Sender & Read MUX) ---
  output_controller u_output_ctrl (
      .current_state(current_state),
      // Gen
      .gen_sender_start(gen_snd_start), .gen_sender_data(gen_snd_data),
      .gen_sender_last_col(gen_snd_last), .gen_sender_newline(gen_snd_nl),
      // Display
      .disp_sender_start(disp_snd_start), .disp_sender_data(disp_snd_data),
      .disp_sender_last_col(disp_snd_last), .disp_sender_newline(disp_snd_nl),
      .disp_sender_id(disp_snd_id),
      .disp_sender_sum_head(disp_snd_head), .disp_sender_sum_elem(disp_snd_elem),
      .disp_rd_id(disp_rd_id),
      // Result
      .res_sender_start(res_snd_start), .res_sender_data(res_snd_data),
      .res_sender_last_col(res_snd_last), .res_sender_newline(res_snd_nl),
      // ALU Select (Default Read)
      .alu_rd_id_A(alu_op_id_A),

      // Mux Outputs
      .mux_sender_start(mux_snd_start), .mux_sender_data(mux_snd_data),
      .mux_sender_last_col(mux_snd_last), .mux_sender_newline(mux_snd_nl),
      .mux_sender_id(mux_snd_id),
      .mux_sender_sum_head(mux_snd_head), .mux_sender_sum_elem(mux_snd_elem),
      .mux_rd_id_A(ms_rd_id_A)
  );

  // --- Matrix Storage System ---
  matrix_manage_sys u_mat_storage (
      .clk(clk), .rst_n(rst_n),
      .wr_cmd_clear(1'b0), // TODO: 接到某个按键（如长按复位）
      .wr_cmd_new(ms_wr_cmd_new),
      .wr_cmd_load_all(1'b0), 
      .wr_cmd_single(ms_wr_cmd_single),
      .wr_dims_r(ms_wr_dims_r), .wr_dims_c(ms_wr_dims_c),
      .wr_row_idx(ms_wr_row_idx), .wr_col_idx(ms_wr_col_idx),
      .wr_val_scalar(ms_wr_val_scalar),
      .wr_target_id('0), .wr_val_matrix('0),
      
      .rd_id_A(ms_rd_id_A), .rd_data_A(ms_rd_data_A), .rd_valid_A(ms_rd_valid_A),
      .rd_id_B(alu_op_id_B), .rd_data_B(ms_rd_data_B), .rd_valid_B(ms_rd_valid_B),
      
      .total_matrix_cnt(total_matrix_cnt),
      .type_valid_cnt(type_valid_cnt)
  );

  // --- Shared Matrix UART Sender ---
  matrix_uart_sender u_uart_sender (
      .clk(clk), .rst_n(rst_n),
      .start(mux_snd_start),
      .data_in(mux_snd_data),
      .is_last_col(mux_snd_last),
      .send_newline(mux_snd_nl),
      .send_id(mux_snd_id),
      .send_summary_head(mux_snd_head),
      .send_summary_elem(mux_snd_elem),
      .sender_done(sender_done),
      
      .tx_data(tx_byte), .tx_start(tx_start), .tx_busy(tx_busy)
  );

  //==========================================================================
  // 5. Status Controllers
  //==========================================================================

  // --- LED Controller ---
  led_controller u_led_ctrl (
      .current_state(current_state),
      .inp_err(inp_err),
      .alu_err(alu_err),
      .ext_led_mask(8'h00), // 暂未用，接0
      .led_status(led_status)
  );

  // --- Seg Controller ---
  seg_controller u_seg_ctrl (
      .current_state(current_state),
      .sw_mode_sel(sw_mode_sel),
      .total_matrix_cnt(total_matrix_cnt),
      .seg_display_data(seg_display_data),
      .blink_mask(blink_mask)
  );

  // --- Seven Seg Driver ---
  seven_seg_display_driver u_seg_driver (
      .clk(clk), .rst_n(rst_n),
      .display_data(seg_display_data),
      .blink_mask(blink_mask),
      .an(seg_an),
      .seg0(seg_data_0),
      .seg1(seg_data_1)
  );

endmodule