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
#     Module to handle STATE_DISPLAY state: read matrices from storage and 
#     send them via matrix_uart_sender module.
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

module matrix_display (
    input wire clk,
    input wire rst_n,
    input wire start_en, // 进入 Display 模式

    // --- 交互接口 ---
    input wire       btn_quit,  // 退出按钮
    input wire [7:0] rx_data,   // UART 接收
    input wire       rx_done,

    // --- 存储读取接口 ---
    output reg           [MAT_ID_W-1:0] rd_id,
    input  wire matrix_t                rd_data, // 组合逻辑读取

    // --- 统计信息接口 (From Storage) ---
    input wire [7:0] total_matrix_cnt,
    input wire [3:0] type_valid_cnt  [0:MAT_SIZE_CNT-1],

    // --- Sender 接口 ---
    output matrix_element_t sender_data,
    output reg              sender_start,
    output reg              sender_is_last_col,
    output reg              sender_newline_only,
    output reg              sender_id,            // 输出 ID 模式
    output reg              sender_sum_head,      // 输出表头模式
    output reg              sender_sum_elem,      // 输出表格行模式
    input  wire             sender_done,

    // --- 状态指示 ---
    output reg display_done,  // 退出 Display 模式信号

    // --- 预留数码管输出接口 ---
    output code_t [7:0] seg_data,
    output reg seg_blink
);
  // 点亮数码管，指示工作中
  assign seg_data = {
    CHAR_C,
    CHAR_5,
    CHAR_T,
    CHAR_BLK,
    CHAR_BLK,
    CHAR_BLK,
    CHAR_BLK,
    code_t'(total_matrix_cnt[3:0])  // 注意位宽截断
  };
  assign seg_blink = 8'b1111_1111;

  // --- 状态定义 ---
  typedef enum logic [4:0] {
    IDLE,

    // --- Summary 阶段 ---
    SUM_HEAD,           // 打印总数+表头
    SUM_WAIT_HEAD,
    SUM_CHECK_IDX,      // 遍历 0-24
    SUM_PRINT_ROW_M,    // 打印 | m
    SUM_WAIT_ROW_M,
    SUM_PRINT_ROW_N,    // 打印 | n
    SUM_WAIT_ROW_N,
    SUM_PRINT_ROW_CNT,  // 打印 | cnt |
    SUM_WAIT_ROW_CNT,
    SUM_NEXT_IDX,
    SUM_END_GAP,        // 统计结束空行

    // --- 交互阶段 ---
    WAIT_INPUT_M,
    WAIT_INPUT_N,
    PARSE_CMD,

    // --- 详情阶段 ---
    DET_CALC_BASE,   // 计算起始 ID
    DET_READ_RAM,    // 读内存
    DET_PRINT_ID,    // 打印 "ID"
    DET_WAIT_ID,
    DET_PRINT_CELL,  // 打印数据
    DET_WAIT_CELL,
    DET_GAP,         // 矩阵间空行
    DET_NEXT_MAT     // 下一个矩阵
  } state_t;

  state_t state, next_state;

  // --- 内部变量 ---
  reg [          4:0] scan_idx;  // 遍历类型 (0~24)
  reg [          3:0] mats_printed;  // 当前类型已打印数量
  reg [ROW_IDX_W-1:0] cur_r;  // 行游标
  reg [COL_IDX_W-1:0] cur_c;  // 列游标

  // 命令缓存
  reg [7:0] cmd_m_ascii, cmd_n_ascii;
  logic [ROW_IDX_W-1:0] cmd_m_val;
  logic [COL_IDX_W-1:0] cmd_n_val;

  // 辅助计算
  assign cmd_m_val = cmd_m_ascii - 8'h30;
  assign cmd_n_val = cmd_n_ascii - 8'h30;

  // 从索引反推 M, N (用于 Summary 打印)
  // idx = (m-1)*5 + (n-1)
  wire [ROW_IDX_W-1:0] scan_m = (scan_idx / MAX_COLS) + 1;
  wire [COL_IDX_W-1:0] scan_n = (scan_idx % MAX_COLS) + 1;

  // Sender 数据 Mux
  matrix_element_t val_latch;
  assign sender_data = val_latch;

  // --- 状态机 ---
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      scan_idx <= 0;
      rd_id <= 0;
      display_done <= 0;
      sender_start <= 0;
      // 信号复位
      sender_newline_only <= 0;
      sender_id <= 0;
      sender_sum_head <= 0;
      sender_sum_elem <= 0;
      sender_is_last_col <= 0;
    end else begin
      // Pulse 复位
      sender_start <= 0;
      sender_newline_only <= 0;
      sender_sum_head <= 0;
      sender_sum_elem <= 0;
      sender_id <= 0;
      sender_is_last_col <= 0;
      display_done <= 0;

      case (state)
        IDLE: if (start_en) state <= SUM_HEAD;

        // ======================================================
        // 1. 自动统计 (Summary Table)
        // ======================================================
        SUM_HEAD: begin
          val_latch <= signed'({1'b0, total_matrix_cnt});  // 传入总数
          sender_start <= 1;
          sender_sum_head <= 1;  // 触发表头打印逻辑
          state <= SUM_WAIT_HEAD;
          scan_idx <= 0;
        end
        SUM_WAIT_HEAD: if (sender_done) state <= SUM_CHECK_IDX;

        SUM_CHECK_IDX: begin
          if (type_valid_cnt[scan_idx] > 0) state <= SUM_PRINT_ROW_M;
          else state <= SUM_NEXT_IDX;
        end

        // 打印表格行: | M | N | Cnt |
        // 我们利用 sender_sum_elem 模式，分三次调用

        // 1. 发送 M
        SUM_PRINT_ROW_M: begin
          val_latch <= signed'({1'b0, scan_m});
          sender_start <= 1;
          sender_sum_elem <= 1;
          sender_is_last_col <= 0;  // 不是行尾
          state <= SUM_WAIT_ROW_M;
        end
        SUM_WAIT_ROW_M: if (sender_done) state <= SUM_PRINT_ROW_N;

        // 2. 发送 N
        SUM_PRINT_ROW_N: begin
          val_latch <= signed'({1'b0, scan_n});
          sender_start <= 1;
          sender_sum_elem <= 1;
          sender_is_last_col <= 0;
          state <= SUM_WAIT_ROW_N;
        end
        SUM_WAIT_ROW_N: if (sender_done) state <= SUM_PRINT_ROW_CNT;

        // 3. 发送 Count (行尾)
        SUM_PRINT_ROW_CNT: begin
          val_latch <= signed'({1'b0, type_valid_cnt[scan_idx]});
          sender_start <= 1;
          sender_sum_elem <= 1;
          sender_is_last_col <= 1;  // 触发 Sender 打印行尾分割线
          state <= SUM_WAIT_ROW_CNT;
        end
        SUM_WAIT_ROW_CNT: if (sender_done) state <= SUM_NEXT_IDX;

        SUM_NEXT_IDX: begin
          if (scan_idx == MAT_SIZE_CNT - 1) state <= SUM_END_GAP;
          else begin
            scan_idx <= scan_idx + 1;
            state <= SUM_CHECK_IDX;
          end
        end

        SUM_END_GAP: begin
          sender_start <= 1;
          sender_newline_only <= 1;  // 表格后空一行
          state <= WAIT_INPUT_M;
        end

        // ======================================================
        // 2. 交互等待 (Interactive)
        // ======================================================
        WAIT_INPUT_M: begin
          if (btn_quit) begin
            display_done <= 1;  // 退出 Display 模式
            state <= IDLE;
          end else if (rx_done) begin
            cmd_m_ascii <= rx_data;
            state <= WAIT_INPUT_N;
          end
        end

        WAIT_INPUT_N: begin
          if (rx_done) begin
            cmd_n_ascii <= rx_data;
            state <= PARSE_CMD;
          end
        end

        PARSE_CMD: begin
          // 如果输入 "00" (ASCII 0x30)，重新显示统计
          if (cmd_m_ascii == 8'h30 && cmd_n_ascii == 8'h30) begin
            state <= SUM_HEAD;
          end  // 校验数字范围 1~5
          else if (cmd_m_val >= 1 && cmd_m_val <= MAX_ROWS && 
                         cmd_n_val >= 1 && cmd_n_val <= MAX_COLS) begin
            // 计算目标索引
            scan_idx <= (cmd_m_val - 1) * MAX_COLS + (cmd_n_val - 1);
            state <= DET_CALC_BASE;
          end else begin
            // 输入非法，忽略，回等待
            state <= WAIT_INPUT_M;
          end
        end

        // ======================================================
        // 3. 详情展示 (Details)
        // ======================================================
        DET_CALC_BASE: begin
          mats_printed <= 0;
          // 计算该类型第一个矩阵的 ID
          rd_id <= scan_idx * PHYSICAL_MAX_PER_DIM;

          // 如果该类型没有矩阵，直接回去
          if (type_valid_cnt[scan_idx] == 0) state <= WAIT_INPUT_M;
          else state <= DET_READ_RAM;
        end

        DET_READ_RAM: begin
          // RAM 读延迟
          state <= DET_PRINT_ID;
          cur_r <= 0;
          cur_c <= 0;
        end

        // 1. 打印 ID
        DET_PRINT_ID: begin
          val_latch <= signed'({1'b0, rd_id});
          sender_start <= 1;
          sender_id <= 1;  // 告诉 Sender 这是一个 ID，不用补齐
          sender_is_last_col <= 1;  // 后面跟换行
          state <= DET_WAIT_ID;
        end
        DET_WAIT_ID: if (sender_done) state <= DET_PRINT_CELL;

        // 2. 打印矩阵元素
        DET_PRINT_CELL: begin
          val_latch <= rd_data.cells[cur_r][cur_c];
          sender_start <= 1;

          if (cur_c == rd_data.cols - 1) sender_is_last_col <= 1;
          else sender_is_last_col <= 0;

          state <= DET_WAIT_CELL;
        end

        DET_WAIT_CELL: begin
          if (sender_done) begin
            // 游标更新
            if (cur_c == rd_data.cols - 1) begin
              cur_c <= 0;
              if (cur_r == rd_data.rows - 1) state <= DET_GAP;  // 矩阵结束
              else cur_r <= cur_r + 1;
              state <= DET_PRINT_CELL;  // 下一行
            end else begin
              cur_c <= cur_c + 1;
              state <= DET_PRINT_CELL;  // 下一列
            end
          end
        end

        // 3. 矩阵间隔
        DET_GAP: begin
          sender_start <= 1;
          sender_newline_only <= 1;
          state <= DET_NEXT_MAT;
        end

        DET_NEXT_MAT: begin
          if (sender_done) begin
            // 检查是否还有下一个矩阵
            if (mats_printed < type_valid_cnt[scan_idx] - 1) begin
              mats_printed <= mats_printed + 1;
              rd_id <= rd_id + 1;
              state <= DET_READ_RAM;
            end else begin
              // 全部打印完，回等待命令
              state <= WAIT_INPUT_M;
            end
          end
        end

      endcase
    end
  end

endmodule
