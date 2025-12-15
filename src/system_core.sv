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
# v1.3  | 2025-12-15 |  GitHub Copilot|   Refactored for Scalar RAM Architecture
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
    input wire [7:0] sw_mode_sel,     // 模式选择 / 运算类型选择
    input wire [7:0] sw_scalar_val,
    input wire       btn_confirm,     // 确认
    input wire       btn_reset_logic, // 逻辑复位 / 返回 / 结束输入(Esc)

    // --- Logical Outputs ---
    output wire [15:0] led_status,  // 16? LED 状?指?

    // --- Display Driver Interface ---
    output wire [7:0] seg_an,      // 数码管位?
    output wire [7:0] seg_data_0,  // 数码管段? Group 0 (Right)
    output wire [7:0] seg_data_1   // 数码管段? Group 1 (Left)
);

  //==========================================================================
  // 1. Internal Signals Definition
  //==========================================================================

  // --- Wire Aliases ---
  wire              btn_esc = btn_reset_logic;

  // --- FSM Signals ---
  sys_state_t       current_state;
  logic             fsm_safe_reset_btn;

  // --- Handshake Signals (Done flags) ---
  logic             input_done;
  logic             gen_done;
  logic             display_done;
  logic             calc_sys_done;  // 计算子系统整体完?

  // --- UART Signals ---
  logic       [7:0] rx_byte;
  logic             rx_valid;
  logic       [7:0] tx_byte;
  logic tx_start, tx_busy;
  logic sender_done;

  // --- Storage Interconnect (Scalar) ---
  // Write Ports (From Input Controller -> Storage)
  logic ms_wr_new, ms_wr_single;
  logic [ROW_IDX_W-1:0] ms_wr_dims_r, ms_wr_row;
  logic [COL_IDX_W-1:0] ms_wr_dims_c, ms_wr_col;
  matrix_element_t ms_wr_data;

  // Read Port A (Shared: ALU Port A / Display)
  logic [MAT_ID_W-1:0] ms_rd_id_A;
  logic [ROW_IDX_W-1:0] ms_rd_row_A;
  logic [COL_IDX_W-1:0] ms_rd_col_A;
  matrix_element_t     ms_rd_val_A;
  logic [ROW_IDX_W-1:0] ms_rd_dims_r_A;
  logic [COL_IDX_W-1:0] ms_rd_dims_c_A;
  logic                 ms_rd_valid_A;

  // Read Port B (ALU Port B)
  logic [MAT_ID_W-1:0] ms_rd_id_B; // From Calc Sys
  logic [ROW_IDX_W-1:0] ms_rd_row_B;
  logic [COL_IDX_W-1:0] ms_rd_col_B;
  matrix_element_t     ms_rd_val_B;
  logic [ROW_IDX_W-1:0] ms_rd_dims_r_B;
  logic [COL_IDX_W-1:0] ms_rd_dims_c_B;
  logic                 ms_rd_valid_B;

  // ALU Write Port
  logic alu_wr_en;
  logic alu_wr_new;
  logic [ROW_IDX_W-1:0] alu_wr_dims_r;
  logic [COL_IDX_W-1:0] alu_wr_dims_c;
  logic [ROW_IDX_W-1:0] alu_wr_row;
  logic [COL_IDX_W-1:0] alu_wr_col;
  matrix_element_t      alu_wr_val;
  logic [MAT_ID_W-1:0]  alu_dst_id;

  // Metadata (Storage -> Display)
  logic [MAT_ID_W-1:0] total_matrix_cnt;
  logic [MAT_ID_W-1:0] ms_last_wr_id;  // Storage -> Input
  logic [3:0] type_valid_cnt[0:MAT_SIZE_CNT-1];

  // --- Functional Module Signals ---

  // 1. Matrix Input
  logic inp_err;
  logic inp_wr_new, inp_wr_single;
  logic [ROW_IDX_W-1:0] inp_wr_dim_r, inp_wr_row;
  logic [COL_IDX_W-1:0] inp_wr_dim_c, inp_wr_col;
  matrix_element_t inp_wr_data;
  
  logic inp_snd_start, inp_snd_last, inp_snd_nl, inp_snd_id;
  matrix_element_t inp_snd_data;
  logic [MAT_ID_W-1:0] inp_rd_id;
  code_t [7:0] inp_seg_d;
  logic [7:0] inp_seg_b;

  // 2. Matrix Gen
  logic gen_wr_new, gen_wr_single;
  logic [ROW_IDX_W-1:0] gen_wr_dim_r, gen_wr_row;
  logic [COL_IDX_W-1:0] gen_wr_dim_c, gen_wr_col;
  matrix_element_t gen_wr_data;

  logic gen_snd_start, gen_snd_last, gen_snd_nl;
  matrix_element_t gen_snd_data;
  code_t [7:0] gen_seg_d;
  logic [7:0] gen_seg_b;

  // 3. Matrix Display
  logic disp_ext_en, disp_ext_done;
  logic [1:0] disp_ext_cmd;
  logic [ROW_IDX_W-1:0] disp_ext_m;
  logic [COL_IDX_W-1:0] disp_ext_n;
  
  logic [MAT_ID_W-1:0] disp_rd_id;
  logic [ROW_IDX_W-1:0] disp_rd_row;
  logic [COL_IDX_W-1:0] disp_rd_col;

  logic disp_snd_start, disp_snd_last, disp_snd_nl, disp_snd_id, disp_snd_head, disp_snd_elem;
  matrix_element_t disp_snd_data;
  code_t [7:0] disp_seg_d;
  logic [7:0] disp_seg_b;

  // 4. Matrix Calc Sys
  logic sys_calc_start_alu;
  op_code_t sys_calc_op;
  logic [MAT_ID_W-1:0] sys_calc_id_A;
  logic [MAT_ID_W-1:0] sys_calc_id_B;
  matrix_element_t sys_calc_scalar_val;
  logic sys_calc_print_start;
  logic sys_calc_err;
  code_t [7:0] calc_seg_d;
  logic [7:0] calc_seg_b;

  // 5. ALU
  logic alu_calc_done;
  logic alu_err_flag;
  logic [31:0] alu_cycle_cnt;
  logic [ROW_IDX_W-1:0] alu_rd_row_A, alu_rd_row_B;
  logic [COL_IDX_W-1:0] alu_rd_col_A, alu_rd_col_B;

  // 6. Result Printer (Disabled/Bypassed)
  logic res_printer_done;
  logic res_snd_start, res_snd_last, res_snd_nl;
  matrix_element_t res_snd_data;

  // --- MUX Signals (Output Controller) ---
  logic mux_tx_start, mux_tx_last, mux_tx_nl, mux_tx_id, mux_tx_head, mux_tx_elem;
  matrix_element_t mux_tx_data;
  logic [MAT_ID_W-1:0] mux_rd_id_A_from_ctrl; // Only ID is muxed by ctrl

  //==========================================================================
  // 2. Main FSM
  //==========================================================================
  main_fsm u_fsm (
      .clk(clk),
      .rst_n(rst_n),
      .sw_mode_sel(sw_mode_sel),
      .btn_confirm(btn_confirm),
      //.btn_reset(btn_reset_logic), // Removed in v1.1
      .input_done(input_done),
      .gen_done(gen_done),
      .display_done(display_done),
      .calc_done(calc_sys_done),
      .current_state(current_state)
      //.safe_reset_btn(fsm_safe_reset_btn) // Removed
  );

  //==========================================================================
  // 3. Functional Modules
  //==========================================================================

  // --- UART RX ---
  uart_rx #(
      .CLK_FREQ(SYS_CLK_FREQ),
      .UART_BPS(BAUD_RATE)
  ) u_uart_rx (
      .clk(clk),
      .rst_n(rst_n),
      .uart_rxd(uart_rx),
      .uart_rx_data(rx_byte),
      .uart_rx_done(rx_valid)
  );

  // --- Matrix Input ---
  matrix_input u_input (
      .clk(clk),
      .rst_n(rst_n),
      .start_en(current_state == STATE_INPUT),
      .btn_confirm(btn_confirm),
      .btn_esc(btn_esc),
      .rx_data(rx_byte),
      .rx_done(rx_valid),
      .last_wr_id(ms_last_wr_id),
      
      // Write Interface
      .wr_cmd_new(inp_wr_new),
      .wr_cmd_single(inp_wr_single),
      .wr_dims_r(inp_wr_dim_r),
      .wr_dims_c(inp_wr_dim_c),
      .wr_row_idx(inp_wr_row),
      .wr_col_idx(inp_wr_col),
      .wr_val_scalar(inp_wr_data),
      
      // Sender Interface
      .sender_data(inp_snd_data),
      .sender_start(inp_snd_start),
      .sender_is_last_col(inp_snd_last),
      .sender_newline_only(inp_snd_nl),
      .sender_id(inp_snd_id),
      .rd_id(inp_rd_id),
      .sender_done(sender_done),
      
      .seg_data(inp_seg_d),
      .seg_blink(inp_seg_b),
      .input_done(input_done),
      .error_flag(inp_err)
  );

  // --- Matrix Gen ---
  matrix_gen u_gen (
      .clk(clk),
      .rst_n(rst_n),
      .start_en(current_state == STATE_GEN),
      .btn_confirm(btn_confirm),
      .btn_esc(btn_esc),
      .rx_data(rx_byte),
      .rx_done(rx_valid),
      .last_wr_id(ms_last_wr_id),

      .wr_cmd_new(gen_wr_new),
      .wr_cmd_single(gen_wr_single),
      .wr_dims_r(gen_wr_dim_r),
      .wr_dims_c(gen_wr_dim_c),
      .wr_row_idx(gen_wr_row),
      .wr_col_idx(gen_wr_col),
      .wr_val_scalar(gen_wr_data),

      .sender_data(gen_snd_data),
      .sender_start(gen_snd_start),
      .sender_is_last_col(gen_snd_last),
      .sender_newline_only(gen_snd_nl),
      .sender_done(sender_done),

      .seg_data(gen_seg_d),
      .seg_blink(gen_seg_b),
      .gen_done(gen_done)
  );

  // --- Matrix Display ---
  matrix_display u_display (
      .clk(clk),
      .rst_n(rst_n),
      .start_en(current_state == STATE_DISPLAY),
      .btn_quit(btn_esc),
      .rx_data(rx_byte),
      .rx_done(rx_valid),

      // Slave Mode
      .ext_en(disp_ext_en),
      .ext_cmd(disp_ext_cmd),
      .ext_m(disp_ext_m),
      .ext_n(disp_ext_n),
      .ext_done(disp_ext_done),
      
      // Storage Read (Scalar)
      .rd_id(disp_rd_id),
      .rd_row(disp_rd_row),
      .rd_col(disp_rd_col),
      .rd_val(ms_rd_val_A),
      .rd_dims_r(ms_rd_dims_r_A),
      .rd_dims_c(ms_rd_dims_c_A),

      .total_matrix_cnt(total_matrix_cnt),
      .type_valid_cnt(type_valid_cnt),
      
      // Sender
      .sender_data(disp_snd_data),
      .sender_start(disp_snd_start),
      .sender_is_last_col(disp_snd_last),
      .sender_newline_only(disp_snd_nl),
      .sender_id(disp_snd_id),
      .sender_sum_head(disp_snd_head),
      .sender_sum_elem(disp_snd_elem),
      .sender_done(sender_done),
      
      // Seg
      .seg_data(disp_seg_d),
      .seg_blink(disp_seg_b),

      // Done flag
      .display_done(display_done)
  );

  // --- Calculation Sub-System ---
  matrix_calc_sys u_calc_sys (
      .clk(clk),
      .rst_n(rst_n),
      .start_en(current_state == STATE_CALC),
      .sw_mode_sel(sw_mode_sel),
      .scalar_val_in(sw_scalar_val),
      .btn_confirm(btn_confirm),
      .btn_esc(btn_reset_logic),
      .rx_data(rx_byte),
      .rx_done(rx_valid),

      // Display Slave Control
      .disp_req_en(disp_ext_en),
      .disp_req_cmd(disp_ext_cmd),
      .disp_req_m(disp_ext_m),
      .disp_req_n(disp_ext_n),
      .disp_req_done(disp_ext_done),

      // Control ALU
      .alu_start(sys_calc_start_alu),
      .alu_op_code(sys_calc_op),
      .alu_id_A(sys_calc_id_A),
      .alu_id_B(sys_calc_id_B),
      .alu_scalar_out(sys_calc_scalar_val),
      .alu_done(alu_calc_done),
      .alu_err(alu_err_flag),

      // Control Printer (Ignored/Bypassed)
      .printer_start(sys_calc_print_start),
      .printer_done (res_printer_done),

      .calc_sys_done(calc_sys_done),
      .calc_err(sys_calc_err),

      // Seg Display
      .seg_data (calc_seg_d),
      .seg_blink(calc_seg_b)
  );

  // --- Matrix ALU ---
  matrix_alu u_alu (
      .clk(clk),
      .rst_n(rst_n),
      .start(sys_calc_start_alu),
      .op_code(sys_calc_op),
      
      // Port A
      .rd_row_A(alu_rd_row_A),
      .rd_col_A(alu_rd_col_A),
      .rd_val_A(ms_rd_val_A),
      .rd_dims_r_A(ms_rd_dims_r_A),
      .rd_dims_c_A(ms_rd_dims_c_A),

      // Port B
      .rd_row_B(alu_rd_row_B),
      .rd_col_B(alu_rd_col_B),
      .rd_val_B(ms_rd_val_B),
      .rd_dims_r_B(ms_rd_dims_r_B),
      .rd_dims_c_B(ms_rd_dims_c_B),

      .scalar_val(sys_calc_scalar_val),

      .done(alu_calc_done),
      .error_flag(alu_err_flag),
      .cycle_cnt(alu_cycle_cnt),

      // Write Port
      .alu_wr_en(alu_wr_en),
      .alu_wr_new(alu_wr_new),
      .alu_wr_dims_r(alu_wr_dims_r),
      .alu_wr_dims_c(alu_wr_dims_c),
      .alu_wr_row(alu_wr_row),
      .alu_wr_col(alu_wr_col),
      .alu_wr_val(alu_wr_val)
  );

  // --- Result Printer Bypass ---
  assign res_printer_done = 1'b1; // Always done
  assign res_snd_start = 0;
  assign res_snd_last = 0;
  assign res_snd_nl = 0;
  assign res_snd_data = 0;

  //==========================================================================
  // 4. Controllers & Storage
  //==========================================================================

  // --- Input Controller (Write MUX) ---
  input_controller u_input_ctrl (
      .current_state(current_state),

      // Source: Input
      .input_wr_cmd_new(inp_wr_new),
      .input_wr_cmd_single(inp_wr_single),
      .input_wr_dims_r(inp_wr_dim_r),
      .input_wr_dims_c(inp_wr_dim_c),
      .input_wr_row_idx(inp_wr_row),
      .input_wr_col_idx(inp_wr_col),
      .input_wr_data(inp_wr_data),

      // Source: Gen
      .gen_wr_cmd_new(gen_wr_new),
      .gen_wr_cmd_single(gen_wr_single),
      .gen_wr_dims_r(gen_wr_dim_r),
      .gen_wr_dims_c(gen_wr_dim_c),
      .gen_wr_row_idx(gen_wr_row),
      .gen_wr_col_idx(gen_wr_col),
      .gen_wr_data(gen_wr_data),

      // Destination: Storage
      .sys_wr_cmd_new(ms_wr_new),
      .sys_wr_cmd_single(ms_wr_single),
      .sys_wr_dims_r(ms_wr_dims_r),
      .sys_wr_dims_c(ms_wr_dims_c),
      .sys_wr_row_idx(ms_wr_row),
      .sys_wr_col_idx(ms_wr_col),
      .sys_wr_val_scalar(ms_wr_data)
  );

  // --- Output Controller (Sender & Read ID MUX) ---
  output_controller u_output_ctrl (
      .current_state(current_state),

      // Source: Input (Echo)
      .inp_sender_start(inp_snd_start),
      .inp_sender_data(inp_snd_data),
      .inp_sender_last_col(inp_snd_last),
      .inp_sender_newline(inp_snd_nl),
      .inp_sender_id(inp_snd_id),
      .inp_rd_id(inp_rd_id),

      // Source: Gen
      .gen_sender_start(gen_snd_start),
      .gen_sender_data(gen_snd_data),
      .gen_sender_last_col(gen_snd_last),
      .gen_sender_newline(gen_snd_nl),

      // Source: Display
      .disp_sender_start(disp_snd_start),
      .disp_sender_data(disp_snd_data),
      .disp_sender_last_col(disp_snd_last),
      .disp_sender_newline(disp_snd_nl),
      .disp_sender_id(disp_snd_id),
      .disp_sender_sum_head(disp_snd_head),
      .disp_sender_sum_elem(disp_snd_elem),
      .disp_rd_id(disp_rd_id),
      .disp_slave_en(disp_ext_en),

      // Source: Result Printer (Disabled)
      .res_sender_start(res_snd_start),
      .res_sender_data(res_snd_data),
      .res_sender_last_col(res_snd_last),
      .res_sender_newline(res_snd_nl),

      // Source: Calc Sys (Operand Select)
      .alu_rd_id_A(sys_calc_id_A),

      // Dest: Sender
      .mux_sender_start(mux_tx_start),
      .mux_sender_data(mux_tx_data),
      .mux_sender_last_col(mux_tx_last),
      .mux_sender_newline(mux_tx_nl),
      .mux_sender_id(mux_tx_id),
      .mux_sender_sum_head(mux_tx_head),
      .mux_sender_sum_elem(mux_tx_elem),

      // Dest: Storage Read A ID
      .mux_rd_id_A(mux_rd_id_A_from_ctrl)
  );

  // --- Read Port A MUX (Row/Col) ---
  // Output Controller handles ID, we handle Row/Col here
  assign ms_rd_id_A = mux_rd_id_A_from_ctrl;
  assign ms_rd_row_A = (current_state == STATE_DISPLAY) ? disp_rd_row : alu_rd_row_A;
  assign ms_rd_col_A = (current_state == STATE_DISPLAY) ? disp_rd_col : alu_rd_col_A;

  // --- Read Port B Connections ---
  assign ms_rd_id_B = sys_calc_id_B;
  assign ms_rd_row_B = alu_rd_row_B;
  assign ms_rd_col_B = alu_rd_col_B;

  // --- Matrix Storage System ---
  matrix_manage_sys u_mat_storage (
      .clk(clk),
      .rst_n(rst_n),
      .wr_cmd_clear(1'b0),
      
      // Port 1: Input/Gen
      .wr_cmd_new(ms_wr_new),
      .wr_cmd_single(ms_wr_single),
      .wr_dims_r(ms_wr_dims_r),
      .wr_dims_c(ms_wr_dims_c),
      .wr_row_idx(ms_wr_row),
      .wr_col_idx(ms_wr_col),
      .wr_val_scalar(ms_wr_data),

      // Port 2: ALU Write
      .alu_wr_en(alu_wr_en),
      .alu_wr_new(alu_wr_new),
      .alu_wr_dims_r(alu_wr_dims_r),
      .alu_wr_dims_c(alu_wr_dims_c),
      .alu_wr_row_idx(alu_wr_row),
      .alu_wr_col_idx(alu_wr_col),
      .alu_wr_val(alu_wr_val),
      .alu_dst_id(alu_dst_id), // Unused for now, or could be used for result printer

      // Read Port A
      .rd_id_A  (ms_rd_id_A),
      .rd_row_A (ms_rd_row_A),
      .rd_col_A (ms_rd_col_A),
      .rd_val_A (ms_rd_val_A),
      .rd_dims_r_A(ms_rd_dims_r_A),
      .rd_dims_c_A(ms_rd_dims_c_A),
      .rd_valid_A(ms_rd_valid_A),

      // Read Port B
      .rd_id_B  (ms_rd_id_B),
      .rd_row_B (ms_rd_row_B),
      .rd_col_B (ms_rd_col_B),
      .rd_val_B (ms_rd_val_B),
      .rd_dims_r_B(ms_rd_dims_r_B),
      .rd_dims_c_B(ms_rd_dims_c_B),
      .rd_valid_B(ms_rd_valid_B),

      .total_matrix_cnt(total_matrix_cnt),
      .last_wr_id(ms_last_wr_id),
      .type_valid_cnt(type_valid_cnt)
  );

  // --- UART Sender ---
  matrix_uart_sender u_uart_sender (
      .clk(clk),
      .rst_n(rst_n),
      .start(mux_tx_start),
      .data_in(mux_tx_data),
      .is_last_col(mux_tx_last),
      .send_newline(mux_tx_nl),
      .send_id(mux_tx_id),
      .send_summary_head(mux_tx_head),
      .send_summary_elem(mux_tx_elem),
      .sender_done(sender_done),

      .tx_data (tx_byte),
      .tx_start(tx_start),
      .tx_busy (tx_busy)
  );

  //==========================================================================
  // 5. Status Indicators (Controllers & Drivers)
  //==========================================================================

  // --- LED Controller ---
  led_controller u_led_ctrl (
      .current_state(current_state),
      .inp_err(inp_err),
      .alu_err(sys_calc_err),  // Connect Calc Sys error
      .ext_led_mask(8'h00),
      .led_status(led_status)
  );

  // --- Seg Controller ---
  seg_controller u_seg_ctrl (
      .current_state(current_state),
      .sw_mode_sel  (sw_mode_sel),

      .inp_seg_data  (inp_seg_d),
      .inp_seg_blink (inp_seg_b),
      .gen_seg_data  (gen_seg_d),
      .gen_seg_blink (gen_seg_b),
      .disp_seg_data (disp_seg_d),
      .disp_seg_blink(disp_seg_b),
      .calc_seg_data (calc_seg_d),
      .calc_seg_blink(calc_seg_b),

      .seg_data_out (seg_display_data),
      .seg_blink_out(blink_mask)
  );

  // --- Seven Seg Driver ---
  seven_seg_display_driver u_seg_driver (
      .clk(clk),
      .rst_n(rst_n),
      .display_data(seg_display_data),
      .blink_mask(blink_mask),
      .an(seg_an),
      .seg0(seg_data_0),
      .seg1(seg_data_1)
  );

endmodule
