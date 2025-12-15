/*=============================================================================
#
# Project Name   : CS207_Project_Matrix_Calculator
# File Name      : main_fsm.sv
# Module Name    : main_fsm
# University     : SUSTech
#
# Create Date    : 2025-11-23
#
# Description    :
#     Finite State Machine (FSM).
#
# Revision History:
# -----------------------------------------------------------------------------
# Ver   |   Date     |   Author       |   Description
# -----------------------------------------------------------------------------
# v1.0  | 2025-11-23 | DraTelligence  |   Initial creation
# v1.1  | 2025-12-13 | DraTelligence  |   Remove logic reset btn and realted logic
#
#=============================================================================*/
`include "common/project_pkg.sv"
import project_pkg::*;

module main_fsm (
    // --- Global Control ---
    input wire clk,
    input wire rst_n,

    // --- User Inputs ---
    input wire [7:0] sw_mode_sel,
    input wire       btn_confirm,

    // --- Handshakes from Sub-Systems ---
    input logic input_done,
    input logic gen_done,
    input logic display_done,
    input logic calc_sys_done,
    input logic settings_done,

    // --- Output ---
    output sys_state_t current_state
);

  sys_state_t state_reg, state_next;

  // --- Button Posedge Detection ---
  logic btn_confirm_prev;
  wire  btn_pos_confirm = btn_confirm & ~btn_confirm_prev;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state_reg        <= STATE_IDLE;
      btn_confirm_prev <= 1'b0;
    end else begin
      state_reg        <= state_next;
      btn_confirm_prev <= btn_confirm;
    end
  end

  // Output Assignment
  assign current_state = state_reg;

  //==========================================================================
  // Combinational Logic
  //==========================================================================
  always_comb begin
    state_next = state_reg;
    case (state_reg)
      STATE_IDLE: begin
        if (btn_pos_confirm) begin
          if (sw_mode_sel[7]) begin
            state_next = STATE_CALC;  // 进入计算子系统
          end else if (sw_mode_sel[6]) begin
            state_next = STATE_DISPLAY;
          end else if (sw_mode_sel[5]) begin
            state_next = STATE_GEN;
          end else if (sw_mode_sel[4]) begin
            state_next = STATE_INPUT;
          end else if (sw_mode_sel[3]) begin
            state_next = STATE_SETTINGS;
          end
        end
      end

      STATE_INPUT:   if (input_done) state_next = STATE_IDLE;
      STATE_GEN:     if (gen_done) state_next = STATE_IDLE;
      STATE_DISPLAY: if (display_done) state_next = STATE_IDLE;
      STATE_CALC:    if (calc_sys_done) state_next = STATE_IDLE;

      STATE_SETTINGS: begin
        if (settings_done) state_next = STATE_IDLE;
      end

      default: state_next = STATE_IDLE;
    endcase
  end
endmodule
