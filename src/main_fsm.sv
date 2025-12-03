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
#
#=============================================================================*/
`include "common/project_pkg.sv"
import project_pkg::*;

module main_fsm (
    // --- Global Control ---
    input wire clk,
    input wire rst_n,

    // --- Logical Inputs ---
    input wire [7:0] sw_mode_sel,
    input wire       btn_confirm,
    input wire       btn_reset_logic,

    // --- States From Other Modules ---
    input logic input_done,
    input logic gen_done,
    input logic display_done,

    // --- New States From Other Modules (Added) ---
    input logic calc_input_done,
    input logic matrix_valid_flag,
    input logic alu_done,
    input logic timer_done,

    // --- State Outputs ---
    output sys_state_t current_state,
    output op_code_t   operation_code
);

  sys_state_t state_reg, state_next;
  op_code_t op_reg, op_next;

  logic btn_confirm_prev;
  wire  btn_pos = btn_confirm & ~btn_confirm_prev;

  //==========================================================================
  // Sequential Logic
  //==========================================================================
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state_reg        <= STATE_IDLE;
      op_reg           <= OP_NONE;
      btn_confirm_prev <= 1'b0;
    end else begin
      if (btn_reset_logic) state_reg <= STATE_IDLE;
      else state_reg <= state_next;

      op_reg           <= op_next;
      btn_confirm_prev <= btn_confirm;
    end
  end

  assign current_state  = state_reg;
  assign operation_code = op_reg;

  //==========================================================================
  // Combinational Logic
  //==========================================================================
  always_comb begin
    // default
    state_next = state_reg;
    op_next    = op_reg;

    case (state_reg)
      //----------------------------------------------------------------------
      // IDLE
      //----------------------------------------------------------------------
      STATE_IDLE: begin
        op_next = OP_NONE;

        if (sw_mode_sel[7]) begin
          // Directly enter CALC_SELECT without btn_pos
          state_next = STATE_CALC_SELECT;
        end else if (sw_mode_sel[6]) begin
          if (btn_pos) state_next = STATE_DISPLAY;
        end else if (sw_mode_sel[5]) begin
          if (btn_pos) state_next = STATE_GEN;
        end else if (sw_mode_sel[4]) begin
          if (btn_pos) state_next = STATE_INPUT;
        end
      end

      //----------------------------------------------------------------------
      // CALC_SELECT
      //----------------------------------------------------------------------
      STATE_CALC_SELECT: begin
        // op_code
        if (sw_mode_sel[7]) op_next = OP_CONV;
        else if (sw_mode_sel[6]) op_next = OP_MAT_MUL;
        else if (sw_mode_sel[5]) op_next = OP_SCALAR_MUL;
        else if (sw_mode_sel[4]) op_next = OP_ADD;
        else if (sw_mode_sel[3]) op_next = OP_TRANSPOSE;
        else op_next = OP_NONE;

        // confirm
        if (btn_pos) begin
          if (op_next != OP_NONE) begin
            state_next = STATE_CALC_INPUT;
          end
        end  // back (with btn_reset_logic)
        else if (btn_reset_logic) begin
          state_next = STATE_IDLE;
        end  // exit if all calc switches are off
        else if (sw_mode_sel[7:3] == 0) begin
          state_next = STATE_IDLE;
        end
      end

      //----------------------------------------------------------------------
      // CALC_INPUT
      //----------------------------------------------------------------------
      STATE_CALC_INPUT: begin
        if (calc_input_done) begin
          if (matrix_valid_flag) begin
            state_next = STATE_CALC_EXEC;
          end else begin
            state_next = STATE_CALC_ERROR;
          end
        end else if (btn_reset_logic) begin
          state_next = STATE_CALC_SELECT;
        end
      end

      //----------------------------------------------------------------------
      // CALC_EXEC
      //----------------------------------------------------------------------
      STATE_CALC_EXEC: begin
        if (alu_done) begin
          state_next = STATE_CALC_RESULT;
        end
      end

      //----------------------------------------------------------------------
      // CALC_RESULT
      //----------------------------------------------------------------------
      STATE_CALC_RESULT: begin
        if (btn_pos || btn_reset_logic) begin
          state_next = STATE_CALC_SELECT;
        end
      end

      //----------------------------------------------------------------------
      // CALC_ERROR
      //----------------------------------------------------------------------
      STATE_CALC_ERROR: begin
        if (timer_done) begin
          state_next = STATE_CALC_SELECT;
        end else if (btn_pos) begin
          if (matrix_valid_flag) state_next = STATE_CALC_EXEC;
        end else if (btn_reset_logic) begin
          state_next = STATE_CALC_SELECT;
        end
      end

      //----------------------------------------------------------------------
      // INPUT
      //----------------------------------------------------------------------
      STATE_INPUT: begin
        if (btn_reset_logic || input_done) begin
          state_next = STATE_IDLE;
        end
      end

      //----------------------------------------------------------------------
      // GEN
      //----------------------------------------------------------------------
      STATE_GEN: begin
        if (btn_reset_logic || gen_done) begin
          state_next = STATE_IDLE;
        end
      end

      //----------------------------------------------------------------------
      // DISPLAY
      //----------------------------------------------------------------------
      STATE_DISPLAY: begin
        if (btn_reset_logic || display_done) begin
          state_next = STATE_IDLE;
        end
      end

      default: state_next = STATE_IDLE;
    endcase
  end

endmodule
