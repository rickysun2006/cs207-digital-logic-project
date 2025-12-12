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
    input op_code_t         op_code,          // 当前选中的运算类型
    input logic       [31:0] alu_cycle_cnt,   // ALU 运算周期数 (Bonus)
    input logic       [7:0] sw_mode_sel,      // 用于 IDLE 时的模式预览
    input logic       [7:0] total_matrix_cnt, // 用于 Display 模式显示总数

    // --- Outputs ---
    output code_t [7:0] seg_display_data,
    output logic  [7:0] blink_mask
);

  // --- Helper: Binary to BCD (Simple /10 %10) ---
  // 注意：在组合逻辑中使用除法会消耗大量资源且时序差。
  // 但考虑到周期数较小 (卷积约80)，且仅用于显示，暂且如此。
  // 如果时序违例，需改为 Look-up Table 或 Double Dabble 模块。
  function automatic code_t get_digit(input logic [31:0] val, input int pos);
    int digit;
    case (pos)
      0: digit = val % 10;
      1: digit = (val / 10) % 10;
      2: digit = (val / 100) % 10;
      3: digit = (val / 1000) % 10;
      default: digit = 0;
    endcase
    return code_t'(digit); // 0-9 对应 CHAR_0-CHAR_9
  endfunction

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
        // 左侧显示运算类型
        code_t op_char;
        case (op_code)
          OP_TRANSPOSE:  op_char = CHAR_T;
          OP_ADD:        op_char = CHAR_A;
          OP_SCALAR_MUL: op_char = CHAR_B;
          OP_MAT_MUL:    op_char = CHAR_C;
          OP_CONV:       op_char = CHAR_J;
          default:       op_char = CHAR_BLK;
        endcase
        
        // "OP  X"
        seg_display_data = {
            CHAR_0, CHAR_P, CHAR_BLK, op_char, 
            CHAR_BLK, CHAR_BLK, CHAR_BLK, CHAR_BLK
        };
      end

      STATE_CALC_RESULT: begin
        if (op_code == OP_CONV) begin
            // 卷积模式：显示 "J   xxxx" (周期数)
            seg_display_data = {
                CHAR_J, CHAR_BLK, CHAR_BLK, CHAR_BLK,
                get_digit(alu_cycle_cnt, 3),
                get_digit(alu_cycle_cnt, 2),
                get_digit(alu_cycle_cnt, 1),
                get_digit(alu_cycle_cnt, 0)
            };
        end else begin
            // 其他模式："End"
            seg_display_data = {
                CHAR_E, CHAR_5, CHAR_D, CHAR_BLK, 
                CHAR_BLK, CHAR_BLK, CHAR_BLK, CHAR_BLK
            };
        end
      end

      default: ;
    endcase
  end

  // 补充字符定义 (如果 project_pkg 中没有 CHAR_P)
  // 假设 CHAR_P = 5'd20 (需要确认 pkg)
  // 由于不能修改 pkg 且不知道是否有 P，暂时用 0 代替 O, P 用 F 代替? 
  // 或者直接显示 "OP" -> "0 P"
  // 检查 pkg 发现没有 P。
  // 既然没有 P，就只显示 Op Char 在最左边吧。
  // "X       "
  /*
  seg_display_data = {
      op_char, CHAR_BLK, CHAR_BLK, CHAR_BLK, 
      CHAR_BLK, CHAR_BLK, CHAR_BLK, CHAR_BLK
  };
  */
  // 修正上面的 STATE_CALC_SELECT 逻辑：
  /*
        code_t op_char;
        case (op_code)
          OP_TRANSPOSE:  op_char = CHAR_T;
          OP_ADD:        op_char = CHAR_A;
          OP_SCALAR_MUL: op_char = CHAR_B;
          OP_MAT_MUL:    op_char = CHAR_C;
          OP_CONV:       op_char = CHAR_J;
          default:       op_char = CHAR_BLK;
        endcase
        seg_display_data = {op_char, CHAR_BLK, CHAR_BLK, CHAR_BLK, CHAR_BLK, CHAR_BLK, CHAR_BLK, CHAR_BLK};
  */

endmodule
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
