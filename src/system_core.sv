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
    input wire clk,   
    input wire rst_n, 

    // --- UART Interface ---
    input  wire uart_rx,  
    output wire uart_tx,  

    // --- User I/O ---
    input wire [7:0] sw_mode_sel,     
    input wire [7:0] sw_scalar_val,   
    input wire       btn_confirm,     
    input wire       btn_reset_logic, 

    // --- Logical Outputs ---
    output wire [15:0] led_status,  
    
    // --- Display Driver Interface ---
    output wire [7:0] seg_an,      
    output wire [7:0] seg_data_0,  
    output wire [7:0] seg_data_1   
);

  //==========================================================================
  // 1. Internal Signals Definition
  //==========================================================================

  wire btn_esc = btn_reset_logic; 

  sys_state_t current_state;
  logic       fsm_safe_reset_btn; 
  
  // Handshake Signals
  logic input_done, gen_done, display_done, calc_sys_done;

  // UART Signals
  logic [7:0] rx_byte;
  logic       rx_valid;
  logic [7:0] tx_byte;
  logic       tx_start, tx_busy;
  logic       sender_done;

  // Storage Signals
  logic [MAT_ID_W-1:0] ms_rd_id_A, ms_rd_id_B;
  matrix_t             ms_rd_data_A, ms_rd_data_B;
  logic                ms_rd_valid_A, ms_rd_valid_B;
  logic                ms_wr_new, ms_wr_single;
  logic [ROW_IDX_W-1:0] ms_wr_dim_r, ms_wr_row;
  logic [COL_IDX_W-1:0] ms_wr_dim_c, ms_wr_col;
  matrix_element_t     ms_wr_data;
  
  logic [7:0]          total_matrix_cnt;
  logic [3:0]          type_valid_cnt [0:MAT_SIZE_CNT-1];

  // --- Sub-Module Interface Signals ---
  
  // Input Module
  logic            inp_err;
  code_t [7:0]     inp_seg_d;
  logic  [7:0]     inp_seg_b;
  // (Input Write Signals reuse local wires defined in controller section)
  logic inp_wr_new, inp_wr_single;
  logic [ROW_IDX_W-1:0] inp_wr_dim_r, inp_wr_row;
  logic [COL_IDX_W-1:0] inp_wr_dim_c, inp_wr_col;
  matrix_element_t inp_wr_data;

  // Gen Module
  code_t [7:0]     gen_seg_d;
  logic  [7:0]     gen_seg_b;
  // (Gen Write & Sender Signals)
  logic gen_wr_new, gen_wr_single;
  logic [ROW_IDX_W-1:0] gen_wr_dim_r, gen_wr_row;
  logic [COL_IDX_W-1:0] gen_wr_dim_c, gen_wr_col;
  matrix_element_t gen_wr_data;
  logic gen_snd_start, gen_snd_last, gen_snd_nl;
  matrix_element_t gen_snd_data;

  // Display Module
  logic [MAT_ID_W-1:0] disp_rd_id;
  code_t [7:0]     disp_seg_d;
  logic  [7:0]     disp_seg_b;
  // (Display Sender Signals)
  logic disp_snd_start, disp_snd_last, disp_snd_nl, disp_snd_id;
  logic disp_snd_head, disp_snd_elem;
  matrix_element_t disp_snd_data;

  // Calc System (Placeholder for future expansion)
  logic calc_snd_start = 0; // Temp tied to 0
  // ...

  // MUX Outputs
  logic            mux_tx_start, mux_tx_last, mux_tx_nl, mux_tx_id;
  logic            mux_tx_head, mux_tx_elem;
  matrix_element_t mux_tx_data;

  logic [7:0]      rand_val;

  // Display Controller Outputs
  code_t [7:0]     seg_mux_data;
  logic  [7:0]     seg_mux_blink;


  //==========================================================================
  // 2. Control & Infrastructure
  //==========================================================================

  assign fsm_safe_reset_btn = (current_state == STATE_INPUT) ? 1'b0 : btn_reset_logic;

  main_fsm u_fsm (
      .clk(clk), .rst_n(rst_n),
      .sw_mode_sel(sw_mode_sel),
      .btn_confirm(btn_confirm),
      .btn_esc(fsm_safe_reset_btn), 
      
      .input_done(input_done),
      .gen_done(gen_done),
      .display_done(display_done),
      .calc_sys_done(calc_sys_done),   

      .current_state(current_state)
  );

  lfsr_core u_lfsr (
      .clk(clk), .rst_n(rst_n), .en(1'b1),
      .cfg_min(DEFAULT_VAL_MIN), .cfg_max(DEFAULT_VAL_MAX),
      .rand_val(rand_val)
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

  matrix_input u_input (
      .clk(clk), .rst_n(rst_n),
      .start_en(current_state == STATE_INPUT),
      .rx_data(rx_byte), .rx_done(rx_valid),
      .btn_exit_input(btn_esc), 
      .err(inp_err),
      // Storage Write
      .wr_cmd_new(inp_wr_new), .wr_cmd_single(inp_wr_single),
      .wr_dims_r(inp_wr_dim_r), .wr_dims_c(inp_wr_dim_c),
      .wr_row_idx(inp_wr_row), .wr_col_idx(inp_wr_col),
      .wr_data(inp_wr_data),
      // Seg
      .seg_data(inp_seg_d), .seg_blink(inp_seg_b),
      .input_done(input_done)
  );

  matrix_gen u_gen (
      .clk(clk), .rst_n(rst_n),
      .start_en(current_state == STATE_GEN),
      .rand_val(rand_val),
      .rx_data(rx_byte), .rx_done(rx_valid),
      // Sender
      .sender_data(gen_snd_data), .sender_start(gen_snd_start),
      .sender_is_last_col(gen_snd_last), .sender_newline_only(gen_snd_nl),
      .sender_done(sender_done),
      // Writer
      .wr_cmd_new(gen_wr_new), .wr_cmd_single(gen_wr_single),
      .wr_dims_r(gen_wr_dim_r), .wr_dims_c(gen_wr_dim_c),
      .wr_row_idx(gen_wr_row), .wr_col_idx(gen_wr_col),
      .wr_data(gen_wr_data),
      // Seg
      .seg_data(gen_seg_d), .seg_blink(gen_seg_b),
      .gen_done(gen_done)
  );

  matrix_display u_display (
      .clk(clk), .rst_n(rst_n),
      .start_en(current_state == STATE_DISPLAY),
      .rx_data(rx_byte), .rx_done(rx_valid),
      .btn_quit(btn_reset_logic), 
      // Storage Read
      .rd_id(disp_rd_id), .rd_data(ms_rd_data_A),
      .total_matrix_cnt(total_matrix_cnt),
      .type_valid_cnt(type_valid_cnt),
      // Sender
      .sender_data(disp_snd_data), .sender_start(disp_snd_start),
      .sender_is_last_col(disp_snd_last), .sender_newline_only(disp_snd_nl),
      .sender_id(disp_snd_id),
      .sender_sum_head(disp_snd_head), .sender_sum_elem(disp_snd_elem),
      .sender_done(sender_done),
      // Seg
      .seg_data(disp_seg_d), .seg_blink(disp_seg_b),
      .display_done(display_done)
  );

  // (matrix_calc_sys 暂未加入)

  //==========================================================================
  // 4. Controllers & Storage
  //==========================================================================

  // --- Input Controller (Write MUX) ---
  input_controller u_input_ctrl (
      .current_state(current_state),
      // Inputs from modules
      .input_wr_cmd_new(inp_wr_new), .input_wr_cmd_single(inp_wr_single),
      .input_wr_dims_r(inp_wr_dim_r), .input_wr_dims_c(inp_wr_dim_c),
      .input_wr_row_idx(inp_wr_row), .input_wr_col_idx(inp_wr_col),
      .input_wr_data(inp_wr_data),
      
      .gen_wr_cmd_new(gen_wr_new), .gen_wr_cmd_single(gen_wr_single),
      .gen_wr_dims_r(gen_wr_dim_r), .gen_wr_dims_c(gen_wr_dim_c),
      .gen_wr_row_idx(gen_wr_row), .gen_wr_col_idx(gen_wr_col),
      .gen_wr_data(gen_wr_data),
      
      // Output to Storage
      .sys_wr_cmd_new(ms_wr_new), .sys_wr_cmd_single(ms_wr_single),
      .sys_wr_dims_r(ms_wr_dim_r), .sys_wr_dims_c(ms_wr_dim_c),
      .sys_wr_row_idx(ms_wr_row), .sys_wr_col_idx(ms_wr_col),
      .sys_wr_val_scalar(ms_wr_data)
  );

  // --- Output Controller (Sender & Read MUX) ---
  output_controller u_output_ctrl (
      .current_state(current_state),
      
      // From Gen
      .gen_sender_start(gen_snd_start), .gen_sender_data(gen_snd_data),
      .gen_sender_last_col(gen_snd_last), .gen_sender_newline(gen_snd_nl),
      
      // From Display
      .disp_sender_start(disp_snd_start), .disp_sender_data(disp_snd_data),
      .disp_sender_last_col(disp_snd_last), .disp_sender_newline(disp_snd_nl),
      .disp_sender_id(disp_snd_id),
      .disp_sender_sum_head(disp_snd_head), .disp_sender_sum_elem(disp_snd_elem),
      .disp_rd_id(disp_rd_id),
      
      // From Calc (Pending)
      .res_sender_start(calc_snd_start),
      
      // ALU Read (Pending)
      .alu_rd_id_A('0), 

      // Mux Outputs
      .mux_sender_start(mux_tx_start), .mux_sender_data(mux_tx_data),
      .mux_sender_last_col(mux_tx_last), .mux_sender_newline(mux_tx_nl),
      .mux_sender_id(mux_tx_id),
      .mux_sender_sum_head(mux_tx_head), .mux_sender_sum_elem(mux_tx_elem),
      .mux_rd_id_A(ms_rd_id_A)
  );

  // --- Matrix Storage ---
  matrix_manage_sys u_mat_storage (
      .clk(clk), .rst_n(rst_n),
      .wr_cmd_clear(1'b0), 
      .wr_cmd_new(ms_wr_new),
      .wr_cmd_load_all(1'b0), 
      .wr_cmd_single(ms_wr_single),
      .wr_dims_r(ms_wr_dim_r), .wr_dims_c(ms_wr_dim_c),
      .wr_row_idx(ms_wr_row), .wr_col_idx(ms_wr_col),
      .wr_val_scalar(ms_wr_data),
      .wr_target_id('0), .wr_val_matrix('0),
      
      .rd_id_A(ms_rd_id_A), .rd_data_A(ms_rd_data_A), .rd_valid_A(ms_rd_valid_A),
      .rd_id_B('0), .rd_data_B(ms_rd_data_B), .rd_valid_B(ms_rd_valid_B),
      
      .total_matrix_cnt(total_matrix_cnt),
      .type_valid_cnt(type_valid_cnt)
  );

  // --- UART Sender ---
  matrix_uart_sender u_uart_sender (
      .clk(clk), .rst_n(rst_n),
      .start(mux_tx_start),
      .data_in(mux_tx_data),
      .is_last_col(mux_tx_last),
      .send_newline(mux_tx_nl),
      .send_id(mux_tx_id),
      .send_summary_head(mux_tx_head),
      .send_summary_elem(mux_tx_elem),
      .sender_done(sender_done),
      
      .tx_data(tx_byte), .tx_start(tx_start), .tx_busy(tx_busy)
  );

  //==========================================================================
  // 5. Status Indicators (Controllers & Drivers)
  //==========================================================================

  // --- LED Controller ---
  led_controller u_led_ctrl (
      .current_state(current_state),
      .inp_err(inp_err),
      .alu_err(1'b0), // Calc err pending
      .ext_led_mask(8'h00), 
      .led_status(led_status)
  );

  // --- Seg Controller ---
  seg_controller u_seg_ctrl (
      .current_state(current_state),
      .sw_mode_sel(sw_mode_sel),
      .total_matrix_cnt(total_matrix_cnt), 
      
      .inp_seg_data(inp_seg_d), .inp_seg_blink(inp_seg_b),
      .gen_seg_data(gen_seg_d), .gen_seg_blink(gen_seg_b),
      .disp_seg_data(disp_seg_d), .disp_seg_blink(disp_seg_b),
      // .calc_seg_data(),
      
      .seg_data_out(seg_display_data),
      .seg_blink_out(blink_mask)
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