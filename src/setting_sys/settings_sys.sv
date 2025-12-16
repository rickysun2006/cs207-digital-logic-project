/*=============================================================================
#
# Project Name   : CS207_Project_Matrix_Calculator
# File Name      : settings_sys.sv
# Module Name    : settings_sys
# University     : SUSTech
#
# Create Date    : 2025-12-16
#
# Description    :
#     Other modules visit matrix storage through this module.
#
# Revision History:
# -----------------------------------------------------------------------------
# Ver   |   Date     |   Author       |   Description
# -----------------------------------------------------------------------------
# v1.0  | 2025-12-16 | DraTelligence  |   Initial creation
#
#=============================================================================*/
`include "../common/project_pkg.sv"
import project_pkg::*;

module settings_sys (
    input wire clk,
    input wire rst_n,
    input wire start_en,

    // --- User IO ---
    input wire [7:0] sw_val,       // Switches for selection and value input
    input wire       btn_confirm,  // Confirm button
    input wire       btn_esc,      // Escape/Back button

    // --- Config Outputs ---
    output reg        [      3:0] cfg_err_countdown,
    output reg signed [      7:0] cfg_val_max,
    output reg signed [      7:0] cfg_val_min,
    output reg        [PTR_W-1:0] cfg_active_limit,
    output reg                    settings_done,

    output reg        sender_str,
    output reg  [2:0] sender_str_id,
    input  wire       sender_done,
    input  wire       sender_ready,

    // --- Display Interface ---
    output code_t [7:0] seg_data,
    output reg    [7:0] seg_blink
);

  // --- Defaults ---
  localparam int DEFAULT_ERR_TIME = 10;
  localparam int DEFAULT_VAL_MAX_INIT = 9;
  localparam int DEFAULT_VAL_MIN_INIT = 0;
  localparam int DEFAULT_LIMIT_INIT = 2;

  // --- States ---
  typedef enum logic [2:0] {
    IDLE,
    WAIT_MODE_STR,
    SET_MENU,
    SET_ERR_TIME,
    SET_MAX_VAL,
    SET_MIN_VAL,
    SET_STORAGE_LIMIT
  } state_t;

  state_t state;

  // --- Button Edge Detect ---
  logic btn_confirm_prev, btn_esc_prev;
  wire btn_pos_confirm = btn_confirm & ~btn_confirm_prev;
  wire btn_pos_esc = btn_esc & ~btn_esc_prev;

  // --- Display Buffer ---
  code_t [7:0] seg_content;
  assign seg_data  = seg_content;
  assign seg_blink = 8'b1111_1111;

  // --- Logic ---
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      cfg_err_countdown <= DEFAULT_ERR_TIME;
      cfg_val_max <= DEFAULT_VAL_MAX_INIT;
      cfg_val_min <= DEFAULT_VAL_MIN_INIT;
      cfg_active_limit <= DEFAULT_LIMIT_INIT;
      settings_done <= 0;
      sender_str <= 0;
      sender_str_id <= 0;
      btn_confirm_prev <= 0;
      btn_esc_prev <= 0;
      seg_content <= {8{CHAR_BLK}};
    end else begin
      btn_confirm_prev <= btn_confirm;
      btn_esc_prev <= btn_esc;

      if (!start_en) begin
        state <= IDLE;
        settings_done <= 0;
        sender_str <= 0;
        seg_content <= {8{CHAR_BLK}};
      end else begin
        sender_str <= 0;
        case (state)
          IDLE: begin
            if (sender_ready) begin
              sender_str <= 1;
              sender_str_id <= 3'd4;  // mode-set
              state <= WAIT_MODE_STR;
            end
          end

          WAIT_MODE_STR: begin
            if (sender_done) state <= SET_MENU;
          end

          SET_MENU: begin
            // Display "SEt"
            seg_content <= {
              CHAR_S, CHAR_E, CHAR_T, CHAR_BLK, CHAR_BLK, CHAR_BLK, CHAR_BLK, CHAR_BLK
            };

            if (btn_pos_esc) begin
              settings_done <= 1;
            end else if (btn_pos_confirm) begin
              if (sw_val[7]) state <= SET_ERR_TIME;
              else if (sw_val[6]) state <= SET_MAX_VAL;
              else if (sw_val[5]) state <= SET_MIN_VAL;
              else if (sw_val[4]) state <= SET_STORAGE_LIMIT;
            end
          end

          SET_ERR_TIME: begin
            // Display "E [Value]"
            logic [7:0] val;
            val = sw_val;

            seg_content[7] <= CHAR_E;
            seg_content[6] <= CHAR_BLK;
            seg_content[5] <= CHAR_BLK;
            seg_content[4] <= CHAR_BLK;
            seg_content[3] <= CHAR_BLK;
            seg_content[2] <= code_t'((val / 100) % 10);
            seg_content[1] <= code_t'((val / 10) % 10);
            seg_content[0] <= code_t'(val % 10);

            if (btn_pos_esc) state <= IDLE;
            else if (btn_pos_confirm) begin
              if (val >= 5 && val <= 15) begin
                cfg_err_countdown <= val[3:0];
                state <= IDLE;
              end
            end
          end

          SET_MAX_VAL: begin
            // Display "H [Value]"
            logic signed [7:0] val;
            val = signed'(sw_val);

            seg_content[7] <= CHAR_H;
            seg_content[6] <= CHAR_BLK;
            seg_content[5] <= CHAR_BLK;
            seg_content[4] <= CHAR_BLK;

            if (val < 0) begin
              seg_content[3] <= CHAR_DASH;
              seg_content[2] <= code_t'(((0 - val) / 100) % 10);
              seg_content[1] <= code_t'(((0 - val) / 10) % 10);
              seg_content[0] <= code_t'((0 - val) % 10);
            end else begin
              seg_content[3] <= CHAR_BLK;
              seg_content[2] <= code_t'((val / 100) % 10);
              seg_content[1] <= code_t'((val / 10) % 10);
              seg_content[0] <= code_t'(val % 10);
            end

            if (btn_pos_esc) state <= IDLE;
            else if (btn_pos_confirm) begin
              if (val <= 31 && val >= -31) begin
                cfg_val_max <= val;
                state <= IDLE;
              end
            end
          end

          SET_MIN_VAL: begin
            // Display "L [Value]"
            logic signed [7:0] val;
            val = signed'(sw_val);

            seg_content[7] <= CHAR_L;
            seg_content[6] <= CHAR_BLK;
            seg_content[5] <= CHAR_BLK;
            seg_content[4] <= CHAR_BLK;

            if (val < 0) begin
              seg_content[3] <= CHAR_DASH;
              seg_content[2] <= code_t'(((0 - val) / 100) % 10);
              seg_content[1] <= code_t'(((0 - val) / 10) % 10);
              seg_content[0] <= code_t'((0 - val) % 10);
            end else begin
              seg_content[3] <= CHAR_BLK;
              seg_content[2] <= code_t'((val / 100) % 10);
              seg_content[1] <= code_t'((val / 10) % 10);
              seg_content[0] <= code_t'(val % 10);
            end

            if (btn_pos_esc) state <= IDLE;
            else if (btn_pos_confirm) begin
              if (val <= 31 && val >= -31) begin
                cfg_val_min <= val;
                state <= IDLE;
              end
            end
          end

          SET_STORAGE_LIMIT: begin
            // Display "n [Value]"
            logic [7:0] val;
            val = sw_val;

            seg_content[7] <= CHAR_N;
            seg_content[6] <= CHAR_BLK;
            seg_content[5] <= CHAR_BLK;
            seg_content[4] <= CHAR_BLK;
            seg_content[3] <= CHAR_BLK;
            seg_content[2] <= code_t'((val / 100) % 10);
            seg_content[1] <= code_t'((val / 10) % 10);
            seg_content[0] <= code_t'(val % 10);

            if (btn_pos_esc) state <= IDLE;
            else if (btn_pos_confirm) begin
              if (val >= 1 && val <= PHYSICAL_MAX_PER_DIM) begin
                cfg_active_limit <= val[PTR_W-1:0];
                state <= IDLE;
              end
            end
          end

        endcase
      end
    end
  end

endmodule

