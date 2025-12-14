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
#     Module responsible for calculation function. 
#
# Revision History:
# -----------------------------------------------------------------------------
# Ver   |   Date     |   Author       |   Description
# -----------------------------------------------------------------------------
# v1.0  | 2025-12-13 | DraTelligence  |   Initial creation
#
#=============================================================================*/
`include "../common/project_pkg.sv"
import project_pkg::*;

module matrix_calc_sys (
    input wire clk,
    input wire rst_n,
    input wire start_en, // From Main FSM (STATE_CALC)

    // --- User IO ---
    input wire [7:0] sw_mode_sel,    // Op Selection
    input wire [7:0] scalar_val_in,  // Scalar Input from Switches
    input wire       btn_confirm,    // Confirm / Enter
    input wire       btn_esc,        // Back / Cancel

    // --- UART Interaction (For selecting Matrix IDs) ---
    input wire [7:0] rx_data,
    input wire       rx_done,

    // --- Sub-Modules Interfaces ---
    // 1. To ALU
    output logic                    alu_start,
    output op_code_t                alu_op_code,
    output logic     [MAT_ID_W-1:0] alu_id_A,
    output logic     [MAT_ID_W-1:0] alu_id_B,
    input  wire                     alu_done,
    input  wire                     alu_err,

    // 2. To Result Printer
    input  wire  printer_done,
    output logic printer_start,

    // --- System Output ---
    output reg calc_sys_done,  // To Main FSM (Exit CALC mode)
    output reg calc_err,       // To LED

    // --- 数码管输出接口 ---
    output code_t [7:0] seg_data,
    output reg    [7:0] seg_blink
);
  // --- Constants ---
  // Error Countdown: 5 seconds @ 100MHz
  localparam int ERR_COUNT_MAX = 500_000_000;

  // --- States ---
  typedef enum logic [3:0] {
    IDLE,
    SELECT_OP,       // Wait for SW selection & Confirm
    SELECT_A,        // Wait for UART Input (ID A)
    SELECT_B,        // Wait for UART Input (ID B)
    CONFIRM_SCALAR,  // Wait for SW Scalar & Confirm (Optional state)
    EXEC_ALU,        // Trigger ALU
    WAIT_ALU,        // Wait for ALU completion
    ERROR_HOLD,      // Error Countdown
    EXEC_PRINT,      // Trigger Printer
    WAIT_PRINT,      // Wait for printing
    DONE_WAIT        // Wait for user to exit or restart
  } state_t;

  state_t state, next_state;

  // Seg Display
  code_t [7:0] seg_content;
  assign seg_data  = seg_content;
  assign seg_blink = 8'b1111_1111;

  // --- Internal Signals ---
  op_code_t op_reg;
  reg [MAT_ID_W-1:0] id_a_reg;
  reg [MAT_ID_W-1:0] id_b_reg;
  reg [28:0] err_timer;  // Enough for 5s

  // Button Edge Detect
  logic btn_confirm_prev, btn_esc_prev;
  wire                 btn_pos_confirm = btn_confirm & ~btn_confirm_prev;
  wire                 btn_pos_esc = btn_esc & ~btn_esc_prev;

  // UART ID Decoder (Raw Value)
  logic [MAT_ID_W-1:0] rx_id_val;
  assign rx_id_val = rx_data[MAT_ID_W-1:0];
  wire rx_id_valid = (rx_data < MAT_TOTAL_SLOTS);

  // Output Assignments
  assign alu_op_code = op_reg;
  assign alu_id_A = id_a_reg;
  assign alu_id_B = id_b_reg;

  // --- State Machine ---
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      op_reg <= OP_NONE;
      id_a_reg <= 0;
      id_b_reg <= 0;
      calc_sys_done <= 0;
      alu_start <= 0;
      printer_start <= 0;
      calc_err <= 0;
      err_timer <= 0;
      btn_confirm_prev <= 0;
      btn_esc_prev <= 0;
      seg_content <= {
        CHAR_BLK, CHAR_BLK, CHAR_BLK, CHAR_BLK, CHAR_BLK, CHAR_BLK, CHAR_BLK, CHAR_BLK
      };
    end else begin
      btn_confirm_prev <= btn_confirm;
      btn_esc_prev <= btn_esc;

      // Pulse Reset
      alu_start <= 0;
      printer_start <= 0;
      calc_sys_done <= 0;

      case (state)
        IDLE: begin
          if (start_en) state <= SELECT_OP;
          seg_content <= {
            CHAR_BLK, CHAR_BLK, CHAR_BLK, CHAR_BLK, CHAR_BLK, CHAR_BLK, CHAR_BLK, CHAR_BLK
          };
          calc_err <= 0;
          err_timer <= 0;
        end

        // 1. Select Operation
        SELECT_OP: begin
          if (btn_pos_esc) begin
            calc_sys_done <= 1;  // Exit to Main Menu
            state <= IDLE;
          end else begin
            // Seg Display
            seg_content <= {
              CHAR_BLK, CHAR_BLK, CHAR_BLK, CHAR_BLK, CHAR_BLK, CHAR_BLK, CHAR_BLK, CHAR_BLK
            };
            if (sw_mode_sel[7]) seg_content[7] <= CHAR_A;  // Add
            else if (sw_mode_sel[6]) seg_content[7] <= CHAR_B;  // Mat Mul
            else if (sw_mode_sel[5]) seg_content[7] <= CHAR_C;  // Scalar Mul
            else if (sw_mode_sel[4]) seg_content[7] <= CHAR_T;  // Transpose
            else if (sw_mode_sel[3]) seg_content[7] <= CHAR_J;  // Conv

            if (btn_pos_confirm) begin
              // Decode Switchesbegin
              if (sw_mode_sel[7]) op_reg <= OP_ADD;
              else if (sw_mode_sel[6]) op_reg <= OP_MAT_MUL;
              else if (sw_mode_sel[5]) op_reg <= OP_SCALAR_MUL;
              else if (sw_mode_sel[4]) op_reg <= OP_TRANSPOSE;
              else if (sw_mode_sel[3]) op_reg <= OP_CONV;
              else op_reg <= OP_NONE;

              // Next State Logic based on Op Type
              if (sw_mode_sel[7:3] == 0) begin
                state <= SELECT_OP;  // Invalid selection
              end else begin
                state <= SELECT_A;
              end
            end
          end
        end

        // 2. Select Matrix A
        SELECT_A: begin
          seg_content <= {
            CHAR_A, CHAR_BLK, CHAR_BLK, CHAR_BLK, CHAR_BLK, CHAR_BLK, CHAR_BLK, CHAR_BLK
          };

          if (btn_pos_esc) state <= SELECT_OP;
          else if (rx_done && rx_id_valid) begin
            id_a_reg <= rx_id_val;

            // Update Display with ID A (Indices 5, 4)
            seg_content[5] <= code_t'((rx_id_val / 10) % 10);
            seg_content[4] <= code_t'(rx_id_val % 10);

            // Binary Ops need Operand B
            if (op_reg == OP_ADD || op_reg == OP_MAT_MUL) state <= SELECT_B;
            else if (op_reg == OP_SCALAR_MUL)
              state <= CONFIRM_SCALAR;  // Wait for scalar switch confirmation
            else state <= EXEC_ALU;  // Unary Ops (Transpose, Conv)
          end
        end

        // 3. Select Matrix B (Binary Ops)
        SELECT_B: begin
          seg_content[3:0] <= {CHAR_B, CHAR_BLK, CHAR_BLK, CHAR_BLK};

          if (btn_pos_esc) state <= SELECT_A;
          else if (rx_done && rx_id_valid) begin
            id_b_reg <= rx_id_val;

            // Update Display with ID B (Indices 1, 0)
            seg_content[1] <= code_t'((rx_id_val / 10) % 10);
            seg_content[0] <= code_t'(rx_id_val % 10);

            state <= EXEC_ALU;
          end
        end

        // 3.5 Confirm Scalar (Scalar Ops)
        CONFIRM_SCALAR: begin
          // Display: A _ [ID_A] b _ [Scalar]
          seg_content[7] <= CHAR_A;
          seg_content[6] <= CHAR_BLK;
          seg_content[5] <= code_t'((id_a_reg / 10) % 10);
          seg_content[4] <= code_t'(id_a_reg % 10);
          seg_content[3] <= CHAR_BLK;
          seg_content[2] <= CHAR_B;  // 'b' for scalar
          seg_content[1] <= code_t'((scalar_val_in[3:0] / 10) % 10);
          seg_content[0] <= code_t'(scalar_val_in[3:0] % 10);

          if (btn_pos_esc) state <= SELECT_A;
          else if (btn_pos_confirm) begin
            // Scalar val is read directly from system_core wires by ALU
            state <= EXEC_ALU;
          end
        end

        // 4. Trigger ALU
        EXEC_ALU: begin
          alu_start <= 1;
          state <= WAIT_ALU;
        end

        // 5. Wait for ALU
        WAIT_ALU: begin
          if (alu_err) begin
            calc_err <= 1;  // Turn on LED
            err_timer <= 0;
            state <= ERROR_HOLD;
          end else if (alu_done) begin
            state <= EXEC_PRINT;
          end
        end

        // 6. Error Handling (Countdown)
        ERROR_HOLD: begin
          if (btn_pos_esc) begin
            // Manual cancel
            calc_err <= 0;
            state <= SELECT_OP;
          end else if (err_timer >= ERR_COUNT_MAX) begin
            // Timeout -> Reset
            calc_err <= 0;
            state <= SELECT_OP;
          end else begin
            err_timer <= err_timer + 1;
          end
        end

        // 7. Trigger Printer
        EXEC_PRINT: begin
          printer_start <= 1;
          state <= WAIT_PRINT;
        end

        // 8. Wait for Printing
        WAIT_PRINT: begin
          if (printer_done) state <= DONE_WAIT;
        end

        // 9. Finish
        DONE_WAIT: begin
          if (btn_pos_esc || btn_pos_confirm) begin
            state <= SELECT_OP;  // Start over
          end
        end

      endcase
    end
  end

endmodule
