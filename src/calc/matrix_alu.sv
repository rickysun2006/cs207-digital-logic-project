/*=============================================================================
#
# Project Name   : CS207_Project_Matrix_Calculator
# File Name      : matrix_alu.sv
# Module Name    : matrix_alu
# University     : SUSTech
#
# Create Date    : 2025-11-23
#
# Description    :
#     Handles matrix calculations, accepts calc_type, extracts matrices from matrix_storage, and distributes them to other modules for calculation.
#
# Revision History:
# -----------------------------------------------------------------------------
# Ver   |   Date     |   Author       |   Description
# -----------------------------------------------------------------------------
# v1.0  | 2025-11-23 |   [Your Name]  |   Initial creation
# v1.1  | 2025-12-09 | GitHub Copilot |   Implemented ALU logic
# v1.2  | 2025-12-10 | GitHub Copilot |   Optimized ALU resources (Shared Multipliers)
#
#=============================================================================*/
`include "../common/project_pkg.sv"
import project_pkg::*;

module matrix_alu (
    input wire clk,
    input wire rst_n,

    // --- Control Interface ---
    input wire      start,
    input op_code_t op_code,

    // --- Data Interface ---
    input matrix_t         matrix_A,
    input matrix_t         matrix_B,
    input matrix_element_t scalar_val,

    // --- Output Interface ---
    output logic           done,
    output matrix_t        result_matrix,
    output logic           error_flag,
    output logic    [31:0] cycle_cnt
);

  // --- Internal State ---
  typedef enum logic [2:0] {
    ALU_IDLE,
    ALU_EXEC,
    ALU_DONE
  } alu_state_t;
  alu_state_t state;

  // Counters
  logic [3:0] cnt_i;  // Row
  logic [3:0] cnt_j;  // Col
  logic [3:0] cnt_k;  // Dot product accumulator iterator

  logic [3:0] limit_i;
  logic [3:0] limit_j;
  logic [3:0] limit_k;  // For dot product loop

  // Cycle Counter
  logic [31:0] perf_cnt;

  // Accumulators (Width expanded to prevent overflow)
  logic signed [23:0] accum;
  logic signed [23:0] current_prod;

  // --- Optimization: Row Cache for Matrix A ---
  // Caches one row of Matrix A to reduce MUX complexity during Matrix Mul
  matrix_element_t [MAX_COLS-1:0] row_cache_A;

  // --- Hardcoded Image Data (Optimized as Function) ---
  function automatic logic [3:0] get_img_data(input int idx);
    case (idx)
      // Row 1: 3 7 2 9 0 5 1 8 4 6 3 2
      0: return 4'd3; 1: return 4'd7; 2: return 4'd2; 3: return 4'd9;
      4: return 4'd0; 5: return 4'd5; 6: return 4'd1; 7: return 4'd8;
      8: return 4'd4; 9: return 4'd6; 10: return 4'd3; 11: return 4'd2;
      // Row 2: 8 1 6 4 7 3 9 0 5 2 8 1
      12: return 4'd8; 13: return 4'd1; 14: return 4'd6; 15: return 4'd4;
      16: return 4'd7; 17: return 4'd3; 18: return 4'd9; 19: return 4'd0;
      20: return 4'd5; 21: return 4'd2; 22: return 4'd8; 23: return 4'd1;
      // Row 3: 4 9 0 2 6 8 3 5 7 1 4 9
      24: return 4'd4; 25: return 4'd9; 26: return 4'd0; 27: return 4'd2;
      28: return 4'd6; 29: return 4'd8; 30: return 4'd3; 31: return 4'd5;
      32: return 4'd7; 33: return 4'd1; 34: return 4'd4; 35: return 4'd9;
      // Row 4: 7 3 8 5 1 4 9 2 0 6 7 3
      36: return 4'd7; 37: return 4'd3; 38: return 4'd8; 39: return 4'd5;
      40: return 4'd1; 41: return 4'd4; 42: return 4'd9; 43: return 4'd2;
      44: return 4'd0; 45: return 4'd6; 46: return 4'd7; 47: return 4'd3;
      // Row 5: 2 6 4 0 8 7 5 3 1 9 2 4
      48: return 4'd2; 49: return 4'd6; 50: return 4'd4; 51: return 4'd0;
      52: return 4'd8; 53: return 4'd7; 54: return 4'd5; 55: return 4'd3;
      56: return 4'd1; 57: return 4'd9; 58: return 4'd2; 59: return 4'd4;
      // Row 6: 9 0 7 3 5 2 8 6 4 1 9 0
      60: return 4'd9; 61: return 4'd0; 62: return 4'd7; 63: return 4'd3;
      64: return 4'd5; 65: return 4'd2; 66: return 4'd8; 67: return 4'd6;
      68: return 4'd4; 69: return 4'd1; 70: return 4'd9; 71: return 4'd0;
      // Row 7: 5 8 1 6 4 9 2 7 3 0 5 8
      72: return 4'd5; 73: return 4'd8; 74: return 4'd1; 75: return 4'd6;
      76: return 4'd4; 77: return 4'd9; 78: return 4'd2; 79: return 4'd7;
      80: return 4'd3; 81: return 4'd0; 82: return 4'd5; 83: return 4'd8;
      // Row 8: 1 4 9 2 7 0 6 8 5 3 1 4
      84: return 4'd1; 85: return 4'd4; 86: return 4'd9; 87: return 4'd2;
      88: return 4'd7; 89: return 4'd0; 90: return 4'd6; 91: return 4'd8;
      92: return 4'd5; 93: return 4'd3; 94: return 4'd1; 95: return 4'd4;
      // Row 9: 6 2 5 8 3 1 7 4 9 0 6 2
      96: return 4'd6; 97: return 4'd2; 98: return 4'd5; 99: return 4'd8;
      100: return 4'd3; 101: return 4'd1; 102: return 4'd7; 103: return 4'd4;
      104: return 4'd9; 105: return 4'd0; 106: return 4'd6; 107: return 4'd2;
      // Row 10: 0 7 3 9 5 6 4 1 8 2 0 7
      108: return 4'd0; 109: return 4'd7; 110: return 4'd3; 111: return 4'd9;
      112: return 4'd5; 113: return 4'd6; 114: return 4'd4; 115: return 4'd1;
      116: return 4'd8; 117: return 4'd2; 118: return 4'd0; 119: return 4'd7;
      default: return 4'd0;
    endcase
  endfunction

  // Helper function for saturation
  function automatic matrix_element_t saturate(input logic signed [23:0] val);
    if (val > 24'sd127) return 8'sd127;
    else if (val < -24'sd128) return -8'sd128;
    else return val[7:0];
  endfunction

  // --- Sequential Logic ---
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state         <= ALU_IDLE;
      done          <= 0;
      error_flag    <= 0;
      result_matrix <= '0;
      cnt_i         <= 0;
      cnt_j         <= 0;
      cnt_k         <= 0;
      limit_i       <= 0;
      limit_j       <= 0;
      limit_k       <= 0;
      perf_cnt      <= 0;
      accum         <= 0;
    end else begin
      case (state)
        // ------------------------------------------------------------
        // 1. IDLE & PREPARE
        // ------------------------------------------------------------
        ALU_IDLE: begin
          done <= 0;
          if (start) begin
            error_flag             <= 0;
            perf_cnt               <= 0;
            result_matrix.is_valid <= 0;

            cnt_i                  <= 0;
            cnt_j                  <= 0;
            cnt_k                  <= 0;
            accum                  <= 0;  // Clear accumulator

            case (op_code)
              OP_ADD: begin
                if ((matrix_A.rows != matrix_B.rows) || (matrix_A.cols != matrix_B.cols)) begin
                  error_flag <= 1;
                  state <= ALU_DONE;
                end else begin
                  result_matrix.rows <= matrix_A.rows;
                  result_matrix.cols <= matrix_A.cols;
                  limit_i <= matrix_A.rows;
                  limit_j <= matrix_A.cols;
                  limit_k <= 1;  // Not used loop
                  state <= ALU_EXEC;
                end
              end

              OP_SCALAR_MUL: begin
                result_matrix.rows <= matrix_A.rows;
                result_matrix.cols <= matrix_A.cols;
                limit_i <= matrix_A.rows;
                limit_j <= matrix_A.cols;
                limit_k <= 1;
                state <= ALU_EXEC;
              end

              OP_TRANSPOSE: begin
                result_matrix.rows <= matrix_A.cols;
                result_matrix.cols <= matrix_A.rows;
                limit_i <= matrix_A.cols;
                limit_j <= matrix_A.rows;
                limit_k <= 1;
                state <= ALU_EXEC;
              end

              OP_MAT_MUL: begin
                if (matrix_A.cols != matrix_B.rows) begin
                  error_flag <= 1;
                  state <= ALU_DONE;
                end else begin
                  result_matrix.rows <= matrix_A.rows;
                  result_matrix.cols <= matrix_B.cols;
                  limit_i <= matrix_A.rows;
                  limit_j <= matrix_B.cols;
                  limit_k <= matrix_A.cols;  // The common dimension
                  state <= ALU_EXEC;
                  // Optimization: Preload Row Cache
                  row_cache_A <= matrix_A.cells[0];
                end
              end

              OP_CONV: begin
                if (matrix_B.rows != 3 || matrix_B.cols != 3) begin
                  error_flag <= 1;
                  state <= ALU_DONE;
                end else begin
                  result_matrix.rows <= 8;
                  result_matrix.cols <= 10;
                  limit_i <= 8;
                  limit_j <= 10;
                  limit_k <= 0;  // Convolution uses fixed loops
                  state <= ALU_EXEC;
                end
              end

              default: state <= ALU_DONE;
            endcase
          end
        end

        // ------------------------------------------------------------
        // 2. EXECUTION (Serialized)
        // ------------------------------------------------------------
        ALU_EXEC: begin
          perf_cnt <= perf_cnt + 1;

          case (op_code)
            // --- Simple Operations (1 cycle per element) ---
            OP_ADD: begin
              result_matrix.cells[cnt_i][cnt_j] <= saturate(
                  24'(signed'(matrix_A.cells[cnt_i][cnt_j])) + 
                    24'(signed'(matrix_B.cells[cnt_i][cnt_j]))
              );
              // Loop Logic (i, j)
              if (cnt_j == limit_j - 1) begin
                cnt_j <= 0;
                if (cnt_i == limit_i - 1) begin
                  result_matrix.is_valid <= 1;
                  state <= ALU_DONE;
                end else cnt_i <= cnt_i + 1;
              end else cnt_j <= cnt_j + 1;
            end

            OP_SCALAR_MUL: begin
              result_matrix.cells[cnt_i][cnt_j] <= saturate(
                  24'(signed'(matrix_A.cells[cnt_i][cnt_j])) * 24'(signed'(scalar_val))
              );
              // Loop Logic (same as ADD)
              if (cnt_j == limit_j - 1) begin
                cnt_j <= 0;
                if (cnt_i == limit_i - 1) begin
                  result_matrix.is_valid <= 1;
                  state <= ALU_DONE;
                end else cnt_i <= cnt_i + 1;
              end else cnt_j <= cnt_j + 1;
            end

            OP_TRANSPOSE: begin
              result_matrix.cells[cnt_i][cnt_j] <= matrix_A.cells[cnt_j][cnt_i];
              // Loop Logic
              if (cnt_j == limit_j - 1) begin
                cnt_j <= 0;
                if (cnt_i == limit_i - 1) begin
                  result_matrix.is_valid <= 1;
                  state <= ALU_DONE;
                end else cnt_i <= cnt_i + 1;
              end else cnt_j <= cnt_j + 1;
            end

            // --- Complex Operation: Matrix Mul (Serialized Loop) ---
            OP_MAT_MUL: begin
              // Accumulate: sum += row_cache_A[k] * B[k][j]
              // Optimization: Use row_cache_A instead of matrix_A.cells[cnt_i] to reduce MUX size
              
              accum <= accum + (24'(signed'(row_cache_A[cnt_k])) * 24'(signed'(matrix_B.cells[cnt_k][cnt_j])));

              if (cnt_k == limit_k - 1) begin
                // Dot product finished for this cell
                result_matrix.cells[cnt_i][cnt_j] <= saturate(
                    accum + (24'(signed'(row_cache_A[cnt_k])) * 24'(signed'(matrix_B.cells[cnt_k][cnt_j])))
                );
                accum <= 0;  // Reset for next cell
                cnt_k <= 0;

                // Move to next cell (j, then i)
                if (cnt_j == limit_j - 1) begin
                  cnt_j <= 0;
                  if (cnt_i == limit_i - 1) begin
                    result_matrix.is_valid <= 1;
                    state <= ALU_DONE;
                  end else begin
                    cnt_i <= cnt_i + 1;
                    // Optimization: Update Row Cache for next row
                    row_cache_A <= matrix_A.cells[cnt_i + 1];
                  end
                end else cnt_j <= cnt_j + 1;

              end else begin
                cnt_k <= cnt_k + 1;
              end
            end

            // --- Complex Operation: Convolution ---
            // For simplicity, we can keep convolution combinational per pixel (it's only 3x3=9 ops),
            // or serialize it if needed. 9 ops is much smaller than 12x12=144 parallel ops.
            // Let's keep it simple (combinational logic inside the state) for now, 
            // as MatMul was the main offender.
            OP_CONV: begin
              // Using blocking assignment logic variable for cleaner code,
              // or just write the sum expression.
              // Since `img_data` and `matrix_B` are small, 9 muls is usually fine.
              // If this still fails timing, we can serialize this too.

              logic signed [23:0] conv_sum_temp;
              conv_sum_temp = 0;
              for (int r = 0; r < 3; r++) begin
                for (int c = 0; c < 3; c++) begin
                  // Optimization: Use get_img_data function and explicit shift for index
                  conv_sum_temp += 24'(signed'({4'b0, get_img_data(((cnt_i + r) << 3) + ((cnt_i + r) << 2) + (cnt_j + c))})) * 24'(signed'(matrix_B.cells[r][c]));
                end
              end

              result_matrix.cells[cnt_i][cnt_j] <= saturate(conv_sum_temp);

              // Loop Logic (8x10 output)
              if (cnt_j == limit_j - 1) begin
                cnt_j <= 0;
                if (cnt_i == limit_i - 1) begin
                  result_matrix.is_valid <= 1;
                  state <= ALU_DONE;
                end else cnt_i <= cnt_i + 1;
              end else cnt_j <= cnt_j + 1;
            end

            default: state <= ALU_DONE;
          endcase
        end

        // ------------------------------------------------------------
        // 3. DONE
        // ------------------------------------------------------------
        ALU_DONE: begin
          done <= 1;
          if (!start) state <= ALU_IDLE;
        end
      endcase
    end
  end

  assign cycle_cnt = perf_cnt;

endmodule
