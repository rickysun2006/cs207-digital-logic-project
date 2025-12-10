/*=============================================================================
#
# Project Name   : CS207_Project_Matrix_Calculator
# File Name      : matrix_uart_sender.sv
# Module Name    : matrix_uart_sender
# University     : SUSTech
#
# Create Date    : 2025-12-10
#
# Description    :
#     Used by matrix_gen and alu module to send matrix elements via UART with 
#     proper formatting (including sign, BCD conversion, padding, and line endings).
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

module matrix_uart_sender (
    input logic clk,
    input logic rst_n,

    // --- 控制接口 ---
    input  logic            start,        // 启动一次发送
    input  matrix_element_t data_in,      // 待发送的数值 (有符号)
    input  logic            is_last_col,  // 是否为当前行最后一个元素 (决定发\n)
    input  logic            send_newline, // 是否仅发送一个换行符
    output logic            sender_done,  // 发送完成信号

    // --- UART 物理接口 ---
    output logic [7:0] tx_data,
    output logic       tx_start,
    input  logic       tx_busy
);
  localparam int COL_WIDTH = 5;

  typedef enum logic [3:0] {
    IDLE,
    PREPARE,       // 计算 BCD 和 符号
    SEND_SIGN,     // 发送负号
    SEND_DIGIT_2,  // 百位
    SEND_DIGIT_1,  // 十位
    SEND_DIGIT_0,  // 个位
    SEND_PADDING,  // 补齐空格
    SEND_END,      // 发送换行符 (如果是行尾)
    WAIT_TX        // 等待 UART 空闲
  } state_t;
  state_t state, next_state, return_state;

  // --- internal signals ---
  logic       is_negative;
  logic [7:0] abs_val;
  logic [3:0] bcd_2, bcd_1, bcd_0;  // 百, 十, 个
  logic [3:0] char_count; // 已发送字符计数

  // --- 数值预处理 ---
  always_comb begin
    is_negative = (data_in < 0);
    abs_val     = is_negative ? (~data_in + 1) : data_in;
    bcd_2       = abs_val / 100;
    bcd_1       = (abs_val % 100) / 10;
    bcd_0       = abs_val % 10;
  end

  // --- 状态机 ---
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      char_count <= 0;
      sender_done <= 0;
      tx_start <= 0;
      tx_data <= 0;
    end else begin
      // 默认脉冲归零
      tx_start <= 0;
      sender_done <= 0;

      case (state)
        IDLE: begin
          char_count <= 0;
          if (start) begin
            // 如果是空行请求，直接跳到发送换行
            if (send_newline) begin
                state <= SEND_END;
                return_state <= IDLE; // 发完换行直接结束
            end else begin
                state <= PREPARE;
            end
          end
        end

        PREPARE: begin
          // 决定从哪里开始发
          if (is_negative) begin
            state <= SEND_SIGN;
          end else if (bcd_2 > 0) begin
            state <= SEND_DIGIT_2;
          end else if (bcd_1 > 0) begin
            state <= SEND_DIGIT_1;
          end else begin
            state <= SEND_DIGIT_0;
          end
        end

        // --- 发送序列 ---
        SEND_SIGN: begin
          tx_data <= "-";
          tx_start <= 1;
          char_count <= char_count + 1;
          return_state = (bcd_2 > 0) ? SEND_DIGIT_2 : ((bcd_1 > 0) ? SEND_DIGIT_1 : SEND_DIGIT_0);
          state <= WAIT_TX;
        end

        SEND_DIGIT_2: begin
          tx_data <= {4'h3, bcd_2};
          tx_start <= 1;
          char_count <= char_count + 1;
          return_state <= SEND_DIGIT_1;
          state <= WAIT_TX;
        end

        SEND_DIGIT_1: begin
          tx_data <= {4'h3, bcd_1};
          tx_start <= 1;
          char_count <= char_count + 1;
          return_state <= SEND_DIGIT_0;
          state <= WAIT_TX;
        end

        SEND_DIGIT_0: begin
          tx_data <= {4'h3, bcd_0};
          tx_start <= 1;
          char_count <= char_count + 1;
          return_state <= SEND_PADDING;
          state <= WAIT_TX;
        end

        // --- 补齐空格 (左对齐) ---
        SEND_PADDING: begin
          if (is_last_col) begin
            state <= SEND_END;
          end else if (char_count < COL_WIDTH) begin
            tx_data <= " ";
            tx_start <= 1;
            char_count <= char_count + 1;
            return_state <= SEND_PADDING;
            state <= WAIT_TX;
          end else begin
            state <= IDLE;
            sender_done <= 1;
          end
        end

        // --- 行尾换行 ---
        SEND_END: begin
          tx_data <= 8'h0A;
          tx_start <= 1;  // \n
          return_state <= IDLE;
          state <= WAIT_TX;
        end

        // --- 通用等待状态 ---
        WAIT_TX: begin
          if (!tx_busy && !tx_start) begin
            if (return_state == IDLE) sender_done <= 1;
            state <= return_state;
          end
        end
      endcase
    end
  end

endmodule