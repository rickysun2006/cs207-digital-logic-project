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

    // --- Matrix Dimensions for Validation ---
    input wire [ROW_IDX_W-1:0] mat_a_rows,
    input wire [COL_IDX_W-1:0] mat_a_cols,
    input wire [ROW_IDX_W-1:0] mat_b_rows,
    input wire [COL_IDX_W-1:0] mat_b_cols,
    input wire                 mat_b_valid,

    // --- Configuration ---
    input wire [3:0] cfg_err_countdown,

    // --- Random Number ---
    input wire [7:0] rand_val,

    // --- UART Interaction (For selecting Matrix IDs) ---
    input wire [7:0] rx_data,
    input wire       rx_done,

    output reg        sender_str,
    output reg  [2:0] sender_str_id,
    input  wire       sender_done,
    input  wire       sender_ready,

    // --- Sub-Modules Interfaces ---
    // 1. To ALU
    output logic                           alu_start,
    output op_code_t                       alu_op_code,
    output logic            [MAT_ID_W-1:0] alu_id_A,
    output logic            [MAT_ID_W-1:0] alu_id_B,
    output matrix_element_t                alu_scalar_out,  // Converted Scalar Value
    input  wire                            alu_done,
    input  wire                            alu_err,
    input  wire             [        31:0] alu_cycle_cnt,   // Performance Counter

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
    SEND_MODE_STR,
    WAIT_MODE_STR,
    DEBOUNCE_ENTRY,
    SELECT_OP,  // Wait for SW selection & Confirm

    // Interaction Flow (Replaces SELECT_A/B)
    SEL_SHOW_SUM,  // Request Display Summary
    SEL_WAIT_SUM,  // Wait for Summary Done
    SEL_WAIT_M,    // Wait for User Input M
    SEL_WAIT_N,    // Wait for User Input N
    SEL_SHOW_DET,  // Request Display Detail
    SEL_WAIT_DET,  // Wait for Detail Done
    SEL_WAIT_ID,   // Wait for User Input ID

    // Auto Select
    AUTO_SEARCH_B,
    AUTO_WAIT_MEM,
    AUTO_CHECK,

    // New States for Confirmation
    PRINT_A,
    WAIT_PRINT_A,
    PRINT_B,
    WAIT_PRINT_B,
    CONFIRM_SELECTION,

    CONFIRM_SCALAR,   // Wait for SW Scalar & Confirm (Optional state)
    EXEC_ALU,         // Trigger ALU
    WAIT_ALU,         // Wait for ALU completion
    ERROR_HOLD,       // Error Countdown (ALU Error)
    ERROR_COUNTDOWN,  // Input Validation Error Countdown
    EXEC_PRINT,       // Trigger Printer
    WAIT_PRINT,       // Wait for printing
    DONE_WAIT         // Wait for user to exit or restart
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
  reg [MAT_ID_W-1:0] search_id;
  reg [7:0] scalar_latch;
  reg [31:0] err_timer;  // Enough for 5s
  reg [3:0] err_countdown_val;  // For 10s countdown

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
  wire rx_valid_char = (rx_data < MAT_TOTAL_SLOTS);

  // Button Edge Detect
  logic btn_confirm_prev, btn_esc_prev;
  wire btn_pos_confirm = btn_confirm & ~btn_confirm_prev;
  wire btn_pos_esc = btn_esc & ~btn_esc_prev;

  // Output Assignments
  assign alu_op_code = op_reg;
  assign alu_id_A = id_a_reg;
  assign alu_id_B = id_b_reg;
  // Scalar Conversion: Sign-Magnitude (SW) -> Two's Complement (ALU)
  // Use latched scalar value
  assign alu_scalar_out = scalar_latch[7] ? (8'd0 - {1'b0, scalar_latch[6:0]}) : {1'b0, scalar_latch[6:0]};

  // --- Validation Logic ---
  function automatic logic check_validity();
    case (op_reg)
      OP_ADD: return (mat_a_rows == mat_b_rows) && (mat_a_cols == mat_b_cols);
      OP_MAT_MUL: return (mat_a_cols == mat_b_rows);
      // For other ops, assume valid or add specific rules
      default: return 1'b1;
    endcase
  endfunction

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
      sender_str <= 0;
      sender_str_id <= 0;
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
      sender_str <= 0;
      calc_sys_done <= 0;

      case (state)
        IDLE: begin
          if (start_en) state <= SEND_MODE_STR;
          err_timer <= 0;
          seg_content <= {
            CHAR_BLK, CHAR_BLK, CHAR_BLK, CHAR_BLK, CHAR_BLK, CHAR_BLK, CHAR_BLK, CHAR_BLK
          };
          calc_err <= 0;
          disp_req_en <= 0;
        end

        SEND_MODE_STR: begin
          if (sender_ready) begin
            sender_str <= 1;
            sender_str_id <= 3'd2;  // mode-cal
            state <= WAIT_MODE_STR;
          end
        end

        WAIT_MODE_STR: begin
          if (sender_done) state <= DEBOUNCE_ENTRY;
        end

        DEBOUNCE_ENTRY: begin
          if (btn_confirm) begin
            err_timer <= 0;  // Reset timer if button is pressed (or bouncing high)
          end else begin
            if (err_timer < 10000) begin  // Wait ~100us (100MHz * 10000 = 100us)
              err_timer <= err_timer + 1;
            end else begin
              state <= SELECT_OP;
              err_timer <= 0;
            end
          end
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

            // --- UART Selection Logic ---
            if (rx_done) begin
              case (rx_data)
                8'h41, 8'h61: begin  // A/a -> ADD
                  op_reg <= OP_ADD;
                  target_op <= 0;
                  state <= SEL_SHOW_SUM;
                end
                8'h42, 8'h62: begin  // B/b -> MAT_MUL
                  op_reg <= OP_MAT_MUL;
                  target_op <= 0;
                  state <= SEL_SHOW_SUM;
                end
                8'h43, 8'h63: begin  // C/c -> SCALAR_MUL
                  op_reg <= OP_SCALAR_MUL;
                  target_op <= 0;
                  state <= SEL_SHOW_SUM;
                end
                8'h54, 8'h74: begin  // T/t -> TRANSPOSE
                  op_reg <= OP_TRANSPOSE;
                  target_op <= 0;
                  state <= SEL_SHOW_SUM;
                end
                8'h4A, 8'h6A: begin  // J/j -> CONV
                  op_reg <= OP_CONV;
                  target_op <= 0;
                  state <= SEL_SHOW_SUM;
                end
              endcase
            end

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
          if (target_op == 0) begin
            // Selecting A: Clear all, show 'A'
            seg_content <= {
              CHAR_A, CHAR_BLK, CHAR_BLK, CHAR_BLK, CHAR_BLK, CHAR_BLK, CHAR_BLK, CHAR_BLK
            };
          end else begin
            // Selecting B: Keep A's info (Left 4), Clear Right 4, show 'b'
            // Note: seg_content[7:4] holds "A _ ID ID"
            seg_content[3] <= CHAR_B;
            seg_content[2] <= CHAR_BLK;
            seg_content[1] <= CHAR_BLK;
            seg_content[0] <= CHAR_BLK;
          end

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
          end else if (btn_pos_confirm && target_op == 1 && scalar_val_in == 0) begin
            // Auto Select B
            search_id <= 0;
            state <= AUTO_SEARCH_B;
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
          end else if (btn_pos_confirm && target_op == 1 && scalar_val_in == 0) begin
            // Auto Select B
            search_id <= 0;
            state <= AUTO_SEARCH_B;
          end else if (rx_done && rx_valid_char) begin
            // Store ID
            if (target_op == 0) begin
              id_a_reg <= rx_decoded_val;
              // Fix: For Convolution, the selected matrix is the Kernel, which ALU expects in Matrix B
              if (op_reg == OP_CONV) begin
                id_b_reg <= rx_decoded_val;
              end

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
                state <= PRINT_A;
              end
            end else begin
              id_b_reg <= rx_decoded_val;
              // Update Display B
              seg_content[1] <= code_t'((rx_decoded_val / 10) % 10);
              seg_content[0] <= code_t'(rx_decoded_val % 10);

              state <= PRINT_A;
            end
          end
        end

        // Auto Search Logic
        AUTO_SEARCH_B: begin
          id_b_reg <= search_id;
          state <= AUTO_WAIT_MEM;
        end

        AUTO_WAIT_MEM: begin
          // Wait for memory read (1 cycle passed since AUTO_SEARCH_B)
          state <= AUTO_CHECK;
        end

        AUTO_CHECK: begin
          // Check validity
          if (mat_b_valid && check_validity()) begin
            // Found valid B
            // Update Display B
            seg_content[1] <= code_t'((search_id / 10) % 10);
            seg_content[0] <= code_t'(search_id % 10);
            state <= PRINT_A;
          end else begin
            // Invalid, try next
            if (search_id >= MAT_TOTAL_SLOTS - 1) begin
              state <= SEL_WAIT_ID;  // Give up
            end else begin
              search_id <= search_id + 1;
              state <= AUTO_SEARCH_B;
            end
          end
        end

        // ======================================================
        // New: Print & Confirm Selection
        // ======================================================
        PRINT_A: begin
          disp_req_en <= 1;
          disp_req_cmd <= 3;  // Single ID
          // Split ID A into m and n
          disp_req_m <= id_a_reg[5:3];
          disp_req_n <= id_a_reg[2:0];
          state <= WAIT_PRINT_A;
        end

        WAIT_PRINT_A: begin
          if (disp_req_done) begin
            disp_req_en <= 0;
            if (op_reg == OP_ADD || op_reg == OP_MAT_MUL) begin
              state <= PRINT_B;
            end else begin
              state <= CONFIRM_SELECTION;
            end
          end
        end

        PRINT_B: begin
          disp_req_en <= 1;
          disp_req_cmd <= 3;  // Single ID
          disp_req_m <= id_b_reg[5:3];
          disp_req_n <= id_b_reg[2:0];
          state <= WAIT_PRINT_B;
        end

        WAIT_PRINT_B: begin
          if (disp_req_done) begin
            disp_req_en <= 0;
            state <= CONFIRM_SELECTION;
          end
        end

        CONFIRM_SELECTION: begin
          // Display IDs on Seg (Already set in SEL_WAIT_ID / CONFIRM_SCALAR)
          // Just wait for confirm
          if (btn_pos_esc) begin
            state <= SELECT_OP;
          end else if (btn_pos_confirm) begin
            if (check_validity()) begin
              state <= EXEC_ALU;
            end else begin
              state <= ERROR_COUNTDOWN;
              err_timer <= 0;
              err_countdown_val <= cfg_err_countdown;  // Use Config
              calc_err <= 1;  // Turn on LED
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
            if (scalar_val_in == 0) begin
              // Use Random 0-9
              scalar_latch <= rand_val % 10;
            end else begin
              scalar_latch <= scalar_val_in;
            end
            state <= PRINT_A;
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
            // All operations now use streaming output during ALU execution
            state <= DONE_WAIT;
          end
        end

        // 6.5 Input Validation Error Countdown
        ERROR_COUNTDOWN: begin
          // Display: A/b _ E r r _ [Tens] [Ones]
          // Let's use 'b' to indicate we are re-selecting B
          seg_content <= {
            CHAR_B,
            CHAR_BLK,
            CHAR_E,
            CHAR_R,
            CHAR_R,
            CHAR_BLK,
            code_t'(err_countdown_val / 10),
            code_t'(err_countdown_val % 10)
          };

          // Countdown Logic (1 sec = 100M cycles)
          if (err_timer >= 100_000_000) begin
            err_timer <= 0;
            if (err_countdown_val > 0) begin
              err_countdown_val <= err_countdown_val - 1;
            end else begin
              // Timeout
              calc_err <= 0;
              state <= SELECT_OP;
            end
          end else begin
            err_timer <= err_timer + 1;
          end

          // Re-selection Logic (B)
          if (rx_done && rx_valid_char) begin
            id_b_reg <= rx_decoded_val;
            // Note: We don't update display here because it shows Error
          end

          if (btn_pos_confirm) begin
            if (check_validity()) begin
              calc_err <= 0;
              state <= EXEC_ALU;
            end else begin
              // Reset countdown
              err_countdown_val <= cfg_err_countdown;
              err_timer <= 0;
            end
          end else if (btn_pos_esc) begin
            calc_err <= 0;
            state <= SELECT_OP;
          end
        end

        // 

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
          // Display Cycle Count (Hex)
          // Format: [C] [Y] [C] [L] [Hex3] [Hex2] [Hex1] [Hex0]
          seg_content <= {
            CHAR_C,
            CHAR_Y,
            CHAR_C,
            CHAR_L,
            code_t'(alu_cycle_cnt[15:12]),
            code_t'(alu_cycle_cnt[11:8]),
            code_t'(alu_cycle_cnt[7:4]),
            code_t'(alu_cycle_cnt[3:0])
          };

          if (btn_pos_esc || btn_pos_confirm) begin
            state <= SELECT_OP;  // Start over
          end
        end

      endcase
    end
  end

endmodule
