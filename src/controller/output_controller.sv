/*=============================================================================
#
# Project Name   : CS207_Project_Matrix_Calculator
# File Name      : output_controller.sv
# Module Name    : output_controller
# University     : SUSTech
#
# Create Date    : 2025-12-02
#
# Description    :
#     Module to control output data flow from modules to uart
#
# Revision History:
# -----------------------------------------------------------------------------
# Ver   |   Date     |   Author       |   Description
# -----------------------------------------------------------------------------
# v1.0  | 2025-12-12 | DraTelligence  |   Initial creation
#
#=============================================================================*/
`include "../common/project_pkg.sv"
import project_pkg::*;

module output_controller (
    input sys_state_t current_state,

    // --- Source 1: From Matrix Gen (Echo while generating) ---
    input wire             gen_sender_start,
    input matrix_element_t gen_sender_data,
    input wire             gen_sender_last_col,
    input wire             gen_sender_newline,

    // --- Source 2: From Matrix Display (Summary & Details) ---
    input wire                            disp_sender_start,
    input matrix_element_t                disp_sender_data,
    input wire                            disp_sender_last_col,
    input wire                            disp_sender_newline,
    input wire                            disp_sender_id,
    input wire                            disp_sender_sum_head,
    input wire                            disp_sender_sum_elem,
    input wire             [MAT_ID_W-1:0] disp_rd_id,            // Display 需要读 RAM
    input wire                            disp_active,           // Display 模块处于活动状态

    // --- Source 3: From Matrix Result Printer (ALU Result) ---
    input wire                res_sender_start,
    input logic signed [31:0] res_sender_data,
    input wire                res_sender_last_col,
    input wire                res_sender_newline,

    // --- Source 3.5: From ALU Stream (Convolution) ---
    input wire                alu_stream_valid,
    input logic signed [31:0] alu_stream_data,
    input wire                alu_stream_last_col,

    // --- Source 4: From Input Controller (ALU Operand Selection) ---
    // ALU 计算前选择操作数时，可能也需要读取 Port A 来显示？
    // 根据之前的 input_controller 设计，那里只有写逻辑。
    // 如果“选择操作数”时需要回显（比如显示当前选中的矩阵），那么这里也需要接入。
    // 假设目前由 Display 模块或者单独的 Select 模块负责。
    // 暂时保留 ALU 的 Read ID 输入（通常 ALU 计算时自己控制读地址）
    input wire [MAT_ID_W-1:0] alu_rd_id_A,

    // --- Source 5: From Matrix Input (Echo) ---
    input wire                            inp_sender_start,
    input matrix_element_t                inp_sender_data,
    input wire                            inp_sender_last_col,
    input wire                            inp_sender_newline,
    input wire                            inp_sender_id,
    input wire             [MAT_ID_W-1:0] inp_rd_id,

    // --- Mode String Inputs ---
    input wire       inp_send_str,
    input wire       gen_send_str,
    input wire       disp_send_str,
    input wire       calc_send_str,
    input wire       set_send_str,
    input wire [2:0] inp_str_id,
    input wire [2:0] gen_str_id,
    input wire [2:0] disp_str_id,
    input wire [2:0] calc_str_id,
    input wire [2:0] set_str_id,

    // --- Destination 1: To UART Sender ---
    output reg                 mux_sender_start,
    output logic signed [31:0] mux_sender_data,
    output reg                 mux_sender_last_col,
    output reg                 mux_sender_newline,
    output reg                 mux_sender_id,
    output reg                 mux_sender_sum_head,
    output reg                 mux_sender_sum_elem,
    output reg                 mux_sender_str,
    output reg          [ 2:0] mux_sender_str_id,

    // --- Destination 2: To Matrix Storage (Read Port A) ---
    output reg [MAT_ID_W-1:0] mux_rd_id_A
);

  always_comb begin
    // --- 默认值 (Default: Quiet) ---
    mux_sender_start    = 0;
    mux_sender_data     = 0;
    mux_sender_last_col = 0;
    mux_sender_newline  = 0;
    mux_sender_id       = 0;
    mux_sender_sum_head = 0;
    mux_sender_sum_elem = 0;
    mux_sender_str      = 0;
    mux_sender_str_id   = 0;

    // 默认读地址给 ALU (优先级最低，或者默认状态)
    mux_rd_id_A         = alu_rd_id_A;

    case (current_state)
      // --------------------------------------------------------
      // Mode 0: Matrix Input (Echo)
      // --------------------------------------------------------
      STATE_INPUT: begin
        mux_sender_start    = inp_sender_start;
        mux_sender_data     = 32'(signed'(inp_sender_data));
        mux_sender_last_col = inp_sender_last_col;
        mux_sender_newline  = inp_sender_newline;
        mux_sender_id       = inp_sender_id;
        mux_rd_id_A         = inp_rd_id;
        mux_sender_str      = inp_send_str;
        mux_sender_str_id   = inp_str_id;
      end

      // --------------------------------------------------------
      // Mode 1: Matrix Generation (Echo Random Numbers)
      // --------------------------------------------------------
      STATE_GEN: begin
        mux_sender_start    = gen_sender_start;
        mux_sender_data     = 32'(signed'(gen_sender_data));
        mux_sender_last_col = gen_sender_last_col;
        mux_sender_newline  = gen_sender_newline;
        mux_sender_str      = gen_send_str;
        mux_sender_str_id   = gen_str_id;
      end

      // --------------------------------------------------------
      // Mode 2: Matrix Display (View stored matrices)
      // --------------------------------------------------------
      STATE_DISPLAY: begin
        mux_sender_start    = disp_sender_start;
        mux_sender_data     = 32'(signed'(disp_sender_data));
        mux_sender_last_col = disp_sender_last_col;
        mux_sender_newline  = disp_sender_newline;
        mux_sender_id       = disp_sender_id;
        mux_sender_sum_head = disp_sender_sum_head;
        mux_sender_sum_elem = disp_sender_sum_elem;
        mux_sender_str      = disp_send_str;
        mux_sender_str_id   = disp_str_id;

        // Display 模式需要控制读端口
        mux_rd_id_A         = disp_rd_id;
      end

      // --------------------------------------------------------
      // Mode 3: Calculation Result (Print Result)
      // --------------------------------------------------------
      STATE_CALC: begin
        // Priority: Display (Slave Mode) > ALU Stream (Conv) > Result Printer
        // Fix: Use disp_active to switch read ID even when not sending (e.g. reading RAM)
        if (disp_active) begin
          mux_sender_start    = disp_sender_start;
          mux_sender_data     = 32'(signed'(disp_sender_data));
          mux_sender_last_col = disp_sender_last_col;
          mux_sender_newline  = disp_sender_newline;
          mux_sender_id       = disp_sender_id;
          mux_sender_sum_head = disp_sender_sum_head;
          mux_sender_sum_elem = disp_sender_sum_elem;
          mux_rd_id_A         = disp_rd_id;
        end else if (alu_stream_valid) begin
          // Convolution Stream Output
          mux_sender_start    = 1'b1;
          mux_sender_data     = alu_stream_data;
          mux_sender_last_col = alu_stream_last_col;
          // Stream doesn't have explicit newline signal, usually handled by last_col logic in sender
          // or we can infer it if needed. For now, map to 0.
          mux_sender_newline  = 0;
        end else begin
          mux_sender_start    = res_sender_start;
          mux_sender_data     = res_sender_data;
          mux_sender_last_col = res_sender_last_col;
          mux_sender_newline  = res_sender_newline;
        end
        mux_sender_str    = calc_send_str;
        mux_sender_str_id = calc_str_id;
      end

      // --------------------------------------------------------
      // Mode 4: Settings
      // --------------------------------------------------------
      STATE_SETTINGS: begin
        mux_sender_str    = set_send_str;
        mux_sender_str_id = set_str_id;
      end

      default: ;
    endcase
  end

endmodule
