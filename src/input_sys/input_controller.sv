/*=============================================================================
#
# Project Name   : CS207_Project_Matrix_Calculator
# File Name      : input_controller.sv
# Module Name    : input_controller
# University     : SUSTech
#
# Create Date    : 2025-12-02
#
# Description    :
#     Handles data entry logic for matrix input, generation, and selection.
#
# Revision History:
# -----------------------------------------------------------------------------
# Ver   |   Date     |   Author       |   Description
# -----------------------------------------------------------------------------
# v1.0  | 2025-12-06 | DraTelligence  |   Initial creation
#
#=============================================================================*/
`include "../common/project_pkg.sv"
import project_pkg::*;

module input_controller (
    input wire clk,
    input wire rst_n,

    // --- Control Interface ---
    input  wire start_manual_input, // 对应 STATE_INPUT
    input  wire start_auto_gen,     // 对应 STATE_GEN
    input  wire start_select_op,    // 对应 STATE_CALC_INPUT

    // supported operation code
    input op_code_t op_code,

    // --- User Interaction ---
    input wire       uart_valid,   // UART 数据有效脉冲
    input wire [7:0] uart_data,    // UART ASCII 数据
    input wire       btn_confirm,  // 确认
    input wire [3:0] sw_scalar,    // 标量开关输入

    // --- Output to Storage (Write Interface) ---
    output logic wr_en,
    output logic wr_cmd_set_dims,
    output logic wr_cmd_single,

    // 维度与索引
    output logic            [ROW_IDX_W-1:0] wr_dims_r,
    output logic            [COL_IDX_W-1:0] wr_dims_c,
    output logic            [ROW_IDX_W-1:0] wr_row_idx,
    output logic            [COL_IDX_W-1:0] wr_col_idx,
    output matrix_element_t                 wr_data,

    // --- Output Results ---
    output logic                done,            // 任务完成
    output logic [MAT_ID_W-1:0] selected_id_A,   // 选中的 ID A
    output logic [MAT_ID_W-1:0] selected_id_B,   // 选中的 ID B
    output logic [         3:0] selected_scalar, // 选中的标量

    // 验证标志
    output logic input_valid_flag,

    // 随机数生成控制
    input matrix_element_t cfg_rand_min,
    input matrix_element_t cfg_rand_max
);

  //=========================================================================
  // Task Decoding
  //=========================================================================
  logic need_matrix_B;
  logic need_scalar;

  always_comb begin
    // 默认不需要
    need_matrix_B = 0;
    need_scalar   = 0;

    case (op_code)
      OP_ADD, OP_MAT_MUL: begin
        need_matrix_B = 1;
      end
      OP_SCALAR_MUL: begin
        need_scalar = 1;
      end
      default: ;  // TRANSPOSE, CONV 不需要额外参数
    endcase
  end

  // Enable 信号生成
  wire enable = start_manual_input | start_auto_gen | start_select_op;

  // 内部状态定义
  typedef enum logic [3:0] {
    IDLE,
    // --- 获取维度 ---
    GET_M,
    GET_N,
    EXEC_SET_DIMS,
    // --- 填充数据 ---
    INPUT_LOOP,
    PAD_ZEROS,
    GEN_LOOP,
    // --- 选择运算数 ---
    SEL_GET_A,
    SEL_CHECK_OP,
    SEL_GET_B,
    SEL_GET_SCALAR,
    // --- 结束 ---
    FINISH
  } sub_state_t;

  sub_state_t state;

  // 锁存当前的意图
  logic mode_is_gen;

  //=========================================================================
  // Data Registers & Generators
  //=========================================================================
  logic [ROW_IDX_W-1:0] m_reg, curr_r;
  logic [COL_IDX_W-1:0] n_reg, curr_c;
  logic [5:0] count_curr, count_total;

  // ASCII -> Value (简单取低4位, '0'=0x30 -> 0)
  wire  [3:0] uart_val = uart_data[3:0];

  // Virtual Confirm: CR (0x0D) or LF (0x0A)
  wire virtual_confirm = uart_valid && (uart_data == 8'h0D || uart_data == 8'h0A);

  // LFSR 随机数
  logic [7:0] lfsr;
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) lfsr <= 8'hA5;
    else lfsr <= {lfsr[6:0], lfsr[7] ^ lfsr[5] ^ lfsr[4] ^ lfsr[3]};
  end

  // calculate range length
  wire signed [DATA_WIDTH:0] range_len;
  assign range_len = cfg_rand_max - cfg_rand_min + 1;

  // modulo
  wire signed [DATA_WIDTH:0] offset;
  assign offset = {1'b0, lfsr} % range_len;

  // Final = Min + Offset
  wire signed [DATA_WIDTH-1:0] rand_val_mapped;
  assign rand_val_mapped = cfg_rand_min + offset[DATA_WIDTH-1:0];

  //=========================================================================
  // Main State Machine
  //=========================================================================
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      {wr_en, wr_cmd_set_dims, wr_cmd_single} <= '0;
      done <= 0;
      input_valid_flag <= 0;
      // Reset Registers
      {selected_id_A, selected_id_B, selected_scalar} <= '0;
      {m_reg, n_reg, count_curr, count_total, curr_r, curr_c} <= '0;
      mode_is_gen <= 0;
    end else if (!enable) begin
      // 强制复位：当主 FSM 离开当前状态时，无条件回到 IDLE
      state <= IDLE;
      done  <= 0;
      wr_en <= 0;
    end else begin
      // 默认输出
      wr_en <= 0;
      wr_cmd_set_dims <= 0;
      wr_cmd_single <= 0;

      case (state)
        // ------------------------------------------------------------
        // 任务分发
        // ------------------------------------------------------------
        IDLE: begin
          done <= 0;
          if (start_select_op) begin
            state <= SEL_GET_A;
          end else if (start_manual_input || start_auto_gen) begin
            mode_is_gen <= start_auto_gen;
            state <= GET_M;
          end
        end

        // ------------------------------------------------------------
        // 维度获取
        // ------------------------------------------------------------
        GET_M: begin
          if (uart_valid && uart_val >= 1 && uart_val <= 5) begin
            m_reg <= uart_val[ROW_IDX_W-1:0];
            state <= GET_N;
          end
        end

        GET_N: begin
          if (uart_valid && uart_val >= 1 && uart_val <= 5) begin
            n_reg <= uart_val[COL_IDX_W-1:0];
            state <= EXEC_SET_DIMS;
          end
        end

        EXEC_SET_DIMS: begin
          // 发送 Set Dims 命令
          wr_en           <= 1;
          wr_cmd_set_dims <= 1;
          wr_dims_r       <= m_reg;
          wr_dims_c       <= n_reg;

          // 初始化计数器
          count_total     <= m_reg * n_reg;
          count_curr      <= 0;
          curr_r          <= 0;
          curr_c          <= 0;

          // 分流
          if (mode_is_gen) state <= GEN_LOOP;
          else state <= INPUT_LOOP;
        end

        // ------------------------------------------------------------
        // 数据填充
        // ------------------------------------------------------------
        INPUT_LOOP: begin
          if (uart_valid && !virtual_confirm) begin
            // 只有在没满的情况下才写
            if (count_curr < count_total) begin
              wr_en         <= 1;
              wr_cmd_single <= 1;
              wr_row_idx    <= curr_r;
              wr_col_idx    <= curr_c;
              wr_data       <= uart_val;  // 写入接收值

              // 坐标迭代
              count_curr    <= count_curr + 1;
              if (curr_c == n_reg - 1) begin
                curr_c <= 0;
                curr_r <= curr_r + 1;
              end else begin
                curr_c <= curr_c + 1;
              end
            end
          end else if (btn_confirm || virtual_confirm) begin
            // 用户提前确认，检查是否需要补零
            if (count_curr >= count_total) state <= FINISH;
            else state <= PAD_ZEROS;
          end
        end

        PAD_ZEROS: begin
          // 补零
          if (count_curr < count_total) begin
            wr_en         <= 1;
            wr_cmd_single <= 1;
            wr_row_idx    <= curr_r;
            wr_col_idx    <= curr_c;
            wr_data       <= '0;

            count_curr    <= count_curr + 1;
            if (curr_c == n_reg - 1) begin
              curr_c <= 0;
              curr_r <= curr_r + 1;
            end else begin
              curr_c <= curr_c + 1;
            end
          end else begin
            state <= FINISH;
          end
        end

        // ------------------------------------------------------------
        // 数据生成模式
        // ------------------------------------------------------------
        GEN_LOOP: begin
          if (count_curr < count_total) begin
            wr_en         <= 1;
            wr_cmd_single <= 1;
            wr_row_idx    <= curr_r;
            wr_col_idx    <= curr_c;
            wr_data       <= rand_val_mapped;

            count_curr    <= count_curr + 1;
            if (curr_c == n_reg - 1) begin
              curr_c <= 0;
              curr_r <= curr_r + 1;
            end else begin
              curr_c <= curr_c + 1;
            end
          end else begin
            state <= FINISH;
          end
        end

        // ------------------------------------------------------------
        // 选数流程
        // ------------------------------------------------------------
        SEL_GET_A: begin
          if (uart_valid && !virtual_confirm) begin
            selected_id_A <= uart_val[MAT_ID_W-1:0];
          end
          if (btn_confirm || virtual_confirm) state <= SEL_CHECK_OP;
        end

        SEL_CHECK_OP: begin
          // 使用模块开头解析好的逻辑信号
          if (need_matrix_B) state <= SEL_GET_B;
          else if (need_scalar) state <= SEL_GET_SCALAR;
          else state <= FINISH;
        end

        SEL_GET_B: begin
          if (uart_valid && !virtual_confirm) selected_id_B <= uart_val[MAT_ID_W-1:0];
          if (btn_confirm || virtual_confirm) state <= FINISH;
        end

        SEL_GET_SCALAR: begin
          // 等待用户拨码并确认
          // TODO: 添加实时显示目前拨码数字
          if (uart_valid && !virtual_confirm) selected_scalar <= uart_val;

          if (btn_confirm) begin
            selected_scalar <= sw_scalar;
            state <= FINISH;
          end else if (virtual_confirm) begin
            state <= FINISH;
          end
        end

        // ------------------------------------------------------------
        // 结束
        // ------------------------------------------------------------
        FINISH: begin
          done <= 1;
          input_valid_flag <= 1;
        end

      endcase
    end
  end

endmodule
