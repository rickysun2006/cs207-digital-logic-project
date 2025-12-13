/*=============================================================================
#
# Project Name   : CS207_Project_Matrix_Calculator
# File Name      : matrix_gen.sv
# Module Name    : matrix_gen
# University     : SUSTech
#
# Create Date    : 2025-12-09
#
# Description    :
#     Module to handle STATE_GEN state: generate random matrix and store it.
#
# Revision History:
# -----------------------------------------------------------------------------
# Ver   |   Date     |   Author       |   Description
# -----------------------------------------------------------------------------
# v1.0  | 2025-12-09 | DraTelligence  |   Initial creation
#
#=============================================================================*/
`include "../common/project_pkg.sv"
import project_pkg::*;

module matrix_gen (
    input wire clk,
    input wire rst_n,
    input wire start_en,

    // --- 随机数接口 ---
    input [7:0] rand_val,

    // --- UART 接口 ---
    input wire [7:0] rx_data,
    input wire       rx_done,

    // --- Sender 模块接口 ---
    output matrix_element_t sender_data,
    output reg              sender_start,
    output reg              sender_is_last_col,
    output reg              sender_newline_only,
    input  wire             sender_done,

    // --- 写入存储接口 ---
    output reg wr_cmd_new,
    output reg wr_cmd_single,
    output reg [ROW_IDX_W-1:0] wr_dims_r,
    output reg [COL_IDX_W-1:0] wr_dims_c,
    output reg [ROW_IDX_W-1:0] wr_row_idx,
    output reg [COL_IDX_W-1:0] wr_col_idx,
    output matrix_element_t wr_data,

    // --- 控制接口 ---
    input  wire btn_exit_gen,
    output reg  gen_done,

    // --- 预留数码管输出接口 ---
    output code_t [7:0] seg_data,
    output reg seg_blink
);
  // --- 内部状态定义 ---
  typedef enum logic [3:0] {
    IDLE,
    GET_M,
    GET_N,
    GET_COUNT,
    GEN_CREATE,
    GEN_WRITE,
    TX_WAIT_SENDER,
    NEXT_ELEM,
    GEN_GAP,
    TX_WAIT_GAP,
    DONE
  } state_t;
  state_t state, next_state;

  // --- 点亮数码管，指示工作中 ---
  assign seg_data  = {CHAR_6, CHAR_BLK, CHAR_BLK, CHAR_BLK, CHAR_BLK, CHAR_BLK, CHAR_BLK, CHAR_BLK};
  assign seg_blink = 8'h00;

  // --- 寄存器 ---
  reg [7:0] mat_cnt;
  reg [7:0] cnt_m, cnt_n, cnt_k;
  matrix_element_t val_latch;

  assign sender_data = val_latch;
  assign sender_is_last_col = (cnt_n == wr_dims_c - 1);

  // --- 状态跳转逻辑 ---
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) state <= IDLE;
    else state <= next_state;
  end

  // --- 组合逻辑：状态机 ---
  always_comb begin
    next_state = state;
    case (state)
      IDLE:      if (start_en) next_state = GET_M;
      GET_M: begin
        if (btn_exit_gen) next_state = DONE;
        else if (rx_done) next_state = GET_N;
      end
      GET_N:     if (rx_done) next_state = GET_COUNT;
      GET_COUNT: if (rx_done) next_state = GEN_CREATE;

      GEN_CREATE: next_state = GEN_WRITE;

      GEN_WRITE: next_state = TX_WAIT_SENDER;

      TX_WAIT_SENDER: begin
        if (sender_done) next_state = NEXT_ELEM;
      end

      NEXT_ELEM: begin
        if (cnt_n == wr_dims_c - 1 && cnt_m == wr_dims_r - 1) begin
          // 已经是本矩阵末尾
          if (cnt_k == mat_cnt - 1) begin
            // 是最后一个矩阵，等待下一组输入
            next_state = GET_M;
          end else begin
            // 还有下一个矩阵，先插入空行
            next_state = GEN_GAP;
          end
        end else begin
          // 矩阵未满，继续写下一个元素
          next_state = GEN_WRITE;
        end
      end

      GEN_GAP: next_state = TX_WAIT_GAP;
      TX_WAIT_GAP:
      if (sender_done) next_state = GEN_CREATE;  // 换行发完，创建下一个矩阵

      DONE: if (!start_en) next_state = IDLE;
      default: next_state = IDLE;
    endcase
  end

  // --- 时序逻辑：数据处理 & 调试输出 ---
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      mat_cnt <= 0;
      cnt_m <= 0;
      cnt_n <= 0;
      cnt_k <= 0;
      gen_done <= 0;
      sender_start <= 0;
      sender_newline_only <= 0;
      wr_cmd_single <= 0;
      wr_cmd_new <= 0;
      wr_dims_r <= 0;
      wr_dims_c <= 0;
      wr_row_idx <= 0;
      wr_col_idx <= 0;
      wr_data <= 0;
      val_latch <= 0;
    end else begin
      // 默认信号归位
      sender_start        <= 0;
      sender_newline_only <= 0;
      wr_cmd_new          <= 0;
      wr_cmd_single       <= 0;
      gen_done            <= 0;

      case (state)
        IDLE: begin
          cnt_m <= 0;
          cnt_n <= 0;
          cnt_k <= 0;
        end

        // --- 参数接收 ---
        GET_M: if (rx_done) wr_dims_r <= rx_data[ROW_IDX_W-1:0];
        GET_N: if (rx_done) wr_dims_c <= rx_data[COL_IDX_W-1:0];
        GET_COUNT: begin
          if (rx_done) begin
            mat_cnt <= rx_data;
            cnt_k   <= 0;
            cnt_m   <= 0;
            cnt_n   <= 0;
          end
        end

        GEN_CREATE: begin
          wr_cmd_new <= 1'b1;
        end

        // --- 生成与存储与启动发送 ---
        GEN_WRITE: begin
          val_latch           <= signed'(rand_val);
          wr_cmd_single       <= 1'b1;
          wr_row_idx          <= cnt_m[ROW_IDX_W-1:0];
          wr_col_idx          <= cnt_n[COL_IDX_W-1:0];
          wr_data             <= signed'(rand_val);

          sender_start        <= 1'b1;
          sender_newline_only <= 0;  // 正常发送数据
        end

        // --- 发送空行 ---
        GEN_GAP: begin
          sender_start        <= 1'b1;
          sender_newline_only <= 1'b1;  // 仅发送换行
        end

        // --- 循环控制 ---
        NEXT_ELEM: begin
          if (cnt_n == wr_dims_c - 1) begin
            cnt_n <= 0;
            if (cnt_m == wr_dims_r - 1) begin
              cnt_m <= 0;
              cnt_k <= cnt_k + 1;  // 矩阵完成，ID+1
            end else begin
              cnt_m <= cnt_m + 1;
            end
          end else begin
            cnt_n <= cnt_n + 1;
          end
        end

        DONE: begin
          gen_done <= 1'b1;
        end
      endcase
    end
  end

endmodule
