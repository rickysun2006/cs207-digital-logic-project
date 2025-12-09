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
    input  wire [7:0] rx_data,
    input  wire       rx_done,
    output reg  [7:0] tx_data,   // 回显生成的矩阵
    output reg        tx_start,  // 启动发送
    input  wire       tx_busy,   // 等待发送完成

    // --- 写入存储接口 ---
    output reg wr_cmd_new,    // 新建矩阵
    output reg wr_cmd_single, // 写入数据

    output reg [ROW_IDX_W-1:0] wr_dims_r,  // 新矩阵维度-行
    output reg [COL_IDX_W-1:0] wr_dims_c,  // 新矩阵维度-列

    output reg [ROW_IDX_W-1:0] wr_row_idx,  // 写入元素地址-行
    output reg [COL_IDX_W-1:0] wr_col_idx,  // 写入元素地址-列

    output matrix_element_t wr_data,

    // --- 控制接口 ---
    output reg gen_done  // 任务完成
);
  // --- 内部状态定义 ---
  typedef enum logic [3:0] {
    IDLE,

    GET_M,       // 接收行数
    GET_N,       // 接收列数
    GET_COUNT,   // 接收生成个数
    GEN_CREATE,  // 新建矩阵
    GEN_WRITE,   // 写入 RAM

    TX_SEND_NUM,      // 发送数字
    TX_WAIT_ACK_NUM,  // 等待 busy 上升
    TX_WAIT_DONE_NUM, // 等待 busy 下降

    TX_SEND_SEP,      // 发送分隔符
    TX_WAIT_ACK_SEP,
    TX_WAIT_DONE_SEP,

    NEXT_ELEM,  // 下一个元素判断
    DONE        // 已全部严肃完成
  } state_t;

  state_t state, next_state;

  // --- 寄存器 ---
  reg [7:0] mat_cnt;  // 存储 Count
  reg [7:0] cnt_m, cnt_n, cnt_k;  // 循环计数器: 行, 列, 个数
  matrix_element_t val_latch;  // 锁存当前生成值，供回显使用

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) state <= IDLE;
    else state <= next_state;
  end

  // --- 组合逻辑：状态机 ---
  always_comb begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start_en) next_state = GET_M;
      end
      GET_M: if (rx_done) next_state = GET_N;
      GET_N: if (rx_done) next_state = GET_COUNT;
      GET_COUNT: if (rx_done) next_state = GEN_CREATE;

      GEN_CREATE: next_state = GEN_WRITE;
      GEN_WRITE:  next_state = TX_SEND_NUM;

      TX_SEND_NUM:      next_state = TX_WAIT_ACK_NUM;
      TX_WAIT_ACK_NUM:  if (tx_busy) next_state = TX_WAIT_DONE_NUM;
      TX_WAIT_DONE_NUM: if (!tx_busy) next_state = TX_SEND_SEP;

      TX_SEND_SEP:      next_state = TX_WAIT_ACK_SEP;
      TX_WAIT_ACK_SEP:  if (tx_busy) next_state = TX_WAIT_DONE_SEP;
      TX_WAIT_DONE_SEP: if (!tx_busy) next_state = NEXT_ELEM;

      NEXT_ELEM: begin
        if (cnt_k >= mat_cnt) next_state = DONE;  // 全都生成完了
        else next_state = GEN_CREATE;  // 继续下一个
      end

      DONE: begin
        if (!start_en) next_state = IDLE;  // 等待 FSM 切走
      end

      default: next_state = IDLE;
    endcase
  end

  // --- 时序逻辑：数据处理 ---
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      mat_cnt <= 0;
      cnt_m <= 0;
      cnt_n <= 0;
      cnt_k <= 0;
      gen_done <= 0;
      tx_start <= 0;
      wr_cmd_single <= 0;
      wr_cmd_new <= 0;
    end else begin
      // 默认信号归位
      tx_start <= 0;
      wr_cmd_new    <= 0;
      wr_cmd_single <= 0;
      gen_done <= 0;

      case (state)
        IDLE: begin
          cnt_m <= 0;
          cnt_n <= 0;
          cnt_k <= 0;
        end

        // --- 参数接收 ---
        GET_M: begin
          if (rx_done) wr_dims_r <= rx_data[ROW_IDX_W-1:0];
        end

        GET_N: begin
          if (rx_done) wr_dims_c <= rx_data[COL_IDX_W-1:0];
        end

        GET_COUNT: begin
          if (rx_done) begin
            mat_cnt <= rx_data;

            // 初始化计数器
            cnt_k   <= 0;
            cnt_m   <= 0;
            cnt_n   <= 0;
          end
        end

        GEN_CREATE: begin
          wr_cmd_new <= 1'b1;
        end

        // --- 生成与存储与回显 --
        GEN_WRITE: begin
          val_latch     <= signed'(rand_val);  // 【关键】锁存随机数，供后面回显用

          wr_cmd_single <= 1'b1;
          wr_row_idx    <= cnt_m[ROW_IDX_W-1:0];  // 显式位宽转换，消除警告
          wr_col_idx    <= cnt_n[COL_IDX_W-1:0];
          wr_data       <= signed'(rand_val);  // 直接写入
        end

        // --- 发送数字 ---
        TX_SEND_NUM: begin
          tx_data  <= 8'(val_latch) + 8'h30;  // 使用锁存值转 ASCII
          tx_start <= 1'b1;
        end

        // --- 发送分隔符 ---
        TX_SEND_SEP: begin
          tx_start <= 1'b1;
          if (cnt_n == wr_dims_c - 1) tx_data <= 8'h0A;
          else tx_data <= 8'h20;
        end

        // --- 循环控制 ---
        NEXT_ELEM: begin
          if (cnt_n == wr_dims_c - 1) begin
            cnt_n <= 0;
            if (cnt_m == wr_dims_r - 1) begin
              cnt_m <= 0;
              // 矩阵个数加 1
              cnt_k <= cnt_k + 1;
            end else begin
              cnt_m <= cnt_m + 1;
            end
          end else begin
            cnt_n <= cnt_n + 1;
          end
        end

        DONE: gen_done <= 1;
      endcase
    end
  end

endmodule
