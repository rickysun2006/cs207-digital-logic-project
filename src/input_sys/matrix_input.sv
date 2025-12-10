/*=============================================================================
#
# Project Name   : CS207_Project_Matrix_Calculator
# File Name      : matrix_input.sv
# Module Name    : matrix_input
# University     : SUSTech
#
# Create Date    : 2025-12-10
#
# Description    :
#     Module to handle STATE_INPUT state: store the input matrix from UART.
#
# Revision History:
# -----------------------------------------------------------------------------
# Ver   |   Date     |   Author       |   Description
# -----------------------------------------------------------------------------
# v1.0  | 2025-12-10 | DraTelligence  |   Initial creation
#
#=============================================================================*/
`include "../common/project_pkg.sv"
import project_pkg::*;

module matrix_input (
    input wire clk,
    input wire rst_n,
    input wire start_en,

    // --- UART 接口 ---
    input wire [7:0] rx_data,
    input wire       rx_done,

    // --- 退出输入模式 ---
    input wire btn_exit_input,

    // --- 报错 ---
    output reg err,

    // --- 写入存储接口 ---
    output reg wr_cmd_new,
    output reg wr_cmd_single,
    output reg [ROW_IDX_W-1:0] wr_dims_r,
    output reg [COL_IDX_W-1:0] wr_dims_c,
    output reg [ROW_IDX_W-1:0] wr_row_idx,
    output reg [COL_IDX_W-1:0] wr_col_idx,
    output matrix_element_t wr_data,

    // --- 控制接口 ---
    output reg input_done
);

  // --- 参数定义 ---
  // 500ms @ 100MHz = 50,000,000 cycles
  // log2(50000000) ≈ 25.57 -> 26 bits
  localparam int TIMEOUT_CYCLES = 50_000_000;

  // --- 状态机定义 ---
  typedef enum logic [3:0] {
    IDLE,
    GET_M,
    GET_N,
    CREATE_MAT,
    WAIT_DATA,
    WRITE_DATA,
    PASTE_ZERO,
    NEXT_ELEM,
    ERROR_STATE,
    DONE
  } state_t;

  state_t state, next_state;

  // --- 内部寄存器 ---
  reg [ROW_IDX_W-1:0] cnt_m;
  reg [COL_IDX_W-1:0] cnt_n;
  reg is_padding_mode;

  // 计时器
  reg [25:0] timer_cnt;

  // --- decoder ---
  // TODO: 支持0-9范围以外的输入
  matrix_element_t rx_val_decoded;
  always_comb begin
    if (rx_data >= 8'h30 && rx_data <= 8'h39) rx_val_decoded = signed'(rx_data - 8'h30);
    else rx_val_decoded = signed'(rx_data);
  end

  // --- 状态机跳转 ---
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) state <= IDLE;
    else state <= next_state;
  end

  always_comb begin
    next_state = state;
    case (state)
      IDLE: if (start_en) next_state = GET_M;

      GET_M: begin
        if (btn_exit_input) next_state = DONE;
        else if (rx_done) begin
          if (rx_val_decoded >= 1 && rx_val_decoded <= MAX_ROWS) next_state = GET_N;
          else next_state = ERROR_STATE;
        end
      end

      GET_N: begin
        if (rx_done) begin
          if (rx_val_decoded >= 1 && rx_val_decoded <= MAX_COLS) next_state = CREATE_MAT;
          else next_state = ERROR_STATE;
        end
      end

      CREATE_MAT: next_state = WAIT_DATA;

      WAIT_DATA: begin
        if (rx_done) begin
          next_state = WRITE_DATA;
        end else if (timer_cnt >= TIMEOUT_CYCLES) begin
          // 用户 500ms 没输入，视为输入结束，自动补0
          next_state = PASTE_ZERO;
        end
      end

      WRITE_DATA: next_state = NEXT_ELEM;

      PASTE_ZERO: next_state = NEXT_ELEM;

      NEXT_ELEM: begin
        if (cnt_n == wr_dims_c - 1 && cnt_m == wr_dims_r - 1) begin
          next_state = DONE;
        end else begin
          // 如果已经在补零模式（包括手动按键或超时触发），则继续补零
          if (is_padding_mode) next_state = PASTE_ZERO;
          else next_state = WAIT_DATA;  // 回去等下一个数（并重置计时器）
        end
      end

      ERROR_STATE: if (!start_en) next_state = IDLE;
      DONE:        if (!start_en) next_state = IDLE;
      default:     next_state = IDLE;
    endcase
  end

  // --- 数据通路逻辑 ---
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      cnt_m <= 0;
      cnt_n <= 0;
      wr_cmd_new <= 0;
      wr_cmd_single <= 0;
      wr_dims_r <= 0;
      wr_dims_c <= 0;
      wr_row_idx <= 0;
      wr_col_idx <= 0;
      wr_data <= 0;
      input_done <= 0;
      err <= 0;
      is_padding_mode <= 0;
      timer_cnt <= 0;
    end else begin
      wr_cmd_new <= 0;
      wr_cmd_single <= 0;
      input_done <= 0;

      // 计时器控制：只有在 WAIT_DATA 状态下计数，其他状态清零
      if (state == WAIT_DATA) begin
        if (timer_cnt < TIMEOUT_CYCLES) timer_cnt <= timer_cnt + 1;
      end else begin
        timer_cnt <= 0;
      end

      case (state)
        IDLE: begin
          cnt_m <= 0;
          cnt_n <= 0;
          err <= 0;
          is_padding_mode <= 0;
        end

        GET_M: if (rx_done && next_state == GET_N) wr_dims_r <= rx_val_decoded[ROW_IDX_W-1:0];
        GET_N: if (rx_done && next_state == CREATE_MAT) wr_dims_c <= rx_val_decoded[COL_IDX_W-1:0];

        ERROR_STATE: err <= 1'b1;

        CREATE_MAT: begin
          wr_cmd_new <= 1'b1;
          cnt_m <= 0;
          cnt_n <= 0;
        end

        WAIT_DATA: begin
          if (timer_cnt >= TIMEOUT_CYCLES) is_padding_mode <= 1'b1;
        end

        WRITE_DATA: begin
          wr_cmd_single <= 1'b1;
          wr_row_idx <= cnt_m;
          wr_col_idx <= cnt_n;
          wr_data <= rx_val_decoded;
        end

        PASTE_ZERO: begin
          wr_cmd_single <= 1'b1;
          wr_row_idx <= cnt_m;
          wr_col_idx <= cnt_n;
          wr_data <= 0;  // 强制写 0
        end

        NEXT_ELEM: begin
          if (cnt_n == wr_dims_c - 1) begin
            cnt_n <= 0;
            if (cnt_m != wr_dims_r - 1) cnt_m <= cnt_m + 1;
          end else begin
            cnt_n <= cnt_n + 1;
          end
        end

        DONE: input_done <= 1'b1;
      endcase
    end
  end

endmodule
