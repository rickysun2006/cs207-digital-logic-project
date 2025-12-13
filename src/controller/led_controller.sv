/*=============================================================================
#
# Project Name   : CS207_Project_Matrix_Calculator
# File Name      : led_controller.sv
# Module Name    : led_controller
# University     : SUSTech
#
# Create Date    : 2025-12-02
#
# Description    : Centralized LED control.
#                  - LED[0] : Error Indicator (Red)
#                  - LED[15:11]: Mode Indicator (Debug info)
#                  - LED[15:8]: Optional external mask (for raw debugging)
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

module led_controller (
    // --- Inputs ---
    input sys_state_t current_state,
    input logic       inp_err,
    input logic       alu_err,

    input logic [7:0] ext_led_mask,

    // --- Output ---
    output logic [15:0] led_status
);

  always_comb begin
    led_status = 16'h0000;

    // --- Err ---
    if (inp_err || alu_err) begin
      led_status[0] = 1'b1;
    end

    // --- state display ---
    case (current_state)
      STATE_INPUT:    led_status[12] = 1'b1;  // LED 1: 输入模式
      STATE_GEN:      led_status[13] = 1'b1;  // LED 2: 生成模式
      STATE_DISPLAY:  led_status[14] = 1'b1;  // LED 3: 展示模式
      STATE_CALC:     led_status[15] = 1'b1;  // 统一为一个状态灯
      STATE_SETTINGS: led_status[11] = 1'b1;  // 预留

      default: ;  // IDLE 状态不亮模式灯
    endcase

    // --- 扩展接口 (LED 15-8) ---
    // 直接映射外部输入的 mask，用于临时调试
    led_status[7:0] = ext_led_mask;
  end

endmodule
