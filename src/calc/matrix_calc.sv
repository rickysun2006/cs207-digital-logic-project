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
    output logic                           alu_start,
    output op_code_t                       alu_op_code,
    output logic            [MAT_ID_W-1:0] alu_id_A,
    output logic            [MAT_ID_W-1:0] alu_id_B,
    output matrix_element_t                alu_scalar_out,  // Converted Scalar Value
    input  wire                            alu_done,
    input  wire                            alu_err,

    // 2. To Result Printer
    input  wire  printer_done,
    output logic printer_start,

    // 3. To Display Slave
    output reg                  disp_req_en,
    output reg  [          1:0] disp_req_cmd,
    output reg  [ROW_IDX_W-1:0] disp_req_m,
    output reg  [COL_IDX_W-1:0] disp_req_n,
    input  wire                 disp_req_done,

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
  typedef enum logic [4:0] {
    IDLE,
    SELECT_OP, // Wait for SW selection & Confirm

    // Interaction Flow (Replaces SELECT_A/B)
    SEL_SHOW_SUM,  // Request Display Summary
    SEL_WAIT_SUM,  // Wait for Summary Done
    SEL_WAIT_M,    // Wait for User Input M
    SEL_WAIT_N,    // Wait for User Input N
    SEL_SHOW_DET,  // Request Display Detail
    SEL_WAIT_DET,  // Wait for Detail Done
    SEL_WAIT_ID,   // Wait for User Input ID

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

  // Interaction Helpers
  reg target_op;  // 0: A, 1: B
  reg [ROW_IDX_W-1:0] temp_m;
  reg [COL_IDX_W-1:0] temp_n;

  // UART Input: Raw Hex (User Requirement)
  // Matches matrix_input.sv behavior
  logic [MAT_ID_W-1:0] rx_decoded_val;
  assign rx_decoded_val = rx_data[MAT_ID_W-1:0];

  // Valid if data is within reasonable range (e.g. < 32 for IDs/Dims)
  // This is a loose check, logic will handle specific range checks
  wire rx_valid_char = (rx_data < 8'd32);


  // Button Edge Detect
  logic btn_confirm_prev, btn_esc_prev;
  wire btn_pos_confirm = btn_confirm & ~btn_confirm_prev;
  wire btn_pos_esc = btn_esc & ~btn_esc_prev;



  // Output Assignments
  assign alu_op_code = op_reg;
  assign alu_id_A = id_a_reg;
  assign alu_id_B = id_b_reg;
  // Scalar Conversion: Sign-Magnitude (SW) -> Two's Complement (ALU)
  assign alu_scalar_out = scalar_val_in[7] ? (8'd0 - {1'b0, scalar_val_in[6:0]}) : {1'b0, scalar_val_in[6:0]};

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

      // Display Req Reset
      disp_req_en <= 0;
      disp_req_cmd <= 0;
      disp_req_m <= 0;
      disp_req_n <= 0;
      target_op <= 0;
      temp_m <= 0;
      temp_n <= 0;
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
          disp_req_en <= 0;
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
                target_op <= 0;  // Start with A
                state <= SEL_SHOW_SUM;
              end
            end
          end
        end

        // ======================================================
        // Generic Selection Flow (A or B)
        // ======================================================

        // Step 1: Show Summary
        SEL_SHOW_SUM: begin
          // Display: "A" or "B"
          seg_content <= {
            CHAR_BLK, CHAR_BLK, CHAR_BLK, CHAR_BLK, CHAR_BLK, CHAR_BLK, CHAR_BLK, CHAR_BLK
          };
          if (target_op == 0) seg_content[7] <= CHAR_A;
          else seg_content[3] <= CHAR_B;

          disp_req_en <= 1;
          disp_req_cmd <= 1;  // Summary
          state <= SEL_WAIT_SUM;
        end

        SEL_WAIT_SUM: begin
          if (disp_req_done) begin
            disp_req_en <= 0;
            state <= SEL_WAIT_M;
          end
        end

        // Step 2: Wait for M
        SEL_WAIT_M: begin
          if (btn_pos_esc) begin
            if (target_op == 1) begin
              target_op <= 0;
              state <= SEL_SHOW_SUM;
            end else state <= SELECT_OP;
          end else if (rx_done && rx_valid_char) begin
            // Store M (1-based index)
            // Note: User inputs Raw Hex (0x01-0x05)
            temp_m <= rx_decoded_val[ROW_IDX_W-1:0];
            state  <= SEL_WAIT_N;
          end
        end

        // Step 3: Wait for N
        SEL_WAIT_N: begin
          if (btn_pos_esc) begin
            if (target_op == 1) begin
              target_op <= 0;
              state <= SEL_SHOW_SUM;
            end else state <= SELECT_OP;
          end else if (rx_done && rx_valid_char) begin
            temp_n <= rx_decoded_val[COL_IDX_W-1:0];
            state  <= SEL_SHOW_DET;
          end
        end

        // Step 4: Show Detail
        SEL_SHOW_DET: begin
          disp_req_en <= 1;
          disp_req_cmd <= 2;  // Detail
          disp_req_m <= temp_m;
          disp_req_n <= temp_n;
          state <= SEL_WAIT_DET;
        end

        SEL_WAIT_DET: begin
          if (disp_req_done) begin
            disp_req_en <= 0;
            state <= SEL_WAIT_ID;
          end
        end

        // Step 5: Wait for ID
        SEL_WAIT_ID: begin
          if (btn_pos_esc) begin
            if (target_op == 1) begin
              target_op <= 0;
              state <= SEL_SHOW_SUM;
            end else state <= SELECT_OP;
          end else if (rx_done && rx_valid_char) begin
            // Store ID
            if (target_op == 0) begin
              id_a_reg <= rx_decoded_val;
              // Update Display A
              seg_content[5] <= code_t'((rx_decoded_val / 10) % 10);
              seg_content[4] <= code_t'(rx_decoded_val % 10);

              // Decide Next
              if (op_reg == OP_ADD || op_reg == OP_MAT_MUL) begin
                target_op <= 1;  // Go to B
                state <= SEL_SHOW_SUM;
              end else if (op_reg == OP_SCALAR_MUL) begin
                state <= CONFIRM_SCALAR;
              end else begin
                state <= EXEC_ALU;
              end
            end else begin
              id_b_reg <= rx_decoded_val;
              // Update Display B
              seg_content[1] <= code_t'((rx_decoded_val / 10) % 10);
              seg_content[0] <= code_t'(rx_decoded_val % 10);

              state <= EXEC_ALU;
            end
          end
        end

        // 3.5 Confirm Scalar (Scalar Ops)
        CONFIRM_SCALAR: begin
          // Display: A _ [ID_A] b [Sign] [Tens] [Ones]
          // Note: Indices 7,6,5,4 are kept from SELECT_A state
          seg_content[3] <= CHAR_B;  // 'b' for scalar

          // Sign Bit (SW[7])
          seg_content[2] <= scalar_val_in[7] ? CHAR_DASH : CHAR_BLK;

          // Magnitude (SW[6:0])
          seg_content[1] <= code_t'((scalar_val_in[6:0] / 10) % 10);
          seg_content[0] <= code_t'(scalar_val_in[6:0] % 10);

          if (btn_pos_esc) state <= SEL_SHOW_SUM;
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
