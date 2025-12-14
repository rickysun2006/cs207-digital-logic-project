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
    input sys_state_t       current_state,
    input             [7:0] sw_mode_sel,    // 仅用于 IDLE 模式预览

    // --- From Sub-Modules ---
    input code_t [7:0] inp_seg_data,
    input        [7:0] inp_seg_blink,

    input code_t [7:0] gen_seg_data,
    input        [7:0] gen_seg_blink,

    input code_t [7:0] disp_seg_data,
    input        [7:0] disp_seg_blink,

    input code_t [7:0] calc_seg_data,
    input [7:0]        calc_seg_blink,

    // --- Output to Driver ---
    output code_t [7:0] seg_data_out,
    output reg    [7:0] seg_blink_out
);

  always_comb begin
    // 默认值
    seg_data_out = {CHAR_BLK, CHAR_BLK, CHAR_BLK, CHAR_BLK, CHAR_BLK, CHAR_BLK, CHAR_BLK, CHAR_BLK};
    seg_blink_out = 8'h00;  // 不闪烁

    case (current_state)
      // ------------------------------------------------
      // 1. IDLE: 系统级预览逻辑 (保持在此处)
      // ------------------------------------------------
      STATE_IDLE: begin
        if (sw_mode_sel[7]) seg_display_idle(CHAR_C);  // Calc
        else if (sw_mode_sel[6]) seg_display_idle(CHAR_D);  // Disp
        else if (sw_mode_sel[5]) seg_display_idle(CHAR_6);  // Gen
        else if (sw_mode_sel[4]) seg_display_idle(CHAR_1);  // Input
        else seg_data_out = {CHAR_H, CHAR_E, CHAR_1, CHAR_1, CHAR_0, CHAR_BLK, CHAR_BLK, CHAR_BLK};
      end

      // ------------------------------------------------
      // 2. Sub-Modules Routing
      // ------------------------------------------------
      STATE_INPUT: begin
        seg_data_out  = inp_seg_data;
        seg_blink_out = inp_seg_blink;
      end

      STATE_GEN: begin
        seg_data_out  = gen_seg_data;
        seg_blink_out = gen_seg_blink;
      end

      STATE_DISPLAY: begin
        seg_data_out  = disp_seg_data;
        seg_blink_out = disp_seg_blink;
      end

      STATE_CALC: begin
        seg_data_out  = calc_seg_data;
        seg_blink_out = calc_seg_blink;
      end

      default: ;
    endcase
  end

  // 辅助 task: 生成 "X X X X" 格式
  task seg_display_idle(input code_t ch);
    seg_data_out = {ch, ch, ch, ch, CHAR_BLK, CHAR_BLK, CHAR_BLK, CHAR_BLK};
  endtask

endmodule
