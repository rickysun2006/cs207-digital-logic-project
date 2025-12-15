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
    input logic            start,         // 普通模式：发送数字
    input matrix_element_t data_in,       // 待发送的数值
    input logic            is_last_col,   // 行尾标志
    input logic            send_newline,  // 仅发送换行
    input logic            send_id,       // 发送ID (不补齐空格)

    input logic send_summary_head,  // 发送总数+表头
    input logic send_summary_elem,  // 发送表格元素

    output logic sender_done,

    // --- UART 物理接口 ---
    output logic [7:0] tx_data,
    output logic       tx_start,
    input  logic       tx_busy,
    output logic       ready
);

  assign ready = (state == IDLE);

  // 表格参数
  // Border: +----+----+------+ (18 chars)
  // Header: |  m |  n |  cnt | (18 chars)
  // Col Widths: m=4, n=4, cnt=6
  localparam int TABLE_STR_LEN = 18;
  localparam int WIDTH_M_N = 4;
  localparam int WIDTH_CNT = 6;
  localparam int NORM_WIDTH = 5;

  typedef enum logic [4:0] {
    IDLE,
    PREPARE,
    SEND_SIGN,
    SEND_DIGIT_2,
    SEND_DIGIT_1,
    SEND_DIGIT_0,  // 数字序列
    SEND_PADDING,
    SEND_END,      // 普通换行
    WAIT_TX,       // 等待 UART

    SUM_START_PIPE,    // 打印行首 '| '
    SUM_END_PIPE,      // 打印行尾 ' |'
    SUM_PRINT_BORDER,  // 打印 +----+...
    SUM_PRINT_HEADER,  // 打印 | m | n ...
    SUM_NL_1,
    SUM_NL_2,
    SUM_NL_3           // 各种换行
  } state_t;
  state_t state, next_state, return_state;

  // --- internal signals ---
  logic       is_negative;
  logic [7:0] abs_val;
  logic [3:0] bcd_2, bcd_1, bcd_0;
  logic [4:0] char_count;
  matrix_element_t data_latched;

  // 模式寄存器 (锁存当前请求类型)
  logic mode_sum_head, mode_sum_elem;
  logic mode_last_col, mode_send_id;

  // --- 查找表：边框 ---
  function logic [7:0] get_border_char(input integer idx);
    case (idx)
      0: return "+";
      1, 2, 3, 4: return "-";
      5: return "+";
      6, 7, 8, 9: return "-";
      10: return "+";
      11, 12, 13, 14, 15, 16: return "-";
      17: return "+";
      default: return 0;
    endcase
  endfunction

  // --- 查找表：表头文字 ---
  function logic [7:0] get_header_char(input integer idx);
    // "|  m |  n |  cnt |"
    case (idx)
      0: return "|";
      1, 2: return " ";
      3: return "m";
      4: return " ";
      5: return "|";
      6, 7: return " ";
      8: return "n";
      9: return " ";
      10: return "|";
      11, 12: return " ";
      13: return "c";
      14: return "n";
      15: return "t";
      16: return " ";
      17: return "|";
      default: return 0;
    endcase
  endfunction

  // --- 数值预处理 ---
  always_comb begin
    is_negative = (data_latched < 0);
    abs_val     = is_negative ? (~data_latched + 1) : data_latched;
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
      mode_sum_head <= 0;
      mode_sum_elem <= 0;
      mode_last_col <= 0;
      mode_send_id <= 0;
    end else begin
      // 默认复位
      tx_start <= 0;
      sender_done <= 0;

      case (state)
        IDLE: begin
          char_count <= 0;

          if (start || send_summary_head || send_summary_elem || send_newline) begin
            // 锁存数据与模式
            data_latched  <= data_in;
            mode_sum_head <= send_summary_head;
            mode_sum_elem <= send_summary_elem;
            mode_last_col <= is_last_col;
            mode_send_id  <= send_id;

            // 优先级判断
            if (send_newline) begin
              state <= SEND_END;
              return_state <= IDLE;
            end else if (send_summary_head) begin
              // 模式1：打印总数 -> 换行 -> 边框 -> 表头 -> 边框
              state <= PREPARE;  // 先打数字
            end else if (send_summary_elem) begin
              // 模式2：打印 "| " -> 数字 -> 补齐 -> (如果行尾) "| \n" -> 边框
              state <= SUM_START_PIPE;
            end else begin
              // 普通模式
              state <= PREPARE;
            end
          end
        end

        // ========================
        // 表格特殊前缀
        // ========================
        SUM_START_PIPE: begin
          tx_data <= "|";
          tx_start <= 1;
          char_count <= 0;  // 重置计数给数字用
          // 发完 pipe 紧接着发空格分隔，或者直接发数字？
          // 这里简单处理：直接发数字，Padding 阶段补齐宽度
          state <= WAIT_TX;
          return_state <= PREPARE;
        end

        // ========================
        // 数字发送核心 (通用)
        // ========================
        PREPARE: begin
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

        // ========================
        // 补齐与后缀逻辑
        // ========================
        SEND_PADDING: begin
          // 计算目标宽度
          logic [4:0] target_width;
          if (mode_sum_elem) target_width = mode_last_col ? WIDTH_CNT : WIDTH_M_N;
          else target_width = NORM_WIDTH;

          // 1. 发送 ID 模式并换行
          if (mode_send_id && !mode_sum_head && !mode_sum_elem) begin
            if (mode_last_col) state <= SEND_END;
            else begin
              state <= IDLE;
              sender_done <= 1;
            end
          end  // 2. 补空格循环
          else if (char_count < target_width) begin
            tx_data <= " ";
            tx_start <= 1;
            char_count <= char_count + 1;
            return_state <= SEND_PADDING;
            state <= WAIT_TX;
          end  // 3. 补齐完成，决定下一步
          else begin
            if (mode_sum_head) begin
              // 总数发完了，开始打印表头结构
              state <= SUM_NL_1;
            end else if (mode_sum_elem) begin
              if (mode_last_col) state <= SUM_END_PIPE;  // 行尾处理
              else begin
                // 非行尾，发个结束符 '|'
                state <= IDLE;
                sender_done <= 1;
              end
            end else begin
              // 普通模式
              if (mode_last_col) state <= SEND_END;
              else begin
                state <= IDLE;
                sender_done <= 1;
              end
            end
          end
        end

        // ========================
        // 表格绘制序列
        // ========================

        // --- Head 流程: \n -> Border -> Header -> Border ---
        SUM_NL_1: begin
          tx_data <= 8'h0A;
          tx_start <= 1;
          char_count <= 0;
          state <= WAIT_TX;
          return_state <= SUM_PRINT_BORDER;
          next_state <= SUM_NL_2;  // Border 后发换行
        end

        SUM_NL_2: begin  // Border 后的换行 -> 去发 Header
          tx_data <= 8'h0A;
          tx_start <= 1;
          char_count <= 0;
          state <= WAIT_TX;
          return_state <= SUM_PRINT_HEADER;
        end

        SUM_PRINT_HEADER: begin
          if (char_count < TABLE_STR_LEN) begin
            tx_data <= get_header_char(char_count);
            tx_start <= 1;
            char_count <= char_count + 1;
            state <= WAIT_TX;
            return_state <= SUM_PRINT_HEADER;
          end else begin
            // Header 发完 -> 换行 -> Border
            tx_data <= 8'h0A;
            tx_start <= 1;
            char_count <= 0;
            state <= WAIT_TX;
            return_state <= SUM_PRINT_BORDER;
            next_state <= IDLE;  // 这里的 IDLE 意味着 HEAD 任务全部完成
          end
        end

        // --- Border 打印 (复用状态) ---
        SUM_PRINT_BORDER: begin
          if (char_count < TABLE_STR_LEN) begin
            tx_data <= get_border_char(char_count);
            tx_start <= 1;
            char_count <= char_count + 1;
            state <= WAIT_TX;
            return_state <= SUM_PRINT_BORDER;
          end else begin
            // Border 发完，去哪里？
            if (next_state == IDLE) begin
              // 如果是 Head 流程的最后一步，还需要一个换行
              tx_data <= 8'h0A;
              tx_start <= 1;
              state <= WAIT_TX;
              return_state <= IDLE;
            end else begin
              state <= next_state;
            end
          end
        end

        // --- Elem 行尾流程: " |" -> \n -> Border -> \n ---
        SUM_END_PIPE: begin
          tx_data <= "|";
          tx_start <= 1;
          state <= WAIT_TX;
          return_state <= SUM_NL_3;
        end
        SUM_NL_3: begin
          tx_data <= 8'h0A;
          tx_start <= 1;
          char_count <= 0;
          state <= WAIT_TX;
          return_state <= SUM_PRINT_BORDER;
          next_state <= IDLE;  // Border 发完发换行然后结束
        end

        // ========================
        // 通用结束与等待
        // ========================
        SEND_END: begin
          tx_data <= 8'h0A;
          tx_start <= 1;
          state <= WAIT_TX;
          return_state <= IDLE;
        end

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
