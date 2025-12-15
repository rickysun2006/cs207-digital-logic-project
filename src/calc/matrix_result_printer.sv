/*=============================================================================
# File Name      : matrix_result_printer.sv
# Description    : Sends ALU result via UART Sender.
#                  Format: [Header 0xAA] [Rows] [Cols] [Data...]
=============================================================================*/
`include "../common/project_pkg.sv"
import project_pkg::*;

module matrix_result_printer (
    input wire     clk,
    input wire     rst_n,
    input wire     start,         // Triggered by matrix_calc_sys
    input matrix_t result_matrix, // Result from ALU

    // --- Sender Interface ---
    output matrix_element_t sender_data,
    output reg              sender_start,
    output reg              sender_is_last_col,
    output reg              sender_newline_only,
    input  wire             sender_done,
    input  wire             sender_ready,

    // --- Control Interface ---
    output reg printer_done
);

  typedef enum logic [3:0] {
    IDLE,
    SEND_HEAD,
    WAIT_HEAD,
    SEND_ROWS,
    WAIT_ROWS,
    SEND_COLS,
    WAIT_COLS,
    SEND_DATA,
    WAIT_DATA,
    DONE
  } state_t;

  state_t state;
  reg [ROW_IDX_W-1:0] r;
  reg [COL_IDX_W-1:0] c;

  matrix_element_t val_latch;
  assign sender_data = val_latch;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      sender_start <= 0;
      sender_is_last_col <= 0;
      sender_newline_only <= 0;
      printer_done <= 0;
      r <= 0;
      c <= 0;
    end else begin
      // Default
      sender_start <= 0;
      sender_newline_only <= 0;
      sender_is_last_col <= 0;
      printer_done <= 0;

      case (state)
        IDLE: begin
          if (start) state <= SEND_HEAD;
        end

        // 1. Send Header (0xAA = 170, simplified as a number)
        // Note: Our sender sends ASCII string of the number.
        SEND_HEAD: begin
          if (sender_ready) begin
            val_latch <= 8'd170;  // 0xAA
            sender_start <= 1;
            state <= WAIT_HEAD;
          end
        end
        WAIT_HEAD: if (sender_done) state <= SEND_ROWS;

        // 2. Send Rows
        SEND_ROWS: begin
          if (sender_ready) begin
            val_latch <= signed'({1'b0, result_matrix.rows});
            sender_start <= 1;
            state <= WAIT_ROWS;
          end
        end
        WAIT_ROWS: if (sender_done) state <= SEND_COLS;

        // 3. Send Cols
        SEND_COLS: begin
          if (sender_ready) begin
            val_latch <= signed'({1'b0, result_matrix.cols});
            sender_start <= 1;
            sender_is_last_col <= 1;  // Newline after dimensions
            state <= WAIT_COLS;
          end
        end
        WAIT_COLS: begin
          if (sender_done) begin
            state <= SEND_DATA;
            r <= 0;
            c <= 0;
          end
        end

        // 4. Send Matrix Data Loop
        SEND_DATA: begin
          if (sender_ready) begin
            val_latch <= result_matrix.cells[r][c];
            sender_start <= 1;

            if (c == result_matrix.cols - 1) sender_is_last_col <= 1;
            else sender_is_last_col <= 0;

            state <= WAIT_DATA;
          end
        end

        WAIT_DATA: begin
          if (sender_done) begin
            // Loop Update
            if (c == result_matrix.cols - 1) begin
              c <= 0;
              if (r == result_matrix.rows - 1) begin  // Added begin
                state <= DONE;
              end else begin  // Added begin
                r <= r + 1;
                state <= SEND_DATA;  // Next Row
              end  // Added end
            end else begin
              c <= c + 1;
              state <= SEND_DATA;  // Next Col
            end
          end
        end

        DONE: begin
          printer_done <= 1;
          state <= IDLE;
        end
      endcase
    end
  end

endmodule
