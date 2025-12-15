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

  // --- Hardcoded Image Data (Keep your original ROM data) ---
  logic [3:0] img_data[0:119];
  initial begin
    // 第 1 行: 3 7 2 9 0 5 1 8 4 6 3 2
    img_data[0] = 4'd3; img_data[1] = 4'd7; img_data[2] = 4'd2; img_data[3] = 4'd9;
    img_data[4] = 4'd0; img_data[5] = 4'd5; img_data[6] = 4'd1; img_data[7] = 4'd8;
    img_data[8] = 4'd4; img_data[9] = 4'd6; img_data[10] = 4'd3; img_data[11] = 4'd2;

    // 第 2 行: 8 1 6 4 7 3 9 0 5 2 8 1
    img_data[12] = 4'd8; img_data[13] = 4'd1; img_data[14] = 4'd6; img_data[15] = 4'd4;
    img_data[16] = 4'd7; img_data[17] = 4'd3; img_data[18] = 4'd9; img_data[19] = 4'd0;
    img_data[20] = 4'd5; img_data[21] = 4'd2; img_data[22] = 4'd8; img_data[23] = 4'd1;

    // 第 3 行: 4 9 0 2 6 8 3 5 7 1 4 9
    img_data[24] = 4'd4; img_data[25] = 4'd9; img_data[26] = 4'd0; img_data[27] = 4'd2;
    img_data[28] = 4'd6; img_data[29] = 4'd8; img_data[30] = 4'd3; img_data[31] = 4'd5;
    img_data[32] = 4'd7; img_data[33] = 4'd1; img_data[34] = 4'd4; img_data[35] = 4'd9;

    // 第 4 行: 7 3 8 5 1 4 9 2 0 6 7 3
    img_data[36] = 4'd7; img_data[37] = 4'd3; img_data[38] = 4'd8; img_data[39] = 4'd5;
    img_data[40] = 4'd1; img_data[41] = 4'd4; img_data[42] = 4'd9; img_data[43] = 4'd2;
    img_data[44] = 4'd0; img_data[45] = 4'd6; img_data[46] = 4'd7; img_data[47] = 4'd3;

    // 第 5 行: 2 6 4 0 8 7 5 3 1 9 2 4
    img_data[48] = 4'd2; img_data[49] = 4'd6; img_data[50] = 4'd4; img_data[51] = 4'd0;
    img_data[52] = 4'd8; img_data[53] = 4'd7; img_data[54] = 4'd5; img_data[55] = 4'd3;
    img_data[56] = 4'd1; img_data[57] = 4'd9; img_data[58] = 4'd2; img_data[59] = 4'd4;

    // 第 6 行: 9 0 7 3 5 2 8 6 4 1 9 0
    img_data[60] = 4'd9; img_data[61] = 4'd0; img_data[62] = 4'd7; img_data[63] = 4'd3;
    img_data[64] = 4'd5; img_data[65] = 4'd2; img_data[66] = 4'd8; img_data[67] = 4'd6;
    img_data[68] = 4'd4; img_data[69] = 4'd1; img_data[70] = 4'd9; img_data[71] = 4'd0;

    // 第 7 行: 5 8 1 6 4 9 2 7 3 0 5 8
    img_data[72] = 4'd5; img_data[73] = 4'd8; img_data[74] = 4'd1; img_data[75] = 4'd6;
    img_data[76] = 4'd4; img_data[77] = 4'd9; img_data[78] = 4'd2; img_data[79] = 4'd7;
    img_data[80] = 4'd3; img_data[81] = 4'd0; img_data[82] = 4'd5; img_data[83] = 4'd8;

    // 第 8 行: 1 4 9 2 7 0 6 8 5 3 1 4
    img_data[84] = 4'd1; img_data[85] = 4'd4; img_data[86] = 4'd9; img_data[87] = 4'd2;
    img_data[88] = 4'd7; img_data[89] = 4'd0; img_data[90] = 4'd6; img_data[91] = 4'd8;
    img_data[92] = 4'd5; img_data[93] = 4'd3; img_data[94] = 4'd1; img_data[95] = 4'd4;

    // 第 9 行: 6 2 5 8 3 1 7 4 9 0 6 2
    img_data[96] = 4'd6; img_data[97] = 4'd2; img_data[98] = 4'd5; img_data[99] = 4'd8;
    img_data[100] = 4'd3; img_data[101] = 4'd1; img_data[102] = 4'd7; img_data[103] = 4'd4;
    img_data[104] = 4'd9; img_data[105] = 4'd0; img_data[106] = 4'd6; img_data[107] = 4'd2;

    // 第 10 行: 0 7 3 9 5 6 4 1 8 2 0 7
    img_data[108] = 4'd0; img_data[109] = 4'd7; img_data[110] = 4'd3; img_data[111] = 4'd9;
    img_data[112] = 4'd5; img_data[113] = 4'd6; img_data[114] = 4'd4; img_data[115] = 4'd1;
    img_data[116] = 4'd8; img_data[117] = 4'd2; img_data[118] = 4'd0; img_data[119] = 4'd7;
  end

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
                  limit_k <= 0;  // Reset k for convolution loop
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
              // Accumulate: sum += A[i][k] * B[k][j]
              // Note: We use one extra cycle per element to write back, or optimize inside loop.
              // Here: Accumulate in 'accum'. When k reaches limit, write and reset.

              accum <= accum + (24'(signed'(matrix_A.cells[cnt_i][cnt_k])) * 24'(signed'(matrix_B.cells[cnt_k][cnt_j])));

              if (cnt_k == limit_k - 1) begin
                // Dot product finished for this cell
                result_matrix.cells[cnt_i][cnt_j] <= saturate(
                    accum + (24'(signed'(matrix_A.cells[cnt_i][cnt_k])) * 24'(signed'(matrix_B.cells[cnt_k][cnt_j])))
                );
                accum <= 0;  // Reset for next cell
                cnt_k <= 0;

                // Move to next cell (j, then i)
                if (cnt_j == limit_j - 1) begin
                  cnt_j <= 0;
                  if (cnt_i == limit_i - 1) begin
                    result_matrix.is_valid <= 1;
                    state <= ALU_DONE;
                  end else cnt_i <= cnt_i + 1;
                end else cnt_j <= cnt_j + 1;

              end else begin
                cnt_k <= cnt_k + 1;
              end
            end

            // --- Complex Operation: Convolution ---
            // Serialized implementation to fix timing violation (WNS -11.6ns)
            // Instead of 9 parallel MACs, we do 1 MAC per cycle.
            OP_CONV: begin
              // Calculate current kernel coordinates (kr, kc) from cnt_k (0..8)
              logic [1:0] kr, kc;
              kr = cnt_k / 3;
              kc = cnt_k % 3;

              // Accumulate: sum += Image[i+r][j+c] * Kernel[r][c]
              // Note: img_data is 1D array, index = (i+r)*12 + (j+c)
              accum <= accum + 
                  (24'(signed'({4'b0, img_data[(cnt_i + kr) * 12 + (cnt_j + kc)]})) * 
                   24'(signed'(matrix_B.cells[kr][kc])));

              if (cnt_k == 8) begin
                // Last pixel of the 3x3 window
                // Write result with saturation
                result_matrix.cells[cnt_i][cnt_j] <= saturate(
                    accum + 
                    (24'(signed'({4'b0, img_data[(cnt_i + kr) * 12 + (cnt_j + kc)]})) * 
                     24'(signed'(matrix_B.cells[kr][kc])))
                );

                accum <= 0;  // Reset for next window
                cnt_k <= 0;

                // Loop Logic (8x10 output)
                if (cnt_j == limit_j - 1) begin
                  cnt_j <= 0;
                  if (cnt_i == limit_i - 1) begin
                    result_matrix.is_valid <= 1;
                    state <= ALU_DONE;
                  end else cnt_i <= cnt_i + 1;
                end else cnt_j <= cnt_j + 1;

              end else begin
                cnt_k <= cnt_k + 1;
              end
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
