/*=============================================================================
#
# Project Name   : CS207_Project_Matrix_Calculator
# File Name      : seg_controller.sv
# Module Name    : seg_controller
# University     : SUSTech
#
# Create Date    : 2025-12-02
#
# Description    : Centralized 7-Segment Display Controller.
#                  Determines what to display based on FSM state and Switches.
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

module seg_controller (
    // --- Inputs ---
    input sys_state_t       current_state,
    input logic       [7:0] sw_mode_sel,      // 用于 IDLE 时的模式预览
    input logic       [7:0] total_matrix_cnt, // 用于 Display 模式显示总数

    // --- Outputs ---
    output code_t [7:0] seg_display_data,
    output logic  [7:0] blink_mask
);

  always_comb begin
    // 默认不闪烁
    blink_mask = 8'hFF;
    // 默认全黑
    seg_display_data = {
      CHAR_BLK, CHAR_BLK, CHAR_BLK, CHAR_BLK, CHAR_BLK, CHAR_BLK, CHAR_BLK, CHAR_BLK
    };

    case (current_state)
      // --------------------------------------------------------
      // 1. IDLE 模式：根据拨码开关预览即将进入的模式
      // --------------------------------------------------------
      STATE_IDLE: begin
        // 优先级与 FSM 保持一致 (7 -> 4)
        if (sw_mode_sel[7]) begin
          // Calc Mode -> "C C C C"
          seg_display_data = {
            CHAR_C, CHAR_C, CHAR_C, CHAR_C, CHAR_BLK, CHAR_BLK, CHAR_BLK, CHAR_BLK
          };
        end else if (sw_mode_sel[6]) begin
          // Display Mode -> "d d d d"
          seg_display_data = {
            CHAR_D, CHAR_D, CHAR_D, CHAR_D, CHAR_BLK, CHAR_BLK, CHAR_BLK, CHAR_BLK
          };
        end else if (sw_mode_sel[5]) begin
          // Gen Mode -> "6 6 6 6" (6 looks like G)
          seg_display_data = {
            CHAR_6, CHAR_6, CHAR_6, CHAR_6, CHAR_BLK, CHAR_BLK, CHAR_BLK, CHAR_BLK
          };
        end else if (sw_mode_sel[4]) begin
          // Input Mode -> "1 1 1 1" (Input)
          seg_display_data = {
            CHAR_1, CHAR_1, CHAR_1, CHAR_1, CHAR_BLK, CHAR_BLK, CHAR_BLK, CHAR_BLK
          };
        end else begin
          // Default: "HE110" (Hello)
          seg_display_data = {CHAR_H, CHAR_E, CHAR_1, CHAR_1, CHAR_0, CHAR_BLK, CHAR_BLK, CHAR_BLK};
        end
      end

      // --------------------------------------------------------
      // 2. Input 模式
      // --------------------------------------------------------
      STATE_INPUT: begin
        // "1 1 1 1"
        seg_display_data = {CHAR_1, CHAR_1, CHAR_1, CHAR_1, CHAR_BLK, CHAR_BLK, CHAR_BLK, CHAR_BLK};
      end

      // --------------------------------------------------------
      // 3. Gen 模式
      // --------------------------------------------------------
      STATE_GEN: begin
        // "6 6 6 6"
        seg_display_data = {CHAR_6, CHAR_6, CHAR_6, CHAR_6, CHAR_BLK, CHAR_BLK, CHAR_BLK, CHAR_BLK};
      end

      // --------------------------------------------------------
      // 4. Display 模式：显示矩阵总数
      // --------------------------------------------------------
      STATE_DISPLAY: begin
        // "Cnt  X"
        seg_display_data = {
          CHAR_C,
          CHAR_5,
          CHAR_T,
          CHAR_BLK,  // "Cnt" (5 looks like S/n slightly, or just use context)
          CHAR_BLK,
          CHAR_BLK,
          CHAR_BLK,
          code_t'(total_matrix_cnt[3:0])  // 只显示低4位，假设不超过15
        };
      end

      // --------------------------------------------------------
      // 5. Calc 相关模式
      // --------------------------------------------------------
      STATE_CALC_SELECT, STATE_CALC_INPUT, STATE_CALC_EXEC: begin
        // "C C C C"
        seg_display_data = {CHAR_C, CHAR_C, CHAR_C, CHAR_C, CHAR_BLK, CHAR_BLK, CHAR_BLK, CHAR_BLK};
      end

      STATE_CALC_RESULT: begin
        // "End" -> "E n d" (Use 5 for n approx, d for d)
        seg_display_data = {
          CHAR_E, CHAR_5, CHAR_D, CHAR_BLK, CHAR_BLK, CHAR_BLK, CHAR_BLK, CHAR_BLK
        };
      end

      STATE_CALC_ERROR: begin
        // "Err" -> "E r r"
        seg_display_data = {
          CHAR_E, CHAR_R, CHAR_R, CHAR_BLK, CHAR_BLK, CHAR_BLK, CHAR_BLK, CHAR_BLK
        };
        // 可以在这里让 blink_mask 闪烁
      end

      default: ;
    endcase
  end

endmodule
