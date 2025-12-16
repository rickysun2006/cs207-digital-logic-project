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
    input logic               start,         // 普通模式：发送数字
    input logic signed [31:0] data_in,       // 待发送的数值 (Widened to 32-bit)
    input logic               is_last_col,   // 行尾标志
    input logic               send_newline,  // 仅发送换行
    input logic               send_id,       // 发送ID (不补齐空格)

    input logic send_summary_head,  // 发送总数+表头
    input logic send_summary_elem,  // 发送表格元素

    input logic       send_str,  // New: Send String Mode
    input logic [2:0] str_id,    // New: String ID (0:Inp, 1:Gen, 2:Cal, 3:Dis, 4:Set)

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
    DIV_INIT,          // New: Init division
    DIV_LOOP,          // New: Division loop
    DIV_UPDATE,        // New: Update result
    SUM_START_PIPE,
    SEND_SIGN,
    SEND_DIGITS,       // New: Loop to send digits
    SEND_PADDING,
    SUM_NL_1,
    SUM_NL_2,
    SUM_PRINT_HEADER,
    SUM_PRINT_BORDER,
    SUM_END_PIPE,
    SUM_NL_3,
    SEND_STR_INIT,     // New
    SEND_STR_LOOP,     // New
    SEND_END,
    WAIT_TX
  } state_t;

  state_t state, next_state, return_state;

  // --- 内部寄存器 ---
  logic [4:0] char_count;
  logic [4:0] str_idx;  // New: String Index
  logic [7:0] str_char;  // New: Current Char
  logic signed [31:0] data_latched;
  logic [31:0] abs_val;
  logic is_negative;
  logic [3:0] bcd_digits[0:9];  // Buffer for digits (Max 10 for 32-bit)
  logic [3:0] digit_idx;  // Current digit index
  logic [3:0] total_digits;  // Total digits found

  // --- 除法器寄存器 ---
  logic [31:0] div_quotient;
  logic [4:0] div_remainder;
  logic [4:0] div_cnt;
  logic [4:0] div_temp_rem;

  // 模式寄存器 (锁存当前请求类型)
  logic mode_sum_head, mode_sum_elem;
  logic mode_last_col, mode_send_id;
  logic mode_send_str;  // New
  logic [2:0] mode_str_id;  // New

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

  // --- 查找表：模式字符串 ---
  function logic [7:0] get_mode_str_char(input logic [2:0] id, input integer idx);
    // "mode-inp\n", "mode-gen\n", "mode-cal\n", "mode-dis\n", "mode-set\n"
    // Length is 9 chars (including \n)
    case (id)
      0:
      case (idx)  // inp
        0: return "m";
        1: return "o";
        2: return "d";
        3: return "e";
        4: return "-";
        5: return "i";
        6: return "n";
        7: return "p";
        8: return 8'h0A;
        default: return 0;
      endcase
      1:
      case (idx)  // gen
        0: return "m";
        1: return "o";
        2: return "d";
        3: return "e";
        4: return "-";
        5: return "g";
        6: return "e";
        7: return "n";
        8: return 8'h0A;
        default: return 0;
      endcase
      2:
      case (idx)  // cal
        0: return "m";
        1: return "o";
        2: return "d";
        3: return "e";
        4: return "-";
        5: return "c";
        6: return "a";
        7: return "l";
        8: return 8'h0A;
        default: return 0;
      endcase
      3:
      case (idx)  // dis
        0: return "m";
        1: return "o";
        2: return "d";
        3: return "e";
        4: return "-";
        5: return "d";
        6: return "i";
        7: return "s";
        8: return 8'h0A;
        default: return 0;
      endcase
      4:
      case (idx)  // set
        0: return "m";
        1: return "o";
        2: return "d";
        3: return "e";
        4: return "-";
        5: return "s";
        6: return "e";
        7: return "t";
        8: return 8'h0A;
        default: return 0;
      endcase
      default: return 0;
    endcase
  endfunction

  assign div_temp_rem = {div_remainder[3:0], abs_val[div_cnt]};

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

          if (start || send_summary_head || send_summary_elem || send_newline || send_str) begin
            // 锁存数据与模式
            data_latched  <= data_in;
            mode_sum_head <= send_summary_head;
            mode_sum_elem <= send_summary_elem;
            mode_last_col <= is_last_col;
            mode_send_id  <= send_id;
            mode_send_str <= send_str;
            mode_str_id   <= str_id;

            // 优先级判断
            if (send_str) begin
              state <= SEND_STR_INIT;
            end else if (send_newline) begin
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
          is_negative <= (data_latched < 0);
          abs_val     <= (data_latched < 0) ? (~data_latched + 1) : data_latched;
          digit_idx   <= 0;
          state       <= DIV_INIT;
        end

        DIV_INIT: begin
          if (abs_val < 10) begin
            // 优化：小于10直接处理
            bcd_digits[digit_idx] <= abs_val[3:0];
            state <= is_negative ? SEND_SIGN : SEND_DIGITS;
          end else begin
            div_quotient <= 0;
            div_remainder <= 0;
            div_cnt <= 31;
            state <= DIV_LOOP;
          end
        end

        DIV_LOOP: begin
          if (div_temp_rem >= 10) begin
            div_remainder <= div_temp_rem - 10;
            div_quotient[div_cnt] <= 1;
          end else begin
            div_remainder <= div_temp_rem;
            div_quotient[div_cnt] <= 0;
          end

          if (div_cnt == 0) state <= DIV_UPDATE;
          else div_cnt <= div_cnt - 1;
        end

        DIV_UPDATE: begin
          bcd_digits[digit_idx] <= div_remainder[3:0];
          abs_val <= div_quotient;
          digit_idx <= digit_idx + 1;
          state <= DIV_INIT;
        end

        SEND_SIGN: begin
          tx_data <= "-";
          tx_start <= 1;
          char_count <= char_count + 1;
          state <= WAIT_TX;
          return_state <= SEND_DIGITS;
        end

        SEND_DIGITS: begin
          tx_data <= {4'h3, bcd_digits[digit_idx]};
          tx_start <= 1;
          char_count <= char_count + 1;
          state <= WAIT_TX;

          if (digit_idx == 0) begin
            return_state <= SEND_PADDING;
          end else begin
            digit_idx <= digit_idx - 1;
            return_state <= SEND_DIGITS;
          end
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
        // 字符串发送序列
        // ========================
        SEND_STR_INIT: begin
          str_idx <= 0;
          state   <= SEND_STR_LOOP;
        end

        SEND_STR_LOOP: begin
          str_char = get_mode_str_char(mode_str_id, str_idx);
          if (str_char != 0) begin
            tx_data <= str_char;
            tx_start <= 1;
            str_idx <= str_idx + 1;
            state <= WAIT_TX;
            return_state <= SEND_STR_LOOP;
          end else begin
            // End of string
            state <= IDLE;
            sender_done <= 1;
          end
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
